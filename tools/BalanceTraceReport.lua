-- tools/BalanceTraceReport.lua
-- 밸런스 보고서의 '스승의 흔적' 캠페인 줄 (tools/BalanceReport 가 master_trace 기록에만 부른다):
--   track(w, record, on) : 수기를 연 날 · 최종 보스 등장(그때 점화 수 · 체력 · 시각) · 아이기스 전개/파훼 · 보스 결과(처치 여부 ·
--                          처치 때 점화 수 · 등장부터 걸린 초)
--   emit(emit, records)  : 수기(평균 · 6편 다 모은 비율 · 편별 평균 일차) · 마지막 밤(도달 · 보스 처치 · 처치 때 4/4 점화 · 아이기스) ·
--                          진엔딩(true_dawn) 달성률 — 전체 런 대비 목표 TRUE_TARGET (OK · LOW · HIGH) · 숨은 엔딩(new_gatekeeper) 비율

local BalanceTraceReport = {}

local TRUE_TARGET = { 0.15, 0.30 }

function BalanceTraceReport.track(w, record, on)
    if w.master_trace == nil then
        return
    end
    record.trace_days, record.trace_aegis, record.trace_breaks = {}, 0, 0
    on("master:journal_unlocked", function(p) record.trace_days[p.index] = w.day end)
    on("boss:master_arrived", function(p)
        record.trace_boss, record.trace_lit_start = true, w.master_trace:lit_count()
        record.trace_boss_hp, record.trace_spawn_t = p.monster.max_hp, w.combat.elapsed
    end)
    on("boss:aegis_raised", function() record.trace_aegis = record.trace_aegis + 1 end)
    on("boss:aegis_broken", function() record.trace_breaks = record.trace_breaks + 1 end)
    on("master:final_resolved", function(p)
        record.trace_slain, record.trace_lit = p.slain, p.lit
        record.trace_fight = w.combat.elapsed - (record.trace_spawn_t or 0)
    end)
end

local function pct(part, whole)
    return whole > 0 and part / whole * 100 or 0
end

function BalanceTraceReport.emit(emit, records)
    local n = #records
    local c = { journals = 0, all = 0, reached = 0, lit_start = 0, slain = 0, lit4 = 0, aegis = 0, breaks = 0, wins = 0, true_dawn = 0,
        hidden = 0, softlock = 0, hp = 0, fight = 0, fights = 0, walled = 0 }
    local day_sum, day_n = {}, {}
    for _, r in ipairs(records) do
        local t = r.trace or {}
        c.journals = c.journals + (t.journals or 0)
        c.all = c.all + ((t.journals or 0) >= (t.journal_total or 6) and 1 or 0)
        for index = 1, 6 do
            local day = (r.trace_days or {})[index]
            if day ~= nil then
                day_sum[index], day_n[index] = (day_sum[index] or 0) + day, (day_n[index] or 0) + 1
            end
        end
        if r.trace_boss then
            c.reached, c.lit_start = c.reached + 1, c.lit_start + (r.trace_lit_start or 0)
            c.aegis, c.breaks = c.aegis + (r.trace_aegis or 0), c.breaks + (r.trace_breaks or 0)
            c.hp = c.hp + (r.trace_boss_hp or 0)
        end
        if r.trace_fight ~= nil then
            c.fight, c.fights = c.fight + r.trace_fight, c.fights + 1
            c.walled = c.walled + (r.trace_slain and 0 or 1)
        end
        if r.trace_slain then
            c.slain, c.lit4 = c.slain + 1, c.lit4 + ((r.trace_lit or 0) >= 4 and 1 or 0)
        end
        c.wins = c.wins + (r.result == "victory" and 1 or 0)
        c.true_dawn = c.true_dawn + (r.ending == "true_dawn" and 1 or 0)
        c.hidden = c.hidden + (r.ending == "new_gatekeeper" and 1 or 0)
        c.softlock = c.softlock + (r.softlock and 1 or 0)
    end
    local days = {}
    for index = 1, 6 do
        days[index] = day_n[index] and string.format("%d:%.0f", index, day_sum[index] / day_n[index]) or (index .. ":-")
    end
    emit("trace journals: avg %.1f/6 · all six in %.0f%% of runs · avg unlock day %s", c.journals / n, pct(c.all, n),
        table.concat(days, " "))
    local reached = math.max(1, c.reached)
    emit("trace final night: reached %.0f%% (lit at arrival avg %.1f/4) · boss slain %.0f%% of runs (4/4 lit at the kill %.0f%%) · "
        .. "aegis raised %.1f / broken %.1f per final night", pct(c.reached, n), c.lit_start / reached, pct(c.slain, n),
        pct(c.lit4, n), c.aegis / reached, c.breaks / reached)
    emit("trace boss: max HP avg %.0f · fight %.1fs avg (spawn → slain or wall) · reached the wall %d of %d fights", c.hp / reached,
        c.fight / math.max(1, c.fights), c.walled, c.fights)
    local rate = c.true_dawn / n
    local verdict = rate < TRUE_TARGET[1] and "LOW" or (rate > TRUE_TARGET[2] and "HIGH" or "OK")
    emit("trace endings: true_dawn %.0f%% of runs (target %d~%d%%) %s · new_gatekeeper %.0f%% of runs (%.0f%% of wins) · softlock %.0f%%",
        rate * 100, TRUE_TARGET[1] * 100, TRUE_TARGET[2] * 100, verdict, pct(c.hidden, n), pct(c.hidden, c.wins), pct(c.softlock, n))
end

return BalanceTraceReport

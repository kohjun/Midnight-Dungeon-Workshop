-- tools/BalanceReportText.lua
-- 밸런스 보고서(tools/BalanceReport)의 보고 줄 서식. 계산은 BalanceReport 가 하고, 여기서는 emit(fmt, ...) 으로 한 줄씩 내보낸다.
--   outcome(승패·소프트락·처치) · endings(엔딩 분포) · status(엔딩 판정 상태) · cursed(최종일 보스 때 저주 유물 수) ·
--   forge(강화·템포·연마석·마모) · wall(패배 시점·마지막 일격·방벽 피해 원인과 몫) · economy(달별 수입·골드 흐름·유지비·아침 골드)
-- add · total · month_of 는 BalanceReport 의 기록에도 쓰는 표 도우미다.

local CALENDAR = require("data.calendar")

local BalanceReportText = {}

local GOLD_COLUMNS = 10             -- 일차별 아침 골드 한 줄에 찍는 날 수

local function num(value)
    return type(value) == "number" and value or 0
end

function BalanceReportText.add(book, key, amount)
    book[key] = (book[key] or 0) + amount
end

-- 기록들의 숫자 필드 합 (없는 필드는 0)
function BalanceReportText.total(records, key)
    local sum = 0
    for _, r in ipairs(records) do
        sum = sum + num(r[key])
    end
    return sum
end

function BalanceReportText.month_of(day)
    return math.floor((day - 1) / CALENDAR.month_days) + 1
end

local add, total, month_of = BalanceReportText.add, BalanceReportText.total, BalanceReportText.month_of

local function percent(part, whole)
    return whole > 0 and string.format("%d%%", math.floor(part * 100 / whole + 0.5)) or "-"
end

local function whole_pct(fraction)
    return math.floor(fraction * 100 + 0.5)
end

-- 정렬된 목록의 분위수 (가장 가까운 순위, 비어 있으면 0)
local function quantile(sorted, q)
    return #sorted > 0 and sorted[math.max(1, math.floor(#sorted * q + 0.5))] or 0
end

-- 원인별 합계 → "이름 값 · 이름 값" (이름순, 비어 있으면 none)
local function joined(sums, show, sep)
    local parts = {}
    for key, amount in pairs(sums) do
        parts[#parts + 1] = tostring(key) .. (sep or " ") .. show(amount)
    end
    table.sort(parts)
    return #parts > 0 and table.concat(parts, " · ") or "none"
end

local function per_run(n)
    return function(amount) return string.format("%.1f", amount / n) end
end

function BalanceReportText.outcome(emit, difficulty, mode, records)
    local n, counts, softlocks = #records, {}, 0
    for _, r in ipairs(records) do
        add(counts, r.result or "?", 1)
        softlocks = softlocks + (r.softlock and 1 or 0)
    end
    emit("── %s (%d days, %d runs) ──", difficulty, mode.days, n)
    emit("victory %s · bankrupt %s · defeat %s · soft-lock %s · avg days survived %.1f", percent(counts.victory or 0, n),
        percent(counts.bankrupt or 0, n), percent(counts.defeat or 0, n), percent(softlocks, n), total(records, "days_survived") / n)
    emit("avg kills %.0f · bought %.1f/run · forge ok %d / fail %d", total(records, "kills") / n, total(records, "bought") / n,
        total(records, "forge_ok"), total(records, "forge_fail"))
end

-- mix = BalanceReport.ending_mix(records)
function BalanceReportText.endings(emit, label, mix)
    if mix.wins == 0 then
        emit("%s: no wins", label)
        return
    end
    local parts = {}
    for _, id in ipairs(mix.order) do
        parts[#parts + 1] = string.format("%s %d (%s)", id, mix.counts[id], percent(mix.counts[id], mix.wins))
    end
    local flag = mix.flag == "SKEWED" and string.format("SKEWED (%s >= %d%%)", mix.top, whole_pct(mix.skew)) or mix.flag
    emit("%s (%% of %d wins): %s · %s", label, mix.wins, table.concat(parts, " · "), flag)
end

-- 승리 런의 엔딩 판정 상태 분포 (record.status 는 systems/Endings.status 가 있을 때만 생긴다)
function BalanceReportText.status(emit, wins, high_level)
    local list = {}
    for _, r in ipairs(wins) do
        list[#list + 1] = r.status
    end
    if #list == 0 then
        return
    end
    local function sorted(get)
        local out = {}
        for _, s in ipairs(list) do
            local value = get(s)
            out[#out + 1] = type(value) == "number" and value or nil
        end
        table.sort(out)
        return out
    end
    local function quartiles(get)
        local out = sorted(get)
        return #out == 0 and "-" or string.format("P25 %.2f · P50 %.2f · P75 %.2f", quantile(out, 0.25), quantile(out, 0.5),
            quantile(out, 0.75))
    end
    local function share(test)          -- test 가 nil 을 돌려주는(필드가 없는) 상태는 세지 않는다
        local hit, seen = 0, 0
        for _, s in ipairs(list) do
            local verdict = test(s)
            seen, hit = seen + (verdict ~= nil and 1 or 0), hit + (verdict == true and 1 or 0)
        end
        return percent(hit, seen)
    end
    local function rich(s) if s.gold and s.need then return s.gold >= s.need end end
    local function sturdy(s) if s.hp_ratio and s.min_hp_ratio then return s.hp_ratio >= s.min_hp_ratio end end
    local function both(s) if rich(s) ~= nil and sturdy(s) ~= nil then return rich(s) and sturdy(s) end end
    local function master(s)
        if type(s.master) == "number" and s.best_level then return s.best_level >= s.master end
        if s.master ~= nil then return s.master == true end
    end
    local function high(s) if s.best_level then return s.best_level >= high_level end end
    local levels, level_sum = sorted(function(s) return s.best_level end), 0
    for _, level in ipairs(levels) do
        level_sum = level_sum + level
    end
    emit("ending status (%d wins): gold/need %s · gold >= need %s · need P50 %.0f (base %.0f) · master %s", #list,
        quartiles(function(s) return num(s.need) > 0 and num(s.gold) / s.need or nil end), share(rich),
        quantile(sorted(function(s) return s.need end), 0.5), quantile(sorted(function(s) return s.base_need end), 0.5),
        share(master))
    emit("ending status: hp ratio %s · hp >= min %s · gold and hp both %s · best level avg +%.1f · >= +%d %s",
        quartiles(function(s) return s.hp_ratio end), share(sturdy), share(both), #levels > 0 and level_sum / #levels or 0,
        high_level, share(high))
end

-- 승리 런의 최종일 보스 처치 때 진열장 저주 유물 수 (0 .. bins+) · 비율 사분위 · abyss = 심연 장악 기준 표 (data/endings.lua)
function BalanceReportText.cursed(emit, wins, bins, abyss)
    local counts, parts = {}, {}
    for bin = 0, bins do
        counts[bin] = 0
    end
    local unkilled = 0
    for _, r in ipairs(wins) do
        if r.final_boss_cursed == nil then
            unkilled = unkilled + 1                 -- 최종일 대보스를 못 잡은 승리 (0 개와 구별)
        else
            local bin = math.min(bins, math.floor(num(r.final_boss_cursed)))
            counts[bin] = counts[bin] + 1
        end
    end
    for bin = 0, bins do
        parts[#parts + 1] = string.format("%d%s: %d", bin, bin == bins and "+" or "", counts[bin])
    end
    local shares = {}
    for _, r in ipairs(wins) do
        if r.final_boss_cursed ~= nil then
            shares[#shares + 1] = num(r.final_boss_share)
        end
    end
    table.sort(shares)
    local function q(p)
        return #shares > 0 and shares[math.max(1, math.ceil(#shares * p))] or 0
    end
    local need = abyss and string.format("%d+ cursed and %d%% of the display", abyss.cursed or 0, math.floor((abyss.share or 0) * 100 + 0.5))
    emit("final-boss cursed relics on grid (wins): %s · share P25 %.2f · P50 %.2f · P75 %.2f · abyss ending needs %s%s",
        table.concat(parts, " · "), q(0.25), q(0.5), q(0.75), need or "-",
        unkilled > 0 and string.format(" · final boss not killed %d", unkilled) or "")
end

-- 하룻밤 레인에 나온 몬스터 수: 모든 런 최대 · 런별 최대의 평균 · 밤 평균 (웨이브 상한 data/waves.lua 의 crowd_cap 은 우두머리·소환 제외)
function BalanceReportText.crowd(emit, records)
    local worst, nights = 0, total(records, "crowd_nights")
    for _, r in ipairs(records) do
        worst = math.max(worst, num(r.crowd_max))
    end
    emit("crowd: max %d monsters in one night · avg per-run max %.0f · avg %.0f per night · wave cap %d (+ headliner & summons)",
        worst, total(records, "crowd_max") / math.max(1, #records), total(records, "crowd_sum") / math.max(1, nights),
        require("data.waves").crowd_cap.per_night)
end

-- tempo = BalanceReport.forge_tempo(records) · wear = BalanceReport.wear(records)
function BalanceReportText.forge(emit, records, tempo, wear)
    local n = #records
    emit("forge per run: ok %.1f · fail %.1f · shattered %.2f · durability restores %.1f · best level +%.1f · worn-out %.1f "
        .. "(sold %.1f) · mid-bosses slain %.1f", total(records, "forge_ok") / n, total(records, "forge_fail") / n,
        total(records, "forge_destroyed") / n, total(records, "restored") / n, total(records, "max_level") / n,
        total(records, "worn_out") / n, total(records, "sold_worn") / n, total(records, "midbosses") / n)
    local split = ""
    if tempo.maint + tempo.grow > 0 then
        split = string.format(" · maintenance %.1f/run (%s) · growth %.1f/run (%s)", tempo.maint / n,
            percent(tempo.maint, tempo.attempts), tempo.grow / n, percent(tempo.grow, tempo.attempts))
    end
    emit("forge tempo: %.1f attempts/run · %.2f per survived day · %s (target %.1f-%.1f)%s · AI daily cap hit with work left "
        .. "on %s of days", tempo.attempts / n, tempo.per_day, tempo.flag, tempo.low, tempo.high, split,
        percent(tempo.capped or 0, tempo.days))
    local gained, spent, gained_sum = {}, {}, 0
    for _, r in ipairs(records) do
        for reason, amount in pairs(r.stones_in or {}) do
            add(gained, reason, amount)
            gained_sum = gained_sum + amount
        end
        for reason, amount in pairs(r.stones_out or {}) do
            add(spent, reason, amount)
        end
    end
    emit("stones per run: gained %s (total %.1f) · spent %s · held at end %.1f", joined(gained, per_run(n)), gained_sum / n,
        joined(spent, per_run(n)), total(records, "final_stones") / n)
    if wear.per_night == nil then
        emit("wear: no display weapon-nights recorded")
        return
    end
    emit("wear: display weapons lose %.1f%%/night (%d weapon-nights; %d hit 0%% mid-night, excluded) · "
        .. "main weapon lasts ~%s nights to 0%%", wear.per_night, wear.samples, wear.zeroed,
        wear.nights and string.format("%.1f", wear.nights) or "-")
end

-- wall = BalanceReport.wall_share(records)
function BalanceReportText.wall(emit, records, wall)
    local n, deaths, causes = #records, {}, {}
    for _, r in ipairs(records) do
        if r.result == "defeat" or r.result == "bankrupt" then
            add(deaths, string.format("%s M%02d", r.result, month_of(r.day)), 1)
        end
        for reason, amount in pairs(r.damage or {}) do
            add(causes, reason, amount)
        end
    end
    emit("losses by day: %s", joined(deaths, tostring, ": "))
    emit("killing blow (defeats): %s", joined(wall.blows, tostring))
    emit("avg wall damage per run by cause: %s", joined(causes, per_run(n)))
    local shed = total(records, "shed")             -- AI 가 방벽이 위험할 때 내려 판 저주 대가 유물 (세는 AI 만)
    emit("wall damage share: monster-side %.1f/run (%s) · curse %.1f/run (%s) · %s (target monster-side >= %d%%)%s",
        wall.monster / n, percent(wall.monster, wall.total), wall.curse / n, percent(wall.curse, wall.total), wall.flag,
        whole_pct(wall.target), shed > 0 and string.format(" · cursed relics shed %.1f/run", shed / n) or "")
end

local function rounded_per_run(n)
    return function(amount) return string.format("%d", math.floor(amount / n + 0.5)) end
end

function BalanceReportText.economy(emit, mode, records)
    local n, months, line, sums = #records, {}, {}, { earned = {}, spent = {} }
    local morning_sum, morning_n, row = {}, {}, {}
    for _, r in ipairs(records) do
        for month, amount in pairs(r.monthly or {}) do
            months[month] = months[month] or {}
            table.insert(months[month], amount)
        end
        for book, into in pairs(sums) do
            for reason, amount in pairs(r[book] or {}) do
                add(into, reason, amount)
            end
        end
        for day, gold in pairs(r.gold or {}) do
            add(morning_sum, day, gold)
            add(morning_n, day, 1)
        end
    end
    for month = 1, math.ceil(mode.days / CALENDAR.month_days) do
        local list = months[month] or {}
        table.sort(list)
        line[#line + 1] = string.format("M%d %d", month, quantile(list, 0.5))
    end
    emit("median gold earned per month: %s", table.concat(line, " · "))
    emit("avg gold earned per run: %s", joined(sums.earned, rounded_per_run(n)))
    emit("avg gold spent per run: %s", joined(sums.spent, rounded_per_run(n)))
    local schedule = require("systems.Tribute")({ rules = mode, max_days = mode.days })    -- 할인 없는 기준 금액
    for _, due in ipairs(schedule:schedule()) do
        local reached, paid, golds = 0, 0, {}
        for _, r in ipairs(records) do
            if r.paid[due] or r.missed[due] then
                reached, paid = reached + 1, paid + (r.paid[due] and 1 or 0)
                golds[#golds + 1] = r.before[due]
            end
        end
        table.sort(golds)
        emit("upkeep D%d %dG: pass %s (%d/%d) · gold before upkeep P10 %d · P25 %d · median %d", due, schedule:base_for(due),
            percent(paid, reached), paid, reached, quantile(golds, 0.1), quantile(golds, 0.25), quantile(golds, 0.5))
    end
    for day = 1, mode.days do
        row[#row + 1] = morning_n[day] and string.format("D%d %d", day, math.floor(morning_sum[day] / morning_n[day] + 0.5))
            or ("D" .. day .. " -")
        if #row == GOLD_COLUMNS or day == mode.days then
            emit("avg morning gold: %s", table.concat(row, " · "))
            row = {}
        end
    end
end

return BalanceReportText

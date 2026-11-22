-- tools/SmokeTraceBattleBoss.lua
-- '스승의 흔적' 전투 화면 스모크 검사 2부 (tools/SmokeTraceBattle 가 kit 와 함께 부른다):
--   ② 밤 진열장: 4칸 점화 → 은청색 공명선(가운데 칸 모서리 틈 픽셀) · 번개 슬롯 결계선(푸른 빛) ·
--      룬 사슬(ui/RuneChainView): 묶인 칸이 어두워진다 · 막 묶인 슬램 · 풀리기 직전 옅어짐 경로
--   ③ 최종 보스: 60일차 밤 boss_master 출현 → 경고 배너(ui/EntityMotion 기록) → 공방 봉쇄 연출(사슬 토스트) →
--      65% 아이기스(돔 테 · 레인 아래 체력 띠 · 파훼 게이지 · 과부하 안내) → 과부하로 파훼(토스트) · 그로기 → 처치 결말 배너,
--      몬스터 툴팁(최종 보스 등급 · 아이기스/그로기 줄 · 봉쇄 기믹 수치 — '{' 없음)
--   --shots 면 smoke_trace_grid_night.png · smoke_trace_boss.png · smoke_trace_boss_groggy.png · smoke_trace_boss_end.png

local SmokeTraceBattleBoss = {}

local ROW5 = { 21, 22, 23, 24, 25 }
local T_NIGHT, T_BOSS, T_GROGGY, T_END = 21, 40, 44.3, 60

local function has_toast(hud, text)
    for _, toast in ipairs(hud._toasts) do
        if toast.text == text then
            return true
        end
    end
    return false
end

local function draw_night(w, ui, time)
    require("ui.NightLayoutView").draw(w, ui.input, time, { attacks = ui.attacks, motion = ui.motion })
    ui.hud:draw(w, time)
    ui.fx:draw()
    ui.hud:draw_overlay(false)
    require("ui.Tooltip").draw_hovered(w, ui.input)
end

-- 60일차 밤을 열고 최종 보스가 나올 때까지
local function summon(w, ui, K)
    w.day, w.gold, w.max_hp, w.hp = 60, 100000, 100000, 100000
    K.check(w:start_night(), "the final night should start")
    local boss = nil
    ui.step(14, function()
        boss = require("ui.MasterBossView").alive(w.combat)
        return boss ~= nil
    end)
    K.check(boss ~= nil and boss.type_id == "boss_master", "boss_master appears on night 60")
    K.check(ui.motion.banner ~= nil and ui.motion.banner.kind == "arrival", "the arrival banner is recorded")
    return boss
end

-- ② 밤 진열장: 공명선 · 결계선 · 룬 사슬
local function night_grid(w, ui, shots, K, boss)
    local Slots, SLOT = require("ui.Slots"), K.SLOT
    Slots.set_mode_provider(function() return "night" end)
    local x, y, cw, ch = Slots.rect("grid", SLOT.fire)
    local before = K.grid_only(w, ui, T_NIGHT)
    w.combat:lock_cells(ROW5, 2.4)
    local lx, ly = Slots.center("grid", SLOT.lightning)
    ui.input.pointer.x, ui.input.pointer.y = lx + 6, ly + 4
    boss.x, boss.flash = 1000, 0
    ui.motion:banner_at(T_NIGHT - 1.0)                       -- 배너가 펼쳐진 지 1초 된 순간
    K.render("smoke_trace_grid_night.png", shots, function() draw_night(w, ui, T_NIGHT) end)
    local after = K.grid_only(w, ui, T_NIGHT)                -- 픽셀 검사는 진열장만 (투사체·공격 연출 없이)
    K.check(K.any_pixel(after, x + cw + 1.5, y + ch + 1.5, 2, function(r, g, b) return b > 0.5 and b >= r and b >= g end),
        "4/4 lit sockets send silver-blue resonance lines to the centre")
    local bx, by, bw = Slots.rect("grid", SLOT.lightning)
    K.check(K.any_pixel(after, bx + bw / 2, by - 6, 2, function(r, _, b) return b > 0.55 and b > r + 0.15 end),
        "a lit lightning socket glows blue around its cell")
    local cx, cy, cell = Slots.rect("grid", 22)
    K.check(K.brightness(after, cx, cy, cell, cell) < K.brightness(before, cx, cy, cell, cell) * 0.85,
        "a chained row is darkened under rune chains")
    w.combat:lock_cells({ 3, 8, 13, 18, 23 }, require("data.enemies").boss_patterns.master.lock_time - 0.12)   -- 막 묶인 열 (슬램)
    K.grid_only(w, ui, T_NIGHT)
    w.combat.chains[21], w.combat.chains[22] = nil, 0.3      -- 줄이 끊긴 칸 사슬 · 풀리기 직전(옅어짐)
    K.grid_only(w, ui, T_NIGHT)
    w.combat.chains = {}
end

-- 아이기스 돔 테 · 레인 아래 체력 띠 픽셀
local function check_aegis_pixels(data, boss, K)
    local LAYOUT, LaneView = require("data.layout"), require("ui.LaneView")
    local bar = require("ui.MasterBossHud").bar_rect(LAYOUT.night.lane)
    K.check(K.any_pixel(data, bar.x + 8, bar.y + bar.h - 3, 2, function(r, g, b) return b > 0.5 and r > g and b > g + 0.15 end),
        "the final boss HP bar is drawn at the bottom of the lane")
    local _, art = require("ui.SpriteCatalog").monster_image(boss)
    local r = boss.radius * LAYOUT.night.sprite_scale
    local rx = r * LaneView.SPRITE_SCALE * (art and art.scale or 1) * 0.5 * 0.98
    K.check(K.any_pixel(data, boss.x - rx, boss.y - r * 0.25, 3, function(_, g, b) return b > 0.5 and b > g + 0.12 end),
        "the Rift Aegis dome rim surrounds the boss")
end

local function check_tooltip(boss, K, statuses_needed)
    local MonsterTooltip = require("ui.MonsterTooltip")
    K.check(MonsterTooltip.tier(boss) == "final", "the final boss has its own tooltip tier")
    local statuses, traits = MonsterTooltip.statuses(boss), MonsterTooltip.traits(boss)
    K.check(#statuses >= statuses_needed, "the tooltip lists the boss state")
    K.no_holes(statuses, "final boss statuses")
    K.no_holes(traits, "final boss traits")
    K.check(traits[#traits]:find(tostring(require("data.enemies").boss_patterns.master.reduction * 100), 1, true) ~= nil,
        "the lockdown gimmick line shows the aegis reduction")
    return statuses
end

-- ③ 봉쇄 → 아이기스 → 파훼 · 그로기 → 결말
local function boss_flow(w, ui, shots, K, boss)
    local combat = w.combat
    local EventBus = require("core.EventBus")
    local probe = {}
    EventBus.subscribe("boss:lockdown", function(p) probe.lock = p end, { owner = probe, priority = -300 })
    K.check(ui.step(7, function()
        boss.hp = boss.max_hp                                 -- 보스를 살려 둔다
        return probe.lock ~= nil
    end), "the shade locks a showcase line")
    EventBus.unsubscribe_owner(probe)
    local lock = probe.lock
    local line = K.t(lock.axis == "row" and "trace.boss.row" or "trace.boss.col", { n = lock.line })
    K.check(has_toast(ui.hud, K.t("trace.boss.lockdown", { line = line })), "the lockdown raises a toast naming the line")
    boss.hp = boss.max_hp * 0.6
    ui.step(0.05)
    K.check(boss.aegis ~= nil and has_toast(ui.hud, K.t("trace.boss.aegis_hint")), "the aegis rises with its hint toast")
    combat:set_overclock(true)
    for _ = 1, 6 do
        combat:damage_monster(boss, boss.aegis.need / 10, nil, true, "fire")
    end
    combat:set_overclock(false)
    local share = boss.aegis.dealt / boss.aegis.need
    K.check(share > 0.3 and share < 0.8, "overclock hits fill the break gauge")
    combat.monsters = { boss }                                -- 보스 화면: 다른 몬스터는 치운다 (픽셀 검사가 가리지 않게)
    boss.x, boss.flash = 1010, 0
    ui.input.pointer.x, ui.input.pointer.y = boss.x, boss.y - 20
    local statuses = check_tooltip(boss, K, 1)
    K.check(statuses[#statuses][1]:find(tostring(math.floor(share * 100)), 1, true) ~= nil, "the aegis line shows the break progress")
    K.render("smoke_trace_boss.png", shots, function() draw_night(w, ui, T_BOSS) end)
    check_aegis_pixels(K.render(nil, false, function() require("ui.LaneView").draw(w, T_BOSS, ui.motion) end), boss, K)   -- 레인만
    combat:set_overclock(true)
    for _ = 1, 40 do
        if boss.aegis == nil then
            break
        end
        combat:damage_monster(boss, boss.aegis.need / 10, nil, true, "fire")
    end
    K.check(boss.aegis == nil and boss.groggy_time > 0 and has_toast(ui.hud, K.t("trace.boss.aegis_broken")),
        "overclock shatters the aegis into a stagger")
    check_tooltip(boss, K, 1)
    ui.fx:update(2)                                           -- 떠오르는 글자가 사라진 뒤의 그로기 (별 · 호박색 남은 시간)
    boss.flash = 0
    ui.input.pointer.x, ui.input.pointer.y = 700, 640         -- 툴팁이 머리 위 별을 가리지 않게
    K.render("smoke_trace_boss_groggy.png", shots, function() draw_night(w, ui, T_GROGGY) end)
    boss.hp_floor = nil                                       -- 30% 관문(다음 아이기스)을 건너뛰고 바로 처치
    combat:damage_monster(boss, boss.hp * 10 + 100000, nil, true, "fire")
    local final = w.master_trace.final
    K.check(boss.dead and final ~= nil and final.slain and final.lit == 4, "slaying the shade with 4/4 lit seals is recorded")
    K.check(ui.motion.banner.kind == "verdict" and ui.motion.banner.lit == 4, "the verdict banner is recorded")
    K.check(require("ui.MasterBossView").alive(combat) == nil, "no final boss bar after the kill")
    ui.step(0.1)
    ui.fx:update(1.2)
    ui.motion:banner_at(T_END - 1.2)
    K.render("smoke_trace_boss_end.png", shots, function() draw_night(w, ui, T_END) end)
end

-- 밤 진열장 · 최종 보스 화면 (낮 검사 뒤의 같은 공방). 반환: 로그용 보스 이름
function SmokeTraceBattleBoss.run(w, ui, shots, K)
    local SLOT = K.SLOT
    w.gold = w.gold + 10000                                   -- 진열장 5x5 개방 (공방 개조 경로) → 맨 아래 줄에도 무기
    while w.upgrades:next_level("grid") ~= nil do
        K.check(w.upgrades:buy("grid"), "grid expansion purchase")
    end
    K.ready(w, "midas_gauntlet", 10, SLOT.gold)
    K.ready(w, "frost_crossbow", 3, 12)
    K.ready(w, "inferno_musket", 4, 14)
    K.ready(w, "lightning_orb", 2, 22)
    K.ready(w, "flame_sword", 1, 24)
    K.check(w.master_trace:is_complete(), "precondition: all four sockets lit")
    local gold = w.inventory:get("grid", SLOT.gold)
    local lines = require("ui.Tooltip").lines(gold, w:grid_stats().stats[gold], w)
    K.check(lines[#lines].text == K.t("trace.resonance.immortal"), "a +10 relic in a socket notes its wear immunity")
    K.no_holes(lines, "gold socket tooltip")
    local boss = summon(w, ui, K)
    night_grid(w, ui, shots, K, boss)
    boss_flow(w, ui, shots, K, boss)
    return boss.type_id
end

return SmokeTraceBattleBoss

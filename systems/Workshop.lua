-- systems/Workshop.lua
-- 공방 세션 상태(난이도·일차·골드·연마석·내구도·페이즈)와 공용 규칙(칸 봉인·배치·밤 시작).
-- 하위 시스템을 소유하는 파사드. 골드·연마석·내구도·판매가는 systems/WorkshopEconomy 믹스인,
-- 달력·계절 기준 규칙(과열 확률·손님 규칙·웨이브 실효 일차·밤 수정자)은 systems/WorkshopCalendar 믹스인,
-- 낮/밤/상점 전환 흐름은 systems/DayCycle.lua. 그리기 금지.
-- phase: "day" | "night" | "shop"(상납 성공 직후 길드 보급 상점)

local Class = require("lib.classic")
local Text = require("lib.text")
local EventBus = require("core.EventBus")
local I18n = require("systems.I18n")
local Grid = require("systems.Grid")
local Inventory = require("systems.Inventory")
local ItemEffects = require("systems.ItemEffects")
local Appraisal = require("systems.Appraisal")
local Forge = require("systems.Forge")
local Combat = require("systems.Combat")
local Tribute = require("systems.Tribute")
local Tutorial = require("systems.Tutorial")
local ItemFactory = require("systems.ItemFactory")
local Achievements = require("systems.Achievements")
local Supplies = require("systems.Supplies")
local WorkshopUpgrades = require("systems.WorkshopUpgrades")
local GuildShop = require("systems.GuildShop")
local BlackMarket = require("systems.BlackMarket")
local GuildQuests = require("systems.GuildQuests")
local WorkshopEconomy = require("systems.WorkshopEconomy")
local WorkshopCalendar = require("systems.WorkshopCalendar")
local Drops = require("systems.Drops")
local DayCycle = require("systems.DayCycle")
local MasterTrace = require("systems.MasterTrace")
local HeroEquip = require("systems.HeroEquip")
local HERO = require("data.hero")
local BALANCE = require("data.balance")
local COMBAT = require("data.combat")
local WAVES = require("data.waves")
local DIFFICULTIES = require("data.difficulties")

local Workshop = Class:extend()
WorkshopEconomy.install(Workshop)
WorkshopCalendar.install(Workshop)
HeroEquip.install(Workshop)         -- 주인공 장비창 · 3분류 배치 규칙 · 자동 배치 · 빠른 교체

-- 그리드 스탯 캐시를 무효화하는 이벤트 (언어가 바뀌면 캐시된 보너스 문구도 다시 만든다)
local INVALIDATING_EVENTS = {
    "inventory:changed", "appraisal:cleaned", "forge:resolved", "combat:item_worn_out", "upgrades:purchased",
    "i18n:language_changed",
}

local function merged(base, override)
    local result = {}
    for key, value in pairs(base) do
        result[key] = value
    end
    for key, value in pairs(override or {}) do
        result[key] = value
    end
    return result
end

-- options: { difficulty, tutorial = bool, name = 플레이어 이름, meta = MetaProgression.bonuses() 결과,
--            starter = true 면 data/balance.lua 의 시작 지급 유물을 진열장에 둔다 }
function Workshop:new(options)
    options = options or {}
    local settings = BALANCE.workshop
    self.owner_name = options.name or I18n.t("story.default_name")
    self.difficulty_id = options.difficulty or DIFFICULTIES.default
    self.rules = DIFFICULTIES.modes[self.difficulty_id]
    assert(self.rules ~= nil, "Workshop: unknown difficulty '" .. tostring(self.difficulty_id) .. "'")
    self.meta = options.meta or {}
    self.unlocked_relics = {}       -- 해금된 특수 유물 (업적, systems/Achievements 가 런 도중에도 더한다)
    for id in pairs(self.meta.relics or {}) do
        self.unlocked_relics[id] = true
    end
    self.overclock_rules = merged(COMBAT.overclock, self.rules.overclock)
    self.boss_rules = merged(WAVES.boss, self.rules.boss)              -- 월말 대보스 (난이도 boss 가 덮어쓴다)
    self.midboss_rules = merged(WAVES.midboss, self.rules.midboss)     -- 월 중순 중간 보스

    self.day = 1
    self.max_days = self.rules.days
    self.gold = self.rules.start_gold + self:meta_value("start_gold")
    self.tempering_stones = BALANCE.stones.start
    self.max_hp = self.rules.max_hp + self:meta_value("max_hp")
    self.hp = self.max_hp
    self.phase = "day"
    self.customers_left = settings.customers_per_day
    self.summons_today = 0
    self.scrolls = 0
    self.result = nil   -- nil | "victory" | "defeat" | "bankrupt"
    self.stats = { gold_earned = 0, kills = 0, items_lost = 0, tributes_paid = 0, days_survived = 0 }

    self.inventory = Inventory({ storage = settings.storage_slots, grid = Grid.SIZE, bench = 1, furnace = 1, hero = #HERO.slots })
    for _, spec in ipairs(options.starter and settings.starter_items or {}) do
        self.inventory:place(ItemFactory.make_ready(spec.id, spec.grade, 0), "grid", spec.cell)
    end
    self.effects = ItemEffects(self)
    self.supplies = Supplies(self)
    self.upgrades = WorkshopUpgrades(self, self.meta.grid_stage or 1)
    self.appraisal = Appraisal(self)
    self.forge = Forge(self)
    self.combat = Combat(self)
    self.tribute = Tribute(self)
    self.shop = GuildShop(self)
    self.black_market = BlackMarket(self)
    self.quests = GuildQuests(self)
    self.drops = Drops(self)
    self.tutorial = options.tutorial and Tutorial(self) or nil
    self.achievements = Achievements(self)
    self.master_trace = self.rules.campaign == "master_trace" and MasterTrace(self) or nil     -- 진엔딩 캠페인 (스승의 흔적)
    self.final_rules = self.master_trace and self.master_trace:final_rules() or nil           -- 마지막 밤 최종 보스
    self._grid_stats = nil

    for _, event in ipairs(INVALIDATING_EVENTS) do
        EventBus.subscribe(event, function()
            self._grid_stats = nil
        end, { owner = self, priority = 50 })
    end
    EventBus.subscribe("combat:monster_killed", function()
        self.stats.kills = self.stats.kills + 1
    end, { owner = self, priority = -200 })
end

-- 연출 구독자가 준비된 뒤 호출: 1일차 시작 알림 (+ 튜토리얼 첫 손님)
function Workshop:begin()
    DayCycle.announce_first_day(self)
    if self.tutorial ~= nil then
        self.tutorial:start()
    end
end

function Workshop:destroy()
    if self.tutorial ~= nil then
        self.tutorial:destroy()
    end
    self.black_market:destroy()
    self.quests:destroy()
    self.achievements:destroy()
    self.drops:destroy()
    if self.master_trace ~= nil then
        self.master_trace:destroy()
    end
    self.effects:destroy()
    EventBus.unsubscribe_owner(self)
end

-- 영구 능력치 보너스 (없으면 0)
function Workshop:meta_value(key)
    return self.meta[key] or 0
end

-- 플레이어 호칭 ("모험왕 사장님" / "Boss 모험왕")
function Workshop:address()
    return I18n.t("story.address", { name = self.owner_name })
end

-- 문구 템플릿의 {name} / {address} 치환
function Workshop:personalize(template)
    return Text.fill(template, { name = self.owner_name, address = self:address() })
end

-- 튜토리얼이 잠근 행동인지 ("new_customer", "sell", "forge", "start_night")
function Workshop:allows(action)
    return self.tutorial == nil or self.tutorial:allows(action)
end

function Workshop:keeps_purchase_on_bench()
    return self.tutorial ~= nil and self.tutorial:keeps_purchase_on_bench()
end

function Workshop:grid_stats()
    if self._grid_stats == nil then
        self._grid_stats = Grid.compute_stats(self.inventory)
    end
    return self._grid_stats
end

function Workshop:is_day()
    return self.phase == "day" and self.result == nil
end

function Workshop:is_cell_open(index)
    return Grid.is_open(index, self.upgrades:grid_stage())
end

-- 낮에만, 결과 미정, 용광로 작업 중이 아닐 때 이동 가능. 손님 유물·봉인 칸은 불가.
-- 3분류 규칙(systems/HeroEquip): 방어구는 진열장에, 유물은 주인공에게 놓을 수 없다
function Workshop:move_item(from_area, from_index, to_area, to_index)
    if not self:is_day() then
        EventBus.emit("ui:message", { text = I18n.t("msg.no_move_at_night"), kind = "warn" })
        return false
    end
    local item = self.inventory:get(from_area, from_index)
    local target = self.inventory:get(to_area, to_index)
    if item == nil or not item.owned or (target ~= nil and not target.owned) then
        return false
    end
    if to_area == "grid" and not self:is_cell_open(to_index) then
        EventBus.emit("ui:message", { text = I18n.t("msg.cell_sealed"), kind = "warn" })
        return false
    end
    if self.forge:is_locked(item) or (target ~= nil and self.forge:is_locked(target)) then
        EventBus.emit("ui:message", { text = I18n.t("msg.furnace_busy"), kind = "warn" })
        return false
    end
    if not self:check_fit(item, target, from_area, from_index, to_area, to_index) then
        return false
    end
    return self.inventory:move(from_area, from_index, to_area, to_index)
end

function Workshop:can_start_night()
    return self:is_day() and self.forge.forging == nil and self:allows("start_night")
end

function Workshop:start_night()
    if not self:can_start_night() then
        return false
    end
    EventBus.emit("phase:night_starting", { workshop = self })   -- 저장용 스냅숏 (밤 도중 나가면 이 순간부터 다시)
    self.night_damage, self._dawn_claimed, self.curse_paid = 0, false, 0    -- curse_paid: 이번 밤 저주 대가 합계 (상한)
    -- 매입하지 않은 손님은 돌아간다
    if self.appraisal:has_customer() then
        local item = self.appraisal:bench_item()
        self.inventory:remove(item)
        EventBus.emit("appraisal:customer_left", { item = item })
    end
    self.phase = "night"
    self.quests:night_started()           -- 수락하지 않은 길드 의뢰·암시장 제안은 내려간다
    self.black_market:night_started()
    self.combat:start(self.day, self:night_modifiers(self.black_market:night_modifiers()))     -- 핏빛 달 + 계절
    EventBus.emit("phase:night_started", { workshop = self, day = self.day })
    return true
end

function Workshop:set_overclock(enabled)
    if self.phase == "night" and self.result == nil then
        self.combat:set_overclock(enabled)
    end
end

-- 길드 보급 상점에서 [다음 날 시작]
function Workshop:close_shop()
    if self.phase == "shop" and self.result == nil then
        DayCycle.start_next_day(self)
    end
end

-- 새벽 방벽 무피해 보너스 금액 (그 밤 방벽 피해가 있으면 0)
function Workshop:dawn_bonus()
    if (self.night_damage or 0) > 0 then
        return 0
    end
    return BALANCE.dawn.flawless_base + BALANCE.dawn.flawless_per_day * self.day
end

-- 한 밤에 한 번만 지급 (새벽 정산창 확인 · 화면이 없으면 DayCycle.finish_night). 지급한 금액 반환
function Workshop:claim_dawn_bonus()
    if self._dawn_claimed or self.phase ~= "night" then
        return 0
    end
    self._dawn_claimed = true
    local amount = self:dawn_bonus()
    if amount > 0 then
        self:add_gold(amount, "dawn_bonus")
    end
    return amount
end

-- 런 종료 정산용 요약 (seed · unlocked · rp 는 RunState 가 채운다)
function Workshop:summary(reason)
    local stats = self.stats
    return {
        reason = reason, day = self.day, gold = self.gold, kills = stats.kills, gold_earned = stats.gold_earned,
        items_lost = stats.items_lost, days_survived = stats.days_survived, tributes_paid = stats.tributes_paid,
        difficulty = self.difficulty_id, name = self.owner_name, unlocked = {},
    }
end

function Workshop:update(dt)
    self.forge:update(dt)
    if self.phase == "night" and self.result == nil then
        self.combat:update(dt)
        if self.result == nil and self.combat:is_finished() then
            DayCycle.finish_night(self)
        end
    end
end

return Workshop

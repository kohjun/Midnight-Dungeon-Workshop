-- entities/Item.lua
-- 유물 인스턴스: 감정 상태, 오염도, 강화 단계(+0 ~ +10), 내구도(0 ~ 100%)와 파생 스탯·가격 계산.
-- 이름·설명 문구는 여기 두지 않는다 — proto_id 로 systems/I18n (I18n.item_name) 에서 조회한다.
-- 원형 수치는 data/items.lua (방어구는 data/armors.lua), 강화 배율은 data/forge.lua, 내구도 규칙은 data/durability.lua,
-- 그 밖의 배율은 data/balance.lua.
-- 3분류 category: "weapon"(진열장 + 주인공 무기 슬롯) · "armor"(주인공 전용, equip_slot = helmet | chest | boots) ·
--   "relic"(진열장 전용 — 증폭기는 subtype = "amplifier"). role() = 세부 구분 (weapon | amplifier | relic | armor).

local Class = require("lib.classic")
local ITEMS = require("data.items")
local ARMORS = require("data.armors")
local BALANCE = require("data.balance")
local FORGE = require("data.forge")
local DURABILITY = require("data.durability")

local Item = Class:extend()

local _next_uid = 0

-- 원형 표 (유물·무기 = data/items.lua, 방어구 = data/armors.lua). 없으면 nil
function Item.prototype(proto_id)
    return ITEMS.prototypes[proto_id] or ARMORS.prototypes[proto_id]
end

-- 저장된 런을 복원할 때(systems/RunSave): 새로 만드는 유물 번호가 복원한 유물 번호와 겹치지 않게
function Item.reserve_uid(uid)
    _next_uid = math.max(_next_uid, uid)
end

-- spec: { grade, claimed_grade, flaw, flaw_mark = {x, y}, contamination, grime = { {x, y, r}, ... } }
-- flaw_mark·grime 좌표는 유물 크기 1 기준 정규화 좌표 (-0.5 ~ 0.5)
function Item:new(proto_id, spec)
    local proto = Item.prototype(proto_id)
    assert(proto ~= nil, "Item: unknown prototype '" .. tostring(proto_id) .. "'")
    spec = spec or {}
    _next_uid = _next_uid + 1

    self.uid = _next_uid
    self.proto_id = proto_id
    self.proto = proto
    self.category = proto.category
    self.subtype = proto.subtype
    self.equip_slot = proto.equip_slot or (proto.category == "weapon" and "weapon" or nil)     -- 주인공 장비창 칸 (유물은 nil)
    self.element = proto.element

    self.grade = spec.grade or "common"
    self.claimed_grade = spec.claimed_grade or self.grade
    self.flaw = spec.flaw or proto.innate_flaw   -- 원형 고유 결함(저주받은 단검 등)은 항상 적용
    self.flaw_mark = spec.flaw_mark or { x = 0, y = 0 }
    self.contamination = spec.contamination or 0
    self.cleaned = self.contamination <= 0
    self.grime = spec.grime or {}
    self.adventurer = spec.adventurer             -- 가져온 모험가 id (data/adventurers.lua, 없으면 nil)
    self.ask_mult = spec.ask_mult or 1            -- 모험가의 흥정 성향 (제시가 배율)

    self.level = 0
    self.owned = false
    self.revealed = { grade = false, flaw = false, complete = false }
    self.scan_points = {}

    self.max_durability = DURABILITY.max              -- 0 ~ 100% (밤 전투 마모, 강화 성공으로만 100% 복구)
    self.durability = DURABILITY.max
    -- 감정 시점의 등급 배율 (강화는 data/forge.lua 의 power 배율을 따로 곱한다)
    self._grade_mult = ITEMS.grades[self.grade].mult
end

function Item:grade_info()
    return ITEMS.grades[self.grade]
end

function Item:claimed_grade_info()
    return ITEMS.grades[self.claimed_grade]
end

function Item:element_info()
    return ITEMS.elements[self.element]
end

function Item:flaw_info()
    return self.flaw and ITEMS.flaws[self.flaw] or nil
end

function Item:is_weapon()
    return self.category == "weapon"
end

function Item:is_armor()
    return self.category == "armor"
end

-- 세부 구분: "weapon" | "amplifier" | "relic" | "armor"
function Item:role()
    return self.subtype or self.category
end

-- 방어구 스탯 배율: 등급 · 세척 · 강화 배율의 stat_share 몫 (저주 결함은 x curse.stat_mult)
function Item:gear_mult()
    local mult = 1 + (self:power_mult() - 1) * ARMORS.stat_share
    return self.flaw == "curse" and mult * ARMORS.curse.stat_mult or mult
end

-- 방어구가 주는 스탯 { crit = …, defense = … } (배율 적용, 0% 완전 마모면 빈 표). 방어구가 아니면 nil
function Item:gear_stats()
    if not self:is_armor() then
        return nil
    end
    local stats = {}
    if not self:is_worn_out() then
        local mult = self:gear_mult()
        for key, value in pairs(self.proto.stats) do
            stats[key] = value * mult
        end
    end
    return stats
end

-- 강화 배율 (+0 = 1, +10 = x4.8) — 화력·판매가·증폭기 시너지에 곱한다
function Item:forge_power()
    return FORGE.power[self.level] or 1
end

-- 등급 × 세척
function Item:quality_mult()
    local clean = self.cleaned and (self.clean_mult or BALANCE.appraisal.clean_mult) or 1
    return self._grade_mult * clean
end

-- 등급 × 세척 × 강화 배율
function Item:power_mult()
    return self:quality_mult() * self:forge_power()
end

-- 판매가에 반영되는 강화 배율: 강화 몫의 FORGE.sale_share 만 (되팔기용 강화로 이득을 보지 않게)
function Item:sale_forge_mult()
    return 1 + (self:forge_power() - 1) * FORGE.sale_share
end

-- ── 내구도 (data/durability.lua) ─────────────────────────────
-- +10 '불멸 각인': 내구도 100% 고정 · 마모 면역
function Item:is_immortal()
    return self.level >= DURABILITY.immortal_level
end

-- 0% 완전 마모 = 작동 정지 (공격·증폭·시너지·일일 수익 없음)
function Item:is_worn_out()
    return not self:is_immortal() and self.durability <= 0
end

-- "immortal" | "broken"(0%) | "low"(마모 위험, warn_below 이하) | "mid" | "ok"
function Item:durability_state()
    if self:is_immortal() then
        return "immortal"
    elseif self.durability <= 0 then
        return "broken"
    elseif self.durability <= DURABILITY.warn_below then
        return "low"
    elseif self.durability < DURABILITY.mid_below then
        return "mid"
    end
    return "ok"
end

-- 마모 속도 배율 (균열 결함은 빨리 닳는다)
function Item:wear_mult()
    local flaw = self:flaw_info()
    local mult = flaw and flaw.wear_mult or 1
    return self:is_armor() and self.flaw == "curse" and mult * ARMORS.curse.wear_mult or mult
end

-- 강화 성공: 100% 로 되돌린다
function Item:restore_durability()
    self.durability = self.max_durability
end

-- 저주 결함은 자신의 화력을 올린다 (인접 디버프는 ItemEffects 의 adjacent_curse)
function Item:attack()
    local flaw = self:flaw_info()
    local cursed = flaw and flaw.self_attack_mult or 1
    return (self.proto.attack or 0) * self:power_mult() * cursed
end

-- 초당 발사 수
function Item:fire_rate()
    return self.proto.fire_rate or 0
end

function Item:flaw_value_mult()
    local flaw = self:flaw_info()
    return flaw and flaw.value_mult or 1
end

-- 즉시 판매가 (세척·강화 반영 — 강화는 sale_forge_mult 만큼)
function Item:sale_value()
    return math.max(1, math.floor(self.proto.value * self:quality_mult() * self:sale_forge_mult() * self:flaw_value_mult() + 0.5))
end

-- 기본 판매가 기반 일일 수익 (세척·강화 미반영, 시너지 배율은 Grid 가 곱한다)
function Item:base_income()
    local base = self.proto.value * self._grade_mult * self:flaw_value_mult()
    return math.floor(base * BALANCE.economy.daily_income_ratio + 0.5)
end

-- 손님이 처음 부른 값 (감정으로 드러난 사실을 반영하기 전): 주장 등급 기준 × 흥정 배율
function Item:list_price()
    local price = self.proto.value * ITEMS.grades[self.claimed_grade].mult * BALANCE.customer.ask_ratio * self.ask_mult
    return math.max(1, math.floor(price + 0.5))
end

-- 스캔으로 드러난 진짜 등급이 손님이 말한 등급보다 낮은가 (등급 위조 적발)
function Item:is_forgery_revealed()
    return self.revealed.grade and ITEMS.grades[self.grade].rank < ITEMS.grades[self.claimed_grade].rank
end

-- 손님 제시가: 주장 등급 기준. 스캔으로 더 낮은 진짜 등급이 드러나면 그 등급으로 + 위조 적발 할인, 결함 발견 시 할인
function Item:asking_price()
    local grades = ITEMS.grades
    local basis = self.claimed_grade
    if self.revealed.grade and grades[self.grade].rank < grades[basis].rank then
        basis = self.grade
    end
    local price = self.proto.value * grades[basis].mult * BALANCE.customer.ask_ratio * self.ask_mult
    if self:is_forgery_revealed() then
        price = price * BALANCE.customer.forgery_discount
    end
    if self.flaw ~= nil and self.revealed.flaw then
        price = price * BALANCE.customer.flaw_discount
    end
    return math.max(1, math.floor(price + 0.5))
end

function Item:can_forge()
    return self.level < FORGE.max_level
end

-- 다음 단계 강화표 (data/forge.lua 의 levels[다음 단계], +10 이면 nil)
function Item:next_forge()
    return FORGE.levels[self.level + 1]
end

function Item:forge_chance()
    local spec = self:next_forge()
    return spec and spec.chance or 0
end

-- 원형 효과 + 결함 효과 (ItemEffects 가 그리드 배치 중에 구독한다)
function Item:effects()
    local list = {}
    for _, effect in ipairs(self.proto.effects or {}) do
        list[#list + 1] = effect
    end
    local flaw = self:flaw_info()
    if flaw ~= nil then
        for _, effect in ipairs(flaw.effects or {}) do
            list[#list + 1] = effect
        end
    end
    return list
end

function Item:__tostring()
    return string.format("Item(%s #%d)", self.proto_id, self.uid)
end

return Item

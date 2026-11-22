-- systems/effects/LightningEffects.lua
-- 번개/과속 아키타입: 누적 발사 낙뢰, 감전·경직(제어), 과부하 과열 확률 감소.

local EventBus = require("core.EventBus")

local LightningEffects = {}

-- 폭풍 피뢰침: 진열장 무기 전체 발사가 every 회 쌓일 때마다 모든 적에게 낙뢰 (밤마다 초기화)
function LightningEffects.thunder_every(item, effect)
    local shots = 0
    return {
        {
            event = "phase:night_started",
            fn = function()
                shots = 0
            end,
        },
        {
            event = "combat:fired",
            priority = -10,
            fn = function(payload)
                shots = shots + 1
                if shots >= effect.every and payload.combat ~= nil then
                    shots = 0
                    payload.combat:strike_all(effect.damage * item:power_mult(), item)
                end
            end,
        },
    }
end

-- 감전 + 경직: 적중한 적(연쇄 번개로 맞은 적 포함)에게 감전(받는 피해 증가, DamageRules)과 짧은 둔화
function LightningEffects.shock(item, effect)
    return { {
        event = "combat:hit",
        priority = -2,
        fn = function(payload)
            if payload.item == item then
                local fresh = not payload.monster:is_shocked()
                payload.monster:apply_shock(effect.duration)
                if fresh then           -- 새로 감전됐을 때만 ("감전!" 글자 — ui/Feedback)
                    EventBus.emit("combat:shocked", { monster = payload.monster, x = payload.monster.x, y = payload.monster.y })
                end
                payload.monster:apply_slow(effect.slow, effect.slow_time)
            end
        end,
    } }
end

-- 냉각 핀 · 균열 프리즘: 과부하 마모 가속분(extra = 과부하 마모 배율 - 1)에 mult 를 곱한다 (systems/Wear)
function LightningEffects.overheat_guard(_, effect)
    return { {
        event = "combat:wear_check",
        priority = 10,
        fn = function(payload)
            payload.extra = payload.extra * effect.mult
        end,
    } }
end

return LightningEffects

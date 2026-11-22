-- ui/HitStop.lua
-- 히트스톱: 번개 피해·치명타가 명중하면 전투 레이어(몬스터·투사체·공격 연출)만 아주 잠깐 멈추고 화면을 살짝 떤다.
-- RunState 가 매 프레임 consume(dt) 로 이번 프레임에서 멈출 실제 시간을 받아 전투 시뮬레이션 시간에서 뺀다
-- (화면 전환·HUD·모달·커서는 멈추지 않는다). 재발동 쿨타임(실제 시간)으로 다중 번개 빌드·3배속에서도 끊기지 않는다.
-- 수치는 data/attacks.lua 의 hitstop. 규칙에는 영향이 없다 (헤드리스 밸런스 시뮬레이션에는 없다).

local Class = require("lib.classic")
local EventBus = require("core.EventBus")
local ATTACKS = require("data.attacks")

local HitStop = Class:extend()

local DATA = ATTACKS.hitstop
local PRIORITY = -100

-- fx: ui/Effects (미세한 화면 진동)
function HitStop:new(fx)
    self._fx = fx
    self._freeze = 0
    self._cooldown = 0
    self.triggered = 0          -- 발동 횟수 (스모크 테스트용)
    self.total_frozen = 0       -- 지금까지 멈춘 실제 시간 합 (배속 측정 보정용)
    EventBus.subscribe("combat:damage_dealt", function(p)
        if p.crit then
            self:trigger(DATA.crit)
        elseif p.damage_type == "lightning" then
            self:trigger(DATA.lightning)
        end
    end, { owner = self, priority = PRIORITY })
end

function HitStop:destroy()
    EventBus.unsubscribe_owner(self)
end

-- 쿨타임 중이면 false (무시)
function HitStop:trigger(duration)
    if self._cooldown > 0 then
        return false
    end
    self._freeze = math.max(self._freeze, duration)
    self._cooldown = DATA.cooldown
    self.triggered = self.triggered + 1
    if self._fx ~= nil then
        self._fx:shake(DATA.shake)
    end
    return true
end

function HitStop:is_frozen()
    return self._freeze > 0
end

-- 이번 프레임(dt 실제 초)에서 전투를 멈출 시간
function HitStop:consume(dt)
    self._cooldown = math.max(0, self._cooldown - dt)
    if self._freeze <= 0 then
        return 0
    end
    local frozen = math.min(self._freeze, dt)
    self._freeze = self._freeze - frozen
    self.total_frozen = self.total_frozen + frozen
    return frozen
end

return HitStop

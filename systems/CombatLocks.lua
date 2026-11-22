-- systems/CombatLocks.lua
-- Combat 믹스인: 밤 동안 진열장 칸 봉인 — 그 칸의 무기는 사격하지 않는다 (Combat._update_weapons 가 is_locked 로 묻는다).
--   webs   : 문지기 골렘의 거미줄 (칸 → 남은 클릭 수). 플레이어가 그 칸을 클릭해 걷어 낸다 (hit_web)
--   chains : 최종 보스(균열의 잔영)의 공방 봉쇄 룬 사슬 (칸 → 남은 초). 시간이 지나면 풀린다 (update_locks)
-- 새벽(Combat:end_night)과 밤 시작(Combat:start)에 둘 다 비운다. 그리기 금지 (ui/GridView 가 webs · chains 를 읽는다).

local EventBus = require("core.EventBus")
local Grid = require("systems.Grid")

local CombatLocks = {}

local METHODS = {}

function METHODS:is_locked(index)
    return self.webs[index] ~= nil or self.chains[index] ~= nil
end

-- 룬 사슬: cells 칸들을 time 초 동안 봉인 (이미 묶인 칸은 더 긴 쪽)
function METHODS:lock_cells(cells, time)
    for _, index in ipairs(cells) do
        self.chains[index] = math.max(self.chains[index] or 0, time)
    end
end

-- 사슬 시간을 줄이고, 풀린 칸들을 한 번에 알린다 (칸 번호 순서 — 연출 순서도 결정론적)
function METHODS:update_locks(dt)
    local freed = nil
    for index = 1, Grid.SIZE do
        local left = self.chains[index]
        if left ~= nil then
            left = left - dt
            if left <= 0 then
                self.chains[index] = nil
                freed = freed or {}
                freed[#freed + 1] = index
            else
                self.chains[index] = left
            end
        end
    end
    if freed ~= nil then
        EventBus.emit("boss:lockdown_ended", { cells = freed })
    end
end

-- 거미줄 칸 클릭: 남은 클릭 수를 줄이고 0 이면 해제. 거미줄이 있던 칸이면 true
function METHODS:hit_web(index)
    local left = self.webs[index]
    if left == nil then
        return false
    end
    left = left - 1
    local x, y = Grid.cell_center(index)
    if left <= 0 then
        self.webs[index] = nil
        EventBus.emit("boss:web_cleared", { index = index, x = x, y = y })
    else
        self.webs[index] = left
        EventBus.emit("boss:web_struck", { index = index, left = left, x = x, y = y })
    end
    return true
end

function CombatLocks.install(class)
    for name, method in pairs(METHODS) do
        class[name] = method
    end
end

return CombatLocks

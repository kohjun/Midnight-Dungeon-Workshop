-- core/EventBus.lua
-- 싱글톤 Pub/Sub. 유물·스킬·패시브 시너지는 반드시 이 버스를 통해 연결한다.
--
--   local token = EventBus.subscribe("combat:before_damage", function(payload, event)
--       payload.amount = payload.amount * 2
--   end, { priority = 10, owner = relic })
--   local result = EventBus.emit("combat:before_damage", { amount = 5 })  -- 수정된 payload 반환
--   EventBus.unsubscribe(token)          -- 또는 EventBus.unsubscribe_owner(relic)
--
-- 실행 순서: priority 내림차순 → 같은 priority 는 구독 순서.
-- 구독 목록은 copy-on-write 라서 emit 도중 구독/해제해도 안전하다 (새 구독은 다음 emit 부터 호출).

local EventBus = {}

local _listeners = {}   -- event -> 정렬된 구독 토큰 배열 (변경 시 새 배열로 교체)
local _sequence = 0

local function compare_tokens(a, b)
    if a.priority ~= b.priority then
        return a.priority > b.priority
    end
    return a.sequence < b.sequence
end

-- predicate 가 true 인 구독을 제거하고 제거 개수를 반환
local function remove_where(event, predicate)
    local old = _listeners[event]
    if old == nil then
        return 0
    end
    local kept, removed = {}, 0
    for i = 1, #old do
        local token = old[i]
        if predicate(token) then
            token.active = false
            removed = removed + 1
        else
            kept[#kept + 1] = token
        end
    end
    if removed > 0 then
        _listeners[event] = (#kept > 0) and kept or nil
    end
    return removed
end

-- options: { priority = number (기본 0), once = boolean, owner = any }
function EventBus.subscribe(event, handler, options)
    assert(type(event) == "string" and event ~= "", "EventBus.subscribe: event must be a non-empty string")
    assert(type(handler) == "function", "EventBus.subscribe: handler must be a function")
    options = options or {}

    _sequence = _sequence + 1
    local token = {
        event = event,
        handler = handler,
        priority = options.priority or 0,
        once = options.once == true,
        owner = options.owner,
        sequence = _sequence,
        active = true,
    }

    local old = _listeners[event] or {}
    local list = {}
    for i = 1, #old do
        list[i] = old[i]
    end
    list[#list + 1] = token
    table.sort(list, compare_tokens)
    _listeners[event] = list
    return token
end

function EventBus.unsubscribe(token)
    if token == nil or not token.active then
        return false
    end
    return remove_where(token.event, function(candidate)
        return candidate == token
    end) > 0
end

-- owner 로 등록된 모든 구독 해제 (유물 제거, 상태 exit 시)
function EventBus.unsubscribe_owner(owner)
    assert(owner ~= nil, "EventBus.unsubscribe_owner: owner must not be nil")
    local removed = 0
    for event in pairs(_listeners) do
        removed = removed + remove_where(event, function(candidate)
            return candidate.owner == owner
        end)
    end
    return removed
end

-- 핸들러들이 수정한 payload 를 그대로 반환한다.
function EventBus.emit(event, payload)
    local list = _listeners[event]
    if list == nil then
        return payload
    end
    for i = 1, #list do
        local token = list[i]
        if token.active then
            if token.once then
                EventBus.unsubscribe(token)
            end
            token.handler(payload, event)
        end
    end
    return payload
end

-- event 생략 시 전체 구독 수
function EventBus.count(event)
    if event ~= nil then
        local list = _listeners[event]
        return list and #list or 0
    end
    local total = 0
    for _, list in pairs(_listeners) do
        total = total + #list
    end
    return total
end

-- event 생략 시 전체 해제
function EventBus.clear(event)
    for name, list in pairs(_listeners) do
        if event == nil or name == event then
            for i = 1, #list do
                list[i].active = false
            end
            _listeners[name] = nil
        end
    end
end

return EventBus

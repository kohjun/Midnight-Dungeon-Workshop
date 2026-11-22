-- ui/WorkshopCursor.lua
-- 공방 화면에서 지금 보여 줄 커스텀 커서 이름 (ui/WorkshopInput:cursor_name 이 부르고, RunState 가 ui/CursorManager 에 요청한다):
--   "grabbing"(유물을 끌고 있다) | "web_cut"(밤: 거미줄로 봉인된 진열 칸) | "hover"(누를 수 있는 버튼)
--   | "hidden"(세척 브러시를 작업대 위에 직접 그린다) | "appraise"(낮: 작업대 유물 영역 — 감정·세척)
--   | "grab"(낮: 집을 수 있는 보관함·진열장·용광로 유물) | "default"
-- 규칙 계산 없음: 입력·시스템 상태를 읽기만 한다.

local Slots = require("ui.Slots")
local CursorManager = require("ui.CursorManager")
local LAYOUT = require("data.layout")

local WorkshopCursor = {}

local function inside(rect, x, y)
    return x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h
end

function WorkshopCursor.name(input, w)
    if input.drag ~= nil then
        return "grabbing"
    end
    local x, y = input.pointer.x, input.pointer.y
    local area, index = Slots.at(x, y)
    if w.phase == "night" and area == "grid" and w.combat.webs[index] ~= nil then
        return "web_cut"
    end
    for _, button in ipairs(input.buttons) do         -- 그리기를 다른 뷰가 맡은(hidden) 버튼도 누를 수 있다
        if button:contains(x, y) then
            return button:is_enabled() and "hover" or "default"
        end
    end
    if not w:is_day() then
        return "default"
    end
    if input.tool == "brush" and inside(LAYOUT.day.workbench, x, y) then
        return "hidden"
    end
    local item = input:hovered_item()
    if area == "bench" and (input.tool == "uv" or item ~= nil) then
        return "appraise"
    end
    if item ~= nil and item.owned and not w.forge:is_locked(item) then
        return "grab"
    end
    return "default"
end

-- 공방 화면 커서 요청 (RunState 가 매 프레임): 모달이 덮고 있으면 공방 버튼의 호버 요청을 버리고 모달 버튼만 남긴다.
-- 공방 판정(우선순위 2)은 버튼 호버(1)보다 앞선다. "default" 는 요청하지 않는다
function WorkshopCursor.request(input, covered)
    if covered then
        CursorManager.clear()
        return
    end
    local name = input:cursor_name()
    if name ~= "default" then
        CursorManager.request(name, 2)
    end
end

return WorkshopCursor

-- ui/AdventurerPortrait.lua
-- 손님 카운터 오른쪽의 원형 모험가 초상 (좌표 LAYOUT.day.customer_card 의 guest_*). 규칙 계산 없음.
-- 원화 adventurer_<id>.png (ui/SpriteCatalog) 의 얼굴·어깨 영역(data/art.lua 의 adventurers.<id>.region)을 원 안에 그리고,
-- flip 으로 뒤집어 왼쪽 주인장 초상(ui/ShopkeeperPortrait)과 마주 보게 한다. ui/MeshDeformer 의 breathe_soft 메시로
-- 가볍게 숨 쉬고(data/animations.lua 의 adventurer), 손님이 바뀌면 오른쪽에서 살짝 밀려 들어오며 나타난다.
-- 원화가 없으면 모험가 뱃지 색 두건 실루엣으로 폴백한다. 테두리는 뱃지 색.

local Draw = require("ui.Draw")
local Icons = require("ui.Icons")
local MeshDeformer = require("ui.MeshDeformer")
local SpriteCatalog = require("ui.SpriteCatalog")
local ADVENTURERS = require("data.adventurers")
local ANIM = require("data.animations")
local UI = require("data.ui")

local AdventurerPortrait = {}

local C = UI.color
local LG = love.graphics
local ARRIVE_TIME = require("data.audio").voice.delay     -- 문 종소리가 끝날 무렵 자리 잡는다 (그때 대사·더빙 시작)
local ARRIVE_SLIDE = 14         -- 오른쪽에서 밀려 들어오는 거리(px)

local _keys = {}                -- id -> 메시 키 (모험가마다 따로)
local _arrival = { uid = nil, start = 0 }

local function mesh_key(id)
    local key = _keys[id]
    if key == nil then
        key = {}
        _keys[id] = key
    end
    return key
end

-- 0~1: 지금 손님 유물이 나타난 정도 (유물이 바뀌면 다시 0 부터)
local function arrival(item, time)
    if _arrival.uid ~= item.uid then
        _arrival.uid, _arrival.start = item.uid, time
    end
    local t = math.min(1, math.max(0, (time - _arrival.start) / ARRIVE_TIME))
    return 1 - (1 - t) ^ 3
end

-- 0~1: 지금 손님이 자리 잡은 정도 (ui/CustomerCard 는 1 에 가까워질 때 대사를 띄운다)
function AdventurerPortrait.arrived(item, time)
    return arrival(item, time)
end

-- 원화가 있으면 true (스모크 테스트용)
function AdventurerPortrait.has_art(id)
    return (SpriteCatalog.adventurer_image(id)) ~= nil
end

-- card: LAYOUT.day.customer_card, item: 손님 유물 (item.adventurer = 모험가 id), time: 초,
-- dx, rot: 적발 반응 포즈 (ui/GuestReaction — 움찔 떨림 px · 몸을 젖히는 기울기, 생략하면 0)
function AdventurerPortrait.draw(card, item, time, dx, rot)
    local id = item.adventurer
    local data = ADVENTURERS.list[id]
    local badge = data and data.badge or C.text_dim
    local shown = arrival(item, time)
    local r = card.guest_r
    local cx, cy = card.guest_x + (1 - shown) * ARRIVE_SLIDE, card.y + card.h / 2
    Draw.set_color({ 0.03, 0.02, 0.03 }, shown)
    LG.circle("fill", cx, cy, r, 28)
    local image, art = SpriteCatalog.adventurer_image(id)
    if image ~= nil then
        LG.stencil(function()
            LG.circle("fill", cx, cy, r - 1, 28)
        end, "replace", 1)
        LG.setStencilTest("greater", 0)
        LG.push()
        LG.translate(cx + (dx or 0), cy + r * 0.9)               -- 아래(어깨)를 축으로 젖히거나 들이민다
        LG.rotate(rot or 0)
        LG.translate(0, -r * 0.9)
        local size = r * 2 * (art.zoom or 1)
        LG.scale(art.flip and -size or size, size)
        LG.setColor(1, 1, 1, shown)
        MeshDeformer.draw(image, ANIM.adventurer, time + item.uid * 0.7, mesh_key(id), art.region)
        LG.pop()
        LG.setStencilTest()
    else
        Icons.draw("hooded", cx, cy + 2, r * 1.2, badge, 0.85 * shown)
    end
    Draw.set_color(badge, (0.55 + 0.2 * math.sin(time * 2)) * shown)
    LG.setLineWidth(2)
    LG.circle("line", cx, cy, r, 28)
end

return AdventurerPortrait

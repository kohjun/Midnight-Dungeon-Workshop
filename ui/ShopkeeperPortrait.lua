-- ui/ShopkeeperPortrait.lua
-- 손님 카운터 왼쪽의 원형 주인장 초상 (shopkeeper.png 의 얼굴 영역 data/art.lua 의 shopkeeper_face — 얼굴은 오른쪽을 본다).
-- 손님이 오면 오른쪽의 모험가 초상(ui/AdventurerPortrait)과 대사를 사이에 두고 마주 본다.
-- 주인장 얼굴은 ui/MeshDeformer 의 breathe 메시로 숨 쉬고, ui/AmbientEffects 의 반응 포즈(끄덕임·기울임·들썩임·움찔)를 받는다.
-- 그림이 없으면 망치 아이콘으로 폴백한다.

local Draw = require("ui.Draw")
local Icons = require("ui.Icons")
local SpriteBank = require("ui.SpriteBank")
local MeshDeformer = require("ui.MeshDeformer")
local ANIM = require("data.animations")
local ART = require("data.art")
local UI = require("data.ui")

local ShopkeeperPortrait = {}

local C = UI.color
local LG = love.graphics
local KEY = {}          -- 초상 메시 전용 키
local ZOOM = 1.12       -- 얼굴을 살짝 키워 원 가장자리가 비지 않게 (끄덕여도)

-- card: LAYOUT.day.customer_card, item: 작업대 유물(손님 유물이면 테두리가 맥동), ambient: ui/AmbientEffects (없으면 반응 없음)
function ShopkeeperPortrait.draw(card, item, time, ambient)
    local radius = card.portrait_r
    local cx, cy = card.portrait_x, card.y + card.h / 2
    Draw.set_color({ 0.03, 0.02, 0.03 })
    LG.circle("fill", cx, cy, radius, 28)
    local keeper = SpriteBank.image(ART.shopkeeper)
    if keeper ~= nil then
        local rot, dx, dy = 0, 0, 0
        if ambient ~= nil then
            rot, dx, dy = ambient:portrait_pose()
        end
        LG.stencil(function()
            LG.circle("fill", cx, cy, radius - 1, 28)
        end, "replace", 1)
        LG.setStencilTest("greater", 0)
        LG.push()
        LG.translate(cx + dx, cy + dy + radius * 0.9)       -- 아래(어깨)를 축으로 고개를 끄덕인다
        LG.rotate(rot)
        LG.translate(0, -radius * 0.9)
        LG.scale(radius * 2 * ZOOM)
        LG.setColor(1, 1, 1, 1)
        MeshDeformer.draw(keeper, ANIM.shopkeeper, time, KEY, ART.shopkeeper_face)
        LG.pop()
        LG.setStencilTest()
    else
        Icons.draw("hammer", cx, cy + 2, radius * 1.1, C.text, 0.85)
    end
    local glow = item ~= nil and not item.owned and (0.5 + 0.2 * math.sin(time * 2)) or 0.35
    Draw.set_color(C.accent, glow)
    LG.setLineWidth(2)
    LG.circle("line", cx, cy, radius, 28)
end

return ShopkeeperPortrait

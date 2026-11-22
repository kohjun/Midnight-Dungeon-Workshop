-- ui/ItemRenderer.lua
-- 유물 렌더링. 원화 assets/sprites/<원형 id>.png(ui/SpriteCatalog 가 고른다)가 있으면 그림자·등급 글로우와 함께 그리고(ui/SpriteBank),
-- 없으면 절차적 도형(ui/ItemShapes*)으로 폴백한다. 좌표는 크기 1 기준 정규화 좌표(-0.5 ~ 0.5).
--   draw()      : 일반 모습 + 발사 반동 + 강화 +5 이상 포일(ui/Foil — 등급 색) + 오염 얼룩(스텐실로 유물 실루엣 안에만)
--                 + 배지(강화 등급 뱃지 ui/ForgeTier · 감정 등급 · 결함). 내구도 게이지는 칸이 그린다 (ui/ItemStatus)
--   draw_xray() : UV 렌즈 속 모습 — 진짜 등급 색 실루엣과 숨겨진 결함 표식 · 스승의 은빛 인장(ui/SealSigil)
--                 (호출 측이 렌즈 스텐실을 건다)
-- 찾은 은빛 인장이 있는 유물은 왼쪽 아래 모서리에 작은 은빛 마름모 (작업대는 표식 자리에 인장을 크게 그리므로 opts.seal_dot = false)

local I18n = require("systems.I18n")
local Draw = require("ui.Draw")
local ItemShapes = require("ui.ItemShapes")
local ItemShapesExtra = require("ui.ItemShapesExtra")
local ItemShapesSpecial = require("ui.ItemShapesSpecial")
local SpriteBank = require("ui.SpriteBank")
local SpriteCatalog = require("ui.SpriteCatalog")
local Foil = require("ui.Foil")
local ForgeTier = require("ui.ForgeTier")
local SealSigil = require("ui.SealSigil")
local ITEMS = require("data.items")
local UI = require("data.ui")

local ItemRenderer = {}

local LG = love.graphics
local GRIME_ALPHA = 0.9
local LINE_PX = 2.5
local KICK_DROP = 0.11      -- 발사 반동: 발사 반대 방향으로 밀리는 거리 (크기 1 기준)
local KICK_SQUASH = 0.12
local CRACK_POINTS = { -0.12, -0.11, -0.04, -0.03, -0.08, 0.03, 0.02, 0.06, -0.01, 0.12, 0.09, 0.15 }
local SEAL_R = 0.085        -- 은빛 인장 표식 반지름 (크기 1 기준, ui/WorkbenchView 와 같은 값)
ItemRenderer.SEAL_R = SEAL_R

local SHAPES = {}
for name, fn in pairs(ItemShapes.SHAPES) do
    SHAPES[name] = fn
end
for _, module in ipairs({ ItemShapesExtra, ItemShapesSpecial, require("ui.ItemShapesArmor") }) do
    for name, fn in pairs(module) do
        assert(SHAPES[name] == nil, "ItemRenderer: duplicate shape '" .. name .. "'")
        SHAPES[name] = fn
    end
end
local circle = ItemShapes.circle

local function palette(item)
    return { primary = item.proto.color, accent = item.proto.accent }
end

local function shape_of(item)
    local shape = SHAPES[item.proto.shape]
    assert(shape ~= nil, "ItemRenderer: unknown shape '" .. tostring(item.proto.shape) .. "'")
    return shape
end

-- 현재 색으로 유물 실루엣을 그리는 함수 (스프라이트가 있으면 알파 마스크, 없으면 도형). mask: 스텐실용
local function silhouette_of(item)
    local image, art = SpriteCatalog.item_image(item)
    if image ~= nil then
        return function(mask)
            SpriteBank.draw_silhouette(image, mask)
        end, image, art
    end
    local shape, pal = shape_of(item), palette(item)
    return function()
        shape(pal, true)
    end, nil
end

-- 오염 얼룩: 유물 실루엣을 스텐실로 만들어 그 안에만 그린다
local function draw_grime(item, silhouette)
    local amount = item.contamination / 100
    LG.stencil(function()
        silhouette(true)
    end, "replace", 1)
    LG.setStencilTest("greater", 0)
    local grime = UI.color.grime
    LG.setColor(grime[1], grime[2], grime[3], GRIME_ALPHA * amount)
    for _, spot in ipairs(item.grime) do
        circle("fill", spot.x, spot.y, spot.r * (0.55 + 0.45 * amount))
    end
    LG.setColor(grime[1], grime[2], grime[3], 0.35 * amount)
    LG.rectangle("fill", -0.5, -0.5, 1, 1)
    LG.setStencilTest()
end

-- 등급 글로우 세기 (전설은 맥동)
local function glow_strength(item, time)
    local pulse = 0.5 + 0.5 * math.sin(time * 3 + item.uid)
    return item.grade == "legendary" and (0.22 + 0.12 * pulse) or 0.14
end

local function draw_aura(item, time)
    local color = ITEMS.grades[item.grade].color
    local strength = glow_strength(item, time)
    LG.setColor(color[1], color[2], color[3], strength)
    circle("fill", 0, 0, 0.5)
    LG.setColor(color[1], color[2], color[3], strength * 0.8)
    circle("fill", 0, 0, 0.36)
end

local function draw_badges(item, cx, cy, size, time, seal_dot)
    local half = size / 2
    local badge = math.max(5, size * 0.07)
    local small = size >= 120 and UI.font_size.body or UI.font_size.tiny
    ForgeTier.badge(item.level, cx - half - 4, cy - half - 6, small, time)
    if seal_dot and item.silver_seal ~= nil and item.revealed.seal then
        SealSigil.dot(cx - half + badge, cy + half - badge, math.max(3.5, badge * 0.8))
    end
    local gx, gy = cx + half - badge, cy + half - badge
    if item.revealed.grade then
        Draw.set_color(ITEMS.grades[item.grade].color)
        LG.polygon("fill", gx, gy - badge, gx + badge, gy, gx, gy + badge, gx - badge, gy)
    else
        Draw.shadow_text("?", gx - 20, gy - Draw.font(small):getHeight() / 2, 40, "center", small, UI.color.text_dim)
    end
    if item.flaw ~= nil and item.revealed.flaw then
        local color = item.flaw == "curse" and UI.color.link_curse or UI.color.danger
        Draw.set_color(color)
        circle("fill", cx + half - badge, cy - half + badge, badge)
        Draw.text("!", cx + half - badge * 2, cy - half + badge - Draw.font(UI.font_size.tiny):getHeight() / 2,
            badge * 2, "center", UI.font_size.tiny, { 1, 1, 1 })
    end
end

-- opts: { scale = 1, time = 0, badges = true, seal_dot = true }
function ItemRenderer.draw(item, cx, cy, size, opts)
    opts = opts or {}
    local time = opts.time or 0
    local silhouette, image, art = silhouette_of(item)
    local scaled = size * (opts.scale or 1) * (art and art.scale or 1)
    local kick = SpriteBank.kick_value(item)
    if kick < 0 then        -- 내려놓기 튕김 (SpriteBank.pop): 찌그러짐 대신 고르게 커졌다 돌아온다
        scaled = scaled * (1 - 0.2 * kick)
        kick = 0
    end

    local push_x, push_y = SpriteBank.kick_dir(item)
    LG.push()
    LG.translate(cx + push_x * kick * KICK_DROP * scaled, cy + push_y * kick * KICK_DROP * scaled)
    LG.scale(scaled * (1 + KICK_SQUASH * kick), scaled * (1 - KICK_SQUASH * kick))
    LG.setLineWidth(LINE_PX / scaled)
    if image ~= nil then
        local glow = item.revealed.grade and ITEMS.grades[item.grade].color or nil
        SpriteBank.draw_item(image, glow, glow and glow_strength(item, time) * 1.6 or 0)
    else
        if item.revealed.grade then
            draw_aura(item, time)
        end
        shape_of(item)(palette(item), false)
    end
    Foil.draw(function()    -- +5 이상: 흐르는 포일 광택 (황금 · 자홍 룬 · 심연 신화 색)
        if image ~= nil then
            SpriteBank.draw_unit(image)
        else
            shape_of(item)(palette(item), true)
        end
    end, item.level)
    if kick > 0.05 then     -- 발사 섬광
        LG.setColor(1, 1, 1, 0.45 * kick)
        silhouette(false)
    end
    if item.contamination > 0 then
        draw_grime(item, silhouette)
    end
    LG.pop()

    if opts.badges ~= false then
        draw_badges(item, cx, cy, scaled, time, opts.seal_dot ~= false)
    end
end

-- 단색 실루엣 (도감의 봉인된 특수 유물 등)
function ItemRenderer.draw_silhouette(item, cx, cy, size, color, alpha)
    local silhouette, _, art = silhouette_of(item)
    local scaled = size * (art and art.scale or 1)
    LG.push()
    LG.translate(cx, cy)
    LG.scale(scaled)
    Draw.set_color(color, alpha)
    silhouette(false)
    LG.pop()
end

local function draw_flaw_mark(item, time)
    local mx, my = item.flaw_mark.x, item.flaw_mark.y
    local glow = 0.75 + 0.25 * math.sin(time * 9)
    if item.flaw == "crack" then
        local points = {}
        for i = 1, #CRACK_POINTS, 2 do
            points[#points + 1] = mx + CRACK_POINTS[i]
            points[#points + 1] = my + CRACK_POINTS[i + 1]
        end
        LG.setColor(1, 0.4, 0.2, glow)
        LG.setLineWidth(0.03)
        LG.line(points)
    elseif item.flaw == "curse" then
        local curse = UI.color.link_curse
        LG.setColor(curse[1], curse[2], curse[3], glow)
        LG.setLineWidth(0.02)
        circle("line", mx, my, 0.1)
        local star = {}
        for i = 0, 5 do
            local angle = -math.pi / 2 + (i * 2) % 5 * (math.pi * 2 / 5)
            star[#star + 1] = mx + math.cos(angle) * 0.09
            star[#star + 1] = my + math.sin(angle) * 0.09
        end
        LG.line(star)
    end
end

-- UV 투시 모습. 호출 측이 렌즈 원형 스텐실을 건 상태에서 호출한다 (여기서는 스텐실을 쓰지 않음)
function ItemRenderer.draw_xray(item, cx, cy, size, time)
    local silhouette = silhouette_of(item)
    local color = ITEMS.grades[item.grade].color
    time = time or 0

    LG.push()
    LG.translate(cx, cy)
    LG.scale(size)
    LG.setLineWidth(LINE_PX / size)
    LG.push()
    LG.scale(1.08)
    LG.setColor(color[1], color[2], color[3], 0.18)
    silhouette(false)
    LG.pop()
    LG.setColor(color[1], color[2], color[3], 0.45)
    silhouette(false)
    LG.setColor(color[1], color[2], color[3], 0.95)
    circle("fill", 0, 0, 0.055 + 0.015 * math.sin(time * 6))
    if item.flaw ~= nil then
        draw_flaw_mark(item, time)
    end
    local seal = item.silver_seal               -- 스승의 은빛 인장: UV 로만 보인다 (찾기 전에도 렌즈 속에서는 빛난다)
    if seal ~= nil then
        SealSigil.draw(seal.x, seal.y, SEAL_R, 0.8 + 0.2 * math.sin(time * 7), time)
    end
    LG.pop()

    local label = I18n.t("bench.grade_label", { grade = I18n.grade(item.grade) })
    Draw.shadow_text(label, cx - 80, cy + size * 0.1, 160, "center", UI.font_size.small, color)
end

return ItemRenderer

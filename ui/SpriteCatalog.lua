-- ui/SpriteCatalog.lua
-- 스프라이트 이름 목록과 원화 조회 (로드·그리기는 ui/SpriteBank). 어떤 그림을 어떤 보정값(data/art.lua)과 쓸지 정한다:
--   유물  : 원화 <원형 id>.png → 생성 item_<id>.png → nil (호출 측이 ui/ItemShapes* 코드 도형으로 폴백)
--   몬스터: 원화 <몬스터 id>.png → 생성 monster_<id>.png → nil (ui/MonsterShapes)
--   모험가: 원화 adventurer_<id>.png → nil (ui/AdventurerPortrait 가 뱃지 색 두건 실루엣으로 폴백)
-- 지금은 유물 32종 · 몬스터 10종 · 모험가 6인 모두 원화가 있다 (생성 스프라이트는 작업대 텍스처 2장뿐).

local SpriteBank = require("ui.SpriteBank")
local ITEMS = require("data.items")
local ENEMIES = require("data.enemies")
local ART = require("data.art")

local SpriteCatalog = {}

local TEXTURES = { "wood", "stone" }

-- 유물 그림과 표시 보정 (원화가 있으면 그것, 없으면 생성 스프라이트, 둘 다 없으면 nil)
function SpriteCatalog.item_image(item)
    if item.category == "armor" then                    -- 방어구 원화: armor_<id> (없으면 도형 — ui/ItemShapesArmor)
        return SpriteBank.image(ART.armors.prefix .. item.proto_id), ART.armors
    end
    local art = SpriteBank.image(item.proto_id)
    if art ~= nil then
        return art, ART.items[item.proto_id]
    end
    return SpriteBank.image("item_" .. item.proto_id), nil
end

-- 몬스터 그림: art_id(중간 보스는 다른 몬스터의 원화 — data/enemies.lua 의 sprite)의 원화, 없으면 생성 스프라이트
function SpriteCatalog.monster_image(monster)
    local id = monster.art_id or monster.type_id
    local art = SpriteBank.image(id)
    if art ~= nil then
        return art, ART.monsters[id]
    end
    return SpriteBank.image("monster_" .. id), nil
end

-- 모험가 초상과 보정 (flip · zoom · region). 원화가 없거나 등록되지 않은 id 면 nil
function SpriteCatalog.adventurer_image(id)
    local spec = id and ART.adventurers[id]
    if spec == nil then
        return nil, nil
    end
    return SpriteBank.image("adventurer_" .. id), spec
end

-- 기대하는 모든 스프라이트 이름 (정렬됨): 원화가 있는 id(data/art.lua)는 <id>, 나머지는 생성 스프라이트
function SpriteCatalog.expected_names()
    local names = {}
    for id in pairs(ITEMS.prototypes) do
        names[#names + 1] = ART.items[id] and id or "item_" .. id
    end
    for id, spec in pairs(ENEMIES.monsters) do
        if spec.sprite == nil then                  -- 중간 보스는 다른 몬스터의 그림을 다시 쓴다
            names[#names + 1] = ART.monsters[id] and id or "monster_" .. id
        end
    end
    for id in pairs(ART.adventurers) do
        names[#names + 1] = "adventurer_" .. id
    end
    for _, id in ipairs(TEXTURES) do
        names[#names + 1] = "tex_" .. id
    end
    for _, name in ipairs(ART.scenes) do
        names[#names + 1] = name
    end
    for _, name in ipairs(ART.ui_props) do
        names[#names + 1] = name
    end
    for _, id in ipairs(require("data.armors").order) do        -- 방어구 12종 (armors.png)
        names[#names + 1] = ART.armors.prefix .. id
    end
    for _, pose in ipairs(ART.hero.order) do            -- 밤 전투 레인의 주인공 3포즈 (ui/LaneHero)
        names[#names + 1] = ART.hero.poses[pose].sprite
    end
    table.sort(names)
    return names
end

-- 전부 로드해 보고 { loaded = n, missing = { 이름, ... } } 반환
function SpriteCatalog.preload()
    local stats = { loaded = 0, missing = {} }
    for _, name in ipairs(SpriteCatalog.expected_names()) do
        if SpriteBank.image(name) ~= nil then
            stats.loaded = stats.loaded + 1
        else
            stats.missing[#stats.missing + 1] = name
        end
    end
    return stats
end

return SpriteCatalog

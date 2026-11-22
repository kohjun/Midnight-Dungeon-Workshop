-- tools/SmokeI18n.lua
-- 다국어 키 검사 (SmokeSystems 가 부른다): ① 소스에 적힌 완전한 문구 키가 기본 로케일에 있는지
-- ② data 테이블의 id 로 조립되는 문구 키(유물·몬스터·난이도·상점·보스 안내 …)가 모두 있는지.

local SmokeI18n = {}

local SOURCE_DIRECTORIES = { "core", "data", "entities", "states", "systems", "ui" }
local SKIPPED_SOURCES = { ["data/locales"] = true }

local function check(condition, message)
    assert(condition, "SmokeI18n: " .. message)
end

local function collect_sources(directory, out)
    for _, name in ipairs(love.filesystem.getDirectoryItems(directory)) do
        local path = directory .. "/" .. name
        local info = love.filesystem.getInfo(path)
        if info.type == "directory" and not SKIPPED_SOURCES[path] then
            collect_sources(path, out)
        elseif info.type == "file" and name:match("%.lua$") then
            out[#out + 1] = path
        end
    end
    return out
end

-- 소스에 적힌 완전한 문구 키("네임스페이스.키...")가 기본 로케일에 실제로 있는지
function SmokeI18n.check_source_keys(I18n)
    local namespaces = {}
    for _, part in ipairs(require("data.locales.ko").parts) do
        for namespace in pairs(part) do
            namespaces[namespace] = true
        end
    end
    local checked = 0
    local sources = {}
    for _, directory in ipairs(SOURCE_DIRECTORIES) do
        collect_sources(directory, sources)
    end
    for _, path in ipairs(sources) do
        local content = love.filesystem.read(path)
        for key in content:gmatch('"(%l[%w_]*%.[%w_%.]+)"') do
            local namespace = key:match("^[^.]+")
            if namespaces[namespace] and not key:sub(-1):match("[._]") and not key:match("%.lua$") then
                checked = checked + 1
                check(I18n.has(key, "ko"), string.format("%s uses unknown text key '%s'", path, key))
            end
        end
    end
    check(checked > 250, "expected to verify hundreds of text keys, found only " .. checked)
    return checked
end

-- data 테이블의 모든 id 에 대응하는 문구 키(동적으로 조립되는 키)가 로케일에 있는지
function SmokeI18n.check_data_keys(I18n)
    local function need(key)
        check(I18n.has(key, "ko"), "locale is missing the text key '" .. key .. "'")
    end
    local function each(map, prefix, fields)
        for id in pairs(map) do
            for _, field in ipairs(fields) do
                need(prefix .. id .. field)
            end
        end
    end
    local ITEMS = require("data.items")
    each(ITEMS.prototypes, "items.", { ".name", ".description" })
    for _, proto in pairs(ITEMS.prototypes) do
        for _, effect in ipairs(proto.effects or {}) do
            if effect.label_key ~= nil then
                need(effect.label_key)
            end
        end
    end
    each(ITEMS.grades, "grades.", { "" })
    each(ITEMS.categories, "categories.", { "" })
    each(ITEMS.archetypes, "archetypes.", { "" })
    each(ITEMS.elements, "elements.", { "" })
    each(ITEMS.flaws, "flaws.", { ".name", ".summary" })
    for _, proto in pairs(ITEMS.prototypes) do
        need("compendium.damage." .. (proto.damage_type or "physical"))
        need("compendium.projectile." .. (proto.projectile or "bullet"))
    end
    each(require("data.achievements").list, "achievements.", { ".name", ".condition" })
    each(require("data.endings").list, "ending.", { ".name", ".condition", ".title", ".lines.4" })
    each(require("data.enemies").monsters, "monsters.", { "" })
    for _, name in ipairs(require("systems.BossPatterns").names()) do      -- 대보스 · 중간 보스 패턴
        need("boss.hint_" .. name)
        need("monster_tip.gimmick_" .. name)
    end
    need("boss.immune_physical")
    need("boss.immune_elemental")
    each(require("data.difficulties").modes, "difficulty.", { ".name", ".tier", ".playtime", ".briefing", ".summary.1" })
    each(require("data.shop").offers, "shop.", { ".name", ".text" })
    each(require("data.meta").stats, "meta.", { ".name", ".text" })
    for _, step in ipairs(require("data.tutorial").steps) do
        need("tutorial.steps." .. step.id)
    end
    for id, upgrade in pairs(require("data.upgrades").upgrades) do
        need("upgrades." .. id .. ".name")
        need("upgrades." .. id .. ".description")
        need("upgrades." .. id .. ".levels." .. #upgrade.levels)
    end
    local EVENTS = require("data.events").events
    each(EVENTS, "events.", { ".name", ".banner" })
    need("events.mystery_boxes.boxes." .. #EVENTS.mystery_boxes.boxes)
    local SETTINGS = require("data.settings")
    for id, option in pairs(SETTINGS.options) do
        need("settings." .. id)
        if option.kind == "toggle" then
            need("settings.choices." .. id .. ".off")
            need("settings.choices." .. id .. ".on")
        elseif option.kind == "choice" then
            need("settings.choices." .. id .. "." .. #option.choices)
        end
    end
end

return SmokeI18n

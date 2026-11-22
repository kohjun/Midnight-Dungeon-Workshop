-- systems/I18n.lua
-- 다국어 문구 조회. 로케일은 data/locales/<code>.lua (parts 목록을 네임스페이스별로 병합), 현재 언어는 Settings 의 "language".
--   I18n.t("hud.gold")                               → "보유 골드"
--   I18n.t("fx.daily_income", { amount = 30 })       → "{amount}" 자리표시자 치환 (lib/text 의 Text.fill)
--   I18n.t("upgrades.grid.levels.2")                 → 숫자 조각은 배열 인덱스
--   I18n.list("difficulty.broker.summary")           → 문자열 배열
-- 현재 언어에 키가 없으면 기본 언어 → 키 문자열 순으로 대체한다 (콘솔에 한 번 경고).
-- 문구는 그릴 때마다 조회하므로 언어를 바꾸면 재시작 없이 즉시 반영된다. 바뀌는 순간 "i18n:language_changed" 발행
-- (캐시된 문자열을 가진 쪽 — 그리드 보너스 문구, 모달 행 — 이 다시 만들도록).

local EventBus = require("core.EventBus")
local Text = require("lib.text")
local Settings = require("systems.Settings")

local I18n = {}

local LOCALE_PREFIX = "data.locales."

local _tables = {}      -- code -> 병합된 로케일 테이블
local _cache = {}       -- code -> { [key] = 값 | false }
local _warned = {}
local _missing = {}
local _revision = 0

local function default_language()
    return Settings.definition("language").default
end

local function load_locale(code)
    local merged = _tables[code]
    if merged == nil then
        local locale = require(LOCALE_PREFIX .. code)
        merged = {}
        for _, part in ipairs(locale.parts) do
            for namespace, entries in pairs(part) do
                assert(merged[namespace] == nil, "I18n: duplicate namespace '" .. tostring(namespace) .. "' in locale " .. code)
                merged[namespace] = entries
            end
        end
        _tables[code] = merged
        _cache[code] = {}
    end
    return merged
end

-- "a.b.2" → root.a.b[2] (없으면 nil). 결과는 키별로 캐시한다
local function resolve(code, key)
    local root = load_locale(code)
    local cache = _cache[code]
    local value = cache[key]
    if value == nil then
        value = root
        for part in key:gmatch("[^.]+") do
            if type(value) ~= "table" then
                value = nil
                break
            end
            value = value[tonumber(part) or part]
        end
        cache[key] = value == nil and false or value
    end
    return value or nil
end

local function lookup(key)
    local value = resolve(I18n.language(), key)
    if value == nil then
        value = resolve(default_language(), key)
    end
    if value == nil and not _warned[key] then
        _warned[key] = true
        _missing[#_missing + 1] = tostring(key)
        print("[I18n] missing key: " .. tostring(key))
    end
    return value
end

-- 지금까지 조회했지만 어느 로케일에도 없던 키 목록 (화면에 키 문자열이 그대로 나갔다는 뜻 — 스모크 테스트가 검사)
function I18n.missing_lookups()
    return _missing
end

function I18n.language()
    return Settings.get("language")
end

function I18n.set_language(code)
    return Settings.set("language", code)
end

-- 선택 가능한 언어 코드 목록
function I18n.languages()
    return Settings.definition("language").choices
end

-- 언어가 바뀔 때마다 1씩 증가 (문자열을 캐시한 쪽의 갱신 판정용)
function I18n.revision()
    return _revision
end

function I18n.t(key, vars)
    local value = lookup(key)
    if type(value) ~= "string" then
        return key
    end
    if vars ~= nil then
        return Text.fill(value, vars)
    end
    return value
end

function I18n.list(key)
    local value = lookup(key)
    return type(value) == "table" and value or {}
end

function I18n.has(key, code)
    return resolve(code or I18n.language(), key) ~= nil
end

-- 자주 쓰는 키 규칙 도우미
-- 방어구(category "armor")의 이름·설명은 armors 네임스페이스 (data/locales/<언어>/hero.lua)
function I18n.item_name(item)
    return I18n.t((item.category == "armor" and "armors." or "items.") .. item.proto_id .. ".name")
end

function I18n.item_description(item)
    return I18n.t((item.category == "armor" and "armors." or "items.") .. item.proto_id .. ".description")
end

function I18n.grade(grade_id)
    return I18n.t("grades." .. grade_id)
end

local function collect(node, prefix, out)
    for key, value in pairs(node) do
        local path = prefix == "" and tostring(key) or (prefix .. "." .. tostring(key))
        if type(value) == "table" then
            collect(value, path, out)
        else
            out[path] = true
        end
    end
    return out
end

-- code_a 에는 있지만 code_b 에는 없는 말단 키 목록 (정렬됨). 번역 누락 검사용
function I18n.missing(code_a, code_b)
    local keys_a = collect(load_locale(code_a), "", {})
    local keys_b = collect(load_locale(code_b), "", {})
    local missing = {}
    for key in pairs(keys_a) do
        if not keys_b[key] then
            missing[#missing + 1] = key
        end
    end
    table.sort(missing)
    return missing
end

EventBus.subscribe("settings:changed", function(payload)
    if payload.key == "language" then
        _revision = _revision + 1
        EventBus.emit("i18n:language_changed", { language = payload.value })
    end
end, { owner = I18n, priority = 100 })

return I18n

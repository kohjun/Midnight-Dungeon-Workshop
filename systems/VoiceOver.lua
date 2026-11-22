-- systems/VoiceOver.lua
-- 손님 모험가 더빙 · 입장/퇴장 효과음 타이밍 (systems/Audio 가 init 에서 install, update 에서 update 를 부른다).
--   새 손님(appraisal:customer_arrived): 황동 문 종소리(shop_door_bell, data/audio.lua 의 events) → voice.delay 초 뒤
--     초상이 자리 잡고 대사가 뜨는 순간 그 모험가의 입장 대사 더빙 (greet_1 / greet_2 — 유물 번호로 고른다)
--   결함·위조 적발: 그 모험가의 당황·변명 대사 더빙 (caught_forgery / caught_curse / caught_crack, 화면 대사와 같은 문장)
--   손님이 나가면(돌려보내기 · 밤) 더빙을 끊고 발걸음(guest_footsteps_out), 매입이 끝나면 동전 소리 뒤 발걸음
-- 새 대사가 시작되거나 화면이 바뀌면(stop) 이전 더빙은 즉시 멈춘다. 볼륨은 효과음 볼륨 × 마스터(love.audio) · 음소거를 따른다.
-- 파일은 assets/voices/<언어>/<모험가>_<대사>.ogg|mp3|wav (tools/generate_voices.py) — 없으면 조용히 건너뛴다.

local EventBus = require("core.EventBus")
local Settings = require("systems.Settings")
local I18n = require("systems.I18n")
local AUDIO = require("data.audio")

local VoiceOver = {}

local V = AUDIO.voice
local EXTENSIONS = { "ogg", "mp3", "wav" }

local _source = nil
local _pending = nil            -- { id, key, t }
local _after = nil              -- { sound, t } 잠시 뒤 효과음 (매입 뒤 발걸음)
local _play_sound = nil         -- Audio.play (순환 require 를 피해 install 때 받는다)
local _stats = { requested = 0, played = 0, last = nil }

function VoiceOver.path(id, key)
    for _, ext in ipairs(EXTENSIONS) do
        local path = string.format("%s/%s/%s_%s.%s", V.dir, I18n.language(), id, key, ext)
        if love.filesystem.getInfo(path) ~= nil then
            return path
        end
    end
    return nil
end

function VoiceOver.stop()
    if _source ~= nil then
        _source:stop()
        _source = nil
    end
    _pending = nil
end

-- 더빙 예약 (delay 초 뒤). 앞의 더빙은 바로 끊는다
function VoiceOver.say(id, key, delay)
    VoiceOver.stop()
    _stats.requested = _stats.requested + 1
    _stats.last = id .. "_" .. key
    _pending = { id = id, key = key, t = delay or 0 }
end

local function play(id, key)
    local path = VoiceOver.path(id, key)
    if path == nil then
        return
    end
    local ok, source = pcall(love.audio.newSource, path, "static")
    if not ok then
        print("[VoiceOver] failed to load " .. path .. ": " .. tostring(source))
        return
    end
    source:setVolume(V.volume * Settings.get("sfx_volume") / 100)
    source:play()
    _source = source
    _stats.played = _stats.played + 1
end

function VoiceOver.update(dt)
    if _pending ~= nil then
        _pending.t = _pending.t - dt
        if _pending.t <= 0 then
            local pending = _pending
            _pending = nil
            play(pending.id, pending.key)
        end
    end
    if _after ~= nil then
        _after.t = _after.t - dt
        if _after.t <= 0 then
            local name = _after.sound
            _after = nil
            _play_sound(name)
        end
    end
    if _source ~= nil and not _source:isPlaying() then
        _source = nil
    end
end

-- { requested, played, last } — 스모크 테스트용
function VoiceOver.stats()
    return _stats
end

function VoiceOver.install(play_sound)
    _play_sound = play_sound
    EventBus.subscribe("appraisal:customer_arrived", function(p)
        if p.item ~= nil and p.item.adventurer ~= nil then
            VoiceOver.say(p.item.adventurer, "greet_" .. (p.item.uid % 2 + 1), V.delay)
        end
    end, { owner = VoiceOver, priority = -100 })
    EventBus.subscribe("appraisal:customer_left", function()
        VoiceOver.stop()
    end, { owner = VoiceOver, priority = -100 })
    EventBus.subscribe("appraisal:item_bought", function()
        _after = { sound = "guest_footsteps_out", t = V.footsteps_after_buy }
    end, { owner = VoiceOver, priority = -100 })
    local function caught(kind, item)
        if item ~= nil and not item.owned and item.adventurer ~= nil then
            VoiceOver.say(item.adventurer, "caught_" .. kind, 0)
        end
    end
    EventBus.subscribe("appraisal:forgery_revealed", function(p) caught("forgery", p.item) end, { owner = VoiceOver, priority = -100 })
    EventBus.subscribe("appraisal:flaw_revealed", function(p)
        local flaw = p.item and p.item.flaw
        if flaw == "curse" or flaw == "crack" then
            caught(flaw, p.item)
        end
    end, { owner = VoiceOver, priority = -100 })
end

return VoiceOver

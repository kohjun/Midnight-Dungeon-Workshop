-- systems/Audio.lua
-- 효과음·루프·배경음 재생. 목록과 이벤트 매핑은 data/audio.lua, 파일은 tools/generate_audio.py 가 만든 .wav.
--   Audio.init()               : 한 번만 로드 + EventBus 구독 + 배경음 시작 (타이틀 진입 시 호출, 여러 번 불러도 안전)
--   Audio.play(name)           : 효과음 1회 — 재생할 때마다 0.92~1.08 범위의 무작위 피치 변조
--   Audio.set_loop(name, on)   : 누르고 있는 동안만 이어지는 루프 (UV 홀드 스캔 · 세척). 음량이 부드럽게 오르내린다
--   Audio.set_scene(name)      : 장면 배경음·앰비언스 크로스페이드 (title · menu · day · night — data/audio.lua 의 scenes)
--   Audio.set_intensity(0~2)   : 밤 보스 긴장감 1 = 대보스(boss_pitch · boss_gain) · 2 = 최종 보스(final_*) — 지금 값 Audio.intensity()
--   Audio.update(dt)           : 루프 페이드 진행 (모든 화면 상태가 매 프레임 호출)
-- 음량은 Settings 의 master / sfx / bgm / mute 를 따른다. 파일이 없거나 오디오 장치가 없으면 조용히 건너뛴다 (크래시 금지).

local EventBus = require("core.EventBus")
local RNG = require("core.RNG")
local Settings = require("systems.Settings")
local VoiceOver = require("systems.VoiceOver")
local AUDIO = require("data.audio")
local MAX_INTENSITY = 2     -- 보스 긴장감 단계: 0 평소 · 1 대보스(boss_*) · 2 최종 보스(final_*)

local Audio = {}

local _initialized = false
local _sfx = {}         -- name -> { spec, voices = { Source, ... }, last = 마지막 재생 시각 }
local _loops = {}       -- name -> { spec, source, target = 0|1, level = 0~1, tense = boss_* · final_* 가 있는 루프 }
local _scene = nil
local _intensity = 0
local _stats = { loaded = 0, missing = {}, played = {} }

local function available()
    return love.audio ~= nil
end

local function new_source(spec, kind)
    if not available() or love.filesystem.getInfo(spec.file) == nil then
        return nil
    end
    local ok, source = pcall(love.audio.newSource, spec.file, kind)
    if not ok then
        print("[Audio] failed to load " .. spec.file .. ": " .. tostring(source))
        return nil
    end
    return source
end

local function sfx_volume()
    return Settings.get("sfx_volume") / 100
end

local function loop_bus_volume(spec)
    return spec.bus == "bgm" and Settings.get("bgm_volume") / 100 or sfx_volume()
end

-- 보스 긴장감 배율: _intensity 0 → 1(평소) · 1 → boss · 2 → final(없으면 boss), 사이 값은 선형 보간
local function tension(boss, final)
    boss = boss or 1
    local low, high = math.min(_intensity, 1), math.max(_intensity - 1, 0)
    return 1 + (boss - 1) * low + ((final or boss) - boss) * high
end

-- 루프 음량 = 기본 음량 × 버스 볼륨 × 페이드 × (보스 긴장감 음량)
local function loop_volume(loop)
    return loop.spec.volume * loop_bus_volume(loop.spec) * loop.level * tension(loop.spec.boss_gain, loop.spec.final_gain)
end

-- 설정 값을 재생 중인 소스에 반영한다
local function apply_volumes()
    if not available() then
        return
    end
    love.audio.setVolume(Settings.get("mute") and 0 or Settings.get("master_volume") / 100)
    for _, loop in pairs(_loops) do
        loop.source:setVolume(loop_volume(loop))
    end
end

local function sorted_keys(map)
    local keys = {}
    for key in pairs(map) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return keys
end

local function note_load(name, loaded)
    if loaded then
        _stats.loaded = _stats.loaded + 1
    else
        _stats.missing[#_stats.missing + 1] = name
    end
end

local function load_all()
    for _, name in ipairs(sorted_keys(AUDIO.sfx)) do
        local spec = AUDIO.sfx[name]
        local source = new_source(spec, "static")
        if source ~= nil then
            _sfx[name] = { spec = spec, voices = { source }, last = -math.huge }
        end
        note_load(name, source ~= nil)
    end
    for _, name in ipairs(sorted_keys(AUDIO.loops)) do
        local spec = AUDIO.loops[name]
        local source = new_source(spec, spec.stream and "stream" or "static")
        if source ~= nil then
            source:setLooping(true)
            local tense = (spec.boss_pitch or spec.boss_gain or spec.final_pitch or spec.final_gain) ~= nil
            _loops[name] = { spec = spec, source = source, target = 0, level = 0, tense = tense }
        end
        note_load(name, source ~= nil)
    end
end

-- 재생 중이 아닌 보이스를 찾거나 (voices 한도 안에서) 복제한다
local function free_voice(entry)
    for _, voice in ipairs(entry.voices) do
        if not voice:isPlaying() then
            return voice
        end
    end
    if #entry.voices < (entry.spec.voices or 1) then
        local voice = entry.voices[1]:clone()
        entry.voices[#entry.voices + 1] = voice
        return voice
    end
    return nil
end

function Audio.play(name)
    assert(AUDIO.sfx[name] ~= nil, "Audio.play: unknown sound '" .. tostring(name) .. "'")
    local entry = _sfx[name]
    if entry == nil then
        return false    -- 파일 없음 / 오디오 없음
    end
    local now = love.timer.getTime()
    if now - entry.last < (entry.spec.min_interval or 0) then
        return false
    end
    local voice = free_voice(entry)
    if voice == nil then
        return false
    end
    entry.last = now
    voice:setPitch(RNG.stream("audio"):float(AUDIO.pitch.min, AUDIO.pitch.max))
    voice:setVolume(entry.spec.volume * sfx_volume())
    voice:play()
    _stats.played[name] = (_stats.played[name] or 0) + 1
    return true
end

function Audio.set_loop(name, on)
    assert(AUDIO.loops[name] ~= nil, "Audio.set_loop: unknown loop '" .. tostring(name) .. "'")
    local loop = _loops[name]
    if loop == nil then
        return
    end
    if on and loop.target == 0 then
        _stats.played[name] = (_stats.played[name] or 0) + 1
    end
    loop.target = on and 1 or 0
end

function Audio.is_loop_on(name)
    local loop = _loops[name]
    return loop ~= nil and loop.target == 1
end

-- 입력 루프(UV · 세척)를 끈다. 장면 배경음·앰비언스는 그대로 (시스템 메뉴를 열어도 음악은 이어진다)
function Audio.stop_loops()
    VoiceOver.stop()                            -- 화면이 바뀌면 더빙도 끊는다
    for _, loop in pairs(_loops) do
        if not loop.spec.scene then
            loop.target, loop.level = 0, 0
            loop.source:stop()
        end
    end
end

-- 장면 배경음·앰비언스로 크로스페이드 (같은 장면이면 아무것도 하지 않는다). 모르는 장면이면 오류
function Audio.set_scene(name)
    assert(AUDIO.scenes[name] ~= nil, "Audio.set_scene: unknown scene '" .. tostring(name) .. "'")
    if _scene == name then
        return
    end
    _scene = name
    local members = {}
    for _, loop_name in ipairs(AUDIO.scenes[name]) do
        members[loop_name] = true
    end
    for loop_name, loop in pairs(_loops) do
        if loop.spec.scene then
            loop.target = members[loop_name] and 1 or 0
            if loop.target == 1 and not loop.source:isPlaying() then
                loop.source:setVolume(loop_volume(loop))
                loop.source:play()                 -- 음량 0 에서 시작해 Audio.update 가 올린다
            end
        end
    end
end

function Audio.scene()
    return _scene
end

-- 보스 긴장감 0 ~ MAX_INTENSITY (밤에 ui/RunAudio 가 대보스 1 · 최종 보스 2, 그 밖 0)
function Audio.set_intensity(value)
    _intensity = math.max(0, math.min(MAX_INTENSITY, value))
end

function Audio.intensity() return _intensity end

-- 루프 음량을 목표로 부드럽게 수렴시킨다. 0 에 닿으면 정지
function Audio.update(dt)
    VoiceOver.update(dt)
    for _, loop in pairs(_loops) do
        if loop.level ~= loop.target then
            local step = (loop.spec.fade or AUDIO.loop_fade) * dt
            if loop.target > loop.level then
                loop.level = math.min(loop.target, loop.level + step)
            else
                loop.level = math.max(loop.target, loop.level - step)
            end
            loop.source:setVolume(loop_volume(loop))
            if loop.level > 0 and not loop.source:isPlaying() then
                loop.source:play()
            elseif loop.level <= 0 then
                loop.source:stop()
            end
        end
        if loop.tense then                          -- 보스 긴장감: 음높이·음량 (boss_* · final_* 가 있는 루프)
            loop.source:setPitch(tension(loop.spec.boss_pitch, loop.spec.final_pitch))
            loop.source:setVolume(loop_volume(loop))
        end
    end
end

local function subscribe()
    local function on(event, handler)
        EventBus.subscribe(event, handler, { owner = Audio, priority = -150 })
    end
    for _, event in ipairs(sorted_keys(AUDIO.events)) do
        local name = AUDIO.events[event]
        on(event, function() Audio.play(name) end)
    end
    on("ui:button_pressed", function() Audio.play("ui_click") end)
    on("combat:fired", function(payload)
        Audio.play(payload.item.proto.projectile == "laser" and "shoot_laser" or "shoot_bullet")
    end)
    -- 용광로: +1 기본 제련 / +2 이상 오버클럭은 다른 소리
    on("forge:started", function(p) Audio.play(p.overclock and "forge_heat" or "forge_charge") end)
    on("forge:succeeded", function(p) Audio.play(p.overclock and "forge_overclock_ok" or "forge_success") end)
    on("forge:failed", function(p)       -- 파괴 = 파쇄음 · 단계 유지·하락 = 둔탁한 쇳소리
        Audio.play(p.outcome == "destroyed" and (p.overclock and "forge_shatter" or "forge_fail") or "forge_dud")
    end)
    on("combat:overclock_changed", function(payload)
        if payload.enabled then
            Audio.play("overclock_on")
        end
    end)
    on("settings:changed", apply_volumes)
end

function Audio.init()
    if _initialized then
        return
    end
    _initialized = true
    load_all()
    subscribe()
    VoiceOver.install(Audio.play)               -- 손님 더빙 · 매입 뒤 발걸음
    apply_volumes()
    Audio.set_scene(AUDIO.default_scene)
    print(string.format("[Audio] %d sounds loaded, %d missing", _stats.loaded, #_stats.missing))
end

-- { loaded = n, missing = { 이름, ... }, played = { [이름] = 횟수 } } (스모크 테스트 검증용)
function Audio.stats()
    return _stats
end

function Audio.expected_count()
    return #sorted_keys(AUDIO.sfx) + #sorted_keys(AUDIO.loops)
end

-- 지금 장면의 배경음·앰비언스가 하나라도 들리는지
function Audio.is_bgm_playing()
    for _, loop in pairs(_loops) do
        if loop.spec.scene and loop.target == 1 and loop.source:isPlaying() then
            return true
        end
    end
    return false
end

-- 장면 루프의 지금 음량 비율 0~1 (스모크 테스트의 크로스페이드 검증용, 없으면 nil)
function Audio.loop_level(name)
    local loop = _loops[name]
    return loop and loop.level or nil
end

return Audio

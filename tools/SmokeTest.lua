-- tools/SmokeTest.lua
-- 자동 런타임 검증 러너:  lovec . --smoke-test [--shots]
--   1) Lint (문법 / 300줄 / 금지 난수 API)
--   2) RNG 결정론 · EventBus 동작 자가 검사
--   2-1) SmokeSystems — 다국어 키·언어 전환, 설정 저장, 화면 변환, 오디오·스프라이트 로딩, 버튼 비활성 규칙
--   3) SmokeSim — 모든 유물을 그리드에 깔고 과부하 밤 전투 헤드리스 시뮬레이션
--   4) SmokeScenario — 입력 이벤트를 주입해 실제 화면 흐름을 끝까지 진행
-- 성공: "[SMOKE] PASS" 후 exit 0 / 실패: "[SMOKE] FAIL" + traceback 후 exit 1.
-- --shots: 주요 화면을 세이브 디렉토리에 smoke_*.png 로 저장.
-- --missing-assets: assets/ 의 소리·스프라이트가 없는 상태를 검증한다 (전부 없어야 하고, 무음·도형 폴백으로 끝까지 통과해야 한다).
-- --only <모듈>[,<모듈>…]: 개발 중 빠른 확인 — Lint 뒤 그 스모크 모듈만 run(log, shots, missing_assets) 으로 돌리고 끝낸다
--   (예: lovec . --smoke-test --only SmokeMasterTrace). 시나리오는 돌지 않으므로 최종 검증은 항상 전체 실행으로 한다.
-- 게임 모듈은 함수 안에서 지연 require 한다 (문법 오류까지 실패 핸들러가 잡도록).

local SmokeTest = {}

local FLAG = "--smoke-test"
local SHOTS_FLAG = "--shots"
local MISSING_ASSETS_FLAG = "--missing-assets"
local STEP_TIMEOUT_SECONDS = 8    -- 실시간 기준 (프레임 수는 vsync·창 상태에 따라 달라진다)
local SELF_CHECK_SEED = 20261117
local SAMPLE_COUNT = 8

-- 시나리오와 공유하는 문맥: speed = 프레임당 update 횟수, events/last = 관찰한 이벤트
local _context = { shots = false, missing_assets = false, speed = 1, events = {}, last = {} }
local _script = nil
local _index = 1
local _step_frames = 0
local _step_started = nil
local _finished = false

local function log(message, ...)
    print("[SMOKE] " .. string.format(message, ...))
end

-- --only 다음 값 (없으면 nil)
local function only_modules(args)
    for i, value in ipairs(type(args) == "table" and args or {}) do
        if value == "--only" and args[i + 1] ~= nil then
            return args[i + 1]
        end
    end
    return nil
end

local function has_flag(args, flag)
    if type(args) ~= "table" then
        return false
    end
    for _, value in pairs(args) do
        if value == flag then
            return true
        end
    end
    return false
end

-- love.errorhandler 대체: 에러 화면 대신 로그 후 종료 (nil 반환 → LÖVE 가 exit code 1 로 종료)
local function fail_handler(message)
    print("[SMOKE] FAIL: " .. tostring(message))
    print(debug.traceback("", 2))
    return nil
end

-- ── 자가 검사 ──────────────────────────────────────────────

local function sample(stream_name)
    local stream = require("core.RNG").stream(stream_name)
    local values = {}
    for i = 1, SAMPLE_COUNT do
        values[i] = stream:int(1, 1000000)
    end
    return table.concat(values, ",")
end

local function check_rng()
    local RNG = require("core.RNG")
    RNG.set_seed(SELF_CHECK_SEED)
    local a, b = sample("a"), sample("b")
    RNG.set_seed(SELF_CHECK_SEED)
    local b_first, a_second = sample("b"), sample("a")
    assert(a == a_second and b == b_first, "RNG: same seed must reproduce streams regardless of call order")
    assert(a ~= b, "RNG: different stream names must diverge")
    RNG.set_seed(SELF_CHECK_SEED + 1)
    assert(sample("a") ~= a, "RNG: different seeds must diverge")
end

local function check_event_bus()
    local EventBus = require("core.EventBus")
    local owner, order = {}, {}
    EventBus.subscribe("smoke:hit", function(p)
        p.amount = p.amount * 2
        order[#order + 1] = "x2"
    end, { owner = owner })
    EventBus.subscribe("smoke:hit", function(p)
        p.amount = p.amount + 3
        order[#order + 1] = "+3"
    end, { owner = owner, priority = 10 })
    EventBus.subscribe("smoke:hit", function()
        order[#order + 1] = "once"
    end, { owner = owner, once = true })

    local payload = EventBus.emit("smoke:hit", { amount = 5 })
    assert(payload.amount == 16, "EventBus: priority order or payload mutation broken")
    EventBus.emit("smoke:hit", { amount = 0 })
    local sequence = table.concat(order, " ")
    assert(sequence == "+3 x2 once +3 x2", "EventBus: unexpected handler order: " .. sequence)
    EventBus.unsubscribe_owner(owner)
    assert(EventBus.count("smoke:hit") == 0, "EventBus: unsubscribe_owner left listeners behind")
end

-- ── 시나리오 러너 ──────────────────────────────────────────

local function watch_events(names)
    local EventBus = require("core.EventBus")
    for _, name in ipairs(names) do
        EventBus.subscribe(name, function(payload)
            _context.events[name] = (_context.events[name] or 0) + 1
            _context.last[name] = payload
        end, { owner = SmokeTest, priority = -1000 })
    end
end

local function current_state()
    return require("core.StateManager").current_name()
end

local function tick()
    if _finished then
        return
    end
    local current = _script[_index]
    if current == nil then
        _finished = true
        if _context.shots then
            log("screenshots saved to %s", love.filesystem.getSaveDirectory())
        end
        log("PASS (%d steps)", #_script)
        love.event.quit(0)
        return
    end

    _step_frames = _step_frames + 1
    _step_started = _step_started or love.timer.getTime()
    local done = current.run(_step_frames)
    if done then
        if not current.quiet then
            log("ok %3d. %s", _index, current.label)
        end
        -- run 이 숫자를 반환하면 그만큼 다음 스텝을 건너뛴다 (조건부 시나리오)
        _index = _index + 1 + (type(done) == "number" and done or 0)
        _step_frames = 0
        _step_started = nil
    elseif love.timer.getTime() - _step_started > (current.timeout or STEP_TIMEOUT_SECONDS) then
        error(string.format("step %d '%s' timed out after %.1fs / %d frames (current state: %s)",
            _index, current.label, love.timer.getTime() - _step_started, _step_frames, tostring(current_state())), 0)
    end
end

-- main.lua 최상단에서 호출. 플래그가 없으면 아무것도 하지 않는다.
function SmokeTest.install_if_requested(raw_args)
    if require("tools.BalanceSim").install_if_requested(raw_args) then   -- --balance-sim [runs]
        return true
    end
    if not has_flag(raw_args, FLAG) then
        return false
    end
    love.errorhandler = fail_handler
    _context.shots = has_flag(raw_args, SHOTS_FLAG)
    _context.missing_assets = has_flag(raw_args, MISSING_ASSETS_FLAG)
    -- 실제 세이브(진행도·튜토리얼 완료)를 건드리지 않고, 매번 첫 실행 상태에서 검증한다
    require("systems.Progress").use_memory_only()
    require("systems.RunSave").use_memory_only()
    require("ui.DawnSummary").set_auto_confirm(0.4)      -- 새벽 정산창은 0.4초 뒤 저절로 확인 (전용 스텝은 끄고 클릭)
    require("systems.MetaProgression").use_memory_only()
    -- 설정도 메모리 전용(기본값: 한국어·창모드)으로, 검증 중에는 음소거한다 (재생 경로는 그대로 실행된다)
    local Settings = require("systems.Settings")
    Settings.use_memory_only()
    Settings.set("mute", true)

    local problems, file_count = require("tools.Lint").run()
    if #problems > 0 then
        error("lint failed:\n  " .. table.concat(problems, "\n  "), 0)
    end
    log("lint ok (%d lua files)", file_count)

    -- 기본 love.run 을 감싸 매 프레임 끝에 시나리오를 진행한다
    local default_run = love.run
    local only = only_modules(raw_args)
    love.run = function()
        local frame = default_run() -- 내부에서 love.load 실행
        if only ~= nil then
            for name in only:gmatch("[%w_]+") do
                require("tools." .. name).run(log, _context.shots, _context.missing_assets)
            end
            log("PASS (only %s)", only)
            return function() return 0 end
        end
        check_rng()
        check_event_bus()
        log("self-checks ok (RNG, EventBus)")
        require("tools.SmokeSystems").run(log, _context.missing_assets)
        require("tools.SmokeFonts").run(log)
        require("tools.SmokeText").run(log, _context.shots)
        require("tools.SmokeSim").run(_context.shots, log)
        require("tools.SmokeEconomy").run(log)
        require("tools.SmokeContracts").run(log, _context.shots)
        require("tools.SmokeGuild").run(log, _context.shots)
        require("tools.SmokeQuests").run(log, _context.shots)
        require("tools.SmokeForge").run(log, _context.shots)
        require("tools.SmokeWear").run(log)
        require("tools.SmokeCurse").run(log)
        require("tools.SmokeBalanceReport").run(log)
        require("tools.SmokeWaves").run(log, _context.shots)
        require("tools.SmokeCrowd").run(log)
        require("tools.SmokeBosses").run(log)
        require("tools.SmokeCollection").run(log, _context.missing_assets)
        require("tools.SmokeMasterTrace").run(log)                      -- '스승의 흔적' 캠페인 규칙
        require("tools.SmokeTraceScreens").run(log, _context.shots, _context.missing_assets)
        require("tools.SmokeTraceUI").run(log, _context.shots)
        require("tools.SmokeTraceBattle").run(log, _context.shots)
        require("tools.SmokeLaneHero").run(log, _context.shots, _context.missing_assets)     -- 공명 회로 · 레인의 주인공
        require("tools.SmokeHeroEquip").run(log, _context.shots, _context.missing_assets)    -- 3분류 · 주인공 장비창 · 거치대
        require("tools.SmokeTransitions").run(log)
        require("tools.SmokeAnimation").run(log, _context.shots)
        require("tools.SmokeCursor").run(log, _context.shots)
        require("tools.SmokeCursorHammer").run(log, _context.shots)
        require("tools.SmokeCombatFeel").run(log)
        require("tools.SmokeNightClock").run(log, _context.shots)
        require("tools.SmokeTitleFx").run(log, _context.shots, _context.missing_assets)

        require("tools.SmokeTutorialScenario").check_skip_saves(log)    -- 끝나면 진행도를 처음 플레이 상태로 되돌린다
        local Scenario = require("tools.SmokeScenario")
        watch_events(Scenario.WATCHED_EVENTS)
        _script = Scenario.build(_context)

        -- 빨리 감기: 프레임당 update 를 speed 번 호출 (밤 30초 대기 단축)
        local base_update = love.update
        love.update = function(dt)
            for _ = 1, _context.speed do
                base_update(dt)
            end
        end
        return function()
            local exit_code, restart = frame()
            if exit_code ~= nil then
                return exit_code, restart
            end
            tick()
        end
    end
    return true
end

return SmokeTest

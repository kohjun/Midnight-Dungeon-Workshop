-- ui/WorkshopButtons.lua
-- 공방 화면 버튼 정의: { id, label (fn), opts } 목록. 좌표는 data/layout.lua 의 buttons[id], 단축키 표기는 data/controls.lua 의 hints.
-- 버튼마다 "막는 사유" 함수(block)를 둔다: 사유 키를 반환하면 비활성(어둡게 표시·클릭 차단·눌렀을 때 사유 안내), nil 이면 활성.
-- 손님 카운터 버튼은 상황에 맞는 것만 보인다 (visible): 빈 작업대 → 새 손님·호출 / 손님 유물 → 매입·돌려보내기 / 내 유물 → 판매·보관.
-- 창(공방 개조·길드·의뢰·유물 도감·시스템 메뉴)을 여는 버튼은 input:request_modal(kind) 로 RunState 에 요청한다.
-- 낮 화면 버튼(손님 카운터·도구·용광로)은 밤에 보이지 않는다. [의뢰]는 대기 중인 제안 수를 숫자 배지로 보여 준다.
-- 과부하 레버는 밤에만 (낮에는 그 자리가 용광로 칸이라 클릭을 가로채지 않도록).
-- '스승의 흔적' 캠페인의 [수기 · 봉인진] 버튼(낮 · 밤 자리 둘)은 ui/TraceButtons 가 정의해 목록 끝에 붙는다.

local I18n = require("systems.I18n")
local Settings = require("systems.Settings")
local TransitionManager = require("ui.TransitionManager")
local TraceButtons = require("ui.TraceButtons")
local Draw = require("ui.Draw")
local BALANCE = require("data.balance")
local CONTROLS = require("data.controls")
local UI = require("data.ui")

local WorkshopButtons = {}

-- 낮에만 보이는 버튼
local DAY_ONLY = {
    new_customer = true, summon = true, buy = true, dismiss = true, sell = true, stash = true, uv = true, brush = true,
    forge = true, scroll = true,
}

local HINTS = CONTROLS.hints
local LOW_SUPPLY = BALANCE.supplies.low_warning / 100     -- supplies:low 경고와 같은 기준
local LOW_FLASH = { 1.0, 0.86, 0.78 }

-- block() → 사유 키, 변수 | nil 을 버튼 opts(enabled / disabled_message)로 바꾼다
local function gated(block, opts)
    opts.enabled = function()
        return block() == nil
    end
    opts.disabled_message = function()
        local key, vars = block()
        return key and I18n.t(key, vars) or nil
    end
    return opts
end

-- 도구 선반 타일: 켜져 있는 동안에는 언제든 다시 눌러 끌 수 있어야 한다. 아래쪽에 자원 게이지
local function tool_button(input, w, tool, kind, color, block)
    local opts = gated(function()
        if input.tool == tool then
            return nil
        end
        return block()
    end, { style = "tool", key_hint = HINTS[tool], icon = tool, layout = "tile" })
    opts.active = function() return input.tool == tool end
    opts.on_click = function() input:toggle_tool(tool) end
    opts.gauge = function()
        local value = w.supplies[kind] / w.supplies.max
        if value < LOW_SUPPLY then           -- 경고 구간: 붉게 맥동
            local pulse = 0.5 + 0.5 * math.sin(love.timer.getTime() * 7)
            return value, Draw.lerp_color(UI.color.danger, LOW_FLASH, 0.45 * pulse)
        end
        return value, color
    end
    return opts
end

local function build_blocks(w)
    local appraisal, forge = w.appraisal, w.forge
    local function bench()
        return appraisal:bench_item()
    end
    local blocks = {}
    function blocks.new_customer()
        if not w:is_day() then return "disabled.day_only" end
        if w.customers_left <= 0 then return "disabled.no_free_customers" end
        if not w:allows("new_customer") then return "disabled.finish_customer" end
    end
    function blocks.summon()
        if not w:is_day() then return "disabled.day_only" end
        if not w:allows("new_customer") then return "disabled.finish_customer" end
        local cost = appraisal:summon_cost()
        if w.gold < cost then return "disabled.cannot_summon", { cost = cost } end
    end
    function blocks.buy()
        if not w:is_day() or not appraisal:has_customer() then return "disabled.no_customer_item" end
        local price = bench():asking_price()
        if w.gold < price then return "disabled.no_gold", { price = price } end
    end
    function blocks.dismiss()
        if not w:is_day() or not appraisal:has_customer() then return "disabled.no_customer_item" end
        if not w:allows("new_customer") then return "disabled.tutorial_locked" end
    end
    function blocks.sell()
        local item = bench()
        if not w:is_day() or item == nil or not item.owned then return "disabled.nothing_to_sell" end
        if not w:allows("sell") then return "disabled.tutorial_locked" end
    end
    function blocks.stash()
        local item = bench()
        if not w:is_day() or item == nil or not item.owned then return "disabled.nothing_to_sell" end
        if w:route_item(item) == nil then return "disabled.storage_full" end
    end
    function blocks.uv()
        if not w:is_day() then return "disabled.day_only" end
        if bench() == nil then return "disabled.bench_empty" end
        if w.supplies.uv <= 0 then return "disabled.uv_empty" end
    end
    function blocks.brush()
        local item = bench()
        if not w:is_day() then return "disabled.day_only" end
        if item == nil then return "disabled.bench_empty" end
        if not item.owned then return "disabled.buy_first" end
        if item.cleaned then return "disabled.already_clean" end
        if w.supplies.water <= 0 then return "disabled.water_empty" end
    end
    function blocks.forge()
        local item = forge:furnace_item()
        if not w:is_day() then return "disabled.day_only" end
        if forge.forging ~= nil then return "disabled.forge_busy" end
        if item == nil or not item.owned then return "disabled.furnace_empty" end
        if not item:can_forge() then return "disabled.forge_max" end
        if not w:allows("forge") then return "disabled.tutorial_locked" end
        return forge:cost_block(item)         -- 골드 / 연마석(+2 부터)이 모자라면
    end
    function blocks.scroll()
        local item = bench()
        if not w:is_day() then return "disabled.day_only" end
        if w.scrolls <= 0 then return "disabled.no_scrolls" end
        if item == nil then return "disabled.bench_empty" end
        if item.revealed.complete then return "disabled.already_appraised" end
    end
    return blocks
end

function WorkshopButtons.build(input, w)
    local appraisal, forge = w.appraisal, w.forge
    local blocks = build_blocks(w)
    local function counter(state)     -- 손님 카운터 상태: "empty" | "customer" | "owned"
        return function()
            local item = appraisal:bench_item()
            local now = item == nil and "empty" or (item.owned and "owned" or "customer")
            return w:is_day() and now == state
        end
    end
    local function label(key, vars_fn)
        return function() return I18n.t(key, vars_fn and vars_fn() or nil) end
    end

    local specs = {
        { "new_customer", label("buttons.new_customer", function() return { count = math.max(0, w.customers_left) } end),
            gated(blocks.new_customer, { icon = "bell", style = "accent", visible = counter("empty"),
                on_click = function() appraisal:new_customer() end }) },
        { "summon", label("buttons.summon", function() return { cost = appraisal:summon_cost() } end),
            gated(blocks.summon, { icon = "horn", visible = counter("empty"), on_click = function() appraisal:summon_customer() end }) },
        { "buy", function()
            local item = appraisal:bench_item()
            if item == nil or item.owned then
                return I18n.t("buttons.buy_price", { price = 0 })
            end
            local list, price = item:list_price(), item:asking_price()
            if price < list then            -- 감정으로 깎은 값: "매입 78G -35%"
                return I18n.t("buttons.buy_discount", { price = price, pct = math.floor((1 - price / list) * 100 + 0.5) })
            end
            return I18n.t("buttons.buy_price", { price = price })
        end, gated(blocks.buy, { style = "accent", key_hint = HINTS.buy, icon = "buy", visible = counter("customer"),
            on_click = function() appraisal:buy() end }) },
        { "dismiss", label("buttons.dismiss"), gated(blocks.dismiss, { icon = "dismiss", visible = counter("customer"),
            on_click = function() appraisal:dismiss() end }) },
        { "sell", label("buttons.sell_price", function()
            local item = appraisal:bench_item()
            return { price = item and item.owned and w:sale_price(item) or 0 }
        end), gated(blocks.sell, { style = "accent", icon = "sell", visible = counter("owned"),
            on_click = function() appraisal:sell() end }) },
        { "stash", label("buttons.stash"), gated(blocks.stash, { icon = "stash", visible = counter("owned"), on_click = function()
            w:auto_place("bench", 1)       -- 자동 배치: 무기·유물 → 진열장 → 거치대 / 방어구 → 장착 → 거치대
        end }) },
        { "uv", label("buttons.uv"), tool_button(input, w, "uv", "uv", UI.color.uv, blocks.uv) },
        { "brush", label("buttons.brush"), tool_button(input, w, "brush", "water", UI.color.link_boost, blocks.brush) },
        { "forge", function()
            local item = forge:furnace_item()
            if item ~= nil and item:can_forge() and forge.forging == nil then        -- "+5 강화 · 52%"
                return I18n.t("buttons.forge_up", { level = item.level + 1, percent = math.floor(forge:chance(item) * 100 + 0.5) })
            end
            return I18n.t("buttons.forge")
        end, gated(blocks.forge, { style = "danger", key_hint = HINTS.forge, icon = "flame", on_click = function() forge:start() end }) },
        { "scroll", label("buttons.scroll_short", function() return { count = w.scrolls } end),
            gated(blocks.scroll, { icon = "scroll", text = "button_small", visible = function() return w:is_day() and w.scrolls > 0 end,
                on_click = function() appraisal:use_scroll() end }) },
        { "start_night", function()
            if w.phase == "night" then
                if w.combat:in_overtime() then
                    return I18n.t("buttons.night_overtime", { count = w.combat:alive_count() })
                end
                return I18n.t("buttons.night_running", { seconds = math.ceil(w.combat:time_left()) })
            end
            return I18n.t("buttons.start_night")
        end, {
            style = "accent", key_hint = HINTS.start_night, icon = "moon", emphasis = true,
            enabled = function() return w:can_start_night() end,
            on_click = function()           -- 방범 셔터가 쾅 내려온 뒤 밤이 시작된다
                TransitionManager.start("shutter_slam", function() w:start_night() end)
            end,
            disabled_message = function() return I18n.t("disabled.cannot_start_night") end,
        } },
        { "guild", label("buttons.guild"), gated(function()
            return not w:is_day() and "disabled.guild_day_only" or nil
        end, { icon = "banner", sprite = "icon_guild", on_click = function() input:request_modal("guild") end }) },
        { "quests", label("buttons.quests"), {
            icon = "quest", sprite = "icon_quest", on_click = function() input:request_modal("quests") end,
            badge = function() return w.quests:pending_total() end,
        } },
        { "compendium", label("compendium.button"), {
            icon = "gem", sprite = "icon_compendium", on_click = function() input:request_modal("compendium") end,
        } },
        { "upgrades", label("buttons.upgrades"), gated(function()
            return not w:is_day() and "disabled.upgrades_day_only" or nil
        end, { icon = "hammer", sprite = "icon_upgrade", on_click = function() input:request_modal("upgrades") end }) },
        { "settings", label("buttons.settings"), {
            key_hint = HINTS.settings, icon = "gear", sprite = "icon_settings",
            on_click = function() input:request_modal("menu") end,
        } },
        { "speed", function() return I18n.t("buttons.speed_" .. Settings.get("night_speed")) end, {
            style = "tool", key_hint = HINTS.speed, visible = function() return w.phase == "night" end,
            active = function() return Settings.get("night_speed") > 1 end,
            on_click = function() Settings.set("night_speed", Settings.get("night_speed") % 3 + 1) end,     -- 1x → 2x → 3x → 1x
        } },
        { "overclock", "", {
            hidden = true, key_hint = HINTS.overclock, visible = function() return w.phase == "night" end,
            enabled = function() return w.phase == "night" and w.result == nil end,
            on_click = function() w:set_overclock(not w.combat.overclock) end,
            disabled_message = function() return I18n.t("disabled.overclock_night_only") end,
        } },
    }
    for _, spec in ipairs(TraceButtons.build(input, w)) do     -- '스승의 흔적' [수기 · 봉인진] (그 계약에서만 보인다)
        specs[#specs + 1] = spec
    end
    for _, spec in ipairs(specs) do             -- 낮 화면 버튼은 밤에 숨긴다
        local id, opts = spec[1], spec[3]
        if DAY_ONLY[id] then
            local own = opts.visible
            opts.visible = function()
                return w.phase ~= "night" and (own == nil or own())
            end
        end
    end
    return specs
end

return WorkshopButtons

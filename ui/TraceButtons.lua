-- ui/TraceButtons.lua
-- '스승의 흔적' 캠페인 전용 공방 버튼 정의 (ui/WorkshopButtons 가 목록 끝에 붙인다 — 같은 { id, label (fn), opts } 형식).
--   journal       : 낮 — 오른쪽 진열장 머리줄 오른쪽 [수기 N/6 · 봉인진 N/4]
--   journal_night : 밤 — 전투 레인 왼쪽 위 (새벽 진행 막대 아래)
-- 둘 다 workshop.master_trace 가 있는 런(master_trace 계약)에서만 보이고, 누르면 [수기] 창(ui/MasterJournalModal)을 연다
-- (input:request_modal("journal") → ui/RunOverlays). 새로 열린 수기가 있으면 숫자 배지 (창을 열면 사라진다).
-- 좌표는 data/layout.lua 의 buttons.journal · buttons.journal_night.

local I18n = require("systems.I18n")
local MasterJournalModal = require("ui.MasterJournalModal")

local TraceButtons = {}

-- 버튼 글자: "수기 2/6 · 봉인진 1/4" (master_trace 런이 아니면 빈 글자 — 보이지 않는다)
function TraceButtons.label(workshop)
    local trace = workshop.master_trace
    if trace == nil then
        return ""
    end
    local status = trace:status()
    return I18n.t("trace.button", { journals = status.journals, total = status.journal_total, lit = status.lit,
        slots = status.slots })
end

function TraceButtons.build(input, w)
    local function spec(id, night)
        return { id, function() return TraceButtons.label(w) end, {
            icon = "book", style = "tool",
            visible = function() return w.master_trace ~= nil and (w.phase == "night") == night end,
            on_click = function() input:request_modal("journal") end,
            badge = function() return MasterJournalModal.unread(w) end,
        } }
    end
    return { spec("journal", false), spec("journal_night", true) }
end

return TraceButtons

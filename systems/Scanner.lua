-- systems/Scanner.lua
-- UV 감정 판정: 렌즈가 유물 중심을 덮으면 등급, 결함 표식 근처를 지나면 결함을 드러낸다.
-- 렌즈는 UV 모드에서 왼쪽 버튼을 누르고 있는 동안에만 켜진다 — 켜짐 판정과 배터리 소모는 Appraisal:scan 이 맡고,
-- 여기 scan() 은 렌즈가 켜져 있는 프레임에만 호출된다.
-- 4x4 샘플 지점의 커버리지가 기준 이상이면 정밀 스캔 완료 (숨은 결함도 이때 반드시 드러난다).
-- 스승의 은빛 인장(item.silver_seal — '스승의 흔적' 캠페인, systems/MasterTrace)은 결함처럼 렌즈가 표식 근처를 지나거나
-- 렌즈로 정밀 스캔을 끝내면 드러난다 (appraisal:seal_revealed). UV 로만 보인다 — 즉시 감정 주문서로는 드러나지 않는다.

local EventBus = require("core.EventBus")
local BALANCE = require("data.balance")

local Scanner = {}

-- 정밀 스캔 커버리지 판정용 4x4 샘플 지점 (유물 정규화 좌표)
local SCAN_POINTS = {}
for row = 1, 4 do
    for col = 1, 4 do
        SCAN_POINTS[#SCAN_POINTS + 1] = { x = (col - 2.5) * 0.25, y = (row - 2.5) * 0.25 }
    end
end

local function distance_sq(ax, ay, bx, by)
    local dx, dy = ax - bx, ay - by
    return dx * dx + dy * dy
end

function Scanner.coverage(item)
    local covered = 0
    for i = 1, #SCAN_POINTS do
        if item.scan_points[i] then
            covered = covered + 1
        end
    end
    return covered / #SCAN_POINTS
end

function Scanner.reveal_grade(item, cx, cy)
    if not item.revealed.grade then
        item.revealed.grade = true
        EventBus.emit("appraisal:grade_revealed", { item = item, x = cx, y = cy })
        if not item.owned and item:is_forgery_revealed() then      -- 손님이 등급을 부풀렸다: 위조 적발
            EventBus.emit("appraisal:forgery_revealed", { item = item, x = cx, y = cy })
        end
    end
end

function Scanner.reveal_flaw(item, cx, cy, size)
    if item.flaw ~= nil and not item.revealed.flaw then
        item.revealed.flaw = true
        EventBus.emit("appraisal:flaw_revealed", {
            item = item, x = cx + item.flaw_mark.x * size, y = cy + item.flaw_mark.y * size,
        })
    end
end

function Scanner.reveal_seal(item, cx, cy, size)
    local seal = item.silver_seal
    if seal ~= nil and not item.revealed.seal then
        item.revealed.seal = true
        EventBus.emit("appraisal:seal_revealed", { item = item, x = cx + seal.x * size, y = cy + seal.y * size })
    end
end

function Scanner.complete(item, cx, cy, size)
    if item.revealed.complete then
        return
    end
    item.revealed.complete = true
    Scanner.reveal_flaw(item, cx, cy, size)
    EventBus.emit("appraisal:scan_complete", { item = item, flawless = item.flaw == nil, x = cx, y = cy })
end

-- 즉시 감정 주문서: 모든 정보를 한 번에 공개
function Scanner.reveal_all(item, cx, cy, size)
    for i = 1, #SCAN_POINTS do
        item.scan_points[i] = true
    end
    Scanner.reveal_grade(item, cx, cy)
    Scanner.complete(item, cx, cy, size)
end

-- item 을 (cx, cy) 중심·size 크기로 그렸을 때, 켜진 렌즈(반경 radius_px, 중심 (x, y))로 한 프레임 스캔.
-- 렌즈가 유물에 닿아 있으면 true
function Scanner.scan(item, x, y, cx, cy, size, radius_px)
    local settings = BALANCE.appraisal
    local lx, ly = (x - cx) / size, (y - cy) / size
    local radius = (radius_px or settings.scan_radius) / size
    if math.abs(lx) > 0.5 + radius or math.abs(ly) > 0.5 + radius then
        return false
    end

    for i, point in ipairs(SCAN_POINTS) do
        if not item.scan_points[i] and distance_sq(point.x, point.y, lx, ly) <= radius * radius then
            item.scan_points[i] = true
        end
    end
    if distance_sq(0, 0, lx, ly) <= radius * radius then
        Scanner.reveal_grade(item, cx, cy)
    end
    local reveal_radius = radius * settings.flaw_reveal_ratio
    if item.flaw ~= nil and distance_sq(item.flaw_mark.x, item.flaw_mark.y, lx, ly) <= reveal_radius * reveal_radius then
        Scanner.reveal_flaw(item, cx, cy, size)
    end
    if Scanner.coverage(item) >= settings.scan_complete_ratio then
        Scanner.complete(item, cx, cy, size)
    end
    local seal = item.silver_seal
    if seal ~= nil and (item.revealed.complete or distance_sq(seal.x, seal.y, lx, ly) <= reveal_radius * reveal_radius) then
        Scanner.reveal_seal(item, cx, cy, size)
    end
    return true
end

return Scanner

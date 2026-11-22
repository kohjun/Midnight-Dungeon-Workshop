-- systems/RunSave.lua
-- 진행 중인 런 저장/복원 ([이어하기]). 세이브 디렉토리의 save_run.lua 에 평범한 Lua 테이블로 쓴다.
--   capture(workshop): 공방(일차·골드·연마석·방벽·자원 등)과 하위 시스템들의 "평범한 값" 필드, 보관함·진열장·작업대·용광로의 유물,
--     RNG 상태를 담는다. 함수·다른 객체 참조(공방 자신·난수 스트림 등)는 버리고, 유물(Item)은 번호로 한 번만 담아 같은 유물을
--     가리키던 곳이 복원 뒤에도 같은 객체를 가리키게 한다. 유물의 proto(데이터 원형)는 proto_id 로 다시 잇는다.
--   밤 도중에 저장하면 밤이 시작되기 직전(영업 마감 직전)의 스냅숏(phase:night_starting 에서 잡은 것)을 쓴다 → 그 밤을 다시 치른다.
--   restore(workshop, data): RNG 상태를 먼저 되돌린 뒤(RunState) 새로 만든 공방에 값을 되붓고 유물을 제자리에 놓는다
--     (Inventory:place 로 놓아 유물 효과 구독도 다시 걸린다).
--   옛 저장(OLDEST ~ VERSION - 1)은 migrate 가 지금 형식으로 고쳐 읽는다 — 2 → 3: 유물 내구도 정수 칸(최대 1~3) → 0~100%,
--   3 → 4: '스승의 흔적' 캠페인(master_trace 하위 시스템 — 수기 · 인장 Pity · 점화 · 최종 보스 결과, 유물의 silver_seal)이 생겼다
--   (그 전 저장에는 캠페인 런이 없으므로 고칠 것이 없다). 없는 하위 시스템(일반 계약의 master_trace)은 건너뛴다.
-- 스모크 테스트는 use_memory_only() 로 디스크를 건드리지 않는다.

local RNG = require("core.RNG")
local Item = require("entities.Item")
local DURABILITY = require("data.durability")

local RunSave = {}

local FILE = "save_run.lua"
local VERSION = 5          -- 5: 3분류 · 주인공 장비창("hero" 4칸) · 임시 거치대(보관함 4칸 → 3칸) / 4: 스승의 흔적 캠페인 /
                          -- 3: +10 강화 · 0~100% 내구도 / 2: 5단계 난이도 · 장기 달력 · 의뢰 게시판
local OLDEST = 2           -- 이보다 오래된 저장은 이어하기 목록에서 빠진다
RunSave.VERSION = VERSION
local MAX_DEPTH = 14
local AREAS = { "storage", "grid", "bench", "furnace", "hero" }
local FIELDS = { "day", "gold", "tempering_stones", "max_hp", "hp", "phase", "customers_left", "summons_today", "scrolls",
    "stats", "unlocked_relics", "_pending_income" }
local SUBSYSTEMS = { "supplies", "upgrades", "tribute", "shop", "black_market", "quests", "achievements", "appraisal", "forge",
    "drops", "master_trace" }
local ITEM_SKIP = { proto = true }

local _persist = true
local _memory = nil

-- ── 값 복사 (저장) ─────────────────────────────────────────
local capture_value

local function copy_table(value, ctx, depth, skip)
    local out = {}
    for key, inner in pairs(value) do
        local key_type = type(key)
        if (key_type == "string" or key_type == "number") and not (skip and skip[key]) then
            local copied = capture_value(inner, ctx, depth + 1)
            if copied ~= nil then
                out[key] = copied
            end
        end
    end
    return out
end

capture_value = function(value, ctx, depth)
    local kind = type(value)
    if kind == "number" or kind == "string" or kind == "boolean" then
        return value
    elseif kind ~= "table" or depth > MAX_DEPTH then
        return nil
    end
    local meta = getmetatable(value)
    if meta == Item then
        local id = ctx.ids[value]
        if id == nil then
            id = #ctx.items + 1
            ctx.ids[value] = id
            ctx.items[id] = false
            ctx.items[id] = copy_table(value, ctx, depth, ITEM_SKIP)
        end
        return { __item = id }
    elseif meta ~= nil then
        return nil
    end
    return copy_table(value, ctx, depth)
end

-- ── 값 되붓기 (복원) ─────────────────────────────────────────
local function restore_value(value, objects)
    if type(value) ~= "table" then
        return value
    elseif value.__item ~= nil then
        return objects[value.__item]
    end
    local out = {}
    for key, inner in pairs(value) do
        out[key] = restore_value(inner, objects)
    end
    return out
end

function RunSave.capture(workshop, extra)
    local ctx = { ids = {}, items = {} }
    local data = { version = VERSION, fields = {}, systems = {}, slots = {} }
    for _, key in ipairs(FIELDS) do
        data.fields[key] = capture_value(workshop[key], ctx, 0)
    end
    for _, name in ipairs(SUBSYSTEMS) do
        if workshop[name] ~= nil then
            data.systems[name] = capture_value(workshop[name], ctx, 0) or copy_table(workshop[name], ctx, 0)
        end
    end
    for _, area in ipairs(AREAS) do
        data.slots[area] = {}
        for index = 1, workshop.inventory:size(area) do
            local item = workshop.inventory:get(area, index)
            if item ~= nil then
                data.slots[area][index] = capture_value(item, ctx, 0)
            end
        end
    end
    data.items = ctx.items
    for key, value in pairs(extra or {}) do
        data[key] = value
    end
    return data
end

function RunSave.restore(workshop, data)
    local objects, max_uid = {}, 0
    for id, plain in ipairs(data.items or {}) do
        local item = setmetatable({}, Item)
        objects[id] = item
        max_uid = math.max(max_uid, plain.uid or 0)
    end
    for id, plain in ipairs(data.items or {}) do               -- 유물끼리 서로 가리켜도 같은 객체가 되게 두 번에 나눈다
        local item = objects[id]
        for key, value in pairs(plain) do
            item[key] = restore_value(value, objects)
        end
        item.proto = Item.prototype(item.proto_id)
        assert(item.proto ~= nil, "RunSave: unknown relic '" .. tostring(item.proto_id) .. "'")
    end
    Item.reserve_uid(max_uid)
    for key, value in pairs(data.fields or {}) do
        workshop[key] = restore_value(value, objects)
    end
    for name, fields in pairs(data.systems or {}) do
        local system = workshop[name]
        for key, value in pairs(system and fields or {}) do
            system[key] = restore_value(value, objects)
        end
    end
    local homeless = {}
    for _, area in ipairs(AREAS) do
        for index, ref in pairs(data.slots and data.slots[area] or {}) do
            local item, slot = objects[ref.__item], tonumber(index)
            if slot <= workshop.inventory:size(area) then
                workshop.inventory:place(item, area, slot)
            else
                homeless[#homeless + 1] = { slot = slot, item = item }     -- 예전 저장(보관함 4칸)의 넘치는 칸
            end
        end
    end
    table.sort(homeless, function(a, b) return a.slot < b.slot end)
    for _, entry in ipairs(homeless) do
        RunSave.rehome(workshop, entry.item)
    end
end

-- 칸이 없어진 유물을 안전하게 옮긴다: 자동 배치(진열장 빈칸 → 임시 거치대) → 빈 작업대 → 그래도 없으면 판매가만큼 골드로
function RunSave.rehome(workshop, item)
    if workshop:store_item(item) ~= nil then
        return "placed"
    elseif workshop.inventory:get("bench", 1) == nil then
        workshop.inventory:place(item, "bench", 1)
        return "bench"
    end
    workshop.gold = workshop.gold + item:sale_value()
    return "refunded"
end

-- 지금 공방 + 다시 만들 때 필요한 것(난이도 · 이름 · 영구 강화 · RNG 상태)
function RunSave.snapshot(workshop)
    return RunSave.capture(workshop, {
        difficulty = workshop.difficulty_id, name = workshop.owner_name, meta = workshop.meta, rng = RNG.get_state(),
    })
end

-- 저장된 런으로 새 공방을 만든다: RNG 상태를 먼저 되돌려야 하위 시스템이 되돌린 난수 스트림을 잡는다
function RunSave.resume(data, Workshop)
    RNG.set_state(data.rng)
    local workshop = Workshop({ difficulty = data.difficulty, name = data.name, meta = data.meta })
    RunSave.restore(workshop, data)
    return workshop
end

-- ── 직렬화 · 디스크 ─────────────────────────────────────────
local function serialize(value, out)
    local kind = type(value)
    if kind == "table" then
        out[#out + 1] = "{"
        for key, inner in pairs(value) do
            out[#out + 1] = type(key) == "number" and string.format("[%.17g]=", key) or string.format("[%q]=", key)
            serialize(inner, out)
            out[#out + 1] = ","
        end
        out[#out + 1] = "}"
    elseif kind == "string" then
        out[#out + 1] = string.format("%q", value)
    elseif kind == "number" then
        out[#out + 1] = string.format("%.17g", value)
    else
        out[#out + 1] = tostring(value)
    end
end

function RunSave.serialize(data)
    local out = { "return " }
    serialize(data, out)
    return table.concat(out)
end

-- 2 → 3: 유물 내구도가 정수 칸(최대 1~3, 과열마다 -1)에서 0~100% 로 바뀌었다 — 남은 비율 그대로 옮긴다
local function migrate(data)
    if data.version < 3 then
        for _, plain in ipairs(data.items or {}) do
            if type(plain) == "table" then
                local old_max = tonumber(plain.max_durability) or 0
                local ratio = old_max > 0 and (tonumber(plain.durability) or old_max) / old_max or 1
                plain.durability = math.max(0, math.min(1, ratio)) * DURABILITY.max
                plain.max_durability = DURABILITY.max
            end
        end
        data.version = 3
    end
    -- 3 → 4: 고칠 것 없음 / 4 → 5: 보관함 4번 칸의 유물은 restore 가 진열장·임시 거치대로 옮긴다 (rehome)
    data.version = math.max(data.version, VERSION)
    return data
end

function RunSave.deserialize(text)
    local chunk = loadstring(text)
    if chunk == nil then
        return nil
    end
    setfenv(chunk, {})
    local ok, data = pcall(chunk)
    if not ok or type(data) ~= "table" or type(data.version) ~= "number" or data.version < OLDEST or data.version > VERSION then
        return nil
    end
    return migrate(data)
end

function RunSave.use_memory_only()
    _persist, _memory = false, nil
end

function RunSave.write(data)
    if not _persist then
        _memory = RunSave.serialize(data)
        return
    end
    local ok, err = love.filesystem.write(FILE, RunSave.serialize(data))
    if not ok then
        print("[RunSave] failed to save: " .. tostring(err))
    end
end

-- 저장된 런 (없거나 깨졌으면 nil)
function RunSave.load()
    local text = _memory
    if _persist and love.filesystem.getInfo(FILE) ~= nil then
        text = love.filesystem.read(FILE)
    end
    return text and RunSave.deserialize(text) or nil
end

function RunSave.exists()
    return RunSave.load() ~= nil
end

function RunSave.clear()
    _memory = nil
    if _persist and love.filesystem.getInfo(FILE) ~= nil then
        love.filesystem.remove(FILE)
    end
end

return RunSave

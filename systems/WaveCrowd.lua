-- systems/WaveCrowd.lua
-- 하룻밤 몬스터 수 상한 (data/waves.lua 의 crowd_cap) — systems/WaveSpawner 가 부른다.
--   계획 물량 = 일반 스폰(스폰 창 동안의 간격 횟수 × 한 번에 나오는 수) + 돌격 무리. 상한 per_night 를 넘으면 넘는 비율
--   r = 계획 / 상한 만큼 마릿수를 1/r 로 줄이고, 대신 정예 가중치를 x(1 + elite_weight × (r - 1)) 로 올린 뒤
--   개별 체력 배율 hp_mult = 1 + hp_share × (r × 원래 평균 체력 / 정예를 늘린 평균 체력 - 1) 을 곱한다. hp_share = 1 이면 그 밤의
--   총 체력(계획 물량 × 평균 체력)이 그대로다 — 다만 적고 단단한 몬스터는 연쇄·범위 무기에 덜 맞아 더 어려워지므로, 밸런스 시뮬로
--   맞춘 hp_share(1 보다 작게)로 실제 전투 난이도를 예전과 같게 둔다. 우두머리는 상한 밖, 소환은 그 밤 전체 total 까지 (Combat:summon).
--   상한 안의 밤(r = 1)은 예전과 똑같이 나온다 (마릿수 · 구성 · 체력 · 난수 소비 모두).

local ENEMIES = require("data.enemies")
local WAVES = require("data.waves")

local WaveCrowd = {}

-- 일반 스폰 간격(초)과 한 번에 나오는 수
function WaveCrowd.interval(wave_day)
    return math.max(WAVES.interval_min, WAVES.interval_start - WAVES.interval_decay * (wave_day - 1))
end

function WaveCrowd.group(wave_day)
    return 1 + math.floor((wave_day - 1) / WAVES.group_every_days)
end

-- 돌격 무리 하나의 계획 마릿수 (상한 전)
function WaveCrowd.pack_size(pack, wave_day)
    return math.floor(pack.count + pack.per_day * (wave_day - 1))
end

-- 그 실효 일차 밤의 계획 물량 (일반 + 돌격 무리, 상한 전 — 우두머리·소환 제외)
function WaveCrowd.planned(wave_day)
    local events = math.floor((WAVES.spawn_window - WAVES.first_delay) / WaveCrowd.interval(wave_day)) + 1
    local packs = 0
    for _, pack in ipairs(WAVES.packs) do
        packs = packs + WaveCrowd.pack_size(pack, wave_day)
    end
    return events * WaveCrowd.group(wave_day) + packs
end

-- 가중치로 본 평균 기본 체력 (entries = { { id, weight } })
local function average_hp(entries)
    local hp, weight = 0, 0
    for _, entry in ipairs(entries) do
        hp = hp + entry.weight * ENEMIES.monsters[entry.id].hp
        weight = weight + entry.weight
    end
    return weight > 0 and hp / weight or 1
end

-- 그 밤의 상한 계획 { planned, cap, ratio, elite_mult, hp_mult }. entries(웨이브 구성)의 정예 가중치를 그 자리에서 올린다
function WaveCrowd.apply(entries, wave_day)
    local cap = WAVES.crowd_cap
    local planned = WaveCrowd.planned(wave_day)
    local ratio = math.max(1, planned / cap.per_night)
    if ratio <= 1 then
        return { planned = planned, cap = cap.per_night, ratio = 1, elite_mult = 1, hp_mult = 1 }
    end
    local elite_mult = 1 + cap.elite_weight * (ratio - 1)
    local base = average_hp(entries)
    for _, entry in ipairs(entries) do
        if ENEMIES.monsters[entry.id].elite then
            entry.weight = entry.weight * elite_mult
        end
    end
    return { planned = planned, cap = cap.per_night, ratio = ratio, elite_mult = elite_mult,
        hp_mult = 1 + cap.hp_share * (ratio * base / average_hp(entries) - 1) }
end

return WaveCrowd

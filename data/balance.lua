-- data/balance.lua
-- 공방 경제·감정·세척·용광로·자원·상납금 밸런스 수치. 로직 없음.

return {
    -- 생존 일수·초기 자금·내구도는 난이도별 (data/difficulties.lua)
    workshop = {
        customers_per_day = 3,      -- 하루 무료 손님 수
        storage_slots = 3,          -- 임시 거치대 칸 수 (Inventory "storage" — 방어구 교체 · 강화 대기 · 진열장 만석 때)
        -- 시작 지급 유물: 튜토리얼이 아닌 런은 진열장 cell 칸에 이 유물을 두고 시작한다 (무기 없이 밤을 맞는 소프트락 방지)
        starter_items = { { id = "flame_sword", grade = "common", cell = 12 } },
        summon = {                  -- [새 모험가 호출]: 같은 날 부를수록 비싸진다 (다음 날 초기화)
            base_cost = 25,
            step_cost = 15,
            min_cost = 5,
        },
    },

    customer = {
        ask_ratio = 0.8,            -- 손님 제시가 = 원형 가치 × 주장 등급 배율 × 0.8
        flaw_discount = 0.5,        -- 결함을 찾아내면 제시가 × 0.5
        forgery_discount = 0.9,     -- 등급 위조를 들키면 진짜 등급 값에서 다시 × 0.9 (손님이 체면을 지키려 더 깎아 준다)
        honest_chance = 0.6,        -- 등급을 정직하게 말할 확률
        overclaim_chance = 0.5,     -- 거짓말일 때 부풀려 말할 확률 (나머지는 낮춰 말함)
        flaw_chance = 0.4,
        contamination = { min = 25, max = 95 },   -- 오염도(%)
        grime_spots = { min = 6, max = 11 },
    },

    appraisal = {
        scan_radius = 60,           -- UV 렌즈 반경(px)
        flaw_reveal_ratio = 0.75,   -- 결함 표식이 렌즈 반경의 이 비율 안에 들어오면 발견
        scan_complete_ratio = 0.85, -- 스캔 커버리지가 이 이상이면 정밀 스캔 완료
        scrub_per_pixel = 0.07,     -- 문지른 거리 1px 당 오염도 감소(%p)
        clean_mult = 1.5,           -- 오염도 0% 달성 시 판매가·공격력 배율 (고압 브러시로 상향)
    },

    -- UV 배터리 · 정화수 (0~100%)
    supplies = {
        start = 100,
        max = 100,
        morning_refill = 20,            -- 매일 아침 각각 +20%
        -- 소모량 (난이도 supply_mult 를 곱한다 — 어려움 x1.1 · 악몽 x1.2). 화면 문구는 실제 값(Appraisal)을 그대로 보여 준다
        uv_drain_per_second = 10.8,     -- 렌즈가 켜져 있는 동안(버튼 홀드) 초당 소모(%)
        water_per_contamination = 0.36, -- 오염도 1%p 제거당 정화수 소모(%) — 10% 제거 = 3.6%, 완세척(100%) = 36%
        low_warning = 25,               -- 이 % 아래로 떨어지는 순간 경고(supplies:low — 토스트·경고음·게이지 맥동)
        drop_chance = 0.18,             -- 일반 몬스터 처치 시 UV 또는 정화수 드랍 확률
        drop_amount = 12,
        boss_drop = 35,                 -- 보스 처치 시 UV·정화수 각각 확정
    },

    -- 결계 유지비 (던전 관리 길드): 매달 말일(every 일마다) 밤이 끝난 새벽에 징수. 미달 시 즉시 퇴거(파산).
    -- 금액 = amounts[달] × 난이도 tribute_mult × 그 달 계절의 tribute_mult(겨울, data/calendar.lua). 계약 기간 안의 날짜만 징수한다.
    -- amounts 보다 긴 계약이면 마지막 값에서 after_step 씩 더한다
    tribute = {
        every = 10,
        amounts = { 800, 2200, 4000, 6200, 8800, 11800, 14800, 17800, 20800, 23800, 26800, 29800 },
        after_step = 3000,
        warn_days_before = 1,           -- D-1 부터 상단 경고 배너
    },

    -- 연마석 (용광로 +2 이상 강화 재화): 밤 처치 드랍 · 보스·중간 보스 확정 · 길드 상점(하루 제한) · 길드 의뢰 보상.
    -- 강화 템포(하루 1~2회)를 정하는 재화라 무작위 드랍은 한 밤에 night_cap 개까지만 (보스·중간 보스 확정분은 제외, systems/Drops)
    stones = {
        start = 0,
        drop_chance = 0.003,            -- 일반 몬스터 처치 시
        elite_chance = 0.04,            -- 엘리트(data/enemies 의 elite = true) 처치 시
        night_cap = 1,                  -- 한 밤의 무작위 드랍 상한
        boss_drop = 1,                  -- 보스 처치 시 확정
    },

    -- 저주 유물의 밤마다 방벽 대가(피의 대가 · 피의 계약): 한 밤에 모두 합쳐 night_cap 까지만 깎인다 (systems/WorkshopEconomy —
    -- 상한을 넘긴 대가는 받지 않고, 계약 골드도 실제로 바친 만큼만). 상한은 HP 1 당 골드가 큰 계약부터 쓰고 단검은 맨 나중
    -- (CurseEffects.hp_for_gold 의 구독 우선순위 — 진열 순서와 무관). 새벽 무피해 보너스 판정에는 넣지 않는다.
    curse = { night_cap = 3 },

    -- 새벽 방벽 무피해 보너스: 그 밤에 방벽이 한 번도 피해를 입지 않았으면 새벽 정산(ui/DawnSummary · DayCycle)에서 지급
    dawn = { flawless_base = 5, flawless_per_day = 2 },      -- 골드 = base + per_day × 일차

    economy = {
        daily_income_ratio = 0.25,  -- 일일 수익 = 기본 판매가(원형 가치 × 감정 등급 × 결함) × 비율
        kill_gold_mult = 0.45,      -- 밤 처치 골드 = 몬스터 gold(data/combat) × 이 배율 × 과부하 골드 배율 (감정·매매가 주 수입)
    },
}

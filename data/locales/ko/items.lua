-- data/locales/ko/items.lua
-- 유물 원형·등급·분류·아키타입·속성·결함·몬스터 이름과 설명 (한국어). 로직 없음.
-- 키는 data/items.lua · data/combat.lua 의 id 와 같다. label 은 인접 시너지 보너스 문구.

return {
    grades = { common = "일반", rare = "희귀", legendary = "전설" },
    categories = { weapon = "무기", armor = "방어구", relic = "유물", amplifier = "유물(증폭기)" },
    archetypes = { fire = "화염/연소", lightning = "번개/과속", curse = "저주/혈마법", gold = "황금/상인" },
    elements = { fire = "화염", ancient = "고대", arcane = "증폭" },

    flaws = {
        crack = { name = "균열", summary = "내구도 마모 x1.6 · 가치 -40%" },
        curse = { name = "저주", summary = "자신 공격 +50% · 인접 유물 공격 -25% · 가치 -50%", label = "저주 공격 -25%" },
    },

    monsters = {
        slime = "슬라임", goblin = "고블린", ogre = "오우거", shield_bearer = "중장갑 방패병", shadow_assassin = "그림자 암살자",
        skeleton = "해골 병사", gatekeeper_golem = "던전 문지기 골렘", greed_raider = "탐욕의 고블린 약탈자",
        abyss_necromancer = "심연의 사령술사", rift_lord = "차원의 균열 군주",
        mid_vanguard = "철갑 선봉장", mid_raider = "약탈 대장", mid_hexer = "역병 주술사", mid_stalker = "균열 추적자",
        boss_master = "균열의 잔영",
    },

    items = {
        flame_sword = { name = "화염 검", description = "고화력 화염탄. 적중 시 2.5초간 불태우고(초당 4) 주변 적에게 피해 35% 화염 스플래시." },
        lightning_orb = {
            name = "연쇄 번개 오브",
            description = "피해는 낮지만 주변 적 3마리에게 번개가 연쇄되고, 감전(받는 피해 +20%)·경직을 건다.",
        },
        frost_crossbow = { name = "서리 석궁", description = "적중한 적을 1.5초간 50% 둔화시킨다." },
        cursed_dagger = { name = "저주받은 단검", description = "강력하지만 매일 밤 방벽 내구도를 1 빼앗는다. (저주 대가는 한 밤에 모두 합쳐 최대 3)" },
        mana_crystal = {
            name = "마력 증폭 수정", description = "상하좌우 무기의 공격력과 연사 속도 +50%.",
            label = "공격 +50% · 연사 +50%",
        },
        tuning_fork = { name = "공명 소리굽쇠", description = "상하좌우 무기의 연사 속도 +80%.", label = "연사 +80%" },
        rune_tablet = {
            name = "고대 룬 석판", description = "상하좌우 모든 유물의 공격력 +25%, 일일 수익 +50%.",
            label = "공격 +25% · 수익 +50%",
        },
        golden_chalice = { name = "고대 황금 성배", description = "진열장 전체의 일일 수익 +30%.", label = "수익 +30%" },
        guardian_crest = { name = "수호자의 문장", description = "방벽이 받는 피해 -30%." },
        greed_pouch = { name = "탐욕의 금화 주머니", description = "몬스터 처치 골드 +50%." },
        inferno_musket = { name = "폭염 화승총", description = "적중 시 주변 적에게 피해 40% 화염 스플래시. 화상 3중첩된 적을 폭발시켜 주변에 45 피해." },
        ember_brazier = {
            name = "잉걸불 화로", description = "상하좌우 무기 공격 +20%, 그 무기의 적중에 화상을 더한다.",
            label = "공격 +20% · 화상 부여",
        },
        phoenix_feather = { name = "불사조 깃털", description = "모든 화상 피해 +60%." },
        magma_core = { name = "용암 핵", description = "불타는 적이 죽으면 주변에 30 폭발 피해 (연쇄 가능)." },
        storm_rod = { name = "폭풍 피뢰침", description = "적중 시 감전·경직. 진열장 무기가 25회 발사할 때마다 모든 적에게 낙뢰 24." },
        overdrive_coil = {
            name = "과속 코일", description = "상하좌우 무기의 연사 +35%, 공격 +10%.",
            label = "연사 +35% · 공격 +10%",
        },
        cooling_fins = { name = "냉각 핀", description = "과부하 마모 가속 -50%." },
        bloodstone_idol = { name = "혈석 우상", description = "진열장의 저주 유물 1개마다 모든 무기 공격 x1.2 (곱연산)." },
        hex_scythe = { name = "저주 낫", description = "저주받은 고화력 무기. 처치할 때마다 방벽 내구도 +1." },
        grave_lantern = { name = "묘지 등불", description = "저주받았지만 상하좌우 무기 공격 +80%.", label = "공격 +80%" },
        blood_pact_scroll = { name = "피의 계약서", description = "매일 밤 방벽 내구도 2를 바쳐 30 G를 얻는다. (저주 대가는 한 밤에 합쳐 최대 3, 넘치면 바친 만큼만)" },
        midas_gauntlet = { name = "미다스의 건틀릿", description = "보유 골드 500 G마다 공격력 +100% (최대 +200%). 묵직한 일격이 적을 포탈 쪽으로 밀어낸다." },
        merchant_scale = { name = "상인의 저울", description = "모든 판매가 +15%." },
        coin_golem = { name = "동전 골렘", description = "이 무기로 처치할 때마다 골드 +3. 맞은 적을 포탈 쪽으로 밀어낸다." },
        -- 업적 해금 특수 유물 (data/achievements.lua)
        starforge_hammer = { name = "별똥별 단조 망치", description = "3초간 불태우는 화염탄(초당 5)이 적을 크게 밀어낸다. 불타는 적이 죽으면 주변에 28 폭발." },
        bloodmoon_chalice = {
            name = "핏빛 달 성배",
            description = "저주 유물 1개마다 모든 무기 공격 x1.15. 매일 밤 방벽 내구도 1을 바쳐 30 G를 얻는다. (저주 대가는 한 밤에 합쳐 최대 3, 넘치면 바친 만큼만)",
        },
        abyss_crown = { name = "심연의 왕관", description = "저주받았지만 상하좌우 무기 공격 +120%, 연사 +15%.", label = "공격 +120% · 연사 +15%" },
        golem_heart = { name = "문지기의 심장석", description = "방벽이 받는 피해 -35%. 진열장 전체 일일 수익 +15%.", label = "수익 +15%" },
        raider_sack = { name = "약탈자의 끝없는 자루", description = "몬스터 처치 골드 +80%. 모든 판매가 +10%." },
        necro_codex = { name = "사령술사의 금서", description = "서리 광선: 2마리에게 연쇄·둔화. 처치할 때마다 방벽 내구도 +1." },
        rift_prism = {
            name = "균열 프리즘", description = "상하좌우 무기 공격·연사 +35%. 과부하 마모 가속 -40%.", label = "공격 +35% · 연사 +35%",
        },
        tycoon_ledger = { name = "대상인의 금장부", description = "진열장 전체 일일 수익 +40%. 모든 판매가 +12%.", label = "수익 +40%" },
    },
}

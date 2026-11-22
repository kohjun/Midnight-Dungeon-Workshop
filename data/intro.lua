-- data/intro.lua
-- 게임 시작 인트로(states/IntroState) — 7장면 · 14비트 2.5D 모션 코믹스 시간표·카메라·배치. 로직 없음.
--   1. peace    : 스승의 감정 공방 — assets/intro/cut1.png 켄 번스 + 촛불 불티
--   2. storm    : 마나 폭풍이 절벽을 갈라 공방 옆에 균열 포탈 — 보라 벼락·흔들림, 길드의 결계
--   3. defense  : 스승이 진열장의 유물로 밤마다 괴물을 막아 낸다 (화염검·번개 오브)
--   4. vanish   : 스승이 포탈 너머로 사라지고 빈 공방만 남는다 — 사람이 없는 공방 실내(day_workshop.png) + 차가운 푸른빛, 식어 가는 벽난로 불씨
--   5. contract : 주인공이 공방을 물려받고 길드와 결계 유지비 계약 — 양피지가 펼쳐지고 밀랍 인장
--   6. circuit  : 스승이 진열장 아래 심어 둔 공명 회로 — 25칸 소켓을 잇는 마력 도선, 문 앞의 주인공에게 흘러드는 마력
--                 (circuit.image 일러스트 켄 번스. 없으면 circuit.fallback 공방 배경 + 황금색 회로 틴트 + 코드 회로판 — ui/IntroCircuit)
--   7. vow      : 과부하·금속 피로, 낮의 감정·제련 / 밤의 방어 — 타이틀 배경으로 줌아웃 → 로고
-- 내레이션은 beats(로케일 intro.lines[i])마다 타자기로 찍히고, 장면 시계는 그 비트의 hold 에서 멈춰 클릭·Space·Enter 를 기다린다
-- (찍는 중에 누르면 문장 즉시 완성, 다 찍힌 뒤 누르면 다음 비트). 멈춰 있어도 불티·전투는 계속 움직인다. Esc / 오른쪽 위 [건너뛰기] = 건너뛰기.
-- 카메라 좌표는 그림 안의 정규화 위치(0~1)와 확대 배율.
-- video 파일이 있으면 코드 연출 대신 그 영상(Ogg Theora .ogv)을 재생한다.

return {
    video = "assets/video/intro.ogv",
    background = "assets/backgrounds/title.png",
    cut = "assets/intro/cut1.png",
    duration = 53,          -- 마지막 비트를 넘기고 이 시각이 되면 끝 (건너뛰기: Esc / [건너뛰기])
    fade = 0.6,             -- 단계 사이 암전(초)
    skip_hint_at = 1.0,
    letterbox = 44,         -- 위·아래 검은 띠(px)

    stages = {
        { id = "peace", start = 0, stop = 9 },
        { id = "storm", start = 9, stop = 16 },
        { id = "defense", start = 16, stop = 24.4 },
        { id = "vanish", start = 24.4, stop = 31.4 },
        { id = "contract", start = 31.4, stop = 38.4 },
        { id = "circuit", start = 38.4, stop = 45.4 },
        { id = "vow", start = 45.4, stop = 53 },
    },
    -- 내레이션 비트: start 부터 문장을 찍고, 장면 시계는 hold 에서 멈춰 입력을 기다린다 (로케일 intro.lines 와 같은 순서·개수)
    beats = {
        { start = 0.5, hold = 4.4 }, { start = 4.4, hold = 8.6 },
        { start = 9.4, hold = 12.6 }, { start = 12.6, hold = 15.6 },
        { start = 16.4, hold = 19.8 }, { start = 19.8, hold = 23.9 },
        { start = 24.8, hold = 27.8 }, { start = 27.8, hold = 31.0 },
        { start = 31.8, hold = 34.8 }, { start = 34.8, hold = 38.0 },
        { start = 38.8, hold = 41.8 }, { start = 41.8, hold = 45.0 },
        { start = 45.8, hold = 48.8 }, { start = 48.8, hold = 52.6 },
    },

    -- 1단계: cut1 켄 번스 (주인장 → 창밖 도시)
    peace_camera = {
        { t = 0, x = 0.30, y = 0.42, zoom = 1.32 },
        { t = 9, x = 0.55, y = 0.40, zoom = 1.08 },
    },
    -- 4장면: 빈 공방으로 천천히 다가간다 (cut1, 차가운 푸른빛)
    vanish_camera = {
        { t = 24.4, x = 0.52, y = 0.44, zoom = 1.12 },
        { t = 31.4, x = 0.40, y = 0.48, zoom = 1.34 },
    },
    vanish_ember = { x = 0.84, y = 0.80 },     -- 빈 공방(day_workshop.png) 벽난로의 식어 가는 불씨 (정규화 좌표)
    -- 5장면: 양피지 계약서가 펼쳐지는 시간 · 밀랍 인장이 찍히는 시각
    contract = { unroll_from = 31.6, unroll_time = 1.2, seal_at = 35.2, w = 560, h = 300 },
    candles = { { x = 0.05, y = 0.66 }, { x = 0.53, y = 0.36 } },     -- 촛불 위치 (cut1 정규화 좌표) — 불티·흔들리는 빛
    -- 6장면: 공명 회로 (일러스트가 없으면 fallback 그림을 dim 만큼 어둡게 덮고 황금색 회로 틴트 tint_alpha + 코드 회로판 — data/circuit.lua)
    circuit = {
        image = "assets/backgrounds/intro_circuit.png", fallback = "assets/backgrounds/day_workshop.png", dim = 0.62, tint_alpha = 0.12,
        camera = { { t = 38.4, x = 0.46, y = 0.50, zoom = 1.16 }, { t = 45.4, x = 0.54, y = 0.48, zoom = 1.04 } },
    },

    -- 2·3단계 밤 장면 배치 (화면 좌표)
    ground_y = 612,
    pawnshop = { x = 330, size = 470 },
    portal = { x = 930, size = 440, appear_at = 10.8, grow = 1.0 },
    lightning = { 10.0, 10.7, 13.2 },   -- 보라 벼락 시각 (화면 섬광 + 흔들림 + 천둥)
    weapons = {
        flame_sword = { x = 620, y = 548, size = 120, rate = 1.6, speed = 760 },
        lightning_orb = { x = 600, y = 430, size = 100, rate = 1.3 },
    },
    monsters = { spawn_every = 0.55, hp = 3, speed = 95, size = 118, kinds = { "goblin", "slime" } },
    defense_spawn_stop = 23.2,

    -- 7장면: 타이틀 배경으로 줌아웃
    vow_camera = {
        { t = 45.4, x = 0.62, y = 0.50, zoom = 1.75 },
        { t = 50.2, x = 0.5, y = 0.5, zoom = 1.0 },
    },
    title_camera = { x = 0.5, y = 0.5, zoom = 1.0 },
    logo_at = 49.6,
    logo_time = 1.6,

    chars_per_second = 30,

    -- 타이틀 배경 위 연출
    embers_per_second = 7,
    fog_layers = 4,
}

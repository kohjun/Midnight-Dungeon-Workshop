-- data/circuit.lua
-- 공명 회로 연출 수치 (전투 규칙과 무관한 표현용 — ui/ConduitView · ui/IntroCircuit). 로직 없음.
-- 세계관: 스승은 진열장 아래 25칸의 철제·황동 소켓을 상하좌우 마력 도선으로 이어 공명 회로를 심어 두었다. 밤 셔터가 내려오면
-- 이웃한 유물의 마력이 도선을 타고 서로 증폭되어, 공방 문 앞에서 공명 건틀릿과 망치를 든 주인공에게 흘러든다 (ui/LaneHero).
--   conduit   : 이웃한 두 칸의 경계를 가로지르는 황동 도선 한 토막 — 칸 경계에서 양쪽 칸 안으로 reach px.
--               낮에는 불 꺼진 황동, 밤이 시작되면 정중앙 칸에서 바깥으로 ignite_step 초 간격으로 불이 번진다 (칸 사이 거리마다).
--               밝기 alpha: sealed(봉인 칸에 걸친 도선) · idle(빈 칸) · live(양쪽에 작동 중인 유물) · link(시너지로 이어진 두 칸).
--               pulse = 맥동 속도. 과부하를 켜면 mana 대신 overclock 색으로 고동친다
--   core_mark : 정중앙 직접 동조 슬롯(data/layout.lua 의 grid_core) 모서리 표식 — length · inset 은 칸 크기 배율 · px
--   intro     : 인트로 circuit 장면의 코드 회로판(일러스트가 없을 때) — 소켓 간격 · 가운데 위치(화면 비율) · 불이 번지는 속도 ·
--               주인공 위치와 키, 마력이 주인공에게 흘러드는 시각(장면 시작 뒤 초)

return {
    conduit = {
        reach = 13,
        width = 4,
        node = 3,
        ignite_step = 0.22,
        ignite_fade = 0.3,
        brass = { 0.60, 0.45, 0.20 },
        dark = { 0.09, 0.07, 0.05 },
        mana = { 1.00, 0.82, 0.36 },
        overclock = { 1.00, 0.42, 0.14 },
        alpha = { sealed = 0.45, day = 0.85, idle = 0.22, live = 0.55, link = 1.0 },
        pulse = { live = 2.4, link = 5.0, overclock = 9.0 },
        glow_width = 9,
    },
    core_mark = { color = { 1.00, 0.84, 0.36 }, alpha = 0.72, length = 0.2, inset = 6, width = 2 },
    intro = {
        board = { x = 0.37, y = 0.45, spacing = 74, socket = 20 },
        ignite_step = 0.38,
        hero = { x = 0.80, ground = 0.78, height = 330 },
        flow_at = 3.4,
        tint = { 1.00, 0.76, 0.30 },
    },
}

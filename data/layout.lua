-- data/layout.lua
-- 화면 배치 (1280x720). 시스템(히트 판정·투사체 원점)과 UI 가 함께 참조하는 단일 출처. 로직 없음.
-- 공방 화면은 낮과 밤의 배치가 완전히 다르다:
--   day   : 왼쪽 55% 작업대(손님 카운터·감정·세척·용광로) / 오른쪽 45% = 위 보관함 4칸 + 아래 5x5 진열장·시너지 미리보기
--           (탭 없음 — 보관함에서 진열장으로 바로 끌어 놓는다. 길드 상점·결계 유지비는 [길드] 창, 암시장·길드 의뢰는 [의뢰] 창)
--   night : 왼쪽 36% 확대 진열장 + 과부하 레버 / 오른쪽 64% 와이드 전투 레인(방벽·포탈)
-- 야간 전투(systems/Combat)는 night 좌표에서 돈다. field_scale = 이전 620px 레인 대비 넓어진 배율로,
-- 몬스터 크기·속도·범위 효과 거리·탄속에 곱해 밸런스를 그대로 유지한다.

return {
    screen = { w = 1280, h = 720 },   -- 논리 해상도 (전체화면에서는 core/Viewport 가 비율 유지 확대)
    top_bar = { x = 0, y = 0, w = 1280, h = 60 },
    grid_cols = 5,
    grid_rows = 5,
    grid_core = { row = 3, col = 3 },   -- 정중앙 '직접 동조 슬롯' (systems/Grid.CORE — 밤에 문 앞 주인공이 동조하는 주력 무기 자리, 연출만)

    -- 상단 HUD (ui/Hud · ui/HudStatus): 철제·황동 이중 테두리 바. 왼쪽 = 상태 카드 4장 / 오른쪽 = 메뉴 버튼 5개 + 최우측 핵심 진행 버튼
    --   badge: 날짜·페이즈 배지 · ward: 방벽 내구도 · tribute: 결계 유지비 카드 · purse: 골드(gold) · 연마석(stones)
    --   gold / stones 의 cx, cy 는 골드·연마석 연출(동전 파티클)의 목표 지점이기도 하다
    hud = {
        badge = { x = 10, y = 7, w = 170, h = 46 },
        ward = { x = 188, y = 7, w = 150, h = 46 },
        tribute = { x = 346, y = 7, w = 112, h = 46 },
        purse = { x = 466, y = 7, w = 164, h = 46 },
        gold = { cx = 520, cy = 30 },
        stones = { cx = 600, cy = 30 },
        divider = 636,
    },
    -- 상납 경고 띠 (상단 바 바로 아래, D-1 / D-Day 낮)
    tribute_warning = { x = 0, y = 61, w = 1280, h = 18 },

    -- ── 낮 (영업) ──────────────────────────────────────────
    day = {
        workbench = { x = 14, y = 86, w = 692, h = 620 },
        -- 왼쪽 주인장 초상(portrait_*) ↔ 오른쪽 손님 모험가 초상(guest_*)이 대사를 사이에 두고 마주 본다
        customer_card = { x = 30, y = 106, w = 660, h = 122, portrait_x = 84, portrait_r = 40, text_x = 140, text_w = 378,
            guest_x = 500, guest_r = 40, guest_text_w = 296 },
        bench_slot = { x = 148, y = 238, w = 262, h = 262, item_size = 210 },
        appraisal_tag = { x = 420, y = 238, w = 270, h = 262 },
        hint_strip = { x = 30, y = 508, w = 660, h = 28 },
        furnace_section = { x = 30, y = 544, w = 660, h = 152 },
        furnace_slot = { x = 44, y = 556, w = 128, h = 128, item_size = 100 },
        furnace_info = { x = 188, y = 554, w = 300, h = 132 },

        panel = { x = 718, y = 86, w = 548, h = 620 },
        -- 위: 주인공 4부위 장비창(왼쪽 — 무기 · 투구 · 갑옷 · 신발) + 임시 거치대(오른쪽, 칸 수는 balance.workshop.storage_slots).
        -- ui/HeroEquipView · ui/Slots ("hero" / "storage" 영역). hero_title · hero_stats 는 주인공 툴팁이 뜨는 줄
        storage_section = { x = 732, y = 98, w = 520, h = 150 },
        hero_slots = { x = 748, y = 124, size = 64, gap = 6, item_size = 50 },
        storage_slots = { x = 1040, y = 124, size = 64, gap = 6, item_size = 50 },
        hero_title = { x = 744, y = 100, w = 282, h = 22 },
        hero_stats = { x = 744, y = 210, w = 282, h = 30 },
        rack_title = { x = 1036, y = 100, w = 212, h = 22 },
        -- 아래: 5x5 진열장 + 시너지 미리보기 띠
        grid_section = { x = 732, y = 256, w = 520, h = 440 },
        grid = { x = 811, y = 288, cell = 70, gap = 3, item_size = 54 },
        synergy = { x = 744, y = 652, w = 496, h = 38 },
        toast = { x = 718, w = 548, y = 648 },
    },

    -- ── 밤 (방어) ──────────────────────────────────────────
    night = {
        grid_panel = { x = 14, y = 86, w = 444, h = 620 },
        grid = { x = 30, y = 112, cell = 80, gap = 3, item_size = 64 },
        lever_panel = { x = 30, y = 536, w = 412, h = 160 },
        lane = { x = 470, y = 86, w = 796, h = 620 },
        wall = { x = 470, y = 86, w = 100, h = 620 },    -- 방벽 충돌선 = 오른쪽 끝 (공방 건물 오른쪽 벽면, data/art.lua 의 buildings)
        horizon_y = 340,                -- 하늘과 땅의 경계 (= 밤 레인 배경의 돌길 윗선, data/art.lua 의 night_lane.road_y) — 하늘 41% : 땅 59%
        field = { y = 372, h = 180 },   -- 몬스터가 걷는 돌길 (스폰 Y 범위, 포탈 아치 중심 = 띠 가운데)
        field_scale = 1.27,
        sprite_scale = 1.35,            -- 그림만 더 크게 (충돌 반경·밸런스와 무관)
        portal = { x = 1170, size = 270 },  -- 포탈 아치 중심 x · 그림 높이 (몬스터는 이 x, 보행 띠 안에서 나온다)
        toast = { x = 470, w = 796, y = 134 },
    },

    buttons = {
        -- 손님 카운터: 같은 자리에 상황별 버튼 하나만 보인다 (빈 작업대 / 손님 유물 / 내 유물)
        new_customer = { x = 550, y = 114, w = 132, h = 48 },
        buy = { x = 550, y = 114, w = 132, h = 48 },
        sell = { x = 550, y = 114, w = 132, h = 48 },
        summon = { x = 550, y = 170, w = 132, h = 48 },
        dismiss = { x = 550, y = 170, w = 132, h = 48 },
        stash = { x = 550, y = 170, w = 132, h = 48 },
        uv = { x = 30, y = 238, w = 108, h = 128 },
        brush = { x = 30, y = 372, w = 108, h = 128 },
        scroll = { x = 432, y = 456, w = 246, h = 36 },
        forge = { x = 504, y = 578, w = 172, h = 54 },
        -- 상단 바 (오른쪽 구역): 메뉴 버튼 5개 → 최우측 핵심 진행 버튼(낮: 황동 강조 [영업 마감])
        guild = { x = 644, y = 10, w = 86, h = 40 },
        quests = { x = 734, y = 10, w = 86, h = 40 },
        compendium = { x = 824, y = 10, w = 86, h = 40 },
        upgrades = { x = 914, y = 10, w = 100, h = 40 },
        settings = { x = 1018, y = 10, w = 92, h = 40 },
        start_night = { x = 1120, y = 8, w = 150, h = 44 },
        -- 밤 전투 배속 토글 (전투 레인 오른쪽 위)
        speed = { x = 1172, y = 93, w = 86, h = 30 },
        -- 밤 과부하 레버 (레버 패널 안)
        overclock = { x = 42, y = 548, w = 130, h = 136 },
        -- '스승의 흔적' 캠페인의 [수기 N/6 · 봉인진 N/4] (ui/MasterJournalModal 을 연다, ui/TraceButtons):
        -- 낮 = 오른쪽 진열장 머리줄 오른쪽 (진열장 제목 글자 뒤) · 밤 = 전투 레인 왼쪽 위 — 새벽 진행 막대 글자와
        -- 가운데 위쪽 중간 보스 체력 바 상자(ui/MidBossView)보다 아래, 중간 보스 출현 배너 · 최종 보스 먹 띠(ui/MasterBossHud)보다 위
        journal = { x = 1046, y = 261, w = 198, h = 25 },
        journal_night = { x = 482, y = 152, w = 198, h = 22 },
    },

    -- '스승의 흔적' 수기 창 (ui/MasterJournalModal): 양피지 — 왼쪽 위 봉인진 상자 · 그 아래 수기 6편 목록 · 오른쪽 본문
    --   x 기준 오프셋(list_x · detail_x)과 y 기준 오프셋(array_top · list_top · page_top · text_top)은 창 왼쪽 위 기준
    journal = { x = 130, y = 58, w = 1020, h = 620, list_x = 40, list_w = 300, array_top = 96, array_h = 86, list_top = 196,
        card_h = 50, card_gap = 7, detail_x = 384, detail_w = 596, page_top = 96, text_top = 150, close_w = 200, close_h = 44 },

    -- 튜토리얼 안내 띠 후보 자리 (ui/TutorialView): 앞에서부터 스포트라이트 영역과 겹치지 않는 첫 자리 (모두 겹치면 첫 자리)
    tutorial_banners = {
        skip_w = 92,
        day = { { x = 230, y = 640, w = 820, h = 72 }, { x = 230, y = 66, w = 820, h = 72 }, { x = 230, y = 320, w = 820, h = 72 } },
        night = { { x = 486, y = 630, w = 764, h = 72 }, { x = 486, y = 150, w = 764, h = 72 }, { x = 24, y = 300, w = 430, h = 120 } },
    },

    -- 인트로 오른쪽 위 [건너뛰기] (states/IntroState)
    intro_skip = { x = 1124, y = 10, w = 140, h = 38 },

    -- 새벽 방어 정산 결과창 (ui/DawnSummary): 밤 화면 가운데, 위 상단 바는 밝게 둔다
    dawn_summary = { x = 410, y = 150, w = 460, h = 360, button_w = 260, button_h = 48 },

    -- 공용 모달 (길드 상점 · 공방 개조 · 암시장 · 영구 강화)
    modal = { x = 240, y = 84, w = 800, h = 572, row_top = 92, row_h = 64, row_gap = 6,
        button_w = 150, button_h = 40, footer_h = 44, footer_w = 220 },

    -- [길드] 창 (ui/GuildModal): 왼쪽 세계관 안내 · 결계 유지비 현황 / 오른쪽 길드 보급 상점 행
    guild = { x = 100, y = 64, w = 1080, h = 610, lore_w = 430, shop_x = 500, row_top = 108, row_h = 96, row_gap = 10,
        button_w = 150, button_h = 46, close_w = 200, close_h = 44 },
    -- [의뢰] 창 (ui/QuestModal): 양피지 — 왼쪽 의뢰 목록 카드 · 오른쪽 상세(배경·조건·보상·위험도) + [수락]/[거절]
    quests = { x = 110, y = 54, w = 1060, h = 620, list_x = 44, list_w = 320, list_top = 112, card_h = 96, card_gap = 8,
        detail_x = 396, detail_w = 620, button_w = 170, button_h = 46, close_w = 200, close_h = 44 },

    -- 유물 도감 (ui/CompendiumModal): 아키타입별 한 줄(기본 유물 → 특수 유물) · 오른쪽 상세 · 아래 엔딩 수집 두 줄
    --   (ui/CompendiumEndings — 첫 줄 일반 엔딩 3종 / 둘째 줄 '스승의 흔적' 엔딩 2종 + 진엔딩 훈장).
    --   endings_y = "엔딩 수집" 머리글 줄, 카드는 그 아래 ending_top · 둘째 줄은 첫 줄 아래 ending_row_gap (사이에 캠페인 머리글)
    compendium = { x = 70, y = 46, w = 1140, h = 628, grid_x = 24, grid_y = 80, label_w = 128, cell = 58, gap = 8,
        row_h = 66, detail_x = 848, detail_w = 268, detail_h = 500, endings_y = 348, ending_top = 24, ending_h = 72,
        ending_gap = 14, ending_row_gap = 30, close_w = 200, close_h = 44 },

    -- 환경 설정 모달 행 (공용 모달 창 안)
    settings = { row_top = 74, row_h = 50, label_x = 40, label_w = 190, control_x = 240, control_w = 520,
        option_h = 34, option_gap = 8, step_w = 40 },

    tooltip = { width = 300, padding = 12, offset = 18 },

    -- '스승의 흔적' 최종 보스 (ui/MasterBossHud): 전투 레인 아래쪽 가운데 전용 체력 띠 (레인 바닥에서 plate_bottom 위) ·
    -- 출현 경고/결말 배너 띠 (중심 = 레인 위에서 banner_y, 반 높이 banner_half_h — 밤 토스트 아래)
    master_boss = { plate_w = 600, plate_h = 86, plate_bottom = 12, banner_y = 172, banner_half_h = 56 },

    -- 타이틀: 왼쪽 위 로고 · 그 아래 세로 메뉴 한 줄 (오른쪽은 배경 그림)
    title = {
        logo = { cx = 330, y = 58, w = 560 },
        greeting_y = 262,
        menu = { x = 96, y = 312, w = 420, h = 48, gap = 6 },
        press_y = 540,
        hint_y = 684,
    },

    -- 난이도(계약) 선택
    -- 난이도 계약서: 어두워진 타이틀 배경 위로 양피지가 위에서 아래로 펼쳐진다 (카드 3장 + 서명란)
    difficulty = {
        parchment = { x = 56, y = 26, w = 1168, h = 662 },
        title_y = 38,
        -- 계약 카드: 줄마다 가운데 정렬 (줄별 카드 수는 data/difficulties.lua 의 rows — 위 3장 · 아래 2장)
        cards = { w = 340, gap = 30, rows = { { y = 118, h = 188 }, { y = 316, h = 188 } } },
        name_field = { x = 506, y = 518, w = 260, h = 40 },
        notice_y = 566,
        hint_y = 594,
        back = { x = 92, y = 622, w = 184, h = 44 },
        replay = { x = 916, y = 622, w = 272, h = 44 },     -- [튜토리얼 다시 보기] 토글 (오른쪽 아래, [뒤로]와 대칭)
    },

    -- 결과 화면
    gameover = {
        meta_button = { x = 520, y = 600, w = 240, h = 40 },
    },
}

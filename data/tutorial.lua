-- data/tutorial.lua
-- 첫 런 튜토리얼(낮 → 첫 밤 완전판): 첫 손님 · 단계별 스포트라이트 대상 · 잠금 규칙. 로직 없음.
--   낮: ① 상단 HUD 상태(날짜·방벽·골드·연마석) · 결계 유지비 ② 상단 메뉴 바 ③ 작업대·보관함·진열장 세 구역
--       ④ 첫 손님 UV 감정(좋은 발견 / 나쁜 발견) → 할인 매입 ⑤ 브러시 세척 · 에너지(UV 배터리·정화수) 주의 ⑥ 용광로 강화 장단점
--       ⑦ 보관함 → 5x5 진열장 배치 → [영업 마감]
--   밤: ⑧ 진열장 배치 전략·무기 속성·시너지 ⑨ 과부하 레버·과열 ⑩ 배속·몬스터 툴팁·설정 일시정지 → 첫 밤 방어 (⑧~⑩ 은 읽는 동안 전투 정지)
-- highlight: "button:<id>" | "slot:<area>" | "area:grid|workbench|storage|counter|tag|furnace|lever|lane" | "hud:badge|ward|tribute|purse"
--   ui/TutorialView 가 그 영역만 스포트라이트로 뚫고 나머지 화면은 반투명 암막으로 덮는다 (dim = false 면 암막 없이 테두리만).
--   클릭은 막지 않는다. 안내 띠는 강조 영역과 겹치지 않는 자리(LAYOUT.tutorial_banners)에 놓는다.
-- 단계 안내 문구는 data/locales/<언어>/game.lua 의 tutorial.steps.<id> — {name}·{address} 는 플레이어 이름·호칭으로 치환된다.
-- complete_on: 이 이벤트가 오면 단계 완료 (condition 이 있으면 systems/Tutorial.lua 의 판정 함수도 통과해야 함).
--   이후 단계의 완료 이벤트가 먼저 오면 그 단계까지 건너뛴다. info = true: 안내 띠의 [다음](Tutorial:next)으로 넘어간다.
-- pause = true: 이 단계가 떠 있는 동안 밤 전투를 멈춘다 (RunState — 읽고 [다음]을 누르면 재개).

return {
    first_customer = {
        proto = "flame_sword", grade = "rare", claimed_grade = "rare", flaw = "crack", adventurer = "bern",
        flaw_mark = { x = 0.05, y = -0.22 }, contamination = 65,
        grime = {
            { x = -0.15, y = -0.25, r = 0.14 }, { x = 0.12, y = 0.05, r = 0.16 },
            { x = -0.05, y = 0.3, r = 0.12 }, { x = 0.2, y = -0.35, r = 0.1 },
        },
    },

    steps = {
        -- 낮 ① 상단 HUD
        { id = "hud_status", info = true, complete_on = "tutorial:next", highlight = { "hud:badge", "hud:ward", "hud:purse" } },
        { id = "hud_tribute", info = true, complete_on = "tutorial:next", highlight = { "hud:tribute" } },
        -- ② 상단 메뉴 바
        { id = "menu_bar", info = true, complete_on = "tutorial:next",
            highlight = { "button:guild", "button:quests", "button:compendium", "button:upgrades", "button:settings" } },
        -- ③ 공방 세 구역
        { id = "areas", info = true, complete_on = "tutorial:next", highlight = { "area:workbench", "area:storage", "area:grid" } },
        -- ④ 첫 손님 · UV 감정 → 할인 매입
        { id = "scan", complete_on = "appraisal:flaw_revealed", highlight = { "area:counter", "button:uv", "slot:bench" } },
        { id = "buy", complete_on = "appraisal:item_bought", highlight = { "button:buy", "area:tag" } },
        -- ⑤ 브러시 세척 · 에너지 주의
        { id = "clean", complete_on = "appraisal:cleaned", highlight = { "button:brush", "slot:bench", "button:uv" } },
        -- ⑥ 용광로 강화
        { id = "forge_info", info = true, complete_on = "forge:resolved", highlight = { "area:furnace" } },
        -- ⑦ 보관함 → 진열장 → [영업 마감]
        { id = "stash", complete_on = "inventory:changed", condition = "grid_not_empty", highlight = { "button:stash", "area:grid" } },
        { id = "place", info = true, complete_on = "tutorial:next", highlight = { "area:storage", "area:grid" } },
        { id = "night", complete_on = "phase:night_started", highlight = { "button:start_night" } },
        -- 밤 ⑧~⑩ (읽는 동안 전투 정지)
        { id = "night_grid", info = true, pause = true, complete_on = "tutorial:next", highlight = { "area:grid" } },
        { id = "night_lever", info = true, pause = true, complete_on = "tutorial:next", highlight = { "area:lever" } },
        { id = "night_speed", info = true, pause = true, complete_on = "tutorial:next",
            highlight = { "button:speed", "area:lane", "button:settings" } },
        { id = "defend", complete_on = "phase:day_started", dim = false, highlight = { "button:speed", "button:overclock" } },
    },

    -- 행동별로 잠기는 단계 (튜토리얼이 막히지 않도록 최소한만 잠근다)
    locks = {
        new_customer = { "hud_status", "hud_tribute", "menu_bar", "areas", "scan", "buy", "clean" },
        sell = { "hud_status", "hud_tribute", "menu_bar", "areas", "scan", "buy", "clean", "forge_info", "stash", "place" },
        forge = { "hud_status", "hud_tribute", "menu_bar", "areas", "scan", "buy", "clean" },
        start_night = { "hud_status", "hud_tribute", "menu_bar", "areas", "scan", "buy", "clean", "forge_info", "stash", "place" },
    },
    -- 이 단계에서 매입하면 유물을 보관함 대신 작업대에 남긴다 (바로 세척하도록)
    keep_purchase_on_bench = { "hud_status", "hud_tribute", "menu_bar", "areas", "scan", "buy" },
}

-- data/controls.lua
-- 키/마우스 바인딩. 키 이름은 LÖVE KeyConstant 기준. 로직 없음.

return {
    keys = {
        confirm = { "space", "return", "kpenter" },
        back = { "escape" },
        retry = { "r" },
        tool_uv = { "1" },
        tool_brush = { "2" },
        buy = { "3" },
        forge = { "4" },
        phase_action = { "space" },     -- 낮: 영업 마감(밤 시작) / 밤: 과부하 레버 토글
        start_night = { "n" },
        overclock = { "o" },
        speed_toggle = { "tab" },       -- 밤: 전투 배속 1x → 2x → 3x
        replay_tutorial = { "f6" },     -- 난이도 계약서: [튜토리얼 다시 보기] 토글 (서명란이 글자를 받으므로 F 키)
        difficulty_1 = { "f1" },        -- 계약서 카드 F1~F5 (data/difficulties.lua 의 order 순서)
        difficulty_2 = { "f2" },
        difficulty_3 = { "f3" },
        difficulty_4 = { "f4" },
        difficulty_5 = { "f5" },
    },
    mouse = {
        confirm = { 1 },   -- 1 = 좌클릭
        primary = { 1 },
        cancel = { 2 },    -- 2 = 우클릭 (도구 해제)
    },
    -- 버튼 모서리에 표시하는 키 힌트 (버튼 id → 표기)
    hints = {
        uv = "1", brush = "2", buy = "3", forge = "4",
        start_night = "Space", overclock = "Space", settings = "Esc", speed = "Tab",
    },
}

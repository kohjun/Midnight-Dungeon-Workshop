-- data/fonts.lua
-- 글꼴 역할별 후보 파일. 앞에서부터 처음 읽히는 파일을 쓴다 (ui/Draw.lua). 로직 없음.
--   1) assets/fonts/<역할>.ttf|otf — 게임과 함께 배포하는 글꼴 (현재: display·story = 송명, ui·body = 프리텐다드 SemiBold·Medium,
--      둘 다 SIL OFL 1.1 — 라이선스 원문을 같은 폴더의 OFL-*.txt 로 함께 배포한다)
--   2) 이 PC 에 설치된 글꼴 (Noto Sans KR = OFL, 함초롬바탕 = 한컴 무료 글꼴)
--   3) 맑은 고딕 → LÖVE 기본 글꼴 (크래시 금지)
-- 역할: display = 로고·화면/모달 제목·간판·카드 이름 (명조) / ui = 버튼·라벨·HUD 수치·툴팁 이름 (고딕 SemiBold)
--       body = 설명·대사·툴팁·설정창 본문 (고딕) / story = 계약서·인트로 내레이션 본문 (명조)

local MALGUN = "C:/Windows/Fonts/malgun.ttf"
local MALGUN_BOLD = "C:/Windows/Fonts/malgunbd.ttf"

return {
    default_role = "body",
    roles = {
        display = {
            "assets/fonts/display.ttf", "assets/fonts/display.otf",
            "C:/Windows/Fonts/HANBatangB.ttf", "C:/Windows/Fonts/batang.ttc", MALGUN_BOLD, MALGUN,
        },
        ui = {
            "assets/fonts/ui.ttf", "assets/fonts/ui.otf",
            "C:/Windows/Fonts/NotoSansKR-Bold.ttf", MALGUN_BOLD, MALGUN,
        },
        body = {
            "assets/fonts/body.ttf", "assets/fonts/body.otf",
            "C:/Windows/Fonts/NotoSansKR-Regular.ttf", MALGUN,
        },
        story = {
            "assets/fonts/story.ttf", "assets/fonts/story.otf",
            "C:/Windows/Fonts/HANBatang.ttf", "C:/Windows/Fonts/batang.ttc", MALGUN,
        },
    },

    -- 글자가 없을 때 빌려 올 역할 (송명에는 '·' '→' 같은 기호가 없다) → 그래도 없으면 last_resort
    fallbacks = {
        display = { "body" },
        story = { "body" },
        ui = { "body" },
        body = {},
    },
    last_resort = MALGUN,
}

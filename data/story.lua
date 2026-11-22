-- data/story.lua
-- 플레이어 이름 규칙 (난이도 계약서의 서명란 · systems/Progress). 로직 없음.
-- 서명란 문구·호칭("{name} 사장님")·기본 이름은 data/locales/<언어>/game.lua 의 story.* (systems/I18n.lua 로 조회).

return {
    contract = {
        name_max_chars = 10,
    },
}

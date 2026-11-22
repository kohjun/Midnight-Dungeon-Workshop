-- data/locales/ko.lua
-- 한국어 로케일. parts 의 각 파일이 최상위 네임스페이스들을 반환하고 systems/I18n.lua 가 하나로 병합한다. 로직 없음.
-- 키 구조는 en.lua 와 같아야 한다 (스모크 테스트가 누락 키를 검사).

return {
    code = "ko",
    parts = {
        require("data.locales.ko.items"),
        require("data.locales.ko.game"),
        require("data.locales.ko.ui"),
        require("data.locales.ko.screens"),
        require("data.locales.ko.messages"),
        require("data.locales.ko.collection"),
        require("data.locales.ko.guild"),
        require("data.locales.ko.combat"),
        require("data.locales.ko.tooltips"),
        require("data.locales.ko.trace"),
        require("data.locales.ko.hero"),
    },
}

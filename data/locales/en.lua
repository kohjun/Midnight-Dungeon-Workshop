-- data/locales/en.lua
-- English locale. Each file in parts returns top-level namespaces; systems/I18n.lua merges them. No logic.
-- The key structure must match ko.lua (the smoke test checks for missing keys).

return {
    code = "en",
    parts = {
        require("data.locales.en.items"),
        require("data.locales.en.game"),
        require("data.locales.en.ui"),
        require("data.locales.en.screens"),
        require("data.locales.en.messages"),
        require("data.locales.en.collection"),
        require("data.locales.en.guild"),
        require("data.locales.en.combat"),
        require("data.locales.en.tooltips"),
        require("data.locales.en.trace"),
        require("data.locales.en.hero"),
    },
}

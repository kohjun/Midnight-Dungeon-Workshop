-- tools/SmokeFonts.lua
-- 글꼴 검사: 역할(display · story · ui · body)마다 ko/en 로케일의 모든 문구를 빠짐없이 그릴 수 있는지
-- (자기 글꼴 + data/fonts.lua 의 빌려 오는 글꼴 포함). 없는 글자가 있으면 화면에 빈칸으로 나가므로 실패로 본다.

local SmokeFonts = {}

local ROLES = { "display", "story", "ui", "body" }
local LOCALES = { "ko", "en" }

local function collect_strings(node, out)
    for _, value in pairs(node) do
        if type(value) == "table" then
            collect_strings(value, out)
        elseif type(value) == "string" then
            out[#out + 1] = value
        end
    end
    return out
end

function SmokeFonts.run(log)
    local Draw = require("ui.Draw")
    local strings = {}
    for _, code in ipairs(LOCALES) do
        for _, part in ipairs(require("data.locales." .. code).parts) do
            collect_strings(part, strings)
        end
    end
    local problems = {}
    for _, role in ipairs(ROLES) do
        local missing = {}
        for _, text in ipairs(strings) do
            for _, char in ipairs(Draw.missing_glyphs(text, { role = role, size = 16 })) do
                missing[char] = true
            end
        end
        local chars = {}
        for char in pairs(missing) do
            chars[#chars + 1] = char
        end
        if #chars > 0 then
            table.sort(chars)
            problems[#problems + 1] = role .. ": " .. table.concat(chars, " ")
        end
    end
    assert(#problems == 0, "SmokeFonts: glyphs missing in every fallback font -> " .. table.concat(problems, " | "))
    log("fonts ok (%d locale strings render fully in display/story/ui/body)", #strings)
end

return SmokeFonts

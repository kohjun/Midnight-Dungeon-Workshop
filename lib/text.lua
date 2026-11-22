-- lib/text.lua
-- 문자열 유틸 (UTF-8 안전): 템플릿 치환, 글자 수, 앞부분 자르기, 마지막 글자 지우기, 이름 정리.

local utf8 = require("utf8")

local Text = {}

-- "{name} 사장님" + { name = "모험왕" } → "모험왕 사장님" (없는 키는 그대로 둔다)
function Text.fill(template, vars)
    local result = template:gsub("{([%w_]+)}", function(key)
        local value = vars[key]
        if value == nil then
            return "{" .. key .. "}"
        end
        return tostring(value)
    end)
    return result
end

function Text.length(s)
    return utf8.len(s) or #s
end

-- 앞 n 글자
function Text.prefix(s, n)
    if n <= 0 then
        return ""
    end
    if n >= Text.length(s) then
        return s
    end
    return s:sub(1, utf8.offset(s, n + 1) - 1)
end

-- 마지막 한 글자 제거 (백스페이스)
function Text.pop(s)
    local length = utf8.len(s)
    if length == nil or length == 0 then
        return ""
    end
    return s:sub(1, utf8.offset(s, length) - 1)
end

function Text.trim(s)
    local result = s:gsub("^%s+", "")
    result = result:gsub("%s+$", "")
    return result
end

-- 이름 정리: 제어 문자 제거, 연속 공백 하나로, 앞뒤 공백 제거, 최대 max_chars 글자
function Text.sanitize_name(s, max_chars)
    local cleaned = s:gsub("%c", "")
    cleaned = cleaned:gsub("%s+", " ")
    return Text.prefix(Text.trim(cleaned), max_chars)
end

return Text

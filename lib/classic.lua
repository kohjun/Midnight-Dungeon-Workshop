-- lib/classic.lua
-- 경량 OOP 클래스 구현 (직접 작성).
--
--   local Class = require("lib.classic")
--
--   local Animal = Class:extend()
--   function Animal:new(name) self.name = name end
--
--   local Dog = Animal:extend()
--   function Dog:new(name)
--       Dog.super.new(self, name)
--       self.tricks = {}
--   end
--
--   local dog = Dog("Rex")      -- 클래스를 함수처럼 호출 → 인스턴스 생성 후 new(...) 실행
--   dog:is(Animal)              -- true
--   Dog:implement(SomeMixin)    -- 믹스인: 클래스에 아직 없는 함수만 복사

local Object = {}
Object.__index = Object

-- 기본 생성자. 서브클래스에서 재정의한다.
function Object:new()
end

-- 서브클래스 생성.
-- 메타메서드(__ 로 시작하는 키)는 __index 로 상속되지 않으므로 직접 복사한다.
function Object:extend()
    local Subclass = {}
    for key, value in pairs(self) do
        if type(key) == "string" and key:sub(1, 2) == "__" then
            Subclass[key] = value
        end
    end
    Subclass.__index = Subclass
    Subclass.super = self
    return setmetatable(Subclass, self)
end

-- 믹스인 테이블들의 함수 중 클래스(상속 포함)에 아직 없는 것만 복사한다.
function Object:implement(...)
    for i = 1, select("#", ...) do
        local mixin = select(i, ...)
        for key, value in pairs(mixin) do
            if self[key] == nil and type(value) == "function" then
                self[key] = value
            end
        end
    end
    return self
end

-- 인스턴스(또는 클래스)가 Type 이거나 Type 을 상속하는지 검사한다.
function Object:is(Type)
    local meta = getmetatable(self)
    while meta ~= nil do
        if meta == Type then
            return true
        end
        meta = getmetatable(meta)
    end
    return false
end

function Object:__tostring()
    return "Object"
end

-- Class(...) 호출 → 인스턴스 생성 후 new(...) 실행
function Object:__call(...)
    local instance = setmetatable({}, self)
    instance:new(...)
    return instance
end

return Object

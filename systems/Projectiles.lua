-- systems/Projectiles.lua
-- 전투 투사체·광선 갱신 (Combat 의 projectiles / beams 목록을 다룬다).
-- 유도탄은 표적이 죽으면 가장 가까운 적으로 재조준하고, 없으면 사라진다.

local COMBAT = require("data.combat")
local LAYOUT = require("data.layout")

local Projectiles = {}

-- item: 광선을 낸 유물 (공격 연출 종류 결정, 낙뢰 등은 그 효과를 낸 유물 또는 nil)
function Projectiles.add_beam(combat, x1, y1, x2, y2, color, width, item)
    local life = COMBAT.projectiles.beam_life
    combat.beams[#combat.beams + 1] = {
        x1 = x1, y1 = y1, x2 = x2, y2 = y2, color = color, life = life, max_life = life, width = width, item = item,
    }
end

function Projectiles.add_bullet(combat, item, x, y, target, damage, color)
    combat.projectiles[#combat.projectiles + 1] = {
        item = item, x = x, y = y, vx = 0, vy = 0, target = target, damage = damage, color = color,
    }
end

-- on_hit(item, monster, damage) 은 명중 시 Combat 이 넘긴 콜백
function Projectiles.update(combat, dt, on_hit)
    local speed = COMBAT.projectiles.bullet_speed * LAYOUT.night.field_scale
    local list = combat.projectiles
    for i = #list, 1, -1 do
        local projectile = list[i]
        if projectile.target.dead then
            projectile.target = combat:nearest_monster(projectile.x, projectile.y)
        end
        local target = projectile.target
        if target == nil then
            table.remove(list, i)
        else
            local dx, dy = target.x - projectile.x, target.y - projectile.y
            local distance = math.sqrt(dx * dx + dy * dy)
            if distance <= speed * dt + target.radius then
                table.remove(list, i)
                on_hit(projectile.item, target, projectile.damage)
            else
                projectile.vx, projectile.vy = dx / distance * speed, dy / distance * speed
                projectile.x = projectile.x + projectile.vx * dt
                projectile.y = projectile.y + projectile.vy * dt
            end
        end
    end
    for i = #combat.beams, 1, -1 do
        local beam = combat.beams[i]
        beam.life = beam.life - dt
        if beam.life <= 0 then
            table.remove(combat.beams, i)
        end
    end
end

return Projectiles

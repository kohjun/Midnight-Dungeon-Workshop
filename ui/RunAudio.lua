-- ui/RunAudio.lua
-- 공방 화면(RunState)의 소리 연결: 매 프레임
--   ① 누르고 있는 동안만 이어지는 루프 — UV 홀드 스캔(uv_hum) · 세척(scrub)
--   ② 장면 배경음·앰비언스 — 밤이면 "night"(긴박한 타악 + 포탈 저주파), 그 밖(낮·길드 상점)은 "day"(류트·현악 + 벽난로).
--      페이즈가 바뀌는 순간(셔터가 화면을 덮었을 때)부터 Audio 가 부드럽게 크로스페이드한다
--   ③ 보스 긴장감 — 밤에 대보스가 살아 있으면 1(밤 배경음의 음높이·음량 — data/audio.lua 의 boss_pitch · boss_gain),
--      '스승의 흔적' 최종 보스(spec.final)가 살아 있으면 2(final_pitch · final_gain — 더 빠르고 크게, 포탈 저주파도 부푼다)
-- 음량은 Settings 의 마스터·효과음·배경음·음소거를 따른다 (systems/Audio).

local Audio = require("systems.Audio")

local RunAudio = {}

local BOSS_TENSION, FINAL_TENSION = 1, 2        -- Audio.set_intensity 단계

-- 살아 있는 우두머리 중 가장 높은 긴장감 단계 (없으면 0, 중간 보스는 세지 않는다)
local function boss_tension(combat)
    local level = 0
    for _, monster in ipairs(combat.monsters) do
        if not monster.dead and monster:is_boss() then
            if monster.spec.final then
                return FINAL_TENSION
            end
            level = BOSS_TENSION
        end
    end
    return level
end

function RunAudio.update(dt, workshop, input)
    Audio.set_loop("uv_hum", workshop.appraisal.lens_on)
    Audio.set_loop("scrub", input:is_scrubbing())
    local night = workshop.phase == "night"
    Audio.set_scene(night and "night" or "day")
    Audio.set_intensity(night and boss_tension(workshop.combat) or 0)
    Audio.update(dt)
end

return RunAudio

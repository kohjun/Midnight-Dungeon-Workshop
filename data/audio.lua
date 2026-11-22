-- data/audio.lua
-- 효과음·루프·배경음 목록과 게임 이벤트 → 효과음 매핑 (systems/Audio.lua). 로직 없음.
-- 파일은 tools/generate_audio.py(+ tools/audio_scenes.py · tools/audio_trace.py)가 assets/sfx · assets/bgm 에 생성한다.
-- 없으면 그 소리만 조용히 건너뛴다.
-- volume: 기본 음량(0~1), min_interval: 같은 효과음 최소 재생 간격(초), voices: 동시에 겹칠 수 있는 수
-- 장면 배경음·앰비언스(loops 의 scene = true)는 Audio.set_scene(이름)이 scenes 목록대로 크로스페이드한다 (fade = 1초당 음량 변화).
--   bus = "bgm" 은 배경음 볼륨, 그 밖(앰비언스·입력 루프)은 효과음 볼륨을 따른다. 마스터·음소거는 전부 따른다

return {
    -- 손님 모험가 더빙 (systems/VoiceOver · tools/generate_voices.py): assets/voices/<언어>/<id>_<대사>.ogg|mp3|wav
    --   delay: 문 종소리 뒤 초상이 자리 잡고 대사·더빙이 시작되는 시간(초, ui/AdventurerPortrait 도 같은 값으로 미끄러져 들어온다)
    --   footsteps_after_buy: 매입 동전 소리 뒤 손님 발걸음까지(초). 볼륨 = volume × 효과음 볼륨 × 마스터
    voice = { dir = "assets/voices", volume = 0.95, delay = 0.62, footsteps_after_buy = 0.35,
        keys = { "greet_1", "greet_2", "caught_forgery", "caught_curse", "caught_crack" } },

    pitch = { min = 0.92, max = 1.08 },     -- 효과음마다 무작위 피치 변조
    loop_fade = 9,                          -- 루프 음량이 목표로 수렴하는 속도(1/초)

    sfx = {
        ui_click = { file = "assets/sfx/ui_click.wav", volume = 0.55, min_interval = 0.03, voices = 3 },
        flaw_found = { file = "assets/sfx/flaw_found.wav", volume = 0.8, min_interval = 0.1, voices = 2 },
        coin_buy = { file = "assets/sfx/coin_buy.wav", volume = 0.7, min_interval = 0.06, voices = 3 },
        forge_charge = { file = "assets/sfx/forge_charge.wav", volume = 0.75, min_interval = 0.2, voices = 1 },
        forge_success = { file = "assets/sfx/forge_success.wav", volume = 0.85, min_interval = 0.2, voices = 1 },
        forge_fail = { file = "assets/sfx/forge_fail.wav", volume = 0.9, min_interval = 0.2, voices = 1 },
        -- 용광로 오버클럭(+2 이상, ui/ForgeDrama): 상승하는 금속 공명 → 웅장한 모루 타격 / 둔탁한 파쇄
        forge_heat = { file = "assets/sfx/forge_heat.wav", volume = 0.8, min_interval = 0.2, voices = 1 },
        forge_overclock_ok = { file = "assets/sfx/forge_overclock_ok.wav", volume = 0.95, min_interval = 0.2, voices = 1 },
        forge_shatter = { file = "assets/sfx/forge_shatter.wav", volume = 1.0, min_interval = 0.2, voices = 1 },
        -- UV 감정 결함·위조 적발 (날카로운 감정 적발음)
        uv_defect_reveal = { file = "assets/sfx/uv_defect_reveal.wav", volume = 0.85, min_interval = 0.15, voices = 2 },
        -- 망치 커서 클릭 (ui/CursorManager — 버튼 위가 아닌 곳을 누를 때만, 낮은 볼륨 · 짧은 쿨타임 · 재생마다 미세 피치 랜덤)
        cursor_tap = { file = "assets/sfx/cursor_tap.wav", volume = 0.32, min_interval = 0.07, voices = 2 },
        coin_tally = { file = "assets/sfx/coin_tally.wav", volume = 0.7, min_interval = 0.3, voices = 1 },       -- 새벽 정산 카운트업
        shop_door_bell = { file = "assets/sfx/shop_door_bell.wav", volume = 0.6, min_interval = 0.3, voices = 1 },   -- 새 손님 입장
        guest_footsteps_out = { file = "assets/sfx/guest_footsteps_out.wav", volume = 0.55, min_interval = 0.3, voices = 1 },
        supply_low = { file = "assets/sfx/supply_low.wav", volume = 0.6, min_interval = 0.8, voices = 1 },   -- UV·정화수 25% 미만 경고
        forge_dud = { file = "assets/sfx/forge_dud.wav", volume = 0.85, min_interval = 0.2, voices = 1 },     -- 강화 실패: 단계 유지·하락
        midboss_horn = { file = "assets/sfx/midboss_horn.wav", volume = 0.85, min_interval = 1.0, voices = 1 }, -- 중간 보스 출현
        shoot_bullet = { file = "assets/sfx/shoot_bullet.wav", volume = 0.32, min_interval = 0.06, voices = 4 },
        shoot_laser = { file = "assets/sfx/shoot_laser.wav", volume = 0.3, min_interval = 0.07, voices = 4 },
        monster_hit = { file = "assets/sfx/monster_hit.wav", volume = 0.34, min_interval = 0.05, voices = 4 },
        overclock_on = { file = "assets/sfx/overclock_on.wav", volume = 0.85, min_interval = 0.3, voices = 1 },
        intro_thunder = { file = "assets/sfx/intro_thunder.wav", volume = 0.9, min_interval = 0.5, voices = 1 },
        -- 화면 전환 (ui/TransitionManager)
        seal_stamp = { file = "assets/sfx/seal_stamp.wav", volume = 0.9, min_interval = 0.3, voices = 1 },
        iris_brass = { file = "assets/sfx/iris_brass.wav", volume = 0.7, min_interval = 0.2, voices = 2 },
        shutter_slam = { file = "assets/sfx/shutter_slam.wav", volume = 0.9, min_interval = 0.3, voices = 1 },
        bolt_unlock = { file = "assets/sfx/bolt_unlock.wav", volume = 0.8, min_interval = 0.3, voices = 1 },
        -- 타이틀 2.5D 배경 연출 (ui/TitleScene · ui/TitleWeather)
        title_thunder = { file = "assets/sfx/title_thunder.wav", volume = 0.78, min_interval = 0.6, voices = 2 },
        sign_creak = { file = "assets/sfx/sign_creak.wav", volume = 0.55, min_interval = 0.4, voices = 2 },
        -- '스승의 흔적' 캠페인 (tools/audio_trace.py): UV 로 찾은 스승의 은빛 인장 · 최종 보스 등장 조종 · 균열 아이기스 파훼
        seal_clue_found = { file = "assets/sfx/seal_clue_found.wav", volume = 0.7, min_interval = 0.2, voices = 1 },
        master_toll = { file = "assets/sfx/master_toll.wav", volume = 1.0, min_interval = 1.0, voices = 1 },
        aegis_break = { file = "assets/sfx/aegis_break.wav", volume = 0.95, min_interval = 0.3, voices = 1 },
    },

    -- 누르고 있는 동안만 이어지는 입력 루프(UV · 세척)와 장면 배경음·앰비언스(scene = true — scenes 목록)
    loops = {
        uv_hum = { file = "assets/sfx/uv_hum.wav", volume = 0.5 },
        scrub = { file = "assets/sfx/scrub.wav", volume = 0.6 },
        title_ambience = { file = "assets/bgm/title_ambience.wav", volume = 0.48, bus = "bgm", fade = 0.8, stream = true, scene = true },
        -- 타이틀 밖 메뉴·인트로·엔딩·결과 화면의 어두운 공방 드론
        workshop_ambient = { file = "assets/bgm/workshop_ambient.wav", volume = 0.5, bus = "bgm", fade = 0.8, stream = true, scene = true },
        -- 낮 공방: 음울한 류트·현악 + 벽난로 장작 앰비언스
        day_bgm = { file = "assets/bgm/day_bgm.wav", volume = 0.5, bus = "bgm", fade = 0.8, stream = true, scene = true },
        day_ambience = { file = "assets/bgm/day_ambience.wav", volume = 0.42, fade = 0.8, stream = true, scene = true },
        -- 밤 전투: 긴박한 저음 타악 + 포탈 저주파 앰비언스. 보스 긴장감(Audio.set_intensity — ui/RunAudio)에 따라
        --   1 = 대보스가 살아 있음 → boss_pitch · boss_gain, 2 = '스승의 흔적' 최종 보스 → final_pitch · final_gain
        --   (음높이 = 템포도 함께 빨라진다, 없는 값은 한 단계 아래 값 그대로 · 사이 값은 보간)
        night_bgm = { file = "assets/bgm/night_bgm.wav", volume = 0.55, bus = "bgm", fade = 0.8, stream = true, scene = true,
            boss_pitch = 1.06, boss_gain = 1.2, final_pitch = 1.12, final_gain = 1.4 },
        night_ambience = { file = "assets/bgm/night_ambience.wav", volume = 0.45, fade = 0.8, stream = true, scene = true,
            final_gain = 1.35 },                -- 최종 보스 앞에서는 포탈 저주파도 부풀어 오른다
    },

    -- 장면 → 함께 트는 루프 (Audio.set_scene)
    scenes = {
        title = { "workshop_ambient", "title_ambience" },
        menu = { "workshop_ambient" },
        day = { "day_bgm", "day_ambience" },
        night = { "night_bgm", "night_ambience" },
    },
    default_scene = "menu",

    -- 조건 없이 그대로 재생하는 이벤트 (발사 종류·과부하 켜짐 같은 조건부 매핑은 systems/Audio.lua)
    events = {
        ["appraisal:grade_revealed"] = "flaw_found",            -- 등급 판명 (딸깍 + 맑은 울림)
        ["appraisal:flaw_revealed"] = "uv_defect_reveal",      -- 결함·위조 적발 (날카로운 감정 적발음)
        ["appraisal:forgery_revealed"] = "uv_defect_reveal",
        ["appraisal:item_bought"] = "coin_buy",
        ["appraisal:customer_arrived"] = "shop_door_bell",        -- 새 손님: 황동 문 종소리 (그 뒤 더빙은 systems/VoiceOver)
        ["appraisal:customer_left"] = "guest_footsteps_out",      -- 돌려보내기 · 밤: 멀어지는 발걸음
        ["appraisal:item_sold"] = "coin_buy",
        ["appraisal:summoned"] = "coin_buy",
        ["shop:purchased"] = "coin_buy",
        ["upgrades:purchased"] = "coin_buy",
        ["economy:tribute_paid"] = "coin_buy",
        ["meta:upgraded"] = "coin_buy",
        ["meta:achievement_unlocked"] = "forge_success",
        ["combat:damage_dealt"] = "monster_hit",
        ["quest:accepted"] = "seal_stamp",            -- 의뢰 수락: 계약 도장
        ["quest:completed"] = "coin_buy",
        ["quest:delivered"] = "seal_stamp",           -- 의뢰 납품: 길드 인수 도장
        ["supplies:low"] = "supply_low",              -- UV 배터리·정화수 25% 아래로
        ["equip:rejected"] = "forge_dud",             -- 3분류 배치 거절 (방어구 → 진열장 · 유물 → 주인공): 둔탁한 쇳소리
        ["combat:midboss_arrived"] = "midboss_horn",  -- 중간 보스 출현 경고
        -- '스승의 흔적' 캠페인 (systems/MasterTrace · systems/MasterBossPattern · systems/DayCycle)
        ["appraisal:seal_revealed"] = "seal_clue_found",      -- UV 렌즈 아래 스승의 은빛 인장: 맑은 은빛 종 + 유리 반짝임
        ["master:journal_unlocked"] = "seal_stamp",           -- 스승의 수기 한 편이 열림: 밀랍·양피지 도장
        ["master:seal_lit"] = "flaw_found",                   -- 봉인 공명 슬롯 점화: 딸깍 + 맑은 울림 (꺼짐은 화면 연출만)
        ["master:array_complete"] = "forge_overclock_ok",     -- 봉인진 4칸 완성: 웅장한 모루 타격 + 장조 종소리
        ["calendar:interference_rose"] = "intro_thunder",     -- 새 달 아침 포탈 간섭 상승: 인트로의 마나 폭풍 천둥
        ["boss:master_arrived"] = "master_toll",              -- 최종 보스 '균열의 잔영' 등장: 깊은 조종 + 균열 드론
        ["boss:lockdown"] = "bolt_unlock",                    -- 공방 봉쇄: 룬 사슬이 빗장처럼 미끄러져 철컥 잠긴다
        ["boss:aegis_raised"] = "forge_heat",                 -- 균열 아이기스가 선다: 치솟는 금속 공명 (과부하로 깨라)
        ["boss:aegis_broken"] = "aegis_break",                -- 아이기스 파훼: 결정 파쇄 + 묵직한 저음
    },
}

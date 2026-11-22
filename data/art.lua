-- data/art.lua
-- 직접 그린 아트(assets/sprites/<id>.png — tools/extract_sprites.py 가 assets/sheets/ 시트에서 잘라 낸 것)의 목록과 표시 보정값.
-- 여기 올라 있는 id 는 원화를 쓰므로 생성 스프라이트(item_<id> / monster_<id>)를 만들지 않는다 (tools/generate_sprites.py).
-- 원화 파일이 없으면 ui/ItemShapes* · ui/MonsterShapes 의 코드 도형으로 그린다. 로직 없음.
--   flip  : 그림이 오른쪽을 보고 있으면 true (몬스터는 왼쪽 방벽을 향해 걷는다)
--   scale : 레인·칸 크기 대비 배율 (그림 여백·비율 보정)

return {
    monsters = {
        goblin = { flip = true, scale = 1.55 },             -- monsters_weapons.png
        slime = { scale = 1.6 },
        ogre = { flip = true, scale = 1.25 },               -- monsters_extra.png
        shield_bearer = { flip = true, scale = 1.35 },
        shadow_assassin = { scale = 1.85 },
        skeleton = { flip = true, scale = 1.5 },
        gatekeeper_golem = { scale = 1.25 },                -- bosses.png
        greed_raider = { flip = true, scale = 1.4 },
        abyss_necromancer = { scale = 1.45 },
        rift_lord = { scale = 1.3 },
        boss_master = { scale = 1.6 },                     -- boss_master.png ('스승의 흔적' 최종 보스, 망치가 왼쪽 방벽을 향한다)
    },
    -- 유물 32종 전부 원화 (기본 24 + 특수 8)
    items = {
        flame_sword = { scale = 1.1 },                      -- monsters_weapons.png
        lightning_orb = { scale = 1.1 },
        frost_crossbow = { scale = 1.05 },                  -- relics_base_1.png
        cursed_dagger = { scale = 1.0 },
        mana_crystal = { scale = 1.0 },
        tuning_fork = { scale = 1.0 },
        rune_tablet = { scale = 1.0 },
        golden_chalice = { scale = 1.0 },
        guardian_crest = { scale = 1.0 },
        greed_pouch = { scale = 1.0 },
        inferno_musket = { scale = 1.05 },                  -- relics_base_2.png
        ember_brazier = { scale = 1.0 },
        phoenix_feather = { scale = 1.0 },
        magma_core = { scale = 0.95 },
        storm_rod = { scale = 1.05 },
        overdrive_coil = { scale = 1.0 },
        cooling_fins = { scale = 1.0 },
        bloodstone_idol = { scale = 1.0 },
        hex_scythe = { scale = 1.05 },                      -- relics_base_3.png
        grave_lantern = { scale = 1.0 },
        blood_pact_scroll = { scale = 1.0 },
        midas_gauntlet = { scale = 1.0 },
        merchant_scale = { scale = 1.0 },
        coin_golem = { scale = 1.0 },
        starforge_hammer = { scale = 1.0 },                 -- special_relics.png
        bloodmoon_chalice = { scale = 1.0 },
        abyss_crown = { scale = 1.0 },
        golem_heart = { scale = 1.0 },
        raider_sack = { scale = 1.0 },
        necro_codex = { scale = 1.0 },
        rift_prism = { scale = 1.0 },
        tycoon_ledger = { scale = 1.0 },
    },
    -- 손님 카운터 오른쪽 원형 초상 (assets/sprites/adventurer_<id>.png, adventurers.png).
    -- 원화는 모두 오른쪽을 보므로 flip 으로 뒤집어 왼쪽 주인장 초상(오른쪽을 본다)과 마주 보게 한다.
    --   region: 원 안에 보일 영역 (그림 기준 정규화 사각형, 픽셀로 정사각형 = 원에 내접). 머리 꼭대기(모자·두건·머리카락)부터
    --           턱 아래 어깨까지 여백을 두고 들어오게 머리 상자 중심에 맞췄다 — y 가 음수면 그림 위 투명 여백까지 포함
    --   zoom  : 원 지름 대비 배율 (1 = region 이 원에 꼭 맞음)
    adventurers = {
        bern = { flip = true, zoom = 1.0, region = { x = 0.296, y = -0.030, w = 0.608, h = 0.590 } },
        rina = { flip = true, zoom = 1.0, region = { x = 0.136, y = -0.030, w = 0.588, h = 0.580 } },
        ellen = { flip = true, zoom = 1.0, region = { x = 0.092, y = -0.050, w = 0.715, h = 0.600 } },
        thorin = { flip = true, zoom = 1.0, region = { x = 0.207, y = -0.030, w = 0.586, h = 0.740 } },
        kain = { flip = true, zoom = 1.0, region = { x = 0.110, y = -0.045, w = 0.660, h = 0.586 } },
        cedric = { flip = true, zoom = 1.0, region = { x = 0.251, y = -0.034, w = 0.538, h = 0.564 } },
    },
    -- 방어구 12종 원화 (armors.png 3x4 — 순흑색 배경 전용 추출 tools/sprite_black_bg.py): assets/sprites/armor_<id>.png
    armors = { prefix = "armor_", scale = 1.0 },
    -- 포탈 내부 2.5D 결투장 배경 (2단계에서 쓴다 — 파일이 없으면 코드 배경으로 폴백)
    portal_arena = { image = "assets/backgrounds/portal_arena.png", ground_y = 0.72, dim = 0.15 },
    -- 장면용 원화 (인트로·엔딩·작업대 초상·밤 레인 건물, buildings.png): 스모크 테스트가 존재를 확인한다
    scenes = { "shopkeeper", "building_workshop", "building_portal" },
    -- UI 파츠·아이콘 (ui_props.png 3x4): 레버 받침·손잡이(예비 — 과부하 레버는 ON/OFF 가 또렷한 코드 그림, ui/OverclockLever)
    -- · 진열장/보관함 칸 타일 · 상단 바 아이콘. 없으면 코드로 그린 대체 도형(ui/Icons · Frame.inset)을 쓴다
    ui_props = {
        "ui_lever_base", "ui_lever_handle", "ui_grid_slot", "ui_storage_slot",
        "icon_gold", "icon_stone", "icon_ward", "icon_guild",
        "icon_quest", "icon_compendium", "icon_upgrade", "icon_settings",
        "cursor_hammer", "ui_anvil",     -- hammer_anvil.png: 대장장이 망치 커서(data/cursors.lua 의 hammer) · 용광로 칸 바닥 모루
    },
    -- 용광로 칸의 모루 (ui_anvil): 칸 너비 대비 폭 · 바닥에서 띄우는 거리. 강화 중에는 그 위를 망치(cursor_hammer)가 두드린다
    anvil = { width = 0.74, bottom = 6, hammer_size = 58, beat = 4.5 },
    -- 칸 타일 (ui_grid_slot = 철제·황동 소켓 / ui_storage_slot = 목재 상자): 칸보다 살짝 크게 그려 테두리가 칸 경계에 걸치게
    slot_tiles = { grid = "ui_grid_slot", storage = "ui_storage_slot", hero = "ui_storage_slot", scale = 1.08 },
    -- 밤 전투 레인 배경 (assets/backgrounds/night_lane.png, 2560x1440): 비율을 지켜 scale 배로 그리고, 원본의 돌길 윗선(road_src_y)이
    -- 화면 road_y 에 오게 맞춘다 (= LAYOUT.night.field 의 몬스터 보행 띠 바로 위). anchor_x: 가로 자르기 기준(0 왼쪽 ~ 1 오른쪽 절벽)
    -- 원본 아래 끝이 레인 바닥보다 위면 원본 돌길 아랫부분을 이어 붙이고 fill_shade 만큼 어둡게(앞쪽 그늘)
    night_lane = { image = "assets/backgrounds/night_lane.png", scale = 0.66, road_src_y = 1114, road_y = 340, anchor_x = 1.0,
        dim = 0.16, fill_shade = 0.22 },
    -- 밤 레인의 건물 (buildings.png): 공방은 왼쪽 끝 — 오른쪽 벽면(face_x)이 방벽 충돌선(LAYOUT.night.wall 오른쪽)에 닿는다.
    --   포탈은 오른쪽 끝 — 아치 안쪽 중심(arch)이 LAYOUT.night.portal.x · 보행 띠 가운데에 온다 (몬스터가 여기서 나온다).
    --   base: 그림 안의 바닥선(정규화 y) — 돌길 위에 세우고 그 아래에 접지 그림자를 깐다
    buildings = {
        workshop = { sprite = "building_workshop", height = 262, face_x = 0.84, base = 0.97, ground_y = 536 },
        portal = { sprite = "building_portal", height = 300, arch = { x = 0.517, y = 0.6 }, base = 0.97 },
    },

    -- 밤 전투 레인의 주인공 (protagonist_battle.png 1x3 — tools/extract_sprites.py 가 세 포즈를 같은 배율로 자르고 방어 포즈만 뒤집어
    -- 모두 오른쪽 = 포탈 쪽을 본다, ui/LaneHero). 공방 문 앞 결계선에 선다: x_offset = 방벽 충돌선(LAYOUT.night.wall 오른쪽)에서
    -- 발 중심까지, ground_y = 발바닥(돌길), height = 대기 포즈의 화면 높이(px — 다른 포즈도 같은 배율), pad = 그림 가장자리 투명 여백.
    -- poses.<id>.hammer · gauntlet = 그림 안 정규화 위치 (속성 오라 · 마력 섬광 · 파동이 나오는 자리). 원화가 없으면 코드 실루엣
    hero = {
        x_offset = 46, ground_y = 552, height = 132, shadow_w = 84, pad = 8, aspect = 0.66,
        order = { "idle", "attack", "block" },
        poses = {
            idle = { sprite = "protagonist_idle", hammer = { x = 0.70, y = 0.49 }, gauntlet = { x = 0.87, y = 0.28 } },
            attack = { sprite = "protagonist_attack", hammer = { x = 0.71, y = 0.48 }, gauntlet = { x = 0.90, y = 0.27 } },
            block = { sprite = "protagonist_block", hammer = { x = 0.64, y = 0.08 }, gauntlet = { x = 0.40, y = 0.20 } },
        },
    },

    -- 작업대 손님 카운터의 주인장 초상: shopkeeper.png 안의 얼굴 영역 (정규화 좌표, 얼굴은 오른쪽 = 손님 쪽을 본다)
    shopkeeper = "shopkeeper",
    shopkeeper_face = { x = 0.395, y = 0.0, w = 0.33, h = 0.31 },

    -- 공방 화면 뒤에 깔리는 실내 그림과 어둡게 덮는 정도 (낮 = assets/backgrounds/day_workshop.png, 밤 = 인트로 cut1)
    room = { image = "assets/backgrounds/day_workshop.png", night_image = "assets/intro/cut1.png",
        dim_day = 0.34, dim_night = 0.84, vignette = 0.92 },
    panel_fill_alpha = 0.8,     -- 실내 그림이 비치도록 큰 패널 바탕을 살짝 투명하게
}

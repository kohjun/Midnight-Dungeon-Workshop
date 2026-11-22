-- data/items.lua
-- 유물 원형 32종(기본 24 + 업적 해금 특수 8, 4대 아키타입), 등급, 카테고리, 속성(화염/고대/증폭), 결함 데이터. 로직 없음.
-- 이름·설명·보너스 문구는 data/locales/<언어>/items.lua 에 같은 id 로 있다 (label_key = 시너지 보너스 문구 키).
-- effects[].type 은 systems/ItemEffects.lua 의 HANDLERS 이름과 일치해야 한다.
-- shape 는 ui/ItemRenderer.lua 의 도형 이름과 일치해야 한다.
-- 무기 역할: 레이저·번개(lightning_orb·storm_rod)·서리 = 낮은 피해 + 감전·경직 제어 / 화염·물리·저주 탄환 = 메인 딜러.
-- damage_type: "physical" | "fire" | "lightning" | "frost" (균열 군주 면역·DamageRules 판정)

return {
    grade_order = { "common", "rare", "legendary" },
    grades = {
        common = { rank = 1, mult = 1.0, weight = 62, weight_per_day = -1.2, color = { 0.80, 0.82, 0.86 } },
        rare = { rank = 2, mult = 1.5, weight = 30, weight_per_day = 0.8, color = { 0.36, 0.62, 1.00 } },
        legendary = { rank = 3, mult = 2.2, weight = 8, weight_per_day = 0.6, color = { 1.00, 0.62, 0.18 } },
    },

    -- 3분류 (category): weapon = 5x5 진열장 + 주인공 무기 슬롯 / armor = 주인공 전용 (data/armors.lua) /
    -- relic = 진열장 전용 (증폭기 · 성배 · 계약서 등 비무기류 — 증폭기는 subtype = "amplifier" 로 구분한다)
    categories = { weapon = true, armor = true, relic = true },

    -- 4대 아키타입 (시너지 묶음). archetype_order = 도감·표시 순서
    archetype_order = { "fire", "lightning", "curse", "gold" },
    category_order = { "weapon", "armor", "relic" },
    role_order = { "weapon", "amplifier", "relic" },       -- 도감 정렬: 세부 구분(subtype 이 있으면 그것, 없으면 category)
    archetypes = {
        fire = { color = { 1.00, 0.50, 0.20 } },
        lightning = { color = { 0.55, 0.70, 1.00 } },
        curse = { color = { 0.80, 0.30, 0.90 } },
        gold = { color = { 1.00, 0.84, 0.30 } },
    },

    elements = {
        fire = { color = { 1.00, 0.48, 0.20 } },
        ancient = { color = { 0.98, 0.82, 0.38 } },
        arcane = { color = { 0.58, 0.68, 1.00 } },
    },

    flaws = {
        crack = { value_mult = 0.6, wear_mult = 1.6 },       -- 균열: 가치 -40% · 내구도가 1.6배 빨리 닳는다 (data/durability.lua)
        curse = {
            value_mult = 0.5,
            self_attack_mult = 1.5,   -- 저주 = 인접 디버프 + 고화력
            effects = { { type = "adjacent_curse", attack_mult = 0.75, label_key = "flaws.curse.label" } },
        },
    },

    prototypes = {
        flame_sword = {
            archetype = "fire", category = "weapon", element = "fire", shape = "sword",
            attack = 13, fire_rate = 1.1, value = 40, weight = 12, projectile = "bullet", damage_type = "fire",
            color = { 0.95, 0.42, 0.18 }, accent = { 1.00, 0.80, 0.30 },
            effects = { { type = "burn", dps = 4, duration = 2.5 }, { type = "splash", ratio = 0.35, radius = 50 } },
        },
        lightning_orb = {
            archetype = "lightning", category = "weapon", element = "arcane", shape = "orb",
            attack = 4, fire_rate = 0.7, value = 55, weight = 10, projectile = "laser", damage_type = "lightning",
            color = { 0.35, 0.45, 0.95 }, accent = { 0.75, 0.90, 1.00 },
            effects = {
                { type = "chain", count = 3, range = 160, damage_ratio = 0.6 },
                { type = "shock", duration = 2.5, slow = 0.7, slow_time = 0.6 },
            },
        },
        frost_crossbow = {
            archetype = "lightning", category = "weapon", element = "arcane", shape = "crossbow",
            attack = 6, fire_rate = 0.9, value = 45, weight = 11, projectile = "bullet", damage_type = "frost",
            color = { 0.45, 0.80, 0.95 }, accent = { 0.85, 0.97, 1.00 },
            effects = { { type = "slow", factor = 0.5, duration = 1.5 } },
        },
        cursed_dagger = {
            archetype = "curse", category = "weapon", element = "ancient", shape = "dagger",
            attack = 19, fire_rate = 1.5, value = 35, weight = 8, projectile = "bullet", damage_type = "physical",
            innate_flaw = "curse",
            color = { 0.55, 0.20, 0.55 }, accent = { 0.90, 0.30, 0.45 },
            effects = { { type = "blood_price", hp_cost = 1 } },
        },
        mana_crystal = {
            archetype = "lightning", category = "relic", subtype = "amplifier", element = "arcane", shape = "crystal",
            value = 45, weight = 12,
            color = { 0.55, 0.40, 0.95 }, accent = { 0.85, 0.75, 1.00 },
            effects = { {
                type = "adjacent_boost", target = "weapon", attack_mult = 1.5, rate_mult = 1.5,
                label_key = "items.mana_crystal.label",
            } },
        },
        tuning_fork = {
            archetype = "lightning", category = "relic", subtype = "amplifier", element = "arcane", shape = "fork",
            value = 40, weight = 10,
            color = { 0.40, 0.85, 0.75 }, accent = { 0.75, 1.00, 0.90 },
            effects = { { type = "adjacent_boost", target = "weapon", rate_mult = 1.8, label_key = "items.tuning_fork.label" } },
        },
        rune_tablet = {
            archetype = "gold", category = "relic", subtype = "amplifier", element = "ancient", shape = "tablet",
            value = 50, weight = 8,
            color = { 0.52, 0.50, 0.46 }, accent = { 0.40, 0.95, 0.80 },
            effects = { {
                type = "adjacent_boost", target = "any", attack_mult = 1.25, income_mult = 1.5,
                label_key = "items.rune_tablet.label",
            } },
        },
        golden_chalice = {
            archetype = "gold", category = "relic", element = "ancient", shape = "chalice",
            value = 90, weight = 6,
            color = { 0.95, 0.75, 0.25 }, accent = { 0.85, 0.20, 0.25 },
            effects = { { type = "income_aura", income_mult = 1.3, label_key = "items.golden_chalice.label" } },
        },
        guardian_crest = {
            archetype = "gold", category = "relic", element = "ancient", shape = "crest",
            value = 60, weight = 8,
            color = { 0.30, 0.45, 0.75 }, accent = { 0.95, 0.85, 0.45 },
            effects = { { type = "wall_guard", reduction = 0.3 } },
        },
        greed_pouch = {
            archetype = "gold", category = "relic", element = "fire", shape = "pouch",
            value = 50, weight = 9,
            color = { 0.62, 0.36, 0.20 }, accent = { 0.95, 0.80, 0.30 },
            effects = { { type = "gold_bonus", gold_mult = 1.5 } },
        },
        -- ── 확장 14종 ─────────────────────────────────────────
        inferno_musket = {
            archetype = "fire", category = "weapon", element = "fire", shape = "musket",
            attack = 20, fire_rate = 0.75, value = 60, weight = 8, projectile = "bullet", damage_type = "fire",
            color = { 0.60, 0.30, 0.18 }, accent = { 1.00, 0.55, 0.15 },
            effects = {
                { type = "burn", dps = 3, duration = 2.5 }, { type = "burn_detonate", stacks = 3, radius = 85, damage = 45 },
                { type = "splash", ratio = 0.4, radius = 55 },
            },
        },
        ember_brazier = {
            archetype = "fire", category = "relic", subtype = "amplifier", element = "fire", shape = "brazier",
            value = 50, weight = 8, color = { 0.35, 0.30, 0.30 }, accent = { 1.00, 0.45, 0.10 },
            effects = {
                { type = "adjacent_boost", target = "weapon", attack_mult = 1.2, label_key = "items.ember_brazier.label" },
                { type = "grant_burn", dps = 2, duration = 2 },
            },
        },
        phoenix_feather = {
            archetype = "fire", category = "relic", element = "fire", shape = "feather",
            value = 70, weight = 6, color = { 1.00, 0.40, 0.15 }, accent = { 1.00, 0.85, 0.30 },
            effects = { { type = "burn_amp", mult = 1.6 } },
        },
        magma_core = {
            archetype = "fire", category = "relic", element = "fire", shape = "core",
            value = 65, weight = 6, color = { 0.45, 0.15, 0.10 }, accent = { 1.00, 0.50, 0.10 },
            effects = { { type = "burn_death_blast", radius = 85, damage = 30 } },
        },
        storm_rod = {
            archetype = "lightning", category = "weapon", element = "arcane", shape = "rod",
            attack = 4, fire_rate = 1.0, value = 60, weight = 7, projectile = "laser", damage_type = "lightning",
            color = { 0.55, 0.58, 0.70 }, accent = { 0.70, 0.90, 1.00 },
            effects = {
                { type = "thunder_every", every = 25, damage = 24 },
                { type = "shock", duration = 2, slow = 0.75, slow_time = 0.4 },
            },
        },
        overdrive_coil = {
            archetype = "lightning", category = "relic", subtype = "amplifier", element = "arcane", shape = "coil",
            value = 55, weight = 8, color = { 0.80, 0.55, 0.25 }, accent = { 0.55, 0.85, 1.00 },
            effects = { { type = "adjacent_boost", target = "weapon", rate_mult = 1.35, attack_mult = 1.1, label_key = "items.overdrive_coil.label" } },
        },
        cooling_fins = {
            archetype = "lightning", category = "relic", element = "arcane", shape = "fins",
            value = 50, weight = 7, color = { 0.60, 0.70, 0.78 }, accent = { 0.55, 0.90, 1.00 },
            effects = { { type = "overheat_guard", mult = 0.5 } },
        },
        bloodstone_idol = {
            archetype = "curse", category = "relic", element = "ancient", shape = "idol",
            value = 70, weight = 6, color = { 0.45, 0.10, 0.15 }, accent = { 0.95, 0.20, 0.30 },
            effects = { { type = "curse_count_mult", per_curse = 1.2 } },
        },
        hex_scythe = {
            archetype = "curse", category = "weapon", element = "ancient", shape = "scythe",
            attack = 26, fire_rate = 0.8, value = 45, weight = 6, projectile = "bullet", innate_flaw = "curse",
            damage_type = "physical",
            color = { 0.30, 0.25, 0.35 }, accent = { 0.80, 0.20, 0.40 },
            effects = { { type = "wall_leech", hp = 1 } },
        },
        grave_lantern = {
            archetype = "curse", category = "relic", subtype = "amplifier", element = "ancient", shape = "lantern",
            value = 45, weight = 6, innate_flaw = "curse", color = { 0.25, 0.28, 0.25 }, accent = { 0.55, 1.00, 0.60 },
            effects = { { type = "adjacent_boost", target = "weapon", attack_mult = 1.8, label_key = "items.grave_lantern.label" } },
        },
        blood_pact_scroll = {
            archetype = "curse", category = "relic", element = "ancient", shape = "scroll",
            value = 40, weight = 6, color = { 0.85, 0.78, 0.62 }, accent = { 0.70, 0.08, 0.10 },
            effects = { { type = "hp_for_gold", hp_cost = 2, gold = 30 } },
        },
        midas_gauntlet = {
            archetype = "gold", category = "weapon", element = "ancient", shape = "gauntlet",
            attack = 9, fire_rate = 1.0, value = 75, weight = 6, projectile = "bullet", damage_type = "physical",
            color = { 0.95, 0.75, 0.25 }, accent = { 0.70, 0.45, 0.10 },
            effects = { { type = "gold_scaling", per_gold = 500, max_bonus = 2 }, { type = "knockback", distance = 24 } },
        },
        merchant_scale = {
            archetype = "gold", category = "relic", element = "ancient", shape = "scale",
            value = 60, weight = 7, color = { 0.80, 0.65, 0.35 }, accent = { 0.95, 0.85, 0.50 },
            effects = { { type = "sale_bonus", mult = 1.15 } },
        },
        coin_golem = {
            archetype = "gold", category = "weapon", element = "ancient", shape = "golem",
            attack = 11, fire_rate = 1.1, value = 50, weight = 8, projectile = "bullet", damage_type = "physical",
            color = { 0.70, 0.55, 0.30 }, accent = { 1.00, 0.85, 0.35 },
            effects = { { type = "kill_gold_flat", gold = 3 }, { type = "knockback", distance = 24 } },
        },
        -- ── 특수 유물 8종 (special = true: 업적으로 영구 해금되기 전에는 손님·상점에 나오지 않는다, data/achievements.lua) ──
        starforge_hammer = {
            archetype = "fire", category = "weapon", element = "fire", shape = "hammer", special = true,
            attack = 15, fire_rate = 1.0, value = 110, weight = 5, projectile = "bullet", damage_type = "fire",
            color = { 0.42, 0.36, 0.40 }, accent = { 1.00, 0.62, 0.20 },
            effects = {
                { type = "burn", dps = 5, duration = 3 }, { type = "burn_death_blast", radius = 75, damage = 28 },
                { type = "knockback", distance = 30 },
            },
        },
        bloodmoon_chalice = {
            archetype = "curse", category = "relic", element = "ancient", shape = "goblet", special = true,
            value = 95, weight = 5, color = { 0.55, 0.12, 0.16 }, accent = { 0.95, 0.25, 0.25 },
            effects = { { type = "curse_count_mult", per_curse = 1.15 }, { type = "hp_for_gold", hp_cost = 1, gold = 30 } },
        },
        abyss_crown = {
            archetype = "curse", category = "relic", subtype = "amplifier", element = "ancient", shape = "crown", special = true,
            value = 100, weight = 5, innate_flaw = "curse", color = { 0.32, 0.22, 0.40 }, accent = { 0.85, 0.30, 0.95 },
            effects = { {
                type = "adjacent_boost", target = "weapon", attack_mult = 2.2, rate_mult = 1.15,
                label_key = "items.abyss_crown.label",
            } },
        },
        golem_heart = {
            archetype = "gold", category = "relic", element = "ancient", shape = "heartstone", special = true,
            value = 90, weight = 5, color = { 0.55, 0.50, 0.44 }, accent = { 0.45, 0.95, 0.80 },
            effects = {
                { type = "wall_guard", reduction = 0.35 },
                { type = "income_aura", income_mult = 1.15, label_key = "items.golem_heart.label" },
            },
        },
        raider_sack = {
            archetype = "gold", category = "relic", element = "ancient", shape = "sack", special = true,
            value = 85, weight = 5, color = { 0.50, 0.40, 0.25 }, accent = { 0.30, 0.75, 0.35 },
            effects = { { type = "gold_bonus", gold_mult = 1.8 }, { type = "sale_bonus", mult = 1.1 } },
        },
        necro_codex = {
            archetype = "curse", category = "weapon", element = "ancient", shape = "tome", special = true,
            attack = 7, fire_rate = 0.9, value = 95, weight = 5, projectile = "laser", damage_type = "frost",
            color = { 0.20, 0.24, 0.22 }, accent = { 0.55, 1.00, 0.65 },
            effects = {
                { type = "chain", count = 2, range = 140, damage_ratio = 0.5 },
                { type = "slow", factor = 0.5, duration = 1.2 },
                { type = "wall_leech", hp = 1 },
            },
        },
        rift_prism = {
            archetype = "lightning", category = "relic", subtype = "amplifier", element = "arcane", shape = "prism", special = true,
            value = 100, weight = 5, color = { 0.30, 0.20, 0.55 }, accent = { 0.65, 0.90, 1.00 },
            effects = {
                { type = "adjacent_boost", target = "weapon", attack_mult = 1.35, rate_mult = 1.35, label_key = "items.rift_prism.label" },
                { type = "overheat_guard", mult = 0.6 },
            },
        },
        tycoon_ledger = {
            archetype = "gold", category = "relic", element = "ancient", shape = "ledger", special = true,
            value = 120, weight = 5, color = { 0.35, 0.18, 0.15 }, accent = { 0.95, 0.80, 0.35 },
            effects = {
                { type = "income_aura", income_mult = 1.4, label_key = "items.tycoon_ledger.label" },
                { type = "sale_bonus", mult = 1.12 },
            },
        },
    },
}

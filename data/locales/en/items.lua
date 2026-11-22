-- data/locales/en/items.lua
-- Names and descriptions for relic prototypes, grades, categories, archetypes, elements, flaws and monsters (English). No logic.
-- Keys match the ids in data/items.lua and data/combat.lua. label is the adjacent-synergy bonus text.

return {
    grades = { common = "Common", rare = "Rare", legendary = "Legendary" },
    categories = { weapon = "Weapon", armor = "Armor", relic = "Relic", amplifier = "Relic (amplifier)" },
    archetypes = { fire = "Fire / Burn", lightning = "Lightning / Overdrive", curse = "Curse / Blood Magic", gold = "Gold / Merchant" },
    elements = { fire = "Fire", ancient = "Ancient", arcane = "Arcane" },

    flaws = {
        crack = { name = "Crack", summary = "Wears x1.6 faster · Value -40%" },
        curse = { name = "Curse", summary = "Own attack +50% · Adjacent attack -25% · Value -50%", label = "Curse: ATK -25%" },
    },

    monsters = {
        slime = "Slime", goblin = "Goblin", ogre = "Ogre", shield_bearer = "Heavy Shieldbearer", shadow_assassin = "Shadow Assassin",
        skeleton = "Skeleton", gatekeeper_golem = "Gatekeeper Golem", greed_raider = "Greedy Goblin Raider",
        abyss_necromancer = "Abyssal Necromancer", rift_lord = "Rift Lord",
        mid_vanguard = "Ironclad Vanguard", mid_raider = "Raid Captain", mid_hexer = "Plague Hexer", mid_stalker = "Rift Stalker",
        boss_master = "Rift Shade",
    },

    items = {
        flame_sword = { name = "Flame Sword", description = "Heavy fire bolts. Burns for 2.5s on hit (4/s) and splashes 35% fire damage nearby." },
        lightning_orb = {
            name = "Chain Lightning Orb",
            description = "Low damage, but arcs to 3 nearby enemies, shocking (+20% damage taken) and staggering them.",
        },
        frost_crossbow = { name = "Frost Crossbow", description = "Slows hit enemies by 50% for 1.5s." },
        cursed_dagger = { name = "Cursed Dagger", description = "Powerful, but drains 1 wall HP every night. (Curse tolls total at most 3 a night.)" },
        mana_crystal = {
            name = "Mana Amp Crystal", description = "Adjacent weapons gain +50% attack and fire rate.",
            label = "ATK +50% · Rate +50%",
        },
        tuning_fork = { name = "Resonant Tuning Fork", description = "Adjacent weapons gain +80% fire rate.", label = "Rate +80%" },
        rune_tablet = {
            name = "Ancient Rune Tablet", description = "Adjacent relics gain +25% attack and +50% daily income.",
            label = "ATK +25% · Income +50%",
        },
        golden_chalice = {
            name = "Ancient Golden Chalice", description = "+30% daily income for the whole showcase.",
            label = "Income +30%",
        },
        guardian_crest = { name = "Guardian's Crest", description = "The wall takes 30% less damage." },
        greed_pouch = { name = "Pouch of Greed", description = "+50% gold from monster kills." },
        inferno_musket = { name = "Inferno Musket", description = "Hits splash 40% fire damage nearby. Detonates enemies at 3 burn stacks for 45 area damage." },
        ember_brazier = {
            name = "Ember Brazier", description = "Adjacent weapons gain +20% attack and their hits apply burn.",
            label = "ATK +20% · Burn on hit",
        },
        phoenix_feather = { name = "Phoenix Feather", description = "All burn damage +60%." },
        magma_core = { name = "Magma Core", description = "Burning enemies explode for 30 damage on death (can chain)." },
        storm_rod = {
            name = "Storm Lightning Rod",
            description = "Shocks and staggers on hit. Every 25 showcase shots, lightning strikes all enemies for 24.",
        },
        overdrive_coil = {
            name = "Overdrive Coil", description = "Adjacent weapons gain +35% fire rate and +10% attack.",
            label = "Rate +35% · ATK +10%",
        },
        cooling_fins = { name = "Cooling Fins", description = "Overclock extra wear -50%." },
        bloodstone_idol = {
            name = "Bloodstone Idol",
            description = "All weapons deal x1.2 attack per cursed relic on display (multiplicative).",
        },
        hex_scythe = { name = "Hex Scythe", description = "A cursed heavy weapon. Each kill restores 1 wall HP." },
        grave_lantern = { name = "Grave Lantern", description = "Cursed, but adjacent weapons gain +80% attack.", label = "ATK +80%" },
        blood_pact_scroll = { name = "Blood Pact Scroll", description = "Each night, sacrifices 2 wall HP for 30 G. (Curse tolls cap at 3 a night; pays only for what it takes.)" },
        midas_gauntlet = { name = "Midas Gauntlet", description = "+100% attack per 500 G held (max +200%). Heavy blows knock enemies back toward the portal." },
        merchant_scale = { name = "Merchant's Scale", description = "All sale prices +15%." },
        coin_golem = { name = "Coin Golem", description = "+3 gold for each kill with this weapon. Knocks enemies back toward the portal." },
        -- Special relics unlocked by achievements (data/achievements.lua)
        starforge_hammer = {
            name = "Starforge Hammer", description = "Fire bolts that burn for 3s (5/s) and knock enemies far back. Burning enemies explode for 28 on death.",
        },
        bloodmoon_chalice = {
            name = "Blood Moon Chalice",
            description = "All weapons x1.15 ATK per cursed relic. Each night, sacrifices 1 wall HP for 30 G. (Curse tolls cap at 3 a night; pays only for what it takes.)",
        },
        abyss_crown = {
            name = "Abyssal Crown", description = "Cursed, but adjacent weapons gain +120% attack and +15% fire rate.",
            label = "ATK +120% · Rate +15%",
        },
        golem_heart = {
            name = "Warden's Heartstone", description = "The wall takes 35% less damage. +15% daily income for the whole showcase.",
            label = "Income +15%",
        },
        raider_sack = { name = "Raider's Bottomless Sack", description = "+80% gold from kills. All sale prices +10%." },
        necro_codex = {
            name = "Necromancer's Codex", description = "Frost beam that chains to 2 and slows. Each kill restores 1 wall HP.",
        },
        rift_prism = {
            name = "Rift Prism", description = "Adjacent weapons gain +35% attack and fire rate. Overclock extra wear -40%.",
            label = "ATK +35% · Rate +35%",
        },
        tycoon_ledger = {
            name = "Tycoon's Ledger", description = "+40% daily income for the whole showcase. All sale prices +12%.",
            label = "Income +40%",
        },
    },
}

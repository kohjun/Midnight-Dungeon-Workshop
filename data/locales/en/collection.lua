-- data/locales/en/collection.lua
-- Relic compendium, achievements (special relic unlocks) and ending texts (English). No logic.

return {
    compendium = {
        title = "Relic Compendium",
        button = "Codex",
        menu = "Relic Compendium",
        subtitle = "Relics revealed {owned}/{total}  ·  Achievements {achieved}/{achievements}  ·  Endings {endings}/{ending_total}",
        hint = "Hover or click a relic for details   ·   ESC to close",
        kind_line = "{archetype} · {category}",
        stats_weapon = "ATK {attack}  ·  {rate} shots/s",
        stats_damage = "{damage} {projectile}",
        damage = { physical = "Physical", fire = "Fire", lightning = "Lightning", frost = "Frost" },
        projectile = { bullet = "bullets", laser = "beam" },
        synergy = "Synergy: {label}",
        innate_curse = "Innate curse: own ATK +50% · adjacent ATK -25%",
        locked_name = "Sealed Special Relic",
        unlock_condition = "Unlock: {condition}",
        unlocked_by = "Unlocked by achievement '{name}'",
        endings_title = "Endings",
        ending_unknown = "???",
        ending_target = "This contract: {gold} G+ · wall {hp}%",
        ending_target_master = "This contract: {gold} G+ (+{level} relic discount) · wall {hp}%",
        campaign_title = "The Master's Trace",
        campaign_target = "This contract: seals {lit}/{slots} · journals {journals}/{total}",
        campaign_locked = "Ending of a sealed contract — revealed after Nightmare",
        hidden_condition = "Hidden ending",
        medal_name = "True Ending Medal",
        medal_earned = "The artisan who opened the dawn — the rift is closed forever",
        medal_locked = "Earned by seeing 'Dawn of the Perfect Seal'",
    },

    -- {level} · {cursed} · {percent} in the conditions come from data/achievements.lua (systems/Achievements.condition_vars)
    achievements = {
        unlocked_toast = "Achievement: {name} — special relic '{relic}' unlocked!",
        forge_master = { name = "Legendary Smith", condition = "Succeed at the forge gamble up to +{level} on one relic." },
        blood_moon = { name = "Under the Blood Moon", condition = "Accept the black market's Blood Moon pact and survive that night." },
        cursed_quartet = { name = "Cursed Quartet", condition = "Defeat a month-end great boss with {cursed} or more cursed relics on display." },
        tycoon = { name = "Graven's Big Spender", condition = "Hold {gold} G or more within one contract." },
        golem_slayer = { name = "Gatekeeper Dismantled", condition = "Defeat the month-end great boss, the Gatekeeper Golem." },
        raider_slayer = { name = "Raider Hunter", condition = "Defeat the month-end great boss, the Greedy Goblin Raider." },
        necro_slayer = { name = "Rest for the Dead", condition = "Defeat the month-end great boss, the Abyssal Necromancer." },
        rift_slayer = { name = "Rift Sealer", condition = "Defeat the month-end great boss, the Rift Lord." },
    },

    -- {hp} · {cursed} in the conditions come from data/endings.lua (systems/Endings.condition_vars)
    ending = {
        skip = "Space / Click: continue",
        epilogue = "Epilogue",
        relocation = {
            name = "Safe Relocation",
            condition = "See the contract through and pay the final ward upkeep (default ending)",
            title = "Safe Relocation — A New Sign Inside the Walls",
            lines = {
                "The guild's red seal landed on the final ward upkeep receipt.",
                "With the relocation deposit paid, the workshop's tools and relics went onto the cart.",
                "Inside the city walls, the old sign hung again over a small shop.",
                "The portal's nightly howl is now a story from beyond the walls.",
            },
        },
        monopoly = {
            name = "Dungeon Market Monopoly",
            condition = "After upkeep: contract-sized fortune (+{level} relic: {mult}%), wall {hp}%+",
            title = "Dungeon Monopoly — The Golden Street at the Portal",
            lines = {
                "Even after the ward upkeep, the vault overflowed.",
                "The move never happened. Instead, you bought the land around the portal.",
                "Every adventurer now passes through this workshop before the dungeon.",
                "Not even the guild signs an appraisal without {address}'s approval.",
            },
        },
        true_dawn = {
            name = "Dawn of the Perfect Seal",
            condition = "Master's Trace · slay the Rift Shade on the last night with all 4 seals lit",
            title = "Dawn of the Perfect Seal — The Master's Last Appraisal",
            lines = {
                "As the four seals blazed silver-blue, the shade's hammer froze in midair.",
                "\"Well appraised, {address}. That was a fake.\" — your master's voice rang through the workshop one last time.",
                "The rift was stitched shut like a seam, leaving only rune-carved stones on the cliff.",
                "Morning light found the signboard. No upkeep collector will ever knock again.",
                "Your master's old loupe lies on the workbench. Today, too, it waits for the first customer.",
            },
        },
        new_gatekeeper = {
            name = "The New Gatekeeper",
            condition = "Master's Trace · survive the last night without completing the seal",
            title = "The New Gatekeeper — Before a Gate That Would Not Close",
            lines = {
                "The last night passed, but a dark seal array could not close the gate.",
                "The rift breathed in and drew {address}'s shadow toward it.",
                "As your master once did, {address} now holds the gate from the inside.",
                "A new apprentice keeps the workshop, and customers' relics arrive with an unfamiliar silver seal.",
            },
        },
        abyss = {
            name = "Abyssal Dominion",
            condition = "Nightmare · {share}%+ of displayed relics cursed ({cursed}+) · final boss slain",
            title = "Abyssal Dominion — The Portal Greets Its New Master",
            lines = {
                "On the last night, the cursed relics wailed crimson as one.",
                "Beyond the portal, the fallen lord's throne stood empty.",
                "{address} walked into the rift, the showcase keys in hand.",
                "Now the Dungeon Guild comes to this workshop to pay its upkeep.",
            },
        },
    },
}

-- data/locales/en/game.lua
-- Difficulty, contract, tutorial, workshop upgrade, guild shop, black market and permanent stat text (English). No logic.
-- Keys match the ids in data/difficulties, tutorial, upgrades, shop, events and meta.

return {
    difficulty = {
        apprentice = {
            name = "Apprentice Appraiser", tier = "Easy", playtime = "about 1 hour",
            summary = { "30 days (3 months) · Start 200 G", "Upkeep x0.9 · due at month-end", "Forge +10%p · Overclock x1.4 · No extra wear" },
            briefing = "The guild's shortest contract: three months. Learn appraisal and night defense free of overclock wear while you save for the move.",
        },
        broker = {
            name = "Midnight Broker", tier = "Normal", playtime = "about 2 hours",
            summary = { "60 days (6 months) · Start 180 G", "Upkeep x1.4 · More grade fakers", "Overclock wear x1.8" },
            briefing = "For half a year the guild collector comes at every month's end. Spot the liars and ration your overclock.",
        },
        veteran = {
            name = "Veteran of Graven", tier = "Hard", playtime = "about 4 hours",
            summary = { "120 days (1 year) · Four seasons", "Overclock wear x2.3 · Hot summer · Sly autumn", "Winter: tough foes · Upkeep +15%" },
            briefing = "A one-year contract. Every season rewrites the rules of running the shop. Only appraisers who read the seasons survive.",
        },
        abyss = {
            name = "Fence of the Abyss", tier = "Nightmare", playtime = "about 5 hours",
            summary = { "120 days · Extreme seasons (x1.35)", "Overclock wear x3.0 · Many curses", "Strong bosses · Legendary x2.5" },
            briefing = "The abyss beyond the portal is boiling. To last a year you must brave extreme seasons and wield even cursed relics.",
        },
        master_trace = {
            name = "The Master's Trace", tier = "True End", playtime = "about 2 hours",
            summary = { "60-day true-ending campaign · Rift", "UV silver seals → 6 master's journals", "Light 4 seal sockets · Final boss" },
            briefing = "A contract open only to appraisers who outlasted the Nightmare. Customers' relics arrive stamped with your "
                .. "master's silver seal. Gather the journals, light the seal array, and close the rift on the last night.",
            veiled = {      -- before a Nightmare clear: the burnt-parchment "???" seal card
                name = "???", tier = "Sealed", playtime = "???",
                summary = { "Blotted out in black ink", "Clauses the Guild won't speak of", "Unseal: complete Nightmare" },
            },
        },
    },

    story = {
        signature_label = "Sign:",
        signature_role = "(Owner of the Graven outskirts workshop)",
        name_placeholder = "Write your name",
        empty_name = "You must write a name on the signature line to sign.",
        default_name = "Nameless",
        address = "Boss {name}",
    },

    tutorial = {
        label = "Tutorial",
        skip = "Skip",
        next = "Next",
        steps = {
            hud_status = "Top-left status cards — the day/phase badge, wall durability (0 means defeat), your gold and tempering stones (fuel for +2 and higher).",
            hud_tribute = "Ward upkeep is collected automatically at dawn on the last day of each month (every 10 days). Be short on gold by then and the ward falls: instant eviction (bankrupt)! A red pulsing card is your warning.",
            menu_bar = "Top menu — [Guild] upkeep schedule & supplies · [Quests] bonus jobs (number badge) · [Codex] relic & monster info · [Upgrades] permanent upgrades · [Menu] volume & language. Opening the menu during a night battle pauses it.",
            areas = "The workshop has three areas: the bench on the left (guests, appraisal, cleaning, forging), the hero gear panel (weapon, helmet, armor, boots) with its spare rack top-right, and the 5x5 resonance showcase bottom-right (25 sockets wired by mana conduits: the circuit that fights at night).",
            scan = "Your first guest, {address}! Turn on the [UV Scanner] (1) and sweep while holding the button. Genuine, high grades and special marks are good finds; exposing forged seals, hidden curses or cracks slashes the price.",
            buy = "Crack exposed! The tag shows the flaw and the asking price dropped. [Buy] (3) it cheap.",
            clean = "Turn on the [Scrub Brush] (2) and scrub to 0% grime — sale price and attack x1.5. UV battery and purifying water run down as you use them and only refill a little each morning, so use them wisely.",
            forge_info = "Alchemy Forge (4): forge from +1 to +10. +1 costs only gold (100%); from +2 it also takes stones. Each level raises power and synergy (+10 = x4.8) but lowers the odds — from +4 a failure drops a level, from +6 it may shatter. A successful forge resets durability to 100% (failure keeps it), and +10 grants the immortal seal: no more wear! [Next]",
            stash = "Send the cleaned relic off with [Auto-place] — weapons and relics go to the first free cell of the 5x5 resonance showcase, armor is equipped on the hero's empty slot (or the spare rack when there is no room). Normal purchases are auto-placed by the same rule.",
            place = "Items come in three kinds — weapons (showcase + the hero's weapon slot), armor (hero only) and relics (showcase only). Showcase cells are wired by mana conduits and the center is the resonance circuit core. Drag to move, or right-click to swap at once. The weapon you equip, {address}, is the one you swing at the door at night.",
            night = "All set! Press [Close Shop] (Space) to drop the shutter and start your first defense.",
            night_grid = "Night has fallen (the battle waits while you read). With the shutter down, mana runs through the conduits: neighboring relics amplify each other and the power gathers on you at the door, {address}. Weapons attack differently — physical knockback, fire splash, lightning shock & stagger, curses. Amplifiers boost the weapons wired next to them, so cluster them.",
            night_lever = "Overclock lever (Space): it forces the circuit's output up — fire rate x{rate} and kill gold x{gold}! Relics drained of mana wear a little every night from metal fatigue (the gauge under each cell), and while overclocked they wear faster by your contract's overheat risk (no extra wear for Apprentice). At 0% a relic stops working — forge it by day to restore 100%.",
            night_speed = "Top-right [>] (Tab) sets battle speed 1/2/3x; hover a monster to see its HP and resistances. In a pinch, [Menu] (Esc) pauses at any time. Press [Next] to start the battle!",
            defend = "Monsters pour from the portal! Clear the whole wave and morning comes after the dawn tally. Survive your first night.",
        },
        exploded = "The relic exploded! Take a new customer and try again.",
        completed = "Tutorial complete! This workshop is yours now, {address}.",
    },

    upgrades = {
        grid = {
            name = "Showcase Expansion", description = "Unseals more grid cells.",
            levels = { "3x3 → 3x4", "3x4 → 4x4", "4x4 → 4x5", "4x5 → 5x5" },
        },
        lens = {
            name = "UV Lens Upgrade", description = "Wider lens · lower battery drain.",
            levels = { "Radius +12 · Drain -20%", "Radius +24 · Drain -40%", "Drain -50% · Auto-detects 1 flaw on customer relics" },
        },
        brush = {
            name = "High-Pressure Brush", description = "Less water used · higher full-clean bonus.",
            levels = { "Water use -25%", "Water use -40% · Full clean x1.75" },
        },
        furnace = {
            name = "Furnace Stabilizer", description = "Higher forge success · more scrap on failure.",
            levels = { "Success +5%p", "Success +10%p · Scrap x2", "Success +15%p · Scrap x3" },
        },
        wall = {
            name = "Wall Reinforcement", description = "Raises max wall HP (healed by the amount gained).",
            levels = { "Max HP +20", "Max HP +45", "Max HP +75" },
        },
    },

    shop = {
        uv_pack = { name = "Concentrated UV Battery Pack", text = "UV battery +60%" },
        water_barrel = { name = "Blessed Water Barrel", text = "Purified water +60%" },
        repair_kit = { name = "Wall Repair Kit", text = "Wall HP +30" },
        tempering_stone = { name = "Tempering Stone", text = "Fuel for +2 and higher forging (1 per day)" },
        appraisal_scroll = { name = "Instant Appraisal Scroll", text = "Fully appraises the bench relic once (no battery)" },
        rare_relic = { name = "Guild-Certified Rare Relic", text = "A cleaned, appraised rare relic or armor piece (auto-placed)" },
    },

    events = {
        mystery_boxes = {
            name = "Mystery Sealed Boxes",
            banner = "A black market dealer brought 3 sealed boxes that cannot be appraised.",
            boxes = { "Rusty Sealed Box", "Silver Sealed Box", "Obsidian Sealed Box" },
        },
        fence_request = {
            name = "Fence's Urgent Request",
            banner = "Fence: \"I'll buy flawed goods as-is for 2.5x. Only until sundown.\"",
        },
        blood_moon = {
            name = "Blood Moon",
            banner = "A blood moon rises. Monsters grow stronger tonight, but survive and the guild cuts your ward upkeep.",
        },
    },

    meta = {
        start_capital = { name = "Starting Capital", text = "Starting gold +40 G / Lv" },
        trade = { name = "Trade Savvy", text = "Sale prices +6% / Lv" },
        appraisal_eye = { name = "Appraiser's Eye", text = "UV battery drain -10% / Lv" },
        alchemy = { name = "Alchemy Mastery", text = "Forge success +3%p / Lv" },
        workshop_design = { name = "Workshop Blueprint", text = "Wall HP +10 / Lv · Lv.3: start with a 3x4 grid" },
        black_market = { name = "Black Market Ties", text = "Black market chance +8%p · Summon cost -4 G / Lv" },
    },
}

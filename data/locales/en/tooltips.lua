-- data/locales/en/tooltips.lua
-- Hover tooltips for the top HUD and workshop tools (English, ui/HoverTooltip). No logic.

return {
    hover = {
        badge = {
            title = "Day · Phase",
            day = "Day: appraise and buy guest relics, then arrange the showcase. Free guests left today: {count}.",
            night = "Night: monsters pour out of the portal. {seconds}s until dawn — clear the whole wave for morning to come.",
            contract = "{date} — day {day} of {max}; survive to the last day to win. 1 month = 10 days · upkeep at month-end · bosses mid-month and month-end.",
            season = "Season {season}: {effect} (changes every 30 days)",
        },
        ward = {
            title = "Wall {hp} / {max}",
            body = "Drops when monsters reach the workshop or cursed relics gnaw at it. At 0 you lose. Reinforce it in [Upgrades].",
        },
        tribute = {
            title = "Ward upkeep",
            none = "No more ward upkeep is due in this contract.",
            due = "{amount} G is collected at dawn of {date} (D-{days}). You hold {gold} G.",
            short = "{shortfall} G short — miss it and the ward falls: instant eviction (bankrupt)!",
            ready = "Ready — it is paid automatically at dawn.",
        },
        gold = {
            title = "Gold {gold} G",
            body = "Spent on buying, summoning guests, +1 refining, guild supplies and ward upkeep. Showcase income arrives every morning.",
        },
        stones = {
            title = "Tempering stones: {count}",
            body = "Fuel for +2 and higher forging (+2~3: 1 · +4~5: 2 · +6~7: 3 · +8~10: 4~6). From night kills (at most 1 a night), mid-bosses and great bosses, the [Guild] shop (1 a day) and guild quests.",
        },
        guild = { title = "Guild", body = "Lore · ward upkeep schedule · supply shop (water · UV battery · stones). Day only; the game pauses while open." },
        quests = { title = "Quests", body = "Black market offers and guild quests. The number = offers waiting. Accept or decline by day; the game pauses while open." },
        compendium = { title = "Codex", body = "Stats, synergies and unlock conditions of all 32 relics, plus ending collection. The game pauses while open." },
        upgrades = { title = "Upgrades", body = "Showcase expansion · UV lens · pressure brush · forge stabilizer · wall reinforcement. Day only." },
        settings = {
            title = "Menu (Esc)",
            body = "System menu: resume · settings · restart · return to title.",
            pause = "Opening the menu during a night battle pauses the battle.",
        },
        uv = {
            title = "UV Scanner (1)",
            body = "Turn it on, then hold the left button and sweep over the bench relic. Exposing the true grade, forgeries, curse marks or cracks lowers the price.",
            cost = "Drains {rate}% UV battery per second while the lens is lit (now {value}% · warns below {low}%).",
        },
        brush = {
            title = "Scrub Brush (2)",
            body = "Scrub your relic to remove grime. Fully clean (0%) means sale price and attack x1.5.",
            cost = "Uses {cost}% purified water per 10% grime · {full}% for a full clean (now {value}% · warns below {low}%).",
        },
        furnace = {
            title = "Alchemy Forge (4)",
            body = "Forge +1 to +10: gold (plus stones from +2). Success +2 {c2}% · +5 {c5}% · +8 {c8}% · +10 {c10}%. Power and synergy grow each level, x4.8 at +10.",
            risk = "Failure: +2~3 keep the level · +4~5 drop 1 · +6 and up drop or shatter.",
            durability = "A successful forge resets durability to 100% (failure keeps it). +10 is the immortal seal — no wear.",
        },
        storage = { title = "Spare Rack", body = "Three slots for swapping armor, queuing forges, or overflow when the showcase is full. Drag items out, or right-click to equip or display them at once. Racked items do not fight at night." },
        grid = {
            title = "5x5 Resonance Showcase",
            body = "Twenty-five sockets wired side to side and top to bottom by mana conduits. Weapons set here fire through the circuit at night. Amplifiers boost the weapons wired next to them; sealed cells open via [Upgrades].",
            core = "Resonance circuit core (3,3): the heart of the circuit — the relic here tints the hero's aura at the door. The weapon the hero actually swings is equipped in the weapon slot of the gear panel.",
        },
    },
}

-- data/adventurers.lua
-- 공방을 찾는 고유 모험가 6인. 손님이 올 때마다 한 명이 방문해 그 성향대로 유물을 가져온다 (systems/ItemFactory).
-- 이름·이명·대사·특성 태그 문구는 data/locales/<언어>/guild.lua 의 adventurers.<id> / adventurers.tags.<tag>. 로직 없음.
--   weight        : 방문 가중치 (난이도 customer.adventurer_weights 가 곱해진다)
--   badge         : 손님 카운터의 뱃지·두건 색
--   tone          : 대사 톤 (문구 묶음 이름, 로케일 adventurers.<id>.lines)
--   tags          : 카운터에 표시하는 특성 태그 (로케일 adventurers.tags.<tag>)
--   prefers       : 선호 유물 — archetypes / categories / shapes 중 하나라도 맞으면 등장 가중치 x mult
--   contamination : 가져오는 유물의 오염도 범위(%)
--   flaw_mult     : 결함 확률 배율 · curse_mult : 저주 결함·고유 저주 원형 가중치 배율
--   honest_mult   : 등급을 정직하게 말할 확률 배율 (낮을수록 위조 잦음) · overclaim : 거짓말일 때 부풀릴 확률(없으면 난이도 값)
--   legendary_mult: 전설 등급 가중치 배율 · haggle : 흥정 성향 = 제시가 배율
--   reaction      : 결함·위조를 들켰을 때 초상의 반응 (ui/GuestReaction) — flinch = 움찔 떨림 세기, tilt = 몸을 젖히는(+)·들이미는(-) 정도
--                   대사는 로케일 adventurers.<id>.caught.{forgery, curse, crack}

return {
    order = { "bern", "rina", "ellen", "thorin", "kain", "cedric" },

    list = {
        bern = {
            weight = 1, badge = { 0.62, 0.70, 0.82 }, tone = "gruff", tags = { "melee", "honest" },
            prefers = { categories = { "weapon" }, shapes = { "sword", "dagger", "hammer", "scythe", "gauntlet" }, mult = 3 },
            contamination = { min = 25, max = 60 },
            flaw_mult = 0.8, curse_mult = 0.5, honest_mult = 1.3, legendary_mult = 1, haggle = 1.0,
            reaction = { flinch = 0.4, tilt = -0.05 },          -- 순순히 인정
        },
        rina = {
            weight = 1, badge = { 0.86, 0.62, 0.28 }, tone = "sly", tags = { "filthy", "treasure" },
            prefers = { archetypes = { "gold" }, categories = { "relic" }, mult = 3 },
            contamination = { min = 60, max = 95 },
            flaw_mult = 1.3, curse_mult = 1, honest_mult = 0.9, legendary_mult = 1.2, haggle = 0.9,
            reaction = { flinch = 1.2, tilt = 0.08 },           -- 화들짝 놀라 변명
        },
        ellen = {
            weight = 1, badge = { 0.48, 0.62, 1.00 }, tone = "timid", tags = { "arcane", "naive" },
            prefers = { archetypes = { "lightning" }, categories = { "amplifier" }, mult = 3 },
            contamination = { min = 30, max = 70 },
            flaw_mult = 1.1, curse_mult = 1, honest_mult = 1.0, overclaim = 0.15, legendary_mult = 1, haggle = 0.85,
            reaction = { flinch = 1.4, tilt = 0.1 },            -- 당황해서 어쩔 줄 모름
        },
        thorin = {
            weight = 1, badge = { 0.95, 0.46, 0.20 }, tone = "proud", tags = { "smith", "stubborn" },
            prefers = { archetypes = { "fire" }, categories = { "weapon" }, mult = 3 },
            contamination = { min = 15, max = 50 },
            flaw_mult = 0.6, curse_mult = 0.7, honest_mult = 1.3, legendary_mult = 1.1, haggle = 1.15,
            reaction = { flinch = 0.3, tilt = -0.12 },          -- 버럭 들이밀며 우김
        },
        kain = {
            weight = 1, badge = { 0.66, 0.30, 0.86 }, tone = "cold", tags = { "cursed", "shady" },
            prefers = { archetypes = { "curse" }, mult = 4 },
            contamination = { min = 40, max = 90 },
            flaw_mult = 1.2, curse_mult = 3, honest_mult = 0.8, legendary_mult = 1, haggle = 0.95,
            reaction = { flinch = 0.2, tilt = 0.03 },           -- 눈 하나 깜짝 안 함
        },
        cedric = {
            weight = 1, badge = { 0.92, 0.80, 0.40 }, tone = "haughty", tags = { "forger", "pricey" },
            prefers = { archetypes = { "gold" }, mult = 2 },
            contamination = { min = 20, max = 55 },
            flaw_mult = 1.0, curse_mult = 1, honest_mult = 0.4, overclaim = 0.95, legendary_mult = 1.8, haggle = 1.3,
            reaction = { flinch = 0.9, tilt = 0.14 },           -- 모욕당한 듯 몸을 젖힘
        },
    },
}

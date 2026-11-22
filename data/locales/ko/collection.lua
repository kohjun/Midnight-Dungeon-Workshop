-- data/locales/ko/collection.lua
-- 유물 도감 · 업적(특수 유물 해금) · 엔딩 문구 (한국어). 로직 없음.

return {
    compendium = {
        title = "유물 도감",
        button = "도감",
        menu = "유물 도감",
        subtitle = "공개된 유물 {owned}/{total}  ·  업적 {achieved}/{achievements}  ·  엔딩 {endings}/{ending_total}",
        hint = "유물을 가리키거나 클릭해 자세히 보기   ·   ESC 닫기",
        kind_line = "{archetype} · {category}",
        stats_weapon = "공격력 {attack}  ·  초당 {rate}발",
        stats_damage = "{damage} 속성 {projectile}",
        damage = { physical = "물리", fire = "화염", lightning = "번개", frost = "서리" },
        projectile = { bullet = "탄환", laser = "광선" },
        synergy = "시너지: {label}",
        innate_curse = "고유 저주: 자신 공격 +50% · 인접 유물 공격 -25%",
        locked_name = "봉인된 특수 유물",
        unlock_condition = "해금 조건: {condition}",
        unlocked_by = "업적 '{name}' 달성으로 해금",
        endings_title = "엔딩 수집",
        ending_unknown = "???",
        ending_target = "이번 계약: {gold} G 이상 · 방벽 {hp}%",
        ending_target_master = "이번 계약: {gold} G 이상(+{level} 유물 할인) · 방벽 {hp}%",
        campaign_title = "스승의 흔적",
        campaign_target = "이번 계약: 봉인진 {lit}/{slots} · 수기 {journals}/{total}",
        campaign_locked = "봉인된 계약의 결말 — 악몽을 완수하면 드러난다",
        hidden_condition = "숨겨진 결말",
        medal_name = "진엔딩 훈장",
        medal_earned = "새벽을 연 장인 — 균열의 문을 영원히 닫았다",
        medal_locked = "'새벽의 완전 봉인'을 보면 받는다",
    },

    -- 조건 문구의 {level} · {cursed} · {percent} 는 data/achievements.lua 의 값 (systems/Achievements.condition_vars)
    achievements = {
        unlocked_toast = "업적 달성: {name} — 특수 유물 '{relic}' 해금!",
        forge_master = { name = "전설의 대장장이", condition = "용광로 강화 도박으로 유물을 +{level}까지 성공시킨다." },
        blood_moon = { name = "핏빛 달 아래에서", condition = "암시장의 핏빛 달 계약을 받고 그 밤을 버텨낸다." },
        cursed_quartet = { name = "저주받은 사중주", condition = "진열장에 저주 유물 {cursed}개 이상을 둔 채 월말 대보스를 쓰러뜨린다." },
        tycoon = { name = "그레이븐의 큰손", condition = "한 계약 안에서 골드 {gold} G 이상을 모은다." },
        golem_slayer = { name = "문지기 해체", condition = "월말 대보스 '던전 문지기 골렘'을 쓰러뜨린다." },
        raider_slayer = { name = "약탈자 사냥꾼", condition = "월말 대보스 '탐욕의 고블린 약탈자'를 쓰러뜨린다." },
        necro_slayer = { name = "망자의 안식", condition = "월말 대보스 '심연의 사령술사'를 쓰러뜨린다." },
        rift_slayer = { name = "균열 봉인자", condition = "월말 대보스 '차원의 균열 군주'를 쓰러뜨린다." },
    },

    -- 조건 문구의 {hp} · {cursed} 는 data/endings.lua 의 값 (systems/Endings.condition_vars)
    ending = {
        skip = "Space / 클릭: 넘기기",
        epilogue = "에필로그",
        relocation = {
            name = "무사 이주",
            condition = "계약을 끝까지 지키고 마지막 결계 유지비를 낸다 (기본 결말)",
            title = "무사 이주 — 성벽 안의 새 간판",
            lines = {
                "마지막 결계 유지비 영수증에 길드의 붉은 도장이 찍혔다.",
                "이주 보증금을 치르고, 공방의 연장과 유물을 짐수레에 실었다.",
                "성벽 안 골목의 작은 가게에 낡은 간판을 다시 걸었다.",
                "밤마다 들리던 포탈의 울음은 이제 먼 성벽 너머의 이야기다.",
            },
        },
        monopoly = {
            name = "던전 상권 독점",
            condition = "유지비 뒤에도 계약 규모만큼 재산(+{level} 유물: {mult}%) · 방벽 {hp}% 이상",
            title = "던전 상권 독점 — 포탈 앞 황금 거리",
            lines = {
                "결계 유지비를 내고도 금고가 넘쳐흘렀다.",
                "이주는 없던 일이 되었다. 대신 포탈 앞 땅을 통째로 사들였다.",
                "모험가들은 이제 던전에 들어가기 전에 반드시 이 공방을 거친다.",
                "길드조차 {address}의 허락 없이는 감정서를 쓰지 못한다.",
            },
        },
        true_dawn = {
            name = "새벽의 완전 봉인",
            condition = "스승의 흔적 · 봉인진 4/4 점화 상태로 마지막 밤 균열의 잔영 처치",
            title = "새벽의 완전 봉인 — 스승의 마지막 감정서",
            lines = {
                "네 개의 봉인이 은청색으로 타오르자, 잔영의 망치가 허공에서 멈췄다.",
                "\"잘 감정했다, {address}. 그건 가짜였다.\" — 스승의 목소리가 마지막으로 공방을 울렸다.",
                "균열은 바늘땀처럼 꿰매어 닫혔고, 절벽에는 룬이 새겨진 돌만 남았다.",
                "아침 햇살이 간판을 비췄다. 이제 결계 유지비 징수원은 오지 않는다.",
                "작업대 위에는 스승의 낡은 확대경이 놓여 있다. 오늘도 첫 손님을 기다린다.",
            },
        },
        new_gatekeeper = {
            name = "새로운 문지기",
            condition = "스승의 흔적 · 봉인을 완성하지 못한 채 마지막 밤을 넘긴다",
            title = "새로운 문지기 — 닫히지 않은 문 앞에서",
            lines = {
                "마지막 밤은 지나갔지만, 꺼진 봉인진은 문을 닫지 못했다.",
                "균열이 숨을 들이쉬듯 {address}의 그림자를 끌어당겼다.",
                "스승이 그랬듯, 이제는 {address}이 포탈 안쪽에서 문을 버틴다.",
                "공방에는 새 견습생이 들어왔고, 손님의 유물에는 낯선 은빛 인장이 찍혀 온다.",
            },
        },
        abyss = {
            name = "심연 장악",
            condition = "심연의 장물아비 · 진열 유물의 {share}% 이상(최소 {cursed}개)이 저주인 채 최종일 보스 처치",
            title = "심연 장악 — 포탈이 새 주인을 맞이했다",
            lines = {
                "마지막 밤, 저주받은 유물들이 일제히 붉게 울었다.",
                "쓰러진 군주의 왕좌가 포탈 저편에서 비어 있었다.",
                "{address}은 진열장의 열쇠를 쥔 채 균열 안으로 걸어 들어갔다.",
                "이제 던전 관리 길드가 결계 유지비를 내러 이 공방을 찾아온다.",
            },
        },
    },
}

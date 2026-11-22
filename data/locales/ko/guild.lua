-- data/locales/ko/guild.lua
-- 길드·의뢰·모험가 문구 (한국어): [길드] 창, [의뢰] 창(길드 의뢰 · 암시장 제안), 위험도, 고유 모험가 6인. 로직 없음.
-- {address} 는 플레이어 호칭으로 치환된다 (Workshop:personalize).

return {
    guild = {
        title = "그레이븐 던전 관리 길드",
        subtitle = "보유 골드 {gold} G  ·  연마석 {stones}개  ·  보급품은 낮에도 같은 값",
        lore = "마나 폭풍이 공방 옆에 던전 포탈을 열어젖힌 뒤, 그레이븐 시의 던전 관리 길드가 결계를 세웠다. 결계가 서 있는 한 포탈 너머의 것들은 밤에만 기어 나오지만, 그 대가로 길드는 매달 말일마다 결계 유지비를 걷는다. 단 하루라도 미납하면 결계는 걷히고 공방은 즉시 퇴거다. 길드는 장부만큼은 정직하다 — 보급품은 언제나 같은 값이다.",
        upkeep_title = "결계 유지비 현황",
        schedule_title = "계약 기간 납부 일정",
        schedule_paid = "{date}  {amount} G  · 납부 완료",
        schedule_tonight = "{date}  {amount} G  · 오늘 밤",
        schedule_due = "{date}  {amount} G",
        schedule_more = "… 이후 {count}회 더 (계약 끝까지)",
        schedule_paid_count = "납부 완료 {count}회",
        shop_title = "길드 보급 상점",
        daily_left = "오늘 남은 수량 {left}/{limit}  ·  보유 {have}개",
    },

    quest_ui = {
        title = "의뢰 게시판",
        subtitle = "수락을 기다리는 의뢰 {count}건  ·  수락·거절·납품은 낮에만 · 수락한 의뢰는 기한을 넘기면 위약금",
        empty = "오늘은 들어온 의뢰가 없습니다.",
        empty_detail = "암시장 상인이나 길드 전령이 들르면 여기에 의뢰가 붙습니다.",
        source_market = "암시장 제안",
        source_guild = "길드 의뢰 · {category}",
        state_pending = "대기 중",
        state_accepted = "진행 중",
        state_done = "달성",
        state_failed = "실패",
        story = "배경",
        goal = "달성 조건",
        reward = "보상",
        penalty = "기한 초과 시",
        risk = "위험도",
        accept = "수락",
        decline = "거절",
        deliver = "납품",
        day_only = "의뢰 수락·거절·납품은 낮에만 할 수 있습니다.",
        deliver_none = "납품할 의뢰가 아닙니다.",
        deliver_missing = "임시 거치대·작업대에 조건에 맞는 유물이 없습니다. (진열장 유물은 먼저 거치대로 옮기세요)",
        reward_gold = "{gold} G",
        reward_stones = "연마석 {stones}개",
        reward_discount = "다음 결계 유지비 -{percent}%",
        reward_repair = "방벽 긴급 수리 +{amount}",
        payout_discount = "다음 결계 유지비 -{amount} G",
        payout_repair = "방벽 +{amount}",
        reward_join = "  ·  ",
        card_reward = "보상: {reward}",
        card_deadline = "기한 {date} 밤까지 (D-{days})",
        card_deadline_today = "기한 오늘 밤까지 (D-Day)",
        deadline = "{date} 밤이 끝날 때까지 (오늘 포함 {days}일)",
        deadline_today = "오늘 밤이 끝날 때까지",
        penalty_text = "위약금 {fine} G를 즉시 냅니다. 골드가 모자라면 남은 몫은 다음 결계 유지비에 더해집니다.",
        penalty_none = "수락하기 전에는 벌칙이 없습니다 — 그날 밤이 오면 게시판에서 내려갑니다.",
        box_line = "{name}  ·  {grades} 등급 +{min}~{max}",
        progress_count = "진행 {now} / {target}",
        progress_overclock = "과부하 유지 {now} / {target}초 — 새벽에 판정 (그 밤을 버텨야 함)",
        progress_deliver_ready = "조건에 맞는 유물이 있습니다 — [납품]을 누르세요",
        progress_deliver_wait = "조건에 맞는 유물을 임시 거치대·작업대에 준비하세요",
        progress_done = "달성! 보상을 받았습니다.",
        progress_failed = "기한 안에 끝내지 못했습니다. 위약금 {fine} G (유지비 가산 {surcharge} G)",
        category = { forge = "단조 납품", appraisal = "감정 적발", combat = "전투", purify = "정화 납품" },
        element = { fire = "화염", lightning = "번개", frost = "서리", curse = "저주", gold = "황금" },
    },

    risk = { none = "없음", low = "낮음", mid = "보통", high = "높음" },

    quests = {
        forge_delivery = {
            name = "단조 유물 납품",
            story = "길드 무기고가 바닥났다. 감찰관이 공방 용광로에서 두드린 유물을 원한다. \"{address}, 불에 단련된 물건이라야 결계 수비대가 씁니다.\"",
            goal = "{grade} 등급 이상 · +{level} 이상 강화한 유물 1점 [납품]",
        },
        expose_fraud = {
            name = "위조 인장 적발",
            story = "길드 인장을 위조한 유물과 저주를 숨긴 유물이 시장에 돈다. 길드는 감정사의 눈으로 사기꾼을 가려내 달라고 한다.",
            goal = "수락한 뒤 손님 유물의 등급 위조(가짜 길드 인장) 또는 숨은 저주를 UV 로 {target}번 적발",
        },
        overclock_trial = {
            name = "과부하 내구 시험",
            story = "길드 결계사들이 공방 진열장의 과부하 한계를 재고 싶어 한다. 레버를 내린 채 밤을 버텨 보라는 것이다.",
            goal = "하룻밤에 과부하 레버를 {target}초 이상 켠 채 그 밤을 버틴다 (과부하 중에는 유물이 더 빨리 닳는다)",
        },
        boss_hunt = {
            name = "{boss_time} 보스 토벌",
            story = "포탈 감시탑이 큰 그림자를 보았다. 길드는 그것이 결계를 두드리기 전에 공방 앞에서 쓰러뜨리기를 원한다.",
            goal = "{date} 밤에 나타나는 보스 '{boss}'를 쓰러뜨린다",
        },
        purify_delivery = {
            name = "{element} 유물 정화 납품",
            story = "길드 창고에 마나 찌꺼기가 엉겨 붙은 {element} 유물이 필요하다. 결계 정비에 쓸 수 있도록 깨끗하게 닦아 오라고 한다.",
            goal = "{element} 속성 유물을 오염도 0%로 완세척해 1점 [납품]",
        },
        boss_time = { mid = "월 중순", month_end = "월말" },
    },

    market_quests = {
        mystery_boxes = {
            story = "두건 쓴 상인이 감정 불가 봉인 상자 세 개를 뒷문에 내려놓았다. \"열어 보기 전엔 아무도 모르지요, {address}.\"",
            goal = "수락하면 상자 3종(녹슨 · 은빛 · 흑요석)을 골드로 사서 열 수 있다 (오늘 낮까지)",
            reward = "{success}% 확률로 고강화 희귀·전설 유물",
            accepted = "상인이 상자를 펼쳐 놓았다 — 오른쪽 버튼으로 개봉",
        },
        fence_request = {
            story = "장물아비가 은밀히 찾아왔다. \"결함품을 수리 없이 사들이겠소. 오늘 해 질 때까지만이오.\"",
            goal = "수락하면 오늘 낮 동안 결함(균열·저주) 유물 판매가 x{mult}",
            reward = "결함 유물을 작업대에 올려 [즉시 판매]",
            accepted = "오늘 낮 결함품 판매가 x{mult} 적용 중",
        },
        blood_moon = {
            story = "핏빛 달이 뜨는 밤, 암시장은 결계 유지비 장부에 손을 댈 수 있다고 속삭인다. 대가는 미쳐 날뛰는 포탈이다.",
            goal = "수락하면 오늘 밤 몬스터 체력 x{hp} · 속도 x{speed} — 끝까지 버텨 낼 것",
            reward = "다음 결계 유지비 -{discount} G",
            accepted = "오늘 밤 핏빛 달 — 버텨 내면 유지비 -{discount} G",
        },
    },

    adventurers = {
        display = "{epithet} {name}",
        bern = {
            name = "베른", epithet = "강철의",
            lines = {
                "\"{address}, {grade} 등급 {item}이오. 칼밥 먹는 놈이 거짓말은 안 하지.\"",
                "\"전장에서 주워 온 {item}이오. {grade} 등급, 값만 맞춰 주시오.\"",
                "\"{item} 한 자루. 내 눈엔 {grade} 등급이오, {address}.\"",
            },
            caught = {
                forgery = "\"…쳇, 눈썰미 좋군. 그래, 등급은 내가 좀 불렀소. 값은 깎아 주지.\"",
                curse = "\"저주라니… 전장에서 주운 거라 몰랐소. 정직하게 값을 내리겠소.\"",
                crack = "\"금이 가 있었나. 칼밥 먹는 놈이 그걸 못 봤군. 깎아 주시오.\"",
            },
        },
        rina = {
            name = "리나", epithet = "도굴꾼",
            lines = {
                "\"무덤 냄새는 좀 나도 {grade} 등급 {item}이에요, {address}. 닦으면 반짝일걸요?\"",
                "\"쉿, 출처는 묻지 마세요. {item}, {grade} 등급이에요.\"",
                "\"흙 좀 털어 오긴 했는데… {grade} 등급 {item}! 싸게 드릴게요.\"",
            },
            caught = {
                forgery = "\"에, 에이~ 그게 그렇게 보여요? 무덤 먼지 때문에 착각했나 봐요… 헤헤.\"",
                curse = "\"저, 저주요?! 그러니까 밤마다 이상한 소리가 났구나… 싸게 드릴게요!\"",
                crack = "\"어머, 금이요? 파낼 때 삽에 맞았나…? 깎아 드릴게요, 네?\"",
            },
        },
        ellen = {
            name = "엘렌", epithet = "견습 마법사",
            lines = {
                "\"저, 저기… 스승님 창고에서 나온 {item}인데요, {grade} 등급… 맞을 거예요.\"",
                "\"{address}, 이 {item} 마력이 좀 이상해요. {grade} 등급이라고 들었어요.\"",
                "\"값은 잘 몰라서요… {grade} 등급 {item}, 적당히 쳐 주세요.\"",
            },
            caught = {
                forgery = "\"네, 네에?! 스승님이 분명 그 등급이라고… 죄, 죄송해요!\"",
                curse = "\"저주 각인이요…? 어쩐지 손이 계속 저리더라니… 히익.\"",
                crack = "\"금이 갔다고요? 제, 제가 떨어뜨렸나 봐요… 죄송해요!\"",
            },
        },
        thorin = {
            name = "토린", epithet = "드워프 대장장이",
            lines = {
                "\"흥, 내가 직접 담금질한 {item}이다. {grade} 등급, 한 푼도 못 깎아.\"",
                "\"{address}, 드워프 망치질을 의심하나? {grade} 등급 {item}이야.\"",
                "\"불맛을 아는 놈이면 이 {item} 값을 알 텐데. {grade} 등급이다.\"",
            },
            caught = {
                forgery = "\"흥! 드워프의 눈엔 그 등급으로 보였어! …좋아, 이번만 깎아 주지.\"",
                curse = "\"저주 따위 담금질로 날려 버렸을 텐데! …제길, 값은 내리지.\"",
                crack = "\"내 망치질에 금이 갔을 리가… 크흠. 그래, 깎아 주마.\"",
            },
        },
        kain = {
            name = "카인", epithet = "그림자 추적자",
            lines = {
                "\"…{grade} 등급 {item}. 주인은 더 이상 찾으러 오지 않는다.\"",
                "\"{address}. 이 {item}, 밤마다 속삭인다. {grade} 등급이다.\"",
                "\"묻지 마라. {item}, {grade} 등급. 값만 말해.\"",
            },
            caught = {
                forgery = "\"…들켰군. 상관없다. 그 값에 넘기지.\"",
                curse = "\"알고 있었다. 그래서 싸게 넘기는 거다.\"",
                crack = "\"…금쯤은 아무래도 좋다. 값만 맞춰.\"",
            },
        },
        cedric = {
            name = "세드릭", epithet = "몰락한 귀족",
            lines = {
                "\"이건 우리 가문 대대로 내려온 {grade} 등급 {item}일세. 감히 값을 깎을 생각은 말게.\"",
                "\"{address}, 귀족의 물건을 알아보는 눈이 있겠지? {grade} 등급 {item}이네.\"",
                "\"선대 백작께서 아끼던 {item}… 물론 {grade} 등급이고말고.\"",
            },
            caught = {
                forgery = "\"무, 무례하군! 가문의 보물을 감히… 흠흠, 좋소, 조금 양보하리다.\"",
                curse = "\"저주라니, 우리 가문을 모욕하는 건가?! …크흠, 값은 내리겠네.\"",
                crack = "\"그 금은 선대 백작께서 남기신 영광의 흔적이오! …알았네, 깎아 주지.\"",
            },
        },
        tags = {
            melee = "근접 무기 전문",
            honest = "정직한 거래",
            filthy = "오염 심한 도굴품",
            treasure = "황금·성물 선호",
            arcane = "번개·증폭기 취급",
            naive = "시세에 어두움",
            smith = "화염 무기 장인",
            stubborn = "값을 깎지 않음",
            cursed = "저주 유물 다수 소지",
            shady = "수상한 출처",
            forger = "등급 부풀리기 상습",
            pricey = "귀족의 허세 가격",
        },
    },
}

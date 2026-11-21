import Foundation

// =====================================================================
// 화면 언어 (한국어 / English) — 안드로이드 버전의 L 객체와 동일
// =====================================================================

enum L {
    private static let key = "ui_lang"
    private(set) static var isEn: Bool = UserDefaults.standard.string(forKey: key) == "en"

    static func t(_ ko: String, _ en: String) -> String { isEn ? en : ko }

    static func set(english: Bool) {
        isEn = english
        UserDefaults.standard.set(english ? "en" : "ko", forKey: key)
    }
}

// =====================================================================
// 실험 조건
// =====================================================================

enum Technique: String {
    case volumeKey = "VOLUME_KEY"
    case touchDrag = "TOUCH_DRAG"

    var code: String { rawValue }
    var shortLabel: String {
        switch self {
        case .volumeKey: return L.t("볼륨키", "Volume Keys")
        case .touchDrag: return L.t("터치 드래그", "Touch Drag")
        }
    }
}

enum StudyEnvironment: String {
    case stationary = "STATIONARY"
    case walking = "WALKING"

    var code: String { rawValue }
    var shortLabel: String {
        switch self {
        case .stationary: return L.t("착석", "Seated")
        case .walking: return L.t("보행", "Walking")
        }
    }
}

enum TaskLanguage: String { case ko = "KO", en = "EN" }
enum TextLengthType: String { case single = "SINGLE", paragraph = "PARAGRAPH" }

struct ExperimentCondition {
    let id: Int
    let technique: Technique
    let environment: StudyEnvironment
    var shortName: String { "\(environment.shortLabel) × \(technique.shortLabel)" }
}

/// 위치·길이는 모두 UTF-16 단위 (안드로이드 Java String 인덱스와 동일).
struct TaskSentence {
    let id: Int
    let language: TaskLanguage
    let lengthType: TextLengthType
    let text: String
    let typoGuide: String
    let typoWord: String
    let typoChar: String
    let typoCharIndex: Int
    let correctedText: String

    var length: Int { (text as NSString).length }
}

struct TlxItem {
    let key: String
    let title: String
    let question: String
    let lowLabel: String
    let highLabel: String
}

// =====================================================================
// 기록 형식 (CSV 한 줄) — 안드로이드와 같은 컬럼
// =====================================================================

struct TrialRecord {
    let participantId: String
    let group: String
    let conditionOrder: Int
    let conditionId: Int
    let technique: String
    let environment: String
    let isPractice: Bool
    let trialInCondition: Int
    let trialNumber: Int
    let taskId: Int
    let language: String
    let lengthType: String
    let textLength: Int
    let targetIndex: Int
    let initialIndex: Int
    let initialDistance: Int
    let isSuccess: Bool
    let completionTimeMs: Int
    let firstReachTimeMs: Int
    let positioningTimeMs: Int
    let firstEditInZone: Bool
    let overshootCount: Int
    let cursorTravel: Int
    let cursorMoveEvents: Int
    let editCount: Int
    let keyPressCount: Int
    let keyRepeatMoves: Int
    let keyPressKbHidden: Int
    let touchCount: Int
    let offModeInputCount: Int
    let timestamp: String
    let taskText: String
}

struct TlxRecord {
    let participantId: String
    let group: String
    let conditionOrder: Int
    let conditionId: Int
    let technique: String
    let environment: String
    let mental: Int
    let physical: Int
    let temporal: Int
    let performance: Int
    let effort: Int
    let frustration: Int
    let timestamp: String

    var rawTlx: Double { Double(mental + physical + temporal + performance + effort + frustration) / 6.0 }
}

// =====================================================================
// 안드로이드와 똑같은 난수열을 만들기 위한 java.util.Random 구현.
// 같은 피험자 ID면 안드로이드/아이폰 어디서 하든 문장 순서와 시작 위치가 같다.
// =====================================================================

struct JavaRandom {
    private var seed: UInt64
    private static let multiplier: UInt64 = 0x5DEECE66D
    private static let mask: UInt64 = (1 << 48) - 1

    init(seed: Int64) {
        self.seed = (UInt64(bitPattern: seed) ^ JavaRandom.multiplier) & JavaRandom.mask
    }

    private mutating func next(_ bits: Int) -> Int32 {
        seed = (seed &* JavaRandom.multiplier &+ 0xB) & JavaRandom.mask
        return Int32(truncatingIfNeeded: Int64(bitPattern: seed) >> (48 - bits))
    }

    mutating func nextInt(_ bound: Int) -> Int {
        precondition(bound > 0)
        let b = Int32(bound)
        var r = next(31)
        let m = b &- 1
        if (b & m) == 0 {
            return Int((Int64(b) &* Int64(r)) >> 31)
        }
        var u = r
        r = u % b
        while u &- r &+ m < 0 {
            u = next(31)
            r = u % b
        }
        return Int(r)
    }

    /// java.util.Collections.shuffle 과 같은 순서로 섞는다 (Kotlin의 list.shuffled(random)).
    mutating func shuffled<T>(_ list: [T]) -> [T] {
        var a = list
        var i = a.count
        while i > 1 {
            let j = nextInt(i)
            a.swapAt(i - 1, j)
            i -= 1
        }
        return a
    }
}

/// Java String.hashCode() 와 동일
func javaHashCode(_ s: String) -> Int32 {
    var h: Int32 = 0
    for u in s.utf16 { h = h &* 31 &+ Int32(u) }
    return h
}

// =====================================================================
// 실험 데이터셋 — 안드로이드 ExperimentDataset 와 동일한 문장·순서·그룹
// =====================================================================

enum ExperimentDataset {
    // v2.1: 피로도를 줄이기 위해 조건당 연습 1 + 본 시행 5 (이전: 연습 2 + 본 시행 8)
    static let trialsPerCondition = 5
    static let practicePerCondition = 1
    static let startDistanceSingle = 8
    static let startDistanceParagraph = 25

    static var tlxItems: [TlxItem] { L.isEn ? tlxItemsEn : tlxItemsKo }

    private static let tlxItemsKo: [TlxItem] = [
        TlxItem(key: "mental", title: "1. 정신적 요구 (Mental Demand)",
                question: "과업을 수행하는 동안 얼마나 많은 정신적·인지적 노력(생각, 주목, 기억 등)이 필요했습니까?",
                lowLabel: "1: 매우 낮음", highLabel: "10: 매우 높음"),
        TlxItem(key: "physical", title: "2. 신체적 요구 (Physical Demand)",
                question: "과업을 수행하는 동안 얼마나 많은 신체적 활동(손가락 움직임, 파지 유지, 보행 균형 등)이 필요했습니까?",
                lowLabel: "1: 매우 낮음", highLabel: "10: 매우 높음"),
        TlxItem(key: "temporal", title: "3. 시간적 압박 (Temporal Demand)",
                question: "과업의 진행 속도 때문에 얼마나 서두르거나 쫓긴다고 느꼈습니까?",
                lowLabel: "1: 매우 낮음", highLabel: "10: 매우 높음"),
        TlxItem(key: "performance", title: "4. 수행 성과 (Performance)",
                question: "요구된 과업(오타 위치로 커서를 옮겨 고치기)을 얼마나 성공적으로 해냈다고 생각합니까? ⚠ 이 문항만 1이 좋은 쪽입니다 (1 = 완벽하게 성공, 10 = 실패)",
                lowLabel: "1: 완벽하게 성공", highLabel: "10: 실패"),
        TlxItem(key: "effort", title: "5. 노력 (Effort)",
                question: "목표한 수준의 결과를 얻기 위해 (정신적·신체적으로) 얼마나 많은 노력을 들여야 했습니까?",
                lowLabel: "1: 매우 적음", highLabel: "10: 매우 많음"),
        TlxItem(key: "frustration", title: "6. 스트레스·짜증 (Frustration)",
                question: "과업을 수행하는 동안 얼마나 짜증나거나 스트레스를 받았습니까?",
                lowLabel: "1: 매우 낮음", highLabel: "10: 매우 높음"),
    ]

    private static let tlxItemsEn: [TlxItem] = [
        TlxItem(key: "mental", title: "1. Mental Demand",
                question: "How much mental and perceptual activity (thinking, attending, remembering, etc.) was required to perform the task?",
                lowLabel: "1: Very low", highLabel: "10: Very high"),
        TlxItem(key: "physical", title: "2. Physical Demand",
                question: "How much physical activity (finger movement, holding the phone, keeping balance while walking, etc.) was required?",
                lowLabel: "1: Very low", highLabel: "10: Very high"),
        TlxItem(key: "temporal", title: "3. Temporal Demand",
                question: "How hurried or rushed did you feel because of the pace of the task?",
                lowLabel: "1: Very low", highLabel: "10: Very high"),
        TlxItem(key: "performance", title: "4. Performance",
                question: "How successful were you in accomplishing what you were asked to do (moving the cursor to the typo and fixing it)? ⚠ For this item only, 1 is the good end (1 = perfect, 10 = failure)",
                lowLabel: "1: Perfect", highLabel: "10: Failure"),
        TlxItem(key: "effort", title: "5. Effort",
                question: "How hard did you have to work (mentally and physically) to achieve your level of performance?",
                lowLabel: "1: Very little", highLabel: "10: Very much"),
        TlxItem(key: "frustration", title: "6. Frustration",
                question: "How irritated or stressed did you feel while performing the task?",
                lowLabel: "1: Very low", highLabel: "10: Very high"),
    ]

    /// 문장 1개 정의 (안드로이드 v2 의 s() 와 동일).
    /// 오타 위치는 안내 문구 "오타 → 정답"에서 두 단어가 처음으로 달라지는 글자로 자동 계산한다. 위치는 UTF-16 단위.
    private static func s(_ id: Int, _ language: TaskLanguage, _ text: String, _ guide: String) -> TaskSentence {
        let parts = guide.components(separatedBy: " → ")
        precondition(parts.count == 2, "Task \(id): guide must be 'typo → fix'")
        let wrong = parts[0] as NSString
        let right = parts[1] as NSString
        let ns = text as NSString
        let r = ns.range(of: parts[0])
        precondition(r.location != NSNotFound, "Task \(id): '\(parts[0])' not found")
        let rest = NSRange(location: r.location + 1, length: ns.length - r.location - 1)
        precondition(ns.range(of: parts[0], options: [], range: rest).location == NSNotFound,
                     "Task \(id): '\(parts[0])' must appear exactly once")
        let common = min(wrong.length, right.length)
        var offset = common
        for i in 0..<common where wrong.character(at: i) != right.character(at: i) {
            offset = i
            break
        }
        if offset >= wrong.length { offset = wrong.length - 1 }
        let corrected = ns.replacingCharacters(in: r, with: parts[1])
        return TaskSentence(id: id, language: language, lengthType: .single, text: text,
                            typoGuide: guide, typoWord: parts[0],
                            typoChar: wrong.substring(with: NSRange(location: offset, length: 1)),
                            typoCharIndex: r.location + offset, correctedText: corrected)
    }

    /// v2 문장 세트: 참가자는 한 언어만 수행한다 (한국어 세트 또는 영어 세트).
    /// - 모두 한 줄짜리 단문, 길이 통일: 한국어 33~37자, 영어 58~64자
    /// - 오타는 문장 중간(전체 길이의 33~67% 위치)에 1개
    /// - 본 시행 32개 = 4블록 × 8문항, 블록은 제시 순서에 묶인다
    static func blocksFor(_ language: TaskLanguage) -> [[TaskSentence]] {
        language == .en ? enBlocks : koBlocks
    }

    static func practiceFor(_ language: TaskLanguage) -> [TaskSentence] {
        language == .en ? enPractice : koPractice
    }

    private static let koBlocks: [[TaskSentence]] = [
        [
            s(1, .ko, "오늘 오후에는 친구들과 함께 도서관에서 공뿌를 하기로 약속했습니다.", "공뿌를 → 공부를"),
            s(2, .ko, "오늘 점심에 학교 앞 식당에서 먿은 짜장면이 정말 맛있었습니다.", "먿은 → 먹은"),
            s(3, .ko, "주말마다 근처 공원에서 강아지와 산쳑을 즐기며 시간을 보냅니다.", "산쳑을 → 산책을"),
            s(4, .ko, "내일 아침에는 일찍 일어나서 운돔을 하러 공원에 가려고 합니다.", "운돔을 → 운동을"),
            s(5, .ko, "갑자기 내린 소나기 때문에 지하철역 근첲의 편의점으로 피했습니다.", "근첲의 → 근처의"),
            s(6, .ko, "출근 시간이라 버스 안에 사람이 먆아서 학교까지 서서 갔습니다.", "먆아서 → 많아서"),
            s(7, .ko, "다음 주에 제출해야 하는 기말보고서 작션을 미리 준비하고 있습니다.", "작션을 → 작성을"),
            s(8, .ko, "교수님 피드백을 바탕으로 실험 계흭과 설문 문항을 수정했습니다.", "계흭과 → 계획과"),
        ],
        [
            s(9, .ko, "비가 많이 와서 우산을 챙겼는데 버스 졍류장에 두고 내렸습니다.", "졍류장에 → 정류장에"),
            s(10, .ko, "동생 생일을 맞아 작은 케이크와 꽃댜발을 사서 집으로 돌아왔습니다.", "꽃댜발을 → 꽃다발을"),
            s(11, .ko, "시험 기간이라 도서관 열람싨에는 빈 자리가 거의 없었습니다.", "열람싨에는 → 열람실에는"),
            s(12, .ko, "새로 산 운동화가 발에 잘 맞야서 오래 걸어도 편안했습니다.", "맞야서 → 맞아서"),
            s(13, .ko, "점심시간에는 회사 근처 공원을 샨책하며 잠시 휴식을 취했습니다.", "샨책하며 → 산책하며"),
            s(14, .ko, "주말에 대청소를 하면서 오래됀 옷과 책을 정리해서 기부했습니다.", "오래됀 → 오래된"),
            s(15, .ko, "카페에서 친구를 기다리며 따뚯한 라떼를 한 잔 주문했습니다.", "따뚯한 → 따뜻한"),
            s(16, .ko, "지하철 안에서 이어폰을 끼고 좋아하는 노레를 들으며 출근했습니다.", "노레를 → 노래를"),
        ],
        [
            s(17, .ko, "퇴근길에 마트에 들러 저녁 반챤으로 먹을 두부와 계란을 샀습니다.", "반챤으로 → 반찬으로"),
            s(18, .ko, "새해에는 매일 아침 일찍 일어나서 영여 공부를 하기로 결심했습니다.", "영여 → 영어"),
            s(19, .ko, "어제 본 영화는 생각보다 훨신 재미있어서 시간 가는 줄 몰랐습니다.", "훨신 → 훨씬"),
            s(20, .ko, "봄이 되자 학교 앞 길가에 벗꽃이 활짝 피어 무척 아름다웠습니다.", "벗꽃이 → 벚꽃이"),
            s(21, .ko, "회의 시간에 늦지 않으려고 오늘은 평쇼보다 일찍 집을 나섰습니다.", "평쇼보다 → 평소보다"),
            s(22, .ko, "현관 앞에 택배가 도착했다는 문쟈를 받고 서둘러 나가 보았습니다.", "문쟈를 → 문자를"),
            s(23, .ko, "여름 방학 동안 가족들과 제쥬도로 여행을 다녀올 계획을 세웠습니다.", "제쥬도로 → 제주도로"),
            s(24, .ko, "노트북 배터리가 거의 다 떨어저서 충전기를 찾아 연결했습니다.", "떨어저서 → 떨어져서"),
        ],
        [
            s(25, .ko, "친구가 추천해 준 책을 읽어 보니 내옹이 생각보다 어려웠습니다.", "내옹이 → 내용이"),
            s(26, .ko, "운동을 마치고 집에 돌아와 시운한 물로 샤워를 하고 쉬었습니다.", "시운한 → 시원한"),
            s(27, .ko, "도서관에서 빌린 책을 반냡하려고 오늘 학교에 일찍 도착했습니다.", "반냡하려고 → 반납하려고"),
            s(28, .ko, "길 잃은 관광객에게 지하쳘역으로 가는 길을 친절히 알려 주었습니다.", "지하쳘역으로 → 지하철역으로"),
            s(29, .ko, "겨울이 되니 손이 자주 챠가워져서 따뜻한 장갑을 새로 샀습니다.", "챠가워져서 → 차가워져서"),
            s(30, .ko, "발표 자료를 만드느라 어젯밤 늗게까지 컴퓨터 앞에 앉아 있었습니다.", "늗게까지 → 늦게까지"),
            s(31, .ko, "엘리베이터가 고장 나서 계댠으로 오 층까지 걸어서 올라갔습니다.", "계댠으로 → 계단으로"),
            s(32, .ko, "오랜만에 고향 친구들을 만나서 즐겨운 저녁 식사를 함께했습니다.", "즐겨운 → 즐거운"),
        ],
    ]

    private static let koPractice: [TaskSentence] = [
        s(101, .ko, "어제 저녁에는 가족들과 함께 맛잇는 불고기를 먹으러 갔습니다.", "맛잇는 → 맛있는"),
        s(102, .ko, "이번 주말에는 영화관에서 친구와 함꼐 새로 나온 영화를 봅니다.", "함꼐 → 함께"),
        s(103, .ko, "아침마다 따뜻한 물 한 쟌을 마시면 몸이 한결 가벼워집니다.", "쟌을 → 잔을"),
        s(104, .ko, "날씨가 좋아서 창문을 활짝 열고 짐 안을 모두 환기시켰습니다.", "짐 안을 → 집 안을"),
    ]

    private static let enBlocks: [[TaskSentence]] = [
        [
            s(201, .en, "The quick brown fox jumps over the lasy dog near the river.", "lasy → lazy"),
            s(202, .en, "Please remember to submit your final asignments before Friday.", "asignments → assignments"),
            s(203, .en, "She decided to bring a warm cup of cofee to the morning meeting.", "cofee → coffee"),
            s(204, .en, "They wanted to visit the famous musium before the rain started.", "musium → museum"),
            s(205, .en, "He forgot to check the weather forcast before leaving his house.", "forcast → forecast"),
            s(206, .en, "The train arrived at the staton ten minutes ahead of schedule.", "staton → station"),
            s(207, .en, "We usually eat breakfast togehter before going to work each day.", "togehter → together"),
            s(208, .en, "Every weekday morning, the new libary on campus opens at nine.", "libary → library"),
        ],
        [
            s(209, .en, "I left my phone on the kitchen tabel before heading out today.", "tabel → table"),
            s(210, .en, "Our professor asked us to raed the next chapter before class.", "raed → read"),
            s(211, .en, "It started raining, so we wiated inside the cafe for an hour.", "wiated → waited"),
            s(212, .en, "My roommate cooked a delicous pasta dinner for everyone tonight.", "delicous → delicious"),
            s(213, .en, "The bus this morning was so crwoded that we stood by the door.", "crwoded → crowded"),
            s(214, .en, "She bought fresh flowres for her mom at the market on Sunday.", "flowres → flowers"),
            s(215, .en, "We should leave early because the trafic is usually heavy here.", "trafic → traffic"),
            s(216, .en, "According to the news, tomorow will be sunny and warm all day.", "tomorow → tomorrow"),
        ],
        [
            s(217, .en, "Please turn off the ligths when you leave the meeting room.", "ligths → lights"),
            s(218, .en, "The new phone has a much larger scren and a better camera too.", "scren → screen"),
            s(219, .en, "He practices the piano for an huor every evening after dinner.", "huor → hour"),
            s(220, .en, "The hotel room was clean, qiuet, and had a lovely ocean view.", "qiuet → quiet"),
            s(221, .en, "Our team finished the porject two days before the deadline.", "porject → project"),
            s(222, .en, "The doctor told him to drink more watre and get enough sleep.", "watre → water"),
            s(223, .en, "My grandmother bakes cookeis for the whole family every winter.", "cookeis → cookies"),
            s(224, .en, "Remember to bring your pasport when you travel abroad soon.", "pasport → passport"),
        ],
        [
            s(225, .en, "The students listened carefuly while the teacher explained it.", "carefuly → carefully"),
            s(226, .en, "I usually take a short walk in the prak after finishing lunch.", "prak → park"),
            s(227, .en, "She always keeps a small notbook in her bag to write ideas.", "notbook → notebook"),
            s(228, .en, "The new coffee shop downstiars serves really good sandwiches.", "downstiars → downstairs"),
            s(229, .en, "Please send me the upadted file before the meeting starts.", "upadted → updated"),
            s(230, .en, "My little brother leanred how to ride a bicycle this summer.", "leanred → learned"),
            s(231, .en, "The store was closed, so we had to coem back the next morning.", "coem → come"),
            s(232, .en, "Our neighbor kindly helped us cary the heavy boxes upstairs.", "cary → carry"),
        ],
    ]

    private static let enPractice: [TaskSentence] = [
        s(301, .en, "My sister bought a new umbrela at the store near our home.", "umbrela → umbrella"),
        s(302, .en, "The children played soccor in the park after school ended.", "soccor → soccer"),
        s(303, .en, "The quiet music in the backgorund helped me focus on studying.", "backgorund → background"),
        s(304, .en, "Last night we watched a very fnuny movie with our classmates.", "fnuny → funny"),
    ]

    static let C1 = ExperimentCondition(id: 1, technique: .touchDrag, environment: .stationary)
    static let C2 = ExperimentCondition(id: 2, technique: .volumeKey, environment: .stationary)
    static let C3 = ExperimentCondition(id: 3, technique: .touchDrag, environment: .walking)
    static let C4 = ExperimentCondition(id: 4, technique: .volumeKey, environment: .walking)

    static let groupKeys = ["A", "B", "C", "D"]
    static let groups: [String: [ExperimentCondition]] = [
        "A": [C1, C2, C3, C4], // 착석(터치→볼륨) → 보행(터치→볼륨)
        "B": [C2, C1, C4, C3], // 착석(볼륨→터치) → 보행(볼륨→터치)
        "C": [C3, C4, C1, C2], // 보행(터치→볼륨) → 착석(터치→볼륨)
        "D": [C4, C3, C2, C1], // 보행(볼륨→터치) → 착석(볼륨→터치)
    ]

    static func conditionSequence(_ group: String) -> [ExperimentCondition] {
        groups[group.uppercased()] ?? groups["A"]!
    }

    /// P01→A, P02→B, P03→C, P04→D, P05→A ...
    static func suggestedGroup(for participantId: String) -> String {
        let n = Int(participantId.filter { $0.isASCII && $0.isNumber }) ?? 1
        let idx = ((n - 1) % groupKeys.count + groupKeys.count) % groupKeys.count
        return groupKeys[idx]
    }
}

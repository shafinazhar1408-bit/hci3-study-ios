import UIKit

/// 안드로이드 MainActivity 를 그대로 옮긴 실험 화면.
///
/// 과업: 오타가 있는 문장이 가상 키보드와 함께 제시된다. 참가자는 지정된 기법(볼륨키 / 터치 드래그)으로
/// 커서를 오타 위치로 옮긴 뒤 키보드로 직접 고친다. 입력창 내용이 정답 문장과 같아지면 시행이 자동으로 끝난다.
/// 볼륨키는 '가상 키보드가 열려 있는 동안에만' 커서 이동으로 동작하고, 키보드가 닫혀 있으면 원래 음량 조절로 동작한다.
final class ExperimentViewController: UIViewController, UITextViewDelegate {

    private enum Screen { case setup, intro, task, tlx, summary }
    private var screen: Screen = .setup

    // ---------- 볼륨키 설정 (아이폰 파일럿에서 조정 필요) ----------
    /// 이 간격보다 짧게 이벤트가 이어지면 '같은 버튼을 계속 누르고 있는 중'으로 본다
    private let holdGap: CFTimeInterval = 0.30
    /// 길게 누른 지 이 시간이 지나면 빠른 연속 이동
    private let longPressThreshold: CFTimeInterval = 0.5
    /// 빠른 연속 이동 중, iOS 자동 반복 이벤트 1번당 움직일 글자 수
    private let repeatStep = 2
    private let imeWaitTimeout: TimeInterval = 1.5

    // ---------- 화면 ----------
    private var setupPage: UIScrollView!
    private var introPage: UIScrollView!
    private var tlxPage: UIScrollView!
    private var summaryPage: UIScrollView!
    private let taskPage = UIView()

    // 설정
    private let langControl = UISegmentedControl(items: ["한국어", "English"])
    private let appTitle = UILabel()
    private let appSubtitle = UILabel()
    private let pidLabel = UILabel()
    private let pidField = UITextField()
    private let groupLabel = UILabel()
    private let groupControl = UISegmentedControl(items: ExperimentDataset.groupKeys)
    private let groupPreview = PaddedLabel()
    // v2: 참가자가 수행할 과업 문장 언어 (한 언어만)
    private let taskLangLabel = UILabel()
    private let taskLangControl = UISegmentedControl(items: ["한국어 문장", "English sentences"])
    private let debugSwitch = UISwitch()
    private let debugSwitchLabel = UILabel()
    private let setupInfo = UILabel()
    private let startButton = UIButton(type: .system)
    private let shareLastButton = UIButton(type: .system)

    // 조건 안내
    private let introStep = UILabel()
    private let introTitle = UILabel()
    private let restTimerLabel = PaddedLabel()
    private let introBody = UILabel()
    private let introNext = UIButton(type: .system)
    private let abortButton = UIButton(type: .system)

    // 과업
    private let badge = PaddedLabel()
    private let progressLabel = UILabel()
    private let practiceBanner = PaddedLabel()
    private let targetGuide = UILabel()
    private let techGuide = UILabel()
    private let textContainer = UIView()
    private let textView = StudyTextView()
    private let touchBlocker = UIView()
    private let startTrialButton = UIButton(type: .system)
    private let debugText = UILabel()
    private let skipLabel = UILabel()
    private let taskAbortLabel = UILabel()

    // NASA-TLX
    private let tlxTitle = UILabel()
    private let tlxSubtitle = UILabel()
    private let tlxStack = UIStackView()
    private let tlxSubmit = UIButton(type: .system)
    private var tlxAnswers = [Int](repeating: 0, count: 6)
    private var tlxButtons: [[UIButton]] = []

    // 완료
    private let summaryTitle = UILabel()
    private let summarySubtitle = UILabel()
    private let summaryStats = UILabel()
    private let exportButton = UIButton(type: .system)
    private let nextParticipantButton = UIButton(type: .system)

    // ---------- 세션 상태 ----------
    private var participantId = "P01"
    private var group = "A"
    private var showDebug = false
    private var taskLanguage: TaskLanguage = L.isEn ? .en : .ko
    private var conditionSequence: [ExperimentCondition] = []
    private var mainTasksPerCondition: [[TaskSentence]] = []
    private var conditionIdx = 0
    private var isPracticePhase = true
    private var trialInPhase = 0
    private var lastTlxSubmitTime: CFTimeInterval = 0
    private var random = JavaRandom(seed: 0)
    private var currentTask: TaskSentence?

    private var currentCondition: ExperimentCondition { conditionSequence[conditionIdx] }

    // ---------- 현재 시행 상태 ----------
    private var pendingStart = false
    private var trialActive = false
    private var inEdit = false
    private var volumeMoving = false
    private var imeVisible = false
    private var lastKeyInfo = "-"

    // ---------- 현재 시행 측정값 ----------
    private var taskStartTime: CFTimeInterval = 0
    private var initialIndex = 0
    private var initialDistance = 0
    private var previousCursorPos = 0
    private var lastSide = 0
    private var overshootCount = 0
    private var cursorTravel = 0
    private var cursorMoveEvents = 0
    private var firstReachTimeMs = -1
    private var positioningTimeMs = -1
    private var firstEditInZone = false
    private var editCount = 0
    private var keyPressCount = 0
    private var keyRepeatMoves = 0
    private var keyPressKbHidden = 0
    private var touchCount = 0
    private var offModeInputCount = 0

    // 볼륨 버튼
    private let volume = VolumeButtonObserver()
    private var holdDir = 0
    private var holdStart: CFTimeInterval = 0
    private var lastVolumeEvent: CFTimeInterval = 0
    private var lastVolumeIntervalMs = 0
    private var lastPassThroughEvent: CFTimeInterval = 0

    private var restTimer: Timer?
    private var imeFallback: DispatchWorkItem?
    private var nextTrialWork: DispatchWorkItem?

    private let normalFont = UIFont.systemFont(ofSize: 17)
    private var normalAttributes: [NSAttributedString.Key: Any] {
        let p = NSMutableParagraphStyle()
        p.lineSpacing = 5
        return [.font: normalFont, .foregroundColor: UIColor.appText, .paragraphStyle: p]
    }

    // =====================================================================
    // 초기화
    // =====================================================================

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .appBg
        UIApplication.shared.isIdleTimerDisabled = true // 실험 중 화면 꺼짐 방지

        buildSetupPage()
        buildIntroPage()
        buildTaskPage()
        buildTlxPage()
        buildSummaryPage()
        buildAbortButton()

        volume.onPress = { [weak self] up in self?.handleVolumePress(up: up) }
        volume.onPassThrough = { [weak self] in self?.handleVolumePassThrough() }
        volume.attach(to: view)

        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(keyboardDidShow), name: UIResponder.keyboardDidShowNotification, object: nil)
        nc.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)

        group = ExperimentDataset.suggestedGroup(for: pidField.text ?? "")
        applyLanguage()
        showScreen(.setup)
    }

    // =====================================================================
    // 화면 구성 도우미
    // =====================================================================

    private func style(_ l: UILabel, _ size: CGFloat, _ weight: UIFont.Weight = .regular, _ color: UIColor = .appText) {
        l.font = .systemFont(ofSize: size, weight: weight)
        l.textColor = color
        l.numberOfLines = 0
    }

    private func styleButton(_ b: UIButton, filled: Bool = true, color: UIColor = .appPurple, height: CGFloat = 54) {
        var c: UIButton.Configuration = filled ? .filled() : .plain()
        c.baseBackgroundColor = color
        c.baseForegroundColor = filled ? .white : color
        c.cornerStyle = .large
        b.configuration = c
        if !filled {
            b.layer.borderWidth = 1
            b.layer.borderColor = color.cgColor
            b.layer.cornerRadius = 12
        }
        b.heightAnchor.constraint(equalToConstant: height).isActive = true
    }

    private func setTitle(_ b: UIButton, _ title: String) {
        var c = b.configuration ?? .filled()
        var t = AttributedString(title)
        t.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        c.attributedTitle = t
        b.configuration = c
    }

    private func card(_ views: [UIView], spacing: CGFloat = 8) -> UIView {
        let c = UIView()
        c.backgroundColor = .white
        c.layer.cornerRadius = 12
        c.layer.borderWidth = 1
        c.layer.borderColor = UIColor.appBorder.cgColor
        let s = UIStackView(arrangedSubviews: views)
        s.axis = .vertical
        s.spacing = spacing
        s.translatesAutoresizingMaskIntoConstraints = false
        c.addSubview(s)
        NSLayoutConstraint.activate([
            s.topAnchor.constraint(equalTo: c.topAnchor, constant: 14),
            s.bottomAnchor.constraint(equalTo: c.bottomAnchor, constant: -14),
            s.leadingAnchor.constraint(equalTo: c.leadingAnchor, constant: 14),
            s.trailingAnchor.constraint(equalTo: c.trailingAnchor, constant: -14),
        ])
        return c
    }

    /// 화면 하나 = 세로 스크롤 + 세로 스택. 키보드가 올라오면 키보드 위까지만 차지한다.
    private func makePage() -> (UIScrollView, UIStackView) {
        let sv = UIScrollView()
        sv.alwaysBounceVertical = true
        sv.keyboardDismissMode = .interactive
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        sv.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: sv.contentLayoutGuide.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: sv.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: sv.frameLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: sv.frameLayoutGuide.trailingAnchor, constant: -20),
        ])
        pinToSafeArea(sv)
        return (sv, stack)
    }

    private func pinToSafeArea(_ v: UIView) {
        v.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(v)
        NSLayoutConstraint.activate([
            v.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            v.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            v.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            v.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
        ])
    }

    // ---------- 1. 설정 화면 ----------

    private func buildSetupPage() {
        let (sv, stack) = makePage()
        setupPage = sv

        langControl.selectedSegmentIndex = L.isEn ? 1 : 0
        langControl.addTarget(self, action: #selector(languageChanged), for: .valueChanged)
        langControl.setContentHuggingPriority(.required, for: .horizontal)
        let langRow = UIStackView(arrangedSubviews: [UIView(), langControl])
        stack.addArrangedSubview(langRow)

        style(appTitle, 24, .bold, .appPurpleDark)
        style(appSubtitle, 14, .regular, .appText2)
        stack.addArrangedSubview(appTitle)
        stack.addArrangedSubview(appSubtitle)

        style(pidLabel, 14, .bold)
        pidField.text = "P01"
        pidField.borderStyle = .roundedRect
        pidField.autocapitalizationType = .allCharacters
        pidField.autocorrectionType = .no
        pidField.returnKeyType = .done
        pidField.heightAnchor.constraint(equalToConstant: 44).isActive = true
        pidField.addTarget(self, action: #selector(pidChanged), for: .editingChanged)
        pidField.addTarget(self, action: #selector(dismissKeyboardAction), for: .editingDidEndOnExit)

        style(groupLabel, 14, .bold)
        groupControl.addTarget(self, action: #selector(groupChanged), for: .valueChanged)
        style(groupPreview, 12, .regular, .appText2)
        groupPreview.backgroundColor = UIColor(hex: 0xF1F5F9)
        groupPreview.insets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)

        style(debugSwitchLabel, 12, .regular, .appText2)
        let debugRow = UIStackView(arrangedSubviews: [debugSwitch, debugSwitchLabel])
        debugRow.spacing = 8
        debugRow.alignment = .center

        style(taskLangLabel, 14, .bold)
        taskLangControl.selectedSegmentIndex = taskLanguage == .en ? 1 : 0
        taskLangControl.addTarget(self, action: #selector(taskLanguageChanged), for: .valueChanged)

        stack.addArrangedSubview(card([pidLabel, pidField, groupLabel, groupControl, groupPreview,
                                       taskLangLabel, taskLangControl, debugRow], spacing: 10))

        style(setupInfo, 13, .regular, .appText2)
        stack.addArrangedSubview(card([setupInfo]))

        styleButton(startButton)
        startButton.addTarget(self, action: #selector(startExperiment), for: .touchUpInside)
        styleButton(shareLastButton, filled: false)
        shareLastButton.addTarget(self, action: #selector(shareCsv), for: .touchUpInside)
        stack.setCustomSpacing(24, after: stack.arrangedSubviews.last!)
        stack.addArrangedSubview(startButton)
        stack.addArrangedSubview(shareLastButton)
    }

    // ---------- 2. 조건 안내 ----------

    private func buildIntroPage() {
        let (sv, stack) = makePage()
        introPage = sv
        style(introStep, 14, .bold, .appText2)
        style(introTitle, 26, .bold, .appPurpleDark)
        style(restTimerLabel, 14, .bold, UIColor(hex: 0x92400E))
        restTimerLabel.backgroundColor = UIColor(hex: 0xFEF3C7)
        restTimerLabel.insets = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        style(introBody, 15)
        styleButton(introNext)
        introNext.addTarget(self, action: #selector(startPractice), for: .touchUpInside)

        stack.addArrangedSubview(introStep)
        stack.addArrangedSubview(introTitle)
        stack.addArrangedSubview(restTimerLabel)
        stack.addArrangedSubview(card([introBody]))
        stack.setCustomSpacing(24, after: stack.arrangedSubviews.last!)
        stack.addArrangedSubview(introNext)
    }

    // ---------- 3. 과업 ----------

    private func buildTaskPage() {
        pinToSafeArea(taskPage)

        style(badge, 12, .bold, .white)
        badge.backgroundColor = .appPurple
        badge.layer.cornerRadius = 12
        badge.clipsToBounds = true
        badge.insets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        badge.numberOfLines = 1
        style(progressLabel, 14, .bold)
        progressLabel.numberOfLines = 1
        progressLabel.textAlignment = .right
        badge.setContentHuggingPriority(.required, for: .horizontal)
        progressLabel.setContentHuggingPriority(.required, for: .horizontal)
        let topRow = UIStackView(arrangedSubviews: [badge, UIView(), progressLabel])
        topRow.alignment = .center

        style(practiceBanner, 13, .bold, UIColor(hex: 0x1E40AF))
        practiceBanner.backgroundColor = UIColor(hex: 0xDBEAFE)
        practiceBanner.textAlignment = .center
        practiceBanner.insets = UIEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)

        style(targetGuide, 15, .bold, .appRed)
        style(techGuide, 12, .regular, .appText2)
        let guideCard = card([targetGuide, techGuide], spacing: 4)

        // 입력창 + (볼륨 조건용) 터치 차단막 + 시작 버튼
        textView.font = normalFont
        textView.backgroundColor = .white
        textView.layer.cornerRadius = 12
        textView.layer.borderWidth = 1
        textView.layer.borderColor = UIColor.appBorder.cgColor
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 8)
        textView.autocorrectionType = .no
        textView.spellCheckingType = .no
        textView.autocapitalizationType = .none
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        textView.smartInsertDeleteType = .no
        if #available(iOS 17.0, *) { textView.inlinePredictionType = .no }
        textView.tintColor = .appPurple
        textView.delegate = self
        textView.isHidden = true

        touchBlocker.backgroundColor = .clear

        styleButton(startTrialButton, color: .appGreen, height: 96)
        startTrialButton.addTarget(self, action: #selector(beginTrial), for: .touchUpInside)

        for v in [textView, touchBlocker, startTrialButton] as [UIView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            textContainer.addSubview(v)
        }
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: textContainer.topAnchor),
            textView.bottomAnchor.constraint(equalTo: textContainer.bottomAnchor),
            textView.leadingAnchor.constraint(equalTo: textContainer.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: textContainer.trailingAnchor),
            touchBlocker.topAnchor.constraint(equalTo: textContainer.topAnchor),
            touchBlocker.bottomAnchor.constraint(equalTo: textContainer.bottomAnchor),
            touchBlocker.leadingAnchor.constraint(equalTo: textContainer.leadingAnchor),
            touchBlocker.trailingAnchor.constraint(equalTo: textContainer.trailingAnchor),
            startTrialButton.topAnchor.constraint(equalTo: textContainer.topAnchor),
            startTrialButton.leadingAnchor.constraint(equalTo: textContainer.leadingAnchor),
            startTrialButton.trailingAnchor.constraint(equalTo: textContainer.trailingAnchor),
        ])
        textContainer.setContentHuggingPriority(.defaultLow, for: .vertical)
        textContainer.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        // 문장 영역 터치 횟수 세기 (다른 동작은 방해하지 않음)
        let counter = TouchDownCounter(target: nil, action: nil)
        counter.onTouchDown = { [weak self] in self?.onTextAreaTouched() }
        textContainer.addGestureRecognizer(counter)

        // 아래 줄: 디버그 / 중단 / 건너뛰기
        style(debugText, 11, .regular, .appText2)
        style(taskAbortLabel, 11, .regular, .appBorder)
        style(skipLabel, 11, .regular, .appBorder)
        taskAbortLabel.numberOfLines = 1
        skipLabel.numberOfLines = 1
        for l in [taskAbortLabel, skipLabel] {
            l.isUserInteractionEnabled = true
            l.setContentHuggingPriority(.required, for: .horizontal)
            l.setContentCompressionResistancePriority(.required, for: .horizontal)
        }
        let skipPress = UILongPressGestureRecognizer(target: self, action: #selector(skipLongPressed(_:)))
        skipLabel.addGestureRecognizer(skipPress)
        let abortPress = UILongPressGestureRecognizer(target: self, action: #selector(abortLongPressed(_:)))
        taskAbortLabel.addGestureRecognizer(abortPress)
        let bottomRow = UIStackView(arrangedSubviews: [debugText, taskAbortLabel, skipLabel])
        bottomRow.spacing = 10
        bottomRow.alignment = .center

        let stack = UIStackView(arrangedSubviews: [topRow, practiceBanner, guideCard, textContainer, bottomRow])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        taskPage.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: taskPage.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: taskPage.bottomAnchor, constant: -6),
            stack.leadingAnchor.constraint(equalTo: taskPage.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: taskPage.trailingAnchor, constant: -16),
        ])
    }

    // ---------- 4. NASA-TLX ----------

    private func buildTlxPage() {
        let (sv, stack) = makePage()
        tlxPage = sv
        style(tlxTitle, 20, .bold)
        style(tlxSubtitle, 13, .regular, .appText2)
        tlxStack.axis = .vertical
        tlxStack.spacing = 10
        styleButton(tlxSubmit)
        tlxSubmit.addTarget(self, action: #selector(submitTlx), for: .touchUpInside)
        stack.addArrangedSubview(tlxTitle)
        stack.addArrangedSubview(tlxSubtitle)
        stack.addArrangedSubview(tlxStack)
        stack.addArrangedSubview(tlxSubmit)
    }

    private func buildTlxForm() {
        tlxStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        tlxButtons.removeAll()
        for (itemIdx, item) in ExperimentDataset.tlxItems.enumerated() {
            let title = UILabel(); style(title, 15, .bold); title.text = item.title
            let q = UILabel(); style(q, 13, .regular, .appText2); q.text = item.question

            let row = UIStackView()
            row.distribution = .fillEqually
            row.spacing = 4
            var buttons: [UIButton] = []
            for value in 1...10 {
                let b = UIButton(type: .custom)
                b.setTitle("\(value)", for: .normal)
                b.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
                b.layer.cornerRadius = 8
                b.layer.borderWidth = 1
                b.heightAnchor.constraint(equalToConstant: 42).isActive = true
                b.tag = itemIdx * 100 + value
                b.addTarget(self, action: #selector(tlxTapped(_:)), for: .touchUpInside)
                paintChip(b, selected: false)
                row.addArrangedSubview(b)
                buttons.append(b)
            }
            tlxButtons.append(buttons)

            let low = UILabel(); style(low, 11, .regular, .appTeal); low.text = item.lowLabel
            let high = UILabel(); style(high, 11, .regular, .appTeal); high.text = item.highLabel
            high.textAlignment = .right
            let labels = UIStackView(arrangedSubviews: [low, high])
            labels.distribution = .fillEqually

            tlxStack.addArrangedSubview(card([title, q, row, labels], spacing: 6))
        }
        tlxAnswers = [Int](repeating: 0, count: tlxButtons.count)
        tlxSubmit.isEnabled = false
    }

    private func paintChip(_ b: UIButton, selected: Bool) {
        b.backgroundColor = selected ? .appPurple : .white
        b.setTitleColor(selected ? .white : .appText, for: .normal)
        b.layer.borderColor = (selected ? UIColor.appPurple : UIColor.appBorder).cgColor
    }

    // ---------- 5. 완료 ----------

    private func buildSummaryPage() {
        let (sv, stack) = makePage()
        summaryPage = sv
        style(summaryTitle, 22, .bold)
        summaryTitle.textAlignment = .center
        style(summarySubtitle, 14, .regular, .appText2)
        summarySubtitle.textAlignment = .center
        style(summaryStats, 13)
        styleButton(exportButton, color: .appGreen)
        exportButton.addTarget(self, action: #selector(shareCsv), for: .touchUpInside)
        styleButton(nextParticipantButton, filled: false)
        nextParticipantButton.addTarget(self, action: #selector(resetToSetup), for: .touchUpInside)
        stack.addArrangedSubview(summaryTitle)
        stack.addArrangedSubview(summarySubtitle)
        stack.addArrangedSubview(card([summaryStats]))
        stack.setCustomSpacing(24, after: stack.arrangedSubviews.last!)
        stack.addArrangedSubview(exportButton)
        stack.addArrangedSubview(nextParticipantButton)
    }

    /// 안내/TLX 화면 오른쪽 위 '중단' 버튼 (안드로이드의 뒤로 가기 대신)
    private func buildAbortButton() {
        var c = UIButton.Configuration.plain()
        c.baseForegroundColor = .appText2
        abortButton.configuration = c
        abortButton.translatesAutoresizingMaskIntoConstraints = false
        abortButton.addTarget(self, action: #selector(confirmAbort), for: .touchUpInside)
        view.addSubview(abortButton)
        NSLayoutConstraint.activate([
            abortButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
            abortButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -8),
        ])
    }

    // =====================================================================
    // 화면 언어
    // =====================================================================

    @objc private func languageChanged() {
        L.set(english: langControl.selectedSegmentIndex == 1)
        // 기본값: 화면 언어를 바꾸면 과업 문장 언어도 같이 맞춘다 (이후 따로 바꿀 수 있음)
        taskLanguage = L.isEn ? .en : .ko
        taskLangControl.selectedSegmentIndex = L.isEn ? 1 : 0
        applyLanguage()
    }

    @objc private func taskLanguageChanged() {
        taskLanguage = taskLangControl.selectedSegmentIndex == 1 ? .en : .ko
        updateSetupInfo()
    }

    private func applyLanguage() {
        appTitle.text = L.t("HCI 볼륨키 커서 연구 v2 (iOS)", "HCI Volume-Key Cursor Study v2 (iOS)")
        taskLangLabel.text = L.t("과업 문장 언어 (참가자가 편한 언어 1개)", "Task sentence language (one language per participant)")
        appSubtitle.text = L.t("2×2 반복측정 실험 · 실험자 설정 화면", "2×2 within-subjects study · Experimenter setup")
        pidLabel.text = L.t("피험자 ID", "Participant ID")
        pidField.placeholder = L.t("예: P01, P02...", "e.g. P01, P02...")
        groupLabel.text = L.t("카운터밸런싱 그룹 (ID에 따라 자동 추천)", "Counterbalancing group (suggested from ID)")
        debugSwitchLabel.text = L.t("실험자 디버그 정보 표시 (파일럿용, 본 실험에서는 끄기)", "Show debug info (pilot only, turn off for the real study)")
        setTitle(startButton, L.t("실험 시작", "Start Experiment"))
        setTitle(shareLastButton, L.t("직전 세션 CSV 공유", "Share Last Session CSV"))
        practiceBanner.text = L.t("연습 시행 (기록은 분석에서 제외됩니다)", "Practice trial (not included in analysis)")
        skipLabel.text = L.t("실험자: 길게 눌러 건너뛰기", "Experimenter: hold to skip")
        taskAbortLabel.text = L.t("길게 눌러 중단", "Hold to stop")
        tlxTitle.text = L.t("NASA-TLX 작업 부하 평가", "NASA-TLX Workload Rating")
        setTitle(tlxSubmit, L.t("응답 제출", "Submit"))
        summaryTitle.text = L.t("실험이 모두 완료되었습니다", "The experiment is complete")
        setTitle(exportButton, L.t("CSV 내보내기 / 공유", "Export / Share CSV"))
        setTitle(nextParticipantButton, L.t("다음 피험자 시작", "Next Participant"))
        setTitle(abortButton, L.t("중단", "Stop"))

        groupControl.selectedSegmentIndex = ExperimentDataset.groupKeys.firstIndex(of: group) ?? 0
        updateGroupPreview()
        updateSetupInfo()
        buildTlxForm()
    }

    private func updateSetupInfo() {
        let p = ExperimentDataset.practicePerCondition
        let n = ExperimentDataset.trialsPerCondition
        setupInfo.text = L.isEn ? """
            Procedure (repeated for 4 conditions)
            ① Condition intro → ② \(p) practice → ③ \(n) main trials → ④ NASA-TLX → Rest

            • Task: move the cursor to the typo and fix it with the keyboard; the next trial starts automatically
            • \(n * 4) main trials in total, all in the selected language (\(taskLanguage == .en ? "English" : "Korean"))
            • All sentences are one line of similar length (Korean 33–37 / English 58–64 characters), typo in the middle
            • Volume buttons move the cursor only while the keyboard is open
            • Seated/Walking are blocked, so the environment changes only once
            • Every trial and questionnaire is saved to CSV immediately
              Location: Files app > On My iPhone > HciCursorStudy > HCI_Study
            • Run the pre/post questionnaires (interview) separately in Google Forms
            • Condition IDs: C1 Seated×Touch, C2 Seated×Volume, C3 Walking×Touch, C4 Walking×Volume
            • To stop: tap "Stop" (top right) or hold "Hold to stop" on the task screen
            """ : """
            진행 순서 (조건 4개 반복)
            ① 조건 안내 → ② 연습 \(p)문항 → ③ 본 시행 \(n)문항 → ④ NASA-TLX → 휴식

            • 과업: 오타 위치로 커서를 옮겨 키보드로 고치면 자동으로 다음 문항
            • 본 시행 총 \(n * 4)문항, 모두 선택한 언어(\(taskLanguage == .en ? "영어" : "한국어")) 문장
            • 모든 문장은 길이가 비슷한 한 줄 단문 (한국어 33~37자 / 영어 58~64자), 오타는 문장 중간
            • 볼륨 버튼은 키보드가 열려 있을 때만 커서 이동으로 동작
            • 착석/보행은 블록으로 묶어 환경 전환은 1번만 합니다.
            • 매 시행·설문이 끝날 때마다 CSV에 바로 저장됩니다.
              저장 위치: 파일 앱 > 나의 iPhone > HciCursorStudy > HCI_Study
            • 사전·사후 설문(인터뷰)은 Google Forms로 따로 진행하세요.
            • 조건 ID: C1 착석×터치, C2 착석×볼륨, C3 보행×터치, C4 보행×볼륨
            • 중단: 오른쪽 위 [중단] 또는 과업 화면의 '길게 눌러 중단'
            """
    }

    // =====================================================================
    // 화면 전환
    // =====================================================================

    private func showScreen(_ s: Screen) {
        screen = s
        setupPage.isHidden = s != .setup
        introPage.isHidden = s != .intro
        taskPage.isHidden = s != .task
        tlxPage.isHidden = s != .tlx
        summaryPage.isHidden = s != .summary
        abortButton.isHidden = !(s == .intro || s == .tlx)
        view.bringSubviewToFront(abortButton)

        restTimer?.invalidate()
        restTimer = nil
        if s == .intro {
            restTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.updateRestTimer() }
        }
        if s != .task { hideKeyboard() }
        if s == .setup { shareLastButton.isHidden = CsvLogger.filesForShare().isEmpty }
        updateVolumeIntercept()
    }

    // =====================================================================
    // 1. 설정
    // =====================================================================

    @objc private func pidChanged() {
        group = ExperimentDataset.suggestedGroup(for: pidField.text ?? "")
        groupControl.selectedSegmentIndex = ExperimentDataset.groupKeys.firstIndex(of: group) ?? 0
        updateGroupPreview()
    }

    @objc private func groupChanged() {
        group = ExperimentDataset.groupKeys[groupControl.selectedSegmentIndex]
        updateGroupPreview()
    }

    @objc private func dismissKeyboardAction() { hideKeyboard() }

    private func updateGroupPreview() {
        let seq = ExperimentDataset.conditionSequence(group)
        groupPreview.text = seq.enumerated().map { "\($0.offset + 1). C\($0.element.id)  \($0.element.shortName)" }
            .joined(separator: "\n")
    }

    @objc private func startExperiment() {
        // 파일 이름에 쓰이므로 영문/숫자/-/_ 만 남긴다
        let cleaned = (pidField.text ?? "").trimmingCharacters(in: .whitespaces).uppercased()
            .filter { ($0.isASCII && ($0.isLetter || $0.isNumber)) || $0 == "-" || $0 == "_" }
        participantId = cleaned.isEmpty ? "P01" : cleaned
        showDebug = debugSwitch.isOn
        conditionSequence = ExperimentDataset.conditionSequence(group)

        // 안드로이드와 같은 난수 → 같은 ID면 같은 문장 순서·시작 위치
        random = JavaRandom(seed: Int64(javaHashCode(participantId)))
        var shuffled: [[TaskSentence]] = []
        // 각 블록(8문장)의 앞 5문장을 고정으로 사용 → 모든 참가자가 같은 문장 20개를 수행 (순서만 섞음)
        for block in ExperimentDataset.blocksFor(taskLanguage) {
            shuffled.append(random.shuffled(Array(block.prefix(ExperimentDataset.trialsPerCondition))))
        }
        mainTasksPerCondition = shuffled

        CsvLogger.startSession(participantId: participantId, group: group, taskLanguage: taskLanguage.rawValue)
        conditionIdx = 0
        lastTlxSubmitTime = 0
        showConditionIntro()
    }

    // =====================================================================
    // 2. 조건 안내 / 휴식
    // =====================================================================

    private func showConditionIntro() {
        let c = currentCondition
        let p = ExperimentDataset.practicePerCondition
        introStep.text = L.t("조건", "Condition") + " \(conditionIdx + 1) / \(conditionSequence.count)   (C\(c.id))"
        introTitle.text = c.shortName

        let envText: String
        switch c.environment {
        case .stationary:
            envText = L.t("🪑 의자에 앉아서 진행합니다. 팔꿈치를 책상에 대고 편한 자세로 휴대폰을 잡으세요.",
                          "🪑 Sit on a chair. Rest your elbow on the desk and hold the phone comfortably.")
        case .walking:
            envText = L.t("🚶 안전한 평지 통로를 평소 속도로 걸으면서 진행합니다. 실험자가 옆에서 함께 걷습니다. 멈추지 말고 계속 걸어 주세요.",
                          "🚶 Walk at your normal pace along a safe, flat hallway. The experimenter will walk beside you. Please keep walking without stopping.")
        }
        let techText: String
        switch c.technique {
        case .volumeKey:
            techText = L.t(
                "🔊 볼륨 버튼으로 커서를 움직입니다. (키보드가 열려 있을 때만 동작)\n" +
                "  • 볼륨 ▲(위): 앞으로(왼쪽) 1글자\n" +
                "  • 볼륨 ▼(아래): 뒤로(오른쪽) 1글자\n" +
                "  • 길게 누르고 있으면 연속으로 빠르게 이동\n" +
                "  • 이 조건에서는 문장을 터치해서 커서를 옮길 수 없습니다.",
                "🔊 Move the cursor with the volume buttons (works only while the keyboard is open).\n" +
                "  • Volume ▲ (up): 1 character backward (left)\n" +
                "  • Volume ▼ (down): 1 character forward (right)\n" +
                "  • Hold the button to move quickly and continuously\n" +
                "  • In this condition you cannot move the cursor by touching the text.")
        case .touchDrag:
            techText = L.t(
                "👆 화면 터치로 커서를 움직입니다.\n" +
                "  • 문장을 터치하면 그 위치에 커서가 놓입니다.\n" +
                "  • 커서를 길게 누른 채 드래그하면 세밀하게 옮길 수 있습니다.\n" +
                "  • 이 조건에서는 볼륨 버튼이 동작하지 않습니다.",
                "👆 Move the cursor by touching the screen.\n" +
                "  • Tap the text to place the cursor there.\n" +
                "  • Press and drag the cursor to fine-tune its position.\n" +
                "  • The volume buttons do not work in this condition.")
        }
        introBody.text = "\(envText)\n\n\(techText)\n\n" + L.t(
            "✋ 휴대폰은 반드시 한 손으로만 잡고, 같은 손으로만 조작하세요. 다른 손은 사용하지 않습니다.\n\n" +
            "🎯 과업: 빨간색으로 표시된 오타로 커서를 옮긴 뒤, 키보드로 지우고 다시 입력해 위에 안내된 정답처럼 고치세요. " +
            "올바르게 고쳐지면 자동으로 다음 문항으로 넘어갑니다. 최대한 빠르고 정확하게 해 주세요.\n\n" +
            "⚠ 스페이스바를 길게 눌러 커서 옮기기 등 키보드 자체의 커서 이동 기능은 사용하지 마세요.\n\n" +
            "[시작] 버튼을 누르면 문장과 키보드가 나타나고 시간 측정이 시작됩니다. 먼저 연습 \(p)문항을 진행합니다.",
            "✋ Hold the phone with one hand only and operate it with the same hand. Do not use your other hand.\n\n" +
            "🎯 Task: move the cursor to the typo shown in red, then delete and retype it with the keyboard so it matches the correction shown above. " +
            "Once it is correct, the next trial starts automatically. Please be as fast and accurate as possible.\n\n" +
            "⚠ Do not use the keyboard's own cursor features (e.g. press-and-hold the spacebar).\n\n" +
            "Pressing [Start] shows the sentence and the keyboard and starts the timer. You will first do \(p) practice \(p == 1 ? "trial" : "trials").")

        setTitle(introNext, L.t("연습 시작 (\(p)문항)", "Start Practice (\(p) \(p == 1 ? "trial" : "trials"))"))
        showScreen(.intro)
        updateRestTimer()
    }

    private func updateRestTimer() {
        guard conditionIdx > 0, lastTlxSubmitTime > 0 else {
            restTimerLabel.isHidden = true
            return
        }
        let prev = conditionSequence[conditionIdx - 1]
        let envChanged = prev.environment != currentCondition.environment
        let elapsed = Int(CACurrentMediaTime() - lastTlxSubmitTime)
        let guide = envChanged ? L.t("환경 전환: 장소 이동 후 3~5분 휴식 권장", "Environment change: move, then rest 3–5 min")
                               : L.t("1~2분 휴식 권장", "Rest 1–2 min recommended")
        restTimerLabel.isHidden = false
        restTimerLabel.text = String(format: L.t("⏱ 휴식 경과 %02d:%02d  ·  ", "⏱ Rest %02d:%02d  ·  "), elapsed / 60, elapsed % 60) + guide
    }

    @objc private func startPractice() {
        isPracticePhase = true
        trialInPhase = 0
        showScreen(.task)
        loadTrial()
    }

    // =====================================================================
    // 3. 과업
    // =====================================================================

    private func currentPhaseTasks() -> [TaskSentence] {
        if isPracticePhase {
            let p = ExperimentDataset.practiceFor(taskLanguage)
            let n = ExperimentDataset.practicePerCondition
            // 조건마다 다른 연습 문장 (연습 4개 = 조건 4개 × 1문장)
            let offset = conditionIdx * n
            return (0..<n).map { p[(offset + $0) % p.count] }
        }
        return mainTasksPerCondition[conditionIdx]
    }

    private func loadTrial() {
        trialActive = false
        pendingStart = false
        imeFallback?.cancel()
        hideKeyboard()

        let tasks = currentPhaseTasks()
        let task = tasks[trialInPhase]
        currentTask = task
        let c = currentCondition

        badge.text = "C\(c.id)  \(c.shortName)"
        progressLabel.text = isPracticePhase
            ? L.t("연습", "Practice") + " \(trialInPhase + 1)/\(tasks.count)"
            : "\(trialInPhase + 1)/\(tasks.count)  (" + L.t("조건", "Condition") + " \(conditionIdx + 1)/\(conditionSequence.count))"
        practiceBanner.isHidden = !isPracticePhase
        targetGuide.text = L.t("고칠 오타: ", "Fix: ") + task.typoGuide
        switch c.technique {
        case .volumeKey:
            techGuide.text = L.t("✋ 한 손 · 볼륨 ▲ 앞(왼쪽) / ▼ 뒤(오른쪽) · 길게 누르면 연속 이동 → 키보드로 수정",
                                 "✋ One hand · Volume ▲ left / ▼ right · hold to move continuously → fix with keyboard")
        case .touchDrag:
            techGuide.text = L.t("✋ 한 손 · 문장 터치 후 커서 드래그 → 키보드로 수정",
                                 "✋ One hand · tap the text, drag the cursor → fix with keyboard")
        }

        // 문장 + 오타 글자 강조
        let len = task.length
        let t = task.typoCharIndex
        let attr = NSMutableAttributedString(string: task.text, attributes: normalAttributes)
        attr.addAttributes([
            .foregroundColor: UIColor.appRed,
            .backgroundColor: UIColor(hex: 0xFEE2E2),
            .font: UIFont.systemFont(ofSize: 17, weight: .bold),
            .underlineStyle: NSUnderlineStyle.single.rawValue,
        ], range: NSRange(location: t, length: min(1, len - t)))
        textView.attributedText = attr
        textView.typingAttributes = normalAttributes
        textView.backgroundColor = .white

        // 시작 커서: 목표 구간(오타 글자 앞~뒤)에서 고정 거리만큼 떨어진 위치, 왼쪽/오른쪽은 무작위
        let dist = task.lengthType == .paragraph ? ExperimentDataset.startDistanceParagraph : ExperimentDataset.startDistanceSingle
        let candidates = [t - dist, t + 1 + dist].filter { $0 >= 0 && $0 <= len }
        if !candidates.isEmpty {
            initialIndex = candidates[random.nextInt(candidates.count)]
        } else {
            initialIndex = t >= len - (t + 1) ? 0 : len
        }
        initialDistance = distanceToTarget(initialIndex)

        textView.isHidden = true
        touchBlocker.isHidden = false
        startTrialButton.isHidden = false
        setTitle(startTrialButton, c.environment == .walking
                 ? L.t("걷기 시작한 뒤 눌러서 시작", "Start walking, then tap to begin")
                 : L.t("준비되면 눌러서 시작", "Tap to begin when ready"))
        debugText.isHidden = !showDebug
        debugText.text = ""
        updateVolumeIntercept()
    }

    /// [시작] 버튼: 문장을 보여주고 키보드를 연다. 측정은 키보드가 실제로 열린 뒤 시작한다.
    @objc private func beginTrial() {
        guard !trialActive, !pendingStart, screen == .task else { return }
        overshootCount = 0
        cursorTravel = 0
        cursorMoveEvents = 0
        firstReachTimeMs = -1
        positioningTimeMs = -1
        firstEditInZone = false
        editCount = 0
        keyPressCount = 0
        keyRepeatMoves = 0
        keyPressKbHidden = 0
        touchCount = 0
        offModeInputCount = 0
        holdDir = 0

        startTrialButton.isHidden = true
        textView.isHidden = false
        pendingStart = true
        showKeyboard()
        textView.selectedRange = NSRange(location: initialIndex, length: 0)

        let work = DispatchWorkItem { [weak self] in
            guard let self = self, self.pendingStart else { return }
            self.startMeasuring() // 키보드 감지가 안 되는 경우 대비
        }
        imeFallback = work
        DispatchQueue.main.asyncAfter(deadline: .now() + imeWaitTimeout, execute: work)
        if imeVisible { startMeasuring() }
    }

    private func startMeasuring() {
        guard pendingStart, let _ = currentTask else { return }
        pendingStart = false
        imeFallback?.cancel()
        if textView.selectedRange.location != initialIndex || textView.selectedRange.length != 0 {
            textView.selectedRange = NSRange(location: initialIndex, length: 0)
        }
        previousCursorPos = initialIndex
        lastSide = sideOf(initialIndex)
        taskStartTime = CACurrentMediaTime()
        trialActive = true
        // 볼륨 조건에서는 문장 터치로 커서를 옮길 수 없도록 차단막을 유지
        touchBlocker.isHidden = currentCondition.technique == .touchDrag
        updateVolumeIntercept()
        updateDebug()
    }

    private func elapsedMs() -> Int { Int(((CACurrentMediaTime() - taskStartTime) * 1000).rounded()) }

    // ---------- 키보드 감지 ----------

    @objc private func keyboardDidShow() { setImeVisible(true) }
    @objc private func keyboardWillHide() { setImeVisible(false) }

    private func setImeVisible(_ visible: Bool) {
        guard visible != imeVisible else { return }
        imeVisible = visible
        if visible && pendingStart && screen == .task { startMeasuring() }
        updateVolumeIntercept()
        if trialActive { updateDebug() }
    }

    private func showKeyboard() {
        textView.becomeFirstResponder()
    }

    private func hideKeyboard() {
        view.endEditing(true)
    }

    // ---------- 위치 계산 ----------

    /// -1 = 목표 왼쪽, 0 = 목표 구간(오타 글자 바로 앞/뒤), +1 = 오른쪽
    private func sideOf(_ pos: Int) -> Int {
        guard let t = currentTask?.typoCharIndex else { return 0 }
        if pos < t { return -1 }
        if pos > t + 1 { return 1 }
        return 0
    }

    private func distanceToTarget(_ pos: Int) -> Int {
        guard let t = currentTask?.typoCharIndex else { return 0 }
        if pos < t { return t - pos }
        if pos > t + 1 { return pos - (t + 1) }
        return 0
    }

    private func onCursorMoved(_ pos: Int) {
        guard trialActive, !inEdit, pos != previousCursorPos else { return }
        cursorMoveEvents += 1
        cursorTravel += abs(pos - previousCursorPos)

        // 볼륨 조건에서 볼륨 버튼이 아닌 방법(스페이스바 트랙패드 등)으로 커서가 움직인 경우
        if currentCondition.technique == .volumeKey && !volumeMoving { offModeInputCount += 1 }

        // 첫 편집 전(커서 위치 잡기 단계)에만 오버슈트·도달 시간을 계산
        if positioningTimeMs < 0 {
            let side = sideOf(pos)
            if side != 0 {
                if side != lastSide { overshootCount += 1 }
                lastSide = side
            } else if firstReachTimeMs < 0 {
                firstReachTimeMs = elapsedMs()
            }
        }
        previousCursorPos = pos
        updateDebug()
    }

    private func onTextAreaTouched() {
        guard trialActive, screen == .task else { return }
        touchCount += 1
        if currentCondition.technique == .volumeKey {
            // 볼륨 조건: 터치로 커서를 옮길 수 없다. 키보드가 닫혀 있으면 키보드만 다시 연다.
            if imeVisible { offModeInputCount += 1 } else { showKeyboard() }
        }
        updateDebug()
    }

    private func updateDebug() {
        guard showDebug, let task = currentTask else { return }
        debugText.text = "[DEBUG] cursor \(textView.selectedRange.location) · target \(task.typoCharIndex)~\(task.typoCharIndex + 1) · " +
            "OS \(overshootCount) · travel \(cursorTravel) · edits \(editCount) · keys \(keyPressCount)(kbHidden \(keyPressKbHidden)) · " +
            "rep \(keyRepeatMoves) · touch \(touchCount) · offMode \(offModeInputCount) · IME \(imeVisible ? "open" : "closed") · " +
            "lastKey \(lastKeyInfo) · gap \(lastVolumeIntervalMs)ms"
    }

    // ---------- UITextViewDelegate ----------

    func textView(_ tv: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        guard trialActive else { return false }
        inEdit = true
        editCount += 1
        if positioningTimeMs < 0 {
            positioningTimeMs = elapsedMs()
            firstEditInZone = sideOf(tv.selectedRange.location) == 0
        }
        // textViewDidChange 가 오지 않는 경우에도 inEdit 이 남지 않도록
        DispatchQueue.main.async { [weak self] in self?.inEdit = false }
        return true
    }

    func textViewDidChange(_ tv: UITextView) {
        inEdit = false
        guard trialActive, let task = currentTask else { return }
        if positioningTimeMs < 0 {
            // (한글 조합 등으로 shouldChangeTextIn 이 불리지 않은 경우의 보완)
            editCount += 1
            positioningTimeMs = elapsedMs()
            firstEditInZone = sideOf(previousCursorPos) == 0
        }
        previousCursorPos = tv.selectedRange.location // 입력으로 밀린 커서 위치는 이동으로 치지 않음
        updateDebug()
        if tv.text == task.correctedText { onCorrected() }
    }

    func textViewDidChangeSelection(_ tv: UITextView) {
        let r = tv.selectedRange
        if tv.markedTextRange == nil {
            tv.typingAttributes = normalAttributes // 빨간 오타 서식이 새 입력에 묻어나지 않도록
            if r.length > 0 && trialActive && !inEdit {
                // 더블탭 등으로 범위가 선택되면 커서 1개로 되돌린다
                DispatchQueue.main.async {
                    if tv.selectedRange.length > 0 {
                        tv.selectedRange = NSRange(location: tv.selectedRange.location, length: 0)
                    }
                }
            }
        }
        onCursorMoved(r.location)
    }

    // ---------- 볼륨 버튼 ----------

    /// 버튼을 가로챌지(커서 이동/무시) 원래 음량 조절로 둘지 결정
    private func updateVolumeIntercept() {
        let intercept: Bool
        if screen != .task {
            intercept = false
        } else if !trialActive {
            intercept = true                    // 시행 사이: 음량이 바뀌지 않도록 무시
        } else if currentCondition.technique == .touchDrag {
            intercept = true                    // 터치 조건: 차단 (조건 외 입력으로 기록)
        } else {
            intercept = imeVisible              // 볼륨 조건: 키보드가 열려 있을 때만 커서 이동
        }
        volume.interceptEnabled = intercept
    }

    @discardableResult
    private func moveCursorBy(_ delta: Int) -> Bool {
        let cur = textView.selectedRange.location
        let len = (textView.text as NSString).length
        let next = min(max(cur + delta, 0), len)
        guard next != cur else { return false }
        volumeMoving = true
        textView.selectedRange = NSRange(location: next, length: 0)
        onCursorMoved(next) // 델리게이트 호출 여부와 관계없이 기록 (중복은 자동으로 걸러짐)
        volumeMoving = false
        textView.scrollRangeToVisible(textView.selectedRange)
        return true
    }

    private func handleVolumePress(up: Bool) {
        guard screen == .task else { return }
        let keyName = up ? "▲" : "▼"
        // 위(▲) = 앞으로(문장 앞쪽, 왼쪽), 아래(▼) = 뒤로(문장 뒤쪽, 오른쪽)
        let dir = up ? -1 : 1
        let now = CACurrentMediaTime()
        let gap = now - lastVolumeEvent
        lastVolumeIntervalMs = Int(gap * 1000)
        let isNewPress = gap > holdGap || dir != holdDir
        lastVolumeEvent = now
        if isNewPress { holdDir = dir; holdStart = now }

        guard trialActive else {
            lastKeyInfo = "\(keyName) ignored(not measuring)"
            updateDebug()
            return
        }

        if currentCondition.technique == .touchDrag {
            if isNewPress { offModeInputCount += 1 }
            lastKeyInfo = "\(keyName) blocked(touch cond.)"
            updateDebug()
            return
        }

        guard imeVisible else { return } // (가로채기는 키보드가 열려 있을 때만 켜지지만 한 번 더 확인)

        if isNewPress {
            keyPressCount += 1
            moveCursorBy(dir)
            lastKeyInfo = "\(keyName) move"
        } else if now - holdStart >= longPressThreshold {
            // 길게 누르는 중 → 빠른 연속 이동
            for _ in 0..<repeatStep { if moveCursorBy(dir) { keyRepeatMoves += 1 } }
            lastKeyInfo = "\(keyName) fast"
        } else {
            // 길게 누르기 초반의 자동 반복 → 1글자씩
            if moveCursorBy(dir) { keyRepeatMoves += 1 }
            lastKeyInfo = "\(keyName) repeat"
        }
        updateDebug()
    }

    /// 볼륨 조건에서 키보드가 닫혀 있을 때 버튼을 누름 → 원래 음량 조절로 동작
    private func handleVolumePassThrough() {
        guard screen == .task, trialActive, currentCondition.technique == .volumeKey, !imeVisible else { return }
        let now = CACurrentMediaTime()
        if now - lastPassThroughEvent > holdGap { keyPressKbHidden += 1 }
        lastPassThroughEvent = now
        lastKeyInfo = "volume(IME closed)"
        updateDebug()
    }

    // ---------- 시행 종료 ----------

    private func onCorrected() {
        guard trialActive else { return }
        finishTrial(success: true, completionTime: elapsedMs())
    }

    @objc private func skipLongPressed(_ g: UILongPressGestureRecognizer) {
        guard g.state == .began, screen == .task, trialActive || pendingStart else { return }
        let completion = trialActive ? elapsedMs() : 0
        pendingStart = false
        trialActive = true // finishTrial 공통 처리를 위해
        finishTrial(success: false, completionTime: completion)
    }

    @objc private func abortLongPressed(_ g: UILongPressGestureRecognizer) {
        if g.state == .began { confirmAbort() }
    }

    private func finishTrial(success: Bool, completionTime: Int) {
        guard let task = currentTask else { return }
        trialActive = false
        imeFallback?.cancel()
        let c = currentCondition

        CsvLogger.addTrial(TrialRecord(
            participantId: participantId,
            group: group,
            conditionOrder: conditionIdx + 1,
            conditionId: c.id,
            technique: c.technique.code,
            environment: c.environment.code,
            isPractice: isPracticePhase,
            trialInCondition: trialInPhase + 1,
            trialNumber: isPracticePhase ? 0 : conditionIdx * ExperimentDataset.trialsPerCondition + trialInPhase + 1,
            taskId: task.id,
            language: task.language.rawValue,
            lengthType: task.lengthType.rawValue,
            textLength: task.length,
            targetIndex: task.typoCharIndex,
            initialIndex: initialIndex,
            initialDistance: initialDistance,
            isSuccess: success,
            completionTimeMs: completionTime,
            firstReachTimeMs: firstReachTimeMs,
            positioningTimeMs: positioningTimeMs,
            firstEditInZone: firstEditInZone,
            overshootCount: overshootCount,
            cursorTravel: cursorTravel,
            cursorMoveEvents: cursorMoveEvents,
            editCount: editCount,
            keyPressCount: keyPressCount,
            keyRepeatMoves: keyRepeatMoves,
            keyPressKbHidden: keyPressKbHidden,
            touchCount: touchCount,
            offModeInputCount: offModeInputCount,
            timestamp: nowString(),
            taskText: task.text
        ))

        if success { textView.backgroundColor = UIColor(hex: 0xD1FAE5) } // 정답이면 잠깐 초록색
        hideKeyboard()
        updateVolumeIntercept()
        nextTrialWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.goToNextTrial() }
        nextTrialWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + (success ? 0.6 : 0), execute: work)
    }

    private func goToNextTrial() {
        guard screen == .task else { return }
        trialInPhase += 1
        if trialInPhase < currentPhaseTasks().count {
            loadTrial()
            return
        }
        if isPracticePhase {
            let n = ExperimentDataset.trialsPerCondition
            let alert = UIAlertController(
                title: L.t("연습 완료", "Practice Complete"),
                message: L.t("이제 본 시행 \(n)문항을 시작합니다.\n조작 방법은 연습과 같습니다.",
                             "Now starting the \(n) main trials.\nThe controls are the same as in practice."),
                preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: L.t("본 시행 시작", "Start Main Trials"), style: .default) { [weak self] _ in
                guard let self = self else { return }
                self.isPracticePhase = false
                self.trialInPhase = 0
                self.loadTrial()
            })
            present(alert, animated: true)
        } else {
            showTlx()
        }
    }

    // =====================================================================
    // 4. NASA-TLX
    // =====================================================================

    @objc private func tlxTapped(_ b: UIButton) {
        let itemIdx = b.tag / 100
        let value = b.tag % 100
        guard itemIdx < tlxAnswers.count else { return }
        tlxAnswers[itemIdx] = value
        for (i, chip) in tlxButtons[itemIdx].enumerated() { paintChip(chip, selected: i + 1 == value) }
        tlxSubmit.isEnabled = tlxAnswers.allSatisfy { $0 > 0 }
    }

    private func showTlx() {
        tlxAnswers = [Int](repeating: 0, count: tlxButtons.count)
        tlxButtons.forEach { $0.forEach { paintChip($0, selected: false) } }
        tlxSubmit.isEnabled = false
        let cond = "C\(currentCondition.id) \(currentCondition.shortName)"
        tlxSubtitle.text = L.t(
            "방금 수행한 조건 [\(cond)]에 대해 느낀 부하를 1~10점으로 평가해 주세요. (앉아서 응답해도 됩니다)",
            "Rate the workload you felt in the condition you just finished [\(cond)] from 1 to 10. (You may sit down to answer.)")
        showScreen(.tlx)
        tlxPage.setContentOffset(.zero, animated: false)
    }

    @objc private func submitTlx() {
        // 빠르게 두 번 누르면 같은 응답이 두 번 저장되는 문제 방지
        guard screen == .tlx, tlxAnswers.count == 6, tlxAnswers.allSatisfy({ $0 > 0 }) else { return }
        tlxSubmit.isEnabled = false
        let c = currentCondition
        CsvLogger.addTlx(TlxRecord(
            participantId: participantId, group: group,
            conditionOrder: conditionIdx + 1, conditionId: c.id,
            technique: c.technique.code, environment: c.environment.code,
            mental: tlxAnswers[0], physical: tlxAnswers[1], temporal: tlxAnswers[2],
            performance: tlxAnswers[3], effort: tlxAnswers[4], frustration: tlxAnswers[5],
            timestamp: nowString()))
        lastTlxSubmitTime = CACurrentMediaTime()

        conditionIdx += 1
        if conditionIdx < conditionSequence.count {
            showConditionIntro()
        } else {
            showSummary()
        }
    }

    // =====================================================================
    // 5. 완료
    // =====================================================================

    private func showSummary() {
        showScreen(.summary)
        let trials = CsvLogger.trials.filter { !$0.isPractice }
        let tlx = CsvLogger.tlx
        summarySubtitle.text = L.t(
            "피험자 \(participantId) (그룹 \(group) · \(taskLanguage == .en ? "영어" : "한국어") 문장)\n본 시행 \(trials.count)문항 · NASA-TLX \(tlx.count)회 기록됨\n이제 사후 인터뷰(Google Forms)를 진행하세요.",
            "Participant \(participantId) (Group \(group) · \(taskLanguage == .en ? "English" : "Korean") sentences)\n\(trials.count) main trials · \(tlx.count) NASA-TLX recorded\nNow proceed to the post-study interview (Google Forms).")

        var s = L.t("조건별 요약 (본 시행만, 실험자 확인용)\n\n", "Summary by condition (main trials only, for the experimenter)\n\n")
        for c in ExperimentDataset.groups["A"]! { // C1~C4 순서
            let r = trials.filter { $0.conditionId == c.id }
            if r.isEmpty { continue }
            let ok = r.filter { $0.isSuccess }
            let avgTime = ok.isEmpty ? 0 : Double(ok.map { $0.completionTimeMs }.reduce(0, +)) / Double(ok.count) / 1000
            let pos = ok.filter { $0.positioningTimeMs >= 0 }
            let avgPos = pos.isEmpty ? 0 : Double(pos.map { $0.positioningTimeMs }.reduce(0, +)) / Double(pos.count) / 1000
            let inZone = Double(r.filter { $0.firstEditInZone }.count) * 100 / Double(r.count)
            let avgOs = Double(r.map { $0.overshootCount }.reduce(0, +)) / Double(r.count)
            s += "C\(c.id) \(c.shortName)\n"
            s += String(format: L.t(
                "  성공 %d/%d · 수정 완료 %.2f s · 위치 잡기 %.2f s\n  첫 편집 위치 정확 %.0f%% · 오버슈트 %.2f회",
                "  Success %d/%d · Completion %.2f s · Positioning %.2f s\n  First edit in zone %.0f%% · Overshoot %.2f"),
                ok.count, r.count, avgTime, avgPos, inZone, avgOs)
            if let raw = tlx.first(where: { $0.conditionId == c.id })?.rawTlx {
                s += String(format: " · Raw TLX %.1f", raw)
            }
            s += "\n\n"
        }
        s += L.t("저장된 파일:\n", "Saved files:\n")
        CsvLogger.currentFiles().forEach { s += "  \($0.lastPathComponent)\n" }
        s += L.t("\n위치: 파일 앱 > 나의 iPhone > HciCursorStudy > HCI_Study",
                 "\nLocation: Files app > On My iPhone > HciCursorStudy > HCI_Study")
        summaryStats.text = s
    }

    // =====================================================================
    // 공통
    // =====================================================================

    @objc private func shareCsv() {
        let files = CsvLogger.filesForShare()
        guard !files.isEmpty else { return }
        let vc = UIActivityViewController(activityItems: files, applicationActivities: nil)
        vc.popoverPresentationController?.sourceView = view
        vc.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        present(vc, animated: true)
    }

    @objc private func confirmAbort() {
        guard screen != .setup && screen != .summary else { return }
        let openedAt = CACurrentMediaTime()
        let alert = UIAlertController(
            title: L.t("실험 중단", "Stop Experiment"),
            message: L.t("실험을 중단하고 설정 화면으로 돌아갈까요?\n지금까지 완료한 시행과 설문은 이미 CSV에 저장되어 있습니다.",
                         "Stop the experiment and return to the setup screen?\nAll completed trials and questionnaires are already saved to CSV."),
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L.t("계속 진행", "Continue"), style: .cancel) { [weak self] _ in
            // 중단 확인창이 떠 있던 시간은 수행 시간에서 제외
            guard let self = self else { return }
            if self.trialActive { self.taskStartTime += CACurrentMediaTime() - openedAt }
        })
        alert.addAction(UIAlertAction(title: L.t("중단", "Stop"), style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            self.trialActive = false
            self.pendingStart = false
            self.imeFallback?.cancel()
            self.nextTrialWork?.cancel()
            self.showScreen(.setup)
        })
        present(alert, animated: true)
    }

    @objc private func resetToSetup() {
        let num = Int(participantId.filter { $0.isASCII && $0.isNumber }) ?? 0
        pidField.text = String(format: "P%02d", num + 1)
        pidChanged() // 그룹도 자동 추천
        showScreen(.setup)
    }

    private func nowString() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f.string(from: Date())
    }
}

/// 안쪽 여백이 있는 라벨 (배지, 안내 띠 등)
final class PaddedLabel: UILabel {
    var insets = UIEdgeInsets.zero

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override func textRect(forBounds bounds: CGRect, limitedToNumberOfLines n: Int) -> CGRect {
        let r = super.textRect(forBounds: bounds.inset(by: insets), limitedToNumberOfLines: n)
        return r.inset(by: UIEdgeInsets(top: -insets.top, left: -insets.left, bottom: -insets.bottom, right: -insets.right))
    }
}

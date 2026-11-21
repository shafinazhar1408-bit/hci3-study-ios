import AVFoundation
import MediaPlayer
import UIKit

/// iOS 볼륨 버튼 감지.
///
/// iOS는 앱이 볼륨 버튼을 직접 가로채는 공개 API를 제공하지 않는다. 그래서
///  1) 시스템 음량(outputVolume)이 바뀌는 것을 감시해서 어느 버튼이 눌렸는지 알아내고,
///  2) 곧바로 음량을 중간값(0.5)으로 되돌린다 (음량이 0이나 최대에 닿으면 더 이상 변화가 안 생기므로).
/// 화면 밖에 숨긴 MPVolumeView 를 두면 시스템 음량 표시(HUD)가 대부분 뜨지 않는다.
///
/// 버튼을 계속 누르고 있으면 iOS가 음량을 반복해서 바꾸므로 이벤트가 연속으로 들어온다(자동 반복).
final class VolumeButtonObserver: NSObject {

    /// 가로채기 모드에서 버튼이 눌릴 때마다 호출 (up = true 이면 ▲)
    var onPress: ((_ up: Bool) -> Void)?
    /// 가로채지 않는 모드에서 음량이 실제로 바뀌었을 때 호출 (원래 음량 조절로 동작)
    var onPassThrough: (() -> Void)?

    /// true: 버튼을 커서 이동 등에 사용(음량은 0.5로 유지) / false: 원래 음량 조절
    var interceptEnabled = false {
        didSet {
            if interceptEnabled && !oldValue { resetToNeutral() }
        }
    }

    private let volumeView = MPVolumeView(frame: CGRect(x: -3000, y: -3000, width: 10, height: 10))
    private var observation: NSKeyValueObservation?
    private var lastVolume: Float = 0.5
    private var resettingUntil: CFTimeInterval = 0
    private let neutral: Float = 0.5

    func attach(to view: UIView) {
        volumeView.alpha = 0.01
        volumeView.isUserInteractionEnabled = false
        view.addSubview(volumeView)
        activateSession()

        let session = AVAudioSession.sharedInstance()
        lastVolume = session.outputVolume
        observation = session.observe(\.outputVolume, options: [.new]) { [weak self] _, change in
            guard let v = change.newValue else { return }
            DispatchQueue.main.async { self?.handle(volume: v) }
        }
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive),
                                               name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    /// 오디오 세션이 활성 상태여야 outputVolume 변화가 전달된다. (다른 앱 음악은 끊지 않음)
    func activateSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    @objc private func appDidBecomeActive() {
        activateSession()
        lastVolume = AVAudioSession.sharedInstance().outputVolume
        if interceptEnabled { resetToNeutral() }
    }

    private var slider: UISlider? {
        volumeView.subviews.compactMap { $0 as? UISlider }.first
    }

    private func resetToNeutral() {
        guard abs(lastVolume - neutral) > 0.001 else { return }
        resettingUntil = CACurrentMediaTime() + 0.3
        // MPVolumeView 슬라이더 값을 바꾸면 시스템 음량이 바뀐다 (약간 지연시켜야 안정적으로 적용됨)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [weak self] in
            guard let self = self else { return }
            self.slider?.setValue(self.neutral, animated: false)
            self.slider?.sendActions(for: .valueChanged)
        }
    }

    private func handle(volume v: Float) {
        let delta = v - lastVolume
        lastVolume = v

        // 우리가 0.5로 되돌린 변화는 무시
        if abs(v - neutral) < 0.001 && CACurrentMediaTime() < resettingUntil {
            return
        }
        guard abs(delta) > 0.0001 else { return }

        if interceptEnabled {
            onPress?(delta > 0)
            resetToNeutral()
        } else {
            onPassThrough?()
        }
    }
}

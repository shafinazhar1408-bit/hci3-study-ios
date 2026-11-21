import UIKit
import UIKit.UIGestureRecognizerSubclass

/// 과업 문장 입력창.
/// - 복사/붙여넣기/선택 메뉴를 띄우지 않는다 (커서 1개만 사용)
/// - 커서를 굵게 그린다 (안드로이드 cursor_thick 과 동일한 목적)
final class StudyTextView: UITextView {
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool { false }

    override func caretRect(for position: UITextPosition) -> CGRect {
        var r = super.caretRect(for: position)
        r.size.width = 3
        return r
    }
}

/// 손가락이 화면에 닿는 순간을 세기만 하고 다른 제스처는 방해하지 않는 인식기.
final class TouchDownCounter: UIGestureRecognizer {
    var onTouchDown: (() -> Void)?

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        onTouchDown?()
        state = .failed
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
    static let appPurple = UIColor(hex: 0x4F46E5)
    static let appPurpleDark = UIColor(hex: 0x4338CA)
    static let appTeal = UIColor(hex: 0x0E7490)
    static let appBg = UIColor(hex: 0xF8FAFC)
    static let appText = UIColor(hex: 0x0F172A)
    static let appText2 = UIColor(hex: 0x475569)
    static let appRed = UIColor(hex: 0xEF4444)
    static let appGreen = UIColor(hex: 0x10B981)
    static let appBorder = UIColor(hex: 0xCBD5E1)
}

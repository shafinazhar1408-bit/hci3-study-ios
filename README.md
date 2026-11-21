# HCI Volume-Key Cursor Study — iOS version v2 (experimental)

> 한국어 설명은 아래에 있습니다.

## v2 changes (same as Android v2)

- **One task language per participant:** choose "한국어 문장" or "English sentences" on the setup screen.
  Only sentences in that language appear (32 main + 4 practice per language, all different).
- **v2.1 — fewer trials:** per condition **1 practice + 5 main** sentences (24 per participant, was 2 + 8 = 40).
  The first 5 sentences of each 8-sentence block are used, so every participant does the same 20 main sentences
  (only the order is shuffled by participant ID, identical to Android v2.1). Each condition gets a different practice sentence.
  Change `trialsPerCondition` / `practicePerCondition` in `Model.swift` to adjust (main max 8).
- **Uniform length:** every sentence is a single line — Korean 33–37 / English 58–64 characters,
  typo in the middle (33–67 % of the length). Paragraphs removed; start distance is always 8.
- **NASA-TLX wording:** item 3 (pace of the task), item 4 (how *successful*, 1 = perfect, 10 = failure —
  do **not** reverse-code), item 6 (how irritated or stressed).
- CSV file name includes the language, e.g. `P01_GA_KO_20261116_101500_trials.csv`. Columns are unchanged.
- Bundle ID `com.example.hcicursorstudy.ios.v2`, so it can be installed next to the v1 iOS app.

This is a port of the Android app (`HciVolumeCursorApp`) to iPhone (Swift / UIKit).
Same tasks, same counterbalancing groups, same CSV columns, and the same random order per participant ID,
so iOS and Android data can be merged directly.

**Status: written on Windows, never compiled or run.** Expect to fix small compile errors in Xcode.

## Requirements

- A Mac with Xcode 15 or later
- iPhone with iOS 15 or later
- A free Apple ID is enough (the app must be reinstalled every 7 days with a free account)

## Build (option A — XcodeGen, recommended)

```bash
brew install xcodegen
cd HciVolumeCursorApp-iOS
xcodegen
open HciCursorStudy.xcodeproj
```

Then in Xcode: select the `HciCursorStudy` target → **Signing & Capabilities** → choose your Team (your Apple ID).
Change the Bundle Identifier if Xcode says it is taken (e.g. add your initials).
Connect the iPhone, select it as the run destination, and press ▶ Run.

On the iPhone: **Settings → General → VPN & Device Management** → trust your developer certificate.
On iOS 16+, also turn on **Settings → Privacy & Security → Developer Mode**.

## Build (option B — without XcodeGen)

1. Xcode → File → New → Project → iOS **App**, Interface: **Storyboard**, Language: **Swift**, name `HciCursorStudy`.
2. Delete the generated `AppDelegate.swift`, `SceneDelegate.swift`, `ViewController.swift`, `Main.storyboard`.
3. Drag all `.swift` files from the `HciCursorStudy` folder into the project (Copy items if needed).
4. Replace the target's Info.plist with `HciCursorStudy/Info.plist`
   (Build Settings → `Info.plist File` = path to it, and `Generate Info.plist File` = No).
   Make sure there is **no** `UIApplicationSceneManifest` and **no** `UIMainStoryboardFile` entry.
5. Deployment target: iOS 15.0. Signing as above. Run.

## Files

| File | Role |
|---|---|
| `Model.swift` | Language switch, conditions, 32 + 4 sentences, NASA-TLX items, Java-compatible random |
| `CsvLogger.swift` | CSV writing (same format as Android) |
| `VolumeButtonObserver.swift` | Volume-button detection |
| `ExperimentViewController.swift` | All screens and measurement logic |
| `StudyTextView.swift` | Text view without copy/paste menu, thick cursor, touch counter, colors |

## Differences from Android (important)

1. **Volume buttons:** iOS has no public API to capture the volume buttons.
   The app watches the system volume and resets it to 50% after each press.
   - The system volume HUD may briefly appear on some iOS versions.
   - **Long press:** iOS repeats volume changes while a button is held. The app treats events that
     arrive less than `holdGap` (0.30 s) apart as one hold. After `longPressThreshold` (0.5 s) each
     repeat event moves `repeatStep` (2) characters. The real speed depends on iOS's repeat rate,
     so **check it in a pilot** (turn on debug info: `gap` shows the time between events in ms)
     and adjust the three constants at the top of `ExperimentViewController.swift`.
   - Two very fast separate taps (< 0.3 s apart) may be counted as one hold
     (`key_press_count` slightly lower, `key_repeat_moves` slightly higher).
   - Do not set the iPhone to silent-only volume limits; if the phone volume is at 0 or 100% when the
     app starts, the first press may be lost (the app resets to 50% automatically afterwards).
2. **Touch drag:** iOS has no teardrop handle. Participants tap to place the cursor and press-and-drag
   the cursor to move it. iOS's spacebar trackpad (press and hold the spacebar) must not be used;
   if used in the volume condition, it is logged in `off_mode_input_count`.
3. **Stopping:** there is no Back button. Use **Stop** (top right) on the intro/TLX screens or
   **Hold to stop** at the bottom of the task screen.
4. **CSV location:** Files app → On My iPhone → HciCursorStudy → HCI_Study, or use the share buttons.
5. Because the device differs (screen size, button position, keyboard), **do not mix iPhone and Android
   participants in one analysis without noting it**. Add a `device` column when merging.

---

# 한국어 안내

안드로이드 앱을 아이폰(Swift / UIKit)으로 옮긴 **실험용 버전**입니다.
과업 문장, 카운터밸런싱 그룹, CSV 컬럼이 모두 같습니다. 같은 피험자 ID면 문장 순서와 시작 위치도 안드로이드와 똑같이 나옵니다.

**주의:** Windows에서 작성해서 **한 번도 빌드·실행해 보지 못했습니다.** Xcode에서 작은 컴파일 오류가 날 수 있습니다.

## 준비물
- Xcode 15 이상이 설치된 **Mac**
- iOS 15 이상 아이폰
- 무료 Apple ID로 설치 가능 (단, 7일마다 다시 설치해야 함)

## 빌드 (Mac 터미널)
```bash
brew install xcodegen
cd HciVolumeCursorApp-iOS
xcodegen
open HciCursorStudy.xcodeproj
```
Xcode에서 Signing & Capabilities → Team에 본인 Apple ID 선택 → 아이폰 연결 → ▶ 실행.
아이폰에서 설정 → 일반 → VPN 및 기기 관리 → 개발자 신뢰, iOS 16 이상은 설정 → 개인정보 보호 및 보안 → 개발자 모드 켜기.

## 안드로이드와 다른 점
1. **볼륨 버튼:** iOS는 볼륨 버튼을 직접 받는 기능이 없어서, 음량 변화를 감지한 뒤 음량을 50%로 되돌리는 방식입니다.
   음량 표시가 잠깐 뜰 수 있고, **길게 누르기 속도는 iOS 자동 반복 속도에 따라 달라지므로 파일럿에서 꼭 확인**하세요.
   (디버그 표시의 `gap`이 이벤트 간격(ms)입니다. `ExperimentViewController.swift` 맨 위 상수 3개로 조정)
2. **터치 드래그:** 아이폰에는 물방울 손잡이가 없습니다. 탭으로 커서를 놓고, 커서를 길게 눌러 끌어서 옮깁니다.
3. **중단:** 뒤로 가기 버튼이 없으므로 안내/TLX 화면 오른쪽 위 [중단], 과업 화면 아래 '길게 눌러 중단'을 씁니다.
4. **CSV 위치:** 파일 앱 → 나의 iPhone → HciCursorStudy → HCI_Study (또는 공유 버튼)
5. 기기가 다르면 결과가 달라질 수 있으므로, 아이폰/안드로이드 데이터를 합칠 때는 기기 컬럼을 추가해 구분하세요.

# How to install the HCI Study app (v2) on an iPhone

iPhones cannot install apps from a downloaded file the way Android installs an APK.
The app has to be **built and signed** with an Apple ID first. There are two ways to do that,
depending on whether you have a Mac.

| | Option A — with a Mac | Option B — without a Mac (Windows only) |
|---|---|---|
| What you need | Mac with Xcode, iPhone, USB cable, Apple ID | Windows PC, iPhone, USB cable, Apple ID, GitHub account |
| Difficulty | Easy | Medium |
| Time (first time) | ~30 min (Xcode download takes longest) | ~30–40 min |

**Both options:**
- A free Apple ID is enough. You do **not** need the paid Apple Developer Program.
- With a free Apple ID the app **stops opening after 7 days.** Install it again the same way,
  ideally 1–2 days before the experiment sessions. Your saved CSV files are kept when you reinstall.
- iPhone with **iOS 15 or later**.

> ⚠ This iOS version has not been compiled yet (it was written without a Mac).
> If you see a build error, copy the full error message and send it back so it can be fixed.

---

## Option A — With a Mac

### 1. Install the tools (once)
1. Install **Xcode** from the Mac App Store (free, large download).
2. Open Xcode once and accept the license. Let it install additional components.
3. Install **Homebrew** if you don't have it: <https://brew.sh> (copy the one-line command into Terminal).
4. In Terminal, install XcodeGen:
   ```bash
   brew install xcodegen
   ```

### 2. Create the Xcode project
1. Copy the whole `HciVolumeCursorApp-iOS-v2` folder to the Mac.
2. In Terminal:
   ```bash
   cd path/to/HciVolumeCursorApp-iOS-v2
   xcodegen
   open HciCursorStudy.xcodeproj
   ```
   (Tip: type `cd ` and drag the folder into the Terminal window to fill in the path.)

### 3. Sign with your Apple ID
1. Xcode → **Settings → Accounts** → **+** → **Apple ID** → sign in.
2. In the left panel, click the blue **HciCursorStudy** project → target **HciCursorStudy** →
   **Signing & Capabilities** tab.
3. Check **Automatically manage signing** and choose your name (Personal Team) under **Team**.
4. If Xcode says the Bundle Identifier is unavailable, change it to something unique,
   e.g. `com.yourname.hcistudy.v2`.

### 4. Install on the iPhone
1. Connect the iPhone with a cable. Unlock it and tap **Trust This Computer**.
2. At the top of the Xcode window, select your iPhone as the run destination.
3. Press **▶ (Run)**. The first build takes a few minutes.
4. If the iPhone asks for **Developer Mode** (iOS 16+):
   **Settings → Privacy & Security → Developer Mode → On**, then restart the phone and confirm.
5. If the app won't open ("Untrusted Developer"):
   **Settings → General → VPN & Device Management** → tap your Apple ID → **Trust**.

The app appears on the home screen as **HCI Study v2**. After that, the Mac is no longer needed until the 7 days run out.

---

## Option B — Without a Mac (Windows)

The idea: GitHub builds the app for free on one of its Macs in the cloud, you download the file (`.ipa`),
and a Windows tool called **Sideloadly** signs it with your Apple ID and installs it on the iPhone.

### 1. Build the app on GitHub (once per code change)
1. Create a free account at <https://github.com> and click **New repository**.
   Name it e.g. `hci-study-ios`. **Private** is fine.
2. Click **uploading an existing file** and upload the **contents** of the `HciVolumeCursorApp-iOS-v2` folder
   (the `HciCursorStudy` folder, `project.yml`, the `.github` folder, etc.) so that `project.yml`
   is at the top level of the repository.
   - The `.github` folder is hidden on some PCs. If drag-and-drop skips it, create the file manually on GitHub:
     **Add file → Create new file**, name it `.github/workflows/build-ios.yml`, and paste the contents of that file.
3. Open the **Actions** tab → **Build iOS app (unsigned IPA)** → **Run workflow**.
4. Wait ~5–10 minutes until the run shows a green check. ❌ red = build error → open it, copy the error, send it back.
5. Open the finished run, scroll to **Artifacts**, and download **HciCursorStudy-ipa**.
   Unzip it to get `HciCursorStudy-unsigned.ipa`.

### 2. Install Sideloadly on Windows (once)
1. Install **iTunes** and **iCloud** from Apple's website (the versions from apple.com,
   **not** the Microsoft Store versions — Sideloadly needs them to talk to the iPhone).
2. Download and install **Sideloadly** from its official site: <https://sideloadly.io>

### 3. Install on the iPhone
1. Connect the iPhone with a cable. Unlock it and tap **Trust This Computer**.
2. Open Sideloadly. Your iPhone should appear under **iDevice**.
3. Drag `HciCursorStudy-unsigned.ipa` into Sideloadly.
4. Enter your **Apple ID** email and press **Start**. Enter your Apple ID password when asked
   (it is sent only to Apple). Some people use a separate Apple ID for this — that's fine too.
5. When it says **Done**, on the iPhone:
   - **Settings → General → VPN & Device Management** → tap your Apple ID → **Trust**.
   - iOS 16+: **Settings → Privacy & Security → Developer Mode → On**, restart, confirm.

After 7 days, repeat **step 3 only** (you can reuse the same `.ipa`).

---

## After installing: 10-minute check before the real experiment

The iPhone cannot report "volume button held down" the way Android can, so the app guesses a long press
from the repeated volume changes iOS sends while a button is held. Please check that it feels right:

1. Open the app → turn on **Show debug info** → start a test session (ID e.g. `T01`)
   and go to a **Volume Keys** condition.
2. **Tap** volume ▲ or ▼ once → the cursor moves 1 character; the debug line shows `lastKey ▲ move`.
3. **Hold** a volume button → the debug line should go `repeat` → `fast`, and the cursor should move quickly.
4. Note the `gap` value (milliseconds between repeated events) shown while holding, e.g. `gap 100ms`.
5. Send back: the **gap value**, your **iPhone model / iOS version**, and whether the hold speed felt
   too fast, too slow, or OK. The speed can then be adjusted to match the Android version.

Other things to check: the volume HUD (the on-screen volume bar) should not pop up much,
and the CSV files should appear in **Files → On My iPhone → HciCursorStudy → HCI_Study**.

## Getting the data out
- At the end of a session, tap **Export / Share CSV** and send the files (AirDrop, email, Google Drive, …).
- Or open the **Files** app → **On My iPhone → HciCursorStudy → HCI_Study**.
- File names look like `P01_GA_EN_20261116_101500_trials.csv` (participant, group, task language, date/time).

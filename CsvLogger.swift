import Foundation

/// 시행 로그와 NASA-TLX 응답을 CSV로 저장한다 (안드로이드 버전과 같은 컬럼·형식).
///
/// 매 시행/설문이 끝날 때마다 바로 한 줄씩 추가하므로 앱이 꺼져도 그때까지의 데이터는 남는다.
/// 저장 위치: 앱의 Documents/HCI_Study/  → '파일' 앱 > 나의 iPhone > HciCursorStudy 에서 보인다.
enum CsvLogger {
    private(set) static var trials: [TrialRecord] = []
    private(set) static var tlx: [TlxRecord] = []
    private(set) static var trialFile: URL?
    private(set) static var tlxFile: URL?

    private static let trialHeader =
        "participant_id,group,condition_order,condition_id,technique,environment,is_practice," +
        "trial_in_condition,trial_number,task_id,language,length_type,text_length," +
        "target_index,initial_index,initial_distance,is_success," +
        "completion_time_ms,first_reach_time_ms,positioning_time_ms,first_edit_in_zone," +
        "overshoot_count,cursor_travel,cursor_move_events,edit_count," +
        "key_press_count,key_repeat_moves,key_press_kb_hidden,touch_count,off_mode_input_count,timestamp,task_text"

    private static let tlxHeader =
        "participant_id,group,condition_order,condition_id,technique,environment," +
        "mental,physical,temporal,performance,effort,frustration,raw_tlx,timestamp"

    static var outputDir: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("HCI_Study", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func startSession(participantId: String, group: String, taskLanguage: String) {
        trials.removeAll()
        tlx.removeAll()
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd_HHmmss"
        let stamp = f.string(from: Date())
        // v2: 파일 이름에 과업 언어 표시 (예: P01_GA_KO_20261116_101500_trials.csv)
        let base = "\(participantId)_G\(group)_\(taskLanguage)_\(stamp)"
        trialFile = outputDir.appendingPathComponent("\(base)_trials.csv")
        tlxFile = outputDir.appendingPathComponent("\(base)_tlx.csv")
        // UTF-8 BOM: 엑셀에서 한글이 깨지지 않도록
        writeLine(trialFile!, "\u{FEFF}" + trialHeader)
        writeLine(tlxFile!, "\u{FEFF}" + tlxHeader)
    }

    private static func b(_ v: Bool) -> String { v ? "TRUE" : "FALSE" }

    static func addTrial(_ r: TrialRecord) {
        trials.append(r)
        let escapedText = "\"" + r.taskText.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        let fields: [String] = [
            r.participantId, r.group, "\(r.conditionOrder)", "\(r.conditionId)", r.technique, r.environment,
            b(r.isPractice), "\(r.trialInCondition)", "\(r.trialNumber)", "\(r.taskId)",
            r.language, r.lengthType, "\(r.textLength)", "\(r.targetIndex)", "\(r.initialIndex)", "\(r.initialDistance)",
            b(r.isSuccess), "\(r.completionTimeMs)", "\(r.firstReachTimeMs)",
            "\(r.positioningTimeMs)", b(r.firstEditInZone),
            "\(r.overshootCount)", "\(r.cursorTravel)", "\(r.cursorMoveEvents)", "\(r.editCount)",
            "\(r.keyPressCount)", "\(r.keyRepeatMoves)", "\(r.keyPressKbHidden)", "\(r.touchCount)",
            "\(r.offModeInputCount)", r.timestamp,
        ]
        if let f = trialFile { writeLine(f, fields.joined(separator: ",") + "," + escapedText) }
    }

    static func addTlx(_ r: TlxRecord) {
        tlx.append(r)
        let fields: [String] = [
            r.participantId, r.group, "\(r.conditionOrder)", "\(r.conditionId)", r.technique, r.environment,
            "\(r.mental)", "\(r.physical)", "\(r.temporal)", "\(r.performance)", "\(r.effort)", "\(r.frustration)",
            String(format: "%.2f", r.rawTlx), r.timestamp,
        ]
        if let f = tlxFile { writeLine(f, fields.joined(separator: ",")) }
    }

    static func currentFiles() -> [URL] { [trialFile, tlxFile].compactMap { $0 } }

    /// 공유할 파일: 이번 실행의 세션 파일. 없으면 저장 폴더에서 가장 최근 세션(trials + tlx 한 쌍).
    static func filesForShare() -> [URL] {
        let fm = FileManager.default
        let current = currentFiles().filter { fm.fileExists(atPath: $0.path) }
        if !current.isEmpty { return current }
        guard let items = try? fm.contentsOfDirectory(at: outputDir, includingPropertiesForKeys: [.contentModificationDateKey]) else { return [] }
        let latest = items
            .filter { $0.lastPathComponent.hasSuffix("_trials.csv") }
            .max { a, b in
                let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return da < db
            }
        guard let trialsUrl = latest else { return [] }
        let name = trialsUrl.lastPathComponent
        let tlxUrl = trialsUrl.deletingLastPathComponent()
            .appendingPathComponent(String(name.dropLast("_trials.csv".count)) + "_tlx.csv")
        return [trialsUrl, tlxUrl].filter { fm.fileExists(atPath: $0.path) }
    }

    private static func writeLine(_ url: URL, _ line: String) {
        let data = (line + "\n").data(using: .utf8)!
        if FileManager.default.fileExists(atPath: url.path), let h = try? FileHandle(forWritingTo: url) {
            h.seekToEndOfFile()
            h.write(data)
            h.closeFile()
        } else {
            try? data.write(to: url)
        }
    }
}

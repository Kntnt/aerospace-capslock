// Local AeroSpace helpers. Rebuild with ../build.sh.
import AppKit
import Carbon
import Foundation

// Optional overrides let the launch flow be tested without moving real windows.
func aerospaceExecutable() -> String {
    if let override = ProcessInfo.processInfo.environment["AEROSPACE_CLI"] { return override }
    let path = ProcessInfo.processInfo.environment["PATH"] ?? ""
    let candidates = ["/opt/homebrew/bin/aerospace", "/usr/local/bin/aerospace"]
        + path.split(separator: ":").map { String($0) + "/aerospace" }
    return candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) })
        ?? "/opt/homebrew/bin/aerospace"
}
let aerospace = aerospaceExecutable()
let appOpener = ProcessInfo.processInfo.environment["AEROSPACE_APP_OPENER"] ?? "/usr/bin/open"
let aerospaceBundleID = "bobko.aerospace"

struct ShortcutError: Error, CustomStringConvertible {
    let description: String
    init(_ message: String) { description = message }
}

@discardableResult
func run(_ executable: String, _ arguments: [String], allowFailure: Bool = false) throws -> String {
    let process = Process()
    let output = Pipe()
    // Keep errors separate from machine-readable JSON.
    let errors = Pipe()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    var environment = ProcessInfo.processInfo.environment
    environment.removeValue(forKey: "AEROSPACE_WINDOW_ID")
    environment.removeValue(forKey: "AEROSPACE_WORKSPACE")
    process.environment = environment
    process.standardOutput = output
    process.standardError = errors
    try process.run()
    let data = output.fileHandleForReading.readDataToEndOfFile()
    let errorData = errors.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    if process.terminationStatus != 0 && !allowFailure {
        let detail = String(decoding: errorData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        throw ShortcutError("\(executable) \(arguments.joined(separator: " ")): \(detail)")
    }
    return String(decoding: data, as: UTF8.self)
}

func mouseFollowsFocus() {
    _ = try? run(aerospace, ["eval", "move-mouse window-lazy-center || move-mouse monitor-lazy-center"], allowFailure: true)
}

struct AppTarget {
    let workspace: String
    let url: URL
    var bundleID: String { Bundle(url: url)!.bundleIdentifier! }
}

func appTarget(_ key: String) throws -> AppTarget {
    let names = ["c": "Claude", "e": "Sublime Text", "g": "ChatGPT",
                 "m": "Typora", "s": "Spotify", "t": "Ghostty"]
    let url: URL
    if key == "b", let browser = ProcessInfo.processInfo.environment["AEROSPACE_BROWSER_APP"] {
        url = URL(fileURLWithPath: browser)
    } else if key == "b" {
        // Resolve the default browser without actually opening a URL.
        guard let browser = NSWorkspace.shared.urlForApplication(toOpen: URL(string: "https://example.com")!) else {
            throw ShortcutError("No default browser was found.")
        }
        url = browser
    } else if let name = names[key] {
        url = URL(fileURLWithPath: "/Applications/\(name).app")
    } else {
        throw ShortcutError("Unknown app shortcut: \(key)")
    }
    guard Bundle(url: url)?.bundleIdentifier != nil else {
        throw ShortcutError("Application not found: \(url.path)")
    }
    return AppTarget(workspace: key.uppercased(), url: url)
}

func windows(_ arguments: [String]) throws -> [[String: Any]] {
    let output = try run(aerospace, ["list-windows"] + arguments + [
        "--format", "%{window-id} %{app-bundle-id} %{workspace}", "--json"
    ], allowFailure: arguments.contains("--focused"))
    if output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return [] }
    guard let result = try JSONSerialization.jsonObject(with: Data(output.utf8)) as? [[String: Any]] else {
        throw ShortcutError("AeroSpace returned an unexpected list-windows response.")
    }
    return result
}

func windowID(_ window: [String: Any]) -> String? {
    (window["window-id"] as? NSNumber)?.stringValue
}

func chooseWindow(_ candidates: [[String: Any]], focused: [String: Any]?, workspace: String) -> [String: Any]? {
    if let focused, let id = windowID(focused),
       let match = candidates.first(where: { windowID($0) == id }) { return match }
    return candidates.first(where: { $0["workspace"] as? String == workspace }) ?? candidates.first
}

func launchApp(_ key: String) throws {
    let target = try appTarget(key)
    // Confirm that AeroSpace is reachable before changing application focus.
    let existing = try windows(["--monitor", "all", "--app-bundle-id", target.bundleID])
    try run(aerospace, ["workspace", target.workspace])
    // open also reopens an application that is running with no open windows.
    try run(appOpener, ["-a", target.url.path])
    let deadline = Date().addingTimeInterval(30)
    let activationDeadline = Date().addingTimeInterval(2)
    while Date() < deadline {
        let candidates = try windows(["--monitor", "all", "--app-bundle-id", target.bundleID])
        let focused = try windows(["--focused"]).first
        let appHasFocus = focused?["app-bundle-id"] as? String == target.bundleID
        // Wait for activation to identify the app's selected window. A fallback
        // handles apps that expose a window without reporting focus promptly.
        if !candidates.isEmpty && (appHasFocus || Date() >= activationDeadline) {
            guard let window = chooseWindow(candidates, focused: focused, workspace: target.workspace),
                  let id = windowID(window) else { throw ShortcutError("Window ID is missing.") }
            try run(aerospace, ["move-node-to-workspace", "--window-id", id,
                                "--focus-follows-window", target.workspace])
            try run(aerospace, ["focus", "--window-id", id])
            mouseFollowsFocus()
            return
        }
        Thread.sleep(forTimeInterval: 0.1)
    }
    throw ShortcutError("\(target.url.lastPathComponent) did not open a usable window within 30 seconds (\(existing.count) existed before launch).")
}

func toggle() {
    do {
        try run(aerospace, ["enable", "toggle"])
        mouseFollowsFocus()
    } catch {
        fputs("AeroSpace toggle: \(error)\n", stderr)
    }
}

func hotkey() throws {
    // This helper belongs to AeroSpace's lifetime, including its paused state.
    guard let owner = NSRunningApplication.runningApplications(withBundleIdentifier: aerospaceBundleID).first else {
        throw ShortcutError("AeroSpace is not running.")
    }
    _ = setpgid(0, 0)
    let application = NSApplication.shared
    application.setActivationPolicy(.prohibited)
    var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
    var handler: EventHandlerRef?
    let handlerStatus = InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
        toggle()
        return noErr
    }, 1, &eventType, nil, &handler)
    guard handlerStatus == noErr else { throw ShortcutError("Could not install the hotkey handler: \(handlerStatus)") }
    var reference: EventHotKeyRef?
    let identifier = EventHotKeyID(signature: 0x41535043, id: 1) // ASPC
    // Hyperkey maps Caps Lock to Ctrl + Alt + Cmd; Shift is a separate layer.
    let modifiers = UInt32(controlKey | optionKey | cmdKey)
    let status = RegisterEventHotKey(UInt32(kVK_Escape), modifiers, identifier, GetApplicationEventTarget(), 0, &reference)
    guard status == noErr else {
        throw ShortcutError("Caps + Escape could not be registered (error \(status)); another process may already be using this shortcut.")
    }
    print("Caps + Escape registered; AeroSpace PID \(owner.processIdentifier).")
    fflush(stdout)
    // A timer also covers abnormal termination, without a persistent login agent.
    let timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
        if owner.isTerminated { application.terminate(nil) }
    }
    application.run()
    timer.invalidate()
    if let reference { UnregisterEventHotKey(reference) }
    if let handler { RemoveEventHandler(handler) }
}

func selfTest() throws {
    let a: [String: Any] = ["window-id": 1, "workspace": "3"]
    let b: [String: Any] = ["window-id": 2, "workspace": "B"]
    guard windowID(chooseWindow([a, b], focused: a, workspace: "B")!) == "1",
          windowID(chooseWindow([a, b], focused: nil, workspace: "B")!) == "2",
          windowID(chooseWindow([a], focused: nil, workspace: "B")!) == "1",
          chooseWindow([], focused: a, workspace: "B") == nil else {
        throw ShortcutError("Window selection self-test failed.")
    }
    for key in ["b", "c", "e", "g", "m", "s", "t"] {
        let target = try appTarget(key)
        print("\(target.workspace): \(target.url.path) [\(target.bundleID)]")
    }
    print("Window selection and application targets: OK")
}

do {
    let arguments = Array(CommandLine.arguments.dropFirst())
    switch arguments.first {
    case "launch" where arguments.count == 2: try launchApp(arguments[1].lowercased())
    case "hotkey" where arguments.count == 1: try hotkey()
    case "self-test" where arguments.count == 1: try selfTest()
    default: throw ShortcutError("Usage: aerospace-shortcuts launch <b|c|e|g|m|s|t> | hotkey | self-test")
    }
} catch {
    fputs("\(error)\n", stderr)
    exit(1)
}

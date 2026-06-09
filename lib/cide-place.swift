// cide-place.swift — macOS-native display detection + window placement for cide.
// Pure Apple frameworks (no aerospace/yabai/hammerspoon):
//   • CoreGraphics  — display geometry in the SAME top-left coordinate space the
//     Accessibility API uses (CGDisplayBounds), so window moves need no Y-flip.
//   • AppKit        — NSScreen.localizedName (the human-friendly monitor name) +
//     NSScreen↔CGDirectDisplayID mapping, and the frontmost app.
//   • ApplicationServices (AX) — move the focused window of the frontmost app.
//
// Run interpreted (no build step): `swift cide-place.swift list | move <monitor-ref>`.
// `move` targets the frontmost app's focused window — cide focuses the cmux window first
// (cmux focus-window) so "frontmost" is the window we mean. The Accessibility grant is
// attributed to the responsible app in the process tree (cmux/Ghostty), NOT `swift`.
import AppKit
import ApplicationServices

struct Display { let name: String; let uuid: String; let bounds: CGRect; let orientation: String }

func displays() -> [Display] {
    var out: [Display] = []
    for s in NSScreen.screens {
        guard let n = s.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { continue }
        let id = CGDirectDisplayID(n.uint32Value)
        let b = CGDisplayBounds(id)               // top-left origin, == AX coordinate space
        let uuid = CFUUIDCreateString(nil, CGDisplayCreateUUIDFromDisplayID(id).takeRetainedValue()) as String
        out.append(Display(name: s.localizedName, uuid: uuid, bounds: b,
                           orientation: b.height > b.width ? "portrait" : "landscape"))
    }
    return out
}

func resolve(_ ref: String, _ ds: [Display]) -> Display? {
    let r = ref.lowercased()
    if let m = ds.first(where: { $0.uuid.lowercased() == r }) { return m }   // UUID (exact)
    if let m = ds.first(where: { $0.name.lowercased() == r }) { return m }   // macOS name (case-insensitive)
    if r == "portrait" || r == "landscape", let m = ds.first(where: { $0.orientation == r }) { return m }
    if let i = Int(ref), i >= 0, i < ds.count { return ds[i] }               // arrangement index
    return nil
}

func err(_ s: String) { FileHandle.standardError.write((s + "\n").data(using: .utf8)!) }

func axTrusted(prompt: Bool) -> Bool {
    let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
    return AXIsProcessTrustedWithOptions(opts)
}

// Move (and best-effort raise) the frontmost app's focused window to a display origin.
func moveFrontmostWindow(to b: CGRect) -> Bool {
    guard let app = NSWorkspace.shared.frontmostApplication else { return false }
    let axApp = AXUIElementCreateApplication(app.processIdentifier)
    var winRef: CFTypeRef?
    guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &winRef) == .success,
          let win = winRef else { return false }
    let window = win as! AXUIElement
    var pos = b.origin
    guard let posVal = AXValueCreate(.cgPoint, &pos) else { return false }
    return AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posVal) == .success
}

let args = Array(CommandLine.arguments.dropFirst())
switch args.first ?? "" {
case "list":
    for d in displays() {
        print("\(d.name)\t\(d.uuid)\t\(Int(d.bounds.width))x\(Int(d.bounds.height))\t\(d.orientation)\t\(Int(d.bounds.origin.x)),\(Int(d.bounds.origin.y))")
    }
case "move":
    guard args.count >= 2 else { err("cide-place: move needs a monitor ref"); exit(2) }
    guard let target = resolve(args[1], displays()) else { err("cide-place: no display matched '\(args[1])'"); exit(3) }
    if !axTrusted(prompt: true) {
        err("cide-place: Accessibility permission needed — grant it to cmux (or Ghostty) in")
        err("            System Settings ▸ Privacy & Security ▸ Accessibility, then retry.")
        exit(4)
    }
    if moveFrontmostWindow(to: target.bounds) { print("cide-place: moved frontmost window → \(target.name)") }
    else { err("cide-place: AX move failed (no focused window, or window not movable)"); exit(5) }
default:
    err("usage: cide-place.swift  list | move <name|uuid|portrait|landscape|index>"); exit(64)
}

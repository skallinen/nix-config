// keylight: a small square in the top left corner of every screen that says where the
// keystrokes go. utm-arch wiki/utm-input-and-keyboard.md, "Keylight".
//
//   green  UTM is the frontmost app AND has captured input: keys go to the VM
//   blue   another Mac app is frontmost, or UTM is but capture is released
//          (Command+Option): keys go to the Mac
//   red    the ErgoDox EZ (3297:4975) has no HID device on the Mac: it was handed to the
//          VM over USB, or the hub dropped it. A notification and a sound on the change.
//
// Click-through, never key, never activates; on all Spaces including UTM's full screen
// Space. It reads only the IORegistry (no device is opened), NSWorkspace and the global
// hot key mode, so it needs no Accessibility, Input Monitoring or Screen Recording
// permission, and it runs on the Mac, so a frozen VM does not stop it. Run by launchd
// (nix-config utm-arch/keylight/darwin.nix); state changes are printed for the log.

import AppKit
import IOKit

// Capture signal. UTM 4.7.5 VMMetalView.captureMouse() calls
// CGSSetGlobalHotKeyOperatingMode(cid, .disable) and releaseMouse() sets .enable again;
// the mode is global in the WindowServer, so any process reads it (0 enabled, 1 disabled).
// No notification exists, so it is polled. Window subtitle ("Press ... to release
// cursor") would need Screen Recording; cursor visibility reads only our own process.
@_silgen_name("CGSMainConnectionID") func CGSMainConnectionID() -> Int32
@_silgen_name("CGSGetGlobalHotKeyOperatingMode")
func CGSGetGlobalHotKeyOperatingMode(_ cid: Int32, _ mode: UnsafeMutablePointer<UInt32>) -> Int32

func hotKeysDisabled() -> Bool {
  var mode: UInt32 = 0
  return CGSGetGlobalHotKeyOperatingMode(CGSMainConnectionID(), &mode) == 0 && mode != 0
}

let utmBundle = "com.utmapp.UTM"
let keyboardVendor = 0x3297
let keyboardProduct = 0x4975
let side: CGFloat = 14
let inset: CGFloat = 6   // clear of the rounded display corner

enum State: String { case vm, mac, gone }

func colour(_ s: State) -> NSColor {
  switch s {
  case .vm:   return NSColor(srgbRed: 0.13, green: 0.80, blue: 0.27, alpha: 1)
  case .mac:  return NSColor(srgbRed: 0.20, green: 0.45, blue: 1.00, alpha: 1)
  case .gone: return NSColor(srgbRed: 1.00, green: 0.15, blue: 0.15, alpha: 1)
  }
}

func log(_ s: String) {
  let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd HH:mm:ss"
  print("\(f.string(from: Date())) \(s)"); fflush(stdout)
}

func notify(_ title: String, _ body: String) {
  // osascript, because UNUserNotificationCenter needs an app bundle.
  let p = Process()
  p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
  p.arguments = ["-e", "display notification \"\(body)\" with title \"\(title)\""]
  try? p.run()
}

final class Light {
  var windows: [NSWindow] = []
  var state: State = .mac
  var frontIsUTM = false
  var captured = false
  var keyboardCount = 0
  var notifyPorts: IONotificationPortRef?
  var iterators: [io_iterator_t] = []

  func start() {
    frontIsUTM = NSWorkspace.shared.frontmostApplication?.bundleIdentifier == utmBundle
    let nc = NSWorkspace.shared.notificationCenter
    nc.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { n in
      let app = n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
      self.frontIsUTM = app?.bundleIdentifier == utmBundle
      self.update()
    }
    NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { _ in
      self.buildWindows()
    }
    captured = hotKeysDisabled()
    Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { _ in
      let c = hotKeysDisabled()
      if c != self.captured { self.captured = c; self.update() }
    }
    watchKeyboard()
    buildWindows()
    update(initial: true)
  }

  // One IOHIDDevice per HID interface of the keyboard. When UTM hands the keyboard to
  // the VM, macOS detaches the HID driver and these terminate (Karabiner logs "is
  // terminated"); a hub drop terminates them too.
  func watchKeyboard() {
    let port = IONotificationPortCreate(kIOMainPortDefault)
    notifyPorts = port
    IONotificationPortSetDispatchQueue(port, DispatchQueue.main)
    let me = Unmanaged.passUnretained(self).toOpaque()
    for (kind, delta) in [(kIOFirstMatchNotification, 1), (kIOTerminatedNotification, -1)] {
      let match = IOServiceMatching("IOHIDDevice") as NSMutableDictionary
      match["VendorID"] = keyboardVendor
      match["ProductID"] = keyboardProduct
      var it: io_iterator_t = 0
      let cb: IOServiceMatchingCallback = delta > 0
        ? { ctx, it in let l = Unmanaged<Light>.fromOpaque(ctx!).takeUnretainedValue(); l.drain(it, 1) }
        : { ctx, it in let l = Unmanaged<Light>.fromOpaque(ctx!).takeUnretainedValue(); l.drain(it, -1) }
      IOServiceAddMatchingNotification(port, kind, match, cb, me, &it)
      iterators.append(it)
      drain(it, delta, quiet: true)
    }
  }

  func drain(_ it: io_iterator_t, _ delta: Int, quiet: Bool = false) {
    var s = IOIteratorNext(it)
    while s != 0 { keyboardCount = max(0, keyboardCount + delta); IOObjectRelease(s); s = IOIteratorNext(it) }
    if !quiet { update() }
  }

  func buildWindows() {
    windows.forEach { $0.orderOut(nil) }
    windows = NSScreen.screens.map { screen in
      let f = screen.frame
      let rect = NSRect(x: f.minX + inset, y: f.maxY - inset - side, width: side, height: side)
      let w = NSPanel(contentRect: rect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
      w.level = .screenSaver
      w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
      w.ignoresMouseEvents = true
      w.isOpaque = false
      w.hasShadow = false
      w.hidesOnDeactivate = false
      w.backgroundColor = .clear
      let v = NSView(frame: NSRect(x: 0, y: 0, width: side, height: side))
      v.wantsLayer = true
      v.layer?.cornerRadius = 3
      v.layer?.borderWidth = 1
      v.layer?.borderColor = NSColor(white: 0, alpha: 0.6).cgColor
      w.contentView = v
      w.orderFrontRegardless()
      return w
    }
    paint()
  }

  func paint() {
    for w in windows { w.contentView?.layer?.backgroundColor = colour(state).cgColor }
  }

  func update(initial: Bool = false) {
    let next: State = keyboardCount == 0 ? .gone : (frontIsUTM && captured ? .vm : .mac)
    if next == state && !initial { return }
    let prev = state
    state = next
    paint()
    log("\(next.rawValue) (front UTM: \(frontIsUTM), captured: \(captured), ErgoDox HID devices: \(keyboardCount))")
    if next == .gone && (prev != .gone || initial) {
      NSSound(named: "Basso")?.play()
      notify("ErgoDox is not on the Mac", "It was handed to the VM or the hub dropped it. Built-in keyboard still works.")
    } else if prev == .gone && next != .gone && !initial {
      notify("ErgoDox is back on the Mac", "Keys from it reach macOS again.")
    }
  }
}

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)   // no Dock icon, never frontmost
let light = Light()
light.start()
app.run()

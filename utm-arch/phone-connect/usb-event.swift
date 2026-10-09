// The phone-connect job's own program (darwin.nix). launchd starts it when the Pixel
// appears on USB and hands it the IOKit matching event, which it must take with
// xpc_set_event_stream_handler, or launchd starts it again and again while the device
// stays attached (launchd.plist(5), xpc_events(3)). Only the process launchd spawned
// may take the event: run as a child of a shell script it got "failed activation ...
// error = 45: Operation not supported" (9.10.2026). So this is the job, and the script
// that asks the VM to pull is its argument, run once the events have been taken.
//   phone-usb-event SCRIPT [ARGS...]
import Foundation
import XPC

setvbuf(stdout, nil, _IOLBF, 0)
let args = CommandLine.arguments
var events = 0
xpc_set_event_stream_handler("com.apple.iokit.matching", DispatchQueue.main) { event in
    events += 1
    let name = xpc_dictionary_get_string(event, "XPCEventName").map { String(cString: $0) } ?? "?"
    print("iokit event \(name)")
}
// Events arrive right after the handler is set; one second takes them all.
DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
    if events == 0 { print("no iokit event (started by kickstart)") }
    guard args.count > 1 else { exit(0) }
    let p = Process()
    p.executableURL = URL(fileURLWithPath: args[1])
    p.arguments = Array(args.dropFirst(2))
    do { try p.run(); p.waitUntilExit(); exit(p.terminationStatus) }
    catch { print("could not run \(args[1]): \(error)"); exit(1) }
}
dispatchMain()

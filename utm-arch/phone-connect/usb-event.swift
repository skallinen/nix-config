// Takes the IOKit matching event that launchd holds for the phone-connect agent, prints
// the event's name, and exits. A job launched by LaunchEvents with IOMatchLaunchStream
// must take its event through xpc_set_event_stream_handler; one that does not is
// started again and again by launchd while the device stays attached (launchd.plist(5),
// xpc_events(3)). Events arrive on the main queue right after the handler is set; one
// second is ample, and a second event in that time is taken as well.
import Foundation
import XPC

xpc_set_event_stream_handler("com.apple.iokit.matching", DispatchQueue.main) { event in
    let name = xpc_dictionary_get_string(event, "XPCEventName").map { String(cString: $0) } ?? "?"
    print("iokit event \(name)")
}
DispatchQueue.main.asyncAfter(deadline: .now() + 1) { exit(0) }
dispatchMain()

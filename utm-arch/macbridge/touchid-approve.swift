// touchid-approve: ask the person at the Mac to approve something with Touch ID.
// Part of the utm-arch macbridge (utm-arch wiki/macbridge.md).
//
//   touchid-approve [--timeout SECONDS] REASON
//
// Shows the system Touch ID sheet with REASON. Exit codes: 0 approved, 1 denied or
// cancelled, 2 timed out, 3 no way to authenticate. The policy is
// deviceOwnerAuthentication: Touch ID, with the login password as the fallback (a
// closed lid or no finger on hand still works).
import Foundation
import LocalAuthentication

var args = Array(CommandLine.arguments.dropFirst())
var timeout: Double = 30
if args.count >= 2 && args[0] == "--timeout" {
    timeout = Double(args[1]) ?? 30
    args.removeFirst(2)
}
guard args.count == 1, !args[0].isEmpty else {
    FileHandle.standardError.write("usage: touchid-approve [--timeout SECONDS] REASON\n".data(using: .utf8)!)
    exit(64)
}
let reason = args[0]
let context = LAContext()
var error: NSError?
guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
    FileHandle.standardError.write("touchid-approve: cannot authenticate: \(error?.localizedDescription ?? "unknown")\n".data(using: .utf8)!)
    exit(3)
}
let done = DispatchSemaphore(value: 0)
var code: Int32 = 1
context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { ok, err in
    if ok { code = 0 }
    else if let e = err as? LAError, e.code == .appCancel { code = 2 }
    else { code = 1 }
    done.signal()
}
if done.wait(timeout: .now() + timeout) == .timedOut {
    context.invalidate()            // takes the sheet down
    _ = done.wait(timeout: .now() + 2)
    exit(2)
}
exit(code)

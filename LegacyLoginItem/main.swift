import Cocoa

guard let helperBundleIdentifier = Bundle.main.bundleIdentifier else {
    exit(1)
}

let mainBundleIdentifier = helperBundleIdentifier.replacingOccurrences(
    of: ".LoginItem",
    with: ""
)
if !NSRunningApplication.runningApplications(
    withBundleIdentifier: mainBundleIdentifier
).isEmpty {
    exit(0)
}

let components = (Bundle.main.bundlePath as NSString).pathComponents
guard components.count >= 5 else {
    exit(1)
}
let mainAppURL = URL(
    fileURLWithPath: NSString.path(
        withComponents: Array(components[0...(components.count - 5)])
    )
)
let configuration = NSWorkspace.OpenConfiguration()
configuration.arguments = ["--launched-at-login"]
NSWorkspace.shared.openApplication(
    at: mainAppURL,
    configuration: configuration
) { _, _ in
    exit(0)
}
RunLoop.main.run()

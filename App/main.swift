import Cocoa

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let appController = AppController()
app.delegate = appController
app.run()

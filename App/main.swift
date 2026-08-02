import Cocoa

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let appController = AppController()
app.delegate = appController

DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
    appController.start()
}

app.run()

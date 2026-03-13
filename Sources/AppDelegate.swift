import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var sessionManager: SessionManager!
    private var menuBarController: MenuBarController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarController = MenuBarController()
        sessionManager = SessionManager(delegate: menuBarController)
        sessionManager.startPolling()
    }
}

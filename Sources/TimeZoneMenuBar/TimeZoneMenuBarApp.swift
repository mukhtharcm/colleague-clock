import AppKit
import SwiftUI

private enum MenuBarIcon {
    static func makeImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18))
        image.lockFocus()

        NSColor.black.setStroke()
        NSColor.black.setFill()

        let primaryRect = NSRect(x: 1.5, y: 2.0, width: 10.5, height: 10.5)
        let secondaryRect = NSRect(x: 9.3, y: 9.1, width: 6.2, height: 6.2)

        let primaryClock = NSBezierPath(ovalIn: primaryRect)
        primaryClock.lineWidth = 1.35
        primaryClock.stroke()

        let secondaryClock = NSBezierPath(ovalIn: secondaryRect)
        secondaryClock.lineWidth = 1.25
        secondaryClock.stroke()

        let primaryCenter = NSPoint(x: primaryRect.midX, y: primaryRect.midY)
        let secondaryCenter = NSPoint(x: secondaryRect.midX, y: secondaryRect.midY)

        func drawHand(from center: NSPoint, length: CGFloat, angleDegrees: CGFloat, lineWidth: CGFloat) {
            let angle = angleDegrees * .pi / 180.0
            let endpoint = NSPoint(
                x: center.x + cos(angle) * length,
                y: center.y + sin(angle) * length
            )
            let path = NSBezierPath()
            path.lineCapStyle = .round
            path.lineWidth = lineWidth
            path.move(to: center)
            path.line(to: endpoint)
            path.stroke()
        }

        drawHand(from: primaryCenter, length: 3.8, angleDegrees: 30, lineWidth: 1.45)
        drawHand(from: primaryCenter, length: 2.55, angleDegrees: 140, lineWidth: 1.45)

        drawHand(from: secondaryCenter, length: 2.0, angleDegrees: 28, lineWidth: 1.2)
        drawHand(from: secondaryCenter, length: 1.35, angleDegrees: 312, lineWidth: 1.05)

        NSBezierPath(
            ovalIn: NSRect(x: primaryCenter.x - 0.65, y: primaryCenter.y - 0.65, width: 1.3, height: 1.3)
        ).fill()
        NSBezierPath(
            ovalIn: NSRect(x: secondaryCenter.x - 0.55, y: secondaryCenter.y - 0.55, width: 1.1, height: 1.1)
        ).fill()

        image.unlockFocus()
        image.isTemplate = true
        return image
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = TimeZoneStore()
    private let popover = NSPopover()
    private var statusItem: NSStatusItem?
    private var mainWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        configurePopover()
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = MenuBarIcon.makeImage()
        item.button?.image?.accessibilityDescription = "Colleague Clock"
        item.button?.imagePosition = .imageOnly
        item.button?.action = #selector(togglePopover(_:))
        item.button?.target = self
        statusItem = item
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: MainMenuView(
                store: store,
                onOpenApp: { [weak self] in
                    self?.openMainWindowFromPopover()
                }
            )
        )
    }

    @objc
    private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem?.button else {
            return
        }

        if popover.isShown {
            popover.performClose(sender)
            return
        }

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func openMainWindowFromPopover() {
        popover.performClose(nil)
        showMainWindow()
    }

    private func showMainWindow() {
        if mainWindow == nil {
            mainWindow = makeMainWindow()
        }

        guard let mainWindow else {
            return
        }

        NSApp.activate(ignoringOtherApps: true)
        mainWindow.makeKeyAndOrderFront(nil)
    }

    private func makeMainWindow() -> NSWindow {
        let rootView = MainMenuView(
            store: store,
            preferredWidth: 720,
            fillsWindow: true,
            showsQuitButton: false
        )
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)

        window.title = "Colleague Clock"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 760, height: 560))
        window.contentMinSize = NSSize(width: 640, height: 460)
        window.center()
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("ColleagueClockMainWindow")

        return window
    }
}

@main
struct TimeZoneMenuBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

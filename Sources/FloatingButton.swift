import Foundation
import AppKit

final class FloatingButtonController: NSObject {
    private let panel: NSPanel
    private let button: NSButton
    private let menu: NSMenu

    var onToggleSurveillance: (() -> Void)?
    private var initialDragPoint: NSPoint = .zero
    private var didDrag = false

    init(menu: NSMenu) {
        self.menu = menu

        let savedX = UserDefaults.standard.object(forKey: "macwatch.pillX") as? Double
        let savedY = UserDefaults.standard.object(forKey: "macwatch.pillY") as? Double
        let screenFrame = (NSScreen.screens.first ?? NSScreen.main)?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let defaultX = min(max(CGFloat(savedX ?? Double(screenFrame.maxX - 125)), screenFrame.minX), screenFrame.maxX - 108)
        let defaultY = min(max(CGFloat(savedY ?? Double(screenFrame.maxY - 46)), screenFrame.minY), screenFrame.maxY - 30)

        panel = NSPanel(
            contentRect: NSRect(x: defaultX, y: defaultY, width: 108, height: 30),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.title = "NyxWatch"
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true

        button = NSButton(frame: NSRect(x: 0, y: 0, width: 108, height: 30))
        button.bezelStyle = .rounded
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.cornerRadius = 14
        button.layer?.borderWidth = 1
        button.font = NSFont.systemFont(ofSize: 11.5, weight: .semibold)
        button.contentTintColor = .white
        button.image = NyxWatchBrandIcon.image(size: 18)
        button.imagePosition = .imageLeading
        button.imageHugsTitle = true

        super.init()

        let contentView = DraggablePillView(frame: NSRect(x: 0, y: 0, width: 102, height: 28))
        contentView.wantsLayer = true
        contentView.onLeftClick = { [weak self] in
            self?.onToggleSurveillance?()
        }
        contentView.onRightClick = { [weak self] event in
            guard let self, let view = self.panel.contentView else { return }
            NSMenu.popUpContextMenu(self.menu, with: event, for: view)
        }
        contentView.onMoved = { [weak self] in
            guard let self else { return }
            UserDefaults.standard.set(Double(self.panel.frame.origin.x), forKey: "macwatch.pillX")
            UserDefaults.standard.set(Double(self.panel.frame.origin.y), forKey: "macwatch.pillY")
        }

        contentView.addSubview(button)
        panel.contentView = contentView
        updateState(.off)
        panel.orderFrontRegardless()
    }

    func updateState(_ state: SurveillanceVisualState) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch state {
            case .off:
                self.button.title = " OFF"
                self.button.layer?.backgroundColor = NSColor(white: 0.15, alpha: 0.88).cgColor
                self.button.layer?.borderColor = NSColor(white: 1.0, alpha: 0.2).cgColor
            case .waitingBluetooth:
                self.button.title = " ACTIF"
                self.button.layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.9).cgColor
                self.button.layer?.borderColor = NSColor.white.withAlphaComponent(0.35).cgColor
            case .armed:
                self.button.title = " ARMÉ"
                self.button.layer?.backgroundColor = NSColor.systemRed.withAlphaComponent(0.92).cgColor
                self.button.layer?.borderColor = NSColor.white.withAlphaComponent(0.45).cgColor
            }
        }
    }
}

private final class DraggablePillView: NSView {
    var onLeftClick: (() -> Void)?
    var onRightClick: ((NSEvent) -> Void)?
    var onMoved: (() -> Void)?

    private var dragStartScreen: NSPoint = .zero
    private var windowStartOrigin: NSPoint = .zero
    private var moved = false

    override func hitTest(_ point: NSPoint) -> NSView? {
        return bounds.contains(convert(point, from: superview)) ? self : nil
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        dragStartScreen = NSEvent.mouseLocation
        windowStartOrigin = window.frame.origin
        moved = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }
        let current = NSEvent.mouseLocation
        let dx = current.x - dragStartScreen.x
        let dy = current.y - dragStartScreen.y
        if abs(dx) > 3 || abs(dy) > 3 {
            moved = true
        }
        window.setFrameOrigin(NSPoint(x: windowStartOrigin.x + dx, y: windowStartOrigin.y + dy))
    }

    override func mouseUp(with event: NSEvent) {
        if moved {
            onMoved?()
        } else {
            onLeftClick?()
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        onRightClick?(event)
    }
}

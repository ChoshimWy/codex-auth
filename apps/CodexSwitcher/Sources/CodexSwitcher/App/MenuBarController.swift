import AppKit
import SwiftUI

@MainActor
final class MenuBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(
        withLength: NSStatusItem.variableLength
    )

    private let popover = NSPopover()
    private let store: MenuBarStore

    // MARK: - Init

    init(store: MenuBarStore) {
        self.store = store
        super.init()
        configureStatusItem()
        configurePopover()
        observeStore()
    }

    // MARK: - Status Item

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }

        button.target = self
        button.action = #selector(togglePopover)
        button.imagePosition = .imageLeading

        // Icon — set once, native NSStatusBarButton rendering (no distortion)
        button.image = NSImage(
            systemSymbolName: "diamond",
            accessibilityDescription: "Codex"
        )?.withSymbolConfiguration(
            NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        )
        button.image?.isTemplate = true

        button.attributedTitle = statusText(L10n.statusLoading, color: .secondaryLabelColor)
    }

    /// Updates the status bar text. Called automatically when store data changes.
    /// Icon spacing is controlled by a leading thin space in the attributed string.
    private func updateStatusItem() {
        guard let button = statusItem.button else { return }

        if let active = store.activeAccount,
           let usage = active.primaryUsage {
            let pct = Int(usage.remainingPercent)
            let state = QuotaStyle.state(remainingPercent: usage.remainingPercent)
            let nsColor = QuotaStyle.tint(for: state).toNSColor ?? .labelColor

            button.attributedTitle = statusText(
                "\(active.alias) · \(pct)%",
                color: nsColor
            )
        } else if store.isRefreshing {
            button.attributedTitle = statusText(L10n.statusRefreshing, color: .secondaryLabelColor)
        } else if store.errorMessage != nil {
            button.attributedTitle = statusText(L10n.statusError, color: .systemRed)
        } else {
            button.attributedTitle = statusText(L10n.statusDefault, color: .labelColor)
        }
    }

    /// Builds an attributed string with a leading space for icon–text spacing.
    /// Two thin spaces (`\u{2009}`) ≈ 6pt gap with a 12pt system font.
    private func statusText(_ string: String, color: NSColor) -> NSAttributedString {
        NSAttributedString(
            string: "\u{2009}\u{2009}\(string)",
            attributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: color,
            ]
        )
    }

    // MARK: - Store Observation

    /// Swift `@Observable` tracking — updates the status bar
    /// whenever account data or refresh state changes.
    private func observeStore() {
        withObservationTracking {
            _ = store.accounts
            _ = store.activeAccount
            _ = store.isRefreshing
            _ = store.lastSyncTime
            _ = store.errorMessage
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.updateStatusItem()
                self?.observeStore()   // re-subscribe
            }
        }
    }

    // MARK: - Popover

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true

        let hosting = NSHostingController(
            rootView: MenuBarPopoverView(store: store)
        )
        hosting.sizingOptions = .preferredContentSize
        popover.contentViewController = hosting
    }

    @objc
    private func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            Task { await store.refresh() }
            popover.show(
                relativeTo: button.bounds,
                of: button,
                preferredEdge: .minY
            )
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}

// MARK: - SwiftUI Color → NSColor Bridge

private extension Color {
    var toNSColor: NSColor? { NSColor(self) }
}

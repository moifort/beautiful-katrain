import Foundation

/// Decides when the "AI is thinking" indicator is actually on screen.
///
/// KataGo often answers in a couple of hundred milliseconds. Showing a spinner for
/// that long, then hiding it, reads as a glitch — so the indicator waits before
/// appearing, and once it has appeared it stays for a moment even if the answer has
/// already arrived. Both delays belong to the interface: the bridge reports thinking
/// state raw, with no smoothing of its own.
@MainActor
@Observable
public final class ThinkingIndicator {
    public private(set) var isVisible = false

    public var appearAfter: Duration = .milliseconds(400)
    public var minimumVisible: Duration = .milliseconds(300)

    private var appearTask: Task<Void, Never>?
    private var hideTask: Task<Void, Never>?
    private var shownAt: ContinuousClock.Instant?

    public init() {}

    public func began() {
        hideTask?.cancel()
        hideTask = nil
        guard !isVisible, appearTask == nil else { return }
        appearTask = Task { [appearAfter] in
            try? await Task.sleep(for: appearAfter)
            guard !Task.isCancelled else { return }
            self.isVisible = true
            self.shownAt = .now
            self.appearTask = nil
        }
    }

    public func ended() {
        appearTask?.cancel()
        appearTask = nil
        guard isVisible, let shownAt else {
            isVisible = false
            return
        }
        let elapsed = ContinuousClock.now - shownAt
        guard elapsed < minimumVisible else {
            hide()
            return
        }
        hideTask = Task { [remaining = minimumVisible - elapsed] in
            try? await Task.sleep(for: remaining)
            guard !Task.isCancelled else { return }
            self.hide()
        }
    }

    private func hide() {
        isVisible = false
        shownAt = nil
        hideTask = nil
    }
}

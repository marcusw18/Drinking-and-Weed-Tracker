import Foundation

/// Fires a callback every `interval` seconds while a drinking session is active.
@Observable
final class AutoAnalysisTimer {

    private(set) var isRunning = false
    private var timer: Timer?
    var onFire: (() -> Void)?

    let interval: TimeInterval

    init(interval: TimeInterval = 15 * 60) {  // default: 15 minutes
        self.interval = interval
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        scheduleTimer()
    }

    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    private func scheduleTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.onFire?()
        }
    }
}

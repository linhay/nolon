import Foundation
import Observation

@MainActor
protocol CopyToastPresenting: AnyObject {
    var isShowingCopyToast: Bool { get set }
    var copyToastMessage: String { get set }
    var copyToastTask: Task<Void, Never>? { get set }
}

enum CopyToastSupport {
    static let message = NSLocalizedString("remote.error.copied", value: "Copied", comment: "Copied tooltip")
    static let dismissDelayNanoseconds: UInt64 = 1_200_000_000
}

extension CopyToastPresenting {
    func showCopyToast() {
        copyToastTask?.cancel()
        copyToastMessage = CopyToastSupport.message
        isShowingCopyToast = true
        copyToastTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: CopyToastSupport.dismissDelayNanoseconds)
            guard let self else { return }
            self.isShowingCopyToast = false
        }
    }
}

import SwiftUI

@main
struct MoshiDopaApp: App {
    @State private var showingPiP = false
    @State private var restoreCompletion: ((Bool) -> Void)?

    var body: some Scene {
        WindowGroup {
            MoshiDopaRootView(onOpenPiP: { showingPiP = true })
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    PiPDiagnosticsModel.shared.applicationEnteredBackground()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    PiPDiagnosticsModel.shared.applicationWillEnterForeground()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.protectedDataWillBecomeUnavailableNotification)) { _ in
                    PiPDiagnosticsModel.shared.deviceProtectedDataUnavailable()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.protectedDataDidBecomeAvailableNotification)) { _ in
                    PiPDiagnosticsModel.shared.deviceProtectedDataAvailable()
                }
                .onOpenURL { url in
                    if url.scheme == "moshidopa", url.host == "counter" { showingPiP = true }
                }
                .sheet(isPresented: $showingPiP) {
                    PiPDiagnosticsView()
                        .presentationDragIndicator(.visible)
                        .onAppear {
                            restoreCompletion?(true)
                            restoreCompletion = nil
                        }
                }
                .onReceive(NotificationCenter.default.publisher(for: Notification.Name("MoshiDopaRestorePiP"))) { notification in
                    let completion = notification.userInfo?["completion"] as? (Bool) -> Void
                    if showingPiP { completion?(true) }
                    else {
                        restoreCompletion = completion
                        showingPiP = true
                    }
                }
        }
    }
}

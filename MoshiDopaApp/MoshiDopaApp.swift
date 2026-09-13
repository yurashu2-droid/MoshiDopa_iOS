import SwiftUI

@main
struct MoshiDopaApp: App {
    @State private var showingPiP = false
    @State private var restoreCompletion: ((Bool) -> Void)?

    var body: some Scene {
        WindowGroup {
            MoshiDopaRootView(onOpenPiP: { showingPiP = true })
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

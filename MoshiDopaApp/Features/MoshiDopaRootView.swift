import Foundation
import SwiftUI

/// Native SwiftUI host for the P2A fixture-driven UI. The fixture is held in memory only;
/// no sample activity is sent to the session repository.
struct MoshiDopaRootView: View {
    private let onOpenPiP: () -> Void
    @State private var route: MDRoute
    @State private var measurementMode: MDMode = .spend
    @State private var historyPeriod: MDPeriod = .day
    @State private var historyMode: MDMode = .spend
    @State private var historyAnchorDay = 13
    @State private var selectedReceiptID: UUID?
    @State private var data: MDFixtureData

    init(onOpenPiP: @escaping () -> Void = {}) {
        let launch = MDLaunchConfiguration()
        self.onOpenPiP = onOpenPiP
        _route = State(initialValue: launch.route)
        _data = State(initialValue: MDFixtureData.make(launch.fixture))
    }

    var body: some View {
        routeView
            .preferredColorScheme(.light)
            .tint(MoshiDopaBrand.limeInk)
    }

    @ViewBuilder
    private var routeView: some View {
        switch route {
        case .home:
            MDHomeView(data: $data, navigate: navigate, start: start)
        case .measurement:
            MDMeasurementView(data: $data, mode: $measurementMode, navigate: navigate,
                              goBack: { route = .home }, onOpenPiP: onOpenPiP)
        case .history:
            MDHistoryView(data: $data, period: $historyPeriod, mode: $historyMode, anchorDay: $historyAnchorDay,
                          navigate: navigate, openReceipt: openReceipt, goBack: { route = .home })
        case .settings:
            MDSettingsView(data: $data, navigate: navigate, goBack: { route = .home }, onOpenPiP: onOpenPiP)
        case .counter:
            MDCounterView(data: $data, navigate: navigate, goBack: { route = .settings }, onOpenPiP: onOpenPiP)
        case .receipt:
            MDReceiptView(data: data, goBack: { route = .history }, initialID: selectedReceiptID)
        case .statement:
            MDStatementView(data: data, goBack: { route = .history })
        case .onboarding:
            MDOnboardingView(goBack: { route = .home }, finish: { route = .home })
        case .whatif:
            MDWhatIfView(data: data, goBack: { route = .home })
        }
    }

    private func navigate(_ target: MDRoute) {
        withAnimation(.easeInOut(duration: 0.22)) { route = target }
    }

    private func start(_ mode: MDMode) {
        measurementMode = mode
        navigate(.measurement)
    }

    private func openReceipt(_ id: UUID?) {
        selectedReceiptID = id
        route = .receipt
    }
}

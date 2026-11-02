import SwiftUI
import UIKit
import Combine

struct ContentView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var patchDraftCoordinator: PatchDraftCoordinator
    @EnvironmentObject private var patchStore: PatchProjectStore
    @EnvironmentObject private var repositoryStore: PackageRepositoryStore
    @AppStorage(FeatureVisibility.developerModeStorageKey)
    private var developerModeEnabled = false
    @State private var tabNavigation: AppTabNavigationState
    @State private var showSettings = false
    @State private var showLogs = false

    init() {
#if targetEnvironment(simulator)
        let arguments = ProcessInfo.processInfo.arguments
        let initialTab: Int
        if arguments.contains("--simulate-new-tab") {
            initialTab = 1
        } else if arguments.contains("--simulate-sources-tab") {
            initialTab = 2
        } else if arguments.contains("--simulate-installed-tab")
                    || arguments.contains("--simulate-patch-tab")
                    || arguments.contains("--simulate-wallpaper-tab") {
            initialTab = 3
        } else if arguments.contains("--simulate-files-tab") {
            initialTab = 4
        } else if arguments.contains("--simulate-search-tab") {
            initialTab = 5
        } else {
            initialTab = AppSection.installed.rawValue
        }
        _tabNavigation = State(initialValue: AppTabNavigationState(selectedTab: initialTab))
        _showSettings = State(
            initialValue: arguments.contains("--simulate-settings")
        )
#else
        _tabNavigation = State(initialValue: AppTabNavigationState())
#endif
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            StarfieldBackground().ignoresSafeArea()
            Group {
                if horizontalSizeClass == .regular {
                    regularLayout
                } else {
                    compactLayout
                }
            }
        }
        .tint(AppTheme.accent)
        .imageScale(.small)
        .onChange(of: patchDraftCoordinator.request?.id) { requestID in
            if requestID != nil {
                tabNavigation.select(AppSection.installed.rawValue)
            }
        }
        .onChange(of: patchDraftCoordinator.importRequest?.id) { requestID in
            if requestID != nil {
                tabNavigation.select(AppSection.installed.rawValue)
            }
        }
        .onChange(of: developerModeEnabled) { _ in
            tabNavigation.reconcileSelection(with: featureVisibility)
        }
        .onAppear {
            tabNavigation.reconcileSelection(with: featureVisibility)
            AppMediaController.shared.startFunctionAudio()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showLogs) {
            LogView()
        }
        // .patchStorePresentation(patchStore)
        .repositoryStorePresentation(repositoryStore, patchStore: patchStore)
    }

    private var compactLayout: some View {
        ZStack(alignment: .bottom) {
            sectionContent(selectedVisibleSection)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(edges: .bottom)

            HStack(spacing: 0) {
                compactBottomButton(.installed)
                compactBottomButton(.home)
            }
            .padding(3)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(Color(red: 0.015, green: 0.025, blue: 0.055))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
            .padding(.horizontal, 52)
            .padding(.bottom, 6)
            .zIndex(10)
        }
        .background(Color.black.ignoresSafeArea())
    }

    private func compactBottomButton(_ section: AppSection) -> some View {
        Button {
            tabNavigation.select(section.rawValue)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: section.systemImage)
                    .font(.system(size: 17, weight: .medium))

                Text(section == .installed ? "Function" : "Account")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(
                section.rawValue == tabNavigation.selectedTab
                    ? Color.white
                    : Color(red: 0.64, green: 0.69, blue: 0.82)
            )
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                section.rawValue == tabNavigation.selectedTab
                    ? Color(red: 0.15, green: 0.52, blue: 0.95)
                    : Color.clear,
                in: Capsule()
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(
            section.rawValue == tabNavigation.selectedTab ? .isSelected : []
        )
    }

    private var regularLayout: some View {
        NavigationSplitView {
            List {
                ForEach([AppSection.installed, .home]) { section in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            tabNavigation.select(section.rawValue)
                        }
                    } label: {
                        Label(
                            language.text(section.titleKey),
                            systemImage: section.systemImage
                        )
                        .fontWeight(
                            section.rawValue == tabNavigation.selectedTab
                                ? .semibold
                                : .regular
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(
                        section.rawValue == tabNavigation.selectedTab
                            ? AppTheme.accent.opacity(0.14)
                            : Color.clear
                    )
                    .accessibilityAddTraits(
                        section.rawValue == tabNavigation.selectedTab
                            ? .isSelected
                            : []
                    )
                }
            }
            .navigationTitle("BEST EXTERNAL")
            .navigationSplitViewColumnWidth(
                min: 210,
                ideal: 240,
                max: 300
            )
        } detail: {
            sectionContent(selectedVisibleSection)
                .id(selectedVisibleSection.rawValue)
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private func sectionContent(_ section: AppSection) -> some View {
        switch section {
        case .home:
            MisbahHomeView(onOpenSettings: openSettings)

        case .new:
            RepositoryNewView(
                onOpenSettings: openSettings,
                onOpenLogs: openLogs
            )

        case .sources:
            RepositorySourcesView(
                onOpenSettings: openSettings,
                onOpenLogs: openLogs
            )

        case .installed:
            PatchProjectsView(
                onOpenSettings: openSettings,
                onOpenLogs: openLogs
            )

        case .files:
            AppDataBrowserView(
                tabSession: filesTabSession,
                onOpenSettings: openSettings,
                onOpenLogs: openLogs
            )

        case .search:
            RepositorySearchView(
                onOpenSettings: openSettings,
                onOpenLogs: openLogs
            )
        }
    }

    private var tabSelection: Binding<Int> {
        Binding(
            get: { tabNavigation.selectedTab },
            set: { tabNavigation.select($0) }
        )
    }

    private var filesTabSession: Binding<FilesTabSession> {
        Binding(
            get: { tabNavigation.filesTabs },
            set: { tabNavigation.setFilesTabs($0) }
        )
    }

    private var featureVisibility: FeatureVisibility {
        FeatureVisibility(developerModeEnabled: developerModeActive)
    }

    private var developerModeActive: Bool {
#if targetEnvironment(simulator)
        developerModeEnabled
            || ProcessInfo.processInfo.arguments.contains("--simulate-developer-mode")
            || ProcessInfo.processInfo.arguments.contains("--simulate-files-tab")
#else
        developerModeEnabled
#endif
    }

    private var selectedVisibleSection: AppSection {
        let selected = AppSection(rawValue: tabNavigation.selectedTab)
        return selected.flatMap {
            ([AppSection.home, .installed].contains($0)) ? $0 : nil
        } ?? .installed
    }

    private func openSettings() {
        showSettings = true
    }

    private func openLogs() {
        showLogs = true
    }
}

/// Full-screen falling star field: small points only, no streaks or connecting lines.
struct StarfieldBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            Canvas { context, size in
                let elapsed = timeline.date.timeIntervalSinceReferenceDate
                for index in 0..<105 {
                    let seed = Double(index)
                    let x = (sin(seed * 12.9898) * 0.5 + 0.5) * size.width
                    let baseY = (cos(seed * 7.233) * 0.5 + 0.5) * size.height
                    let speed = 14.0 + (seed.truncatingRemainder(dividingBy: 7.0) * 7.0)
                    let y = (baseY + (reduceMotion ? 0 : elapsed * speed).truncatingRemainder(dividingBy: max(size.height, 1))) .truncatingRemainder(dividingBy: max(size.height, 1))
                    let diameter = index.isMultiple(of: 11) ? 2.2 : 1.25
                    let rect = CGRect(x: x, y: y, width: diameter, height: diameter)
                    context.opacity = index.isMultiple(of: 5) ? 0.85 : 0.48
                    context.fill(Path(ellipseIn: rect), with: .color(.white))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct CompactTabLabel: View {
    let title: String
    let systemImage: String

    @ViewBuilder
    var body: some View {
        if let image = UIImage(
            systemName: systemImage,
            withConfiguration: UIImage.SymbolConfiguration(
                pointSize: 17,
                weight: .medium
            )
        )?.withRenderingMode(.alwaysTemplate) {
            Image(uiImage: image)
        } else {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .medium))
        }

        Text(title)
    }
}

private extension AppSection {
    var titleKey: String {
        switch self {
        case .home: return "tab.account"
        case .new: return "tab.new"
        case .sources: return "tab.sources"
        case .installed: return "tab.functions"
        case .files: return "tab.files"
        case .search: return "tab.search"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "person.crop.circle.fill"
        case .new: return "clock.fill"
        case .sources: return "shippingbox.fill"
        case .installed: return "square.grid.2x2.fill"
        case .files: return "folder.fill"
        case .search: return "magnifyingglass"
        }
    }
}


// MARK: - ROBO INDIA account dashboard

struct MisbahHomeView: View {
    @EnvironmentObject private var license: MisbahLicenseManager
    @EnvironmentObject private var appState: AppState

    let onOpenSettings: () -> Void

    private let officialChannel = URL(string: "https://whatsapp.com/channel/0029VbE0r70HAdNWmaH1nK1h")!

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 3) {
                        Text("BEST EXTERNAL")
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color(red: 0.66, green: 0.48, blue: 0.88))

                        Text("Developer Shafay")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.82))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(.white)

                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            let remaining = max(
                                0,
                                (license.expiresAt ?? context.date)
                                    .timeIntervalSince(context.date)
                            )

                            Text(Self.formatDuration(remaining))
                                .font(
                                    .system(
                                        size: 34,
                                        weight: .bold,
                                        design: .rounded
                                    )
                                    .monospacedDigit()
                                )
                                .foregroundStyle(.white)
                        }

                        Text("KEY LINK ACTIVE")
                            .font(.system(size: 12, weight: .bold))
                            .tracking(1.1)
                            .foregroundStyle(.white.opacity(0.75))

                        Text("Linked to This Device")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial, in: Capsule())
                            .overlay(Capsule().stroke(Color.gray.opacity(0.55), lineWidth: 1))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 0.24, green: 0.14, blue: 0.38).opacity(0.34),
                                Color.white.opacity(0.07)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 22)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(Color.gray.opacity(0.55), lineWidth: 1)
                    )

                    VStack(alignment: .leading, spacing: 0) {
                        Text("Version & Update")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color(red: 0.62, green: 0.42, blue: 0.84))
                            .padding(.bottom, 8)

                        deviceRow("Version", value: "V1.0")
                        deviceRow("Update System", value: "Required Update", last: true)
                    }
                    .padding(16)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 0.24, green: 0.14, blue: 0.38).opacity(0.28),
                                Color.white.opacity(0.07)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 20)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.gray.opacity(0.55), lineWidth: 1)
                    )

                    VStack(alignment: .leading, spacing: 0) {
                        Text("Device Information")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color(red: 0.62, green: 0.42, blue: 0.84))
                            .padding(.bottom, 8)

                        deviceRow(
                            "Device Name",
                            value: UIDevice.current.name
                        )

                        deviceRow(
                            "Device Model",
                            value: AppInfo.machineName
                        )

                        deviceRow(
                            "iOS Version",
                            value: UIDevice.current.systemVersion
                        )

                        deviceRow(
                            "Source",
                            value: "BEST EXTERNAL"
                        )

                        deviceRow(
                            "Supported",
                            value: appState.isSupported ? "Yes" : "Not supported",
                            good: appState.isSupported,
                            last: true
                        )
                    }
                    .padding(16)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 0.24, green: 0.14, blue: 0.38).opacity(0.28),
                                Color.white.opacity(0.07)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 20)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.gray.opacity(0.55), lineWidth: 1)
                    )

                    VStack(spacing: 10) {
                        Text("BEST OFFICIAL")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color(red: 0.62, green: 0.42, blue: 0.84))

                        Link(destination: officialChannel) {
                            Label(
                                "BEST OFFICIAL — WhatsApp Channel",
                                systemImage: "message.fill"
                            )
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(
                                maxWidth: .infinity,
                                alignment: .leading
                            )
                            .padding(14)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.24, green: 0.14, blue: 0.38).opacity(0.30),
                                        Color.white.opacity(0.08)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                in: RoundedRectangle(cornerRadius: 14)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.gray.opacity(0.55), lineWidth: 1)
                            )
                        }

                        Button {
                            license.signOut()
                        } label: {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(13)
                                .background(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.24, green: 0.14, blue: 0.38).opacity(0.30),
                                        Color.white.opacity(0.08)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                in: RoundedRectangle(cornerRadius: 14)
                            )
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.gray.opacity(0.55), lineWidth: 1))
                        }
                    }
                }
                .padding(16)
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .background(Color.clear)
        .preferredColorScheme(ColorScheme.dark)
        .onReceive(
            Timer.publish(
                every: 1,
                on: .main,
                in: .common
            ).autoconnect()
        ) { _ in
            license.checkExpiry()
        }
    }

    private func deviceRow(
        _ title: String,
        value: String,
        good: Bool = false,
        last: Bool = false
    ) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.72))

                Spacer(minLength: 12)

                Text(value)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(
                        title == "Supported"
                            ? (good ? Color.green : Color.red)
                            : .white
                    )
                    .multilineTextAlignment(.trailing)
            }
            .padding(.vertical, 11)

            if !last {
                Divider()
                    .overlay(Color.white.opacity(0.12))
            }
        }
    }

    private static func formatDuration(
        _ interval: TimeInterval
    ) -> String {
        let seconds = max(0, Int(interval))
        let days = seconds / 86400
        let hours = (seconds % 86400) / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60

        return days > 0
            ? String(
                format: "%02d:%02d:%02d:%02d",
                days,
                hours,
                minutes,
                secs
            )
            : String(
                format: "%02d:%02d:%02d",
                hours,
                minutes,
                secs
            )
    }
}


// MARK: - ROBO INDIA license authorization

@MainActor
final class MisbahLicenseManager: ObservableObject {
    @Published private(set) var isAuthorized = false
    @Published private(set) var expiresAt: Date?
    @Published private(set) var isVerifying = false
    @Published var message: String?
    @Published var lastStatus: String?

    private let endpoint = URL(
        string: "https://shafaykeyauthadmin.lovable.app/api/public/v1/verify-license"
    )!

    private let savedKeyKey = "misbah.license.key"
    private let savedExpiryKey = "misbah.license.expires_at"
    private let deviceIDKey = "misbah.license.device_id"

    init() {
        if let savedKey = UserDefaults.standard.string(forKey: savedKeyKey),
           !savedKey.isEmpty {
            Task {
                await verify(key: savedKey, showErrors: false)
            }
        }
    }

    var deviceID: String {
        if let existing = UserDefaults.standard.string(forKey: deviceIDKey) {
            return existing
        }

        let value = UIDevice.current.identifierForVendor?.uuidString
            ?? UUID().uuidString

        UserDefaults.standard.set(value, forKey: deviceIDKey)
        return value
    }

    func activate(key: String) async {
        await verify(
            key: key.trimmingCharacters(in: .whitespacesAndNewlines),
            showErrors: true
        )
    }

    func reverifySavedLicense() async {
        guard let key = UserDefaults.standard.string(forKey: savedKeyKey),
              !key.isEmpty else {
            isAuthorized = false
            return
        }

        await verify(key: key, showErrors: false)
    }

    func checkExpiry() {
        guard let expiresAt, expiresAt <= Date() else {
            return
        }

        isAuthorized = false
        self.expiresAt = nil

        UserDefaults.standard.removeObject(forKey: savedKeyKey)
        UserDefaults.standard.removeObject(forKey: savedExpiryKey)

        message = "This license key has expired."
    }

    func signOut() {
        isAuthorized = false
        expiresAt = nil
        message = nil
        lastStatus = nil
        UserDefaults.standard.removeObject(forKey: savedKeyKey)
        UserDefaults.standard.removeObject(forKey: savedExpiryKey)
    }

    private func verify(
        key: String,
        showErrors: Bool
    ) async {
        guard !key.isEmpty else {
            message = showErrors ? "Enter your license key first." : nil
            isAuthorized = false
            return
        }

        isVerifying = true
        defer {
            isVerifying = false
        }

        do {
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.setValue(
                "application/json",
                forHTTPHeaderField: "Content-Type"
            )
            request.timeoutInterval = 20

            request.httpBody = try JSONSerialization.data(
                withJSONObject: [
                    "key": key,
                    "device_id": deviceID
                ]
            )

            let (data, response) = try await URLSession.shared.data(
                for: request
            )

            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

            let payload = (
                try? JSONSerialization.jsonObject(with: data)
            ) as? [String: Any] ?? [:]

            let valid = payload["valid"] as? Bool == true
                && payload["success"] as? Bool == true

            let status = (
                payload["status"] as? String ?? "unknown"
            ).lowercased()

            guard (200..<300).contains(statusCode),
                  valid,
                  status == "active",
                  let expiryString = payload["expires_at"] as? String,
                  let expiry = Self.parseDate(expiryString),
                  expiry > Date() else {

                isAuthorized = false
                expiresAt = nil

                UserDefaults.standard.removeObject(forKey: savedKeyKey)
                UserDefaults.standard.removeObject(forKey: savedExpiryKey)

                let code = payload["code"] as? String

                switch code ?? status {
                case "not_found", "invalid":
                    message = "This license key is invalid."

                case "device_limit":
                    message = "This key has reached its device limit."

                case "expired":
                    message = "This license key has expired."

                default:
                    message = showErrors
                        ? (
                            payload["message"] as? String
                                ?? "License verification failed. Please try again."
                        )
                        : nil
                }

                lastStatus = status
                return
            }

            UserDefaults.standard.set(key, forKey: savedKeyKey)
            UserDefaults.standard.set(
                expiry.timeIntervalSince1970,
                forKey: savedExpiryKey
            )

            expiresAt = expiry
            isAuthorized = true
            message = nil
            lastStatus = "active"

        } catch {
            isAuthorized = false

            message = showErrors
                ? "Could not contact the license server. Check your internet and try again."
                : nil
        }
    }

    private static func parseDate(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]

        if let date = fractional.date(from: value) {
            return date
        }

        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]

        return standard.date(from: value)
    }
}


struct MisbahAuthorizationView: View {
    @EnvironmentObject private var license: MisbahLicenseManager
    @State private var keyText = ""

    private let officialChannel = URL(string: "https://whatsapp.com/channel/0029VbE0r70HAdNWmaH1nK1h")!

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            AppAuthorizationVideoBackground()

            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 190)

                    Text("BEST EXTERNAL")
                        .foregroundStyle(Color(red: 0.68, green: 0.49, blue: 0.90))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)

                    Text("EXTERNAL SUPPORTS FREE FIRE PATCHES")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.1)
                        .foregroundStyle(.white.opacity(0.88))

                    VStack(alignment: .leading, spacing: 12) {
                        Text("LICENSE KEY")
                            .font(.system(size: 14, weight: .medium))
                            .tracking(2.2)
                            .foregroundStyle(Color(red: 0.55, green: 0.59, blue: 0.70))

                        HStack(spacing: 12) {
                            Image(systemName: "key.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(Color(red: 0.48, green: 0.53, blue: 0.65))

                            TextField("Enter license key", text: $keyText)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(.white)
                                .tint(.white)
                                .accessibilityLabel("License key")
                        }
                        .padding(.horizontal, 18)
                        .frame(height: 58)
                        .background(
                            Color(red: 0.055, green: 0.055, blue: 0.065),
                            in: Capsule()
                        )

                        Button {
                            Task {
                                await license.activate(key: keyText)
                            }
                        } label: {
                            HStack(spacing: 10) {
                                if license.isVerifying {
                                    ProgressView().tint(.white)
                                }
                                Image(systemName: "key.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                Text(license.isVerifying ? "Verifying..." : "Activate")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                            .foregroundStyle(.white.opacity(
                                keyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1
                            ))
                            .frame(maxWidth: .infinity)
                            .frame(height: 58)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.28, green: 0.16, blue: 0.46),
                                        Color(red: 0.18, green: 0.10, blue: 0.34)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                in: Capsule()
                            )
                        }
                        .disabled(
                            license.isVerifying
                                || keyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        )

                        if let message = license.message {
                            Text(message)
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(.red)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.horizontal, 42)

                    Link(destination: officialChannel) {
                        HStack(spacing: 10) {
                            Image(systemName: "message.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color(red: 0.62, green: 0.42, blue: 0.84))
                            Text("BEST OFFICIAL")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .padding(.horizontal, 18)
                        .frame(height: 46)
                        .background(Color.white.opacity(0.04), in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1))
                    }
                    .padding(.horizontal, 54)

                    Spacer(minLength: 80)
                }
                .frame(maxWidth: .infinity, minHeight: UIScreen.main.bounds.height)
            }
        }
        .onAppear { AppMediaController.shared.startFunctionAudio() }
    }
}

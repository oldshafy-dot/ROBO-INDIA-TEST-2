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
        .tint(.white)
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
        TabView(selection: tabSelection) {
            ForEach([AppSection.installed, .home]) { section in
                sectionContent(section)
                    .background(Color.clear)
                    .tabItem {
                        CompactTabLabel(
                            title: language.text(section.titleKey),
                            systemImage: section.systemImage
                        )
                    }
                    .tag(section.rawValue)
            }
        }
        .background(Color.clear)
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
            .navigationTitle("ROBO INDIA")
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
private struct StarfieldBackground: View {
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

    private let whatsappGroup = URL(
        string: "https://chat.whatsapp.com/GYAkNlKXIqB4i2FxOuLxQW?s=cl&p=i&mlu=4&ilr=4&iam=2"
    )!

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 3) {
                        (Text("ROBO ").foregroundColor(.white)
                            + Text("INDIA").foregroundColor(Color(red: 0.20, green: 0.68, blue: 1.0)))
                            .font(.system(size: 28, weight: .heavy, design: .rounded))

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
                            .overlay(Capsule().stroke(Color.gray.opacity(0.60), lineWidth: 1))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(Color.gray.opacity(0.60), lineWidth: 1)
                    )

                    VStack(alignment: .leading, spacing: 0) {
                        Text("Version & Update")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.bottom, 8)

                        deviceRow("Version", value: "V1.0")
                        deviceRow("Update System", value: "Required Update", last: true)
                    }
                    .padding(16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.gray.opacity(0.55), lineWidth: 1)
                    )

                    VStack(alignment: .leading, spacing: 0) {
                        Text("Device Information")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
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
                            value: "ROBO INDIA"
                        )

                        deviceRow(
                            "Supported",
                            value: appState.isSupported ? "Yes" : "Not supported",
                            good: appState.isSupported,
                            last: true
                        )
                    }
                    .padding(16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.gray.opacity(0.55), lineWidth: 1)
                    )

                    VStack(spacing: 10) {
                        Text("Our Official Channel")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)

                        Link(destination: whatsappGroup) {
                            Label(
                                "Join our WhatsApp group",
                                systemImage: "message.circle.fill"
                            )
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(
                                maxWidth: .infinity,
                                alignment: .leading
                            )
                            .padding(14)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
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
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.gray.opacity(0.60), lineWidth: 1))
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

    private let whatsappGroup = URL(
        string: "https://chat.whatsapp.com/GYAkNlKXIqB4i2FxOuLxQW?s=cl&p=i&mlu=4&ilr=4&iam=2"
    )!

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            StarfieldBackground().ignoresSafeArea()
            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 5) {
                        (Text("ROBO ").foregroundColor(.white)
                            + Text("INDIA").foregroundColor(Color(red: 0.20, green: 0.68, blue: 1.0)))
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)

                        Text("Developer Shafay")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.82))
                    }
                    .padding(.top, 4)

                    VStack(alignment: .leading, spacing: 16) {
                        Label(
                            "Key Authorization",
                            systemImage: "key.horizontal"
                        )
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(.white)

                        HStack(spacing: 10) {
                            TextField(
                                "Enter or paste your key",
                                text: $keyText
                            )
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .font(.system(size: 15))
                            .foregroundStyle(.white)
                            .tint(.white)
                            .accessibilityLabel("License key")

                            Button {
                                if let pasted = UIPasteboard.general.string {
                                    keyText = pasted.trimmingCharacters(
                                        in: .whitespacesAndNewlines
                                    )
                                }
                            } label: {
                                Label(
                                    "Paste",
                                    systemImage: "doc.on.clipboard"
                                )
                                .font(.system(size: 14, weight: .bold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 11))
                                .overlay(RoundedRectangle(cornerRadius: 11).stroke(Color.gray.opacity(0.60), lineWidth: 1))
                                .foregroundStyle(.white)
                            }
                        }
                        .padding(12)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(Color.gray.opacity(0.60), lineWidth: 1)
                        )

                        Button {
                            Task {
                                await license.activate(key: keyText)
                            }
                        } label: {
                            HStack(spacing: 9) {
                                if license.isVerifying {
                                    ProgressView()
                                        .tint(.white)
                                }

                                Text(
                                    license.isVerifying
                                        ? "Verifying..."
                                        : "Activate Key"
                                )
                                .font(.system(size: 17, weight: .bold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.gray.opacity(0.70), lineWidth: 1))
                        }
                        .disabled(
                            license.isVerifying
                                || keyText.trimmingCharacters(
                                    in: .whitespacesAndNewlines
                                ).isEmpty
                        )

                        if let message = license.message {
                            Text(message)
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(.red)
                                .fixedSize(
                                    horizontal: false,
                                    vertical: true
                                )
                        }
                    }
                    .padding(18)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(Color.gray.opacity(0.55), lineWidth: 1)
                    )
                    .shadow(
                        color: Color.white.opacity(0.04),
                        radius: 15,
                        y: 6
                    )

                    VStack(spacing: 12) {
                        Text("Our Official Channel")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)

                        Link(destination: whatsappGroup) {
                            HStack(spacing: 12) {
                                Image(systemName: "message.circle.fill")
                                    .font(.system(size: 27))
                                    .foregroundStyle(
                                        Color(
                                            red: 0.10,
                                            green: 0.65,
                                            blue: 0.38
                                        )
                                    )

                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Join our WhatsApp group")
                                        .font(
                                            .system(
                                                size: 15,
                                                weight: .semibold
                                            )
                                        )
                                        .foregroundStyle(.white)

                                    Text("Official updates and announcements")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.white.opacity(0.72))
                                }

                                Spacer()

                                Image(systemName: "arrow.up.right")
                                    .foregroundStyle(.white)
                            }
                            .padding(14)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(
                                        Color.gray.opacity(0.55),
                                        lineWidth: 1
                                    )
                            )
                        }

                    }

                    (Text("ROBO ").foregroundColor(.white)
                        + Text("INDIA").foregroundColor(Color(red: 0.20, green: 0.68, blue: 1.0))
                        + Text("  •  Secure License Access").foregroundColor(.white.opacity(0.72)))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.72))
                        .padding(.top, 2)
                }
                .padding(20)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
        }
        .background(Color.clear)
        .preferredColorScheme(ColorScheme.dark)
    }
}

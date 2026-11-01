import SwiftUI
import UIKit

@main
struct ThreeOneOSFiveApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var licenseAuth = MisbahLicenseManager()
    @StateObject private var patchDraftCoordinator = PatchDraftCoordinator()
    @StateObject private var fileOperationCoordinator = FileOperationCoordinator()
    @StateObject private var patchStore = PatchProjectStore()
    @StateObject private var repositoryStore = PackageRepositoryStore()
    @StateObject private var requiredPatchUpdate = RequiredPatchUpdateManager()
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.english.rawValue
    @State private var showOnboarding = false
    @State private var showAttribution = false
    @State private var updateOffer: AppUpdateChecker.Offer?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init() {
        setupLogCapture()
        log("app: 3105 launching — iOS \(AppInfo.osVersion) (\(AppInfo.osBuild)) \(AppInfo.machineName)")
    }

    private var language: AppLanguage {
        AppLanguage(rawValue: languageCode) ?? .english
    }

    private func checkForUpdate() {
        Task {
            guard let offer = await AppUpdateChecker.check() else { return }
            await MainActor.run { updateOffer = offer }
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if licenseAuth.isAuthorized {
                    if let requiredUpdate = requiredPatchUpdate.offer {
                        RequiredPatchUpdateView(
                            offer: requiredUpdate,
                            isInstalling: requiredPatchUpdate.isInstalling,
                            statusMessage: requiredPatchUpdate.statusMessage
                        ) {
                            requiredPatchUpdate.install(patchStore: patchStore)
                        }
                    } else {
                        ContentView()
                            .environmentObject(licenseAuth)
                            .environmentObject(appState)
                            .environmentObject(patchDraftCoordinator)
                            .environmentObject(fileOperationCoordinator)
                            .environmentObject(patchStore)
                            .environmentObject(repositoryStore)
                            .environment(\.appLanguage, language)
                            .environment(\.locale, language.locale)
                            .opacity(showOnboarding ? 0 : 1)
                            .allowsHitTesting(!showOnboarding)
                    }
                } else {
                    MisbahAuthorizationView()
                        .environmentObject(licenseAuth)
                }

                if licenseAuth.isAuthorized && showOnboarding {
                    OnboardingView {
                        OnboardingStore.markCompleted()
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.24)) {
                            showOnboarding = false
                        }
                        appState.detectSupport()
                        checkForUpdate()
                    }
                    .environment(\.appLanguage, language)
                    .environment(\.locale, language.locale)
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .opacity.combined(with: .scale(scale: 0.98))
                    )
                    .zIndex(1)
                }
            }
            .displayIdentityAttribution(isPresented: $showAttribution, enabled: !showOnboarding)
            .sheet(isPresented: $showAttribution) {
                DisplayAttributionSheet()
            }
            .alert(item: $updateOffer) { offer in
                Alert(
                    title: Text(language.text("update.title")),
                    message: Text(language.text("update.message", offer.version)),
                    primaryButton: .default(Text(language.text("update.agree"))) {
                        UIApplication.shared.open(offer.url)
                    },
                    secondaryButton: .cancel(Text(language.text("update.dismiss"))) {
                        AppUpdateChecker.dismiss(version: offer.version)
                    }
                )
            }
            .onAppear {
                if licenseAuth.isAuthorized && !showOnboarding {
                    appState.detectSupport()
                    checkForUpdate()
                    requiredPatchUpdate.refresh()
                }
            }
            .onChange(of: licenseAuth.isAuthorized) { authorized in
                guard authorized, !showOnboarding else { return }
                appState.detectSupport()
                checkForUpdate()
                requiredPatchUpdate.refresh()
            }
            .onChange(of: scenePhase) { phase in
                guard phase == .active else { return }
                Task { await licenseAuth.reverifySavedLicense() }
                guard licenseAuth.isAuthorized, !showOnboarding else { return }
                appState.detectSupport()
                requiredPatchUpdate.refresh()
            }
            .onOpenURL { url in
                patchDraftCoordinator.presentImport(url)
            }
        }
    }
}

class AppState: ObservableObject {
    @Published var exploitStatus: ExploitStatus = .notStarted
    @Published var unsupportedMessage: String?
    @Published var kernelExploitRunning = false

    private var autoRunAttempted = false

    var kernelExploitApplicable: Bool {
        KernelExploit.isApplicable(
            major: AppInfo.versionTuple.major,
            minor: AppInfo.versionTuple.minor,
            patch: AppInfo.versionTuple.patch,
            build: AppInfo.osBuild
        )
    }

    var isSupported: Bool { unsupportedMessage == nil }

    func detectSupport() {
        let v = AppInfo.versionTuple
        let supported = ExploitSupportPolicy.isSupported(
            major: v.major,
            minor: v.minor,
            patch: v.patch,
            build: AppInfo.osBuild
        )
#if targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--simulate-access") {
            exploitStatus = .success(method: "Simulator preview")
        }
#endif

        unsupportedMessage = supported ? nil : "iOS \(AppInfo.osVersion) (\(AppInfo.osBuild))"
        if let unsupportedMessage {
            exploitStatus = .unsupported(unsupportedMessage)
            return
        }

        let applicable = KernelExploit.isApplicable(
            major: v.major,
            minor: v.minor,
            patch: v.patch,
            build: AppInfo.osBuild
        )
        guard applicable else { return }

        refreshKernelExploitStatus()
        maybeAutoRunKernelExploit()
    }

    private func maybeAutoRunKernelExploit() {
        guard !kernelExploitRunning,
              !exploitStatus.isSuccess,
              !exploitStatus.isFailed,
              !autoRunAttempted else { return }
        autoRunAttempted = true
        log("app: starting kernel exploit automatically")
        runKernelExploitIfNeeded()
    }

    private func refreshKernelExploitStatus() {
        guard !kernelExploitRunning else { return }

        // iOS < 26: kernel R/W success persists (no sandbox probe)
        // iOS >= 26: verify full sandbox escape is still active
        if KernelExploit.requiresSandboxEscape {
            if KernelExploit.hasSandboxAccess() {
                if !exploitStatus.isSuccess {
                    exploitStatus = .success(method: "kexploit")
                    log("app: existing sandbox access is still active; skipping kernel exploit")
                }
            } else if exploitStatus.isSuccess {
                exploitStatus = .notStarted
                log("app: sandbox access is no longer active")
            }
        }
    }

    func runKernelExploitIfNeeded() {
        refreshKernelExploitStatus()
        guard !kernelExploitRunning,
              !exploitStatus.isSuccess,
              !exploitStatus.isFailed else { return }
        kernelExploitRunning = true
        exploitStatus = .notStarted
        log("app: running kernel exploit on background...")
        DispatchQueue.global(qos: .userInitiated).async {
            let ok = KernelExploit.run()
            DispatchQueue.main.async {
                self.kernelExploitRunning = false
                if ok {
                    self.exploitStatus = .success(method: "kexploit")
                    if KernelExploit.requiresSandboxEscape {
                        log("app: kernel exploit success — sandbox access verified")
                    } else {
                        log("app: kernel exploit success — kernel access active")
                    }
                } else {
                    self.exploitStatus = .failed(method: "kexploit", code: -1)
                    log("app: kernel exploit failed — relaunch the app before retrying")
                }
            }
        }
    }
}


struct RequiredPatchUpdateOffer: Equatable {
    let version: String
    let notes: String
    let downloadURL: URL
}

@MainActor
final class RequiredPatchUpdateManager: ObservableObject {
    @Published private(set) var offer: RequiredPatchUpdateOffer?
    @Published private(set) var isInstalling = false
    @Published private(set) var statusMessage: String?

    private let endpoint = URL(string: "https://shafaykeyauthadmin.lovable.app/api/public/v1/patch/latest")!
    private let installedVersionKey = "robo.required.patch.installed.version"
    private var isRefreshing = false

    func refresh() {
        guard !isRefreshing, !isInstalling else { return }
        isRefreshing = true

        Task {
            defer { isRefreshing = false }

            do {
                let (data, response) = try await URLSession.shared.data(from: endpoint)
                guard let http = response as? HTTPURLResponse,
                      (200..<300).contains(http.statusCode) else {
                    return
                }

                let payload = try JSONDecoder().decode(RequiredPatchUpdatePayload.self, from: data)
                guard payload.active,
                      let rawURL = payload.downloadURL,
                      let url = URL(string: rawURL),
                      url.scheme == "https" else {
                    return
                }

                let installed = UserDefaults.standard.string(forKey: installedVersionKey)
                    ?? Bundle.main.object(forInfoDictionaryKey: "AppReleaseDisplayVersion") as? String
                    ?? "1.0"

                guard compareVersions(payload.version, installed) == .orderedDescending else {
                    offer = nil
                    return
                }

                offer = RequiredPatchUpdateOffer(
                    version: payload.version,
                    notes: payload.notes,
                    downloadURL: url
                )
                statusMessage = nil
            } catch {
                statusMessage = "Could not check for the required update."
            }
        }
    }

    func install(patchStore: PatchProjectStore) {
        guard let offer, !isInstalling else { return }

        isInstalling = true
        statusMessage = "Downloading update…"

        Task {
            do {
                let (data, response) = try await URLSession.shared.data(from: offer.downloadURL)
                guard let http = response as? HTTPURLResponse,
                      (200..<300).contains(http.statusCode) else {
                    throw UpdateInstallError.downloadFailed
                }

                statusMessage = "Installing patches…"

                let tempRoot = FileManager.default.temporaryDirectory
                    .appendingPathComponent("robo-required-update-\(UUID().uuidString)", isDirectory: true)
                try FileManager.default.createDirectory(
                    at: tempRoot,
                    withIntermediateDirectories: true
                )
                defer { try? FileManager.default.removeItem(at: tempRoot) }

                let archiveURL = tempRoot.appendingPathComponent("ROBO-PATCHES.zip")
                try data.write(to: archiveURL, options: .atomic)

                let extractionRoot = tempRoot.appendingPathComponent("extracted", isDirectory: true)
                try FileManager.default.createDirectory(
                    at: extractionRoot,
                    withIntermediateDirectories: true
                )

                let result = try ZIPArchiveExtractor.extract(
                    archiveURL: archiveURL,
                    into: extractionRoot
                )

                let packageURLs = try findPatchPackages(
                    in: result.destinationURL,
                    fileManager: .default
                )

                guard !packageURLs.isEmpty else {
                    throw UpdateInstallError.noPatchesFound
                }

                var imported = 0

                for packageURL in packageURLs {
                    let packageData = try Data(contentsOf: packageURL)

                    while patchStore.isBusy {
                        try await Task.sleep(nanoseconds: 150_000_000)
                    }

                    guard patchStore.importPackage(data: packageData) else {
                        throw UpdateInstallError.patchImportFailed
                    }

                    while patchStore.isBusy {
                        try await Task.sleep(nanoseconds: 150_000_000)
                    }

                    if patchStore.passwordRequest != nil {
                        throw UpdateInstallError.passwordProtectedPackage
                    }

                    imported += 1
                }

                guard imported > 0 else {
                    throw UpdateInstallError.noPatchesFound
                }

                patchStore.reload()
                UserDefaults.standard.set(offer.version, forKey: installedVersionKey)
                statusMessage = "Update installed successfully."
                isInstalling = false
                self.offer = nil
            } catch {
                statusMessage = error.localizedDescription
                isInstalling = false
            }
        }
    }

    private func findPatchPackages(
        in root: URL,
        fileManager: FileManager
    ) throws -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var result: [URL] = []

        for case let url as URL in enumerator {
            let values = try url.resourceValues(
                forKeys: [.isRegularFileKey, .isSymbolicLinkKey]
            )

            guard values.isRegularFile == true,
                  values.isSymbolicLink != true,
                  url.pathExtension.lowercased() == "3105" else {
                continue
            }

            result.append(url)
        }

        return result
    }

    private func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = lhs.split(separator: ".").map { Int($0) ?? 0 }
        let right = rhs.split(separator: ".").map { Int($0) ?? 0 }
        let count = max(left.count, right.count)

        for index in 0..<count {
            let l = index < left.count ? left[index] : 0
            let r = index < right.count ? right[index] : 0

            if l != r {
                return l < r ? .orderedAscending : .orderedDescending
            }
        }

        return .orderedSame
    }

    private struct RequiredPatchUpdatePayload: Decodable {
        let version: String
        let notes: String
        let downloadURL: String?
        let active: Bool

        enum CodingKeys: String, CodingKey {
            case version
            case notes
            case active
            case downloadURL = "download_url"
        }
    }

    private enum UpdateInstallError: LocalizedError {
        case downloadFailed
        case noPatchesFound
        case patchImportFailed
        case passwordProtectedPackage

        var errorDescription: String? {
            switch self {
            case .downloadFailed:
                return "The update could not be downloaded."
            case .noPatchesFound:
                return "ROBO-PATCHES.zip does not contain any .3105 patches."
            case .patchImportFailed:
                return "A patch could not be imported."
            case .passwordProtectedPackage:
                return "A patch package requires a password and could not be installed automatically."
            }
        }
    }
}

struct RequiredPatchUpdateView: View {
    let offer: RequiredPatchUpdateOffer
    let isInstalling: Bool
    let statusMessage: String?
    let onInstall: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            StarfieldBackground().ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: isInstalling ? "arrow.down.circle.fill" : "arrow.down.circle.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(
                        Color(red: 0.25, green: 0.68, blue: 1.0)
                    )

                Text("Required Update")
                    .font(.system(size: 27, weight: .bold))
                    .foregroundStyle(.white)

                Text("Version \(offer.version) is required before you can use Functions.")
                    .font(.system(size: 15))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.72))

                if !offer.notes.isEmpty {
                    Text(offer.notes)
                        .font(.system(size: 13))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.58))
                }

                if let statusMessage {
                    Text(statusMessage)
                        .font(.system(size: 13, weight: .medium))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.72))
                }

                Button(action: onInstall) {
                    HStack(spacing: 8) {
                        if isInstalling {
                            ProgressView()
                                .tint(.white)
                        }

                        Text(isInstalling ? "Installing…" : "Download & Install")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 0.12, green: 0.45, blue: 0.82),
                                Color(red: 0.22, green: 0.68, blue: 1.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isInstalling)
            }
            .padding(24)
        }
    }
}

import SwiftUI
import AVFoundation
import AVKit

/// Keeps the Functions clip's audio alive across authorization and tab changes.
final class AppMediaController {
    static let shared = AppMediaController()

    private var audioPlayer: AVQueuePlayer?
    private var audioLooper: AVPlayerLooper?
    private var didAttemptStart = false

    private init() {}

    func startFunctionAudio() {
        guard !didAttemptStart else {
            if audioPlayer?.timeControlStatus != .playing { audioPlayer?.play() }
            return
        }
        didAttemptStart = true

        guard let url = Bundle.main.url(forResource: "Functionscreen", withExtension: "mov") else {
            NSLog("BEST EXTERNAL: Functionscreen.mov is not yet included in the app bundle")
            return
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .moviePlayback,
                options: [.mixWithOthers]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            NSLog("BEST EXTERNAL: audio session setup failed: %@", error.localizedDescription)
        }

        let queue = AVQueuePlayer()
        queue.isMuted = false
        queue.volume = 1
        queue.actionAtItemEnd = .advance
        audioLooper = AVPlayerLooper(player: queue, templateItem: AVPlayerItem(url: url))
        audioPlayer = queue
        queue.play()
    }

    func resumeFunctionAudio() {
        guard let audioPlayer, audioPlayer.timeControlStatus != .playing else { return }
        audioPlayer.play()
    }
}

/// Full-screen, zoom-to-fill muted video used behind the license screen.
struct AppAuthorizationVideoBackground: View {
    var body: some View {
        LoopingVideoSurface(
            resourceName: "Keyauthvideo",
            fileExtension: "mp4",
            fallbackResourceName: "MISBAH_Background",
            fallbackExtension: "mp4",
            isMuted: true,
            gravity: .resizeAspectFill
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A looping, zoomable/cropped video surface with no playback controls.
struct LoopingVideoSurface: View {
    let resourceName: String
    let fileExtension: String
    var fallbackResourceName: String? = nil
    var fallbackExtension: String? = nil
    var isMuted = true
    var gravity: AVLayerVideoGravity = .resizeAspectFill

    @StateObject private var playback: LocalLoopingVideo

    init(
        resourceName: String,
        fileExtension: String,
        fallbackResourceName: String? = nil,
        fallbackExtension: String? = nil,
        isMuted: Bool = true,
        gravity: AVLayerVideoGravity = .resizeAspectFill
    ) {
        self.resourceName = resourceName
        self.fileExtension = fileExtension
        self.fallbackResourceName = fallbackResourceName
        self.fallbackExtension = fallbackExtension
        self.isMuted = isMuted
        self.gravity = gravity
        _playback = StateObject(wrappedValue: LocalLoopingVideo(
            resourceName: resourceName,
            fileExtension: fileExtension,
            fallbackResourceName: fallbackResourceName,
            fallbackExtension: fallbackExtension,
            isMuted: isMuted
        ))
    }

    var body: some View {
        PlayerLayerSurface(player: playback.player, gravity: gravity)
            .onAppear { playback.resume() }
    }
}

private final class LocalLoopingVideo: ObservableObject {
    let player: AVQueuePlayer?
    private var looper: AVPlayerLooper?

    init(
        resourceName: String,
        fileExtension: String,
        fallbackResourceName: String?,
        fallbackExtension: String?,
        isMuted: Bool
    ) {
        let url = Bundle.main.url(forResource: resourceName, withExtension: fileExtension)
            ?? fallbackResourceName.flatMap {
                Bundle.main.url(forResource: $0, withExtension: fallbackExtension)
            }
        guard let url else {
            player = nil
            NSLog("BEST EXTERNAL: video asset %@.%@ is missing", resourceName, fileExtension)
            return
        }

        let queue = AVQueuePlayer()
        queue.isMuted = isMuted
        queue.volume = isMuted ? 0 : 1
        queue.actionAtItemEnd = .advance
        looper = AVPlayerLooper(player: queue, templateItem: AVPlayerItem(url: url))
        player = queue
        queue.play()
    }

    func resume() {
        guard let player, player.timeControlStatus != .playing else { return }
        player.play()
    }
}

private struct PlayerLayerSurface: UIViewRepresentable {
    let player: AVPlayer?
    let gravity: AVLayerVideoGravity

    func makeUIView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        view.backgroundColor = .black
        view.isOpaque = true
        view.playerLayer.videoGravity = gravity
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ uiView: PlayerLayerView, context: Context) {
        uiView.playerLayer.videoGravity = gravity
        uiView.playerLayer.player = player
    }

    final class PlayerLayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }

        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

        override func layoutSubviews() {
            super.layoutSubviews()
            playerLayer.frame = bounds
        }
    }
}

import SwiftUI
import AVFoundation
import AVKit

/// Shared full-screen looping video background for Home, Functions, and child screens.
struct AppVideoBackground: View {
    var body: some View {
        GeometryReader { geometry in
            SharedLoopingVideoView()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private final class SharedBackgroundVideo {
    static let shared = SharedBackgroundVideo()

    let player: AVQueuePlayer?
    private let looper: AVPlayerLooper?

    private init() {
        guard let url = Bundle.main.url(
            forResource: "MISBAH_Background",
            withExtension: "mp4"
        ) else {
            player = nil
            looper = nil
            NSLog("MISBAH Background: MISBAH_Background.mp4 missing from app bundle")
            return
        }

        let queue = AVQueuePlayer()
        queue.actionAtItemEnd = .advance
        queue.isMuted = false
        queue.volume = 1.0

        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .moviePlayback,
                options: [.mixWithOthers]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            NSLog("MISBAH Background: audio session setup failed: %@", error.localizedDescription)
        }

        let item = AVPlayerItem(url: url)
        self.looper = AVPlayerLooper(player: queue, templateItem: item)
        self.player = queue
        queue.play()
    }

    func resume() {
        guard let player, player.timeControlStatus != .playing else { return }
        player.play()
    }
}

private struct SharedLoopingVideoView: UIViewRepresentable {
    func makeUIView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        view.backgroundColor = .black
        view.isOpaque = true
        view.playerLayer.videoGravity = .resizeAspectFill
        view.playerLayer.player = SharedBackgroundVideo.shared.player
        SharedBackgroundVideo.shared.resume()
        return view
    }

    func updateUIView(_ uiView: PlayerLayerView, context: Context) {
        uiView.playerLayer.player = SharedBackgroundVideo.shared.player
        SharedBackgroundVideo.shared.resume()
    }

    final class PlayerLayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }

        var playerLayer: AVPlayerLayer {
            layer as! AVPlayerLayer
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            playerLayer.frame = bounds
        }
    }
}

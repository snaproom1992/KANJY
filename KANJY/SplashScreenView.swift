import SwiftUI
import AVKit

struct SplashScreenView: View {
    @State private var isActive = false
    @State private var debugMessage = ""
    @State private var showDebugInfo = false
    
    var body: some View {
        if isActive {
            ContentView()
        } else {
            // 完全に別のアプローチ - UIViewControllerRepresentableを使用
            SplashPlayerRepresentable(isActive: $isActive, debugMessage: $debugMessage)
                .edgesIgnoringSafeArea(.all)
                .overlay(
                    // デバッグ情報（開発時のみ表示）
                    Group {
                        if showDebugInfo && !debugMessage.isEmpty {
                            VStack {
                                Spacer()
                                Text(debugMessage)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .padding()
                                    .background(Color.black.opacity(0.7))
                                    .cornerRadius(8)
                            }
                            .padding()
                        }
                    }
                )
                .onTapGesture(count: 3) {
                    showDebugInfo.toggle()
                }
        }
    }
}

// UIKitを直接使用して動画と文字を表示するためのラッパー
struct SplashPlayerRepresentable: UIViewControllerRepresentable {
    @Binding var isActive: Bool
    @Binding var debugMessage: String
    
    func makeUIViewController(context: Context) -> SplashPlayerViewController {
        let controller = SplashPlayerViewController()
        controller.onComplete = {
            DispatchQueue.main.async {
                withAnimation {
                    self.isActive = true
                }
            }
        }
        controller.onDebugMessage = { message in
            DispatchQueue.main.async {
                self.debugMessage = message
            }
        }
        return controller
    }
    
    func updateUIViewController(_ uiViewController: SplashPlayerViewController, context: Context) {
        // 更新処理は特になし
    }
}

// 動画再生とテキスト表示を担当するUIViewController
class SplashPlayerViewController: UIViewController {
    var onComplete: (() -> Void)? = nil
    var onDebugMessage: ((String) -> Void)? = nil
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var titleLabel: UILabel?
    private var subtitleLabel: UILabel?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupVideoPlayer()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // 画面サイズが変わった時に動画の位置とサイズを再調整
        if let playerLayer = playerLayer {
            let screenBounds = view.bounds
            let videoContainerSize = CGSize(
                width: screenBounds.width * 0.85,
                height: screenBounds.height * 0.85
            )
            
            let videoFrame = CGRect(
                x: (screenBounds.width - videoContainerSize.width) / 2,
                y: (screenBounds.height - videoContainerSize.height) / 2,
                width: videoContainerSize.width,
                height: videoContainerSize.height
            )
            
            playerLayer.frame = videoFrame
            
            // ウォーターマークを隠すオーバーレイも再調整
            updateWatermarkOverlay(videoFrame: videoFrame)
        }
    }
    
    private func setupVideoPlayer() {
        // 複数の拡張子を試す
        let videoName = "SplashAnimation"
        let possibleExtensions = ["mp4", "MP4", "mov", "MOV", "m4v", "M4V"]
        var videoURL: URL? = nil
        
        for ext in possibleExtensions {
            if let path = Bundle.main.path(forResource: videoName, ofType: ext) {
                videoURL = URL(fileURLWithPath: path)
                onDebugMessage?("動画ファイルを見つけました: \(videoName).\(ext)")
                break
            }
        }
        
        guard let finalURL = videoURL else {
            onDebugMessage?("動画ファイルが見つかりません")
            setupPlaceholderBackground()
            setupTexts()
            return
        }
        
        // プレーヤーの設定
        player = AVPlayer(url: finalURL)
        playerLayer = AVPlayerLayer(player: player)
        
        // ビデオの表示方法を変更 - 画面内に収める
        playerLayer?.videoGravity = .resizeAspect  // アスペクト比を維持して画面内に収める
        
        // 動画サイズを調整 - 画面の85%サイズに制限
        let screenBounds = view.bounds
        let videoContainerSize = CGSize(
            width: screenBounds.width * 0.85,  // 画面幅の85%
            height: screenBounds.height * 0.85  // 画面高さの85%
        )
        
        // 中央に配置するための計算
        let videoFrame = CGRect(
            x: (screenBounds.width - videoContainerSize.width) / 2,
            y: (screenBounds.height - videoContainerSize.height) / 2,
            width: videoContainerSize.width,
            height: videoContainerSize.height
        )
        
        playerLayer?.frame = videoFrame
        view.layer.addSublayer(playerLayer!)
        
        // RUNWAYの文字を隠すための白いレイヤーを追加
        addOverlayToHideWatermark(videoFrame: videoFrame)
        
        // 動画の再生準備
        player?.currentItem?.addObserver(self, forKeyPath: "status", options: [.new, .initial], context: nil)
        
        // 動画終了時のハンドリング
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem
        )
        
        // テキストの準備とアニメーション
        setupTexts()
        
        // 指定時間後に完了コールバックを呼び出す
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            self.onComplete?()
        }
    }
    
    private func setupPlaceholderBackground() {
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [UIColor.systemBlue.withAlphaComponent(0.2).cgColor, UIColor.white.cgColor]
        gradientLayer.locations = [0.0, 1.0]
        gradientLayer.frame = view.bounds
        view.layer.addSublayer(gradientLayer)
    }
    
    private func setupTexts() {
        // アプリ名ラベル
        let titleLabel = UILabel()
        titleLabel.text = "KANJY"
        
        // ヒラギノ丸ゴの太いバージョンを最優先で使用
        if let roundedFont = UIFont(name: "HiraMaruProN-W8", size: 70) {
            // ヒラギノ丸ゴ太字を使用
            titleLabel.font = roundedFont
        } else if let roundedFont = UIFont(name: "HiraMaruProN-W8", size: 70) {
            // 代替：ヒラギノ丸ゴ標準
            titleLabel.font = roundedFont
        } else if let arialRounded = UIFont(name: "ArialRoundedMTBold", size: 70) {
            // 代替：ArialRoundedMTBold
            titleLabel.font = arialRounded
        } else {
            // 最終フォールバック - システムフォント（太め）
            titleLabel.font = UIFont.systemFont(ofSize: 70, weight: .black)
        }
        
        // スタイル設定
        titleLabel.textAlignment = .center
        titleLabel.adjustsFontSizeToFitWidth = true // テキストがラベルに収まるように調整
        titleLabel.minimumScaleFactor = 0.7 // 必要に応じて最大30%までサイズダウン
        titleLabel.alpha = 0
        
        // カラーコード「365ECF」を使用
        titleLabel.textColor = hexStringToUIColor(hex: "365ECF")
        
        // サブタイトルラベル
        let subtitleLabel = UILabel()
        subtitleLabel.text = "幹事さんのための割り勘アプリ"
        
        // サブタイトルにもヒラギノ丸ゴを使用
        if let roundedFont = UIFont(name: "HiraMaruProN-W4", size: 20) {
            // ヒラギノ丸ゴを使用
            subtitleLabel.font = roundedFont
        } else {
            // フォールバック
            subtitleLabel.font = UIFont.systemFont(ofSize: 20, weight: .medium)
        }
        subtitleLabel.textColor = UIColor.darkGray
        subtitleLabel.textAlignment = .center
        subtitleLabel.alpha = 0
        
        // レイアウト設定
        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // 位置を調整 - 画面下部に配置（キャラクターと被らないように）
        NSLayoutConstraint.activate([
            // タイトルを画面下部に
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -100),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // サブタイトル
            subtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
        
        // シンプルなフェードインアニメーション
        UIView.animate(withDuration: 0.8, delay: 1.0, options: .curveEaseOut) {
            titleLabel.alpha = 1.0
        }
        
        UIView.animate(withDuration: 0.8, delay: 1.5, options: .curveEaseOut) {
            subtitleLabel.alpha = 1.0
        }
        
        self.titleLabel = titleLabel
        self.subtitleLabel = subtitleLabel
    }
    
    // 16進数カラーコードをUIColorに変換するヘルパーメソッド
    private func hexStringToUIColor(hex: String) -> UIColor {
        var cString: String = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        if cString.hasPrefix("#") {
            cString.remove(at: cString.startIndex)
        }
        
        if cString.count != 6 {
            return UIColor.systemBlue // フォールバックカラー
        }
        
        var rgbValue: UInt64 = 0
        Scanner(string: cString).scanHexInt64(&rgbValue)
        
        return UIColor(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: 1.0
        )
    }
    
    // RUNWAYの文字を隠すためのオーバーレイを追加
    private func addOverlayToHideWatermark(videoFrame: CGRect) {
        // 白いレイヤーを作成（動画の下部15%をカバー）
        let overlayHeight = videoFrame.height * 0.15
        let overlayY = videoFrame.maxY - overlayHeight
        
        let overlayLayer = CALayer()
        overlayLayer.backgroundColor = UIColor.white.cgColor
        overlayLayer.frame = CGRect(
            x: videoFrame.minX,
            y: overlayY,
            width: videoFrame.width,
            height: overlayHeight
        )
        
        // 動画レイヤーの上に追加（テキストレイヤーの下に配置）
        view.layer.addSublayer(overlayLayer)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "status", let item = object as? AVPlayerItem {
            if item.status == .readyToPlay {
                onDebugMessage?("動画の再生準備ができました")
                player?.play()
            } else if item.status == .failed {
                onDebugMessage?("動画の読み込みに失敗しました: \(item.error?.localizedDescription ?? "unknown")")
                setupPlaceholderBackground()
            }
        }
    }
    
    @objc func playerDidFinishPlaying() {
        // 動画が終了したら最初に戻して再生（ループ再生）
        player?.seek(to: CMTime.zero)
        player?.play()
    }
    
    // 白いオーバーレイのサイズと位置を更新
    private func updateWatermarkOverlay(videoFrame: CGRect) {
        // 既存のオーバーレイレイヤーを探す
        for layer in view.layer.sublayers ?? [] {
            // playerLayer以外のCALayerを検索（layer is CALayerは常にtrueなので削除）
            if layer != playerLayer {
                // 白いレイヤーのサイズと位置を更新
                let overlayHeight = videoFrame.height * 0.15
                let overlayY = videoFrame.maxY - overlayHeight
                
                layer.frame = CGRect(
                    x: videoFrame.minX,
                    y: overlayY,
                    width: videoFrame.width,
                    height: overlayHeight
                )
                break
            }
        }
    }
    
    deinit {
        // 監視を解除
        player?.currentItem?.removeObserver(self, forKeyPath: "status")
        NotificationCenter.default.removeObserver(self)
    }
}

struct ContentView: View {
    var body: some View {
        TopView()
    }
}

#Preview {
    SplashScreenView()
} 

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
        gradientLayer.colors = [UIColor(red: 0.067, green: 0.094, blue: 0.157, alpha: 0.2).cgColor, UIColor.white.cgColor]
        gradientLayer.locations = [0.0, 1.0]
        gradientLayer.frame = view.bounds
        view.layer.addSublayer(gradientLayer)
    }
    
    private func setupTexts() {
        // アプリ名ラベル（web版と統一：K A N J Y）
        let titleLabel = UILabel()
        
        // web版のfont-thin（薄いフォント）に合わせる
        // システムフォントの薄いウェイトを使用
        titleLabel.font = UIFont.systemFont(ofSize: 56, weight: .ultraLight)  // font-thin相当
        
        // web版のtracking-widest（広い文字間隔）に合わせる
        // NSAttributedStringで文字間隔を設定
        let titleText = "K A N J Y"  // スペース区切り、大文字
        let attributedString = NSMutableAttributedString(string: titleText)
        attributedString.addAttribute(.kern, value: 8.0, range: NSRange(location: 0, length: attributedString.length))
        titleLabel.attributedText = attributedString
        
        // スタイル設定
        titleLabel.textAlignment = .center
        titleLabel.adjustsFontSizeToFitWidth = true // テキストがラベルに収まるように調整
        titleLabel.minimumScaleFactor = 0.7 // 必要に応じて最大30%までサイズダウン
        titleLabel.alpha = 0
        
        // web版のtext-gray-900（#111827）に合わせる
        titleLabel.textColor = UIColor(red: 0.067, green: 0.094, blue: 0.157, alpha: 1.0)  // #111827
        
        // サブタイトルラベル（web版と統一）
        let subtitleLabel = UILabel()
        subtitleLabel.text = "幹事さんの負担を減らし、\n参加者みんなが楽しめる飲み会を。"
        
        // web版のtext-lg（18pt相当）に合わせる
        subtitleLabel.font = UIFont.systemFont(ofSize: 18, weight: .regular)
        
        // web版のtext-gray-600（#4B5563相当）に合わせる
        subtitleLabel.textColor = UIColor(red: 0.294, green: 0.333, blue: 0.388, alpha: 1.0)  // #4B5563
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0  // 複数行表示を許可
        subtitleLabel.lineBreakMode = .byWordWrapping  // 単語単位で改行
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
            return UIColor(red: 0.067, green: 0.094, blue: 0.157, alpha: 1.0) // フォールバックカラー
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
    @State private var selectedTab = 0
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showingOnboarding = false
    @StateObject private var viewModel = PrePlanViewModel()
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // ホームタブ
            TopView(selectedTab: $selectedTab)
                .tabItem {
                    Label("ホーム", systemImage: "house.fill")
                }
                .tag(0)
            
            // 新規作成タブ（中央に配置）
            QuickCreatePlanView(viewModel: viewModel)
                .tabItem {
                    Label("新規作成", systemImage: "plus.circle.fill")
                }
                .tag(1)
            
            // 設定タブ
            SettingsView()
                .tabItem {
                    Label("設定", systemImage: "gearshape.fill")
                }
                .tag(2)
        }
        .accentColor(Color(red: 0.067, green: 0.094, blue: 0.157))
        .onAppear {
            if !hasCompletedOnboarding {
                showingOnboarding = true
            }
        }
        .fullScreenCover(isPresented: $showingOnboarding) {
            OnboardingGuideView(isPresented: $showingOnboarding) {
                hasCompletedOnboarding = true
            }
        }
    }
}

#Preview {
    SplashScreenView()
} 

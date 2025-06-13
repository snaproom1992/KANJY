import SwiftUI

struct PaymentInfoGenerator: View {
    @ObservedObject var viewModel: PrePlanViewModel
    @AppStorage("payPayID") private var payPayID = ""
    @AppStorage("bankInfo") private var bankInfo = ""
    
    // テキストフィールドの内容
    @State private var messageText = "お支払いよろしくお願いします。"
    @State private var dueText = "お支払い期限: 7日以内"
    
    @State private var selectedPaymentMethods: Set<PaymentMethod> = [.payPay, .bankTransfer, .cash]
    @State private var showShareSheet = false
    @State private var generatedImage: UIImage?
    @State private var itemsToShare: [Any] = []
    @State private var isGeneratingImages = false
    @State private var showProgress = false
    @State private var progressValue = 0.0
    @State private var selectedParticipant: Participant? = nil
    @State private var previewImage: UIImage? = nil
    
    // 定型文の配列
    private let messageTemplates = [
        "お支払いよろしくお願いします。",
        "お支払いのご協力をお願いいたします。",
        "今回の会費のお支払いをお願いします。",
        "楽しい時間をありがとうございました。お支払いをお願いします。",
        "お疲れ様でした！会費の納入をお願いします。",
        "幹事を担当しました。お支払いのご協力をお願いします。",
        "飲み会の精算です。お支払いよろしくお願いします。"
    ]
    
    enum PaymentMethod: String, CaseIterable, Identifiable {
        case payPay = "PayPay"
        case bankTransfer = "銀行振込"
        case cash = "現金"
        
        var id: String { self.rawValue }
        
        var icon: String {
            switch self {
            case .payPay: return "creditcard.fill"
            case .bankTransfer: return "building.columns.fill"
            case .cash: return "yensign.circle.fill"
            }
        }
    }
    
    var body: some View {
        ZStack {
            Form {
                // 支払い方法セクション
                Section(header: Text("支払い方法（複数選択可）")) {
                    ForEach(PaymentMethod.allCases) { method in
                        HStack {
                            Image(systemName: method.icon)
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            
                            Text(method.rawValue)
                            
                            Spacer()
                            
                            Toggle("", isOn: Binding(
                                get: { selectedPaymentMethods.contains(method) },
                                set: { isOn in
                                    if isOn {
                                        selectedPaymentMethods.insert(method)
                                    } else {
                                        selectedPaymentMethods.remove(method)
                                    }
                                    updatePreviewImage()
                                }
                            ))
                            .labelsHidden()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedPaymentMethods.contains(method) {
                                selectedPaymentMethods.remove(method)
                            } else {
                                selectedPaymentMethods.insert(method)
                            }
                            updatePreviewImage()
                        }
                    }
                    
                    if selectedPaymentMethods.contains(.payPay) && payPayID.isEmpty {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text("PayPay IDが設定されていません")
                                .font(.footnote)
                                .foregroundColor(.orange)
                            Spacer()
                        }
                        .padding(.top, 4)
                        .padding(.horizontal, 4)
                        .padding(.bottom, 2)
                    }
                    
                    if selectedPaymentMethods.contains(.bankTransfer) && bankInfo.isEmpty {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text("銀行振込情報が設定されていません")
                                .font(.footnote)
                                .foregroundColor(.orange)
                            Spacer()
                        }
                        .padding(.top, 4)
                        .padding(.horizontal, 4)
                        .padding(.bottom, 2)
                    }
                    
                    if selectedPaymentMethods.isEmpty {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.red)
                            Text("少なくとも1つの支払い方法を選択してください")
                                .font(.footnote)
                                .foregroundColor(.red)
                            Spacer()
                        }
                        .padding(.top, 4)
                        .padding(.horizontal, 4)
                        .padding(.bottom, 2)
                    }
                }
                
                // メッセージカスタマイズセクション
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        // 案内メッセージラベルとランダムボタン
                        HStack {
                            Text("案内メッセージ")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.top, 2)
                            
                            Spacer()
                            
                            // コンパクトなランダムボタン
                            Button {
                                // メッセージをランダムに変更
                                messageText = messageTemplates.randomElement() ?? "お支払いよろしくお願いします。"
                                updatePreviewImage()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "dice")
                                        .font(.footnote)
                                    Text("ランダム")
                                        .font(.caption)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                            }
                            .buttonStyle(BorderlessButtonStyle()) // ボタンスタイルを明示的に設定
                            .padding(.top, 2)
                        }
                        .padding(.bottom, 4)
                        
                        // テキストエディタを個別のビューで囲み、クリックイベントを独立させる
                        Group {
                            ZStack(alignment: .topLeading) {
                                TextEditor(text: $messageText)
                                    .frame(minHeight: 90)
                                    .padding(6)
                                    .background(Color(.systemBackground))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color(.systemGray4), lineWidth: 1)
                                    )
                                    .cornerRadius(10)
                            .onChange(of: messageText) { _, _ in
                                updatePreviewImage()
                            }
                                
                                // プレースホルダー
                                if messageText.isEmpty {
                                    Text("お支払いよろしくお願いします。")
                                        .foregroundColor(Color(.placeholderText))
                                        .padding(.horizontal, 10)
                                        .padding(.top, 12)
                                        .padding(.leading, 2)
                                        .allowsHitTesting(false)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        
                        // 支払い期限部分
                            Text("支払い期限")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            .padding(.top, 8)
                            .padding(.bottom, 4)
                        
                        // テキストフィールドを個別のビューで囲み、クリックイベントを独立させる
                        Group {
                        TextField("お支払い期限: 7日以内", text: $dueText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.vertical, 2)
                            .onChange(of: dueText) { _, _ in
                                updatePreviewImage()
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    // タップイベントが子ビューに伝播しないようにする
                    .onTapGesture {}
                } header: {
                    Text("メッセージ設定")
                }
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                
                // プレビューセクション
                if !viewModel.participants.isEmpty {
                    Section(header: Text("プレビュー")) {
                        VStack(alignment: .center, spacing: 10) {
                            if let preview = previewImage {
                                Image(uiImage: preview)
                                    .resizable()
                                    .scaledToFit()
                                    .cornerRadius(16)
                                    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 3)
                                    .padding(.vertical, 10)
                            } else {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 200)
                                    .cornerRadius(16)
                                    .overlay(
                                        Text("プレビューを生成中...")
                                            .foregroundColor(.gray)
                                    )
                                    .padding(.vertical, 10)
                            }
                            
                            Button(action: {
                                shareImage()
                            }) {
                                HStack {
                                    Image(systemName: "square.and.arrow.up")
                                        .imageScale(.medium)
                                    Text("プレビューを共有")
                                        .font(.headline)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            .disabled(isGeneratingDisabled)
                            .padding(.bottom, 10)
                        }
                    }
                }
                
                // 参加者一覧セクション
                if !viewModel.participants.isEmpty {
                    Section(header: Text("参加者一覧")) {
                        ForEach(viewModel.participants) { participant in
                            HStack {
                                // 集金状況インジケータ
                                Image(systemName: participant.hasCollected ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(participant.hasCollected ? .green : .gray)
                                    .imageScale(.large)
                                
                                // 参加者情報
                                Text(participant.name)
                                
                                Spacer()
                                
                                // 金額
                                Text("¥\(viewModel.formatAmount(String(viewModel.paymentAmount(for: participant))))")
                                    .foregroundColor(.blue)
                                    .fontWeight(.semibold)
                            }
                            .opacity(participant.hasCollected ? 0.6 : 1.0)
                            .padding(.vertical, 4)
                            .background(
                                selectedParticipant?.id == participant.id 
                                ? Color.blue.opacity(0.1) 
                                : Color.clear
                            )
                            .cornerRadius(8)
                        }
                    }
                } else {
                    Section(header: Text("参加者一覧")) {
                        Text("参加者が登録されていません")
                            .foregroundColor(.gray)
                            .italic()
                            .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("お支払い案内")
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: itemsToShare)
            }
            .onAppear {
                updatePreviewImage()
            }
            
            // プログレスオーバーレイ
            if showProgress {
                VStack {
                    ProgressView(value: progressValue)
                        .progressViewStyle(LinearProgressViewStyle())
                        .padding()
                    
                    Text("お支払い案内を生成中...")
                        .font(.headline)
                        .padding()
                }
                .frame(width: 250, height: 150)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(radius: 10)
                )
            }
        }
    }
    
    // 生成ボタンの無効化条件
    private var isGeneratingDisabled: Bool {
        isGeneratingImages || 
        selectedPaymentMethods.isEmpty ||
        (selectedPaymentMethods.contains(.payPay) && payPayID.isEmpty) || 
        (selectedPaymentMethods.contains(.bankTransfer) && bankInfo.isEmpty) ||
        viewModel.participants.isEmpty
    }
    
    // プレビュー画像を更新
    private func updatePreviewImage() {
        DispatchQueue.global(qos: .userInitiated).async {
            let image = self.generatePaymentSummaryImage()
            DispatchQueue.main.async {
                self.previewImage = image
            }
        }
    }
    
    // 画像を共有
    private func shareImage() {
        guard let image = previewImage else {
            updatePreviewImage()
            return
        }
        
        itemsToShare = [image]
        showShareSheet = true
    }
    
    // 全員分の一覧表画像を生成
    private func generatePaymentSummaryImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1080, height: 1600))
        
        // 基本色の定義
        let primaryColor = UIColor(red: 0.0, green: 0.4, blue: 0.8, alpha: 1.0)
        let secondaryColor = UIColor(red: 0.15, green: 0.5, blue: 0.9, alpha: 1.0)
        let backgroundColor = UIColor(red: 0.97, green: 0.97, blue: 0.97, alpha: 1.0)
        let cardColor = UIColor.white
        let textColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        let lightGrayColor = UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)
        
        // 基本フォントサイズ
        let mainTitleFontSize: CGFloat = 68  // 飲み会名のフォントサイズを大きく
        let titleFontSize: CGFloat = 38      // お支払い案内のフォントサイズを小さく
        let _ = CGFloat(34)                  // headingFontSize（未使用なので_に置き換え）
        let subheadingFontSize: CGFloat = 30
        let bodyFontSize: CGFloat = 28
        let smallFontSize: CGFloat = 24
        
        let image = renderer.image { context in
            // 背景
            backgroundColor.setFill()
            UIBezierPath(rect: CGRect(x: 0, y: 0, width: 1080, height: 1600)).fill()
            
            // トップバナー
            let bannerGradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    primaryColor.cgColor,
                    secondaryColor.cgColor
                ] as CFArray,
                locations: [0, 1]
            )!
            
            _ = CGRect(x: 0, y: 0, width: 1080, height: 180)  // bannerRect（未使用なので_に置き換え）
            context.cgContext.drawLinearGradient(
                bannerGradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: 1080, y: 0),
                options: []
            )
            
            // メインコンテンツの白い背景（カード風）
            let contentRect = CGRect(x: 40, y: 140, width: 1000, height: 1410)
            cardColor.setFill()
            let contentPath = UIBezierPath(roundedRect: contentRect, cornerRadius: 16)
            contentPath.fill()
            
            // 影の効果を追加
            context.cgContext.setShadow(offset: CGSize(width: 0, height: 5), blur: 12, color: UIColor.black.withAlphaComponent(0.1).cgColor)
            UIBezierPath(roundedRect: contentRect, cornerRadius: 16).stroke()
            context.cgContext.setShadow(offset: .zero, blur: 0, color: nil)
            
            // タイトル（お支払い案内）- 位置を上に移動し、サイズを小さく
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: titleFontSize, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let titleRect = CGRect(x: 50, y: 60, width: 980, height: 60)
            NSString(string: "お支払い案内").draw(in: titleRect, withAttributes: titleAttributes)
            
            // イベント名（最も目立つように）- 位置を下に移動し、サイズを大きく
            let eventNameRect = CGRect(x: 70, y: 170, width: 940, height: 100)
            let eventAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: mainTitleFontSize, weight: .bold),
                .foregroundColor: primaryColor
            ]
            NSString(string: viewModel.editingPlanName).draw(in: eventNameRect, withAttributes: eventAttributes)
            
            // メッセージ（イベント名の下に配置）
            let messageAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: bodyFontSize),
                .foregroundColor: textColor
            ]
            let messageRect = CGRect(x: 70, y: 280, width: 940, height: 60)
            NSString(string: messageText).draw(in: messageRect, withAttributes: messageAttributes)
            
            // 区切り線
            UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0).setStroke()
            let dividerPath = UIBezierPath()
            dividerPath.move(to: CGPoint(x: 70, y: 350))
            dividerPath.addLine(to: CGPoint(x: 1010, y: 350))
            dividerPath.lineWidth = 1
            dividerPath.stroke()
            
            // 支払い方法セクション
            let methodHeaderAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: subheadingFontSize, weight: .semibold),
                .foregroundColor: primaryColor
            ]
            let methodHeaderRect = CGRect(x: 70, y: 370, width: 300, height: 40)
            NSString(string: "支払い方法").draw(in: methodHeaderRect, withAttributes: methodHeaderAttributes)
            
            // 説明文を追加
            let instructionAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: smallFontSize),
                .foregroundColor: textColor
            ]
            let instructionRect = CGRect(x: 70, y: 410, width: 940, height: 30)
            NSString(string: "下記のいずれかの方法で支払いをお願いいたします。").draw(in: instructionRect, withAttributes: instructionAttributes)
            
            // アイコンサイズと位置
            let iconSize: CGFloat = 36
            let iconSpacing: CGFloat = 200
            var iconX = 70.0
            let iconY = 450.0
            
            // 支払い方法アイコンとテキスト
            for method in selectedPaymentMethods.sorted(by: { $0.rawValue < $1.rawValue }) {
                // アイコン描画
                let iconRect = CGRect(x: iconX, y: iconY, width: iconSize, height: iconSize)
                
                // 支払い方法ごとに色を変更
                switch method {
                case .payPay:
                    // PayPayは赤
                    UIColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1.0).setFill()
                case .bankTransfer:
                    // 銀行振込は緑
                    UIColor(red: 0.0, green: 0.6, blue: 0.3, alpha: 1.0).setFill()
                case .cash:
                    // 現金は黄色
                    UIColor(red: 0.95, green: 0.7, blue: 0.1, alpha: 1.0).setFill()
                }
                UIBezierPath(ovalIn: iconRect).fill()
                
                // アイコン内のシンボル
                let symbolAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 20, weight: .bold),
                    .foregroundColor: UIColor.white
                ]
                
                let symbolText: String
                switch method {
                case .payPay: symbolText = "P"
                case .bankTransfer: symbolText = "銀"
                case .cash: symbolText = "¥"
                }
                
                let symbolRect = CGRect(x: iconX + 10, y: iconY + 5, width: 20, height: 30)
                NSString(string: symbolText).draw(in: symbolRect, withAttributes: symbolAttributes)
                
                // テキスト
                let methodAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: bodyFontSize),
                    .foregroundColor: textColor
                ]
                let methodRect = CGRect(x: iconX + iconSize + 10, y: iconY, width: 120, height: 40)
                NSString(string: method.rawValue).draw(in: methodRect, withAttributes: methodAttributes)
                
                iconX += iconSpacing
            }
            
            // 支払い情報
            var infoY = iconY + 60
            
            // 支払い先の説明文を追加（改行を入れて2行に分ける）
            let paymentInfoAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: smallFontSize),
                .foregroundColor: textColor
            ]
            
            // 1行目の説明文
            let paymentInfoRect1 = CGRect(x: 70, y: infoY, width: 940, height: 30)
            NSString(string: "支払い先は以下でお願いいたします。").draw(in: paymentInfoRect1, withAttributes: paymentInfoAttributes)
            
            // 2行目の説明文（行間を広げる）
            let paymentInfoRect2 = CGRect(x: 70, y: infoY + 35, width: 940, height: 30)  // 25から35に変更して行間を広げる
            NSString(string: "お支払いの際は確認ができるよう氏名を記入してください。").draw(in: paymentInfoRect2, withAttributes: paymentInfoAttributes)
            
            // 説明文の後に余白を追加（2行分の高さ+余白）
            infoY += 75  // 65から75に変更して全体の余白も広げる
            
            // PayPayIDを別に表示（アイコン・ラベル・登録情報をすべて左揃え、テキストボックスもカード左右マージンと揃える）
            if selectedPaymentMethods.contains(.payPay) {
                let cardMargin: CGFloat = 40
                let contentX: CGFloat = 70 // カードの左端
                let iconSize: CGFloat = 28
                let iconY: CGFloat = infoY + 7
                let labelX: CGFloat = contentX
                let labelY: CGFloat = iconY
                let labelHeight: CGFloat = 30
                let boxY: CGFloat = labelY + labelHeight + 8
                let boxWidth: CGFloat = 940 // カード幅1000 - マージン*2(40*2=80)
                let boxHeight: CGFloat = 60 // 1行分なので60ptに
                let tagHeight: CGFloat = labelHeight + 8 + boxHeight
                let idValueAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: bodyFontSize, weight: .bold),
                    .foregroundColor: UIColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1.0)
                ]
                if !payPayID.isEmpty {
                    // Pアイコン
                    UIColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1.0).setFill()
                    UIBezierPath(ovalIn: CGRect(x: labelX, y: iconY + 4, width: iconSize, height: iconSize)).fill()
                    let smallSymbolAttributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 16, weight: .bold),
                        .foregroundColor: UIColor.white
                    ]
                    NSString(string: "P").draw(in: CGRect(x: labelX + 7, y: iconY + 8, width: 14, height: 20), withAttributes: smallSymbolAttributes)
                    // ラベル
                    let labelAttributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: bodyFontSize),
                        .foregroundColor: UIColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1.0)
                    ]
                    let labelTextX = labelX + iconSize + 12
                    NSString(string: "支払い先PayPay ID:").draw(in: CGRect(x: labelTextX, y: labelY, width: boxWidth, height: labelHeight), withAttributes: labelAttributes)
                    // 登録情報（テキストボックス風）
                    let boxX = contentX
                    let idRect = CGRect(x: boxX, y: boxY, width: boxWidth, height: boxHeight)
                    UIColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 0.10).setFill()
                    UIBezierPath(roundedRect: idRect, cornerRadius: 10).fill()
                    NSString(string: payPayID).draw(in: CGRect(x: boxX + 20, y: boxY + 18, width: boxWidth - 40, height: boxHeight - 28), withAttributes: idValueAttributes)
                }
                infoY += tagHeight + 20
            }
            // 銀行振込情報（アイコン・ラベル・登録情報をすべて左揃え、テキストボックスもカード左右マージンと揃える）
            if selectedPaymentMethods.contains(.bankTransfer) {
                let cardMargin: CGFloat = 40
                let contentX: CGFloat = 70
                let iconSize: CGFloat = 28
                let iconY: CGFloat = infoY + 7
                let labelX: CGFloat = contentX
                let labelY: CGFloat = iconY
                let labelHeight: CGFloat = 30
                let boxY: CGFloat = labelY + labelHeight + 12
                let boxWidth: CGFloat = 940
                let boxHeight: CGFloat = 120 // 80から120に拡大
                let tagHeight: CGFloat = labelHeight + 12 + boxHeight
                let bankInfoAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: bodyFontSize, weight: .bold),
                    .foregroundColor: UIColor(red: 0.0, green: 0.5, blue: 0.2, alpha: 1.0)
                ]
                if !bankInfo.isEmpty {
                    // 銀アイコン
                    UIColor(red: 0.0, green: 0.5, blue: 0.2, alpha: 1.0).setFill()
                    UIBezierPath(ovalIn: CGRect(x: labelX, y: iconY + 4, width: iconSize, height: iconSize)).fill()
                    let smallSymbolAttributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 16, weight: .bold),
                        .foregroundColor: UIColor.white
                    ]
                    NSString(string: "銀").draw(in: CGRect(x: labelX + 7, y: iconY + 8, width: 14, height: 20), withAttributes: smallSymbolAttributes)
                    // ラベル
                    let labelAttributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: bodyFontSize),
                        .foregroundColor: UIColor(red: 0.0, green: 0.5, blue: 0.2, alpha: 1.0)
                    ]
                    let labelTextX = labelX + iconSize + 12
                    NSString(string: "振込先:").draw(in: CGRect(x: labelTextX, y: labelY, width: boxWidth, height: labelHeight), withAttributes: labelAttributes)
                    // 登録情報（テキストボックス風）
                    let boxX = contentX
                    let infoRect = CGRect(x: boxX, y: boxY, width: boxWidth, height: boxHeight)
                    UIColor(red: 0.0, green: 0.5, blue: 0.2, alpha: 0.10).setFill()
                    UIBezierPath(roundedRect: infoRect, cornerRadius: 10).fill()
                    // 要素ごとに分割して表示
                    let bankElements = bankInfo.components(separatedBy: " ")
                    var upperLine = ""
                    var holderLine = ""
                    if let nameIndex = bankElements.firstIndex(where: { $0.contains("名義") }) {
                        upperLine = bankElements[0..<nameIndex].joined(separator: "   ")
                        holderLine = bankElements[nameIndex...].joined(separator: " ")
                    } else {
                        upperLine = bankInfo
                    }
                    let upperAttributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: bodyFontSize, weight: .bold),
                        .foregroundColor: UIColor(red: 0.0, green: 0.5, blue: 0.2, alpha: 1.0)
                    ]
                    let holderAttributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: bodyFontSize, weight: .regular),
                        .foregroundColor: UIColor(red: 0.0, green: 0.5, blue: 0.2, alpha: 1.0)
                    ]
                    // 上段（銀行名・支店名・種別・口座番号）
                    NSString(string: upperLine).draw(in: CGRect(x: boxX + 20, y: boxY + 18, width: boxWidth - 40, height: 32), withAttributes: upperAttributes)
                    // 下段（名義）
                    if !holderLine.isEmpty {
                        NSString(string: holderLine).draw(in: CGRect(x: boxX + 20, y: boxY + 60, width: boxWidth - 40, height: 28), withAttributes: holderAttributes)
                    }
                }
                infoY += tagHeight + 20
            }
            
            // 区切り線の位置を調整
            let dividerY = infoY + 20
            UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0).setStroke()
            let dividerPath2 = UIBezierPath()
            dividerPath2.move(to: CGPoint(x: 70, y: dividerY))
            dividerPath2.addLine(to: CGPoint(x: 1010, y: dividerY))
            dividerPath2.lineWidth = 1
            dividerPath2.stroke()
            
            // 参加者リストヘッダーと支払い済み凡例の位置を調整
            let participantsY = dividerY + 20
            let participantsHeaderAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: subheadingFontSize, weight: .semibold),
                .foregroundColor: primaryColor
            ]
            let participantsHeaderRect = CGRect(x: 70, y: participantsY, width: 300, height: 40)
            NSString(string: "参加者一覧").draw(in: participantsHeaderRect, withAttributes: participantsHeaderAttributes)
            
            // 支払い済み凡例
            let legendCircleRect = CGRect(x: 850, y: participantsY + 5, width: 24, height: 24)
            primaryColor.setFill()
            UIBezierPath(ovalIn: legendCircleRect).fill()
            
            let legendCheckAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            NSString(string: "✓").draw(in: CGRect(x: 855, y: participantsY + 5, width: 16, height: 24), withAttributes: legendCheckAttributes)
            
            let legendTextAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: smallFontSize),
                .foregroundColor: textColor
            ]
            NSString(string: "= 支払い済み").draw(in: CGRect(x: 880, y: participantsY + 5, width: 150, height: 30), withAttributes: legendTextAttributes)
            
            // テーブルヘッダーの位置を調整
            let tableY = participantsY + 50
            let tableHeaderRect = CGRect(x: 70, y: tableY, width: 940, height: 50)
            primaryColor.withAlphaComponent(0.1).setFill()
            UIBezierPath(roundedRect: tableHeaderRect, byRoundingCorners: [.topLeft, .topRight], cornerRadii: CGSize(width: 12, height: 12)).fill()
            
            // ヘッダーテキスト
            let headerAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: smallFontSize, weight: .semibold),
                .foregroundColor: primaryColor
            ]
            
            let nameHeaderRect = CGRect(x: 120, y: tableY + 10, width: 300, height: 30)
            NSString(string: "参加者名").draw(in: nameHeaderRect, withAttributes: headerAttributes)
            
            let roleHeaderRect = CGRect(x: 500, y: tableY + 10, width: 200, height: 30)
            NSString(string: "役割").draw(in: roleHeaderRect, withAttributes: headerAttributes)
            
            let amountHeaderRect = CGRect(x: 800, y: tableY + 10, width: 150, height: 30)
            NSString(string: "金額").draw(in: amountHeaderRect, withAttributes: headerAttributes)
            
            // 参加者テーブルの枠線
            let rowHeight: CGFloat = 70.0 // 60.0からさらに70.0に高さを増加
            let maxRows: CGFloat = CGFloat(min(viewModel.participants.count, 10))
            let tableHeight: CGFloat = 50.0 + maxRows * rowHeight
            let tableRect = CGRect(x: 70, y: tableY, width: 940, height: tableHeight)
            UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 0.8).setStroke()
            let tablePath = UIBezierPath(roundedRect: tableRect, cornerRadius: 12)
            tablePath.lineWidth = 1
            tablePath.stroke()
            
            // 参加者ごとの行の描画
            var yOffset = tableY + 50
            
            // 参加者リスト
            let cellAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: bodyFontSize + 2, weight: .medium),
                .foregroundColor: textColor
            ]
            
            let roleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: smallFontSize),
                .foregroundColor: UIColor.darkGray
            ]
            
            // 金額を目立たせる
            let amountAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: bodyFontSize + 4, weight: .bold), // フォントサイズを少し小さく調整
                .foregroundColor: primaryColor
            ]
            
            // 最大表示数に制限して描画
            let maxVisibleRows = 10
            let sortedParticipants = viewModel.participants.sorted { $0.name < $1.name }
            let displayedParticipants = sortedParticipants.prefix(maxVisibleRows)
            
            for (index, participant) in displayedParticipants.enumerated() {
                // 背景（交互に色を変える）
                if index % 2 == 0 {
                    UIColor.white.setFill()
                } else {
                    lightGrayColor.setFill()
                }
                let rowRect = CGRect(x: 70, y: yOffset, width: 940, height: rowHeight)
                UIBezierPath(rect: rowRect).fill()
                
                // 集金状態マーク
                if participant.hasCollected {
                    // 集金済みマーク - サイズを小さく控えめに
                    let checkmarkRect = CGRect(x: 85, y: yOffset + 25, width: 20, height: 20) // Y位置をさらに調整
                    primaryColor.withAlphaComponent(0.6).setFill()
                    UIBezierPath(ovalIn: checkmarkRect).fill()
                    
                    // チェックマーク
                    let checkAttributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 14, weight: .bold),
                        .foregroundColor: UIColor.white
                    ]
                    let checkRect = CGRect(x: 89, y: yOffset + 25, width: 14, height: 20) // Y位置をさらに調整
                    NSString(string: "✓").draw(in: checkRect, withAttributes: checkAttributes)
                }
                
                // 名前
                let nameRect = CGRect(x: 120, y: yOffset + 20, width: 300, height: 30) // Y位置をさらに調整
                NSString(string: participant.name).draw(in: nameRect, withAttributes: cellAttributes)
                
                // 役割
                let roleRect = CGRect(x: 500, y: yOffset + 20, width: 200, height: 30) // Y位置をさらに調整
                var roleName = ""
                switch participant.roleType {
                case .standard(let role):
                    roleName = role.name
                case .custom(let customRole):
                    roleName = customRole.name
                }
                NSString(string: roleName).draw(in: roleRect, withAttributes: roleAttributes)
                
                // 金額 - 右寄せに変更し、背景色なし
                let amount = viewModel.paymentAmount(for: participant)
                let amountString = "¥\(viewModel.formatAmount(String(amount)))"
                
                // 金額用の属性を直接ここで定義（未使用変数の警告を解消）
                let amountTextAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: bodyFontSize + 4, weight: .bold), // フォントサイズを少し小さく調整
                    .foregroundColor: primaryColor
                ]
                
                // 金額の幅を計算して右寄せ
                let amountSize = (amountString as NSString).size(withAttributes: amountTextAttributes)
                let amountX = 970 - amountSize.width
                let amountRect = CGRect(x: amountX, y: yOffset + 20, width: amountSize.width, height: 40) // Y位置とheightをさらに調整
                NSString(string: amountString).draw(in: amountRect, withAttributes: amountTextAttributes)
                
                yOffset += rowHeight
            }
            
            // 表示しきれない参加者がいる場合の注記
            if sortedParticipants.count > maxVisibleRows {
                let noteAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.italicSystemFont(ofSize: smallFontSize),
                    .foregroundColor: UIColor.darkGray
                ]
                let noteRect = CGRect(x: 70, y: yOffset + 10, width: 940, height: 30)
                NSString(string: "※他 \(sortedParticipants.count - maxVisibleRows) 名の参加者がいます").draw(in: noteRect, withAttributes: noteAttributes)
                
                yOffset += 50
            }
            
            // 合計金額セクションの高さを内訳の行数に応じて調整
            let breakdownCount = max(1, viewModel.amountItems.count)
            let totalSectionHeight = 140 + breakdownCount * 30 // さらに高さを増加
            let totalSectionRect = CGRect(x: 70, y: yOffset + 10, width: 940, height: CGFloat(totalSectionHeight)) // Y位置も調整
            primaryColor.withAlphaComponent(0.05).setFill()
            UIBezierPath(roundedRect: totalSectionRect, cornerRadius: 12).fill()
            
            primaryColor.withAlphaComponent(0.3).setStroke()
            let totalBorderPath = UIBezierPath(roundedRect: totalSectionRect, cornerRadius: 12)
            totalBorderPath.lineWidth = 2
            totalBorderPath.stroke()
            
            let totalLabelAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: subheadingFontSize, weight: .bold),
                .foregroundColor: textColor
            ]
            let totalValueAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: bodyFontSize + 2, weight: .semibold),
                .foregroundColor: primaryColor
            ]
            // 合計ラベル
            let totalLabelRect = CGRect(x: 90, y: yOffset + 55, width: 200, height: 40) // Y位置をさらに調整
            NSString(string: "合計金額").draw(in: totalLabelRect, withAttributes: totalLabelAttributes)
            // 合計金額を右揃え
            let totalString = "¥\(viewModel.totalAmount)"
            let totalSize = (totalString as NSString).size(withAttributes: totalValueAttributes)
            let totalX = 970 - totalSize.width
            let totalValueRect = CGRect(x: totalX, y: yOffset + 55, width: totalSize.width, height: 40) // Y位置をさらに調整
            NSString(string: totalString).draw(in: totalValueRect, withAttributes: totalValueAttributes)
            // 内訳（1行ずつ追加、金額は右揃え）
            if !viewModel.amountItems.isEmpty {
                let breakdownFont = UIFont.systemFont(ofSize: smallFontSize - 2)
                let breakdownAttributes: [NSAttributedString.Key: Any] = [
                    .font: breakdownFont,
                    .foregroundColor: UIColor.darkGray
                ]
                var breakdownY = yOffset + 105 // Y位置をさらに調整
                for item in viewModel.amountItems {
                    let breakdownName = item.name
                    let breakdownAmount = "¥\(viewModel.formatAmount(String(item.amount)))"
                    // 左揃え（合計金額ラベルと同じX）
                    NSString(string: breakdownName).draw(in: CGRect(x: 90, y: breakdownY, width: 200, height: 26), withAttributes: breakdownAttributes)
                    // 右揃え（合計金額数値と同じX）
                    let amountSize = (breakdownAmount as NSString).size(withAttributes: breakdownAttributes)
                    let amountX = 970 - amountSize.width
                    NSString(string: breakdownAmount).draw(in: CGRect(x: amountX, y: breakdownY, width: amountSize.width, height: 26), withAttributes: breakdownAttributes)
                    breakdownY += 30 // 行間をさらに広げる
                }
            }
            // 期限セクションを合計金額の下に動的に移動
            yOffset += CGFloat(totalSectionHeight + 30) // 間隔を広げる
            let deadlineAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: subheadingFontSize, weight: .semibold),
                .foregroundColor: primaryColor
            ]
            let deadlineRect = CGRect(x: 70, y: yOffset, width: 940, height: 50)
            NSString(string: dueText).draw(in: deadlineRect, withAttributes: deadlineAttributes)
            
            // フッター
            let footerAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: smallFontSize),
                .foregroundColor: UIColor.gray
            ]
            let footerText = "KANJY アプリで作成"
            let footerTextSize = (footerText as NSString).size(withAttributes: footerAttributes)
            let footerTextX = (1080 - footerTextSize.width) / 2
            NSString(string: footerText).draw(in: CGRect(x: footerTextX, y: 1520, width: footerTextSize.width, height: 40), withAttributes: footerAttributes)
        }
        
        return image
    }
}

// 共有シート
struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    PaymentInfoGenerator(viewModel: PrePlanViewModel())
} 
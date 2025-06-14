import SwiftUI

struct PaymentInfoGenerator: View {
    @ObservedObject var viewModel: PrePlanViewModel
    @AppStorage("payPayID") private var payPayID = ""
    @AppStorage("bankInfo") private var bankInfo = ""
    
    // テキストフィールドの内容
    @State private var messageText = "お支払いよろしくお願いします。"
    @State private var dueText = "お支払い期限: 7日以内"
    
    @State private var selectedPaymentMethods: Set<PaymentMethod> = []
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
                        VStack(alignment: .center, spacing: 0) { // spacingを0に変更
                            if let preview = previewImage {
                                ScrollView(.vertical) {
                                    Image(uiImage: preview)
                                        .resizable()
                                        .scaledToFit()
                                        .padding(.top, 20) // 上部に余白を追加
                                }
                                .padding(0) // すべての余白を削除
                            } else {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 300)
                                    .cornerRadius(16)
                                    .overlay(
                                        VStack {
                                            if selectedPaymentMethods.isEmpty {
                                                Text("支払い方法を選択してください")
                                                    .foregroundColor(.gray)
                                            } else if isGeneratingImages {
                                                VStack {
                                                    ProgressView()
                                                        .padding(.bottom, 10)
                                                    Text("プレビューを生成中...")
                                                        .foregroundColor(.gray)
                                                }
                                            } else {
                                                Text("プレビューを生成できません")
                                                    .foregroundColor(.gray)
                                            }
                                        }
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
                                .background(isGeneratingDisabled ? Color.gray : Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            .disabled(isGeneratingDisabled)
                            .padding(.vertical, 16)
                            
                            // 支払い方法が選択されていない場合のヒント
                            if selectedPaymentMethods.isEmpty {
                                Text("支払い方法を1つ以上選択してください")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                    .padding(.vertical, 8) // 上下の余白を増やす
                            }
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
            .navigationTitle("集金案内作成")
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: itemsToShare)
            }
            .onAppear {
                // 画面表示時にプレビュー更新
                // 支払い方法が選択されていない場合は更新しない（デフォルトでは空のため）
                if !selectedPaymentMethods.isEmpty {
                    updatePreviewImage()
                }
            }
            .onChange(of: selectedPaymentMethods) { _, newValue in
                // 支払い方法が変更されたらプレビュー更新
                if !newValue.isEmpty {
                    updatePreviewImage()
                } else {
                    // 選択がなくなったらプレビューをクリア
                    previewImage = nil
                }
            }
            
            // プログレスオーバーレイ
            if showProgress {
                VStack {
                    ProgressView(value: progressValue)
                        .progressViewStyle(LinearProgressViewStyle())
                        .padding()
                    
                    Text("集金案内を生成中...")
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
        // 支払い方法が選択されていない場合は早期リターン
        if selectedPaymentMethods.isEmpty {
            self.previewImage = nil
            return
        }
        
        // 生成中フラグを設定
        isGeneratingImages = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let image = self.generatePaymentSummaryImage()
            DispatchQueue.main.async {
                self.previewImage = image
                self.isGeneratingImages = false // 生成完了
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
        // 内部パディングを定義（一律20pt）
        let padding: CGFloat = 20
        // セクション内部のパディング
        let _ = 15 // sectionPaddingは後で再定義するため、ここでは使用しない
        
        // 基本色の定義
        let primaryColor = UIColor(red: 0.0, green: 0.4, blue: 0.8, alpha: 1.0)
        let backgroundColor = UIColor(red: 0.97, green: 0.97, blue: 0.97, alpha: 1.0)
        let cardColor = UIColor.white
        let textColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        let lightGrayColor = UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)
        
        // 基本フォントサイズ
        let mainTitleFontSize: CGFloat = 68
        let titleFontSize: CGFloat = 38
        let subheadingFontSize: CGFloat = 30
        let bodyFontSize: CGFloat = 28
        let smallFontSize: CGFloat = 24
        
        // 白いカードの上部マージン
        let cardTopMargin: CGFloat = 140
        
        // 最初に幅だけ決定し、高さは後で動的に計算
        let cardWidth: CGFloat = 1000
        let _ = cardWidth - (padding * 2) // cardContentWidthは後で再定義するため、ここでは使用しない
        
        // 基本的な高さを計算（固定値ではなく、コンテンツに基づいて計算）
        
        // 基本高さ（最低限必要な高さ）
        var totalContentHeight: CGFloat = 160 // イベント名とメッセージ
        
        // 支払い方法セクション
        let methodSectionHeight: CGFloat = 150
        totalContentHeight += methodSectionHeight + padding
        
        // PayPay情報セクション（存在する場合）
        if selectedPaymentMethods.contains(.payPay) && !payPayID.isEmpty {
            totalContentHeight += 120 + padding
        }
        
        // 銀行振込情報セクション（存在する場合）
        if selectedPaymentMethods.contains(.bankTransfer) && !bankInfo.isEmpty {
            totalContentHeight += 200 + padding
        }
        
        // 参加者リストセクション（存在する場合）
        if !viewModel.participants.isEmpty {
            // 行の高さ
            let rowHeight: CGFloat = 70
            // 参加者リストの高さを計算（ヘッダー + 参加者行 + 余白）
            let participantsCount = min(viewModel.participants.count, 20)
            let participantsSectionHeight = 50.0 + CGFloat(participantsCount) * rowHeight + 50
            totalContentHeight += participantsSectionHeight + padding
            
            // 合計金額と内訳セクション
            let breakdownCount = max(1, viewModel.amountItems.count)
            let totalSectionHeight = 160 + CGFloat(breakdownCount) * 35 // 合計金額 + 内訳行 + 余白
            totalContentHeight += totalSectionHeight + padding
        }
        
        // 支払い期限セクション
        totalContentHeight += 70 + padding
        
        // フッター用の余白
        totalContentHeight += 80
        
        // カードの高さ（コンテンツの高さ + 上下のパディング + 余裕を持たせる）
        let cardHeight = totalContentHeight + (padding * 2) + 100 // 余裕を持たせるために100ptを追加
        
        // 全体の高さ（カードの高さ + 上部マージン + 下部マージン）
        let totalHeight = cardHeight + cardTopMargin + 60
        
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1080, height: totalHeight))
        
        let image = renderer.image { context in
            // 背景
            backgroundColor.setFill()
            UIBezierPath(rect: CGRect(x: 0, y: 0, width: 1080, height: totalHeight)).fill()
            
            // 青い背景部分に角丸を追加
            let blueBackgroundRect = CGRect(x: 0, y: 0, width: 1080, height: totalHeight)
            let blueBackgroundPath = UIBezierPath(roundedRect: blueBackgroundRect, cornerRadius: 24)
            primaryColor.withAlphaComponent(0.9).setFill()
            blueBackgroundPath.fill()
            
            // メインコンテンツの白い背景（カード風）- 高さを動的に調整
            let contentRect = CGRect(x: 40, y: cardTopMargin, width: 1000, height: cardHeight)
            cardColor.setFill()
            let contentPath = UIBezierPath(roundedRect: contentRect, cornerRadius: 16)
            contentPath.fill()
            
            // 影の効果を追加
            context.cgContext.setShadow(offset: CGSize(width: 0, height: 5), blur: 12, color: UIColor.black.withAlphaComponent(0.1).cgColor)
            UIBezierPath(roundedRect: contentRect, cornerRadius: 16).stroke()
            context.cgContext.setShadow(offset: .zero, blur: 0, color: nil)
            
            // カード内の有効領域を計算
            let cardContentX = contentRect.origin.x + padding
            let cardContentY = contentRect.origin.y + padding
            let cardContentWidth = contentRect.width - (padding * 2)
            let cardContentHeight = contentRect.height - (padding * 2) // 実際に使用する
            
            // セクション内部のパディング
            let sectionPadding: CGFloat = 15
            
            // タイトル（お支払い案内）- 位置を上に移動し、サイズを小さく
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: titleFontSize, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let titleRect = CGRect(x: 50, y: 60, width: 980, height: 60)
            NSString(string: "お支払い案内").draw(in: titleRect, withAttributes: titleAttributes)
            
            // イベント名とメッセージのセクション背景
            let eventSectionRect = CGRect(x: cardContentX, y: cardContentY, width: cardContentWidth, height: 160)
            UIColor(red: 0.95, green: 0.98, blue: 1.0, alpha: 0.5).setFill() // 薄い水色の背景
            UIBezierPath(roundedRect: eventSectionRect, cornerRadius: 12).fill()
            
            // イベント名（最も目立つように）
            let eventNameRect = CGRect(
                x: eventSectionRect.origin.x + sectionPadding,
                y: eventSectionRect.origin.y + sectionPadding,
                width: eventSectionRect.width - (sectionPadding * 2),
                height: 100
            )
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
            let messageRect = CGRect(
                x: eventSectionRect.origin.x + sectionPadding,
                y: eventNameRect.maxY + 10,
                width: eventSectionRect.width - (sectionPadding * 2),
                height: 40
            )
            NSString(string: messageText).draw(in: messageRect, withAttributes: messageAttributes)
            
            // 区切り線
            UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0).setStroke()
            let dividerPath = UIBezierPath()
            dividerPath.move(to: CGPoint(x: cardContentX, y: eventSectionRect.maxY + padding))
            dividerPath.addLine(to: CGPoint(x: cardContentX + cardContentWidth, y: eventSectionRect.maxY + padding))
            dividerPath.lineWidth = 1
            dividerPath.stroke()
            
            // 支払い方法セクション
            let methodHeaderAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: subheadingFontSize, weight: .semibold),
                .foregroundColor: primaryColor
            ]
            
            // 支払い方法セクション全体を囲む背景を追加
            let methodSectionY = eventSectionRect.maxY + (padding * 2)
            let methodSectionRect = CGRect(x: cardContentX, y: methodSectionY, width: cardContentWidth, height: methodSectionHeight)
            UIColor(red: 0.95, green: 0.95, blue: 1.0, alpha: 0.3).setFill() // 薄い青色の背景
            UIBezierPath(roundedRect: methodSectionRect, cornerRadius: 12).fill()
            
            // 支払い方法ヘッダー
            let methodHeaderRect = CGRect(
                x: methodSectionRect.origin.x + sectionPadding,
                y: methodSectionRect.origin.y + sectionPadding,
                width: 300,
                height: 40
            )
            NSString(string: "支払い方法").draw(in: methodHeaderRect, withAttributes: methodHeaderAttributes)
            
            // 説明文を追加
            let instructionAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: smallFontSize),
                .foregroundColor: textColor
            ]
            let instructionRect = CGRect(
                x: methodSectionRect.origin.x + sectionPadding,
                y: methodHeaderRect.maxY + 10,
                width: methodSectionRect.width - (sectionPadding * 2),
                height: 30
            )
            NSString(string: "下記のいずれかの方法で支払いをお願いいたします。").draw(in: instructionRect, withAttributes: instructionAttributes)
            
            // アイコンサイズと位置
            let iconSize: CGFloat = 36
            let iconSpacing: CGFloat = 200 // 固定値に戻す
            var iconX = methodSectionRect.origin.x + sectionPadding
            let iconY = instructionRect.maxY + 15
            
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
            let paymentInfoRect1 = CGRect(
                x: methodSectionRect.origin.x + sectionPadding,
                y: infoY,
                width: methodSectionRect.width - (sectionPadding * 2),
                height: 30
            )
            NSString(string: "支払い先は以下でお願いいたします。").draw(in: paymentInfoRect1, withAttributes: paymentInfoAttributes)
            
            // 2行目の説明文（行間を広げる）
            let paymentInfoRect2 = CGRect(
                x: methodSectionRect.origin.x + sectionPadding,
                y: infoY + 35,
                width: methodSectionRect.width - (sectionPadding * 2),
                height: 30
            )
            NSString(string: "お振込みの際は確認ができるよう氏名を記入してください。").draw(in: paymentInfoRect2, withAttributes: paymentInfoAttributes)
            
            // 説明文の後に余白を追加（2行分の高さ+余白）
            infoY += 75
            
            // PayPayIDを別に表示（アイコン・ラベル・登録情報をすべて左揃え、テキストボックスもカード左右マージンと揃える）
            if selectedPaymentMethods.contains(.payPay) {
                // PayPayセクション全体を囲む背景を追加
                let sectionY = infoY
                let sectionHeight: CGFloat = 120 // セクション全体の高さ
                let sectionRect = CGRect(
                    x: cardContentX,
                    y: sectionY,
                    width: cardContentWidth,
                    height: sectionHeight
                )
                UIColor(red: 1.0, green: 0.95, blue: 0.95, alpha: 0.5).setFill() // 薄い赤色の背景
                UIBezierPath(roundedRect: sectionRect, cornerRadius: 12).fill()
                
                let contentX = sectionRect.origin.x + sectionPadding
                let iconSize: CGFloat = 28
                let iconY: CGFloat = infoY + 20 // 上部に余白を追加
                let labelX: CGFloat = contentX
                let labelY: CGFloat = iconY
                let labelHeight: CGFloat = 30
                let boxY: CGFloat = labelY + labelHeight + 15 // 余白を増やす
                let boxWidth: CGFloat = sectionRect.width - (sectionPadding * 2)
                let boxHeight: CGFloat = 60 // 1行分なので60ptに
                
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
                infoY += sectionHeight + padding // セクションの高さ + 余白
            }
            
            // 銀行振込情報（アイコン・ラベル・登録情報をすべて左揃え、テキストボックスもカード左右マージンと揃える）
            if selectedPaymentMethods.contains(.bankTransfer) {
                // 銀行振込セクション全体を囲む背景を追加
                let sectionY = infoY
                let sectionHeight: CGFloat = 200 // セクション全体の高さ
                let sectionRect = CGRect(
                    x: cardContentX,
                    y: sectionY,
                    width: cardContentWidth,
                    height: sectionHeight
                )
                UIColor(red: 0.95, green: 0.98, blue: 0.95, alpha: 0.5).setFill() // 薄い緑色の背景
                UIBezierPath(roundedRect: sectionRect, cornerRadius: 12).fill()
                
                let contentX = sectionRect.origin.x + sectionPadding
                let iconSize: CGFloat = 28
                let iconY: CGFloat = infoY + 20 // 上部に余白を追加
                let labelX: CGFloat = contentX
                let labelY: CGFloat = iconY
                let labelHeight: CGFloat = 30
                let boxY: CGFloat = labelY + labelHeight + 15 // 余白を増やす
                let boxWidth: CGFloat = sectionRect.width - (sectionPadding * 2)
                let boxHeight: CGFloat = 140 
                
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
                    NSString(string: upperLine).draw(in: CGRect(x: boxX + 20, y: boxY + 25, width: boxWidth - 40, height: 40), withAttributes: upperAttributes)
                    // 下段（名義）
                    if !holderLine.isEmpty {
                        NSString(string: holderLine).draw(in: CGRect(x: boxX + 20, y: boxY + 75, width: boxWidth - 40, height: 40), withAttributes: holderAttributes)
                    }
                }
                infoY += sectionHeight + padding // セクションの高さ + 余白
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
            
            // 行の高さを定義
            let rowHeight: CGFloat = 70.0 // 行の高さ
            
            // 参加者セクション全体を囲む背景を追加
            // 動的に高さを計算（ヘッダー + 参加者行 + 余白）
            let participantsCount = min(viewModel.participants.count, 20)
            let participantsSectionHeight = 50.0 + CGFloat(participantsCount) * rowHeight + 50
            let participantsSectionRect = CGRect(x: cardContentX, y: participantsY, width: cardContentWidth, height: participantsSectionHeight)
            UIColor(red: 0.95, green: 0.95, blue: 1.0, alpha: 0.5).setFill() // 薄い青色の背景
            UIBezierPath(roundedRect: participantsSectionRect, cornerRadius: 12).fill()
            
            let participantsHeaderAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: subheadingFontSize, weight: .semibold),
                .foregroundColor: primaryColor
            ]
            let participantsHeaderRect = CGRect(x: 70, y: participantsY + 15, width: 300, height: 40)
            NSString(string: "参加者一覧").draw(in: participantsHeaderRect, withAttributes: participantsHeaderAttributes)
            
            // 支払い済み凡例
            let legendCircleRect = CGRect(x: 850, y: participantsY + 20, width: 24, height: 24)
            primaryColor.setFill()
            UIBezierPath(ovalIn: legendCircleRect).fill()
            
            let legendCheckAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            NSString(string: "✓").draw(in: CGRect(x: 855, y: participantsY + 20, width: 16, height: 24), withAttributes: legendCheckAttributes)
            
            let legendTextAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: smallFontSize),
                .foregroundColor: textColor
            ]
            NSString(string: "= 支払い済み").draw(in: CGRect(x: 880, y: participantsY + 20, width: 150, height: 30), withAttributes: legendTextAttributes)
            
            // テーブルヘッダーの位置を調整
            let tableY = participantsY + 65
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
            let maxRows: CGFloat = CGFloat(min(viewModel.participants.count, 20)) // 最大20人まで表示
            let tableHeight: CGFloat = 50.0 + maxRows * rowHeight
            let tableRect = CGRect(x: cardContentX + 20, y: tableY, width: cardContentWidth - 40, height: tableHeight)
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
            
            // 金額は直接属性を定義して使用するため、この変数は不要
            
            // 参加者数に応じて表示数を調整（最大20人まで表示）
            let maxVisibleRows = 20
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
            
            // 合計金額セクション全体を囲む背景を追加
            let breakdownCount = max(1, viewModel.amountItems.count)
            let totalSectionHeight = 160 + CGFloat(breakdownCount) * 35 // 合計金額 + 内訳行 + 余白
            let totalSectionRect = CGRect(
                x: cardContentX,
                y: yOffset,
                width: cardContentWidth,
                height: totalSectionHeight
            )
            UIColor(red: 0.95, green: 1.0, blue: 0.95, alpha: 0.5).setFill() // 薄い緑色の背景
            UIBezierPath(roundedRect: totalSectionRect, cornerRadius: 12).fill()
            
            // 合計金額部分の背景
            let totalBoxRect = CGRect(
                x: totalSectionRect.origin.x + sectionPadding,
                y: yOffset + 40,
                width: totalSectionRect.width - (sectionPadding * 2),
                height: 70
            )
            primaryColor.withAlphaComponent(0.05).setFill()
            UIBezierPath(roundedRect: totalBoxRect, cornerRadius: 12).fill()
            
            primaryColor.withAlphaComponent(0.3).setStroke()
            let totalBorderPath = UIBezierPath(roundedRect: totalBoxRect, cornerRadius: 12)
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
            let totalLabelRect = CGRect(
                x: totalBoxRect.origin.x + sectionPadding,
                y: yOffset + 55,
                width: 200,
                height: 40
            )
            NSString(string: "合計金額").draw(in: totalLabelRect, withAttributes: totalLabelAttributes)
            
            // 合計金額を右揃え
            let totalString = "¥\(viewModel.totalAmount)"
            let totalSize = (totalString as NSString).size(withAttributes: totalValueAttributes)
            let totalX = totalBoxRect.maxX - sectionPadding - totalSize.width
            let totalValueRect = CGRect(x: totalX, y: yOffset + 55, width: totalSize.width, height: 40)
            NSString(string: totalString).draw(in: totalValueRect, withAttributes: totalValueAttributes)
            
            // 内訳ヘッダー
            if !viewModel.amountItems.isEmpty {
                let breakdownHeaderAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: smallFontSize, weight: .medium),
                    .foregroundColor: UIColor.darkGray
                ]
                let breakdownHeaderRect = CGRect(
                    x: totalSectionRect.origin.x + sectionPadding,
                    y: yOffset + 120,
                    width: 200,
                    height: 30
                )
                NSString(string: "内訳:").draw(in: breakdownHeaderRect, withAttributes: breakdownHeaderAttributes)
                
                // 内訳項目の背景
                let breakdownBoxRect = CGRect(
                    x: totalSectionRect.origin.x + sectionPadding,
                    y: yOffset + 155,
                    width: totalSectionRect.width - (sectionPadding * 2),
                    height: CGFloat(breakdownCount * 35 + 10)
                )
                UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.7).setFill() // 白っぽい背景
                UIBezierPath(roundedRect: breakdownBoxRect, cornerRadius: 8).fill()
                
                // 内訳項目
                let breakdownFont = UIFont.systemFont(ofSize: smallFontSize)
                let breakdownAttributes: [NSAttributedString.Key: Any] = [
                    .font: breakdownFont,
                    .foregroundColor: UIColor.darkGray
                ]
                var breakdownY = yOffset + 165
                for item in viewModel.amountItems {
                    let breakdownName = item.name
                    let breakdownAmount = "¥\(viewModel.formatAmount(String(item.amount)))"
                    // 左揃え（合計金額ラベルと同じX）
                    NSString(string: breakdownName).draw(in: CGRect(
                        x: breakdownBoxRect.origin.x + sectionPadding,
                        y: breakdownY,
                        width: 500,
                        height: 30
                    ), withAttributes: breakdownAttributes)
                    
                    // 右揃え（合計金額数値と同じX）
                    let amountSize = (breakdownAmount as NSString).size(withAttributes: breakdownAttributes)
                    let amountX = breakdownBoxRect.maxX - sectionPadding - amountSize.width
                    NSString(string: breakdownAmount).draw(in: CGRect(
                        x: amountX,
                        y: breakdownY,
                        width: amountSize.width,
                        height: 30
                    ), withAttributes: breakdownAttributes)
                    
                    breakdownY += 35
                }
            }
            
            // 期限セクションを合計金額の下に動的に移動
            yOffset += totalSectionHeight + 30 // 間隔を広げる
            
            // 期限セクション全体を囲む背景を追加
            let deadlineSectionHeight: CGFloat = 70 // 再定義
            let deadlineSectionRect = CGRect(
                x: cardContentX,
                y: yOffset,
                width: cardContentWidth,
                height: deadlineSectionHeight
            )
            UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 0.5).setFill() // 薄いグレーの背景
            UIBezierPath(roundedRect: deadlineSectionRect, cornerRadius: 12).fill()
            
            let deadlineAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: subheadingFontSize, weight: .semibold),
                .foregroundColor: primaryColor
            ]
            let deadlineRect = CGRect(
                x: deadlineSectionRect.origin.x + sectionPadding,
                y: yOffset + 20,
                width: deadlineSectionRect.width - (sectionPadding * 2),
                height: 50
            )
            NSString(string: dueText).draw(in: deadlineRect, withAttributes: deadlineAttributes)
            
            // フッターの位置を調整
            yOffset += deadlineSectionHeight + 50
            
            // フッター
            let footerAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: smallFontSize),
                .foregroundColor: UIColor.gray
            ]
            let footerText = "KANJY アプリで作成"
            let footerTextSize = (footerText as NSString).size(withAttributes: footerAttributes)
            let footerTextX = (contentRect.width - footerTextSize.width) / 2 + contentRect.origin.x
            // フッターの位置をカードの下部に配置
            let footerY = contentRect.maxY - 60 // カードの下から60ptの位置
            NSString(string: footerText).draw(in: CGRect(x: footerTextX, y: footerY, width: footerTextSize.width, height: 40), withAttributes: footerAttributes)
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

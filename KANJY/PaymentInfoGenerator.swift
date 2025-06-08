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
                                .foregroundColor(.orange)
                        }
                        .padding(.top, 4)
                    }
                    
                    if selectedPaymentMethods.contains(.bankTransfer) && bankInfo.isEmpty {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text("銀行振込情報が設定されていません")
                                .foregroundColor(.orange)
                        }
                        .padding(.top, 4)
                    }
                    
                    if selectedPaymentMethods.isEmpty {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.red)
                            Text("少なくとも1つの支払い方法を選択してください")
                                .foregroundColor(.red)
                        }
                        .padding(.top, 4)
                    }
                }
                
                // メッセージカスタマイズセクション
                Section(header: Text("メッセージ設定")) {
                    VStack(alignment: .leading, spacing: 12) {
                        // 案内メッセージ部分
                        HStack {
                            Text("案内メッセージ")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
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
                        }
                        
                        // メッセージのテキストフィールド
                        TextField("お支払いよろしくお願いします", text: $messageText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onChange(of: messageText) { _, _ in
                                updatePreviewImage()
                            }
                        
                        // 支払い期限部分
                        HStack {
                            Text("支払い期限")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            // ランダムボタンを削除
                        }
                        .padding(.top, 4)
                        
                        // 期限のテキストフィールド
                        TextField("お支払い期限: 7日以内", text: $dueText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onChange(of: dueText) { _, _ in
                                updatePreviewImage()
                            }
                    }
                    .padding(.vertical, 6)
                }
                
                // プレビューセクション
                if !viewModel.participants.isEmpty {
                    Section(header: Text("集金案内")) {
                        VStack(alignment: .center, spacing: 10) {
                            if let preview = previewImage {
                                Image(uiImage: preview)
                                    .resizable()
                                    .scaledToFit()
                                    .cornerRadius(8)
                                    .shadow(radius: 2)
                                    .padding(.vertical, 10)
                            } else {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 200)
                                    .cornerRadius(8)
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
                                    Text("一覧表を共有")
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
                                
                                // 参加者情報
                                Text(participant.name)
                                
                                Spacer()
                                
                                // 金額
                                Text("¥\(viewModel.formatAmount(String(viewModel.paymentAmount(for: participant))))")
                                    .foregroundColor(.blue)
                            }
                            .opacity(participant.hasCollected ? 0.6 : 1.0)
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
                    }
                }
            }
            .navigationTitle("集金案内")
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
                    
                    Text("支払い案内を生成中...")
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
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1080, height: 1500))
        let image = renderer.image { context in
            // 背景
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: CGSize(width: 1080, height: 1500)))
            
            // タイトル
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 70, weight: .bold),
                .foregroundColor: UIColor.black
            ]
            let titleRect = CGRect(x: 0, y: 80, width: 1080, height: 100)
            NSString(string: "支払い金額一覧").draw(in: titleRect, withAttributes: titleAttributes)
            
            // イベント名
            let eventAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 50, weight: .semibold),
                .foregroundColor: UIColor.darkGray
            ]
            let eventRect = CGRect(x: 50, y: 170, width: 980, height: 70)
            NSString(string: viewModel.editingPlanName).draw(in: eventRect, withAttributes: eventAttributes)
            
            // 支払い方法
            let methodLabelAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 40, weight: .medium),
                .foregroundColor: UIColor.black
            ]
            let methodLabelRect = CGRect(x: 50, y: 250, width: 980, height: 50)
            
            // 複数の支払い方法を表示
            let methodNames = selectedPaymentMethods.map { $0.rawValue }.joined(separator: "・")
            NSString(string: "支払い方法: \(methodNames)").draw(in: methodLabelRect, withAttributes: methodLabelAttributes)
            
            // 支払い情報
            let infoAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 35),
                .foregroundColor: UIColor.darkGray
            ]
            let infoRect = CGRect(x: 50, y: 300, width: 980, height: 100)
            
            var paymentInfo = ""
            
            // 複数の支払い方法の情報を表示
            var infoLines: [String] = []
            
            if selectedPaymentMethods.contains(.payPay) {
                infoLines.append("PayPay ID: \(payPayID)")
            }
            
            if selectedPaymentMethods.contains(.bankTransfer) {
                infoLines.append("振込先: \(bankInfo.replacingOccurrences(of: "\n", with: " "))")
            }
            
            if selectedPaymentMethods.contains(.cash) {
                infoLines.append("現金: 当日お支払いください")
            }
            
            paymentInfo = infoLines.joined(separator: " / ")
            
            NSString(string: paymentInfo).draw(in: infoRect, withAttributes: infoAttributes)
            
            // ヘッダー
            let headerAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 40, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            
            // ヘッダー背景
            UIColor.darkGray.setFill()
            let headerRect = CGRect(x: 50, y: 400, width: 980, height: 60)
            context.fill(headerRect)
            
            // ヘッダーテキスト
            let nameHeaderRect = CGRect(x: 70, y: 400, width: 400, height: 60)
            NSString(string: "参加者名").draw(in: nameHeaderRect, withAttributes: headerAttributes)
            
            let roleHeaderRect = CGRect(x: 480, y: 400, width: 250, height: 60)
            NSString(string: "役割").draw(in: roleHeaderRect, withAttributes: headerAttributes)
            
            let amountHeaderRect = CGRect(x: 750, y: 400, width: 250, height: 60)
            NSString(string: "金額").draw(in: amountHeaderRect, withAttributes: headerAttributes)
            
            // 参加者リスト
            let cellAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 35),
                .foregroundColor: UIColor.black
            ]
            
            let roleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 30),
                .foregroundColor: UIColor.darkGray
            ]
            
            let amountAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 35, weight: .semibold),
                .foregroundColor: UIColor.blue
            ]
            
            // 参加者ごとの行を描画
            var yOffset = 480.0
            let rowHeight = 80.0
            let maxVisibleRows = 10
            
            // 最大表示数に制限して描画
            let sortedParticipants = viewModel.participants.sorted { $0.name < $1.name }
            let displayedParticipants = sortedParticipants.prefix(maxVisibleRows)
            
            for participant in displayedParticipants {
                // 背景（交互に色を変える）
                if displayedParticipants.firstIndex(where: { $0.id == participant.id })! % 2 == 0 {
                    UIColor(white: 0.95, alpha: 1.0).setFill()
                } else {
                    UIColor(white: 1.0, alpha: 1.0).setFill()
                }
                let rowRect = CGRect(x: 50, y: yOffset, width: 980, height: rowHeight)
                context.fill(rowRect)
                
                // 名前
                let nameRect = CGRect(x: 70, y: yOffset + 20, width: 400, height: 40)
                NSString(string: participant.name).draw(in: nameRect, withAttributes: cellAttributes)
                
                // 役割
                let roleRect = CGRect(x: 480, y: yOffset + 20, width: 250, height: 40)
                var roleName = ""
                switch participant.roleType {
                case .standard(let role):
                    roleName = role.name
                case .custom(let customRole):
                    roleName = customRole.name
                }
                NSString(string: roleName).draw(in: roleRect, withAttributes: roleAttributes)
                
                // 金額
                let amount = viewModel.paymentAmount(for: participant)
                let amountRect = CGRect(x: 750, y: yOffset + 20, width: 250, height: 40)
                NSString(string: "¥\(viewModel.formatAmount(String(amount)))").draw(in: amountRect, withAttributes: amountAttributes)
                
                yOffset += rowHeight
            }
            
            // 表示しきれない参加者がいる場合の注記
            if sortedParticipants.count > maxVisibleRows {
                let noteAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.italicSystemFont(ofSize: 30),
                    .foregroundColor: UIColor.darkGray
                ]
                let noteRect = CGRect(x: 50, y: yOffset + 10, width: 980, height: 40)
                NSString(string: "※他 \(sortedParticipants.count - maxVisibleRows) 名の参加者がいます").draw(in: noteRect, withAttributes: noteAttributes)
                
                yOffset += 50
            }
            
            // 合計金額
            yOffset += 30
            
            UIColor.black.setStroke()
            let totalLinePath = UIBezierPath()
            totalLinePath.move(to: CGPoint(x: 50, y: yOffset))
            totalLinePath.addLine(to: CGPoint(x: 1030, y: yOffset))
            totalLinePath.lineWidth = 2
            totalLinePath.stroke()
            
            let totalLabelAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 40, weight: .bold),
                .foregroundColor: UIColor.black
            ]
            let totalValueAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 50, weight: .bold),
                .foregroundColor: UIColor.blue
            ]
            
            let totalLabelRect = CGRect(x: 50, y: yOffset + 20, width: 200, height: 50)
            NSString(string: "合計金額").draw(in: totalLabelRect, withAttributes: totalLabelAttributes)
            
            let totalValueRect = CGRect(x: 750, y: yOffset + 20, width: 280, height: 50)
            NSString(string: "¥\(viewModel.totalAmount)").draw(in: totalValueRect, withAttributes: totalValueAttributes)
            
            // メッセージ
            let messageAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 35),
                .foregroundColor: UIColor.darkGray
            ]
            let messageRect = CGRect(x: 50, y: yOffset + 100, width: 980, height: 100)
            NSString(string: messageText).draw(in: messageRect, withAttributes: messageAttributes)
            
            // 期限
            let deadlineAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 35, weight: .medium),
                .foregroundColor: UIColor(red: 0.2, green: 0.2, blue: 0.6, alpha: 1.0)
            ]
            let deadlineRect = CGRect(x: 50, y: yOffset + 200, width: 980, height: 50)
            NSString(string: dueText).draw(in: deadlineRect, withAttributes: deadlineAttributes)
            
            // フッター
            let footerAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 30),
                .foregroundColor: UIColor.lightGray
            ]
            let footerRect = CGRect(x: 0, y: 1400, width: 1080, height: 50)
            NSString(string: "KANJY アプリで作成").draw(in: footerRect, withAttributes: footerAttributes)
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
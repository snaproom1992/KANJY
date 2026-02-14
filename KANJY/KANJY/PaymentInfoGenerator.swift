import SwiftUI

struct PaymentInfoGenerator: View {
    @ObservedObject var viewModel: PrePlanViewModel
    @AppStorage("payPayID") private var payPayID = ""
    @AppStorage("bankInfo") private var bankInfo = ""
    
    // テキストフィールドの内容
    @State private var messageText = "お支払いよろしくお願いします。"
    @State private var dueText = "お支払い期限: 7日以内"
    
    @State private var selectedPaymentMethods: Set<PaymentMethod> = []

    @State private var generatedImage: UIImage?
    @State private var itemsToShare: [Any] = []
    @State private var isGeneratingImages = false
    @State private var showProgress = false
    @State private var progressValue = 0.0
    @State private var selectedParticipant: Participant? = nil
    @State private var previewImage: UIImage? = nil
    
    // トーンの定義
    enum TextTone: String, CaseIterable, Identifiable {
        case casual = "カジュアル"
        case formal = "フォーマル"
        case simple = "シンプル"
        
        var id: String { self.rawValue }
        
        var template: String {
            switch self {
            case .casual:
                return """
                昨日はお疲れ様！精算のお知らせです。
                楽しかったね！ありがとう。
                会費計算したので、画像で自分の金額確認してみてー！
                また飲もう！
                """
            case .formal:
                return """
                お疲れ様です。昨日の会費の精算詳細をご連絡します。
                各自の金額については添付の画像をご確認ください。
                よろしくお願いいたします。
                """
            case .simple:
                return """
                会費の集金案内です。
                各自の金額は添付の画像をご確認ください。
                期限内の送金をお願いします。
                """
            }
        }
    }
    
    @State private var selectedTone: TextTone = .casual
    
    enum PaymentMethod: String, CaseIterable, Identifiable {
        case payPay = "PayPay"
        case bankTransfer = "銀行振込"
        case cash = "現金"
        
        var id: String { self.rawValue }
        
        var icon: String {
            switch self {
            case .payPay: return "creditcard"
            case .bankTransfer: return "building.columns"
            case .cash: return "yensign.circle"
            }
        }
    }
    
    @State private var showingShareSheet = false
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 24) {
                    // STEP 1: 案内を作成（入力）

                    VStack(alignment: .leading, spacing: 16) {
                        Text("STEP 1: 案内を作成")
                            .font(DesignSystem.Typography.title3.weight(.bold))
                            .foregroundColor(DesignSystem.Colors.primary)
                            .padding(.horizontal)
                        
                        VStack(alignment: .leading, spacing: 24) {
                            paymentMethodContent
                                .padding(.horizontal)
                                .padding(.top)
                            
                            Divider()
                                .padding(.horizontal)
                            
                            messageCustomizationContent
                                .padding(.horizontal)
                                .padding(.bottom)
                        }
                        .background(DesignSystem.Colors.white)
                        .cornerRadius(DesignSystem.Card.cornerRadiusLarge)
                        .shadow(color: DesignSystem.Colors.gray3.opacity(0.2), radius: 8, x: 0, y: 4)
                    }
                    
                    // STEP 2: 確認と共有（出力）
                    VStack(alignment: .leading, spacing: 16) {
                        Text("STEP 2: 確認と共有")
                            .font(DesignSystem.Typography.title3.weight(.bold))
                            .foregroundColor(DesignSystem.Colors.primary)
                            .padding(.horizontal)
                        
                        VStack(spacing: 0) {
                            previewContent
                                .padding()
                        }
                        .background(DesignSystem.Colors.white)
                        .cornerRadius(DesignSystem.Card.cornerRadiusLarge)
                        .shadow(color: DesignSystem.Colors.gray3.opacity(0.2), radius: 8, x: 0, y: 4)
                    }
                }
                .padding(.vertical, 24)
                .padding(.horizontal, 16)
            }
            .background(DesignSystem.Colors.groupedBackground.edgesIgnoringSafeArea(.all))
            .navigationTitle("集金案内")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button(action: {
                            copyToClipboard()
                        }) {
                            Image(systemName: "doc.on.doc")
                        }
                        .disabled(selectedPaymentMethods.isEmpty)
                        
                        Button("共有") {
                            shareContent()
                        }
                        .disabled(selectedPaymentMethods.isEmpty || previewImage == nil)
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(activityItems: itemsToShare)
            }
            
            // コピー完了トースト
            if showCopyToast {
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.white)
                        Text(toastMessage)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(8)
                    .padding(.bottom, 50)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(1)
            }
        }
    }
    
    @State private var showCopyToast = false
    @State private var toastMessage = "テキストをコピーしました"
    
    private func copyToClipboard() {
        // 編集中のテキストをコピー
        let text = editablePaymentText
        UIPasteboard.general.string = text
        print("Clipboard text set: \(text)") // デバッグ用ログ
        
        showToast(message: "テキストをコピーしました")
    }
    
    private func copyImageToClipboard() {
        guard let image = previewImage else { return }
        
        UIPasteboard.general.image = image
        
        showToast(message: "画像をコピーしました")
    }
    
    private func showToast(message: String) {
        toastMessage = message
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        // アニメーション付きでトーストを表示
        withAnimation(.easeOut(duration: 0.3)) {
            showCopyToast = true
        }
        
        // 2秒後に非表示にする
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeIn(duration: 0.3)) {
                showCopyToast = false
            }
        }
    }
    
    private func generatePaymentText() -> String {
        var text = ""
        
        // ヘッダー
        text += "【集金のお願い】\n"
        text += "\(viewModel.editingPlanName)\n"
        
        if let date = viewModel.editingPlanDate {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ja_JP")
            formatter.dateFormat = "M月d日(E)"
            text += "開催日: \(formatter.string(from: date))\n" // 絵文字削除
        }
        
        text += "\n"
        
        // メッセージ・期限
        if !messageText.isEmpty {
            text += "\(messageText)\n"
        }
        if !dueText.isEmpty {
            text += "期限: \(dueText)\n" // 絵文字削除
        }
        
        text += "\n"
        
        // 金額確認の案内（トーンによっては重複するかもしれないが、確実に伝えるために残すか、シンプルにする）
        // トーンの文章に含まれている場合は重複を避ける判断も可能だが、
        // 今回は「画像を見てね」は重要なの念押しで入れておく。
        // ただしシンプルに。
        text += "■ 金額一覧\n"
        text += "添付の画像をご確認ください。\n\n"
        
        // 支払い方法
        text += "■ お支払い先\n"
        
        if selectedPaymentMethods.contains(.payPay) {
            text += "PayPay\n" // 絵文字削除
            if !payPayID.isEmpty {
                text += "ID: \(payPayID)\n"
                text += "(↑長押しでコピーできます)\n"
            } else {
                text += "ID: (未設定)\n"
            }
            text += "\n"
        }
        
        if selectedPaymentMethods.contains(.bankTransfer) {
            text += "銀行振込\n" // 絵文字削除
            if !bankInfo.isEmpty {
                text += "\(bankInfo)\n"
            } else {
                text += "(未設定)\n"
            }
            text += "\n"
        }
        
        if selectedPaymentMethods.contains(.cash) {
            text += "現金（当日手渡し）\n" // 絵文字削除
        }
        
        return text
    }
    
    // MARK: - 支払い方法セクション
    private var paymentMethodContent: some View {
        VStack(alignment: .leading, spacing: 16) { // Group -> VStack with spacing 16
            Text("支払い方法（複数選択可）")
                .font(DesignSystem.Typography.headline)
                .foregroundColor(DesignSystem.Colors.primary)
                .padding(.top, 4)
                
            ForEach(PaymentMethod.allCases) { method in
                paymentMethodRow(method)
            }
            // 警告と入力フィールドを表示
            paymentMethodInputs
        }
    }
    
    private func paymentMethodRow(_ method: PaymentMethod) -> some View {
        HStack {
            Image(systemName: method.icon)
                .foregroundColor(DesignSystem.Colors.primary)
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
                    
    private var paymentMethodInputs: some View {
        Group {
            // PayPay ID入力
            if selectedPaymentMethods.contains(.payPay) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    if payPayID.isEmpty {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(DesignSystem.Colors.warning)
                            Text("PayPay IDが未設定です")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.warning)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("PayPay ID")
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundColor(DesignSystem.Colors.secondary)
                        TextField("IDを入力 (例: kanji_taro_1234)", text: $payPayID)
                            .submitLabel(.done)
                            .padding(10)
                            .background(DesignSystem.Colors.background)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.TextField.cornerRadius)
                                    .stroke(DesignSystem.Colors.gray3, lineWidth: 1)
                            )
                            .cornerRadius(DesignSystem.TextField.cornerRadius)
                            .onChange(of: payPayID) { _, _ in
                                updatePreviewImage()
                            }
                    }
                }
                .padding(.vertical, DesignSystem.Spacing.sm)
            }
            
            // 銀行口座情報入力
            if selectedPaymentMethods.contains(.bankTransfer) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    if bankInfo.isEmpty {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(DesignSystem.Colors.warning)
                            Text("振込先情報が未設定です")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.warning)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("銀行振込先")
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundColor(DesignSystem.Colors.secondary)
                        TextField("振込先を入力 (例: 〇〇銀行 〇〇支店 普通 1234567 ヤマダタロウ)", text: $bankInfo, axis: .vertical)
                            .padding(10)
                            .background(DesignSystem.Colors.background)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.TextField.cornerRadius)
                                    .stroke(DesignSystem.Colors.gray3, lineWidth: 1)
                            )
                            .cornerRadius(DesignSystem.TextField.cornerRadius)
                            .lineLimit(2...4)
                            .onChange(of: bankInfo) { _, _ in
                                updatePreviewImage()
                            }
                    }
                }
                .padding(.vertical, DesignSystem.Spacing.sm)
            }
            
            if selectedPaymentMethods.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(DesignSystem.Colors.alert)
                    Text("少なくとも1つの支払い方法を選択してください")
                        .font(DesignSystem.Typography.footnote)
                        .foregroundColor(DesignSystem.Colors.alert)
                    Spacer()
                }
                .padding(.top, 4)
                .padding(.horizontal, 4)
                .padding(.bottom, 2)
            }
        }
    }
                
    // MARK: - メッセージカスタマイズセクション
    // MARK: - メッセージカスタマイズコンテンツ
    private var messageCustomizationContent: some View {
        VStack(alignment: .leading, spacing: 8) { // Group -> VStack with spacing 8 (tighter)
            Text("メッセージ設定")
                .font(DesignSystem.Typography.headline)
                .foregroundColor(DesignSystem.Colors.primary)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                messageHeader
                messageEditor
                dueDateSection
            }
            .padding(.vertical, DesignSystem.Spacing.xs)
        }
    }
    
    private var messageHeader: some View {
        HStack {
            Text("案内メッセージ")
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(DesignSystem.Colors.secondary)
                .padding(.top, DesignSystem.Spacing.xs / 2)
            
            Spacer()
            
            Picker("トーン", selection: $selectedTone) {
                ForEach(TextTone.allCases) { tone in
                    Text(tone.rawValue).tag(tone)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: selectedTone) { _, newTone in
                messageText = newTone.template
                updatePreviewImage()
            }
        }
        .padding(.bottom, DesignSystem.Spacing.xs)
    }
                        
    private var messageEditor: some View {
        Group {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $messageText)
                    .frame(minHeight: 90)
                    .padding(DesignSystem.Spacing.xs * 1.5) // 6 -> 6
                    .background(DesignSystem.Colors.background)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.TextField.cornerRadius)
                            .stroke(DesignSystem.Colors.gray3, lineWidth: 1)
                    )
                    .cornerRadius(DesignSystem.TextField.cornerRadius)
                    .onChange(of: messageText) { _, _ in
                        updatePreviewImage()
                    }
                
                if messageText.isEmpty {
                    Text("メッセージを入力してください")
                        .foregroundColor(Color(.placeholderText))
                        .padding(.horizontal, 10)
                        .padding(.top, 12)
                        .padding(.leading, 2)
                        .allowsHitTesting(false)
                }
            }
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
        .onAppear {
            // 初期表示時に現在選択されているトーンのテキストをセット
            if messageText == "お支払いよろしくお願いします。" { // デフォルト値の場合のみ
                 messageText = selectedTone.template
            }
        }
    }
                        
    private var dueDateSection: some View {
        Group {
            Text("支払い期限")
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(DesignSystem.Colors.secondary)
                .padding(.top, DesignSystem.Spacing.sm)
                .padding(.bottom, DesignSystem.Spacing.xs)
        
            TextField("お支払い期限: 7日以内", text: $dueText)
                .submitLabel(.done)
                .padding(10)
                .background(DesignSystem.Colors.background)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.TextField.cornerRadius)
                        .stroke(DesignSystem.Colors.gray3, lineWidth: 1)
                )
                .cornerRadius(DesignSystem.TextField.cornerRadius)
                .onChange(of: dueText) { _, _ in
                    updatePreviewImage()
                }
        }
    }
    
    // MARK: - プレビューセクション
    // MARK: - プレビューコンテンツ
    private var previewContent: some View {
        Group {
            if !viewModel.participants.isEmpty {
                // 画像プレビュー
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("画像プレビュー")
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundColor(DesignSystem.Colors.secondary)
                        Spacer()
                        if previewImage != nil {
                            Button(action: {
                                copyImageToClipboard()
                            }) {
                                HStack(spacing: DesignSystem.Spacing.xs) {
                                    Text("コピー")
                                        .font(DesignSystem.Typography.caption.weight(.bold))
                                    Image(systemName: "doc.on.doc")
                                        .font(DesignSystem.Typography.caption)
                                }
                                .foregroundColor(DesignSystem.Colors.white)
                                .padding(.vertical, DesignSystem.Spacing.xs)
                                .padding(.horizontal, DesignSystem.Spacing.sm)
                                .background(DesignSystem.Colors.primary)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    VStack(alignment: .center, spacing: 0) {
                        if let preview = previewImage {
                            Image(uiImage: preview)
                                .resizable()
                                .scaledToFit()
                                .padding(.top, DesignSystem.Spacing.xl)
                        } else {
                            Rectangle()
                                .fill(DesignSystem.Colors.gray1.opacity(0.2))
                                .frame(height: 300) // Placeholder remains fixed height
                                .cornerRadius(DesignSystem.Card.cornerRadiusLarge)
                                .overlay(
                                    VStack {
                                        if selectedPaymentMethods.isEmpty {
                                            Text("支払い方法を選択してください")
                                                .foregroundColor(DesignSystem.Colors.gray4)
                                        } else if isGeneratingImages {
                                            VStack {
                                                ProgressView()
                                                .padding(.bottom, 10)
                                                Text("プレビューを生成中...")
                                                .foregroundColor(DesignSystem.Colors.gray4)
                                            }
                                        } else {
                                            Text("プレビューを生成中...")
                                                .foregroundColor(DesignSystem.Colors.gray4)
                                        }
                                    }
                                )
                        }
                    }
                }
                
                // テキストプレビュー（編集可能）
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("テキストプレビュー")
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundColor(DesignSystem.Colors.secondary)
                        Spacer()
                        Button(action: {
                            copyToClipboard()
                        }) {
                            HStack(spacing: DesignSystem.Spacing.xs) {
                                Text("コピー")
                                    .font(DesignSystem.Typography.caption.weight(.bold))
                                    Image(systemName: "doc.on.doc")
                                    .font(DesignSystem.Typography.caption)
                            }
                            .foregroundColor(DesignSystem.Colors.white)
                            .padding(.vertical, DesignSystem.Spacing.xs)
                            .padding(.horizontal, DesignSystem.Spacing.sm)
                            .background(DesignSystem.Colors.primary)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        // テキストエディタ
                        TextEditor(text: $editablePaymentText)
                            .frame(minHeight: 200)
                            .font(DesignSystem.Typography.body)
                            .padding(DesignSystem.Spacing.xs)
                            .background(DesignSystem.Colors.background)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.TextField.cornerRadius)
                                    .stroke(DesignSystem.Colors.gray3, lineWidth: 1)
                            )
                        
                        // リセットボタン
                        HStack {
                            Spacer()
                            Button(action: {
                                editablePaymentText = generatePaymentText()
                                let generator = UINotificationFeedbackGenerator()
                                generator.notificationOccurred(.success)
                            }) {
                                HStack(spacing: DesignSystem.Spacing.xs) {
                                    Image(systemName: "arrow.counterclockwise")
                                    Text("設定内容からリセット")
                                }
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.secondary)
                                .padding(DesignSystem.Spacing.sm)
                                .background(DesignSystem.Colors.gray1)
                                .cornerRadius(DesignSystem.Spacing.sm)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                    }
                }
                .padding(.vertical, 8)
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
    
    // 編集用テキスト
    @State private var editablePaymentText: String = ""
    
    // プレビュー画像を更新
    private func updatePreviewImage() {
        // 支払い方法が選択されていない場合は早期リターン
        if selectedPaymentMethods.isEmpty {
            self.previewImage = nil
            return
        }
        
        // テキストも更新（ユーザーが未編集、または強制更新の場合）
        // ここではシンプルに、設定変更時は常に再生成して反映させる
        // ただし、ユーザーが編集中の場合は上書きしない方が親切だが、
        // 設定を変えたのに反映されないのも混乱の元なので、
        // 今回は「設定変更＝テキスト再生成」とする。
        // ※編集内容は「リセット」で戻せるようにしてあるため。
        editablePaymentText = generatePaymentText()
        
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
    
    // 画像とテキストを共有
    // 画像とテキストを共有
    private func shareContent() {
        guard let image = previewImage else {
            updatePreviewImage()
            return
        }
        
        // テキストと画像をセットで共有
        itemsToShare = [editablePaymentText, image]
        showingShareSheet = true
    }
    
    // 全員分の一覧表画像を生成
    private func generatePaymentSummaryImage() -> UIImage {
        // 基本デザイン定数
        let padding: CGFloat = 40
        
        // 基本色の定義
        let primaryColor = DesignSystem.Colors.uiPrimary
        let backgroundColor = DesignSystem.Colors.uiBackground
        let cardColor = DesignSystem.Colors.uiWhite
        let textColor = DesignSystem.Colors.uiText
        let lightGrayColor = DesignSystem.Colors.uiLightGray

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
        
        // 基本高さ（最低限必要な高さ）- イベント名と開催日のみ
        var totalContentHeight: CGFloat = 120
        
        // 参加者リストセクション（存在する場合）
        if !viewModel.participants.isEmpty {
            // 行の高さ
            let rowHeight: CGFloat = 70
            // 参加者リストの高さを計算（ヘッダー + 参加者行 + 余白）
            let participantsCount = min(viewModel.participants.count, 20)
            let participantsSectionHeight = 50.0 + CGFloat(participantsCount) * rowHeight + 50
            totalContentHeight += participantsSectionHeight + padding
            
            // 合計金額と内訳セクションは削除（シンプル化のため）
            // リクエストがあれば復活させる方針
        } else {
            // 参加者がいない場合の高さを確保
            totalContentHeight += 200
        }
        
        // フッター用の余白
        totalContentHeight += 60 // フッター用に少し広げる
        
        // カードの高さ（コンテンツの高さ + 上下のパディング + 余裕を持たせる）
        let cardHeight = totalContentHeight + (padding * 2)
        
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
            context.cgContext.setShadow(offset: CGSize(width: 0, height: 5), blur: 12, color: DesignSystem.Colors.uiBlack.withAlphaComponent(0.1).cgColor)
            UIBezierPath(roundedRect: contentRect, cornerRadius: 16).stroke()
            context.cgContext.setShadow(offset: .zero, blur: 0, color: nil)
            
            // カード内の有効領域を計算
            let cardContentX = contentRect.origin.x + padding
            let cardContentY = contentRect.origin.y + padding
            let cardContentWidth = contentRect.width - (padding * 2)
            
            // セクション内部のパディング
            let sectionPadding: CGFloat = 15
            
            // タイトル（金額一覧）
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: titleFontSize, weight: .bold),
                .foregroundColor: DesignSystem.Colors.uiWhite
            ]
            let titleRect = CGRect(x: 50, y: 60, width: 980, height: 60)
            NSString(string: "参加者リスト").draw(in: titleRect, withAttributes: titleAttributes)
            
            // イベント名と開催日のセクション背景
            let eventSectionRect = CGRect(x: cardContentX, y: cardContentY, width: cardContentWidth, height: 120) // 高さを縮小
            DesignSystem.Colors.uiPrimaryLight.setFill() // 薄い水色の背景
            UIBezierPath(roundedRect: eventSectionRect, cornerRadius: 12).fill()
            
            // イベント名（最も目立つように）
            let eventNameRect = CGRect(
                x: eventSectionRect.origin.x + sectionPadding,
                y: eventSectionRect.origin.y + sectionPadding,
                width: eventSectionRect.width - (sectionPadding * 2),
                height: 70
            )
            let eventAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: mainTitleFontSize, weight: .bold),
                .foregroundColor: primaryColor
            ]
            NSString(string: viewModel.editingPlanName).draw(in: eventNameRect, withAttributes: eventAttributes)
            
            // 開催日を追加
            if let planDate = viewModel.editingPlanDate {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy年M月d日(EEEE)"
                dateFormatter.locale = Locale(identifier: "ja_JP")
                let dateString = dateFormatter.string(from: planDate)
                
                let dateAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: bodyFontSize, weight: .medium),
                    .foregroundColor: textColor
                ]
                let dateRect = CGRect(
                    x: eventSectionRect.origin.x + sectionPadding,
                    y: eventNameRect.maxY + 5,
                    width: eventSectionRect.width - (sectionPadding * 2),
                    height: 30
                )
                NSString(string: "開催日: \(dateString)").draw(in: dateRect, withAttributes: dateAttributes)
            }
            // メッセージ描画を削除
            
            // 区切り線
            DesignSystem.Colors.uiLightGray.setStroke()
            let dividerPath = UIBezierPath()
            dividerPath.move(to: CGPoint(x: cardContentX, y: eventSectionRect.maxY + padding))
            dividerPath.addLine(to: CGPoint(x: cardContentX + cardContentWidth, y: eventSectionRect.maxY + padding))
            dividerPath.lineWidth = 1
            dividerPath.stroke()
            
            // 参加者リストヘッダーと支払い済み凡例の位置を調整
            let participantsY = eventSectionRect.maxY + padding + 20
            
            // 行の高さを定義
            let rowHeight: CGFloat = 70.0 // 行の高さ
            
            if viewModel.participants.isEmpty {
                // 参加者がいない場合
                let emptyTextAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: subheadingFontSize),
                    .foregroundColor: DesignSystem.Colors.uiSecondaryText
                ]
                let emptyRect = CGRect(x: cardContentX, y: participantsY + 50, width: cardContentWidth, height: 50)
                let emptyString = NSString(string: "参加者が登録されていません")
                
                // 中央揃えスタイル
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.alignment = .center
                
                var centeredAttributes = emptyTextAttributes
                centeredAttributes[.paragraphStyle] = paragraphStyle
                
                emptyString.draw(in: emptyRect, withAttributes: centeredAttributes)
            } else {
                // 参加者セクション全体を囲む背景（uiPrimaryLightAlt）を削除
                // シンプルに白背景（カード自体の色）のままにする
                // let participantsSectionRect = ... (使用しない)
                // DesignSystem.Colors.uiPrimaryLightAlt.setFill()
                // UIBezierPath(...).fill()
                
                // "参加者一覧"というテキスト描画を削除（タイトルと重複するため）
                // 凡例表示は維持
                
                // 支払い済み凡例
                let legendCircleRect = CGRect(x: 850, y: participantsY + 20, width: 24, height: 24)
                primaryColor.setFill()
                UIBezierPath(ovalIn: legendCircleRect).fill()
                
                let legendCheckAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 16, weight: .bold),
                    .foregroundColor: DesignSystem.Colors.uiWhite
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
                DesignSystem.Colors.uiLightGray.setStroke()
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
                    .foregroundColor: DesignSystem.Colors.uiSecondaryText
                ]
                
                // 参加者数に応じて表示数を調整（最大20人まで表示）
                let maxVisibleRows = 20
                let sortedParticipants = viewModel.participants.sorted { $0.name < $1.name }
                let displayedParticipants = sortedParticipants.prefix(maxVisibleRows)
                
                for (index, participant) in displayedParticipants.enumerated() {
                    // 背景（交互に色を変える）
                    if index % 2 == 0 {
                        DesignSystem.Colors.uiWhite.setFill()
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
                            .foregroundColor: DesignSystem.Colors.uiWhite
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
                        .foregroundColor: DesignSystem.Colors.uiSecondaryText
                    ]
                    let noteRect = CGRect(x: 70, y: yOffset + 10, width: 940, height: 30)
                    NSString(string: "※他 \(sortedParticipants.count - maxVisibleRows) 名の参加者がいます").draw(in: noteRect, withAttributes: noteAttributes)
                    
                    yOffset += 50
                }
            } // end if !viewModel.participants.isEmpty
            
            // フッター（アプリ名と日時）
            let footerDate = Date()
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy/MM/dd HH:mm"
            let dateStr = dateFormatter.string(from: footerDate)
            
            let footerAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: smallFontSize - 4, weight: .medium),
                .foregroundColor: DesignSystem.Colors.uiSecondaryText.withAlphaComponent(0.8)
            ]
            let footerString = "Generated by KANJY - \(dateStr)" as NSString
            let footerSize = footerString.size(withAttributes: footerAttributes)
            
            let footerRect = CGRect(
                x: contentRect.maxX - footerSize.width - padding,
                y: contentRect.maxY - 30,
                width: footerSize.width,
                height: 30
            )
            footerString.draw(in: footerRect, withAttributes: footerAttributes)
        }
        
        return image
    }
}

#Preview {
    PaymentInfoGenerator(viewModel: PrePlanViewModel())
}


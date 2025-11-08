import SwiftUI

struct EventInvitationGenerator: View {
    @ObservedObject var viewModel: PrePlanViewModel
    @Environment(\.dismiss) private var dismiss
    
    let confirmedDate: Date
    let confirmedLocation: String?
    let confirmedParticipants: [Participant]
    let planName: String
    let planEmoji: String
    
    @State private var messageText = "お待ちしております！"
    @State private var meetingPlace: String = ""
    @State private var meetingTime: String = ""
    @State private var notes: String = ""
    @State private var previewImage: UIImage?
    @State private var showingShareSheet = false
    @State private var isGeneratingImage = false
    
    // 定型文の配列
    private let messageTemplates = [
        "お待ちしております！",
        "みんなで楽しい時間を過ごしましょう！",
        "お会いできるのを楽しみにしています！",
        "ぜひご参加ください！",
        "お気軽にご参加ください！",
        "お待ちしています！",
        "楽しみにしています！",
        "ぜひお越しください！"
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Form {
                    eventInfoSection
                    messageCustomizationSection
                    additionalInfoSection
                    previewSection
                }
                .navigationTitle("開催案内作成")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("キャンセル") {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("共有") {
                            showingShareSheet = true
                        }
                        .disabled(previewImage == nil)
                    }
                }
                .sheet(isPresented: $showingShareSheet) {
                    if let image = previewImage {
                        ShareSheet(activityItems: [image])
                    }
                }
                .onAppear {
                    updatePreviewImage()
                }
            }
        }
    }
    
    // MARK: - イベント情報セクション
    private var eventInfoSection: some View {
        Section(header: Text("イベント情報")) {
            HStack {
                Text(planEmoji)
                    .font(.system(size: 40))
                Text(planName)
                    .font(DesignSystem.Typography.headline)
                Spacer()
            }
            .padding(.vertical, DesignSystem.Spacing.xs)
            
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(DesignSystem.Colors.primary)
                Text(formatDateTime(confirmedDate))
                    .font(DesignSystem.Typography.body)
            }
            .padding(.vertical, DesignSystem.Spacing.xs)
            
            if let location = confirmedLocation, !location.isEmpty {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(DesignSystem.Colors.primary)
                    Text(location)
                        .font(DesignSystem.Typography.body)
                }
                .padding(.vertical, DesignSystem.Spacing.xs)
            }
            
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundColor(DesignSystem.Colors.primary)
                Text("参加者: \(confirmedParticipants.count)人")
                    .font(DesignSystem.Typography.body)
            }
            .padding(.vertical, DesignSystem.Spacing.xs)
        }
    }
    
    // MARK: - メッセージカスタマイズセクション
    private var messageCustomizationSection: some View {
        Section(header: Text("メッセージ")) {
            TextField("メッセージを入力", text: $messageText, axis: .vertical)
                .lineLimit(3...6)
                .onChange(of: messageText) { _, _ in
                    updatePreviewImage()
                }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(messageTemplates, id: \.self) { template in
                        Button(action: {
                            messageText = template
                            updatePreviewImage()
                        }) {
                            Text(template)
                                .font(DesignSystem.Typography.caption)
                                .padding(.horizontal, DesignSystem.Spacing.sm)
                                .padding(.vertical, DesignSystem.Spacing.xs)
                                .background(
                                    RoundedRectangle(cornerRadius: DesignSystem.Card.cornerRadiusSmall, style: .continuous)
                                        .fill(messageText == template ? DesignSystem.Colors.primary.opacity(0.2) : DesignSystem.Colors.gray1)
                                )
                                .foregroundColor(messageText == template ? DesignSystem.Colors.primary : DesignSystem.Colors.black)
                        }
                    }
                }
                .padding(.vertical, DesignSystem.Spacing.xs)
            }
        }
    }
    
    // MARK: - 追加情報セクション
    private var additionalInfoSection: some View {
        Section(header: Text("追加情報（任意）")) {
            TextField("集合場所", text: $meetingPlace)
                .onChange(of: meetingPlace) { _, _ in
                    updatePreviewImage()
                }
            
            TextField("集合時間", text: $meetingTime)
                .onChange(of: meetingTime) { _, _ in
                    updatePreviewImage()
                }
            
            TextField("持ち物・注意事項", text: $notes, axis: .vertical)
                .lineLimit(2...4)
                .onChange(of: notes) { _, _ in
                    updatePreviewImage()
                }
        }
    }
    
    // MARK: - プレビューセクション
    private var previewSection: some View {
        Section(header: Text("プレビュー")) {
            if isGeneratingImage {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if let image = previewImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(DesignSystem.Card.cornerRadius)
            } else {
                Text("プレビューを生成中...")
                    .foregroundColor(DesignSystem.Colors.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
    }
    
    // MARK: - プレビュー画像を更新
    private func updatePreviewImage() {
        isGeneratingImage = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let image = self.generateInvitationImage()
            DispatchQueue.main.async {
                self.previewImage = image
                self.isGeneratingImage = false
            }
        }
    }
    
    // MARK: - 開催案内画像を生成
    private func generateInvitationImage() -> UIImage {
        let padding: CGFloat = 40
        let cardWidth: CGFloat = 1000
        let cardContentWidth = cardWidth - (padding * 2)
        
        // 基本色の定義
        let primaryColor = UIColor(red: 0.0, green: 0.4, blue: 0.8, alpha: 1.0)
        let backgroundColor = UIColor(red: 0.98, green: 0.98, blue: 0.99, alpha: 1.0)
        let cardColor = UIColor.white
        let textColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        let secondaryTextColor = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        
        // フォントサイズ
        let emojiFontSize: CGFloat = 80
        let titleFontSize: CGFloat = 48
        let headingFontSize: CGFloat = 32
        let bodyFontSize: CGFloat = 28
        let captionFontSize: CGFloat = 24
        
        // 高さを計算
        var totalHeight: CGFloat = padding * 2
        
        // 絵文字とタイトル
        totalHeight += emojiFontSize + 20
        totalHeight += titleFontSize + 30
        
        // 日時・場所
        totalHeight += headingFontSize + 20
        totalHeight += bodyFontSize + 15
        if confirmedLocation != nil && !confirmedLocation!.isEmpty {
            totalHeight += bodyFontSize + 15
        }
        
        // 参加者
        totalHeight += headingFontSize + 20
        totalHeight += bodyFontSize + 15
        
        // メッセージ
        if !messageText.isEmpty {
            totalHeight += headingFontSize + 20
            let messageHeight = messageText.height(withConstrainedWidth: cardContentWidth - 40, font: UIFont.systemFont(ofSize: bodyFontSize))
            totalHeight += messageHeight + 15
        }
        
        // 追加情報
        if !meetingPlace.isEmpty || !meetingTime.isEmpty || !notes.isEmpty {
            totalHeight += headingFontSize + 20
            if !meetingPlace.isEmpty {
                totalHeight += bodyFontSize + 10
            }
            if !meetingTime.isEmpty {
                totalHeight += bodyFontSize + 10
            }
            if !notes.isEmpty {
                let notesHeight = notes.height(withConstrainedWidth: cardContentWidth - 40, font: UIFont.systemFont(ofSize: captionFontSize))
                totalHeight += notesHeight + 10
            }
        }
        
        totalHeight += padding
        
        // 画像を生成
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: cardWidth, height: totalHeight))
        let image = renderer.image { context in
            let cgContext = context.cgContext
            
            // 背景
            backgroundColor.setFill()
            cgContext.fill(CGRect(x: 0, y: 0, width: cardWidth, height: totalHeight))
            
            // カード背景
            cardColor.setFill()
            let cardRect = CGRect(x: padding, y: padding, width: cardContentWidth, height: totalHeight - padding * 2)
            let cardPath = UIBezierPath(roundedRect: cardRect, cornerRadius: 24)
            cardPath.fill()
            
            // 影
            cgContext.setShadow(offset: CGSize(width: 0, height: 4), blur: 12, color: UIColor.black.withAlphaComponent(0.1).cgColor)
            cardPath.fill()
            cgContext.setShadow(offset: .zero, blur: 0, color: nil)
            
            var currentY: CGFloat = padding + 40
            
            // 絵文字とタイトル
            let emojiAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: emojiFontSize)
            ]
            let emojiRect = CGRect(x: padding + 20, y: currentY, width: cardContentWidth - 40, height: emojiFontSize)
            planEmoji.draw(in: emojiRect, withAttributes: emojiAttributes)
            currentY += emojiFontSize + 20
            
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: titleFontSize),
                .foregroundColor: textColor
            ]
            let titleRect = CGRect(x: padding + 20, y: currentY, width: cardContentWidth - 40, height: titleFontSize + 10)
            planName.draw(in: titleRect, withAttributes: titleAttributes)
            currentY += titleFontSize + 30
            
            // 日時
            let headingAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: headingFontSize),
                .foregroundColor: primaryColor
            ]
            "📅 日時".draw(at: CGPoint(x: padding + 20, y: currentY), withAttributes: headingAttributes)
            currentY += headingFontSize + 10
            
            let bodyAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: bodyFontSize),
                .foregroundColor: textColor
            ]
            formatDateTime(confirmedDate).draw(at: CGPoint(x: padding + 40, y: currentY), withAttributes: bodyAttributes)
            currentY += bodyFontSize + 15
            
            // 場所
            if let location = confirmedLocation, !location.isEmpty {
                "📍 場所".draw(at: CGPoint(x: padding + 20, y: currentY), withAttributes: headingAttributes)
                currentY += headingFontSize + 10
                location.draw(at: CGPoint(x: padding + 40, y: currentY), withAttributes: bodyAttributes)
                currentY += bodyFontSize + 15
            }
            
            // 参加者
            "👥 参加者".draw(at: CGPoint(x: padding + 20, y: currentY), withAttributes: headingAttributes)
            currentY += headingFontSize + 10
            "\(confirmedParticipants.count)人".draw(at: CGPoint(x: padding + 40, y: currentY), withAttributes: bodyAttributes)
            currentY += bodyFontSize + 20
            
            // メッセージ
            if !messageText.isEmpty {
                "💬 メッセージ".draw(at: CGPoint(x: padding + 20, y: currentY), withAttributes: headingAttributes)
                currentY += headingFontSize + 10
                
                let messageAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: bodyFontSize),
                    .foregroundColor: textColor
                ]
                let messageRect = CGRect(x: padding + 40, y: currentY, width: cardContentWidth - 80, height: 200)
                messageText.draw(in: messageRect, withAttributes: messageAttributes)
                let messageHeight = messageText.height(withConstrainedWidth: cardContentWidth - 80, font: UIFont.systemFont(ofSize: bodyFontSize))
                currentY += messageHeight + 20
            }
            
            // 追加情報
            if !meetingPlace.isEmpty || !meetingTime.isEmpty || !notes.isEmpty {
                "📋 詳細情報".draw(at: CGPoint(x: padding + 20, y: currentY), withAttributes: headingAttributes)
                currentY += headingFontSize + 10
                
                let captionAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: captionFontSize),
                    .foregroundColor: secondaryTextColor
                ]
                
                if !meetingPlace.isEmpty {
                    "集合場所: \(meetingPlace)".draw(at: CGPoint(x: padding + 40, y: currentY), withAttributes: captionAttributes)
                    currentY += captionFontSize + 10
                }
                
                if !meetingTime.isEmpty {
                    "集合時間: \(meetingTime)".draw(at: CGPoint(x: padding + 40, y: currentY), withAttributes: captionAttributes)
                    currentY += captionFontSize + 10
                }
                
                if !notes.isEmpty {
                    let notesRect = CGRect(x: padding + 40, y: currentY, width: cardContentWidth - 80, height: 200)
                    notes.draw(in: notesRect, withAttributes: captionAttributes)
                    let notesHeight = notes.height(withConstrainedWidth: cardContentWidth - 80, font: UIFont.systemFont(ofSize: captionFontSize))
                    currentY += notesHeight + 10
                }
            }
        }
        
        return image
    }
    
    // MARK: - 日時フォーマット
    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月d日(E) HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - String Extension
extension String {
    func height(withConstrainedWidth width: CGFloat, font: UIFont) -> CGFloat {
        let constraintRect = CGSize(width: width, height: .greatestFiniteMagnitude)
        let boundingBox = self.boundingRect(with: constraintRect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [NSAttributedString.Key.font: font], context: nil)
        return ceil(boundingBox.height)
    }
}



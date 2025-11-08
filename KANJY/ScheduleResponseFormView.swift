import SwiftUI

struct ScheduleResponseFormView: View {
    let event: ScheduleEvent
    @State private var participantName: String = ""
    @State private var participantStatus: AttendanceStatus = .attending
    @State private var selectedDates: Set<Date> = []
    @State private var comment: String = ""
    @State private var department: String = ""
    @State private var isSubmitting = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isSubmissionSuccessful = false
    
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    
    enum Field {
        case name, department, comment
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // イベント概要
                    EventSummaryCard(event: event)
                    
                    // 基本情報入力
                    BasicInfoCard(
                        participantName: $participantName,
                        department: $department,
                        focusedField: $focusedField
                    )
                    
                    // 参加状況選択
                    ParticipationStatusCard(
                        participantStatus: $participantStatus,
                        selectedDates: $selectedDates
                    )
                    
                    // 日時選択（参加の場合のみ表示）
                    if participantStatus == .attending {
                        DateSelectionCard(
                            candidateDates: event.candidateDates,
                            selectedDates: $selectedDates
                        )
                    }
                    
                    // コメント入力
                    CommentCard(
                        comment: $comment,
                        focusedField: $focusedField
                    )
                    
                    // 送信ボタン
                    SubmitButton(
                        isSubmitting: isSubmitting,
                        canSubmit: canSubmit,
                        onSubmit: submitResponse
                    )
                }
                .padding(20)
            }
            .navigationTitle("出欠回答")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(false)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
        }
        .alert("回答送信", isPresented: $showingAlert) {
            Button("OK") {
                if isSubmissionSuccessful {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var canSubmit: Bool {
        !participantName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func submitResponse() {
        guard canSubmit else { return }
        
        isSubmitting = true
        
        // シンプルな仕様に変更：選択した日程は全て参加確定
        let finalAvailableDates = Array(selectedDates)
        let finalMaybeDates: [Date] = []
        
        let response = ScheduleResponse(
            participantName: participantName.trimmingCharacters(in: .whitespacesAndNewlines),
            availableDates: finalAvailableDates,
            maybeDates: finalMaybeDates,
            status: participantStatus,
            comment: comment.isEmpty ? nil : comment,
            department: department.isEmpty ? nil : department
        )
        
        Task {
            do {
                try await AttendanceManager.shared.addResponseToSupabase(eventId: event.id, response: response)
                
                await MainActor.run {
                    isSubmitting = false
                    isSubmissionSuccessful = true
                    alertMessage = "回答を送信しました！"
                    showingAlert = true
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    isSubmissionSuccessful = false
                    alertMessage = "送信に失敗しました: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
    }
}

// MARK: - イベントサマリーカード

struct EventSummaryCard: View {
    let event: ScheduleEvent
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "calendar.badge.plus")
                    .foregroundColor(DesignSystem.Colors.primary)
                    .font(.system(size: DesignSystem.Icon.Size.xlarge, weight: DesignSystem.Typography.FontWeight.medium))
                
                Text(event.title)
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.black)
                
                Spacer()
            }
            
            if let description = event.description {
                Text(description)
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(DesignSystem.Colors.secondary)
            }
            
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "calendar")
                    .foregroundColor(DesignSystem.Colors.primary)
                    .frame(width: DesignSystem.Icon.Size.medium)
                
                Text("候補日時: \(event.candidateDates.count)件")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(DesignSystem.Colors.secondary)
                
                Spacer()
                
                if let deadline = event.deadline {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "clock")
                            .foregroundColor(DesignSystem.Colors.warning)
                            .font(.system(size: DesignSystem.Icon.Size.small))
                        
                        Text("期限: \(formatDate(deadline))")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.warning)
                    }
                }
            }
        }
        .padding(DesignSystem.Card.Padding.medium)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Card.cornerRadiusLarge, style: .continuous)
                .fill(DesignSystem.Colors.primary.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Card.cornerRadiusLarge, style: .continuous)
                        .stroke(DesignSystem.Colors.primary.opacity(0.3), lineWidth: DesignSystem.Card.borderWidth)
                )
        )
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - 基本情報入力カード

struct BasicInfoCard: View {
    @Binding var participantName: String
    @Binding var department: String
    var focusedField: FocusState<ScheduleResponseFormView.Field?>.Binding
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            Text("基本情報")
                .font(DesignSystem.Typography.headline)
                .foregroundColor(DesignSystem.Colors.black)
            
            VStack(spacing: DesignSystem.Spacing.md) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Text("お名前")
                            .font(DesignSystem.Typography.emphasizedSubheadline)
                            .foregroundColor(DesignSystem.Colors.black)
                        
                        Text("*")
                            .foregroundColor(DesignSystem.Colors.alert)
                    }
                    
                    TextField("山田太郎", text: $participantName)
                        .standardTextFieldStyle()
                        .focused(focusedField, equals: .name)
                }
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("所属・部署（任意）")
                        .font(DesignSystem.Typography.emphasizedSubheadline)
                        .foregroundColor(DesignSystem.Colors.black)
                    
                    TextField("営業部", text: $department)
                        .standardTextFieldStyle()
                        .focused(focusedField, equals: .department)
                }
            }
        }
        .padding(DesignSystem.Card.Padding.large)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Card.cornerRadiusLarge, style: .continuous)
                .fill(DesignSystem.Colors.background)
                .shadow(
                    color: Color.black.opacity(DesignSystem.Card.Shadow.opacity),
                    radius: DesignSystem.Card.Shadow.radius,
                    x: DesignSystem.Card.Shadow.offset.width,
                    y: DesignSystem.Card.Shadow.offset.height
                )
        )
    }
}

// MARK: - 参加状況選択カード

struct ParticipationStatusCard: View {
    @Binding var participantStatus: AttendanceStatus
    @Binding var selectedDates: Set<Date>
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            Text("参加状況")
                .font(DesignSystem.Typography.headline)
                .foregroundColor(DesignSystem.Colors.black)
            
            Text("参加状況を選択してください。")
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(DesignSystem.Colors.secondary)
            
            VStack(spacing: DesignSystem.Spacing.lg) {
                ForEach([AttendanceStatus.attending, .notAttending, .maybe], id: \.self) { status in
                    ParticipationStatusRow(
                        status: status,
                        isSelected: participantStatus == status,
                        onSelectionChanged: {
                            participantStatus = status
                            // 参加以外を選択した場合は日程選択をクリア
                            if status != .attending {
                                selectedDates.removeAll()
                            }
                        }
                    )
                }
            }
        }
        .padding(DesignSystem.Card.Padding.large)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Card.cornerRadiusLarge, style: .continuous)
                .fill(DesignSystem.Colors.background)
                .shadow(
                    color: Color.black.opacity(DesignSystem.Card.Shadow.opacity),
                    radius: DesignSystem.Card.Shadow.radius,
                    x: DesignSystem.Card.Shadow.offset.width,
                    y: DesignSystem.Card.Shadow.offset.height
                )
        )
    }
}

struct ParticipationStatusRow: View {
    let status: AttendanceStatus
    let isSelected: Bool
    let onSelectionChanged: () -> Void
    
    var body: some View {
        Button(action: onSelectionChanged) {
            HStack(spacing: DesignSystem.Spacing.lg) {
                // ラジオボタン（ステータス色に合わせる）
                ZStack {
                    Circle()
                        .stroke(isSelected ? status.color : DesignSystem.Colors.gray3, lineWidth: 2)
                        .frame(width: DesignSystem.Icon.Size.medium, height: DesignSystem.Icon.Size.medium)
                        .animation(.easeInOut(duration: 0.2), value: isSelected)
                    
                    if isSelected {
                        Circle()
                            .fill(status.color)
                            .frame(width: DesignSystem.Icon.Size.small, height: DesignSystem.Icon.Size.small)
                            .scaleEffect(isSelected ? 1.0 : 0.5)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
                    }
                }
                
                // ステータスアイコン
                Image(systemName: status.icon)
                    .font(.system(size: DesignSystem.Icon.Size.xlarge, weight: DesignSystem.Typography.FontWeight.medium))
                    .foregroundColor(status.color)
                    .frame(width: DesignSystem.Icon.Size.xlarge)
                
                // ステータステキスト
                Text(status.rawValue)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.black)
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.xl)
            .padding(.horizontal, DesignSystem.Spacing.xl)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Card.cornerRadiusLarge, style: .continuous)
                    .fill(isSelected ? status.color.opacity(0.05) : DesignSystem.Colors.background)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.Card.cornerRadiusLarge, style: .continuous)
                            .stroke(isSelected ? status.color.opacity(0.3) : DesignSystem.Colors.gray3, lineWidth: DesignSystem.Card.borderWidth)
                    )
                    .animation(.easeInOut(duration: 0.2), value: isSelected)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 日時選択カード

struct DateSelectionCard: View {
    let candidateDates: [Date]
    @Binding var selectedDates: Set<Date>
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            Text("参加可能な日程")
                .font(DesignSystem.Typography.headline)
                .foregroundColor(DesignSystem.Colors.black)
            
            Text("参加可能な日程をチェックボックスで選択してください。")
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(DesignSystem.Colors.secondary)
            
            VStack(spacing: DesignSystem.Spacing.md) {
                ForEach(candidateDates.sorted(), id: \.self) { date in
                    DateCheckboxRow(
                        date: date,
                        isSelected: selectedDates.contains(date),
                        onSelectionChanged: { isSelected in
                            if isSelected {
                                selectedDates.insert(date)
                            } else {
                                selectedDates.remove(date)
                            }
                        }
                    )
                }
            }
        }
        .padding(DesignSystem.Card.Padding.large)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Card.cornerRadiusLarge, style: .continuous)
                .fill(DesignSystem.Colors.background)
                .shadow(
                    color: Color.black.opacity(DesignSystem.Card.Shadow.opacity),
                    radius: DesignSystem.Card.Shadow.radius,
                    x: DesignSystem.Card.Shadow.offset.width,
                    y: DesignSystem.Card.Shadow.offset.height
                )
        )
    }
}

struct DateCheckboxRow: View {
    let date: Date
    let isSelected: Bool
    let onSelectionChanged: (Bool) -> Void
    
    var body: some View {
        Button(action: {
            onSelectionChanged(!isSelected)
        }) {
            HStack(spacing: DesignSystem.Spacing.md) {
                // チェックボックス
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: DesignSystem.Icon.Size.xlarge, weight: DesignSystem.Typography.FontWeight.medium))
                    .foregroundColor(isSelected ? DesignSystem.Colors.primary : DesignSystem.Colors.gray4)
                
                // 日時情報
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(formatDate(date))
                        .font(DesignSystem.Typography.emphasizedSubheadline)
                        .foregroundColor(DesignSystem.Colors.black)
                    
                    Text(formatTime(date))
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.secondary)
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.md)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Card.cornerRadiusSmall, style: .continuous)
                    .fill(isSelected ? DesignSystem.Colors.primary.opacity(0.1) : DesignSystem.Colors.gray1)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.Card.cornerRadiusSmall, style: .continuous)
                            .stroke(isSelected ? DesignSystem.Colors.primary : Color.clear, lineWidth: DesignSystem.Card.borderWidth)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日(E)"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - コメントカード

struct CommentCard: View {
    @Binding var comment: String
    var focusedField: FocusState<ScheduleResponseFormView.Field?>.Binding
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            Text("コメント（任意）")
                .font(DesignSystem.Typography.headline)
                .foregroundColor(DesignSystem.Colors.black)
            
            TextField("遅れるかもしれません、予算について相談したいです など", text: $comment, axis: .vertical)
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.black)
                .padding(DesignSystem.TextField.Padding.horizontal)
                .frame(minHeight: DesignSystem.TextField.Height.medium)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.TextField.cornerRadius, style: .continuous)
                        .fill(focusedField.wrappedValue == .comment ? DesignSystem.TextField.focusedBackgroundColor : DesignSystem.TextField.backgroundColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.TextField.cornerRadius, style: .continuous)
                        .stroke(focusedField.wrappedValue == .comment ? DesignSystem.TextField.focusedBorderColor : DesignSystem.TextField.borderColor, lineWidth: DesignSystem.TextField.borderWidth)
                )
                .focused(focusedField, equals: .comment)
                .lineLimit(3...6)
        }
        .padding(DesignSystem.Card.Padding.large)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Card.cornerRadiusLarge, style: .continuous)
                .fill(DesignSystem.Colors.background)
                .shadow(
                    color: Color.black.opacity(DesignSystem.Card.Shadow.opacity),
                    radius: DesignSystem.Card.Shadow.radius,
                    x: DesignSystem.Card.Shadow.offset.width,
                    y: DesignSystem.Card.Shadow.offset.height
                )
        )
    }
}

// MARK: - 送信ボタン

struct SubmitButton: View {
    let isSubmitting: Bool
    let canSubmit: Bool
    let onSubmit: () -> Void
    
    var body: some View {
        Button(action: onSubmit) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                if isSubmitting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.Colors.white))
                        .scaleEffect(0.8)
                }
                
                Text(isSubmitting ? "送信中..." : "回答を送信")
                    .font(DesignSystem.Typography.headline)
            }
            .frame(maxWidth: .infinity)
            .frame(height: DesignSystem.Button.Size.large)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Card.cornerRadiusLarge, style: .continuous)
                    .fill(canSubmit ? DesignSystem.Colors.primary : DesignSystem.Colors.gray4)
            )
            .foregroundColor(DesignSystem.Colors.white)
        }
        .disabled(!canSubmit || isSubmitting)
    }
}

// MARK: - プレビュー

#Preview {
    let sampleEvent = ScheduleEvent(
        id: UUID(),
        title: "忘年会のスケジュール調整",
        description: "今年一年お疲れ様でした！",
        candidateDates: [
            Calendar.current.date(byAdding: .day, value: 7, to: Date())!,
            Calendar.current.date(byAdding: .day, value: 14, to: Date())!
        ],
        responses: [],
        createdBy: "山田太郎",
        createdAt: Date()
    )
    
    ScheduleResponseFormView(event: sampleEvent)
} 
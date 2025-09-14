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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar.badge.plus")
                    .foregroundColor(.blue)
                    .font(.title3)
                
                Text(event.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            if let description = event.description {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.blue)
                    .frame(width: 16)
                
                Text("候補日時: \(event.candidateDates.count)件")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let deadline = event.deadline {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .foregroundColor(.orange)
                            .font(.caption)
                        
                        Text("期限: \(formatDate(deadline))")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.blue.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
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
        VStack(alignment: .leading, spacing: 16) {
            Text("基本情報")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("お名前")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("*")
                            .foregroundColor(.red)
                    }
                    
                    TextField("山田太郎", text: $participantName)
                        .textFieldStyle(CustomTextFieldStyle())
                        .focused(focusedField, equals: .name)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("所属・部署（任意）")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField("営業部", text: $department)
                        .textFieldStyle(CustomTextFieldStyle())
                        .focused(focusedField, equals: .department)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - 参加状況選択カード

struct ParticipationStatusCard: View {
    @Binding var participantStatus: AttendanceStatus
    @Binding var selectedDates: Set<Date>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("参加状況")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("参加状況を選択してください。")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(spacing: 16) {
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
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
}

struct ParticipationStatusRow: View {
    let status: AttendanceStatus
    let isSelected: Bool
    let onSelectionChanged: () -> Void
    
    var body: some View {
        Button(action: onSelectionChanged) {
            HStack(spacing: 16) {
                // ラジオボタン（ステータス色に合わせる）
                ZStack {
                    Circle()
                        .stroke(isSelected ? status.color : Color(.systemGray4), lineWidth: 2)
                        .frame(width: 20, height: 20)
                        .animation(.easeInOut(duration: 0.2), value: isSelected)
                    
                    if isSelected {
                        Circle()
                            .fill(status.color)
                            .frame(width: 10, height: 10)
                            .scaleEffect(isSelected ? 1.0 : 0.5)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
                    }
                }
                
                // ステータスアイコン
                Image(systemName: status.icon)
                    .font(.title3)
                    .foregroundColor(status.color)
                    .frame(width: 24)
                
                // ステータステキスト
                Text(status.rawValue)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? status.color.opacity(0.05) : Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? status.color.opacity(0.3) : Color(.systemGray5), lineWidth: 1.5)
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
        VStack(alignment: .leading, spacing: 16) {
            Text("参加可能な日程")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("参加可能な日程をチェックボックスで選択してください。")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
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
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
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
            HStack(spacing: 12) {
                // チェックボックス
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundColor(isSelected ? .blue : .gray)
                
                // 日時情報
                VStack(alignment: .leading, spacing: 2) {
                    Text(formatDate(date))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(formatTime(date))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(.tertiarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1.5)
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
        VStack(alignment: .leading, spacing: 16) {
            Text("コメント（任意）")
                .font(.headline)
                .foregroundColor(.primary)
            
            TextField("遅れるかもしれません、予算について相談したいです など", text: $comment, axis: .vertical)
                .textFieldStyle(CustomTextFieldStyle())
                .focused(focusedField, equals: .comment)
                .lineLimit(3...6)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
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
            HStack {
                if isSubmitting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }
                
                Text(isSubmitting ? "送信中..." : "回答を送信")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(canSubmit ? Color.blue : Color.gray)
            )
            .foregroundColor(.white)
        }
        .disabled(!canSubmit || isSubmitting)
    }
}

// MARK: - カスタムテキストフィールドスタイル

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.tertiarySystemBackground))
            )
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
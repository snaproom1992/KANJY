import SwiftUI

struct StepHeaderView: View {
    let step: PartySetupStep
    let isCompleted: Bool
    let isCurrent: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            // ステップ番号とアイコン
            ZStack {
                Circle()
                    .fill(isCompleted ? Color.green : (isCurrent ? Color.accentColor : Color(.systemGray4)))
                    .frame(width: 24, height: 24)
                
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Text("\(step.rawValue + 1)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(isCurrent ? .white : .secondary)
                }
            }
            
            // ステップタイトル
            Text(step.title)
                .font(.headline)
                .foregroundColor(isCurrent ? .accentColor : .primary)
            
            // オプショナル表示
            if step == .schedule || step == .collection {
                Text("（任意）")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 現在のステップ表示
            if isCurrent {
                Text("現在")
                    .font(.caption)
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.accentColor.opacity(0.15))
                    )
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        StepHeaderView(step: .basicInfo, isCompleted: true, isCurrent: false)
        StepHeaderView(step: .participants, isCompleted: false, isCurrent: true)
        StepHeaderView(step: .amount, isCompleted: false, isCurrent: false)
        StepHeaderView(step: .schedule, isCompleted: false, isCurrent: false)
    }
    .padding()
}


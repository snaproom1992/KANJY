import SwiftUI

// 飲み会作成の進捗ステップ
enum PartySetupStep: Int, CaseIterable {
    case basicInfo = 0  // 基本情報（名前、日付、絵文字）
    case participants = 1  // 参加者
    case amount = 2  // 金額
    case schedule = 3  // スケジュール調整（オプション）
    case collection = 4  // 集金管理（オプション）
    
    var title: String {
        switch self {
        case .basicInfo: return "基本情報"
        case .participants: return "参加者"
        case .amount: return "金額"
        case .schedule: return "スケジュール"
        case .collection: return "集金"
        }
    }
    
    var icon: String {
        switch self {
        case .basicInfo: return "info.circle.fill"
        case .participants: return "person.2.fill"
        case .amount: return "yensign.circle.fill"
        case .schedule: return "calendar"
        case .collection: return "creditcard.fill"
        }
    }
}

// 進捗インジケーター
struct ProgressIndicatorView: View {
    let currentStep: PartySetupStep
    let steps: [PartySetupStep]
    
    var body: some View {
        VStack(spacing: DesignSystem.ProgressBar.spacing) {
            // 進捗バー（コンパクト）
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景バー
                    RoundedRectangle(cornerRadius: DesignSystem.ProgressBar.cornerRadius)
                        .fill(DesignSystem.Colors.gray2)
                        .frame(height: DesignSystem.ProgressBar.height)
                    
                    // 進捗バー
                    RoundedRectangle(cornerRadius: DesignSystem.ProgressBar.cornerRadius)
                        .fill(DesignSystem.Colors.primary)
                        .frame(width: geometry.size.width * CGFloat(progress), height: DesignSystem.ProgressBar.height)
                }
            }
            .frame(height: DesignSystem.ProgressBar.height)
            
            // ステップインジケーター（アイコンのみ、コンパクト）
            HStack(spacing: DesignSystem.Spacing.xs) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    StepIndicatorItem(
                        step: step,
                        isActive: index <= currentStep.rawValue,
                        isCurrent: index == currentStep.rawValue
                    )
                    
                    if index < steps.count - 1 {
                        Spacer(minLength: 2)
                    }
                }
            }
        }
        .padding(DesignSystem.ProgressBar.padding)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Card.cornerRadiusSmall, style: .continuous)
                .fill(DesignSystem.Colors.secondaryBackground)
        )
    }
    
    private var progress: Double {
        guard !steps.isEmpty else { return 0 }
        return Double(currentStep.rawValue + 1) / Double(steps.count)
    }
}

struct StepIndicatorItem: View {
    let step: PartySetupStep
    let isActive: Bool
    let isCurrent: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .fill(isActive ? DesignSystem.Colors.primary : DesignSystem.Colors.gray2)
                .frame(width: DesignSystem.ProgressBar.indicatorSize, height: DesignSystem.ProgressBar.indicatorSize)
            
            if isActive {
                Image(systemName: step.icon)
                    .font(.system(size: DesignSystem.ProgressBar.indicatorIconSize, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.white)
            } else {
                Circle()
                    .stroke(DesignSystem.Colors.gray3, lineWidth: 1.5)
                    .frame(width: DesignSystem.ProgressBar.indicatorSize, height: DesignSystem.ProgressBar.indicatorSize)
            }
        }
        .frame(width: DesignSystem.ProgressBar.indicatorSize, height: DesignSystem.ProgressBar.indicatorSize)
    }
}

#Preview {
    VStack {
        ProgressIndicatorView(
            currentStep: .participants,
            steps: PartySetupStep.allCases
        )
    }
    .padding()
}


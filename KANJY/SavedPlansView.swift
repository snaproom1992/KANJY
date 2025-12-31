import SwiftUI

struct SavedPlansView: View {
    @ObservedObject var viewModel: PrePlanViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteAlert = false
    @State private var planToDelete: Plan? = nil
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()
    
    var body: some View {
        List {
            ForEach(viewModel.savedPlans.sorted(by: { $0.date > $1.date })) { plan in
                Button(action: {
                    viewModel.loadPlan(plan)
                    dismiss()
                }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(plan.name)
                            .font(.headline)
                        HStack {
                            Text(dateFormatter.string(from: plan.date))
                                .font(.subheadline)
                                .foregroundColor(DesignSystem.Colors.secondary)
                            Spacer()
                            Text("¥\(viewModel.formatAmount(plan.totalAmount))")
                                .font(.subheadline)
                                .foregroundColor(DesignSystem.Colors.primary)
                        }
                        Text("参加者: \(plan.participants.count)人")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.secondary)
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        planToDelete = plan
                        showingDeleteAlert = true
                    } label: {
                        Label("削除", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle("保存したプラン")
        .navigationBarTitleDisplayMode(.inline)
        .alert("プランの削除", isPresented: $showingDeleteAlert) {
            Button("キャンセル", role: .cancel) {}
            Button("削除", role: .destructive) {
                if let plan = planToDelete {
                    viewModel.deletePlan(id: plan.id)
                }
            }
        } message: {
            Text("このプランを削除してもよろしいですか？")
        }
    }
} 
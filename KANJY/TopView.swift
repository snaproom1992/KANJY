import SwiftUI

struct TopView: View {
    @StateObject private var viewModel = PrePlanViewModel()
    @State private var showingPrePlan = false
    @State private var showingDeleteAlert = false
    @State private var planToDelete: Plan? = nil
    @State private var tempPlanName: String = ""
    @State private var tempPlanDate: Date = Date()
    
    var body: some View {
        NavigationView {
            List {
                // 保存した飲み会セクション
                if !viewModel.savedPlans.isEmpty {
                    Section {
                        ForEach(viewModel.savedPlans.sorted(by: { $0.date > $1.date })) { plan in
                            Button(action: {
                                viewModel.loadPlan(plan)
                                showingPrePlan = true
                            }) {
                                PlanListCell(plan: plan, viewModel: viewModel)
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
                    } header: {
                        Text("保存した飲み会")
                    }
                } else {
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "wineglass")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            Text("保存されている飲み会はありません")
                                .font(.headline)
                                .foregroundColor(.gray)
                            Text("飲み会を作成して保存すると、\nここに表示されます")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    } header: {
                        Text("保存した飲み会")
                    }
                }
                
                // 新規飲み会作成セクション
                Section {
                    Button(action: {
                        viewModel.resetForm()
                        viewModel.editingPlanName = ""
                        showingPrePlan = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                            Text("飲み会を作成")
                                .font(.headline)
                        }
                        .padding(.vertical, 8)
                    }
                } header: {
                    Text("新規飲み会作成")
                }
            }
            .navigationTitle("幹事アプリ")
            .sheet(isPresented: $showingPrePlan) {
                NavigationStack {
                    PrePlanView(
                        viewModel: viewModel,
                        planName: viewModel.editingPlanName.isEmpty ? "" : viewModel.editingPlanName,
                        planDate: viewModel.editingPlanDate,
                        onFinish: {
                            showingPrePlan = false
                        }
                    )
                }
            }
            .alert("飲み会の削除", isPresented: $showingDeleteAlert) {
                Button("キャンセル", role: .cancel) {}
                Button("削除", role: .destructive) {
                    if let plan = planToDelete {
                        viewModel.deletePlan(id: plan.id)
                    }
                }
            } message: {
                Text("この飲み会を削除してもよろしいですか？")
            }
        }
    }
}

// サブビュー: プランリストのセル
private struct PlanListCell: View {
    let plan: Plan
    let viewModel: PrePlanViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(plan.name)
                    .font(.headline)
                if plan.totalAmount.isEmpty || plan.participants.isEmpty {
                    Text("下書き")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.orange.opacity(0.15)))
                }
                Spacer()
                Text(viewModel.formatDate(plan.date))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            HStack {
                Text("参加者: \(plan.participants.count)人")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("¥\(viewModel.formatAmount(plan.totalAmount))")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
        }
    }
}

#Preview {
    TopView()
}

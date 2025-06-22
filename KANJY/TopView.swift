import SwiftUI

struct TopView: View {
    @StateObject private var viewModel = PrePlanViewModel()
    @State private var showingPrePlan = false
    @State private var showingDeleteAlert = false
    @State private var planToDelete: Plan? = nil
    @State private var tempPlanName: String = ""
    @State private var tempPlanDate: Date = Date()
    @State private var displayMode: DisplayMode = .list
    @State private var selectedDate: Date? = nil
    @State private var isAnimating = false
    
    enum DisplayMode {
        case list
        case calendar
    }
    
    private var filteredPlans: [Plan] {
        if let date = selectedDate {
            return viewModel.savedPlans.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
        } else {
            return viewModel.savedPlans.sorted(by: { $0.date > $1.date })
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                // 保存した飲み会セクション
                Section {
                    if displayMode == .list {
                        if let date = selectedDate {
                            HStack {
                                Text("\(date, formatter: Self.dateFormatter) のイベント")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(8)
                                Button(action: {
                                    selectedDate = nil
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                            }
                        }
                        
                        if filteredPlans.isEmpty {
                            if selectedDate != nil {
                                Text("この日のイベントはありません。")
                                    .foregroundColor(.gray)
                            } else {
                                EmptyStateView(isAnimating: $isAnimating)
                            }
                        } else {
                            ForEach(filteredPlans) { plan in
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
                        }
                    } else {
                        ZStack {
                            CalendarView(viewModel: viewModel, selectedDate: $selectedDate, displayMode: $displayMode)
                                .scaleEffect(0.85)
                                .offset(y: -15)
                        }
                        .frame(height: 320)
                    }
                } header: {
                    HStack {
                        Text("保存した飲み会")
                        Spacer()
                        Button(action: {
                            displayMode = displayMode == .list ? .calendar : .list
                        }) {
                            Image(systemName: displayMode == .list ? "calendar" : "list.bullet")
                                .foregroundColor(.blue)
                        }
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
                
                // 設定セクション
                Section {
                    NavigationLink(destination: PaymentSettings()) {
                        HStack {
                            Image(systemName: "creditcard")
                                .font(.title2)
                            Text("集金情報設定")
                                .font(.headline)
                        }
                        .padding(.vertical, 8)
                    }
                } header: {
                    Text("設定")
                }
            }
            .navigationTitle("イベントリスト")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: PaymentSettings()) {
                        Image(systemName: "creditcard")
                    }
                }
            }
            .sheet(isPresented: $showingPrePlan, onDismiss: {
                // シートが閉じる前に自動保存
                if !viewModel.editingPlanName.isEmpty {
                    print("シートが閉じられる際に自動保存を実行: \(viewModel.editingPlanName)")
                    viewModel.savePlan(
                        name: viewModel.editingPlanName.isEmpty ? "無題の飲み会" : viewModel.editingPlanName,
                        date: viewModel.editingPlanDate ?? Date()
                    )
                }
            }) {
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
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
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
            .onAppear {
                // アニメーション開始
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
        }
    }
}

// 空状態用のカスタムビュー
struct EmptyStateView: View {
    @Binding var isAnimating: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            // メインイラスト
            ZStack {
                // 背景の円
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 120, height: 120)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isAnimating)
                
                // 飲み会のイラスト
                HStack(spacing: 8) {
                    Text("🍻")
                        .font(.system(size: 40))
                        .offset(y: isAnimating ? -5 : 0)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)
                    
                    Text("🎉")
                        .font(.system(size: 40))
                        .offset(y: isAnimating ? 5 : 0)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(0.5), value: isAnimating)
                }
            }
            
            VStack(spacing: 12) {
                // メインメッセージ
                Text("初めての飲み会を作成しませんか？")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("みんなで楽しい時間を過ごしましょう！")
                    .font(.headline)
                    .foregroundColor(.blue)
                    .multilineTextAlignment(.center)
                
                // サブメッセージ
                Text("参加者の管理や集金の計算の\nお手伝いをさせてください")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 30)
        .frame(maxWidth: .infinity)
    }
}

extension TopView {
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()
}

// サブビュー: プランリストのセル
private struct PlanListCell: View {
    let plan: Plan
    let viewModel: PrePlanViewModel
    
    // 集金ステータスを計算
    private var collectionStatus: (isComplete: Bool, count: Int, total: Int) {
        let collectedCount = plan.participants.filter { $0.hasCollected }.count
        let totalCount = plan.participants.count
        return (collectedCount == totalCount && totalCount > 0, collectedCount, totalCount)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // 絵文字表示
            Text(plan.emoji ?? "🍻")
                .font(.system(size: 32))
                .frame(width: 50, height: 50)
                .background(
                    Circle()
                        .fill(Color.gray.opacity(0.1))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(plan.name)
                        .font(.headline)
                    
                    // ステータスバッジ
                    if plan.totalAmount.isEmpty || plan.participants.isEmpty {
                        Text("下書き")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.orange.opacity(0.15)))
                    } else if collectionStatus.isComplete {
                        Text("集金済み")
                            .font(.caption)
                            .foregroundColor(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.green.opacity(0.15)))
                    } else {
                        Text("未集金")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.blue.opacity(0.15)))
                    }
                    
                    Spacer()
                    Text(viewModel.formatDate(plan.date))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                HStack {
                    // 参加者数と集金ステータスを表示
                    if !plan.participants.isEmpty && (collectionStatus.count > 0 || collectionStatus.total > 0) {
                        Text("参加者: \(plan.participants.count)人 (\(collectionStatus.count)/\(collectionStatus.total))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("参加者: \(plan.participants.count)人")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text("¥\(viewModel.formatAmount(plan.totalAmount))")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
        }
    }
}

#Preview {
    TopView()
}

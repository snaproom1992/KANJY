import SwiftUI
import UIKit

/// 保存済みプランをカレンダー表示するためのシート用ビュー
struct CalendarSheetView: View {
    @ObservedObject var viewModel: PrePlanViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDate: Date?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                CalendarUIKitView(viewModel: viewModel, selectedDate: $selectedDate)
                    .padding(.horizontal, 16)
                    .padding(.top, 24)

                if let date = selectedDate {
                    calendarDetailSection(for: date)
                        .padding(.top, 24)
                        .padding(.horizontal, 20)
                } else {
                    Text("日付をタップするとイベントを確認できます")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 24)
                        .padding(.horizontal, 20)
                }

                Spacer()
            }
            .navigationTitle("イベントカレンダー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func calendarDetailSection(for date: Date) -> some View {
        let events = viewModel.savedPlans.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }

        VStack(alignment: .leading, spacing: 12) {
            Text(date, formatter: TopView.dateFormatter)
                .font(.headline)

            if events.isEmpty {
                Text("この日のイベントはありません")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(events) { plan in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(plan.name)
                            .font(.headline)
                        Text("参加者: \(plan.participants.count)人")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
                }
            }
        }
    }
}

/// UIKitのUICalendarViewをラップしたビュー
struct CalendarUIKitView: UIViewRepresentable {
    @ObservedObject var viewModel: PrePlanViewModel
    @Binding var selectedDate: Date?

    func makeUIView(context: Context) -> UICalendarView {
        let calendarView = UICalendarView()
        calendarView.calendar = Calendar(identifier: .gregorian)
        calendarView.locale = Locale(identifier: "ja_JP")
        calendarView.delegate = context.coordinator
        calendarView.backgroundColor = .clear
        calendarView.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12)

        let selection = UICalendarSelectionSingleDate(delegate: context.coordinator)
        calendarView.selectionBehavior = selection

        return calendarView
    }

    func updateUIView(_ uiView: UICalendarView, context: Context) {
        context.coordinator.updateDecorations(on: uiView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self, viewModel: viewModel)
    }

    final class Coordinator: NSObject, UICalendarViewDelegate, UICalendarSelectionSingleDateDelegate {
        var parent: CalendarUIKitView
        @ObservedObject var viewModel: PrePlanViewModel

        init(parent: CalendarUIKitView, viewModel: PrePlanViewModel) {
            self.parent = parent
            self.viewModel = viewModel
            super.init()
        }

        func calendarView(_ calendarView: UICalendarView, decorationFor dateComponents: DateComponents) -> UICalendarView.Decoration? {
            guard let date = dateComponents.date else { return nil }

            let hasEvent = viewModel.savedPlans.contains { plan in
                Calendar.current.isDate(plan.date, inSameDayAs: date)
            }

            return hasEvent ? .default(color: .blue, size: .large) : nil
        }

        func dateSelection(_ selection: UICalendarSelectionSingleDate, didSelectDate dateComponents: DateComponents?) {
            parent.selectedDate = dateComponents?.date
        }

        func updateDecorations(on calendarView: UICalendarView) {
            // 必要に応じてデコレーションを更新するhook（今回は何もしない）
        }
    }
}

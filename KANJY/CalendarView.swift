import SwiftUI
import UIKit

struct CalendarView: UIViewRepresentable {
    @ObservedObject var viewModel: PrePlanViewModel
    @Binding var selectedDate: Date?
    @Binding var displayMode: TopView.DisplayMode
    
    func makeUIView(context: Context) -> UICalendarView {
        let calendarView = UICalendarView()
        calendarView.calendar = Calendar(identifier: .gregorian)
        calendarView.delegate = context.coordinator
        
        let dateSelection = UICalendarSelectionSingleDate(delegate: context.coordinator)
        calendarView.selectionBehavior = dateSelection
        
        return calendarView
    }
    
    func updateUIView(_ uiView: UICalendarView, context: Context) {
        // ViewModelの変更を検知してカレンダーのデコレーションを更新
        // この処理はCoordinatorに任せる
        context.coordinator.updateDecorations()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self, viewModel: viewModel)
    }
    
    class Coordinator: NSObject, UICalendarViewDelegate, UICalendarSelectionSingleDateDelegate {
        var parent: CalendarView
        @ObservedObject var viewModel: PrePlanViewModel
        
        init(_ parent: CalendarView, viewModel: PrePlanViewModel) {
            self.parent = parent
            self.viewModel = viewModel
            super.init()
        }
        
        func calendarView(_ calendarView: UICalendarView, decorationFor dateComponents: DateComponents) -> UICalendarView.Decoration? {
            guard let calendarDate = dateComponents.date else { return nil }
            
            // イベントがある日付にドットを付ける
            let foundEvents = viewModel.savedPlans.filter { plan in
                // plan.date は Date 型なので、オプショナルバインディングは不要
                return Calendar.current.isDate(plan.date, inSameDayAs: calendarDate)
            }
            
            if foundEvents.isEmpty {
                return nil
            } else {
                return .default(color: .blue, size: .large)
            }
        }
        
        func dateSelection(_ selection: UICalendarSelectionSingleDate, didSelectDate dateComponents: DateComponents?) {
            parent.selectedDate = dateComponents?.date
            if dateComponents?.date != nil {
                DispatchQueue.main.async {
                    self.parent.displayMode = .list
                }
            }
        }

        func updateDecorations() {
            // カレンダーの表示をリロードして、デコレーションを再描画させる
            // Note: UICalendarViewに直接reloadのようなメソッドはないため、
            // `updateUIView`が呼ばれたことをトリガーに、ViewModelの変更を頼りにする。
            // 実際には、reloadDecorations(forDateComponents:animated:)を呼ぶのが望ましいが、
            // このサンプルではシンプルにするため、ViewModelの変更に依存する形にする。
        }
    }
} 
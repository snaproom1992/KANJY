import SwiftUI

struct PlanSyncModifier: ViewModifier {
    @ObservedObject var viewModel: PrePlanViewModel
    
    // Bindings for local state
    @Binding var localPlanLocation: String
    @Binding var localPlanDescription: String
    
    // Bindings for schedule event state (optional)
    @Binding var scheduleEvent: ScheduleEvent?
    @Binding var scheduleTitle: String
    @Binding var scheduleDescription: String
    @Binding var scheduleCandidateDates: [Date]
    @Binding var scheduleLocation: String
    @Binding var scheduleBudget: String
    
    func body(content: Content) -> some View {
        content
            .modifier(ViewModelSync(viewModel: viewModel, localPlanLocation: $localPlanLocation, localPlanDescription: $localPlanDescription))
            .modifier(ScheduleEventSyncPart1(scheduleEvent: $scheduleEvent, scheduleTitle: $scheduleTitle, scheduleDescription: $scheduleDescription))
            .modifier(ScheduleEventSyncPart2(scheduleEvent: $scheduleEvent, scheduleCandidateDates: $scheduleCandidateDates, scheduleLocation: $scheduleLocation, scheduleBudget: $scheduleBudget))
    }
}

private struct ViewModelSync: ViewModifier {
    @ObservedObject var viewModel: PrePlanViewModel
    @Binding var localPlanLocation: String
    @Binding var localPlanDescription: String
    
    func body(content: Content) -> some View {
        content
            .onChange(of: viewModel.editingPlanLocation) { _, newValue in
                if localPlanLocation != newValue {
                    localPlanLocation = newValue
                }
            }
            .onChange(of: viewModel.editingPlanDescription) { _, newValue in
                if localPlanDescription != newValue {
                    localPlanDescription = newValue
                }
            }
    }
}

private struct ScheduleEventSyncPart1: ViewModifier {
    @Binding var scheduleEvent: ScheduleEvent?
    @Binding var scheduleTitle: String
    @Binding var scheduleDescription: String
    
    func body(content: Content) -> some View {
        content
            .onChange(of: scheduleEvent?.title) { _, newValue in
                if scheduleTitle != newValue {
                    scheduleTitle = newValue ?? ""
                }
            }
            .onChange(of: scheduleEvent?.description) { _, newValue in
                if scheduleDescription != newValue {
                    scheduleDescription = newValue ?? ""
                }
            }
    }
}

private struct ScheduleEventSyncPart2: ViewModifier {
    @Binding var scheduleEvent: ScheduleEvent?
    @Binding var scheduleCandidateDates: [Date]
    @Binding var scheduleLocation: String
    @Binding var scheduleBudget: String
    
    func body(content: Content) -> some View {
        content
            .onChange(of: scheduleEvent?.candidateDates) { _, newValue in
                if scheduleCandidateDates != newValue {
                    scheduleCandidateDates = newValue ?? []
                }
            }
            .onChange(of: scheduleEvent?.location) { _, newValue in
                if scheduleLocation != newValue {
                    scheduleLocation = newValue ?? ""
                }
            }
            .onChange(of: scheduleEvent?.budget) { _, newValue in
                let newBudget = newValue.map { String($0) } ?? ""
                if scheduleBudget != newBudget {
                    scheduleBudget = newBudget
                }
            }
    }
}

extension View {
    func planSync(
        viewModel: PrePlanViewModel,
        localPlanLocation: Binding<String>,
        localPlanDescription: Binding<String>,
        scheduleEvent: Binding<ScheduleEvent?>,
        scheduleTitle: Binding<String>,
        scheduleDescription: Binding<String>,
        scheduleCandidateDates: Binding<[Date]>,
        scheduleLocation: Binding<String>,
        scheduleBudget: Binding<String>
    ) -> some View {
        self.modifier(PlanSyncModifier(
            viewModel: viewModel,
            localPlanLocation: localPlanLocation,
            localPlanDescription: localPlanDescription,
            scheduleEvent: scheduleEvent,
            scheduleTitle: scheduleTitle,
            scheduleDescription: scheduleDescription,
            scheduleCandidateDates: scheduleCandidateDates,
            scheduleLocation: scheduleLocation,
            scheduleBudget: scheduleBudget
        ))
    }
}

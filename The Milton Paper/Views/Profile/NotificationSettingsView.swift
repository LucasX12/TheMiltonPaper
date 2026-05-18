import SwiftUI

struct NotificationSettingsView: View {
    @StateObject private var viewModel = NotificationViewModel()

    var body: some View {
        ZStack {
            Color.miltonBackground.ignoresSafeArea()

            List {
                Section {
                    Toggle("Enable Push Notifications", isOn: Binding(
                        get: { viewModel.notificationsEnabled },
                        set: { value in Task { await viewModel.toggleNotifications(enabled: value) } }
                    ))
                    .tint(.miltonPrimary)
                } header: {
                    Text("Notifications")
                        .font(.miltonLabel)
                        .foregroundColor(.miltonSecondary)
                }

                if viewModel.notificationsEnabled {
                    Section {
                        ForEach(viewModel.availableTopics, id: \.topic) { item in
                            Toggle(item.label, isOn: Binding(
                                get: { viewModel.enabledTopics.contains(item.topic) },
                                set: { enabled in Task { await viewModel.toggleTopic(item.topic, enabled: enabled) } }
                            ))
                            .tint(.miltonPrimary)
                        }
                    } header: {
                        Text("Notify me about")
                            .font(.miltonLabel)
                            .foregroundColor(.miltonSecondary)
                    } footer: {
                        Text("You'll receive a notification when new articles are published in your selected categories.")
                            .font(.miltonCaption)
                            .foregroundColor(.miltonSecondary)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.miltonBackground)
        }
        .navigationTitle("Notification Preferences")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.load() }
    }
}

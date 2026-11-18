import SwiftUI

struct ProfileView: View {
    @Environment(ProgressStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var showEdit = false
    @State private var showScale = false
    @State private var draftName = ""

    private var toleranceBinding: Binding<Double> {
        Binding(get: { store.settings.toleranceCents }, set: { v in store.updateSettings { $0.toleranceCents = v } })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Profile").font(.screenTitle).foregroundStyle(Theme.maroon).accessibilityAddTraits(.isHeader)
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark").font(.body.weight(.semibold)).foregroundStyle(Theme.maroon) }
                    .accessibilityLabel("Close")
            }
            VStack(spacing: 6) {
                AvatarView(name: store.profile.name, size: 64)
                Text(store.profile.name).font(.headline)
                Text("Scale: \(store.saScale.noteName)").font(.footnote).foregroundStyle(Theme.muted)
                Button("Edit Profile") { draftName = store.profile.name; showEdit = true }
                    .font(.caption.weight(.semibold)).foregroundStyle(Theme.maroon)
            }
            .padding(.vertical, 16).frame(maxWidth: .infinity).cardStyle()

            VStack(spacing: 0) {
                Button { showScale = true } label: {
                    row(symbol: "mic", title: "Update your Scale") { Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.muted) }
                }
                Divider().overlay(Theme.gold.opacity(0.5)).padding(.horizontal, 12)
                row(symbol: "slider.horizontal.3", title: "Pitch tolerance") {
                    Picker("Pitch tolerance", selection: toleranceBinding) {
                        Text("Strict (±20¢)").tag(20.0)
                        Text("Balanced (±35¢)").tag(35.0)
                        Text("Relaxed (±50¢)").tag(50.0)
                    }
                    .labelsHidden().tint(Theme.muted)
                }
                Divider().overlay(Theme.gold.opacity(0.5)).padding(.horizontal, 12)
                Button { store.updateProfile { $0.isSignedIn = false }; dismiss() } label: {
                    row(symbol: "power", title: "Log Out") { EmptyView() }
                }
            }
            .buttonStyle(.plain).cardStyle()
            Spacer()
        }
        .padding(Theme.screenPadding)
        .background(Theme.background.ignoresSafeArea())
        .presentationDragIndicator(.visible)
        .alert("Edit Profile", isPresented: $showEdit) {
            TextField("Name", text: $draftName)
            Button("Save") {
                let name = draftName.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty { store.updateProfile { $0.name = name } }
            }
            Button("Cancel", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $showScale) {
            OnboardingFlowView(onComplete: { scale in
                store.updateProfile { $0.saScale = scale }
                showScale = false
            }, onCancel: { showScale = false })
        }
    }

    private func row<T: View>(symbol: String, title: String, @ViewBuilder trailing: () -> T) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).foregroundStyle(Theme.muted).frame(width: 24)
            Text(title).font(.subheadline).foregroundStyle(Theme.ink)
            Spacer()
            trailing()
        }
        .padding(14).contentShape(Rectangle())
    }
}

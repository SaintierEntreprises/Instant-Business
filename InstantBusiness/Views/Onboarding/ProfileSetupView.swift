import SwiftUI
import UIKit

/// Genre puis prénom, un écran à la fois, juste après la connexion. Placé avant le quiz
/// pour que son résultat puisse s'adresser à la personne par son prénom et s'accorder
/// au féminin. Le découpage en deux étapes reprend le rythme du quiz qui suit.
struct ProfileSetupView: View {
    private enum Step {
        case gender
        case name
    }

    @EnvironmentObject private var authManager: AuthManager
    @AppStorage("hasCompletedProfile") private var hasCompletedProfile = false

    @State private var step: Step = .gender
    @State private var gender: Gender?
    @State private var firstName = ""
    @State private var isSaving = false
    @FocusState private var nameFieldFocused: Bool

    private let userSyncService = UserSyncService()

    private var trimmedName: String {
        firstName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Group {
                switch step {
                case .gender: genderStep
                case .name: nameStep
                }
            }
            .id(step)

            Spacer()
        }
        .padding(.horizontal, 24)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: step)
        .onAppear {
            gender = SharedDefaults.gender
            firstName = SharedDefaults.firstName ?? ""
        }
    }

    private var header: some View {
        HStack {
            if step == .name {
                Button {
                    nameFieldFocused = false
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { step = .gender }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(step == .gender ? "1 / 2" : "2 / 2")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.top, 12)
    }

    // MARK: - Étape 1

    private var genderStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Tu es ?")
                .font(.system(.title, design: .rounded, weight: .heavy))
                .padding(.top, 32)

            Text("Pour accorder tes citations et ton profil.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 6)

            VStack(spacing: 12) {
                ForEach(Gender.allCases) { option in
                    genderButton(option)
                }
            }
            .padding(.top, 28)
        }
    }

    private func genderButton(_ option: Gender) -> some View {
        let isSelected = gender == option

        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            gender = option
            // Court délai pour que la sélection soit visible avant de passer à la suite,
            // comme dans le quiz.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    step = .name
                }
            }
        } label: {
            HStack {
                Text(option.displayName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(isSelected ? .white : Color.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.bold))
                        .foregroundStyle(.white)
                }
            }
            .padding(18)
            .background(
                isSelected ? Color.accentColor : Color(.secondarySystemBackground),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
        }
        .buttonStyle(PressableButtonStyle(scale: 0.98))
    }

    // MARK: - Étape 2

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Ton prénom ?")
                .font(.system(.title, design: .rounded, weight: .heavy))
                .padding(.top, 32)

            Text("Pour que l'app s'adresse à toi personnellement.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 6)

            TextField("Prénom", text: $firstName)
                .font(.title3.weight(.semibold))
                .textContentType(.givenName)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($nameFieldFocused)
                .onSubmit { save() }
                .padding(16)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.top, 28)

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                save()
            } label: {
                ZStack {
                    Text("Continuer")
                        .font(.headline)
                        .opacity(isSaving ? 0 : 1)
                    if isSaving {
                        ProgressView().tint(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(trimmedName.isEmpty ? Color(.tertiarySystemFill) : Color.accentColor)
                .foregroundStyle(trimmedName.isEmpty ? Color(.tertiaryLabel) : .white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(PressableButtonStyle(scale: 0.97))
            .disabled(trimmedName.isEmpty || isSaving)
            .padding(.top, 20)
        }
        .onAppear { nameFieldFocused = true }
    }

    private func save() {
        guard let gender, !trimmedName.isEmpty else { return }
        nameFieldFocused = false
        isSaving = true

        SharedDefaults.firstName = trimmedName
        SharedDefaults.gender = gender

        Task {
            if let userID = authManager.session?.user.id.uuidString {
                await userSyncService.saveProfile(userID: userID, firstName: trimmedName, gender: gender)
            }
            isSaving = false
            hasCompletedProfile = true
        }
    }
}

#Preview {
    ProfileSetupView()
        .environmentObject(AuthManager())
}

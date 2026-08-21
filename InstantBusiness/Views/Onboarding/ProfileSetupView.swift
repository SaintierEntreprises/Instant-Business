import SwiftUI
import UIKit

/// Genre, prénom puis nom, un écran à la fois, juste après la connexion. Placé avant le
/// quiz pour que son résultat puisse s'adresser à la personne par son prénom et s'accorder
/// au féminin. Le compteur et la barre sont ceux du parcours complet (voir
/// `OnboardingFlow`) : ces trois écrans et les six du quiz n'en forment qu'un pour la
/// personne qui s'inscrit.
struct ProfileSetupView: View {
    private enum Step: Int {
        case gender
        case firstName
        case lastName

        var previous: Step? { Step(rawValue: rawValue - 1) }
    }

    @EnvironmentObject private var authManager: AuthManager
    @AppStorage("hasCompletedProfile") private var hasCompletedProfile = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var step: Step = .gender
    @State private var gender: Gender?
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var isSaving = false
    @State private var isMovingForward = true
    @FocusState private var focusedField: Step?

    private let userSyncService = UserSyncService()

    private var trimmedFirstName: String {
        firstName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedLastName: String {
        lastName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingHeader(
                step: step.rawValue + 1,
                onBack: step.previous.map { previous in { goBack(to: previous) } }
            )

            Group {
                switch step {
                case .gender: genderStep
                case .firstName: firstNameStep
                case .lastName: lastNameStep
                }
            }
            .padding(.horizontal, 24)
            .id(step)
            .onboardingStepTransition(forward: isMovingForward, reduceMotion: reduceMotion)

            Spacer(minLength: 0)
        }
        .onAppear {
            Haptics.prepare()
            gender = SharedDefaults.gender
            firstName = SharedDefaults.firstName ?? ""
            lastName = SharedDefaults.lastName ?? ""
        }
    }

    // MARK: - Étape 1

    private var genderStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepTitle("Tu es ?", subtitle: "Pour accorder tes citations et ton profil.")

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
            Haptics.select()
            gender = option
            // Court délai pour que la sélection soit visible avant d'enchaîner,
            // comme dans le quiz.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                advance(to: .firstName)
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
        .animation(.spring(response: 0.3, dampingFraction: 1), value: isSelected)
    }

    // MARK: - Étapes 2 et 3

    private var firstNameStep: some View {
        textStep(
            title: "Ton prénom ?",
            subtitle: "Pour que l'app s'adresse à toi personnellement.",
            placeholder: "Prénom",
            text: $firstName,
            contentType: .givenName,
            field: .firstName,
            isValid: !trimmedFirstName.isEmpty,
            isLoading: false
        ) {
            advance(to: .lastName)
        }
    }

    private var lastNameStep: some View {
        textStep(
            title: "Ton nom ?",
            subtitle: "Pour compléter ton profil.",
            placeholder: "Nom",
            text: $lastName,
            contentType: .familyName,
            field: .lastName,
            isValid: !trimmedLastName.isEmpty,
            isLoading: isSaving,
            action: save
        )
    }

    private func textStep(
        title: String,
        subtitle: String,
        placeholder: String,
        text: Binding<String>,
        contentType: UITextContentType,
        field: Step,
        isValid: Bool,
        isLoading: Bool,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            stepTitle(title, subtitle: subtitle)

            TextField(placeholder, text: text)
                .font(.title3.weight(.semibold))
                .textContentType(contentType)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($focusedField, equals: field)
                .onSubmit { if isValid { action() } }
                .padding(16)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.top, 28)

            Button {
                Haptics.commit()
                action()
            } label: {
                ZStack {
                    Text("Continuer")
                        .font(.headline)
                        .opacity(isLoading ? 0 : 1)
                    if isLoading {
                        ProgressView().tint(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isValid ? Color.accentColor : Color(.tertiarySystemFill))
                .foregroundStyle(isValid ? .white : Color(.tertiaryLabel))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(PressableButtonStyle(scale: 0.97))
            .disabled(!isValid || isLoading)
            .animation(.easeOut(duration: 0.2), value: isValid)
            .padding(.top, 20)
        }
        // Le champ sortant relâche le focus pendant la transition, et il le fait après
        // l'`onAppear` du champ entrant : prendre le focus immédiatement se fait donc
        // écraser, et l'étape 3 s'affichait clavier fermé. Un court délai le place une
        // fois l'ancien champ démonté.
        .task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            focusedField = field
        }
    }

    private func stepTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(.title, design: .rounded, weight: .heavy))
                .tracking(-0.5)
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 32)
    }

    // MARK: - Navigation

    private func advance(to next: Step) {
        isMovingForward = true
        withAnimation(.spring(response: 0.45, dampingFraction: 1)) { step = next }
    }

    private func goBack(to previous: Step) {
        Haptics.tap()
        focusedField = nil
        isMovingForward = false
        withAnimation(.spring(response: 0.4, dampingFraction: 1)) { step = previous }
    }

    private func save() {
        guard let gender, !trimmedFirstName.isEmpty, !trimmedLastName.isEmpty else { return }
        focusedField = nil
        isSaving = true

        SharedDefaults.firstName = trimmedFirstName
        SharedDefaults.lastName = trimmedLastName
        SharedDefaults.gender = gender

        Task {
            if let userID = authManager.session?.user.id.uuidString {
                await userSyncService.saveProfile(
                    userID: userID,
                    firstName: trimmedFirstName,
                    lastName: trimmedLastName,
                    gender: gender
                )
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

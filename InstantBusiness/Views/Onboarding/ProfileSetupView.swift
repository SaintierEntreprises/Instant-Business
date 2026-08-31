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
        case notifications

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
    @State private var frequency: NotificationFrequency = .default
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
                case .notifications: notificationsStep
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
            frequency = SharedDefaults.notificationFrequency
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
            isLoading: false
        ) {
            advance(to: .notifications)
        }
    }

    // MARK: - Étape 4

    private var notificationsStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepTitle(
                "Combien de citations par jour ?",
                subtitle: "Toujours entre 8h et 21h. Modifiable à tout moment dans les réglages."
            )

            VStack(spacing: 12) {
                ForEach(NotificationFrequency.allCases) { option in
                    frequencyButton(option)
                }
            }
            .padding(.top, 24)

            Button {
                Haptics.commit()
                save()
            } label: {
                ZStack {
                    Text("Terminer")
                        .font(.headline)
                        .opacity(isSaving ? 0 : 1)
                    if isSaving { ProgressView().tint(.white) }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(PressableButtonStyle(scale: 0.97))
            .disabled(isSaving)
            .padding(.top, 24)
        }
    }

    private func frequencyButton(_ option: NotificationFrequency) -> some View {
        let isSelected = frequency == option

        return Button {
            Haptics.select()
            frequency = option
        } label: {
            HStack(spacing: 14) {
                Image(systemName: option.symbolName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(isSelected ? .white : Color.accentColor)
                    .frame(width: 36, height: 36)
                    .background(
                        isSelected ? Color.accentColor : Color.accentColor.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(option.summary)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(option.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.bold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(14)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 2)
            }
        }
        .buttonStyle(PressableButtonStyle(scale: 0.98))
        .animation(.spring(response: 0.3, dampingFraction: 1), value: isSelected)
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
        SharedDefaults.notificationFrequency = frequency
        PreferenceSync.push()

        Task {
            if let userID = authManager.session?.user.id.uuidString {
                await userSyncService.saveProfile(
                    userID: userID,
                    firstName: trimmedFirstName,
                    lastName: trimmedLastName,
                    gender: gender
                )
            }
            // Le calendrier est reconstruit ici plutôt qu'au prochain lancement : sans
            // cela, la personne garderait le rythme par défaut jusqu'à sa prochaine
            // ouverture, alors qu'elle vient d'en choisir un autre.
            await NotificationManager().reschedule()

            isSaving = false
            // Le genre et le rythme seuls : ni le prénom ni le nom ne quittent l'app ici.
            Analytics.track(.profileCompleted, [
                "gender": .string(gender.rawValue),
                "notification_frequency": .string(frequency.rawValue)
            ])
            hasCompletedProfile = true
        }
    }
}

#Preview {
    ProfileSetupView()
        .environmentObject(AuthManager())
}

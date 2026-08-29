import SwiftUI

/// Profil (3 écrans) puis quiz (6 écrans) forment un seul parcours du point de vue de la
/// personne qui s'inscrit. Un compteur qui repart à « 1 / 6 » juste après « 3 / 3 » donne
/// l'impression de recommencer à zéro ; les deux vues partagent donc une même barre,
/// graduée sur le total réel.
enum OnboardingFlow {
    static let profileStepCount = 4
    static let quizStepCount = 6
    static var totalSteps: Int { profileStepCount + quizStepCount }

    /// Rang absolu, à partir de 1, d'une étape du quiz dans le parcours complet.
    static func quizStepRank(_ index: Int) -> Int { profileStepCount + index + 1 }
}

/// En-tête commun aux étapes du profil et du quiz : retour, compteur, progression.
struct OnboardingHeader: View {
    /// Rang de l'écran courant dans le parcours complet, à partir de 1.
    let step: Int
    var total: Int = OnboardingFlow.totalSteps
    /// Absent sur la toute première étape, où il n'y a nulle part où revenir.
    var onBack: (() -> Void)?

    private var progress: Double { Double(step) / Double(total) }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                if let onBack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableButtonStyle(scale: 0.9))
                    .transition(.opacity)
                }
                Spacer()
                Text("\(step) / \(total)")
                    .font(.footnote.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
            .frame(height: 32)

            ProgressTrack(progress: progress)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }
}

/// Barre de progression maison plutôt que `ProgressView` : elle seule permet de choisir
/// le ressort et de garder la même épaisseur d'un écran à l'autre.
private struct ProgressTrack: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(.tertiarySystemFill))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.75)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(6, proxy.size.width * progress))
            }
        }
        .frame(height: 6)
        // Amorti complet : la barre ne doit pas dépasser puis revenir, elle sert de
        // repère de position, pas d'effet.
        .animation(.spring(response: 0.45, dampingFraction: 1), value: progress)
    }
}

extension AnyTransition {
    /// Entrée et sortie sur le même axe, dans le sens de la navigation : un écran qui
    /// arrive par la droite repart par la droite quand on revient en arrière.
    static func onboardingStep(forward: Bool) -> AnyTransition {
        .asymmetric(
            insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)
        )
    }
}

extension View {
    /// Transition d'étape, ramenée à un simple fondu quand l'utilisateur a demandé moins
    /// d'animations — le glissement latéral est précisément ce qui gêne dans ce cas.
    @ViewBuilder
    func onboardingStepTransition(forward: Bool, reduceMotion: Bool) -> some View {
        if reduceMotion {
            transition(.opacity)
        } else {
            transition(.onboardingStep(forward: forward))
        }
    }
}

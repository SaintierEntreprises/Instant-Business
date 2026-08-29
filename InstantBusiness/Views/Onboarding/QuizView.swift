import SwiftUI

struct QuizView: View {
    @AppStorage("hasCompletedQuiz") private var hasCompletedQuiz = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var index = 0
    @State private var answers: [Int: QuizOption] = [:]
    @State private var showResult = false
    @State private var isMovingForward = true

    private var question: QuizQuestion { Quiz.questions[index] }

    var body: some View {
        Group {
            if showResult {
                QuizResultView(answers: answers) { complete() }
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else {
                questionScreen
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 1), value: showResult)
        .onAppear { Haptics.prepare() }
    }

    private var questionScreen: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingHeader(
                step: OnboardingFlow.quizStepRank(index),
                onBack: index > 0 ? goBack : nil
            )

            VStack(alignment: .leading, spacing: 0) {
                Text(question.prompt)
                    .font(.system(.title, design: .rounded, weight: .heavy))
                    // Les grandes tailles font paraître les lettres trop espacées :
                    // resserrer le crénage rend le titre compact sans le rapetisser.
                    .tracking(-0.5)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 32)

                VStack(spacing: 12) {
                    ForEach(question.options) { option in
                        optionRow(option)
                    }
                }
                .padding(.top, 28)
            }
            .padding(.horizontal, 24)
            .id(index)
            .onboardingStepTransition(forward: isMovingForward, reduceMotion: reduceMotion)

            Spacer(minLength: 0)
        }
    }

    private func optionRow(_ option: QuizOption) -> some View {
        let isSelected = answers[question.id]?.id == option.id

        return Button {
            Haptics.select()
            answers[question.id] = option
            // Court délai pour que la sélection soit visible avant d'enchaîner.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                isMovingForward = true
                withAnimation(.spring(response: 0.45, dampingFraction: 1)) {
                    if index < Quiz.questions.count - 1 {
                        index += 1
                    } else {
                        showResult = true
                    }
                }
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: option.symbol)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(isSelected ? .white : Color.accentColor)
                    .frame(width: 34, height: 34)
                    .background(
                        isSelected ? Color.accentColor : Color.accentColor.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )

                Text(option.label)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
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

    private func goBack() {
        Haptics.tap()
        isMovingForward = false
        withAnimation(.spring(response: 0.4, dampingFraction: 1)) { index -= 1 }
    }

    private func complete() {
        let scores = Quiz.scores(for: answers)
        let profile = Quiz.profile(
            for: scores,
            stage: Quiz.stage(from: answers),
            intent: Quiz.intent(from: answers)
        )
        let preferred = Quiz.preferredCategories(for: scores)

        SharedDefaults.quizProfile = profile.key
        SharedDefaults.preferredCategories = preferred

        Analytics.track(.quizCompleted, [
            "profile": .string(profile.key),
            "top_category": .string(preferred.first?.rawValue ?? "none"),
            "preferred_count": .int(preferred.count)
        ])

        hasCompletedQuiz = true
    }
}

struct QuizResultView: View {
    let answers: [Int: QuizOption]
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Le révélé se fait par paliers plutôt que d'un bloc : l'insigne, puis le nom, puis
    /// les barres l'une après l'autre. Le contenu est le même, la lecture est guidée.
    @State private var stage = 0

    private var scores: [QuoteCategory: Double] { Quiz.scores(for: answers) }

    private var profile: QuizProfile {
        Quiz.profile(
            for: scores,
            stage: Quiz.stage(from: answers),
            intent: Quiz.intent(from: answers)
        )
    }

    private var greeting: String {
        SharedDefaults.firstName.map { "\($0), voici ton profil" } ?? "Voici ton profil"
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            badge
                .scaleEffect(stage >= 1 ? 1 : 0.6)
                .opacity(stage >= 1 ? 1 : 0)

            Text(greeting)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 22)
                .opacity(stage >= 2 ? 1 : 0)

            // Le nom de profil ayant disparu, c'est la description qui devient le titre :
            // sans cette promotion typographique, l'écran de résultat n'aurait plus rien
            // à regarder entre l'insigne et les barres.
            Text(profile.tagline)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .tracking(-0.4)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 28)
                .padding(.top, 6)
                .opacity(stage >= 2 ? 1 : 0)
                .offset(y: stage >= 2 ? 0 : 8)

            VStack(spacing: 12) {
                ForEach(Array(QuoteCategory.allCases.enumerated()), id: \.element) { position, category in
                    scoreBar(category, position: position)
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 32)

            Spacer(minLength: 0)

            Button {
                Haptics.commit()
                onContinue()
            } label: {
                Text("Découvrir mes citations")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(PressableButtonStyle(scale: 0.97))
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
            .opacity(stage >= 3 ? 1 : 0)
        }
        .task { await reveal() }
    }

    private var badge: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.orange, .orange.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 104, height: 104)
                .shadow(color: .orange.opacity(0.35), radius: 22, y: 10)
            Image(systemName: profile.symbol)
                .font(.system(size: 42))
                .foregroundStyle(.white)
        }
    }

    private func scoreBar(_ category: QuoteCategory, position: Int) -> some View {
        let value = scores[category] ?? 0
        return HStack(spacing: 12) {
            Image(systemName: category.symbolName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(category.tint)
                .frame(width: 20)

            Text(category.displayName)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(width: 150, alignment: .leading)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.tertiarySystemFill))
                    Capsule()
                        .fill(category.tint)
                        .frame(width: proxy.size.width * (stage >= 3 ? value : 0))
                }
            }
            .frame(height: 8)
        }
        .opacity(stage >= 3 ? 1 : 0)
        // Décalage par barre : elles se remplissent en cascade au lieu de toutes bouger
        // ensemble, ce qui donne le temps de lire chaque ligne.
        .animation(
            reduceMotion
                ? .easeOut(duration: 0.2)
                : .spring(response: 0.6, dampingFraction: 1).delay(Double(position) * 0.08),
            value: stage
        )
    }

    private func reveal() async {
        guard !reduceMotion else {
            stage = 3
            Haptics.success()
            return
        }
        // Léger dépassement sur l'insigne uniquement : c'est le seul élément qui « arrive »,
        // les autres se posent sans rebond.
        withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) { stage = 1 }
        Haptics.success()

        try? await Task.sleep(nanoseconds: 220_000_000)
        withAnimation(.spring(response: 0.45, dampingFraction: 1)) { stage = 2 }

        try? await Task.sleep(nanoseconds: 260_000_000)
        withAnimation(.spring(response: 0.45, dampingFraction: 1)) { stage = 3 }
    }
}

#Preview {
    QuizView()
}

import SwiftUI
import UIKit

struct QuizView: View {
    @AppStorage("hasCompletedQuiz") private var hasCompletedQuiz = false
    @State private var index = 0
    @State private var answers: [Int: QuizOption] = [:]
    @State private var showResult = false

    private var question: QuizQuestion { Quiz.questions[index] }
    private var progress: Double { Double(index + 1) / Double(Quiz.questions.count) }

    var body: some View {
        Group {
            if showResult {
                QuizResultView(scores: Quiz.scores(for: answers)) { complete() }
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            } else {
                questionScreen
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: showResult)
    }

    private var questionScreen: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                if index > 0 {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { index -= 1 }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text("\(index + 1) / \(Quiz.questions.count)")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)

            ProgressView(value: progress)
                .tint(Color.accentColor)
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .animation(.spring(response: 0.4, dampingFraction: 0.9), value: progress)

            Text(question.prompt)
                .font(.system(.title, design: .rounded, weight: .heavy))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
                .padding(.top, 32)

            VStack(spacing: 12) {
                ForEach(question.options) { option in
                    optionRow(option)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)

            Spacer()
        }
        .id(index)
    }

    private func optionRow(_ option: QuizOption) -> some View {
        let isSelected = answers[question.id]?.id == option.id

        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            answers[question.id] = option
            // Small delay so the selection is visible before moving on.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
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
    }

    private func complete() {
        let scores = Quiz.scores(for: answers)
        SharedDefaults.quizProfile = Quiz.profile(for: scores).name
        SharedDefaults.preferredCategories = Quiz.preferredCategories(for: scores)
        hasCompletedQuiz = true
    }
}

struct QuizResultView: View {
    let scores: [QuoteCategory: Double]
    let onContinue: () -> Void

    @State private var revealed = false

    private var profile: QuizProfile { Quiz.profile(for: scores) }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.orange, .orange.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 104, height: 104)
                    .shadow(color: .orange.opacity(0.35), radius: 22, y: 10)
                Image(systemName: profile.symbol)
                    .font(.system(size: 42))
                    .foregroundStyle(.white)
            }
            .scaleEffect(revealed ? 1 : 0.7)
            .opacity(revealed ? 1 : 0)

            Text("Ton profil")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 22)

            Text(profile.name)
                .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                .padding(.top, 2)

            Text(profile.tagline)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.top, 8)

            VStack(spacing: 12) {
                ForEach(QuoteCategory.allCases) { category in
                    scoreBar(category)
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 32)

            Spacer()

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { revealed = true }
        }
    }

    private func scoreBar(_ category: QuoteCategory) -> some View {
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
                        .frame(width: proxy.size.width * (revealed ? value : 0))
                }
            }
            .frame(height: 8)
        }
        .animation(.spring(response: 0.7, dampingFraction: 0.85).delay(0.15), value: revealed)
    }
}

#Preview {
    QuizView()
}

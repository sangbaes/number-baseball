import SwiftUI

struct SoloGameView: View {
    @EnvironmentObject var loc: LocalizationManager
    @State private var answer: String = NumberBaseballLogic.generateAnswer()
    @State private var guessInput: String = ""
    @State private var attempts: Int = 0
    @State private var history: [GuessRecord] = []
    @State private var showResultModal: Bool = false
    @State private var resultTitle: String = ""
    @State private var resultDetail: String = ""
    @State private var resultEmoji: String = "🎉"
    @State private var resultShareText: String = ""
    @State private var alertMessage: String?
    @FocusState private var isFocused: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var shouldDismissView = false

    private let maxAttempts = 30

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("\(attempts)/\(maxAttempts)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 38)

                TextField("000", text: $guessInput)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .frame(width: 80)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .focused($isFocused)
                    .onChange(of: guessInput) { _, newValue in
                        guessInput = BaseballLogic.filterUniqueDigits(newValue)
                    }
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Text("\(attempts)/\(maxAttempts)")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)

                            Spacer()

                            Button {
                                submitGuess()
                            } label: {
                                Text(loc.t("solo.guess"))
                                    .font(.system(size: 16, weight: .bold))
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 6)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(attempts >= maxAttempts)
                        }
                    }

                Spacer()

                Menu {
                    Button(loc.t("solo.newGame")) { newGame() }
                    Button(loc.t("solo.showAnswer")) { alertMessage = loc.t("solo.answer", answer) }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            if history.isEmpty {
                Spacer()
                Text(loc.t("solo.emptyHint"))
                    .foregroundStyle(.tertiary)
                    .font(.subheadline)
                Spacer()
            } else {
                List {
                    ForEach(Array(history.enumerated()), id: \.element.id) { idx, item in
                        HStack(spacing: 12) {
                            Text("#\(history.count - idx)")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(.tertiary)
                                .frame(width: 28, alignment: .trailing)

                            Text(item.guess)
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .monospacedDigit()

                            Spacer()

                            Text(item.resultText)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(resultBackground(item.resultText))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(loc.t("solo.title"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(loc.t("solo.alert"), isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button(loc.t("common.ok"), role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
        .sheet(isPresented: $showResultModal, onDismiss: {
            if shouldDismissView {
                shouldDismissView = false
                dismiss()
            }
        }) {
            ResultSheet(
                loc: loc,
                emoji: resultEmoji,
                title: resultTitle,
                detail: resultDetail,
                shareText: resultShareText,
                onNewGame: { newGame(); showResultModal = false },
                onClose: { shouldDismissView = true; showResultModal = false }
            )
            .presentationDetents([.medium])
        }
        .onAppear {
            isFocused = true
            GameAnalytics.screenView("solo_game")
            GameAnalytics.soloGameStarted()
        }
    }

    private func resultBackground(_ text: String) -> Color {
        if text.contains("3S") { return .green.opacity(0.2) }
        if text.contains("S")  { return .orange.opacity(0.15) }
        if text.contains("B")  { return .blue.opacity(0.1) }
        return .gray.opacity(0.1)
    }

    private func submitGuess() {
        guard attempts < maxAttempts else { return }

        do {
            let guess = try NumberBaseballLogic.validateGuess(guessInput, loc: loc)
            attempts += 1

            let (s, b) = NumberBaseballLogic.strikeBall(answer: answer, guess: guess)
            let text = NumberBaseballLogic.formatResult(strike: s, ball: b)

            history.insert(GuessRecord(guess: guess, resultText: text), at: 0)
            guessInput = ""

            GameAnalytics.guessSubmitted(attempt: attempts)

            if s == 3 {
                resultEmoji = "🎉"
                resultTitle = loc.t("solo.winTitle")
                resultDetail = loc.t("solo.winDetail", attempts, answer)
                resultShareText = "\(loc.t("share.soloWin", attempts))\n\(AppConfig.appStoreURL)"
                showResultModal = true
                GameAnalytics.soloGameWon(attempts: attempts)
            } else if attempts >= maxAttempts {
                resultEmoji = "😢"
                resultTitle = loc.t("solo.loseTitle")
                resultDetail = loc.t("solo.loseDetail", maxAttempts, answer)
                resultShareText = "\(loc.t("share.soloLose", maxAttempts))\n\(AppConfig.appStoreURL)"
                showResultModal = true
                GameAnalytics.soloGameLost()
            }

            isFocused = true
        } catch {
            alertMessage = error.localizedDescription
            guessInput = ""
            isFocused = true
        }
    }

    private func newGame() {
        answer = NumberBaseballLogic.generateAnswer()
        guessInput = ""
        attempts = 0
        history.removeAll()
        isFocused = true
    }
}

private struct ResultSheet: View {
    let loc: LocalizationManager
    let emoji: String
    let title: String
    let detail: String
    let shareText: String
    let onNewGame: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text(emoji).font(.system(size: 64))
            Text(title).font(.title.bold())
            Text(detail)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            // 결과 공유 버튼
            if !shareText.isEmpty {
                ShareLink(item: shareText) {
                    Label(loc.t("share.resultButton"), systemImage: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.accentColor.opacity(0.25), lineWidth: 1)
                        )
                        .foregroundStyle(Color.accentColor)
                }
                .padding(.horizontal)
            }

            HStack {
                Button(loc.t("solo.newGame")) { onNewGame() }
                    .buttonStyle(.borderedProminent)
                Button(loc.t("common.close")) { onClose() }
                    .buttonStyle(.bordered)
            }
            .padding(.top, 2)
        }
        .padding()
    }
}

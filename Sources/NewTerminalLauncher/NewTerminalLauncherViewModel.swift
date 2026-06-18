import Foundation
import Combine

@MainActor
final class NewTerminalLauncherViewModel: ObservableObject {
    private static let maximumCollapsedCards = 13

    private let cache: NewTerminalLauncherCandidateCache?
    private let localShellSubtitle: String

    @Published private(set) var cards: [NewTerminalLauncherCardSnapshot]
    @Published var filterText = ""
    @Published private(set) var selectedID: String?
    @Published private(set) var isLoading = false
    @Published private(set) var showsAllHosts = false

    init(
        cache: NewTerminalLauncherCandidateCache?,
        localShellSubtitle: String
    ) {
        self.cache = cache
        self.localShellSubtitle = localShellSubtitle
        let localCard = NewTerminalLauncherCardSnapshot.localShell(subtitle: localShellSubtitle)
        self.cards = [localCard]
        self.selectedID = localCard.id
    }

    var filteredCards: [NewTerminalLauncherCardSnapshot] {
        let query = filterText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return cards }
        return cards.filter { card in
            card.title.lowercased().contains(query)
                || card.subtitle.lowercased().contains(query)
                || (card.destination?.lowercased().contains(query) ?? false)
        }
    }

    var visibleCards: [NewTerminalLauncherCardSnapshot] {
        let filtered = filteredCards
        guard !showsAllHosts else { return filtered }
        return Array(filtered.prefix(Self.maximumCollapsedCards))
    }

    var hiddenCardCount: Int {
        max(0, filteredCards.count - visibleCards.count)
    }

    var selectedCard: NewTerminalLauncherCardSnapshot? {
        let visible = visibleCards
        if let selectedID,
           let selected = visible.first(where: { $0.id == selectedID }) {
            return selected
        }
        return visible.first
    }

    func load() async {
        guard let cache else { return }
        isLoading = true
        let remoteCards = await cache.remoteCards()
        cards = [NewTerminalLauncherCardSnapshot.localShell(subtitle: localShellSubtitle)] + remoteCards
        normalizeSelection()
        isLoading = false
    }

    func select(_ card: NewTerminalLauncherCardSnapshot) {
        selectedID = card.id
    }

    func moveSelection(delta: Int) {
        let visible = visibleCards
        guard !visible.isEmpty else { return }
        let currentIndex = selectedID.flatMap { id in
            visible.firstIndex(where: { $0.id == id })
        } ?? 0
        let nextIndex = min(max(currentIndex + delta, 0), visible.count - 1)
        selectedID = visible[nextIndex].id
    }

    func setShowsAllHosts(_ value: Bool) {
        showsAllHosts = value
        normalizeSelection()
    }

    func normalizeSelection() {
        let visible = visibleCards
        guard !visible.isEmpty else {
            selectedID = nil
            return
        }
        if let selectedID,
           visible.contains(where: { $0.id == selectedID }) {
            return
        }
        selectedID = visible.first?.id
    }
}

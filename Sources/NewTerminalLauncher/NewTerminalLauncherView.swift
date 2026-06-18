import SwiftUI

struct NewTerminalLauncherView: View {
    @StateObject private var viewModel: NewTerminalLauncherViewModel
    @FocusState private var filterIsFocused: Bool

    let appearance: PanelAppearance
    let onOpen: (NewTerminalLauncherCardSnapshot) -> Void

    init(
        cache: NewTerminalLauncherCandidateCache?,
        localShellSubtitle: String,
        appearance: PanelAppearance,
        onOpen: @escaping (NewTerminalLauncherCardSnapshot) -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: NewTerminalLauncherViewModel(
                cache: cache,
                localShellSubtitle: localShellSubtitle
            )
        )
        self.appearance = appearance
        self.onOpen = onOpen
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                cardGrid
                showMoreButton
            }
            .frame(maxWidth: 980, alignment: .leading)
            .padding(.horizontal, 32)
            .padding(.vertical, 30)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .scrollDismissesKeyboard(.immediately)
        .background(Color(nsColor: appearance.backgroundColor))
        .foregroundStyle(RightSidebarCatppuccinMochaPalette.text)
        .task {
            await viewModel.load()
        }
        .onAppear {
            filterIsFocused = true
        }
        .onChange(of: viewModel.filterText) {
            viewModel.normalizeSelection()
        }
        .backport.onKeyPress(.upArrow) { _ in
            viewModel.moveSelection(delta: -adaptiveColumnCount)
            return .handled
        }
        .backport.onKeyPress(.downArrow) { _ in
            viewModel.moveSelection(delta: adaptiveColumnCount)
            return .handled
        }
        .backport.onKeyPress(.leftArrow) { _ in
            viewModel.moveSelection(delta: -1)
            return .handled
        }
        .backport.onKeyPress(.rightArrow) { _ in
            viewModel.moveSelection(delta: 1)
            return .handled
        }
        .backport.onKeyPress(.return) { _ in
            if let card = viewModel.selectedCard {
                onOpen(card)
                return .handled
            }
            return .ignored
        }
    }

    private var adaptiveColumnCount: Int {
        3
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "newTerminalLauncher.title", defaultValue: "New Terminal"))
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .foregroundStyle(RightSidebarCatppuccinMochaPalette.text)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            TextField(
                String(localized: "newTerminalLauncher.filter.placeholder", defaultValue: "Filter hosts"),
                text: $viewModel.filterText
            )
            .textFieldStyle(.plain)
            .font(.system(size: 15, weight: .medium, design: .rounded))
            .foregroundStyle(RightSidebarCatppuccinMochaPalette.text)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(RightSidebarCatppuccinMochaPalette.surface0.opacity(0.72))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(RightSidebarCatppuccinMochaPalette.softHairline, lineWidth: 1)
            }
            .focused($filterIsFocused)
            .onSubmit {
                if let card = viewModel.selectedCard {
                    onOpen(card)
                }
            }
        }
    }

    private var cardGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.adaptive(minimum: 210, maximum: 300), spacing: 14, alignment: .top)
            ],
            alignment: .leading,
            spacing: 14
        ) {
            ForEach(viewModel.visibleCards) { card in
                NewTerminalLauncherCardView(
                    snapshot: card,
                    isSelected: card.id == viewModel.selectedID,
                    onSelect: {
                        viewModel.select(card)
                    },
                    onOpen: {
                        onOpen(card)
                    }
                )
            }

            if viewModel.visibleCards.isEmpty {
                Text(String(localized: "newTerminalLauncher.empty", defaultValue: "No matching hosts"))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(RightSidebarCatppuccinMochaPalette.subtext0)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
            } else if viewModel.isLoading {
                Text(String(localized: "newTerminalLauncher.loading", defaultValue: "Loading hosts..."))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(RightSidebarCatppuccinMochaPalette.overlay0)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            }
        }
    }

    @ViewBuilder
    private var showMoreButton: some View {
        if viewModel.hiddenCardCount > 0 || viewModel.showsAllHosts {
            Button {
                viewModel.setShowsAllHosts(!viewModel.showsAllHosts)
            } label: {
                Text(
                    viewModel.showsAllHosts
                    ? String(localized: "newTerminalLauncher.showLess", defaultValue: "Show Less")
                    : String.localizedStringWithFormat(
                        String(localized: "newTerminalLauncher.showMore", defaultValue: "Show %d More"),
                        viewModel.hiddenCardCount
                    )
                )
                .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .buttonStyle(.plain)
            .foregroundStyle(RightSidebarCatppuccinMochaPalette.blue)
        }
    }
}

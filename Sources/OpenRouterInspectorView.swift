import SwiftUI

struct OpenRouterInspectorView: View {
    let isActive: Bool
    let host: String

    @State private var store = OpenRouterInspectorStore()

    private var palette: RightSidebarCatppuccinMochaPalette.Type {
        RightSidebarCatppuccinMochaPalette.self
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RightSidebarChromeMetrics.sectionSpacing) {
                headerSection
                sessionsSection
                recentSection
            }
            .padding(RightSidebarChromeMetrics.contentInset)
        }
        .scrollContentBackground(.hidden)
        .background(palette.panelBackdrop)
        .onAppear {
            store.synchronize(isActive: isActive, host: host)
        }
        .onDisappear {
            store.stop()
        }
        .onChange(of: isActive) { _, nextValue in
            store.synchronize(isActive: nextValue, host: host)
        }
        .onChange(of: host) { _, nextValue in
            store.synchronize(isActive: isActive, host: nextValue)
        }
        .accessibilityIdentifier("OpenRouterInspectorView")
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "openRouterInspector.title", defaultValue: "OpenRouter"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(palette.text)
                    Text(hostLabel)
                        .font(.system(size: 10))
                        .foregroundStyle(palette.subtext0)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 0)
                if store.isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.72)
                        .frame(width: 18, height: 18)
                        .accessibilityLabel(String(localized: "openRouterInspector.loading", defaultValue: "Loading"))
                }
                Button {
                    store.refreshNow(host: host)
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10, weight: .semibold))
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .foregroundStyle(palette.subtext0)
                .disabled(store.isLoading)
                .safeHelp(String(localized: "openRouterInspector.reload.tooltip", defaultValue: "Refresh inspector"))
                .accessibilityIdentifier("OpenRouterInspectorRefreshButton")
            }

            usageMeter

            HStack(spacing: 8) {
                metricPill(
                    title: String(localized: "openRouterInspector.balance", defaultValue: "Balance"),
                    value: currency(store.snapshot.openrouter.balance, places: 2)
                )
                metricPill(
                    title: String(localized: "openRouterInspector.usage", defaultValue: "Usage"),
                    value: currency(store.snapshot.openrouter.usage, places: 2)
                )
                metricPill(
                    title: String(localized: "openRouterInspector.limit", defaultValue: "Limit"),
                    value: currency(store.snapshot.openrouter.limit, places: 2)
                )
            }

            HStack(spacing: 8) {
                Label(spendRateText, systemImage: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 10))
                    .foregroundStyle(palette.subtext0)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if let lastUpdated = store.lastUpdated {
                    Text(relativeTime(lastUpdated))
                        .font(.system(size: 10))
                        .foregroundStyle(palette.overlay0)
                }
            }

            statusMessages
        }
        .padding(10)
        .rightSidebarInsetGroup(cornerRadius: 8)
    }

    private var usageMeter: some View {
        GeometryReader { proxy in
            let ratio = usageRatio
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(palette.crust)
                Capsule()
                    .fill(meterColor.opacity(0.86))
                    .frame(width: max(0, proxy.size.width * ratio))
            }
        }
        .frame(height: 6)
        .accessibilityLabel(String(localized: "openRouterInspector.meter.accessibilityLabel", defaultValue: "OpenRouter usage meter"))
    }

    private var sessionsSection: some View {
        let profilesByID = Dictionary(uniqueKeysWithValues: store.snapshot.profiles.map { ($0.id, $0.label) })
        let choices = selectionChoices
        return VStack(alignment: .leading, spacing: 8) {
            sectionHeader(
                String(localized: "openRouterInspector.sessions.title", defaultValue: "Detected CC Sessions"),
                count: store.snapshot.sessions.count
            )
            if store.snapshot.sessions.isEmpty {
                emptyState(
                    title: String(localized: "openRouterInspector.empty.sessions.title", defaultValue: "No sessions detected"),
                    subtitle: String(localized: "openRouterInspector.empty.sessions.subtitle", defaultValue: "Remote Claude Code sessions will appear here when the inspector reports them.")
                )
            } else {
                VStack(spacing: 0) {
                    let sessionRows = Array(store.snapshot.sessions.enumerated())
                    ForEach(sessionRows, id: \.offset) { index, session in
                        OpenRouterInspectorSessionRow(
                            session: session,
                            profileLabel: session.profile.flatMap { profilesByID[$0] },
                            choices: choices,
                            isActionRunning: store.isRunningAction,
                            onSwitchNow: { target in
                                store.switchNow(session: session, target: target, host: host)
                            },
                            onSetDefault: { target in
                                store.setDefault(target: target, host: host)
                            }
                        )
                        if index != sessionRows.indices.last {
                            RightSidebarCatppuccinDivider()
                        }
                    }
                }
            }
        }
        .padding(10)
        .rightSidebarInsetGroup(cornerRadius: 8)
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(
                String(localized: "openRouterInspector.recent.title", defaultValue: "Recent Generations"),
                count: store.snapshot.openrouter.recent.count
            )
            if store.snapshot.openrouter.recent.isEmpty {
                emptyState(
                    title: String(localized: "openRouterInspector.empty.recent.title", defaultValue: "No recent generations"),
                    subtitle: String(localized: "openRouterInspector.empty.recent.subtitle", defaultValue: "OpenRouter usage events will appear here after the remote script reports them.")
                )
            } else {
                VStack(spacing: 0) {
                    let generationRows = Array(store.snapshot.openrouter.recent.enumerated())
                    ForEach(generationRows, id: \.offset) { index, generation in
                        OpenRouterInspectorGenerationRow(generation: generation)
                        if index != generationRows.indices.last {
                            RightSidebarCatppuccinDivider()
                        }
                    }
                }
            }
        }
        .padding(10)
        .rightSidebarInsetGroup(cornerRadius: 8)
    }

    @ViewBuilder
    private var statusMessages: some View {
        if let actionMessage = store.actionMessage {
            Text(actionMessage)
                .font(.system(size: 10))
                .foregroundStyle(store.actionIsError ? Color.red.opacity(0.92) : palette.blue)
                .fixedSize(horizontal: false, vertical: true)
        }
        if let lastErrorMessage = store.lastErrorMessage {
            Text(lastErrorMessage)
                .font(.system(size: 10))
                .foregroundStyle(Color.red.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var hostLabel: String {
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return String(localized: "openRouterInspector.host.missing", defaultValue: "No host configured")
        }
        return String.localizedStringWithFormat(
            String(localized: "openRouterInspector.host", defaultValue: "Host: %@"),
            trimmed
        )
    }

    private var usageRatio: CGFloat {
        guard let usage = store.snapshot.openrouter.usage,
              let limit = store.snapshot.openrouter.limit,
              limit > 0 else {
            return 0
        }
        return CGFloat(min(max(usage / limit, 0), 1))
    }

    private var meterColor: Color {
        if usageRatio >= 0.9 {
            return Color(red: 0.96, green: 0.48, blue: 0.54)
        }
        if usageRatio >= 0.7 {
            return Color(red: 0.98, green: 0.74, blue: 0.44)
        }
        return palette.mauve
    }

    private var spendRateText: String {
        let recent = store.snapshot.openrouter.recent
        let costs = recent.compactMap(\.cost)
        guard !costs.isEmpty else {
            return String(localized: "openRouterInspector.spendRate.none", defaultValue: "No recent spend")
        }
        let total = costs.reduce(0, +)
        let timestamps = recent.compactMap(\.timestamp)
        guard let earliest = timestamps.min(),
              let latest = timestamps.max(),
              latest.timeIntervalSince(earliest) > 60 else {
            return String.localizedStringWithFormat(
                String(localized: "openRouterInspector.spendRate.total", defaultValue: "%@ recent"),
                currency(total, places: 4)
            )
        }
        let hours = max(latest.timeIntervalSince(earliest) / 3_600, 0.01)
        return String.localizedStringWithFormat(
            String(localized: "openRouterInspector.spendRate.hour", defaultValue: "%@/hr recent"),
            currency(total / hours, places: 4)
        )
    }

    private var selectionChoices: [OpenRouterInspectorChoice] {
        let profileChoices = store.snapshot.profiles.map {
            OpenRouterInspectorChoice(kind: .profile, value: $0.id, title: $0.label)
        }
        let modelChoices = store.snapshot.models.map {
            OpenRouterInspectorChoice(kind: .model, value: $0, title: $0)
        }
        return profileChoices + modelChoices
    }

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(palette.text)
            Text(String(count))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(palette.subtext0)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(palette.crust))
            Spacer(minLength: 0)
        }
    }

    private func emptyState(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(palette.subtext0)
            Text(subtitle)
                .font(.system(size: 10))
                .foregroundStyle(palette.overlay0)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    private func metricPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(palette.overlay0)
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(palette.text)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 7)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(palette.crust.opacity(0.78))
        )
    }
}

private struct OpenRouterInspectorChoice: Identifiable, Equatable {
    enum Kind: String {
        case profile
        case model
    }

    let kind: Kind
    let value: String
    let title: String

    var id: String {
        "\(kind.rawValue)-\(value)"
    }
}

private struct OpenRouterInspectorSessionRow: View {
    let session: OpenRouterInspectorSession
    let profileLabel: String?
    let choices: [OpenRouterInspectorChoice]
    let isActionRunning: Bool
    let onSwitchNow: (String) -> Void
    let onSetDefault: (String) -> Void

    private var palette: RightSidebarCatppuccinMochaPalette.Type {
        RightSidebarCatppuccinMochaPalette.self
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(session.running ? Color.green.opacity(0.82) : palette.overlay0.opacity(0.62))
                .frame(width: 7, height: 7)
                .padding(.top, 5)
                .accessibilityLabel(session.running
                    ? String(localized: "openRouterInspector.running", defaultValue: "Running")
                    : String(localized: "openRouterInspector.stopped", defaultValue: "Stopped")
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(session.displayName)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(palette.text)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if let pid = session.pid {
                        Text(String.localizedStringWithFormat(
                            String(localized: "openRouterInspector.pid", defaultValue: "PID %@"),
                            String(pid)
                        ))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(palette.overlay0)
                    }
                    Spacer(minLength: 0)
                    switcherMenu
                }
                detailLine(
                    title: String(localized: "openRouterInspector.profile", defaultValue: "Profile"),
                    value: profileLabel ?? session.profile ?? String(localized: "openRouterInspector.unknown", defaultValue: "Unknown")
                )
                detailLine(
                    title: String(localized: "openRouterInspector.model", defaultValue: "Model"),
                    value: session.model ?? String(localized: "openRouterInspector.unknown", defaultValue: "Unknown")
                )
            }
        }
        .padding(.vertical, 8)
    }

    private var switcherMenu: some View {
        Menu {
            let profileChoices = choices.filter { $0.kind == .profile }
            let modelChoices = choices.filter { $0.kind == .model }
            if !profileChoices.isEmpty {
                Section(String(localized: "openRouterInspector.switch.profiles", defaultValue: "Profiles")) {
                    ForEach(profileChoices) { choice in
                        choiceMenu(choice)
                    }
                }
            }
            if !modelChoices.isEmpty {
                Section(String(localized: "openRouterInspector.switch.models", defaultValue: "Models")) {
                    ForEach(modelChoices) { choice in
                        choiceMenu(choice)
                    }
                }
            }
            if choices.isEmpty {
                Text(String(localized: "openRouterInspector.switch.empty", defaultValue: "No models or profiles reported"))
            }
        } label: {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 10, weight: .semibold))
                .frame(width: 18, height: 18)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .foregroundStyle(palette.subtext0)
        .disabled(isActionRunning || choices.isEmpty)
        .safeHelp(String(localized: "openRouterInspector.switch.menu", defaultValue: "Switch model"))
    }

    private func choiceMenu(_ choice: OpenRouterInspectorChoice) -> some View {
        Menu(choice.title) {
            Button(String(localized: "openRouterInspector.switch.now", defaultValue: "Switch now (restart + resume)")) {
                onSwitchNow(choice.value)
            }
            .disabled(session.window == nil)

            Button(String(localized: "openRouterInspector.switch.default", defaultValue: "Set as default for next session")) {
                onSetDefault(choice.value)
            }
        }
    }

    private func detailLine(title: String, value: String) -> some View {
        HStack(spacing: 5) {
            Text(title)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(palette.overlay0)
            Text(value)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(palette.subtext0)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

private struct OpenRouterInspectorGenerationRow: View {
    let generation: OpenRouterInspectorGeneration

    private var palette: RightSidebarCatppuccinMochaPalette.Type {
        RightSidebarCatppuccinMochaPalette.self
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(palette.mauve.opacity(0.9))
                .frame(width: 14, height: 16)
            VStack(alignment: .leading, spacing: 4) {
                Text(generation.model)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(palette.text)
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(spacing: 8) {
                    Text(costText)
                    Text(tokensText)
                    if let timestamp = generation.timestamp {
                        Text(relativeTime(timestamp))
                    }
                }
                .font(.system(size: 9))
                .foregroundStyle(palette.overlay0)
                .lineLimit(1)
            }
        }
        .padding(.vertical, 7)
    }

    private var costText: String {
        String.localizedStringWithFormat(
            String(localized: "openRouterInspector.cost", defaultValue: "Cost %@"),
            currency(generation.cost, places: 4)
        )
    }

    private var tokensText: String {
        guard let tokens = generation.tokens else {
            return String(localized: "openRouterInspector.tokens.unknown", defaultValue: "Tokens -")
        }
        return String.localizedStringWithFormat(
            String(localized: "openRouterInspector.tokens", defaultValue: "%@ tokens"),
            tokens.formatted(.number)
        )
    }
}

private func currency(_ value: Double?, places: Int) -> String {
    guard let value else {
        return String(localized: "openRouterInspector.valueUnavailable", defaultValue: "-")
    }
    return String(format: "$%.\(places)f", value)
}

private func relativeTime(_ date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .short
    return formatter.localizedString(for: date, relativeTo: Date())
}

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                configurationSection
                statusSection
                quotesSection
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 760, minHeight: 640)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notion Quotes")
                .font(.system(size: 30, weight: .semibold))

            Text("Configura il database Notion, sincronizza le frasi e lascia che il widget le ruoti automaticamente con l'intervallo scelto.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Con account Apple gratuito il widget va configurato direttamente nelle sue impostazioni e legge Notion in autonomia.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var configurationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Configurazione")
                .font(.title2.weight(.semibold))

            VStack(alignment: .leading, spacing: 12) {
                SecureField("Notion integration token", text: $viewModel.notionToken)
                    .textFieldStyle(.roundedBorder)

                TextField("Database ID", text: $viewModel.databaseID)
                    .textFieldStyle(.roundedBorder)

                TextField("Nome proprietà titolo", text: $viewModel.titlePropertyName)
                    .textFieldStyle(.roundedBorder)

                TextField("Nome proprietà fonte", text: $viewModel.sourcePropertyName)
                    .textFieldStyle(.roundedBorder)

                HStack(spacing: 12) {
                    Stepper(value: $viewModel.refreshIntervalSeconds, in: SharedConstants.minimumRefreshIntervalSeconds ... 3600, step: 30) {
                        Text("Intervallo di rotazione: \(viewModel.refreshIntervalSeconds) secondi")
                    }

                    Spacer()
                }

                HStack(spacing: 12) {
                    Button("Salva configurazione") {
                        viewModel.saveSettings()
                    }

                    Button("Forza refresh widget") {
                        viewModel.forceRefreshWidget()
                    }
                    .buttonStyle(.bordered)

                    Button(viewModel.isSyncing ? "Sincronizzazione in corso..." : "Sincronizza da Notion") {
                        Task {
                            await viewModel.syncQuotes()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isSyncing)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    @ViewBuilder
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let statusMessage = viewModel.statusMessage {
                Text(statusMessage)
                    .foregroundStyle(.green)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }

            if let lastSync = viewModel.lastSync {
                Text("Ultima sincronizzazione: \(lastSync.formatted(date: .abbreviated, time: .shortened))")
                    .foregroundStyle(.secondary)
            } else {
                Text("Nessuna sincronizzazione eseguita finora.")
                    .foregroundStyle(.secondary)
            }

            Text("Frasi presenti nella cache locale dell'app: \(viewModel.quotes.count)")
                .foregroundStyle(.secondary)

            Text(viewModel.diagnosticsSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var quotesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Frasi in cache")
                    .font(.title2.weight(.semibold))

                Spacer()

                Text("\(viewModel.quotes.count) elementi")
                    .foregroundStyle(.secondary)
            }

            if viewModel.quotes.isEmpty {
                Text("Dopo la prima sincronizzazione vedrai qui l'anteprima delle frasi lette da Notion.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
            } else {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.quotes) { quote in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(quote.title)
                                .font(.headline)
                                .fixedSize(horizontal: false, vertical: true)

                            if let source = quote.source, !source.isEmpty {
                                Text(source)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(nsColor: .controlBackgroundColor))
                        )
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}

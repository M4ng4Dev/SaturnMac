import SwiftUI
import UniformTypeIdentifiers
import AppKit

@main
struct SaturnMacApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 840, minHeight: 620)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
    }
}

// MARK: - Data Models

struct SaturnDiscMetadata: Identifiable, Codable {
    var id: String { product_id + title }
    var hardware_id: String = "SEGA SEGASATURN"
    var maker_id: String = "SEGA ENTERPRISES"
    var product_id: String = "MK-00000"
    var version: String = "V1.000"
    var release_date: String = "1996"
    var disc_info: String = "CD-1/1"
    var region_codes: String = "U"
    var regions: [String] = ["North America / USA"]
    var peripheral_codes: String = "J"
    var peripherals: [String] = ["Standard Control Pad"]
    var title: String = "Sega Saturn Game"
    var sector_mode: String = "RAW (2352 bytes)"
    var tracks: [TrackInfo] = []
    var filePath: URL? = nil
    var coverArtURL: URL? = nil
}

struct TrackInfo: Codable {
    let number: Int
    let track_type: String
    let filename: String
}

struct PortedApp: Identifiable {
    let id = UUID()
    let name: String
    let url: URL
    let icon: NSImage?
    let dateModified: Date
}

// MARK: - Main Content View

struct ContentView: View {
    @State private var selectedTab: Int = 0 // 0 = Portejar, 1 = Biblioteca
    @State private var isTargeted: Bool = false
    @State private var loadedGame: SaturnDiscMetadata? = nil
    @State private var coverImage: NSImage? = nil
    @State private var isLoadingArt: Bool = false

    // Options
    @State private var internalResolution: Int = 4 // 1, 2, 4, 8
    @State private var enableAntiAliasing: Bool = true
    @State private var enableDeDither: Bool = true
    @State private var enableCRTShader: Bool = false
    @State private var enableWidescreen: Bool = false
    @State private var outputDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents/SaturnMac/dist")

    // Process State
    @State private var isProcessing: Bool = false
    @State private var currentStep: String = ""
    @State private var logLines: [String] = []
    @State private var generatedAppURL: URL? = nil
    @State private var showLogs: Bool = false
    @State private var portedGames: [PortedApp] = []

    var body: some View {
        ZStack {
            VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Navigation Bar
                headerBar

                Divider()

                if selectedTab == 0 {
                    portingTabContent
                } else {
                    libraryTabContent
                }
            }
        }
        .onAppear {
            ensureOutputDirectory()
            refreshLibrary()
        }
    }

    // MARK: - Header Bar
    var headerBar: some View {
        HStack {
            Image(systemName: "opticaldisc.fill")
                .font(.system(size: 26))
                .foregroundStyle(.linearGradient(colors: [.cyan, .blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("SaturnMac")
                        .font(.title2.bold())
                    Text("STUDIO")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                }
                Text("Portejador de jocs de Sega Saturn a aplicacions natives de Mac")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Picker("", selection: $selectedTab) {
                Label("Portejar Joc", systemImage: "arrow.triangle.2.circlepath.circle").tag(0)
                Label("Jocs Portejats (\(portedGames.count))", systemImage: "square.grid.2x2").tag(1)
            }
            .pickerStyle(.segmented)
            .frame(width: 320)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Tab 1: Porting Studio
    var portingTabContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let game = loadedGame {
                    gameOverviewCard(game)
                    optionsCard
                    actionsCard
                } else {
                    dropZoneView
                }

                if showLogs || !logLines.isEmpty {
                    logConsoleView
                }
            }
            .padding(20)
        }
    }

    // MARK: - Drop Zone View
    var dropZoneView: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(isTargeted ? Color.blue.opacity(0.15) : Color.secondary.opacity(0.08))
                    .frame(width: 110, height: 110)

                Image(systemName: isTargeted ? "arrow.down.doc.fill" : "square.and.arrow.down.fill")
                    .font(.system(size: 46))
                    .foregroundStyle(isTargeted ? .blue : .secondary)
            }

            VStack(spacing: 6) {
                Text("Arrossega aquí el joc de Sega Saturn que vols portejar")
                    .font(.title3.bold())

                Text("Suporta arxius comprimits .ZIP, fitxers .CUE + pistes, imatges .ISO, .CHD i .BIN")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 500)
            }

            Button(action: selectFile) {
                Label("Triar fitxer de joc...", systemImage: "folder.badge.plus")
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, minHeight: 380)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .stroke(isTargeted ? Color.blue : Color.secondary.opacity(0.25), style: StrokeStyle(lineWidth: 2, dash: [8]))
                .background(Color.secondary.opacity(0.03).cornerRadius(18))
        )
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url = url {
                    DispatchQueue.main.async {
                        self.processSelectedROM(url)
                    }
                }
            }
            return true
        }
    }

    // MARK: - Game Overview Card
    func gameOverviewCard(_ game: SaturnDiscMetadata) -> some View {
        HStack(alignment: .top, spacing: 20) {
            // Box Art Preview
            ZStack {
                if let img = coverImage {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 140, height: 190)
                        .cornerRadius(10)
                        .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 4)
                } else if isLoadingArt {
                    VStack(spacing: 8) {
                        ProgressView()
                        Text("Buscant caràtula...")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 140, height: 190)
                    .background(Color.secondary.opacity(0.08).cornerRadius(10))
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "opticaldisc.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("Sega Saturn")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 140, height: 190)
                    .background(Color.secondary.opacity(0.08).cornerRadius(10))
                }
            }

            // Info Details
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(game.title)
                        .font(.title2.bold())
                        .foregroundColor(.primary)

                    Spacer()

                    Button(action: {
                        self.loadedGame = nil
                        self.coverImage = nil
                        self.generatedAppURL = nil
                        self.logLines.removeAll()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 8) {
                    TagBadge(text: game.product_id, color: .blue)
                    TagBadge(text: game.regions.first ?? "Regió Desconeguda", color: .purple)
                    TagBadge(text: game.version, color: .gray)
                    if !game.tracks.isEmpty {
                        TagBadge(text: "\(game.tracks.count) Pistes", color: .teal)
                    }
                }

                Divider().padding(.vertical, 2)

                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                    GridRow {
                        Text("Desenvolupador:").font(.caption).foregroundStyle(.secondary)
                        Text(game.maker_id).font(.caption.bold())
                    }
                    GridRow {
                        Text("Data llançament:").font(.caption).foregroundStyle(.secondary)
                        Text(game.release_date).font(.caption)
                    }
                    if let f = game.filePath {
                        GridRow {
                            Text("Fitxer origen:").font(.caption).foregroundStyle(.secondary)
                            Text(f.lastPathComponent).font(.caption).lineLimit(1)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.secondary.opacity(0.06)))
    }

    // MARK: - Options Card
    var optionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Configuració del Port per a Apple Silicon")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                // Resolution
                VStack(alignment: .leading, spacing: 6) {
                    Text("Resolució interna de renderitzat (Metal / GPU):")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Picker("", selection: $internalResolution) {
                        Text("1x Nativa (240p original)").tag(1)
                        Text("2x Alta Definició (480p)").tag(2)
                        Text("4x Retina HD (960p) [Recomanat]").tag(4)
                        Text("8x Ultra HD 4K (1920p)").tag(8)
                    }
                    .pickerStyle(.segmented)
                }

                Divider()

                // Graphical enhancements toggles
                HStack(spacing: 30) {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Suavitzat Anti-Aliasing (FXAA)", isOn: $enableAntiAliasing)
                        Toggle("Correcció De-Dither (Transparències suaus)", isOn: $enableDeDither)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Filtre CRT Retro (Scanlines de fòsfor)", isOn: $enableCRTShader)
                        Toggle("Format panoràmic anamòrfic 16:9", isOn: $enableWidescreen)
                    }
                }

                Divider()

                // Destination Folder
                HStack {
                    Text("Carpeta de destinació:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(outputDirectory.path)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(6)

                    Spacer()

                    Button("Canviar...") {
                        selectOutputFolder()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.04)))
        }
    }

    // MARK: - Actions Card
    var actionsCard: some View {
        HStack(spacing: 14) {
            // Test Button
            Button(action: testGameNow) {
                Label("Provar Joc Ara", systemImage: "play.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(isProcessing)

            // Port to Mac .app Button
            Button(action: { portGame(mode: "bundle") }) {
                Label("Portejar a Mac (.app)", systemImage: "macbook.and.arrow.forward")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .controlSize(.large)
            .disabled(isProcessing)

            // Complete Multiplatform Release Button
            Button(action: { portGame(mode: "release") }) {
                Label("Release (Mac + iOS/iPad)", systemImage: "shippingbox")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
            .controlSize(.large)
            .disabled(isProcessing)
        }
    }

    // MARK: - Log Console View
    var logConsoleView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if isProcessing {
                    ProgressView().scaleEffect(0.7)
                    Text(currentStep).font(.subheadline.bold())
                } else if let appURL = generatedAppURL {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                    Text("Joc portat correctament a:")
                        .font(.subheadline.bold())
                    Text(appURL.lastPathComponent)
                        .font(.subheadline.bold())
                        .foregroundColor(.blue)

                    Spacer()

                    Button("Mostrar al Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([appURL])
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("Obrir Joc") {
                        NSWorkspace.shared.open(appURL)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .controlSize(.small)
                }

                Spacer()

                Button(action: { showLogs.toggle() }) {
                    Text(showLogs ? "Amagar registre" : "Veure registre")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }

            if showLogs {
                ScrollView {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(logLines.indices, id: \.self) { idx in
                            Text(logLines[idx])
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(10)
                }
                .frame(height: 120)
                .background(Color.black.opacity(0.85).cornerRadius(8))
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.06)))
    }

    // MARK: - Tab 2: Ported Games Library
    var libraryTabContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Jocs de Sega Saturn instal·lats al Mac")
                        .font(.headline)
                    Spacer()
                    Button(action: refreshLibrary) {
                        Label("Actualitzar", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                if portedGames.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("Encara no has portat cap joc de Saturn.")
                            .font(.headline)
                        Text("Ves a la pestanya 'Portejar Joc' i arrossega qualsevol imatge .zip o .cue per començar!")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 280)
                    .background(Color.secondary.opacity(0.03).cornerRadius(16))
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220, maximum: 260), spacing: 16)], spacing: 16) {
                        ForEach(portedGames) { game in
                            gameLibraryCard(game)
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    func gameLibraryCard(_ game: PortedApp) -> some View {
        VStack(spacing: 12) {
            if let icon = game.icon {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .shadow(radius: 4)
            } else {
                Image(systemName: "opticaldisc.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
            }

            VStack(spacing: 4) {
                Text(game.name)
                    .font(.headline)
                    .lineLimit(1)
                    .multilineTextAlignment(.center)

                Text("Aplicació nativa de macOS")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Button(action: { NSWorkspace.shared.open(game.url) }) {
                    Label("Jugar", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .controlSize(.small)

                Button(action: { NSWorkspace.shared.activateFileViewerSelecting([game.url]) }) {
                    Image(systemName: "folder")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.secondary.opacity(0.06)))
    }

    // MARK: - Logic & Operations

    func selectFile() {
        let panel = NSOpenPanel()
        panel.title = "Selecciona un joc de Sega Saturn"
        panel.allowedContentTypes = [
            UTType(filenameExtension: "cue")!,
            UTType(filenameExtension: "zip")!,
            UTType(filenameExtension: "iso")!,
            UTType(filenameExtension: "bin")!,
            UTType(filenameExtension: "chd") ?? .data
        ]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            processSelectedROM(url)
        }
    }

    func selectOutputFolder() {
        let panel = NSOpenPanel()
        panel.title = "Selecciona la carpeta on desar els jocs portats"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            outputDirectory = url
            refreshLibrary()
        }
    }

    func processSelectedROM(_ url: URL) {
        logLines.removeAll()
        generatedAppURL = nil
        appendLog("🔍 Analitzant imatge de disc: \(url.lastPathComponent)...")

        // Try using saturnmac inspect --json CLI
        DispatchQueue.global(qos: .userInitiated).async {
            var meta = SaturnDiscMetadata()
            meta.filePath = url

            let cleanName = url.deletingPathExtension().lastPathComponent
                .replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(of: "(USA)", with: "")
                .replacingOccurrences(of: "(Europe)", with: "")
                .replacingOccurrences(of: "(Japan)", with: "")
                .trimmingCharacters(in: .whitespaces)

            meta.title = cleanName.uppercased()

            if let saturnmacBin = findBinary("saturnmac") {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: saturnmacBin)
                proc.arguments = ["inspect", url.path, "--json"]
                let pipe = Pipe()
                proc.standardOutput = pipe
                proc.standardError = pipe

                do {
                    try proc.run()
                    proc.waitUntilExit()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    if let json = try? JSONDecoder().decode(SaturnDiscMetadata.self, from: data) {
                        meta = json
                        meta.filePath = url
                    }
                } catch {
                    self.appendLog("⚠️ Avís en la inspecció via CLI, s'utilitzarà el nom de fitxer.")
                }
            }

            DispatchQueue.main.async {
                self.loadedGame = meta
                self.fetchCoverArt(title: meta.title, regions: meta.regions)
            }
        }
    }

    func fetchCoverArt(title: String, regions: [String]) {
        self.isLoadingArt = true
        self.coverImage = nil

        let candidates = [
            "\(title) (USA, Brazil).png",
            "\(title) (USA).png",
            "\(title) (Europe).png",
            "\(title) (Japan).png",
            "\(title).png"
        ]

        DispatchQueue.global(qos: .userInitiated).async {
            for cand in candidates {
                guard let encoded = cand.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { continue }
                let urlString = "http://thumbnails.libretro.com/Sega%20-%20Saturn/Named_Boxarts/\(encoded)"
                if let u = URL(string: urlString), let data = try? Data(contentsOf: u), let img = NSImage(data: data) {
                    DispatchQueue.main.async {
                        self.coverImage = img
                        self.isLoadingArt = false
                        self.appendLog("🎨 S'ha trobat la caràtula oficial per a \(title) a la base de dades.")
                    }
                    return
                }
            }

            DispatchQueue.main.async {
                self.isLoadingArt = false
                self.appendLog("ℹ️ Caràtula online no disponible, s'utilitzarà la icona oficial integrada d'alta resolució.")
            }
        }
    }

    func portGame(mode: String) {
        guard let game = loadedGame, let romURL = game.filePath else { return }

        isProcessing = true
        showLogs = true
        currentStep = mode == "release" ? "Generant release multiplataforma..." : "Portejant aplicació a Mac..."
        appendLog("🚀 Iniciant portabilitat de \"\(game.title)\" a \(outputDirectory.path)...")

        DispatchQueue.global(qos: .userInitiated).async {
            guard let saturnmacBin = findBinary("saturnmac") else {
                DispatchQueue.main.async {
                    self.appendLog("❌ No s'ha trobat l'executable saturnmac. Executa 'cargo run -- setup-runner' al terminal.")
                    self.isProcessing = false
                }
                return
            }

            var args = [
                mode,
                romURL.path,
                "--output", outputDirectory.path,
                "--resolution", String(internalResolution)
            ]

            if enableCRTShader { args.append("--crt") }
            if enableWidescreen { args.append("--widescreen") }

            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: saturnmacBin)
            proc.arguments = args

            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = pipe

            pipe.fileHandleForReading.readabilityHandler = { fh in
                let data = fh.availableData
                if !data.isEmpty, let str = String(data: data, encoding: .utf8) {
                    for line in str.components(separatedBy: "\n") where !line.isEmpty {
                        DispatchQueue.main.async {
                            self.appendLog(line)
                            self.currentStep = line
                        }
                    }
                }
            }

            do {
                try proc.run()
                proc.waitUntilExit()
                pipe.fileHandleForReading.readabilityHandler = nil

                DispatchQueue.main.async {
                    self.isProcessing = false
                    if proc.terminationStatus == 0 {
                        NSSound(named: "Glass")?.play()
                        let appName = sanitizeFilename(game.title)
                        let appPath = outputDirectory.appendingPathComponent("\(appName).app")
                        self.generatedAppURL = appPath
                        self.appendLog("🎉 Joc portat amb èxit a: \(appPath.path)")
                        self.refreshLibrary()
                    } else {
                        self.appendLog("❌ S'ha produït un error durant la generació (Codi: \(proc.terminationStatus))")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.appendLog("❌ Error executant saturnmac: \(error.localizedDescription)")
                }
            }
        }
    }

    func testGameNow() {
        guard let game = loadedGame, let romURL = game.filePath else { return }
        appendLog("▶️ Iniciant prova directa de \"\(game.title)\" en finestra nativa...")

        DispatchQueue.global(qos: .userInitiated).async {
            guard let runnerBin = findBinary("saturn_runner") else {
                DispatchQueue.main.async {
                    self.appendLog("❌ No s'ha trobat saturn_runner. Executa 'cargo run -- setup-runner'.")
                }
                return
            }

            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: runnerBin)
            proc.arguments = [
                "--rom", romURL.path,
                "--title", game.title,
                "--resolution", String(internalResolution)
            ]
            if !enableDeDither { proc.arguments?.append("--no-dedither") }
            if !enableAntiAliasing { proc.arguments?.append("--no-smoothing") }

            do {
                try proc.run()
            } catch {
                DispatchQueue.main.async {
                    self.appendLog("❌ Error llançant el joc: \(error.localizedDescription)")
                }
            }
        }
    }

    func refreshLibrary() {
        var apps: [PortedApp] = []
        if let contents = try? FileManager.default.contentsOfDirectory(at: outputDirectory, includingPropertiesForKeys: [.contentModificationDateKey], options: .skipsHiddenFiles) {
            for item in contents where item.pathExtension == "app" && item.lastPathComponent != "SaturnMac.app" {
                let name = item.deletingPathExtension().lastPathComponent
                let date = (try? item.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()
                let icon = NSWorkspace.shared.icon(forFile: item.path)
                apps.append(PortedApp(name: name, url: item, icon: icon, dateModified: date))
            }
        }
        self.portedGames = apps.sorted(by: { $0.dateModified > $1.dateModified })
    }

    func ensureOutputDirectory() {
        try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: YES)
    }

    func appendLog(_ line: String) {
        logLines.append(line)
    }
}

// MARK: - Helpers

func sanitizeFilename(_ s: String) -> String {
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " -_"))
    return String(s.unicodeScalars.filter { allowed.contains($0) }).trimmingCharacters(in: .whitespaces)
}

func findBinary(_ name: String) -> String? {
    // Check inside .app bundle
    if let bundleBin = Bundle.main.resourceURL?.appendingPathComponent("bin/\(name)").path,
       FileManager.default.isExecutableFile(atPath: bundleBin) {
        return bundleBin
    }

    // Check project paths
    let current = FileManager.default.currentDirectoryPath
    let home = NSHomeDirectory()
    let candidates = [
        "\(current)/target/debug/\(name)",
        "\(current)/target/release/\(name)",
        "\(current)/runner/bin/\(name)",
        "\(home)/Documents/SaturnMac/target/debug/\(name)",
        "\(home)/Documents/SaturnMac/target/release/\(name)",
        "\(home)/Documents/SaturnMac/runner/bin/\(name)",
        "/usr/local/bin/\(name)",
        "\(home)/.cargo/bin/\(name)"
    ]

    for c in candidates {
        if FileManager.default.isExecutableFile(atPath: c) {
            return c
        }
    }
    return nil
}

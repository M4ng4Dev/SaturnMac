import SwiftUI
import UniformTypeIdentifiers
import AppKit

@main
struct SaturnMacApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 880, minHeight: 660)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
    }
}

// MARK: - Internationalization (i18n)

enum AppLanguage: String, CaseIterable, Identifiable {
    case catalan = "ca"
    case spanish = "es"
    case english = "en"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .catalan: return "Català"
        case .spanish: return "Español"
        case .english: return "English"
        }
    }
}

struct I18N {
    static func t(_ key: String, lang: String) -> String {
        let strings: [String: [String: String]] = [
            "app_subtitle": [
                "ca": "Portejador de jocs de Sega Saturn a aplicacions natives de Mac",
                "es": "Portador de juegos de Sega Saturn a aplicaciones nativas de Mac",
                "en": "Sega Saturn to native macOS application porter"
            ],
            "tab_port": [
                "ca": "Portejar Joc",
                "es": "Portear Juego",
                "en": "Port Game"
            ],
            "tab_library": [
                "ca": "Jocs Portats",
                "es": "Juegos Porteados",
                "en": "Ported Games"
            ],
            "drop_title": [
                "ca": "Arrossega aquí el joc de Sega Saturn que vols portejar",
                "es": "Arrastra aquí el juego de Sega Saturn que deseas portear",
                "en": "Drag and drop the Sega Saturn game you want to port here"
            ],
            "drop_subtitle": [
                "ca": "Suporta arxius comprimits (.ZIP, .RAR, .7Z), fitxers .CUE + pistes, imatges .ISO, .CHD i .BIN",
                "es": "Soporta archivos comprimidos (.ZIP, .RAR, .7Z), ficheros .CUE + pistas, imágenes .ISO, .CHD y .BIN",
                "en": "Supports compressed archives (.ZIP, .RAR, .7Z), .CUE sheets + tracks, .ISO, .CHD, and .BIN images"
            ],
            "select_file_btn": [
                "ca": "Triar fitxer de joc...",
                "es": "Seleccionar archivo de juego...",
                "en": "Select game file..."
            ],
            "searching_art": [
                "ca": "Buscant caràtula oficial...",
                "es": "Buscando carátula oficial...",
                "en": "Searching official box art..."
            ],
            "change_cover_btn": [
                "ca": "Canviar caràtula...",
                "es": "Cambiar carátula...",
                "en": "Change box art..."
            ],
            "similar_covers_header": [
                "ca": "💡 Caràtules amb noms semblants (fes clic per triar-ne una per a la icona):",
                "es": "💡 Carátulas con nombres similares (haz clic para elegir una para el icono):",
                "en": "💡 Similar matching box arts (click to choose one for the game icon):"
            ],
            "cover_picker_title": [
                "ca": "Seleccionar Caràtula per a la Icona del Joc",
                "es": "Seleccionar Carátula para el Icono del Juego",
                "en": "Select Box Art for Game Icon"
            ],
            "search_covers_placeholder": [
                "ca": "Cercar a les 2.294 caràtules de Saturn (ex: Sonic, Panzer, Rally...)",
                "es": "Buscar en las 2.294 carátulas de Saturn (ej: Sonic, Panzer, Rally...)",
                "en": "Search 2,294 Saturn box arts (e.g. Sonic, Panzer, Rally...)"
            ],
            "choose_custom_file": [
                "ca": "Tria una imatge des del Mac...",
                "es": "Elegir imagen desde el Mac...",
                "en": "Choose image from Mac..."
            ],
            "select_this_art": [
                "ca": "Utilitzar",
                "es": "Usar",
                "en": "Use"
            ],
            "active_icon_badge": [
                "ca": "Seleccionada",
                "es": "Seleccionada",
                "en": "Selected"
            ],
            "done_btn": [
                "ca": "Fet",
                "es": "Listo",
                "en": "Done"
            ],
            "no_results": [
                "ca": "No s'han trobat caràtules per a aquesta cerca.",
                "es": "No se encontraron carátulas para esta búsqueda.",
                "en": "No box arts found matching this search."
            ],
            "dev_label": [
                "ca": "Desenvolupador:",
                "es": "Desarrollador:",
                "en": "Developer:"
            ],
            "release_date_label": [
                "ca": "Data llançament:",
                "es": "Fecha de lanzamiento:",
                "en": "Release date:"
            ],
            "source_file_label": [
                "ca": "Fitxer origen:",
                "es": "Archivo origen:",
                "en": "Source file:"
            ],
            "tracks_count": [
                "ca": "Pistes",
                "es": "Pistas",
                "en": "Tracks"
            ],
            "config_title": [
                "ca": "Configuració del Port per a Apple Silicon",
                "es": "Configuración del Port para Apple Silicon",
                "en": "Apple Silicon Port Configuration"
            ],
            "res_label": [
                "ca": "Resolució interna de renderitzat (Metal / GPU):",
                "es": "Resolución interna de renderizado (Metal / GPU):" ,
                "en": "Internal rendering resolution (Metal / GPU):"
            ],
            "res_1x": [
                "ca": "1x Nativa (240p original)",
                "es": "1x Nativa (240p original)",
                "en": "1x Native (240p original)"
            ],
            "res_2x": [
                "ca": "2x Alta Definició (480p)",
                "es": "2x Alta Definición (480p)",
                "en": "2x High Definition (480p)"
            ],
            "res_4x": [
                "ca": "4x Retina HD (960p) [Recomanat]",
                "es": "4x Retina HD (960p) [Recomendado]",
                "en": "4x Retina HD (960p) [Recommended]"
            ],
            "res_8x": [
                "ca": "8x Ultra HD 4K (1920p)",
                "es": "8x Ultra HD 4K (1920p)",
                "en": "8x Ultra HD 4K (1920p)"
            ],
            "aa_toggle": [
                "ca": "Suavitzat Anti-Aliasing (FXAA)",
                "es": "Suavizado Anti-Aliasing (FXAA)",
                "en": "Anti-Aliasing Smoothing (FXAA)"
            ],
            "dedither_toggle": [
                "ca": "Correcció De-Dither (Transparències suaus de VDP1)",
                "es": "Corrección De-Dither (Transparencias suaves de VDP1)",
                "en": "De-Dither Filter (Smooth VDP1 mesh transparency)"
            ],
            "crt_toggle": [
                "ca": "Filtre CRT Retro (Scanlines de fòsfor)",
                "es": "Filtro CRT Retro (Scanlines de fósforo)",
                "en": "Retro CRT Filter (Phosphor scanlines)"
            ],
            "widescreen_toggle": [
                "ca": "Format panoràmic anamòrfic 16:9",
                "es": "Formato panorámico anamórfico 16:9",
                "en": "16:9 Anamorphic Widescreen mode"
            ],
            "output_folder_label": [
                "ca": "Carpeta de destinació:",
                "es": "Carpeta de destino:",
                "en": "Destination folder:"
            ],
            "change_btn": [
                "ca": "Canviar...",
                "es": "Cambiar...",
                "en": "Change..."
            ],
            "btn_test": [
                "ca": "Provar Joc Ara",
                "es": "Probar Juego Ahora",
                "en": "Test Game Now"
            ],
            "btn_port_mac": [
                "ca": "Portejar a Mac (.app)",
                "es": "Portear a Mac (.app)",
                "en": "Port to Mac (.app)"
            ],
            "btn_release": [
                "ca": "Release (Mac + iOS/iPad)",
                "es": "Release (Mac + iOS/iPad)",
                "en": "Release (Mac + iOS/iPad)"
            ],
            "show_finder": [
                "ca": "Mostrar al Finder",
                "es": "Mostrar en Finder",
                "en": "Show in Finder"
            ],
            "open_game": [
                "ca": "Obrir Joc",
                "es": "Abrir Juego",
                "en": "Open Game"
            ],
            "play_game": [
                "ca": "Jugar",
                "es": "Jugar",
                "en": "Play"
            ],
            "hide_logs": [
                "ca": "Amagar registre",
                "es": "Ocultar registro",
                "en": "Hide logs"
            ],
            "show_logs": [
                "ca": "Veure registre",
                "es": "Ver registro",
                "en": "Show logs"
            ],
            "library_title": [
                "ca": "Jocs de Sega Saturn instal·lats al Mac",
                "es": "Juegos de Sega Saturn instalados en el Mac",
                "en": "Sega Saturn games installed on your Mac"
            ],
            "library_empty_title": [
                "ca": "Encara no has portat cap joc de Saturn.",
                "es": "Aún no has porteado ningún juego de Saturn.",
                "en": "No Saturn games ported yet."
            ],
            "library_empty_desc": [
                "ca": "Ves a la pestanya 'Portejar Joc' i arrossega qualsevol joc per començar!",
                "es": "Ve a la pestaña 'Portear Juego' y arrastra cualquier juego para comenzar!",
                "en": "Go to the 'Port Game' tab and drop any game to get started!"
            ],
            "refresh_btn": [
                "ca": "Actualitzar",
                "es": "Actualizar",
                "en": "Refresh"
            ],
            "native_app_desc": [
                "ca": "Aplicació nativa de macOS",
                "es": "Aplicación nativa de macOS",
                "en": "Native macOS Application"
            ],
            "success_ported": [
                "ca": "Joc portat correctament a:",
                "es": "Juego porteado correctamente en:",
                "en": "Game successfully ported to:"
            ]
        ]

        if let dict = strings[key], let val = dict[lang] {
            return val
        }
        return strings[key]?["en"] ?? key
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

struct CoverCandidate: Identifiable, Hashable {
    var id: String { filename }
    let filename: String
    let displayName: String
    let urlString: String
}

// MARK: - Main Content View

struct ContentView: View {
    @AppStorage("saturnmac_language") private var currentLang: String = "ca"
    @State private var selectedTab: Int = 0 // 0 = Portejar, 1 = Biblioteca
    @State private var isTargeted: Bool = false
    @State private var loadedGame: SaturnDiscMetadata? = nil
    @State private var coverImage: NSImage? = nil
    @State private var isLoadingArt: Bool = false

    // Box Art Candidates & Customization
    @State private var similarCandidates: [CoverCandidate] = []
    @State private var candidateThumbnails: [String: NSImage] = [:]
    @State private var showCoverPicker: Bool = false
    @State private var coverSearchText: String = ""
    @State private var customSearchResults: [CoverCandidate] = []
    @State private var selectedCoverFilename: String = ""

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

    func t(_ key: String) -> String {
        I18N.t(key, lang: currentLang)
    }

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
        .sheet(isPresented: $showCoverPicker) {
            coverPickerSheet
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
                Text(t("app_subtitle"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Picker("", selection: $selectedTab) {
                Label(t("tab_port"), systemImage: "arrow.triangle.2.circlepath.circle").tag(0)
                Label("\(t("tab_library")) (\(portedGames.count))", systemImage: "square.grid.2x2").tag(1)
            }
            .pickerStyle(.segmented)
            .frame(width: 300)

            // Language Selector
            Menu {
                Button("Català") { currentLang = "ca" }
                Button("Español") { currentLang = "es" }
                Button("English") { currentLang = "en" }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "globe")
                    Text(currentLang == "ca" ? "Català" : (currentLang == "es" ? "Español" : "English"))
                        .font(.caption.bold())
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.12))
                .cornerRadius(6)
            }
            .menuStyle(.borderlessButton)
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
                Text(t("drop_title"))
                    .font(.title3.bold())

                Text(t("drop_subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)
            }

            Button(action: selectFile) {
                Label(t("select_file_btn"), systemImage: "folder.badge.plus")
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
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 20) {
                // Box Art Preview & Change Button
                VStack(spacing: 8) {
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
                                Text(t("searching_art"))
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

                    Button(action: {
                        self.coverSearchText = game.title
                        self.performCoverSearch(query: game.title)
                        self.showCoverPicker = true
                    }) {
                        Label(t("change_cover_btn"), systemImage: "photo.badge.plus")
                            .font(.caption2.bold())
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
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
                            self.similarCandidates.removeAll()
                            self.candidateThumbnails.removeAll()
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
                            TagBadge(text: "\(game.tracks.count) \(t("tracks_count"))", color: .teal)
                        }
                    }

                    Divider().padding(.vertical, 2)

                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                        GridRow {
                            Text(t("dev_label")).font(.caption).foregroundStyle(.secondary)
                            Text(game.maker_id).font(.caption.bold())
                        }
                        GridRow {
                            Text(t("release_date_label")).font(.caption).foregroundStyle(.secondary)
                            Text(game.release_date).font(.caption)
                        }
                        if let f = game.filePath {
                            GridRow {
                                Text(t("source_file_label")).font(.caption).foregroundStyle(.secondary)
                                Text(f.lastPathComponent).font(.caption).lineLimit(1)
                            }
                        }
                    }
                }

                Spacer()
            }

            // MARK: - Similar Covers Matching Section
            if !similarCandidates.isEmpty {
                Divider().padding(.top, 4)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(t("similar_covers_header"))
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)

                        Spacer()

                        Button(action: {
                            self.coverSearchText = game.title
                            self.performCoverSearch(query: game.title)
                            self.showCoverPicker = true
                        }) {
                            Text(t("change_cover_btn"))
                                .font(.caption2.bold())
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(similarCandidates.prefix(8)) { cand in
                                CoverMiniCard(
                                    cand: cand,
                                    isSelected: selectedCoverFilename == cand.filename,
                                    thumbnail: candidateThumbnails[cand.filename],
                                    onAppearThumb: { fetchThumbnailForCandidate(cand) },
                                    onSelect: { selectCandidate(cand) }
                                )
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.secondary.opacity(0.06)))
    }

    // MARK: - Options Card
    var optionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(t("config_title"))
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                // Resolution
                VStack(alignment: .leading, spacing: 6) {
                    Text(t("res_label"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Picker("", selection: $internalResolution) {
                        Text(t("res_1x")).tag(1)
                        Text(t("res_2x")).tag(2)
                        Text(t("res_4x")).tag(4)
                        Text(t("res_8x")).tag(8)
                    }
                    .pickerStyle(.segmented)
                }

                Divider()

                // Graphical enhancements toggles
                HStack(spacing: 30) {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(t("aa_toggle"), isOn: $enableAntiAliasing)
                        Toggle(t("dedither_toggle"), isOn: $enableDeDither)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(t("crt_toggle"), isOn: $enableCRTShader)
                        Toggle(t("widescreen_toggle"), isOn: $enableWidescreen)
                    }
                }

                Divider()

                // Destination Folder
                HStack {
                    Text(t("output_folder_label"))
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

                    Button(t("change_btn")) {
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
                Label(t("btn_test"), systemImage: "play.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(isProcessing)

            // Port to Mac .app Button
            Button(action: { portGame(mode: "bundle") }) {
                Label(t("btn_port_mac"), systemImage: "macbook.and.arrow.forward")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .controlSize(.large)
            .disabled(isProcessing)

            // Complete Multiplatform Release Button
            Button(action: { portGame(mode: "release") }) {
                Label(t("btn_release"), systemImage: "shippingbox")
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
                    Text(t("success_ported"))
                        .font(.subheadline.bold())
                    Text(appURL.lastPathComponent)
                        .font(.subheadline.bold())
                        .foregroundColor(.blue)

                    Spacer()

                    Button(t("show_finder")) {
                        NSWorkspace.shared.activateFileViewerSelecting([appURL])
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button(t("open_game")) {
                        let xattr = Process()
                        xattr.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
                        xattr.arguments = ["-cr", appURL.path]
                        try? xattr.run()
                        xattr.waitUntilExit()
                        NSWorkspace.shared.open(appURL)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .controlSize(.small)
                }

                Spacer()

                Button(action: { showLogs.toggle() }) {
                    Text(showLogs ? t("hide_logs") : t("show_logs"))
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
                    Text(t("library_title"))
                        .font(.headline)
                    Spacer()
                    Button(action: refreshLibrary) {
                        Label(t("refresh_btn"), systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                if portedGames.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text(t("library_empty_title"))
                            .font(.headline)
                        Text(t("library_empty_desc"))
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
                Text(t("native_app_desc"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Button(action: {
                    let xattr = Process()
                    xattr.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
                    xattr.arguments = ["-cr", game.url.path]
                    try? xattr.run()
                    xattr.waitUntilExit()
                    NSWorkspace.shared.open(game.url)
                }) {
                    Label(t("play_game"), systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .controlSize(.small)

                Button(action: {
                    NSWorkspace.shared.activateFileViewerSelecting([game.url])
                }) {
                    Image(systemName: "folder")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.secondary.opacity(0.06)))
    }

    // MARK: - Box Art Picker Sheet
    var coverPickerSheet: some View {
        VStack(spacing: 16) {
            HStack {
                Text(t("cover_picker_title"))
                    .font(.headline)

                Spacer()

                Button(t("done_btn")) {
                    showCoverPicker = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField(t("search_covers_placeholder"), text: $coverSearchText)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        performCoverSearch(query: coverSearchText)
                    }

                if !coverSearchText.isEmpty {
                    Button(action: {
                        coverSearchText = ""
                        performCoverSearch(query: "")
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Divider().frame(height: 18)

                Button(action: pickCustomImageFile) {
                    Label(t("choose_custom_file"), systemImage: "photo.badge.plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.08)))

            // Results Grid
            ScrollView {
                let list = customSearchResults.isEmpty ? similarCandidates : customSearchResults
                if list.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "questionmark.folder")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text(t("no_results"))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 220)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120, maximum: 145), spacing: 14)], spacing: 14) {
                        ForEach(list) { cand in
                            CoverGridCard(
                                cand: cand,
                                isSelected: selectedCoverFilename == cand.filename,
                                thumbnail: candidateThumbnails[cand.filename],
                                activeLabel: t("active_icon_badge"),
                                selectLabel: t("select_this_art"),
                                onAppearThumb: { fetchThumbnailForCandidate(cand) },
                                onSelect: {
                                    selectCandidate(cand)
                                    showCoverPicker = false
                                }
                            )
                        }
                    }
                    .padding(4)
                }
            }
            .frame(minHeight: 340)
        }
        .padding(20)
        .frame(minWidth: 660, minHeight: 480)
    }

    // MARK: - Actions & Logic

    func selectFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [
            UTType(filenameExtension: "cue") ?? .data,
            UTType(filenameExtension: "iso") ?? .data,
            UTType(filenameExtension: "chd") ?? .data,
            UTType(filenameExtension: "bin") ?? .data,
            UTType(filenameExtension: "zip") ?? .zip,
            UTType(filenameExtension: "rar") ?? .data,
            UTType(filenameExtension: "7z") ?? .data
        ]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            processSelectedROM(url)
        }
    }

    func selectOutputFolder() {
        let panel = NSOpenPanel()
        panel.title = t("output_folder_label")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            outputDirectory = url
            refreshLibrary()
        }
    }

    func pickCustomImageFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image, .png, .jpeg]

        if panel.runModal() == .OK, let url = panel.url {
            if let img = NSImage(contentsOf: url) {
                self.coverImage = img
                self.selectedCoverFilename = url.lastPathComponent
                self.appendLog("🖼️ S'ha assignat una caràtula personalitzada des de: \(url.lastPathComponent)")
                self.showCoverPicker = false
            }
        }
    }

    func processSelectedROM(_ url: URL) {
        logLines.removeAll()
        generatedAppURL = nil
        similarCandidates.removeAll()
        candidateThumbnails.removeAll()
        customSearchResults.removeAll()
        coverSearchText = ""
        selectedCoverFilename = ""

        let ext = url.pathExtension.lowercased()
        if ext == "zip" || ext == "rar" || ext == "7z" {
            appendLog("📦 S'ha detectat un paquet comprimit \(ext.uppercased()): \(url.lastPathComponent)")
        } else {
            appendLog("🔍 Analitzant disc: \(url.lastPathComponent)...")
        }

        DispatchQueue.global(qos: .userInitiated).async {
            var meta = SaturnDiscMetadata()
            meta.filePath = url

            let cleanName = url.deletingPathExtension().lastPathComponent
                .replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(of: "(USA)", with: "")
                .replacingOccurrences(of: "(Europe)", with: "")
                .replacingOccurrences(of: "(Japan)", with: "")
                .trimmingCharacters(in: .whitespaces)

            meta.title = cleanName

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
                    self.appendLog("⚠️ CLI inspection fallback to filename.")
                }
            }

            DispatchQueue.main.async {
                self.loadedGame = meta
                self.fetchCoverArt(title: meta.title, productId: meta.product_id, regions: meta.regions)
            }
        }
    }

    func fetchCoverArt(title: String, productId: String, regions: [String]) {
        self.isLoadingArt = true
        self.coverImage = nil

        // Find candidate matches from the 2,294 titles database
        let candidates = searchSaturnTitles(query: title, regions: regions, limit: 12)
        self.similarCandidates = candidates

        let titleUpper = title.uppercased()
        let prodUpper = productId.uppercased()

        // 1. Check embedded local assets first
        if titleUpper.contains("SONIC R") || prodUpper.contains("MK-81800") || prodUpper.contains("GS-9170") {
            if let localSonic = loadLocalAsset("sonic_r.png") {
                self.coverImage = localSonic
                self.selectedCoverFilename = "Sonic R (USA, Brazil).png"
                self.isLoadingArt = false
                appendLog("🎨 Caràtula de Sonic R carregada des d'actius integrats.")
                // Preload similar candidates in background
                preloadCandidateThumbnails(candidates)
                return
            }
        }

        // 2. Perform online download of best candidate
        if let topMatch = candidates.first {
            self.selectedCoverFilename = topMatch.filename
            DispatchQueue.global(qos: .userInitiated).async {
                if let img = downloadImageDirect(topMatch.urlString) {
                    DispatchQueue.main.async {
                        self.coverImage = img
                        self.candidateThumbnails[topMatch.filename] = img
                        self.isLoadingArt = false
                        self.appendLog("🎨 Caràtula oficial seleccionada: \(topMatch.displayName)")
                    }
                } else {
                    // Fallback to local default Saturn art
                    DispatchQueue.main.async {
                        self.coverImage = loadLocalAsset("saturn_default.png")
                        self.isLoadingArt = false
                        self.appendLog("ℹ️ S'ha assignat la icona oficial integrada de Sega Saturn.")
                    }
                }
            }
        } else {
            DispatchQueue.main.async {
                self.coverImage = loadLocalAsset("saturn_default.png")
                self.isLoadingArt = false
            }
        }

        // Preload candidate thumbnails for quick selection
        preloadCandidateThumbnails(candidates)
    }

    func preloadCandidateThumbnails(_ candidates: [CoverCandidate]) {
        DispatchQueue.global(qos: .background).async {
            for cand in candidates.prefix(6) {
                if self.candidateThumbnails[cand.filename] == nil {
                    if let img = downloadImageDirect(cand.urlString) {
                        DispatchQueue.main.async {
                            self.candidateThumbnails[cand.filename] = img
                        }
                    }
                }
            }
        }
    }

    func fetchThumbnailForCandidate(_ cand: CoverCandidate) {
        if candidateThumbnails[cand.filename] != nil { return }
        DispatchQueue.global(qos: .background).async {
            if let img = downloadImageDirect(cand.urlString) {
                DispatchQueue.main.async {
                    self.candidateThumbnails[cand.filename] = img
                }
            }
        }
    }

    func selectCandidate(_ cand: CoverCandidate) {
        self.selectedCoverFilename = cand.filename
        self.appendLog("🎨 S'ha seleccionat la caràtula: \(cand.displayName)")

        if let cached = candidateThumbnails[cand.filename] {
            self.coverImage = cached
        } else {
            self.isLoadingArt = true
            DispatchQueue.global(qos: .userInitiated).async {
                if let img = downloadImageDirect(cand.urlString) {
                    DispatchQueue.main.async {
                        self.candidateThumbnails[cand.filename] = img
                        if self.selectedCoverFilename == cand.filename {
                            self.coverImage = img
                        }
                        self.isLoadingArt = false
                    }
                }
            }
        }
    }

    func performCoverSearch(query: String) {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty {
            customSearchResults = []
            return
        }
        customSearchResults = searchSaturnTitles(query: q, limit: 24)
        preloadCandidateThumbnails(customSearchResults)
    }

    func portGame(mode: String) {
        guard let game = loadedGame, let romURL = game.filePath else { return }

        isProcessing = true
        showLogs = true
        currentStep = mode == "release" ? "Generant release multiplataforma..." : "Portejant aplicació a Mac..."
        appendLog("🚀 Iniciant portabilitat de \"\(game.title)\" a \(outputDirectory.path)...")

        // If a coverImage is currently active, export it to PNG so saturnmac uses it as the icon
        var tempIconFile: String? = nil
        if let img = self.coverImage,
           let tiff = img.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let pngData = rep.representation(using: .png, properties: [:]) {
            let tmpPath = NSTemporaryDirectory().appending("saturn_icon_\(UUID().uuidString).png")
            if (try? pngData.write(to: URL(fileURLWithPath: tmpPath))) != nil {
                tempIconFile = tmpPath
            }
        }

        DispatchQueue.global(qos: .userInitiated).async {
            guard let saturnmacBin = findBinary("saturnmac") else {
                DispatchQueue.main.async {
                    self.appendLog("❌ No s'ha trobat l'executable saturnmac.")
                    self.isProcessing = false
                }
                if let tmp = tempIconFile { try? FileManager.default.removeItem(atPath: tmp) }
                return
            }

            var args = [
                mode,
                romURL.path,
                "--output", outputDirectory.path,
                "--resolution", String(internalResolution)
            ]

            if let icon = tempIconFile {
                args.append("--icon")
                args.append(icon)
            }

            if enableCRTShader { args.append("--crt") }
            if enableWidescreen { args.append("--widescreen") }

            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: saturnmacBin)
            proc.arguments = args

            let home = NSHomeDirectory()
            let projectDir = URL(fileURLWithPath: "\(home)/Documents/SaturnMac")
            if FileManager.default.fileExists(atPath: projectDir.path) {
                proc.currentDirectoryURL = projectDir
            }

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

                if let tmp = tempIconFile {
                    try? FileManager.default.removeItem(atPath: tmp)
                }

                DispatchQueue.main.async {
                    self.isProcessing = false
                    if proc.terminationStatus == 0 {
                        let cleanName = sanitizeFilename(game.title)
                        let appPath = outputDirectory.appendingPathComponent("\(cleanName).app")

                        // Clear quarantine attributes to prevent macOS "dañada o incompleta" message
                        let xattrProc = Process()
                        xattrProc.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
                        xattrProc.arguments = ["-cr", appPath.path]
                        try? xattrProc.run()
                        xattrProc.waitUntilExit()

                        // Ad-hoc sign deep
                        let signProc = Process()
                        signProc.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
                        signProc.arguments = ["--force", "--deep", "--sign", "-", appPath.path]
                        try? signProc.run()
                        signProc.waitUntilExit()

                        self.generatedAppURL = appPath
                        self.appendLog("🎉 Joc portat amb èxit a: \(appPath.path)")
                        self.refreshLibrary()
                    } else {
                        self.appendLog("❌ S'ha produït un error (Codi: \(proc.terminationStatus))")
                    }
                }
            } catch {
                if let tmp = tempIconFile {
                    try? FileManager.default.removeItem(atPath: tmp)
                }
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.appendLog("❌ Error: \(error.localizedDescription)")
                }
            }
        }
    }

    func testGameNow() {
        guard let game = loadedGame, let romURL = game.filePath else { return }
        appendLog("▶️ Iniciant prova de \"\(game.title)\" en finestra nativa...")

        DispatchQueue.global(qos: .userInitiated).async {
            guard let runnerBin = findBinary("saturn_runner") else {
                DispatchQueue.main.async {
                    self.appendLog("❌ No s'ha trobat saturn_runner.")
                }
                return
            }

            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: runnerBin)
            proc.arguments = [romURL.path]

            do {
                try proc.run()
                DispatchQueue.main.async {
                    self.appendLog("🎮 Joc obert en finestra Metal. Fes servir el comandament o teclat per jugar.")
                }
            } catch {
                DispatchQueue.main.async {
                    self.appendLog("❌ Error iniciant saturn_runner: \(error.localizedDescription)")
                }
            }
        }
    }

    func refreshLibrary() {
        DispatchQueue.global(qos: .userInitiated).async {
            var apps: [PortedApp] = []
            let fm = FileManager.default

            if let items = try? fm.contentsOfDirectory(at: outputDirectory, includingPropertiesForKeys: [.contentModificationDateKey]) {
                for item in items where item.pathExtension == "app" && item.lastPathComponent != "SaturnMac.app" {
                    let name = item.deletingPathExtension().lastPathComponent
                    let icon = NSWorkspace.shared.icon(forFile: item.path)
                    let attrs = try? fm.attributesOfItem(atPath: item.path)
                    let modDate = attrs?[.modificationDate] as? Date ?? Date()
                    apps.append(PortedApp(name: name, url: item, icon: icon, dateModified: modDate))
                }
            }

            apps.sort { $0.dateModified > $1.dateModified }

            DispatchQueue.main.async {
                self.portedGames = apps
            }
        }
    }

    func ensureOutputDirectory() {
        try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    }

    func appendLog(_ line: String) {
        logLines.append(line)
    }
}

// MARK: - UI Components

struct TagBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(6)
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

struct CoverMiniCard: View {
    let cand: CoverCandidate
    let isSelected: Bool
    let thumbnail: NSImage?
    let onAppearThumb: () -> Void
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    if let thumb = thumbnail {
                        Image(nsImage: thumb)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 58, height: 78)
                            .cornerRadius(6)
                            .shadow(radius: 2)
                    } else {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.secondary.opacity(0.12))
                            .frame(width: 58, height: 78)
                            .overlay(ProgressView().scaleEffect(0.6))
                            .onAppear {
                                onAppearThumb()
                            }
                    }

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .background(Circle().fill(Color.white).padding(1))
                            .offset(x: 4, y: -4)
                    }
                }

                Text(cand.displayName)
                    .font(.system(size: 9))
                    .lineLimit(2)
                    .frame(width: 66)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(isSelected ? Color.blue : Color.primary)
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                    .background(isSelected ? Color.blue.opacity(0.08) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

struct CoverGridCard: View {
    let cand: CoverCandidate
    let isSelected: Bool
    let thumbnail: NSImage?
    let activeLabel: String
    let selectLabel: String
    let onAppearThumb: () -> Void
    let onSelect: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                if let thumb = thumbnail {
                    Image(nsImage: thumb)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 135)
                        .cornerRadius(8)
                        .shadow(radius: 2)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.12))
                        .frame(width: 100, height: 135)
                        .overlay(ProgressView().scaleEffect(0.7))
                        .onAppear {
                            onAppearThumb()
                        }
                }

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.green)
                        .background(Circle().fill(Color.white).padding(2))
                        .offset(x: 4, y: -4)
                }
            }

            Text(cand.displayName)
                .font(.system(size: 10))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 110)

            if isSelected {
                Button(action: onSelect) {
                    Text(activeLabel)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .controlSize(.mini)
            } else {
                Button(action: onSelect) {
                    Text(selectLabel)
                }
                .buttonStyle(.bordered)
                .tint(.blue)
                .controlSize(.mini)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.blue.opacity(0.12) : Color.secondary.opacity(0.04))
        )
    }
}

// MARK: - Helpers & Search

func sanitizeFilename(_ s: String) -> String {
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " -_"))
    return String(s.unicodeScalars.filter { allowed.contains($0) }).trimmingCharacters(in: .whitespaces)
}

func loadLocalAsset(_ name: String) -> NSImage? {
    if let bundleURL = Bundle.main.resourceURL?.appendingPathComponent(name),
       let img = NSImage(contentsOf: bundleURL) {
        return img
    }

    let home = NSHomeDirectory()
    let candidates = [
        "\(home)/Documents/SaturnMac/assets/icons/\(name)",
        "assets/icons/\(name)",
        "../assets/icons/\(name)"
    ]

    for c in candidates {
        if let img = NSImage(contentsOfFile: c) {
            return img
        }
    }
    return nil
}

func getCachedSaturnTitles() -> [String] {
    if let bundleURL = Bundle.main.resourceURL?.appendingPathComponent("saturn_titles.txt"),
       let content = try? String(contentsOf: bundleURL, encoding: .utf8) {
        return content.components(separatedBy: "\n")
    }

    let home = NSHomeDirectory()
    let paths = [
        "assets/saturn_titles.txt",
        "../assets/saturn_titles.txt",
        "\(home)/Documents/SaturnMac/assets/saturn_titles.txt"
    ]

    for p in paths {
        if let content = try? String(contentsOfFile: p, encoding: .utf8) {
            return content.components(separatedBy: "\n")
        }
    }

    return []
}

func searchSaturnTitles(query: String, regions: [String] = [], limit: Int = 16) -> [CoverCandidate] {
    let titles = getCachedSaturnTitles()
    let cleanQ = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let queryWords = cleanQ.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
    if queryWords.isEmpty { return [] }

    var scored: [(String, Int)] = []
    let regStr = regions.joined(separator: " ").uppercased()
    let prefRegion = regStr.contains("J") ? "japan" : (regStr.contains("E") ? "europe" : "usa")

    for raw in titles {
        let filename = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if filename.isEmpty || !filename.hasSuffix(".png") { continue }
        let base = filename.replacingOccurrences(of: ".png", with: "")
        let lower = base.lowercased()

        var score = 0
        if lower.contains(cleanQ) {
            score += 80
            if lower.hasPrefix(cleanQ) { score += 40 }
        }

        let words = lower.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        var matchedCount = 0
        for qw in queryWords {
            if words.contains(qw) {
                matchedCount += 1
                score += 25
            } else if words.contains(where: { $0.hasPrefix(qw) || qw.hasPrefix($0) }) {
                score += 12
            }
        }

        if matchedCount == queryWords.count && !queryWords.isEmpty {
            score += 50
        }

        if score > 0 {
            if lower.contains(prefRegion) { score += 20 }
            if prefRegion == "usa" && lower.contains("usa, brazil") { score += 25 }
            let lenDiff = abs(lower.count - cleanQ.count)
            score -= lenDiff / 5
            scored.append((filename, score))
        }
    }

    scored.sort { $0.1 > $1.1 }
    let top = scored.prefix(limit)

    return top.map { item in
        let fname = item.0
        let cleanName = fname.replacingOccurrences(of: ".png", with: "")
        let encoded = fname.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? fname
        let httpsURL = "https://raw.githubusercontent.com/libretro-thumbnails/Sega_-_Saturn/master/Named_Boxarts/\(encoded)"
        return CoverCandidate(filename: fname, displayName: cleanName, urlString: httpsURL)
    }
}

func downloadImageDirect(_ urlString: String) -> NSImage? {
    if let url = URL(string: urlString),
       let data = try? Data(contentsOf: url),
       data.count > 1024,
       let img = NSImage(data: data) {
        return img
    }

    // Fallback to /usr/bin/curl
    let tmpFile = NSTemporaryDirectory().appending("cover_\(UUID().uuidString).png")
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
    proc.arguments = ["-sL", "--max-time", "8", urlString, "-o", tmpFile]
    do {
        try proc.run()
        proc.waitUntilExit()
        if proc.terminationStatus == 0, let d = try? Data(contentsOf: URL(fileURLWithPath: tmpFile)), d.count > 1024 {
            try? FileManager.default.removeItem(atPath: tmpFile)
            return NSImage(data: d)
        }
    } catch {}
    try? FileManager.default.removeItem(atPath: tmpFile)
    return nil
}

func findBinary(_ name: String) -> String? {
    if let bundleBin = Bundle.main.resourceURL?.appendingPathComponent("bin/\(name)").path,
       FileManager.default.isExecutableFile(atPath: bundleBin) {
        return bundleBin
    }

    let current = FileManager.default.currentDirectoryPath
    let home = NSHomeDirectory()
    let candidates = [
        "\(current)/target/release/\(name)",
        "\(current)/target/debug/\(name)",
        "\(current)/runner/bin/\(name)",
        "\(home)/Documents/SaturnMac/target/release/\(name)",
        "\(home)/Documents/SaturnMac/target/debug/\(name)",
        "\(home)/Documents/SaturnMac/runner/bin/\(name)",
        "/usr/local/bin/\(name)",
        "/opt/homebrew/bin/\(name)"
    ]

    for c in candidates {
        if FileManager.default.isExecutableFile(atPath: c) {
            return c
        }
    }
    return nil
}

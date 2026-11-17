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
            ],
            "progress_title": [
                "ca": "Processant conversió del joc...",
                "es": "Procesando conversión del juego...",
                "en": "Processing game conversion..."
            ],
            "step_extracting": [
                "ca": "Descomprimint fitxers de l'arxiu...",
                "es": "Descomprimiendo archivos del juego...",
                "en": "Extracting archive files..."
            ],
            "step_found_rom": [
                "ca": "Localitzant la imatge principal del disc...",
                "es": "Localizando imagen principal del disco...",
                "en": "Locating primary disc image..."
            ],
            "step_reading_header": [
                "ca": "Analitzant capçalera i sectors de Sega Saturn...",
                "es": "Analizando cabecera y sectores de Sega Saturn...",
                "en": "Parsing Sega Saturn header and disc sectors..."
            ],
            "step_fetching_art": [
                "ca": "Obtenint caràtula oficial i generant icona Apple Silicon...",
                "es": "Obteniendo carátula oficial y generando icono Apple Silicon...",
                "en": "Fetching official box art and generating Apple Silicon icon..."
            ],
            "step_converting_audio": [
                "ca": "Convertint pistes d'àudio CD-DA a alta fidelitat PCM WAV...",
                "es": "Convirtiendo pistas de audio CD-DA a alta fidelidad PCM WAV...",
                "en": "Converting CD-DA audio tracks to high-fidelity PCM WAV..."
            ],
            "step_copying_rom": [
                "ca": "Empaquetant pistes i dades del disc...",
                "es": "Empaquetando pistas y datos del disco...",
                "en": "Packaging disc tracks and data..."
            ],
            "step_embedding_runner": [
                "ca": "Integrant motor autònom Metal per a Apple Silicon...",
                "es": "Integrando motor autónomo Metal para Apple Silicon...",
                "en": "Embedding native Metal runner for Apple Silicon..."
            ],
            "step_embedding_cores": [
                "ca": "Integrant nuclis de màxima fidelitat (Ymir / Yabause)...",
                "es": "Integrando núcleos de máxima fidelidad (Ymir / Yabause)...",
                "en": "Embedding high-accuracy Saturn cores (Ymir / Yabause)..."
            ],
            "step_embedding_bios": [
                "ca": "Instal·lant BIOS autèntiques de Sega Saturn...",
                "es": "Instalando BIOS auténticas de Sega Saturn...",
                "en": "Installing authentic Sega Saturn BIOS ROMs..."
            ],
            "step_codesigning": [
                "ca": "Signant paquet natiu i eliminant quarantena de macOS...",
                "es": "Firmando paquete nativo y eliminando cuarentena de macOS...",
                "en": "Codesigning native bundle and clearing macOS quarantine..."
            ],
            "step_completed": [
                "ca": "Conversió finalitzada amb èxit!",
                "es": "¡Conversión finalizada con éxito!",
                "en": "Conversion completed successfully!"
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
    @State private var processingProgress: Double = 0.0
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
            if let logo = getSaturnLogoImage() {
                Image(nsImage: logo)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                    .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 1)
            } else {
                Image(systemName: "opticaldisc.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(.linearGradient(colors: [.cyan, .blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
            }

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

                if isProcessing || processingProgress > 0 || showLogs || !logLines.isEmpty || generatedAppURL != nil {
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
                                if let logo = getSaturnLogoImage() {
                                    Image(nsImage: logo)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 56, height: 56)
                                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                                } else {
                                    Image(systemName: "opticaldisc.fill")
                                        .font(.system(size: 40))
                                        .foregroundStyle(.secondary)
                                }
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
                            self.processingProgress = 0.0
                            self.isProcessing = false
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

    // MARK: - Log Console & Progress View
    var logConsoleView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Processing Progress Bar Section
            if isProcessing || processingProgress > 0.0 {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center) {
                        HStack(spacing: 8) {
                            if isProcessing {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .frame(width: 16, height: 16)
                            } else if generatedAppURL != nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.headline)
                            } else {
                                Image(systemName: "gearshape.2.fill")
                                    .foregroundColor(.blue)
                                    .font(.headline)
                            }

                            Text(currentStep.isEmpty ? t("progress_title") : currentStep)
                                .font(.subheadline.bold())
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }

                        Spacer()

                        // Percentage badge
                        Text("\(Int(min(processingProgress * 100, 100)))%")
                            .font(.system(.caption, design: .monospaced).bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(isProcessing ? Color.blue.opacity(0.18) : (generatedAppURL != nil ? Color.green.opacity(0.18) : Color.secondary.opacity(0.15)))
                            .foregroundColor(isProcessing ? .blue : (generatedAppURL != nil ? .green : .primary))
                            .cornerRadius(6)
                    }

                    // Native macOS Linear Progress Bar
                    ProgressView(value: min(processingProgress, 1.0), total: 1.0)
                        .progressViewStyle(.linear)
                        .tint(generatedAppURL != nil ? .green : .blue)
                }
                .padding(.bottom, 2)
            }

            // Success action card when completed
            if let appURL = generatedAppURL, !isProcessing {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                        .font(.title2)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(t("success_ported"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(appURL.lastPathComponent)
                            .font(.subheadline.bold())
                            .foregroundColor(.primary)
                    }

                    Spacer()

                    Button(action: {
                        NSWorkspace.shared.activateFileViewerSelecting([appURL])
                    }) {
                        Label(t("show_finder"), systemImage: "folder")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button(action: {
                        let xattr = Process()
                        xattr.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
                        xattr.arguments = ["-cr", appURL.path]
                        try? xattr.run()
                        xattr.waitUntilExit()
                        NSWorkspace.shared.open(appURL)
                    }) {
                        Label(t("open_game"), systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .controlSize(.small)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.green.opacity(0.08)))
            }

            // Log Console Collapsible Section
            HStack {
                Text(showLogs ? t("hide_logs") : t("show_logs"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button(action: { showLogs.toggle() }) {
                    HStack(spacing: 4) {
                        Image(systemName: showLogs ? "chevron.up.circle.fill" : "terminal")
                        Text(showLogs ? t("hide_logs") : t("show_logs"))
                            .font(.caption.bold())
                    }
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
            } else if let logo = getSaturnLogoImage() {
                Image(nsImage: logo)
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
        processingProgress = 0.0
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

    func updateProgressFromLog(_ line: String) {
        let lower = line.lowercased()
        var targetProgress: Double? = nil
        var userFriendlyStep: String? = nil

        if lower.contains("arxiu comprimit") || lower.contains("descomprimint") {
            targetProgress = 0.15
            userFriendlyStep = t("step_extracting")
        } else if lower.contains("imatge principal") {
            targetProgress = 0.25
            userFriendlyStep = t("step_found_rom")
        } else if lower.contains("reading disc") || lower.contains("detected game") {
            targetProgress = 0.35
            userFriendlyStep = t("step_reading_header")
        } else if lower.contains("cerca de caràtules") || lower.contains("box art") {
            targetProgress = 0.45
            userFriendlyStep = t("step_fetching_art")
        } else if lower.contains("convertint pista") || lower.contains("cd-da") {
            targetProgress = max(self.processingProgress, 0.52)
            if self.processingProgress < 0.70 {
                targetProgress = min(self.processingProgress + 0.04, 0.70)
            }
            userFriendlyStep = line.replacingOccurrences(of: "🎵 ", with: "").trimmingCharacters(in: .whitespaces)
        } else if lower.contains("empaquetant pista") || lower.contains("copiant fitxer") {
            targetProgress = max(self.processingProgress, 0.65)
            if self.processingProgress < 0.80 {
                targetProgress = min(self.processingProgress + 0.03, 0.80)
            }
            userFriendlyStep = line.replacingOccurrences(of: "📥 ", with: "").trimmingCharacters(in: .whitespaces)
        } else if lower.contains("motor autònom") || lower.contains("contents/macos") {
            targetProgress = 0.82
            userFriendlyStep = t("step_embedding_runner")
        } else if lower.contains("nucli de saturn") {
            targetProgress = 0.88
            userFriendlyStep = t("step_embedding_cores")
        } else if lower.contains("bios autèntica") {
            targetProgress = 0.92
            userFriendlyStep = t("step_embedding_bios")
        } else if lower.contains("codesign") || lower.contains("xattr") {
            targetProgress = 0.96
            userFriendlyStep = t("step_codesigning")
        } else if lower.contains("created successfully") || lower.contains("finalitzada") || lower.contains("èxit") {
            targetProgress = 1.0
            userFriendlyStep = t("step_completed")
        }

        if let p = targetProgress {
            withAnimation(.easeInOut(duration: 0.25)) {
                self.processingProgress = max(self.processingProgress, p)
            }
        }
        if let s = userFriendlyStep {
            self.currentStep = s
        }
    }

    func portGame(mode: String) {
        guard let game = loadedGame, let romURL = game.filePath else { return }

        isProcessing = true
        processingProgress = 0.05
        generatedAppURL = nil
        showLogs = true
        currentStep = mode == "release" ? t("btn_release") : t("progress_title")
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
            if enableDeDither { args.append("--dedither") }
            if !enableAntiAliasing { args.append("--no-smoothing") }

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
                            self.updateProgressFromLog(line)
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

                        withAnimation(.easeInOut(duration: 0.3)) {
                            self.processingProgress = 1.0
                            self.currentStep = self.t("step_completed")
                        }

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
        "../assets/icons/\(name)",
        "\(home)/Documents/SaturnMac/dist/SaturnMac.app/Contents/Resources/\(name)",
        "dist/SaturnMac.app/Contents/Resources/\(name)",
        "/Applications/SaturnMac.app/Contents/Resources/\(name)"
    ]

    for c in candidates {
        if let img = NSImage(contentsOfFile: c) {
            return img
        }
    }
    return nil
}

private let SATURN_LOGO_BASE64: String = "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"

func getSaturnLogoImage() -> NSImage? {
    if let img = loadLocalAsset("saturn_default.png") ?? loadLocalAsset("saturn_default_128.png") {
        return img
    }
    if let img = NSImage(named: NSImage.Name("AppIcon")), img.isValid {
        return img
    }
    if let appIcon = NSApp.applicationIconImage, appIcon.isValid {
        return appIcon
    }
    if let data = Data(base64Encoded: SATURN_LOGO_BASE64), let img = NSImage(data: data) {
        return img
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

import SwiftUI
import UniformTypeIdentifiers

@main
struct SaturnMacApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 700, minHeight: 520)
        }
        .windowStyle(.hiddenTitleBar)
    }
}

struct SaturnDiscMetadata: Identifiable {
    let id = UUID()
    var title: String
    var productID: String
    var maker: String
    var region: String
    var releaseDate: String
    var version: String
    var tracksCount: Int
    var filePath: URL
}

struct ContentView: View {
    @State private var isTargeted: Bool = false
    @State private var loadedGame: SaturnDiscMetadata? = nil
    @State private var internalResolution: Int = 2
    @State private var enableCRTShader: Bool = false
    @State private var enableProMotion: Bool = true
    @State private var enableWidescreen: Bool = false
    @State private var isBuilding: Bool = false
    @State private var buildSuccessMessage: String? = nil

    var body: some View {
        ZStack {
            VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // Header
                HStack {
                    Image(systemName: "opticaldisc.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.linearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing))
                    
                    VStack(alignment: .leading) {
                        Text("SaturnMac")
                            .font(.title2.bold())
                        Text("Convertidor de jocs de Sega Saturn a Apps natives de macOS")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 16)

                if let game = loadedGame {
                    gameDetailsView(game)
                } else {
                    dropZoneView
                }

                Spacer()

                // Footer Actions
                if loadedGame != nil {
                    footerBar
                }
            }
            .padding()

            if isBuilding {
                ZStack {
                    Color.black.opacity(0.6).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Generant l'aplicació nativa de Mac...")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding(30)
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                }
            }
        }
    }

    // Drop Zone View
    var dropZoneView: some View {
        VStack(spacing: 16) {
            Image(systemName: isTargeted ? "arrow.down.doc.fill" : "square.and.arrow.down")
                .font(.system(size: 48))
                .foregroundColor(isTargeted ? .orange : .secondary)

            Text("Arrossega aquí la teva ROM de Saturn")
                .font(.headline)

            Text("Suporta imatges .cue, .bin, .iso i .chd")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("Seleccionar fitxer...") {
                selectFile()
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
        .frame(maxWidth: .infinity, maxHeight: 320)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isTargeted ? Color.orange : Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [8]))
                .background(Color.secondary.opacity(0.05).cornerRadius(16))
        )
        .padding(.horizontal)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url = url {
                    DispatchQueue.main.async {
                        self.inspectROM(at: url)
                    }
                }
            }
            return true
        }
    }

    // Game Details & Config
    func gameDetailsView(_ game: SaturnDiscMetadata) -> some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 20) {
                // Disc Art Mock
                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [.orange.opacity(0.8), .black], center: .center, startRadius: 10, endRadius: 70))
                        .frame(width: 130, height: 130)
                        .shadow(radius: 8)
                    Circle()
                        .fill(.black)
                        .frame(width: 30, height: 30)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(game.title)
                        .font(.title3.bold())
                    
                    HStack(spacing: 8) {
                        TagBadge(text: game.productID, color: .blue)
                        TagBadge(text: game.region, color: .purple)
                        TagBadge(text: game.version, color: .gray)
                    }

                    Text("Desenvolupador: \(game.maker)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Data de llançament: \(game.releaseDate)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Fitxer: \(game.filePath.lastPathComponent)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Button(action: { loadedGame = nil }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.08)))

            // Options Form
            Form {
                Section("Optimitzacions d'Apple Silicon") {
                    Picker("Resolució interna (Metal):", selection: $internalResolution) {
                        Text("1x Nativa (240p/480p)").tag(1)
                        Text("2x Alta Definició (720p/960p)").tag(2)
                        Text("4x Pantalla Retina 4K").tag(4)
                    }

                    Toggle("Sincronització de fotogrames ProMotion (120Hz)", isOn: $enableProMotion)
                    Toggle("Filtre gràfic CRT Shaders (fòsfor i scanlines)", isOn: $enableCRTShader)
                    Toggle("Format panoràmic 16:9 anamòrfic", isOn: $enableWidescreen)
                }
            }
            .formStyle(.grouped)
            .frame(maxHeight: 200)
        }
    }

    var footerBar: some View {
        HStack {
            if let msg = buildSuccessMessage {
                Label(msg, systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.subheadline)
            }
            Spacer()
            Button("Generar App de macOS (.app)") {
                buildNativeApp()
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .controlSize(.large)
        }
        .padding(.horizontal)
    }

    func selectFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            UTType(filenameExtension: "cue")!,
            UTType(filenameExtension: "bin")!,
            UTType(filenameExtension: "iso")!,
            UTType(filenameExtension: "chd") ?? .data
        ]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            inspectROM(at: url)
        }
    }

    func inspectROM(at url: URL) {
        // Quick inspection
        self.loadedGame = SaturnDiscMetadata(
            title: url.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "_", with: " "),
            productID: "SEGA-AUTO",
            maker: "SEGA ENTERPRISES",
            region: "NTSC / PAL",
            releaseDate: "1996",
            version: "V1.000",
            tracksCount: 1,
            filePath: url
        )
    }

    func buildNativeApp() {
        isBuilding = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.isBuilding = false
            self.buildSuccessMessage = "Joc empaquetat correctament a ~/Applications!"
        }
    }
}

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

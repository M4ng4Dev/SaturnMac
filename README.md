# SaturnMac 🪐🍎

> **Convert Sega Saturn games (`.zip`, `.cue`, `.bin`, `.iso`, `.chd`) into standalone, native Apple Silicon macOS applications and iOS/iPadOS packages.**

---

* [English Documentation](#-english-documentation)
  * [Features](#-features)
  * [SaturnMac Studio GUI](#-saturnmac-studio-native-gui)
  * [Command Line Interface (CLI)](#-command-line-interface-cli)
  * [Multiplatform Releases (macOS, iOS, iPadOS)](#-multiplatform-releases-macos-ios-ipados)
  * [Gamepad & Keyboard Controls](#-gamepad--keyboard-controls)
  * [Internal App Structure](#-internal-app-structure)
  * [Automated Tests](#-automated-tests)
* [Documentació en Català](#-documentació-en-català)
  * [Característiques](#-característiques)
  * [SaturnMac Studio (Interfície Gràfica)](#-saturnmac-studio-interfície-gràfica-nativa)
  * [Ús des del Terminal (CLI)](#-ús-des-del-terminal-cli)
  * [Versions Multiplataforma (macOS, iOS, iPadOS)](#-versions-multiplataforma-macos-ios-ipados)
  * [Controls de Joc i Teclat](#-controls-de-joc-i-teclat)
  * [Estructura d'un Paquet .app](#-estructura-dun-paquet-app)
  * [Tests Automatitzats](#-tests-automatitzats)

---

# 🇬🇧 English Documentation

SaturnMac is an all-in-one suite designed to port, enhance, and package Sega Saturn disc images into standalone native macOS apps (`.app`), installable disk images (`.dmg`), and sideloadable iOS/iPadOS packages (`.ipa`). It features an Apple Silicon native Metal runner, high-resolution rendering, shaders, audio conversion, and an intuitive SwiftUI studio.

## 🌟 Features

- **Trilingual Native SwiftUI Studio (`SaturnMac.app`)**:
  - Full support for **English**, **Català** (Catalan), and **Español** (Spanish).
  - Drag-and-drop `.zip`, `.cue` + track files, `.iso`, `.chd`, or `.bin` ROMs.
  - Built-in library manager displaying all ported games with instant play and Finder reveal.
- **Sega Saturn Disc Parser (IP.BIN)**:
  - Reads Mode 1 (2048 bytes) and RAW (2352 bytes) disc sectors.
  - Extracts official title (with Shift-JIS support), product code (e.g. `MK-81005`), version, and release date.
  - Identifies target region (Japan `J`, North America `U`, Europe `E`) and supported peripherals.
  - Multi-track `.cue` resolver with automatic MP3/WAV CD-DA audio track conversion.
- **Automatic High-Resolution Box Art**:
  - Fetches official box covers directly via Libretro's Sega Saturn database.
  - Fallback to bundled high-res icons and Apple `.icns` generator (Retina 512×512 and 1024×1024).
- **Metal Graphics Enhancements for Apple Silicon (M1/M2/M3/M4)**:
  - **Internal Resolution Upscaling**: 1x Native (240p), 2x HD (480p), 4x Retina HD (960p), 8x Ultra HD 4K (1920p).
  - **FXAA Anti-Aliasing**: Smooths 3D polygon jagged edges and textures.
  - **De-Dither Filter**: Removes the classic VDP1 mesh/cross dithering to produce real transparencies.
  - **CRT Phosphor Filter**: Simulates authentic arcade/CRT phosphor scanlines.
  - **16:9 Anamorphic Widescreen**: Expands supported games to widescreen displays.
- **Low-Latency CoreAudio Engine**:
  - Direct 44.1 kHz 16-bit stereo streaming via Apple CoreAudio buffers.
- **Seamless Controller & Keyboard Support**:
  - Plug-and-play Apple `GameController` framework integration (PS5 DualSense, Xbox Wireless, Nintendo Switch Pro, 8BitDo).
  - Standard macOS keyboard mappings.

---

## 🖥️ SaturnMac Studio (Native GUI)

The fastest and most user-friendly way to port games is through **SaturnMac Studio**:

```bash
# Build runner and GUI
cargo run -- setup-runner

# Launch the app
cargo run -- app
# or open dist/SaturnMac.app
```

### Studio Capabilities
1. **Language Selection**: Toggle between English, Catalan, and Spanish from the top navigation bar at any time.
2. **Drag & Drop**: Drop any Saturn archive or cue file. Disc metadata and official cover art will load automatically.
3. **Graphics Configuration**: Choose 1x/2x/4x/8x resolution, FXAA, De-Dithering, CRT scanlines, and 16:9 aspect ratio.
4. **Test Game Now**: Run and play the game immediately in an isolated native Metal window without building a full bundle.
5. **Port to Mac (`.app`)**: Packages a standalone, codesigned macOS application in seconds.
6. **Multiplatform Release**: Builds `.app`, `.dmg`, and iOS `.ipa` concurrently.
7. **Ported Games Library**: Switch to the **Ported Games** tab to view your collection, play any game, or locate it in Finder.

---

## 🚀 Command Line Interface (CLI)

SaturnMac can also be used entirely from the terminal:

### 1. Initial Setup
Compiles the standalone Apple Silicon Metal runner and builds `dist/SaturnMac.app`:
```bash
cargo run -- setup-runner
```

### 2. Inspect a Disc Image
Displays disc metadata parsed directly from IP.BIN:
```bash
cargo run -- inspect /path/to/game.cue
# Or output machine-readable JSON:
cargo run -- inspect /path/to/game.bin --json
```

### 3. Bundle a Game into a macOS App
```bash
cargo run -- bundle /path/to/game.zip \
  --output ~/Applications \
  --resolution 4 \
  --aa \
  --dedither
```

*Options:*
- `-o`, `--output <DIR>`: Output directory (default: `dist/`).
- `-i`, `--icon <PNG>`: Custom icon or cover image.
- `-r`, `--resolution <1|2|4|8>`: Internal rendering resolution scale.
- `--aa`: Enable FXAA anti-aliasing smoothing.
- `--dedither`: Enable VDP1 mesh de-dithering.
- `--crt`: Enable retro CRT scanline shader.
- `--widescreen`: Enable 16:9 anamorphic widescreen.

### 4. Create Multiplatform Release (macOS + iOS/iPadOS)
```bash
cargo run -- release /path/to/game.cue --output ./dist --resolution 4
```
Generates:
- `dist/GameName.app` (macOS standalone application)
- `dist/GameName.dmg` (macOS disk image installer)
- `dist/GameName.ipa` (Universal iOS / iPadOS application package)

---

## 📱 Multiplatform Releases (macOS, iOS, iPadOS)

Each game ported with `release` creates an iOS/iPadOS `.ipa` bundle in addition to the Mac application:
- **Architecture**: Universal ARM64 for iPhone and iPad running iOS 15+.
- **Sideloading**: Can be installed directly via **AltStore**, **SideStore**, **TrollStore**, or Apple **Xcode / Configurator**.
- **Controllers**: Full support for MFi, DualSense, Xbox, and touch input controls.

---

## 🎮 Gamepad & Keyboard Controls

Controllers connected via Bluetooth or USB are recognized automatically with zero configuration.

| Saturn Action | Keyboard Key | Game Controller (PlayStation / Xbox / Switch) |
|---|---|---|
| **D-Pad Up / Down / Left / Right** | Arrow Keys (`↑`, `↓`, `←`, `→`) | D-Pad / Left Analog Stick |
| **A Button** | `Z` | Cross (✕) / `A` / `B` |
| **B Button** | `X` | Circle (○) / `B` / `A` |
| **C Button** | `C` | R1 / `RB` / `R` |
| **X Button** | `A` | Square (□) / `X` / `Y` |
| **Y Button** | `S` | Triangle (△) / `Y` / `X` |
| **Z Button** | `D` | R2 / `RT` / `ZR` |
| **L Trigger** | `Q` | L1 / `LB` / `L` |
| **R Trigger** | `W` | R1 / `RB` / `R` |
| **Start** | `Enter` / `Return` | Options / Menu / `+` |

---

## 📂 Internal App Structure

Every generated `.app` bundle is fully self-contained:
```text
GameName.app/
└── Contents/
    ├── Info.plist                     # App metadata, GameController framework, ATS configuration
    ├── PkgInfo                        # Package signature
    ├── MacOS/
    │   └── Launcher                   # Direct executable runner
    └── Resources/
        ├── AppIcon.icns               # High-res macOS icon bundle
        ├── Game/
        │   ├── game.cue               # Disc track descriptor
        │   └── game.bin               # Data ROM & audio tracks
        ├── cores/
        │   └── yabause_libretro.dylib # Apple Silicon optimized Saturn core
        └── Config/
            └── saturn.json            # Resolution, shaders, and input settings
```

Saves and states are isolated cleanly per game under:
`~/Library/Application Support/SaturnMac/Saves/<ProductCode>/`

---

## 🧪 Automated Tests

Run the full automated test suite (disc parser, icon conversion, zip extraction, multiplatform release generation):
```bash
cargo test
```

---

<br>

# 🇪🇸 Documentació en Català

SaturnMac és una suite completa dissenyada per transformar, millorar i empaquetar imatges de disc de Sega Saturn en aplicacions natives de macOS (`.app`), imatges de disc instal·lables (`.dmg`) i paquets per a iOS/iPadOS (`.ipa`). Incorpora un motor gràfic natiu Metal per a Apple Silicon, reescalat en alta resolució, filtres gràfics, conversió automàtica d'àudio i un estudi gràfic en SwiftUI.

## 🌟 Característiques

- **Estudi Gràfic Natiu Trilingüe (`SaturnMac.app`)**:
  - Suport complet en **Català**, **Castellà** i **Anglès**.
  - Arrossega i deixa anar fitxers `.zip`, `.cue` + pistes, `.iso`, `.chd` o `.bin`.
  - Gestor de biblioteca integrat que mostra tots els jocs portats, amb opció d'obrir-los o veure'ls al Finder amb un sol clic.
- **Parser Natiu de Discos de Saturn (IP.BIN)**:
  - Llegeix automàticament els sectors del disc en Mode 1 (2048 bytes) i RAW (2352 bytes).
  - Extreu el títol oficial (amb suport per a caràcters japonesos Shift-JIS), codi de producte (ex: `MK-81005`), versió i data de llançament.
  - Reconeix la regió (Japó `J`, Amèrica del Nord `U`, Europa `E`) i els perifèrics compatibles.
  - Conversió automàtica de pistes d'àudio CD-DA en MP3 a WAV de 16 bits i 44.1 kHz sense pèrdua.
- **Caràtules Oficials en Alta Resolució**:
  - Cerca i descàrrega automàtica de la caràtula oficial mitjançant la base de dades de Libretro.
  - Assignació de recursos integrats d'alta resolució i generació d'icones natives d'Apple `.icns` (Retina 512×512 i 1024×1024).
- **Millores Gràfiques Metal per a Apple Silicon (M1/M2/M3/M4)**:
  - **Reescalat de Resolució Interna**: 1x Nativa (240p), 2x HD (480p), 4x Retina HD (960p), 8x Ultra HD 4K (1920p).
  - **Suavitzat Anti-Aliasing (FXAA)**: Elimina l'aspecte dentat dels polígons 3D i textures.
  - **Filtre De-Dither**: Suprimeix el tramat en malla del processador VDP1 per aconseguir transparències suaus reals.
  - **Filtre CRT Retro**: Simula les línies d'escaneig i fòsfor dels monitors clàssics.
  - **Format Panoràmic 16:9**: Ampliació anamòrfica per a pantalles amples.
- **Àudio CoreAudio de Baixa Latència**:
  - Reproducció estèreo natiu a 44.1 kHz i 16 bits amb latència mínima.
- **Configuració Automàtica de Comandaments i Teclat**:
  - Detecció immediata de comandaments sense configuració gràcies a l'API `GameController` d'Apple (PS5 DualSense, Xbox, Switch Pro, 8BitDo).
  - Mapeig complet per a teclat de Mac.

---

## 🖥️ SaturnMac Studio (Interfície Gràfica Nativa)

La manera més còmoda i visual d'utilitzar SaturnMac és a través de **SaturnMac Studio**:

```bash
# Compilar el motor i la interfície
cargo run -- setup-runner

# Obrir l'aplicació
cargo run -- app
# o obrir directament dist/SaturnMac.app
```

### Funcionalitats de l'Estudi
1. **Selector d'Idioma**: Canvia entre Català, Castellà i Anglès des de la barra superior en qualsevol moment.
2. **Arrossegar i Deixar Anar**: Arrossega qualsevol fitxer o arxiu zip de Saturn; les dades del disc i la caràtula es carregaran automàticament.
3. **Configuració Gràfica**: Tria la resolució (1x, 2x, 4x, 8x), FXAA, De-Dithering, filtre CRT i format 16:9.
4. **Provar Joc Ara**: Executa el joc a l'instant en una finestra Metal nativa abans de crear l'aplicació final.
5. **Portejar a Mac (`.app`)**: Crea l'aplicació autònoma signada de macOS en qüestió de segons.
6. **Release Multiplataforma**: Genera el paquet complet per a Mac (`.app` i `.dmg`) i per a iOS/iPadOS (`.ipa`).
7. **Biblioteca de Jocs Portats**: Consulta tots els jocs que has adaptat, obre'ls a l'instant o mostra'ls al Finder.

---

## 🚀 Ús des del Terminal (CLI)

SaturnMac també es pot utilitzar des de la línia d'ordres:

### 1. Configuració Inicial
Compila el motor de joc autònom per a Apple Silicon i genera `dist/SaturnMac.app`:
```bash
cargo run -- setup-runner
```

### 2. Inspeccionar una ROM
Mostra la informació continguda a la capçalera del disc:
```bash
cargo run -- inspect /camí/al/joc.cue
# O en format JSON estructurat:
cargo run -- inspect /camí/al/joc.bin --json
```

### 3. Empaquetar un Joc en una App de Mac
```bash
cargo run -- bundle /camí/al/joc.zip \
  --output ~/Applications \
  --resolution 4 \
  --aa \
  --dedither
```

*Opcions:*
- `-o`, `--output <DIR>`: Carpeta de destinació (per defecte: `dist/`).
- `-i`, `--icon <PNG>`: Fitxer PNG amb la icona o caràtula personalitzada.
- `-r`, `--resolution <1|2|4|8>`: Factor de resolució interna.
- `--aa`: Activa el suavitzat FXAA.
- `--dedither`: Activa el filtre de transparències VDP1.
- `--crt`: Habilita el filtre de línies CRT.
- `--widescreen`: Habilita la relació d'aspecte panoràmica 16:9.

### 4. Crear Release Multiplataforma (Mac + iOS/iPadOS)
```bash
cargo run -- release /camí/al/joc.cue --output ./dist --resolution 4
```
Genera:
- `dist/NomJoc.app` (Aplicació nativa de macOS)
- `dist/NomJoc.dmg` (Imatge de disc instal·lable per a Mac)
- `dist/NomJoc.ipa` (Paquet d'aplicació per a iPhone i iPad)

---

## 📱 Versions Multiplataforma (macOS, iOS, iPadOS)

Cada joc exportat amb la comanda `release` crea un paquet `.ipa` universal a més de la versió de Mac:
- **Arquitectura**: ARM64 natiu per a dispositius amb iOS 15 o posterior.
- **Instal·lació**: Compatible amb mètodes de càrrega lateral (*sideloading*) com **AltStore**, **SideStore**, **TrollStore** o **Xcode / Apple Configurator**.
- **Comandaments**: Suport per a comandaments MFi, DualSense, Xbox i controls tàctils.

---

## 🎮 Controls de Joc i Teclat

Tots els comandaments compatibles es configuren automàticament quan es connecten per Bluetooth o cable USB.

| Acció a Saturn | Tecla de Teclat | Comandament (PlayStation / Xbox / Switch) |
|---|---|---|
| **Creueta (Amunt / Avall / Esquerra / Dreta)** | Fletxes (`↑`, `↓`, `←`, `→`) | Creueta / Palanca Esquerra |
| **Botó A** | `Z` | Creu (✕) / `A` / `B` |
| **Botó B** | `X` | Cercle (○) / `B` / `A` |
| **Botó C** | `C` | R1 / `RB` / `R` |
| **Botó X** | `A` | Quadrat (□) / `X` / `Y` |
| **Botó Y** | `S` | Triangle (△) / `Y` / `X` |
| **Botó Z** | `D` | R2 / `RT` / `ZR` |
| **Gatell L** | `Q` | L1 / `LB` / `L` |
| **Gatell R** | `W` | R1 / `RB` / `R` |
| **Start** | `Enter` / `Retorn` | Opcions / Menú / `+` |

---

## 📂 Estructura d'un Paquet `.app`

Les aplicacions generades són totalment autònomes:
```text
NomJoc.app/
└── Contents/
    ├── Info.plist                     # Metadades, GameController framework i ATS
    ├── PkgInfo                        # Identificador Apple
    ├── MacOS/
    │   └── Launcher                   # Motor executable directe
    └── Resources/
        ├── AppIcon.icns               # Icona d'alta resolució per a macOS
        ├── Game/
        │   ├── game.cue               # Descriptor de pistes
        │   └── game.bin               # Imatge del joc i pistes d'àudio
        ├── cores/
        │   └── yabause_libretro.dylib # Nucli optimitzat per a Apple Silicon
        └── Config/
            └── saturn.json            # Paràmetres de resolució, filtres i controls
```

Les partides desades es guarden de forma neta i independent a:
`~/Library/Application Support/SaturnMac/Saves/<CodiProducte>/`

---

## 🧪 Tests Automatitzats

Pots comprovar el funcionament de tots els mòduls del projecte executant:
```bash
cargo test
```

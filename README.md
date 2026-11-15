# SaturnMac 🪐🍎

> **Convert your Sega Saturn game ROMs (`.cue`, `.bin`, `.iso`, `.chd`) into standalone, native macOS applications optimized for Apple Silicon.**

---

## 🌟 Característiques Principals

- **Parser natiu d'imatges de Saturn (IP.BIN)**:
  - Llegeix automàticament els primers sectors de la ROM (Mode 1 2048 bytes i RAW 2352 bytes).
  - Extreu metadades autèntiques del disc: títol oficial del joc (incloent suport per caràcters Shift-JIS japonesos), codi de producte (ex: `MK-81005`, `GS-9001`), data de llançament, versió i número de disc.
  - Detecta automàticament la **regió del disc** (Japó `J`, Amèrica del Nord `U`, Europa `E`, etc.) i els perifèrics compatibles (comandament estàndard, comandament analògic 3D, ratolí, pistola Virtua Gun, volant Arcade Racer, multitap).
  - Processa fulls `.cue` multi-pista resolent automàticament les pistes de dades i àudio CD-DA.

- **Generador de paquets natius `.app` de macOS**:
  - Construeix una aplicació autònoma `NomDelJoc.app` amb l'estructura estàndard d'Apple.
  - Genera automàticament l'arxiu d'icones natiu d'Apple **`AppIcon.icns`** compatible amb pantalles Retina (512x512 i 1024x1024).
  - Configura el fitxer `Info.plist` amb suport natiu per a:
    - Pantalles d'alta resolució Retina (`NSHighResolutionCapable`).
    - Compatibilitat amb mode fosc (`NSRequiresAquaSystemAppearance: false`).
    - API nativa de comandaments de macOS (`GCSupportedGameControllers` amb suport per a comandaments DualSense de PS5, Xbox Series X/S, Nintendo Switch Pro i 8BitDo).

- **Optimitzacions per a l'arquitectura Apple Silicon (M1/M2/M3/M4)**:
  - **Memòria Unificada (UMA)**: Aprofita l'amplada de banda massiva de la CPU/GPU unificada per evitar els colls d'ampolla clàssics de transferència de dades del bus de Saturn.
  - **Metal Graphics Pipeline**: Suport per a resolucions internes multiplicades (1x natiu 240p/480p, 2x 720p/960p, 4x 4K Retina).
  - **ProMotion (120Hz)**: Adaptació de la taxa de refresc dinàmica de les pantalles ProMotion de Mac.
  - **CoreAudio de baixa latència**: Buffers d'àudio reduïts per a una resposta sonora immediata del xip SCSP.

---

## 🚀 Ús des de la línia de comandes (CLI)

El motor principal està programat en Rust per a màxima rapidesa i zero dependències externes.

### 1. Compilació
```bash
cargo build --release
```

### 2. Inspeccionar una ROM de Saturn
Mostra tota la informació emmagatzemada a la capçalera del disc:
```bash
./target/release/saturnmac inspect /camí/al/joc.cue
```
O en format JSON:
```bash
./target/release/saturnmac inspect /camí/al/joc.bin --json
```

### 3. Empaquetar el joc en una App nativa de Mac (`.app`)
```bash
./target/release/saturnmac bundle /camí/al/joc.cue --output ~/Applications --resolution 4 --crt
```
*Opcions disponibles:*
- `--output` / `-o`: Directori on es desarà el paquet `.app` (per defecte: `./dist`).
- `--icon` / `-i`: Imatge PNG amb la caràtula oficial per generar l'arxiu `.icns`.
- `--resolution` / `-r`: Resolució interna (1 = 240p natiu, 2 = 2x, 4 = 4x Retina).
- `--crt`: Activa els filtres de fòsfor i línies d'escaneig CRT a través de Metal.
- `--widescreen`: Habilita la geometria anamòrfica panoràmica 16:9.

### 4. Generar una ROM de prova sintètica (Mock)
Permet provar l'empaquetador i la creació d'aplicacions sense necessitat d'una ROM protegida per copyright:
```bash
./target/release/saturnmac mock --title "SEGA RALLY CHAMPIONSHIP" --product "MK-81000" --region "E" rally.bin
```

---

## 🖥️ Interfície Gràfica nativa per a macOS (`gui/`)

El projecte inclou una aplicació nativa dissenyada amb **SwiftUI** seguint les guies de disseny de macOS:
- Zona per **arrossegar i deixar anar** (*drag & drop*) fitxers `.cue`, `.bin`, `.iso` o `.chd`.
- Visualització immediata de la caràtula, codi de producte, regió i perifèrics del disc.
- Selectors d'opcions gràfiques (resolució Retina, ProMotion 120Hz, filtres CRT).
- Botó d'un sol clic: **"Generar App de macOS (.app)"**.

Per obrir-la a macOS:
```bash
cd gui
swift run
```

---

## 📂 Estructura d'un paquet `.app` generat

Quan SaturnMac genera una aplicació (per exemple, `NIGHTS INTO DREAMS.app`), l'estructura interna és:

```text
NIGHTS INTO DREAMS.app/
└── Contents/
    ├── Info.plist                     # Metadades de l'aplicació, GameController framework i Retina
    ├── PkgInfo                        # Identificador del paquet d'aplicació Apple (APPL????)
    ├── MacOS/
    │   └── Launcher                   # Script d'arrencada natiu i selector de motor
    └── Resources/
        ├── AppIcon.icns               # Icona d'alta resolució generada per a macOS
        ├── Game/
        │   ├── game.cue               # Full de pistes CUE
        │   └── game.bin               # ROM del joc i pistes d'àudio
        └── Config/
            └── saturn.json            # Configuració optimitzada per a Apple Silicon
```

Les partides desades es guarden de forma neta i aïllada a:
`~/Library/Application Support/SaturnMac/Saves/<CodiProducte>/`

---

## 🧪 Tests

Pots executar els tests automatitzats en qualsevol moment amb:
```bash
cargo test
```

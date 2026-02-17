.PHONY: run build clean build-debug lint init clean-all localize localize-import localize-clean localize-scan test-audio test-audio-source test-audio-convert test-audio-clean test-audio-clean-all test-audio-info test-audio-formats


# ============================================================================
# Project Configuration
# ============================================================================

PROJECT := HiFidelity.xcodeproj
SCHEME := HiFidelity
APP_NAME := HiFidelity
DERIVED_DATA := ./build
DESTINATION := platform=macOS


# ============================================================================
# Build Paths
# ============================================================================

DEBUG_APP := $(DERIVED_DATA)/Build/Products/Debug/$(APP_NAME).app
RELEASE_APP := $(DERIVED_DATA)/Build/Products/Release/$(APP_NAME).app


# ============================================================================
# Test Audio Configuration
# ============================================================================

TEST_AUDIO_DIR := TestAudio
TEST_AUDIO_SOURCE := $(TEST_AUDIO_DIR)/source/紅一葉.mp3
TEST_AUDIO_GEN := $(TEST_AUDIO_DIR)/generated

# Allow custom input file via: make test-audio FILE=path/to/file.mp3
INPUT_FILE ?= $(TEST_AUDIO_SOURCE)
INPUT_BASENAME := $(shell basename "$(INPUT_FILE)" 2>/dev/null | sed 's/\.[^.]*$$//')
OUTPUT_DIR := $(TEST_AUDIO_GEN)/$(INPUT_BASENAME)


# ============================================================================
# System Configuration
# ============================================================================

NCPU := $(shell sysctl -n hw.ncpu)


# ============================================================================
# Default Target
# ============================================================================

all: build


# ============================================================================
# Build Targets
# ============================================================================

build-debug:
	@echo "[Xcode] Building Debug configuration..."
	@xcodebuild -project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-configuration Debug \
		-destination '$(DESTINATION)' \
		-derivedDataPath "$(DERIVED_DATA)" \
		build

build:
	@echo "[Xcode] Building Release configuration..."
	@xcodebuild -project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-configuration Release \
		-destination '$(DESTINATION)' \
		-derivedDataPath "$(DERIVED_DATA)" \
		build


# ============================================================================
# Run Targets
# ============================================================================

run: build
	@echo "[Run] Terminating existing instances..."
	@pkill -f "$(RELEASE_APP)/Contents/MacOS/$(APP_NAME)" 2>/dev/null || true
	@echo "[Run] Launching $(APP_NAME)..."
	@sudo open "$(RELEASE_APP)"

run-debug: build-debug
	@echo "[Run] Terminating existing instances..."
	@pkill -f "$(DEBUG_APP)/Contents/MacOS/$(APP_NAME)" 2>/dev/null || true
	@echo "[Run] Launching $(APP_NAME)..."
	@sudo open "$(DEBUG_APP)"

dev: run-debug


# ============================================================================
# Clean Targets
# ============================================================================

clean:
	@echo "[Clean] Removing build directory..."
	@rm -rf "$(DERIVED_DATA)"
	@echo "[Clean] Removing Xcode derived data..."
	@rm -rf ~/Library/Developer/Xcode/DerivedData/HiFidelity-* 2>/dev/null || true

clean-all: clean
	@echo "[Clean] Complete"


# ============================================================================
# Code Quality Targets
# ============================================================================

lint:
	@echo "[Lint] Running swiftlint..."
	@swiftlint --fix --quiet || echo "[Lint] Warning: swiftlint not found or failed"
	@echo "[Lint] Running prettier..."
	@prettier . --write --log-level warn || echo "[Lint] Warning: prettier not found or failed"


# ============================================================================
# LSP Initialization
# ============================================================================

init:
	@echo "[Init] Checking for Package.swift..."
	@if [ ! -f "Package.swift" ]; then \
		echo "[Init] Error: Package.swift not found. Writing to project root..."; \
		printf '%s\n' \
			'// swift-tools-version: 5.9' \
			'import PackageDescription' \
			'let package = Package(' \
			'    name: "HiFidelity",' \
			'    platforms: [.macOS(.v13)],' \
			'    products: [],' \
			'    dependencies: [' \
			'        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.8.0"),' \
			'        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.8.1")' \
			'        .package(url: "https://github.com/BegoniaHe/Lyra", branch: "main")' \
			'    ],' \
			'    targets: [' \
			'        .target(' \
			'            name: "HiFidelity",' \
			'            dependencies: [' \
			'                .product(name: "GRDB", package: "GRDB.swift"),' \
			'                "Sparkle"' \
			'            ],' \
			'            path: "./HiFidelity"' \
			'        )' \
			'    ]' \
			')' > Package.swift; \
		echo "[Init] Package.swift created successfully"; \
	else \
		echo "[Init] Package.swift already exists"; \
	fi
	@echo "[Init] Generating xcode-build-server config..."
	@if command -v xcode-build-server >/dev/null 2>&1; then \
		xcode-build-server config -project $(PROJECT) -scheme $(SCHEME); \
		echo "[Init] LSP config generated successfully"; \
	else \
		echo "[Init] Error: xcode-build-server not found"; \
		echo "[Init] Install with: brew install xcode-build-server"; \
		exit 1; \
	fi


# ============================================================================
# Xcode Management
# ============================================================================

xcode: clean
	@echo "[Xcode] Removing Package.swift and Package.resolved if exist..."
	@if [ -f "Package.swift" ]; then \
		rm -f "Package.swift"; \
		echo "[Xcode] Package.swift removed"; \
	else \
		echo "[Xcode] Package.swift not found, skipping removal"; \
	fi
	@if [ -f "Package.resolved" ]; then \
		rm -f "Package.resolved"; \
		echo "[Xcode] Package.resolved removed"; \
	else \
		echo "[Xcode] Package.resolved not found, skipping removal"; \
	fi
	@echo "[Xcode] Opening project in Xcode..."
	@xed .


# ============================================================================
# Installation Targets
# ============================================================================

install-debug: build-debug
	@echo "[Install] Checking for existing installation..."
	@if [ -d "/Applications/$(APP_NAME).app" ]; then \
		echo "[Install] Removing existing installation..."; \
		sudo rm -rf "/Applications/$(APP_NAME).app"; \
	fi
	@echo "[Install] Installing $(APP_NAME) to /Applications..."
	@sudo cp -R "$(DEBUG_APP)" "/Applications/$(APP_NAME).app"
	@echo "[Install] Removing quarantine attribute..."
	@sudo xattr -r -d com.apple.quarantine "/Applications/$(APP_NAME).app"
	@echo "[Install] Installation complete"

install: build
	@echo "[Install] Checking for existing installation..."
	@if [ -d "/Applications/$(APP_NAME).app" ]; then \
		echo "[Install] Removing existing installation..."; \
		sudo rm -rf "/Applications/$(APP_NAME).app"; \
	else \
		echo "[Install] No existing installation found, skipping removal"; \
	fi
	@echo "[Install] Installing $(APP_NAME) to /Applications..."
	@sudo cp -R "$(RELEASE_APP)" "/Applications/$(APP_NAME).app"
	@echo "[Install] Removing quarantine attribute..."
	@sudo xattr -r -d com.apple.quarantine "/Applications/$(APP_NAME).app"
	@echo "[Install] Installation complete"


# ============================================================================
# Localization Targets
# ============================================================================

localize:
	@echo "[Localize] Extracting localizable strings..."
	@echo "[Localize] Building project to extract strings..."
	@xcodebuild -project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-destination '$(DESTINATION)' \
		-derivedDataPath "$(DERIVED_DATA)" \
		clean build \
		2>&1 | grep -i "localization" || true
	@echo "[Localize] Exporting localizations to ./Localizations..."
	@mkdir -p ./Localizations
	@xcodebuild -exportLocalizations \
		-project "$(PROJECT)" \
		-localizationPath ./Localizations \
		-exportLanguage en \
		-exportLanguage zh-Hans \
		-exportLanguage de
	@echo ""
	@echo "[Localize] Localization files exported to ./Localizations/"
	@echo "[Localize] Next steps:"
	@echo "  1. Review exported .xcloc bundles in ./Localizations/"
	@echo "  2. Import back to Xcode: File -> Import Localizations..."
	@echo "  3. Or run 'make localize-import' to import automatically"
	@echo ""

localize-import:
	@echo "[Localize] Importing localizations..."
	@for xcloc in ./Localizations/*.xcloc; do \
		if [ -d "$$xcloc" ]; then \
			echo "[Localize] Importing $$xcloc..."; \
			xcodebuild -importLocalizations \
				-project "$(PROJECT)" \
				-localizationPath "$$xcloc"; \
		fi \
	done
	@echo "[Localize] Import complete"
	@echo "[Localize] Localizable.xcstrings updated"

localize-clean:
	@echo "[Localize] Cleaning exported localizations..."
	@rm -rf ./Localizations
	@echo "[Localize] Cleaned"

localize-scan:
	@echo "[Localize] Scanning for untranslated strings..."
	@echo ""
	@echo "Searching for String(localized:) usage:"
	@grep -r "String(localized:" HiFidelity --include="*.swift" || echo "  No String(localized:) found"
	@echo ""
	@echo "Searching for NSLocalizedString usage:"
	@grep -r "NSLocalizedString" HiFidelity --include="*.swift" || echo "  No NSLocalizedString found"
	@echo ""
	@echo "Searching for .localized usage:"
	@grep -r ".localized" HiFidelity --include="*.swift" || echo "  No .localized found"
	@echo ""


# ============================================================================
# Test Audio Targets
# ============================================================================

test-audio-source:
	@echo "[TestAudio] Checking for FFmpeg..."
	@if ! command -v ffmpeg >/dev/null 2>&1; then \
		echo "[TestAudio] Error: FFmpeg not found"; \
		echo "[TestAudio] Install with: brew install ffmpeg"; \
		exit 1; \
	fi
	@echo "[TestAudio] Creating source directory..."
	@mkdir -p $(TEST_AUDIO_DIR)/source
	@if [ -f "$(TEST_AUDIO_SOURCE)" ]; then \
		echo "[TestAudio] Source file already exists: $(TEST_AUDIO_SOURCE)"; \
	else \
		echo "[TestAudio] Generating 440Hz sine wave (10s)..."; \
		ffmpeg -f lavfi -i "sine=frequency=440:duration=10" \
			-c:a libmp3lame -b:a 192k \
			-metadata title="Test Audio - 440Hz Sine Wave" \
			-metadata artist="HiFidelity Test" \
			-metadata album="Test Audio" \
			"$(TEST_AUDIO_SOURCE)" 2>/dev/null; \
		echo "[TestAudio] Source file created: $(TEST_AUDIO_SOURCE)"; \
	fi

test-audio:
	@echo "[TestAudio] Checking for FFmpeg..."
	@if ! command -v ffmpeg >/dev/null 2>&1; then \
		echo "[TestAudio] Error: FFmpeg not found"; \
		echo "[TestAudio] Install with: brew install ffmpeg"; \
		exit 1; \
	fi
	@if [ "$(INPUT_FILE)" = "$(TEST_AUDIO_SOURCE)" ] && [ ! -f "$(TEST_AUDIO_SOURCE)" ]; then \
		echo "[TestAudio] Source file not found, generating..."; \
		$(MAKE) test-audio-source; \
	fi
	@if [ ! -f "$(INPUT_FILE)" ]; then \
		echo "[TestAudio] Error: Input file not found: $(INPUT_FILE)"; \
		echo "[TestAudio] Usage:"; \
		echo "  make test-audio                    # Use default test.mp3"; \
		echo "  make test-audio FILE=path/to/file  # Convert specific file"; \
		exit 1; \
	fi
	@echo "[TestAudio] Converting: $(INPUT_FILE)"
	@echo "[TestAudio] Output directory: $(OUTPUT_DIR)"
	@echo ""
	@mkdir -p "$(OUTPUT_DIR)"
	@$(MAKE) -s _convert-all-formats

_convert-all-formats:
	@echo "================================================================"
	@echo "  Converting: $(INPUT_BASENAME)"
	@echo "================================================================"
	@echo ""
	@echo "--- Core Formats ---"
	@printf "  [1/27] MP3 -> MP2... "
	@ffmpeg -i "$(INPUT_FILE)" -c:a mp2 -b:a 192k -y "$(OUTPUT_DIR)/$(INPUT_BASENAME).mp2" 2>/dev/null && echo "OK" || echo "FAILED"
	@printf "  [2/27] MP3 -> OGG... "
	@ffmpeg -i "$(INPUT_FILE)" -c:a libvorbis -q:a 6 -y "$(OUTPUT_DIR)/$(INPUT_BASENAME).ogg" 2>/dev/null && echo "OK" || echo "FAILED"
	@printf "  [3/27] MP3 -> WAV... "
	@ffmpeg -i "$(INPUT_FILE)" -c:a pcm_s16le -y "$(OUTPUT_DIR)/$(INPUT_BASENAME).wav" 2>/dev/null && echo "OK" || echo "FAILED"
	@printf "  [4/27] MP3 -> AIFF... "
	@ffmpeg -i "$(INPUT_FILE)" -c:a pcm_s16be -y "$(OUTPUT_DIR)/$(INPUT_BASENAME).aiff" 2>/dev/null && echo "OK" || echo "FAILED"
	@printf "  [5/27] MP3 -> AIF... "
	@ffmpeg -i "$(INPUT_FILE)" -c:a pcm_s16be -y "$(OUTPUT_DIR)/$(INPUT_BASENAME).aif" 2>/dev/null && echo "OK" || echo "FAILED"
	@echo ""
	@echo "--- AAC/MP4 Series ---"
	@printf "  [6/27] MP3 -> M4A... "
	@ffmpeg -i "$(INPUT_FILE)" -c:a aac -b:a 256k -y "$(OUTPUT_DIR)/$(INPUT_BASENAME).m4a" 2>/dev/null && echo "OK" || echo "FAILED"
	@printf "  [7/27] MP3 -> M4B... "
	@ffmpeg -i "$(INPUT_FILE)" -c:a aac -b:a 128k -y "$(OUTPUT_DIR)/$(INPUT_BASENAME).m4b" 2>/dev/null && echo "OK" || echo "FAILED"
	@printf "  [8/27] MP3 -> M4P... "
	@ffmpeg -i "$(INPUT_FILE)" -c:a aac -b:a 256k -y "$(OUTPUT_DIR)/$(INPUT_BASENAME).m4p" 2>/dev/null && echo "OK" || echo "FAILED"
	@printf "  [9/27] MP3 -> MP4... "
	@ffmpeg -i "$(INPUT_FILE)" -c:a aac -b:a 256k -y "$(OUTPUT_DIR)/$(INPUT_BASENAME).mp4" 2>/dev/null && echo "OK" || echo "FAILED"
	@printf " [10/27] MP3 -> M4V... "
	@ffmpeg -i "$(INPUT_FILE)" -c:a aac -b:a 256k -y "$(OUTPUT_DIR)/$(INPUT_BASENAME).m4v" 2>/dev/null && echo "OK" || echo "FAILED"
	@printf " [11/27] MP3 -> AAC... "
	@ffmpeg -i "$(INPUT_FILE)" -c:a aac -b:a 256k -y "$(OUTPUT_DIR)/$(INPUT_BASENAME).aac" 2>/dev/null && echo "OK" || echo "FAILED"
	@echo ""
	@echo "--- Apple Formats ---"
	@printf " [12/27] MP3 -> CAF... "
	@ffmpeg -i "$(INPUT_FILE)" -c:a alac -y "$(OUTPUT_DIR)/$(INPUT_BASENAME).caf" 2>/dev/null && echo "OK" || echo "FAILED"
	@echo ""
	@echo "--- Lossless Formats ---"
	@printf " [13/27] MP3 -> FLAC... "
	@ffmpeg -i "$(INPUT_FILE)" -c:a flac -compression_level 8 -y "$(OUTPUT_DIR)/$(INPUT_BASENAME).flac" 2>/dev/null && echo "OK" || echo "FAILED"
	@printf " [14/27] MP3 -> OGA... "
	@ffmpeg -i "$(INPUT_FILE)" -c:a flac -y "$(OUTPUT_DIR)/$(INPUT_BASENAME).oga" 2>/dev/null && echo "OK" || echo "FAILED"
	@printf " [15/27] MP3 -> WV... "
	@ffmpeg -i "$(INPUT_FILE)" -c:a wavpack -y "$(OUTPUT_DIR)/$(INPUT_BASENAME).wv" 2>/dev/null && echo "OK" || echo "FAILED"
	@printf " [16/27] MP3 -> APE... "
	@ffmpeg -i "$(INPUT_FILE)" -c:a ape -y "$(OUTPUT_DIR)/$(INPUT_BASENAME).ape" 2>/dev/null && echo "OK" || echo "SKIP (encoder unavailable)"
	@printf " [17/27] MP3 -> TTA... "
	@ffmpeg -i "$(INPUT_FILE)" -c:a tta -y "$(OUTPUT_DIR)/$(INPUT_BASENAME).tta" 2>/dev/null && echo "OK" || echo "FAILED"
	@echo ""
	@echo "--- High Quality Formats ---"
	@printf " [18/27] MP3 -> OPUS... "
	@ffmpeg -i "$(INPUT_FILE)" -c:a libopus -b:a 128k -y "$(OUTPUT_DIR)/$(INPUT_BASENAME).opus" 2>/dev/null && echo "OK" || echo "FAILED"
	@printf " [19/27] MP3 -> WEBM... "
	@ffmpeg -i "$(INPUT_FILE)" -c:a libopus -y "$(OUTPUT_DIR)/$(INPUT_BASENAME).webm" 2>/dev/null && echo "OK" || echo "FAILED"
	@printf " [20/27] MP3 -> MPC... "
	@ffmpeg -i "$(INPUT_FILE)" -c:a mpc -y "$(OUTPUT_DIR)/$(INPUT_BASENAME).mpc" 2>/dev/null && echo "OK" || echo "SKIP (encoder unavailable)"
	@printf " [21/27] MP3 -> SPX... "
	@ffmpeg -i "$(INPUT_FILE)" -c:a libspeex -y "$(OUTPUT_DIR)/$(INPUT_BASENAME).spx" 2>/dev/null && echo "OK" || echo "SKIP (encoder unavailable)"
	@echo ""
	@echo "================================================================"
	@echo ""
	@$(MAKE) -s _show-results

_show-results:
	@echo "Conversion Results"
	@echo ""
	@echo "Input:  $(INPUT_FILE)"
	@echo "Output: $(OUTPUT_DIR)/"
	@echo ""
	@if [ -d "$(OUTPUT_DIR)" ]; then \
		echo "Generated files:"; \
		ls -lh "$(OUTPUT_DIR)" | tail -n +2 | awk '{printf "  %-30s %8s\n", $$9, $$5}' | sort; \
		echo ""; \
		echo "Total files: $$(ls -1 "$(OUTPUT_DIR)" | wc -l | tr -d ' ')"; \
		echo "Total size:  $$(du -sh "$(OUTPUT_DIR)" 2>/dev/null | cut -f1)"; \
	else \
		echo "No files generated."; \
	fi
	@echo ""

test-audio-convert:
	@if [ -z "$(FILE)" ]; then \
		echo "[TestAudio] Error: FILE parameter required"; \
		echo "Usage: make test-audio-convert FILE=path/to/file.mp3"; \
		exit 1; \
	fi
	@$(MAKE) test-audio INPUT_FILE="$(FILE)"

test-audio-clean:
	@echo "[TestAudio] Cleaning generated files..."
	@rm -rf $(TEST_AUDIO_GEN)
	@mkdir -p $(TEST_AUDIO_GEN)
	@echo "[TestAudio] Cleaned"

test-audio-clean-all:
	@echo "[TestAudio] Cleaning all test audio files..."
	@rm -rf $(TEST_AUDIO_DIR)
	@echo "[TestAudio] All test audio removed"

test-audio-info:
	@echo "================================================================"
	@echo "  Test Audio Information"
	@echo "================================================================"
	@echo ""
	@if [ -f "$(TEST_AUDIO_SOURCE)" ]; then \
		echo "Source File:"; \
		echo "   $(TEST_AUDIO_SOURCE)"; \
		echo ""; \
		echo "Audio Info:"; \
		ffprobe -v quiet -show_entries format=duration,bit_rate,size:stream=codec_name,sample_rate,channels -of default=noprint_wrappers=1 "$(TEST_AUDIO_SOURCE)" 2>/dev/null | sed 's/^/   /' || echo "   Unable to read file info"; \
		echo ""; \
	else \
		echo "Warning: Source file not found: $(TEST_AUDIO_SOURCE)"; \
		echo "   Run 'make test-audio-source' to generate it."; \
		echo ""; \
	fi
	@if [ -d "$(TEST_AUDIO_GEN)" ] && [ -n "$$(ls -A $(TEST_AUDIO_GEN) 2>/dev/null)" ]; then \
		echo "Generated Files:"; \
		for dir in $(TEST_AUDIO_GEN)/*; do \
			if [ -d "$$dir" ]; then \
				echo ""; \
				echo "   $$(basename $$dir):"; \
				ls -lh "$$dir" 2>/dev/null | tail -n +2 | awk '{printf "     %-30s %8s\n", $$9, $$5}' | sort; \
				echo "     Total: $$(ls -1 $$dir | wc -l | tr -d ' ') files, $$(du -sh $$dir 2>/dev/null | cut -f1)"; \
			fi \
		done; \
		echo ""; \
	else \
		echo "No generated files yet."; \
		echo "   Run 'make test-audio' to generate test files."; \
		echo ""; \
	fi
	@echo "================================================================"

test-audio-formats:
	@echo "================================================================"
	@echo "  Supported Audio Formats"
	@echo "================================================================"
	@echo ""
	@echo "Core Formats:"
	@echo "   MP3, MP2                    (MPEG Audio)"
	@echo "   OGG                         (Ogg Vorbis)"
	@echo "   WAV, AIFF, AIF              (PCM Uncompressed)"
	@echo ""
	@echo "AAC/MP4 Series:"
	@echo "   M4A, M4B, M4P               (MPEG-4 Audio)"
	@echo "   MP4, M4V                    (MPEG-4 Container)"
	@echo "   AAC                         (Advanced Audio Coding)"
	@echo ""
	@echo "Apple Formats:"
	@echo "   CAF                         (Core Audio Format)"
	@echo ""
	@echo "Lossless Formats:"
	@echo "   FLAC, OGA                   (FLAC / Ogg FLAC)"
	@echo "   WV                          (WavPack)"
	@echo "   APE                         (Monkey's Audio)"
	@echo "   TTA                         (True Audio)"
	@echo ""
	@echo "High Quality Formats:"
	@echo "   OPUS                        (Opus)"
	@echo "   WEBM                        (WebM with Opus)"
	@echo "   MPC                         (Musepack)"
	@echo "   SPX                         (Speex)"
	@echo ""
	@echo "================================================================"

rm-db:
	@echo "[Database] Removing HiFidelity database..."
	@sudo rm -rf ~/Library/Containers/vr.HiFidelity/Data/Library/Application\ Support/vr.HiFidelity
	@echo "[Database] Removed"

rm-db-dev:
	@echo "[Database] Removing HiFidelity development database..."
	@sudo rm -rf ~/Library/Containers/vr.HiFidelity.debug/Data/Library/Application\ Support/vr.HiFidelity.debug
	@echo "[Database] Removed"


# ============================================================================
# Help
# ============================================================================

help:
	@echo "HiFidelity Build System"
	@echo ""
	@echo "Build targets:"
	@echo "  make build              - Build release configuration"
	@echo "  make build-debug        - Build debug configuration"
	@echo "  make run                - Build and run release app"
	@echo "  make run-debug          - Build and run debug app"
	@echo "  make dev                - Alias for run-debug"
	@echo ""
	@echo "Clean targets:"
	@echo "  make clean              - Clean build artifacts"
	@echo "  make clean-all          - Clean everything including TagLib"
	@echo ""
	@echo "Code quality:"
	@echo "  make lint               - Format code with swiftlint and prettier"
	@echo "  make init               - Initialize LSP config for VSCode"
	@echo ""
	@echo "Localization:"
	@echo "  make localize           - Export localizations (en, zh-Hans, de)"
	@echo "  make localize-import    - Import localizations back to project"
	@echo "  make localize-scan      - Scan code for localization strings"
	@echo "  make localize-clean     - Clean exported localization files"
	@echo ""
	@echo "Test Audio:"
	@echo "  make test-audio         - Convert default test.mp3 to all formats"
	@echo "  make test-audio FILE=.. - Convert specific file to all formats"
	@echo "  make test-audio-source  - Generate source test audio"
	@echo "  make test-audio-clean   - Clean generated test files"
	@echo "  make test-audio-info    - Show test audio information"
	@echo "  make test-audio-formats - List all supported formats"
	@echo ""
	@echo "Dependencies:"
	@echo "  make build-taglib       - Build TagLib from source"
	@echo "  make rebuild-taglib     - Force rebuild TagLib"
	@echo ""
	@echo "Installation:"
	@echo "  make install            - Install release app to /Applications"
	@echo "  make install-debug      - Install debug app to /Applications"
	@echo ""
	@echo "Other:"
	@echo "  make xcode              - Clean and open in Xcode"
	@echo "  make help               - Show this help message"

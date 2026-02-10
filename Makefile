.PHONY: run build clean build-debug lint init build-taglib check-taglib rebuild-taglib clean-all

# Project configuration
PROJECT := HiFidelity.xcodeproj
SCHEME := HiFidelity
APP_NAME := HiFidelity
DERIVED_DATA := ./build
DESTINATION := platform=macOS

# Build paths
DEBUG_APP := $(DERIVED_DATA)/Build/Products/Debug/$(APP_NAME).app
RELEASE_APP := $(DERIVED_DATA)/Build/Products/Release/$(APP_NAME).app

# TagLib configuration
TAGLIB_BUILD_DIR := $(DERIVED_DATA)/taglib
TAGLIB_LIB := HiFidelity/deps/lib/libtag.dylib
TAGLIB_SOURCE := ThirdParty/taglib
TAGLIB_INSTALL := HiFidelity/deps

# Build flags
CMAKE_BUILD_FLAGS := \
	-DCMAKE_BUILD_TYPE=Release \
	-DBUILD_SHARED_LIBS=ON \
	-DBUILD_TESTING=OFF \
	-DBUILD_EXAMPLES=OFF \
	-DBUILD_BINDINGS=OFF \
	-DCMAKE_OSX_DEPLOYMENT_TARGET=12.0 \
	-DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
	-DCMAKE_INSTALL_PREFIX=../../$(TAGLIB_INSTALL)

NCPU := $(shell sysctl -n hw.ncpu)

# Default target
all: build

# Check if TagLib needs to be built
check-taglib:
	@if [ ! -f "$(TAGLIB_LIB)" ]; then \
		echo "[TagLib] Not found, building..."; \
		$(MAKE) build-taglib; \
	else \
		echo "[TagLib] Already built"; \
	fi

# Build TagLib from source
build-taglib:
	@echo "[TagLib] Initializing submodules..."
	@git submodule update --init --recursive
	@echo "[TagLib] Creating build directory..."
	@mkdir -p $(TAGLIB_BUILD_DIR)
	@echo "[TagLib] Configuring with CMake..."
	@cd $(TAGLIB_BUILD_DIR) && \
		cmake ../../$(TAGLIB_SOURCE) $(CMAKE_BUILD_FLAGS)
	@echo "[TagLib] Building with $(NCPU) cores..."
	@cd $(TAGLIB_BUILD_DIR) && \
		cmake --build . --config Release -j$(NCPU)
	@echo "[TagLib] Installing to $(TAGLIB_INSTALL)..."
	@cd $(TAGLIB_BUILD_DIR) && \
		cmake --install . --config Release
	@echo "[TagLib] Build complete"

# Force rebuild TagLib
rebuild-taglib:
	@echo "[TagLib] Cleaning previous build..."
	@rm -rf $(TAGLIB_BUILD_DIR) $(TAGLIB_INSTALL)
	@$(MAKE) build-taglib

# Build debug configuration
build-debug: check-taglib
	@echo "[Xcode] Building Debug configuration..."
	@xcodebuild -project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-configuration Debug \
		-destination '$(DESTINATION)' \
		-derivedDataPath "$(DERIVED_DATA)" \
		build

# Build release configuration
build: check-taglib
	@echo "[Xcode] Building Release configuration..."
	@xcodebuild -project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-configuration Release \
		-destination '$(DESTINATION)' \
		-derivedDataPath "$(DERIVED_DATA)" \
		build

# Run the debug app
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

# Clean build artifacts
clean:
	@echo "[Clean] Removing build directory..."
	@rm -rf "$(DERIVED_DATA)"
	@echo "[Clean] Removing Xcode derived data..."
	@rm -rf ~/Library/Developer/Xcode/DerivedData/HiFidelity-* 2>/dev/null || true

# Clean everything including TagLib
clean-all: clean
	@echo "[Clean] Removing TagLib installation..."
	@rm -rf $(TAGLIB_INSTALL)
	@echo "[Clean] Complete"

# Format code
lint:
	@echo "[Lint] Running swiftlint..."
	@swiftlint --fix --quiet || echo "[Lint] Warning: swiftlint not found or failed"
	@echo "[Lint] Running prettier..."
	@prettier . --write --log-level warn || echo "[Lint] Warning: prettier not found or failed"

# Initialize LSP for VSCode
init:
	@echo "[Init] Generating xcode-build-server config..."
	@if command -v xcode-build-server >/dev/null 2>&1; then \
		xcode-build-server config -project $(PROJECT) -scheme $(SCHEME); \
		echo "[Init] LSP config generated successfully"; \
	else \
		echo "[Init] Error: xcode-build-server not found"; \
		echo "[Init] Install with: brew install xcode-build-server"; \
		exit 1; \
	fi

# Install debug .app to /Applications
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

# Install release .app to /Applications
install: build
	@echo "[Install] Checking for existing installation..."
	@if [ -d "/Applications/$(APP_NAME).app" ]; then \
		echo "[Install] Removing existing installation..."; \
		sudo rm -rf "/Applications/$(APP_NAME).app"; \
	fi
	@echo "[Install] Installing $(APP_NAME) to /Applications..."
	@sudo cp -R "$(RELEASE_APP)" "/Applications/$(APP_NAME).app"
	@echo "[Install] Removing quarantine attribute..."
	@sudo xattr -r -d com.apple.quarantine "/Applications/$(APP_NAME).app"
	@echo "[Install] Installation complete"
	
# Show help
help:
	@echo "HiFidelity Build System"
	@echo ""
	@echo "Available targets:"
	@echo "  make build          - Build release configuration"
	@echo "  make build-debug    - Build debug configuration"
	@echo "  make run            - Build and run debug app"
	@echo "  make clean          - Clean build artifacts"
	@echo "  make clean-all      - Clean everything including TagLib"
	@echo "  make lint           - Format code with swiftlint and prettier"
	@echo "  make init           - Initialize LSP config for VSCode"
	@echo "  make build-taglib   - Build TagLib from source"
	@echo "  make rebuild-taglib - Force rebuild TagLib"
	@echo "  make help           - Show this help message"
	@echo "  make install        - Install the app to /Applications"

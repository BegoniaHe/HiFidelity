.PHONY: run build clean build-debug lint

PROJECT := HiFidelity.xcodeproj
SCHEME := HiFidelity
APP_NAME := HiFidelity
DERIVED_DATA := ./build
DESTINATION := platform=macOS

DEBUG_APP := $(DERIVED_DATA)/Build/Products/Debug/$(APP_NAME).app
RELEASE_APP := $(DERIVED_DATA)/Build/Products/Release/$(APP_NAME).app

# use sudo to run the app with the necessary permissions to access audio and other resources
run: build-debug
	pkill -f "$(DEBUG_APP)/Contents/MacOS/$(APP_NAME)" || true
	sudo open "$(DEBUG_APP)"

build:
	xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -configuration Release -destination '$(DESTINATION)' -derivedDataPath "$(DERIVED_DATA)" build

build-debug:
	xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -configuration Debug -destination '$(DESTINATION)' -derivedDataPath "$(DERIVED_DATA)" build

clean:
	rm -rf "$(DERIVED_DATA)"
	rm -rf ~/Library/Developer/Xcode/DerivedData

lint:
	swiftlint --fix
	prettier . --write

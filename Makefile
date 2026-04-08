.PHONY: generate build run clean

# Generate Xcode project from project.yml (requires xcodegen)
generate:
	xcodegen generate

# Build the app
build: generate
	xcodebuild -project ShotMaker.xcodeproj -scheme ShotMaker -configuration Release -derivedDataPath build build

# Build and run
run: build
	@mkdir -p build/Build/Products/Release/ShotMaker.app/Contents/Resources
	@cp ShotMaker/ShotMaker.icns build/Build/Products/Release/ShotMaker.app/Contents/Resources/
	@touch build/Build/Products/Release/ShotMaker.app
	open build/Build/Products/Release/ShotMaker.app

# Clean build artifacts
clean:
	xcodebuild -project ShotMaker.xcodeproj -scheme ShotMaker clean 2>/dev/null || true
	rm -rf build/

# Install xcodegen if not present
setup:
	brew install xcodegen

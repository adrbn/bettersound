APP = build/Build/Products/Release/BetterSound.app
# Same numbering as the release script, so a local build never looks older than the last release.
VERSION = MARKETING_VERSION=$(shell git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//') CURRENT_PROJECT_VERSION=$(shell git rev-list --count HEAD)

build:
	xcodegen generate -q
	xcodebuild -project BetterSound.xcodeproj -scheme BetterSound -configuration Release -derivedDataPath build -quiet $(VERSION) $(SIGN)

# Signs with your Developer ID (set TEAM), installs to /Applications and relaunches.
install: SIGN = BS_IDENTITY="Developer ID Application" BS_TEAM=$(TEAM)
install: build
	./scripts/sign_sparkle.sh $(APP) "Developer ID Application"
	-killall BetterSound
	rm -rf /Applications/BetterSound.app && cp -R $(APP) /Applications/
	open /Applications/BetterSound.app

.PHONY: build install

# Signed, notarized DMG + Sparkle appcast, published as a GitHub release: make release TAG=v0.1.0
release:
	./scripts/release.sh $(TAG)

.PHONY: release

APP = build/Build/Products/Release/BetterSound.app

build:
	xcodegen generate -q
	xcodebuild -project BetterSound.xcodeproj -scheme BetterSound -configuration Release -derivedDataPath build -quiet $(SIGN)

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

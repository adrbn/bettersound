APP = build/Build/Products/Release/BetterSound.app

build:
	xcodegen generate -q
	xcodebuild -project BetterSound.xcodeproj -scheme BetterSound -configuration Release -derivedDataPath build -quiet $(SIGN)

# Signs with your Developer ID (set TEAM), installs to /Applications and relaunches.
install: SIGN = BS_IDENTITY="Developer ID Application" BS_TEAM=$(TEAM)
install: build
	-killall BetterSound
	rm -rf /Applications/BetterSound.app && cp -R $(APP) /Applications/
	open /Applications/BetterSound.app

.PHONY: build install

.PHONY: build test run verify release dmg icon clean

APP := build/Network Speed.app
TEST_BINARY := .build/manual-tests/NetworkSpeedAppTests
TEST_SOURCES := \
	Sources/NetworkSpeedApp/Models/NetworkTraffic.swift \
	Sources/NetworkSpeedApp/Services/NetworkTrafficMonitor.swift \
	Sources/NetworkSpeedApp/Services/DefaultRouteResolver.swift \
	Sources/NetworkSpeedApp/State/NetworkSpeedCalculator.swift \
	Sources/NetworkSpeedApp/Formatters/TrafficFormatter.swift \
	Sources/NetworkSpeedApp/Views/MenuBarIconRenderer.swift \
	Tests/NetworkSpeedAppTests/NetworkSpeedCalculatorTests.swift

build:
	./App/build.sh

test:
	mkdir -p .build/manual-tests
	swiftc -parse-as-library $(TEST_SOURCES) -o "$(TEST_BINARY)"
	"$(TEST_BINARY)"

run: build
	open "$(APP)"

verify: build test
	codesign --verify --deep --strict --verbose=2 "$(APP)"
	plutil -lint "$(APP)/Contents/Info.plist"
	file "$(APP)/Contents/MacOS/NetworkSpeedApp" | grep -q 'universal binary'
	lipo "$(APP)/Contents/MacOS/NetworkSpeedApp" -verify_arch arm64 x86_64

release: verify
	PACKAGE_FORMAT=all ./scripts/package-release.sh

dmg: verify
	PACKAGE_FORMAT=dmg ./scripts/package-release.sh

icon:
	./scripts/make-icon.sh

clean:
	rm -rf .build build dist

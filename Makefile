# PixPets Makefile
# Build, sign, package for distribution

APP_NAME = pixpets
DISPLAY_NAME = PixPets
VERSION ?= $(shell cat VERSION 2>/dev/null || echo 0.0.0)
BUILD_NUMBER ?= 1

.PHONY: all help clean build run release app-bundle sign dmg distribute

# Default
all: build

help:
	@echo "PixPets Build System"
	@echo ""
	@echo "Development:"
	@echo "  make build         Build debug binary (swift build)"
	@echo "  make run           Build + run"
	@echo "  make clean         Remove build artifacts"
	@echo ""
	@echo "Distribution (brew --cask):"
	@echo "  make release       Build release binary"
	@echo "  make app-bundle    Create .app bundle (universal binary)"
	@echo "  make sign          Sign + notarize .app"
	@echo "  make dmg           Create signed DMG"
	@echo "  make distribute    Full pipeline: build → sign → DMG"
	@echo ""
	@echo "Options:"
	@echo "  VERSION=1.0.0      Set version string"
	@echo "  BUILD_NUMBER=1     Set build number"
	@echo "  SKIP_NOTARIZE=1    Skip notarization step"

# --- Development ---

build:
	swift build

run: build
	swift run

clean:
	rm -rf .build dist

# --- Distribution ---

release:
	swift build -c release

app-bundle:
	VERSION=$(VERSION) BUILD_NUMBER=$(BUILD_NUMBER) ./scripts/create-app-bundle.sh

sign: app-bundle
	./scripts/sign-and-notarize.sh

dmg: sign
	./scripts/create-dmg.sh

distribute: clean dmg
	@echo ""
	@echo "=== Distribution complete ==="
	@echo "DMG: dist/$(DISPLAY_NAME).dmg"
	@echo "Version: $(VERSION) ($(BUILD_NUMBER))"

# --- Release ---

gh-release: distribute
	./scripts/release.sh $(VERSION)

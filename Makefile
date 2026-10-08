# `make` builds every theme from design/tokens.ts and, on Linux, installs
# them for the current user. On other systems it builds into dist/ only.
#
# On Arch: `make package` builds the ambrosia-* packages into out/pkg/, and
# `sudo make iso` builds the installer image from them into out/iso/.
# `make quickshell` rebuilds Quickshell for the installed Qt when needed.

.PHONY: all build install update clean package quickshell iso

all: install

node_modules: package.json bun.lock
	bun install
	@touch node_modules

build: node_modules
	bun test
	bun run build

install: build
	sh tools/install.sh

update: clean install

package:
	mkdir -p out/pkg
	cd packaging && BUILDDIR=$(CURDIR)/out/build PKGDEST=$(CURDIR)/out/pkg makepkg --force --cleanbuild

# Quickshell rebuilt against the installed Qt, for when Arch's lags behind.
quickshell:
	mkdir -p out/pkg
	cd packaging/quickshell && BUILDDIR=$(CURDIR)/out/build PKGDEST=$(CURDIR)/out/pkg makepkg --force --cleanbuild

iso:
	tools/build-iso.sh

clean:
	rm -rf dist out

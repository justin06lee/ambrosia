# `make` builds every theme from design/tokens.ts and, on Linux, installs
# them for the current user. On other systems it builds into dist/ only.
#
# On Arch: `make package` builds the ambrosia-* packages into out/pkg/, and
# `sudo make iso` builds the installer image from them into out/iso/.
# `make quickshell` builds our patched Quickshell for the installed Qt.
#
# On the Mac: `make publish` builds the packages on tenet, signs them and
# uploads them to the hosted [ambrosia] repo (tools/publish-repo.sh).

.PHONY: all build install update clean package quickshell iso publish

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
	rm -f out/pkg/ambrosia-*.pkg.tar.zst
	cd packaging && BUILDDIR=$(CURDIR)/out/build PKGDEST=$(CURDIR)/out/pkg makepkg --force --cleanbuild

# Our Quickshell, with the app menu patch, built against the installed Qt.
quickshell:
	mkdir -p out/pkg
	rm -f out/pkg/quickshell-*.pkg.tar.zst
	cd packaging/quickshell && BUILDDIR=$(CURDIR)/out/build PKGDEST=$(CURDIR)/out/pkg makepkg --force --cleanbuild

iso:
	tools/build-iso.sh

publish:
	tools/publish-repo.sh $(HOST)

clean:
	rm -rf dist out

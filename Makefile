# `make` builds every theme from design/tokens.ts and, on Linux, installs
# them for the current user. On other systems it builds into dist/ only.
#
# On Arch: `make package` builds the ambrosia-* packages into out/pkg/, and
# `sudo make iso` builds the installer image from them into out/iso/.
# `make quickshell` builds our patched Quickshell for the installed Qt.
#
# On the Mac: `make publish` builds the packages on tenet, signs them and
# uploads them to the hosted [ambrosia] repo (tools/publish-repo.sh).
# `make remote-build` runs the build gate on tenet instead of the Mac, and
# `make review-remote` serves the review site from tenet on localhost:4747,
# and `make shot-remote` photographs a page there into out/shots/. All three
# use tenet's own checkout (tools/remote.sh) and run capped there.

HOST ?= justin06lee@192.168.1.172
AMBROSIA_RSH ?= ssh -i $(HOME)/.ssh/id_ed25519_justin -o IdentitiesOnly=yes
export AMBROSIA_RSH
# tenet has no swap and runs other projects' services.
CAP = systemd-run --user --scope --quiet -p MemoryMax=6G nice -n 19 ionice -c3

.PHONY: all build install update clean package quickshell iso publish remote-build review-remote shot-remote

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

remote-build:
	tools/remote.sh $(HOST) '$(CAP) make build'

# The server keeps running on tenet after the tunnel closes:
# `tools/remote.sh $(HOST) systemctl --user stop ambrosia-review` stops it.
review-remote:
	tools/remote.sh $(HOST) 'systemctl --user stop ambrosia-review 2>/dev/null; bun install --frozen-lockfile >/dev/null && systemd-run --user --unit=ambrosia-review --quiet -p MemoryMax=2G -p Nice=10 --working-directory=$$PWD bun run review'
	@echo "review site: http://localhost:4747 (Ctrl-C closes the tunnel)"
	$(AMBROSIA_RSH) -N -L 4747:localhost:4747 $(HOST)

# Headless Firefox at 1440x900. PAGE is a file in the checkout or a URL (the
# review site is http://localhost:4747/ while review-remote runs); SHOT names
# the picture.
PAGE ?= preview/index.html
SHOT ?= preview
shot-remote:
	tools/remote.sh $(HOST) 'bun install --frozen-lockfile >/dev/null && $(CAP) bun tools/gen/index.ts >/dev/null && mkdir -p out/shots out/firefox && rm -f out/shots/$(SHOT).png && { systemd-run --user --scope --quiet -p MemoryMax=2G nice -n 19 timeout 120 firefox --headless --no-remote --profile $$PWD/out/firefox --window-size=1440,900 --screenshot $$PWD/out/shots/$(SHOT).png "$(if $(filter http%,$(PAGE)),$(PAGE),file://$$PWD/$(PAGE))" >/dev/null 2>&1; test -s out/shots/$(SHOT).png; }'
	mkdir -p out/shots
	rsync -q -e '$(AMBROSIA_RSH)' $(HOST):work/ambrosia/out/shots/$(SHOT).png out/shots/
	@echo out/shots/$(SHOT).png

clean:
	rm -rf dist out

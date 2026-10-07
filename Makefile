# `make` builds every theme from design/tokens.ts and, on Linux, installs
# them for the current user. On other systems it builds into dist/ only.

.PHONY: all build install update clean

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

clean:
	rm -rf dist

BINARY  := kat
VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)
COMMIT  := $(shell git rev-parse --short HEAD 2>/dev/null || echo none)
DATE    := $(shell date -u +%Y-%m-%dT%H:%M:%SZ)
LDFLAGS := -s -w -X main.version=$(VERSION) -X main.commit=$(COMMIT) -X main.date=$(DATE)

PLATFORMS := linux/amd64 linux/arm64 darwin/amd64 darwin/arm64 windows/amd64 windows/arm64

.PHONY: dev build build-all test install clean

dev:
	go run ./cmd

build:
	go build -trimpath -ldflags "$(LDFLAGS)" -o ./bin/$(BINARY) ./cmd

# cross-compile every release target into dist/ (same set as .github/workflows/release.yml)
build-all:
	@rm -rf dist && mkdir -p dist
	@for platform in $(PLATFORMS); do \
		goos=$${platform%/*}; goarch=$${platform#*/}; \
		out=build/$${goos}_$${goarch}/$(BINARY); \
		[ "$$goos" = "windows" ] && out=$$out.exe; \
		echo "==> $$goos/$$goarch"; \
		CGO_ENABLED=0 GOOS=$$goos GOARCH=$$goarch \
			go build -trimpath -ldflags "$(LDFLAGS)" -o $$out ./cmd || exit 1; \
		if [ "$$goos" = "windows" ]; then \
			(cd build/$${goos}_$${goarch} && zip -qr ../../dist/$(BINARY)_$(VERSION)_$${goos}_$${goarch}.zip .); \
		else \
			tar -czf dist/$(BINARY)_$(VERSION)_$${goos}_$${goarch}.tar.gz -C build/$${goos}_$${goarch} .; \
		fi; \
	done
	@cd dist && sha256sum * > checksums.txt
	@ls -lh dist

test:
	./bin/$(BINARY) fek.txt

install: build
	install -m 0755 ./bin/$(BINARY) $(HOME)/.local/bin/$(BINARY)

clean:
	rm -rf bin build dist

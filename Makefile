BINARY  := kat
VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)
COMMIT  := $(shell git rev-parse --short HEAD 2>/dev/null || echo none)
DATE    := $(shell date -u +%Y-%m-%dT%H:%M:%SZ)
LDFLAGS := -s -w -X main.version=$(VERSION) -X main.commit=$(COMMIT) -X main.date=$(DATE)

PLATFORMS := linux/amd64 linux/arm64 darwin/amd64 darwin/arm64 windows/amd64 windows/arm64

.PHONY: dev build build-all test install clean pushtag patch minor major

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

# bump the latest semver tag and push it, which triggers the release workflow:
#   make pushtag patch|minor|major     (or: make pushtag BUMP=patch)
#   ALLOW_DIRTY=1  tag even with a dirty working tree
#   YES=1          skip the confirmation prompt
BUMP ?= $(firstword $(filter patch minor major,$(MAKECMDGOALS)))

pushtag:
	@bump="$(BUMP)"; \
	if [ -z "$$bump" ]; then \
		echo "usage: make pushtag patch|minor|major"; exit 1; \
	fi; \
	if [ -n "$$(git status --porcelain)" ] && [ -z "$(ALLOW_DIRTY)" ]; then \
		echo "error: working tree is dirty; commit or stash first (ALLOW_DIRTY=1 to override)"; exit 1; \
	fi; \
	upstream="$$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || true)"; \
	if [ -n "$$upstream" ] && [ -n "$$(git rev-list "$$upstream"..HEAD)" ]; then \
		echo "error: HEAD has commits not pushed to $$upstream; run 'git push' first"; exit 1; \
	fi; \
	git fetch --tags --quiet origin 2>/dev/null || true; \
	latest="$$(git tag -l 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname | head -n1)"; \
	[ -n "$$latest" ] || latest="v0.0.0"; \
	echo "$$latest" | grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+$$' || { echo "error: latest tag $$latest is not plain semver"; exit 1; }; \
	ver="$${latest#v}"; \
	maj="$${ver%%.*}"; rest="$${ver#*.}"; min="$${rest%%.*}"; pat="$${rest#*.}"; \
	case "$$bump" in \
		major) maj=$$((maj + 1)); min=0; pat=0 ;; \
		minor) min=$$((min + 1)); pat=0 ;; \
		patch) pat=$$((pat + 1)) ;; \
	esac; \
	next="v$$maj.$$min.$$pat"; \
	if git rev-parse -q --verify "refs/tags/$$next" >/dev/null; then \
		echo "error: tag $$next already exists"; exit 1; \
	fi; \
	echo "$$latest -> $$next ($$bump) at $$(git rev-parse --short HEAD) on $$(git rev-parse --abbrev-ref HEAD)"; \
	if [ -z "$(YES)" ]; then \
		printf "push tag %s to origin? [y/N] " "$$next"; \
		read -r reply 2>/dev/null < /dev/tty || reply=""; \
		case "$$reply" in y|Y|yes|YES) ;; *) echo "aborted"; exit 1 ;; esac; \
	fi; \
	git tag -a "$$next" -m "$$next"; \
	git push origin "$$next"; \
	echo "pushed $$next"; \
	url="$$(git remote get-url origin 2>/dev/null | sed -E 's#^git@github\.com:#https://github.com/#; s#\.git$$##')"; \
	[ -n "$$url" ] && echo "release running: $$url/actions"

# consumed as the argument to pushtag
patch minor major:
	@:

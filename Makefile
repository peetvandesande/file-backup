# Makefile for building/pushing file-backup images (Option A: build from repo root)

# ---- Config (override via: make push-all DOCKER_REPO=ghcr.io/you/file-backup) ----
DOCKER_REPO ?= peetvandesande/file-backup

# Local build (loaded into docker). Must be a single platform.
BUILD_PLATFORM ?= linux/amd64

# Remote push (multi-arch)
PLATFORMS ?= linux/amd64,linux/arm64

# Tags
TAG_ALPINE ?= alpine
TAG_DEBIAN ?= debian

IMAGE_ALPINE := $(DOCKER_REPO):$(TAG_ALPINE)
IMAGE_DEBIAN := $(DOCKER_REPO):$(TAG_DEBIAN)

# Labels
GIT_SHA  := $(shell git rev-parse --short=8 HEAD 2>/dev/null)
BUILD_OPTS := --label org.opencontainers.image.revision=$(GIT_SHA)

# ---- Helpers ----
.PHONY: help
help:
	@echo "Targets:"
	@echo "  buildx-create         Create/select a buildx builder named 'multiarch'"
	@echo "  build-alpine          Build Alpine (local, --load) for BUILD_PLATFORM=$(BUILD_PLATFORM)"
	@echo "  build-debian          Build Debian (local, --load) for BUILD_PLATFORM=$(BUILD_PLATFORM)"
	@echo "  build-all             Build both locally"
	@echo "  push-alpine           Build+push Alpine for PLATFORMS=$(PLATFORMS)"
	@echo "  push-debian           Build+push Debian for PLATFORMS=$(PLATFORMS)"
	@echo "  push-all              Build+push both images"
	@echo ""
	@echo "Vars (override by 'make VAR=value ...'):"
	@echo "  DOCKER_REPO=$(DOCKER_REPO)"
	@echo "  BUILD_PLATFORM=$(BUILD_PLATFORM)"
	@echo "  PLATFORMS=$(PLATFORMS)"
	@echo "  TAG_ALPINE=$(TAG_ALPINE)  TAG_DEBIAN=$(TAG_DEBIAN)"

.PHONY: buildx-create
buildx-create:
	@if ! docker buildx inspect multiarch >/dev/null 2>&1; then \
	  docker buildx create --name multiarch --use >/dev/null; \
	  echo "Created and selected buildx builder 'multiarch'"; \
	else \
	  docker buildx use multiarch >/dev/null; \
	  echo "Using existing buildx builder 'multiarch'"; \
	fi

# ---- Local builds (single-arch, loaded into docker) ----
.PHONY: build-alpine
build-alpine: buildx-create
	docker buildx build \
	  --builder multiarch \
	  --platform $(BUILD_PLATFORM) \
	  --load \
	  $(BUILD_OPTS) \
	  -t $(IMAGE_ALPINE) \
	  -f alpine/Dockerfile \
	  .

.PHONY: build-debian
build-debian: buildx-create
	docker buildx build \
	  --builder multiarch \
	  --platform $(BUILD_PLATFORM) \
	  --load \
	  $(BUILD_OPTS) \
	  -t $(IMAGE_DEBIAN) \
	  -f debian/Dockerfile \
	  .

.PHONY: build-all
build-all: build-alpine build-debian

# ---- Build + Push (multi-arch) ----
.PHONY: push-alpine
push-alpine: buildx-create
	docker buildx build \
	  --builder multiarch \
	  --platform $(PLATFORMS) \
	  --push \
	  $(BUILD_OPTS) \
	  -t $(IMAGE_ALPINE) \
	  -f alpine/Dockerfile \
	  .

.PHONY: push-debian
push-debian: buildx-create
	docker buildx build \
	  --builder multiarch \
	  --platform $(PLATFORMS) \
	  --push \
	  $(BUILD_OPTS) \
	  -t $(IMAGE_DEBIAN) \
	  -f debian/Dockerfile \
	  .

.PHONY: push-all
push-all: push-alpine push-debian


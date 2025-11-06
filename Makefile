# Makefile for building/pushing the single Alpine image from repo root

# ---- Registry / Image -------------------------------------------------------
DOCKER_REPO ?= peetvandesande/file-backup   # override to ghcr.io/<owner>/<repo> if you prefer GHCR
VARIANT      ?= alpine                       # image flavour suffix (kept from your original)

# ---- Build platforms --------------------------------------------------------
BUILD_PLATFORM ?= linux/amd64               # local load
PLATFORMS      ?= linux/amd64,linux/arm64   # remote multi-arch push

# ---- Git metadata -----------------------------------------------------------
BRANCH     := $(shell git rev-parse --abbrev-ref HEAD 2>/dev/null)
GIT_SHA    := $(shell git rev-parse --short=8 HEAD 2>/dev/null)
# Prefer the most recent tag; fall back to empty if no tags exist
GIT_TAG    := $(shell git describe --tags --abbrev=0 2>/dev/null)
# A “rich” ref for labels/debugging (tag-or-commit, with dirty if any)
GIT_REF    := $(shell git describe --tags --always --dirty --abbrev=8 2>/dev/null)

# ---- Version/tag logic ------------------------------------------------------
# You can hard-override TAGS from the CLI: `make push TAGS="dev dev-$(VARIANT)"`
ifeq ($(origin TAGS), undefined)
  ifeq ($(BRANCH),dev)
    TAGS := dev dev-$(VARIANT) dev-$(GIT_SHA) dev-$(VARIANT)-$(GIT_SHA)
  else ifeq ($(BRANCH),main)
    ifneq ($(strip $(GIT_TAG)),)
      TAGS := latest $(VARIANT) $(GIT_TAG) $(GIT_TAG)-$(VARIANT) $(GIT_SHA)
    else
      TAGS := latest $(VARIANT) $(GIT_SHA)
    endif
  else
    # feature branches (no accidental :latest here)
    TAGS := $(BRANCH) $(BRANCH)-$(VARIANT) $(BRANCH)-$(GIT_SHA)
  endif
endif

# Create repeated -t flags from TAGS
TFLAGS := $(foreach t,$(TAGS),-t $(DOCKER_REPO):$(t))

# ---- OCI labels -------------------------------------------------------------
REPO_URL  := $(shell git config --get remote.origin.url 2>/dev/null)
BUILD_DATE:= $(shell date -u +%Y-%m-%dT%H:%M:%SZ)

BUILD_OPTS ?= \
  --label org.opencontainers.image.title="file-backup" \
  --label org.opencontainers.image.description="Simple backup/restore utility (Alpine)" \
  --label org.opencontainers.image.url="$(REPO_URL)" \
  --label org.opencontainers.image.source="$(REPO_URL)" \
  --label org.opencontainers.image.revision="$(GIT_SHA)" \
  --label org.opencontainers.image.version="$(GIT_TAG)" \
  --label org.opencontainers.image.created="$(BUILD_DATE)"

# ---- buildx helper ----------------------------------------------------------
.PHONY: buildx-create
buildx-create:
	@docker buildx inspect multiarch >/dev/null 2>&1 || docker buildx create --name multiarch --use
	@docker buildx use multiarch >/dev/null 2>&1 || true

# ---- Local build (loads into docker engine) ---------------------------------
.PHONY: build
build: buildx-create
	docker buildx build \
	  --builder multiarch \
	  --platform $(BUILD_PLATFORM) \
	  --load \
	  $(BUILD_OPTS) \
	  $(TFLAGS) \
	  -f alpine/Dockerfile \
	  .

# ---- Multi-arch push --------------------------------------------------------
.PHONY: push
push: buildx-create
	docker buildx build \
	  --builder multiarch \
	  --platform $(PLATFORMS) \
	  --push \
	  $(BUILD_OPTS) \
	  $(TFLAGS) \
	  -f alpine/Dockerfile \
	  .

# ---- Utilities --------------------------------------------------------------
.PHONY: print
print:
	@echo "Repo:     $(DOCKER_REPO)"
	@echo "Branch:   $(BRANCH)"
	@echo "Git tag:  $(GIT_TAG)"
	@echo "Git ref:  $(GIT_REF)"
	@echo "Git sha:  $(GIT_SHA)"
	@echo "Variant:  $(VARIANT)"
	@echo "Tags:     $(TAGS)"
	@echo "Platforms(build): $(BUILD_PLATFORM)"
	@echo "Platforms(push):  $(PLATFORMS)"

.PHONY: tag-list
tag-list:
	@$(foreach t,$(TAGS),echo $(DOCKER_REPO):$(t);)


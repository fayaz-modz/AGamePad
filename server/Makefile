# AGamePad UHID Server Makefile
# Builds for Linux (native) and Android (using NDK)

# Project settings
PROJECT_NAME = uhid_server
SOURCE_FILE = uhid_server.go
OUTPUT_DIR = build

# Android NDK settings
ANDROID_NDK_HOME ?= $(HOME)/Android/Sdk/ndk/27.2.12479018
ANDROID_API_LEVEL = 28
ANDROID_ARCH = arm64

# Derived Android settings
ifeq ($(ANDROID_ARCH),arm64)
    ANDROID_TOOLCHAIN = aarch64-linux-android
    GOARCH = arm64
else ifeq ($(ANDROID_ARCH),arm)
    ANDROID_TOOLCHAIN = armv7a-linux-androideabi
    GOARCH = arm
    GOARM = 7
else ifeq ($(ANDROID_ARCH),x86_64)
    ANDROID_TOOLCHAIN = x86_64-linux-android
    GOARCH = amd64
else ifeq ($(ANDROID_ARCH),x86)
    ANDROID_TOOLCHAIN = i686-linux-android
    GOARCH = 386
endif

# Android toolchain paths
ANDROID_CC = $(ANDROID_NDK_HOME)/toolchains/llvm/prebuilt/linux-x86_64/bin/$(ANDROID_TOOLCHAIN)$(ANDROID_API_LEVEL)-clang
ANDROID_CXX = $(ANDROID_NDK_HOME)/toolchains/llvm/prebuilt/linux-x86_64/bin/$(ANDROID_TOOLCHAIN)$(ANDROID_API_LEVEL)-clang++

# Colors for output
COLOR_RESET = \033[0m
COLOR_GREEN = \033[32m
COLOR_YELLOW = \033[33m
COLOR_CYAN = \033[36m

.PHONY: all linux android android-arm64 android-arm android-x86_64 android-x86 clean install help

# Default target
all: linux

# Build for native Linux
linux:
	@echo "$(COLOR_CYAN)🔨 Building for Linux (native)...$(COLOR_RESET)"
	@mkdir -p $(OUTPUT_DIR)
	go build -o $(OUTPUT_DIR)/$(PROJECT_NAME)-linux $(SOURCE_FILE)
	@echo "$(COLOR_GREEN)✅ Built: $(OUTPUT_DIR)/$(PROJECT_NAME)-linux$(COLOR_RESET)"

# Build for Android (default to arm64)
android: android-arm64

# Build for Android ARM64
android-arm64:
	@echo "$(COLOR_CYAN)🔨 Building for Android ARM64...$(COLOR_RESET)"
	@$(MAKE) _android_build ANDROID_ARCH=arm64

# Build for Android ARM (32-bit)
android-arm:
	@echo "$(COLOR_CYAN)🔨 Building for Android ARM (32-bit)...$(COLOR_RESET)"
	@$(MAKE) _android_build ANDROID_ARCH=arm

# Build for Android x86_64
android-x86_64:
	@echo "$(COLOR_CYAN)🔨 Building for Android x86_64...$(COLOR_RESET)"
	@$(MAKE) _android_build ANDROID_ARCH=x86_64

# Build for Android x86 (32-bit)
android-x86:
	@echo "$(COLOR_CYAN)🔨 Building for Android x86 (32-bit)...$(COLOR_RESET)"
	@$(MAKE) _android_build ANDROID_ARCH=x86

# Internal target for Android builds
_android_build:
	@if [ -z "$(ANDROID_NDK_HOME)" ]; then \
		echo "$(COLOR_YELLOW)⚠️  ANDROID_NDK_HOME not set!$(COLOR_RESET)"; \
		echo "$(COLOR_YELLOW)   Please set it to your NDK path, e.g.:$(COLOR_RESET)"; \
		echo "$(COLOR_YELLOW)   export ANDROID_NDK_HOME=~/Android/Sdk/ndk/27.2.12479018$(COLOR_RESET)"; \
		exit 1; \
	fi
	@if [ ! -d "$(ANDROID_NDK_HOME)" ]; then \
		echo "$(COLOR_YELLOW)⚠️  NDK not found at: $(ANDROID_NDK_HOME)$(COLOR_RESET)"; \
		exit 1; \
	fi
	@if [ ! -f "$(ANDROID_CC)" ]; then \
		echo "$(COLOR_YELLOW)⚠️  Compiler not found: $(ANDROID_CC)$(COLOR_RESET)"; \
		echo "$(COLOR_YELLOW)   Check your NDK installation and API level$(COLOR_RESET)"; \
		exit 1; \
	fi
	@echo "$(COLOR_CYAN)   Using NDK: $(ANDROID_NDK_HOME)$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)   Target: $(ANDROID_TOOLCHAIN) (API $(ANDROID_API_LEVEL))$(COLOR_RESET)"
	@mkdir -p $(OUTPUT_DIR)
	CGO_ENABLED=1 \
	GOOS=android \
	GOARCH=$(GOARCH) \
	$(if $(GOARM),GOARM=$(GOARM),) \
	CC=$(ANDROID_CC) \
	CXX=$(ANDROID_CXX) \
	go build -o $(OUTPUT_DIR)/$(PROJECT_NAME)-android-$(ANDROID_ARCH) $(SOURCE_FILE)
	@echo "$(COLOR_GREEN)✅ Built: $(OUTPUT_DIR)/$(PROJECT_NAME)-android-$(ANDROID_ARCH)$(COLOR_RESET)"

# Build all Android architectures
android-all: android-arm64 android-arm android-x86_64 android-x86
	@echo "$(COLOR_GREEN)✅ Built all Android architectures$(COLOR_RESET)"

# Install Linux binary to /usr/local/bin
install: linux
	@echo "$(COLOR_CYAN)📦 Installing to /usr/local/bin...$(COLOR_RESET)"
	sudo cp $(OUTPUT_DIR)/$(PROJECT_NAME)-linux /usr/local/bin/$(PROJECT_NAME)
	sudo chmod +x /usr/local/bin/$(PROJECT_NAME)
	@echo "$(COLOR_GREEN)✅ Installed: /usr/local/bin/$(PROJECT_NAME)$(COLOR_RESET)"

# Clean build artifacts
clean:
	@echo "$(COLOR_YELLOW)🗑️  Cleaning build artifacts...$(COLOR_RESET)"
	rm -rf $(OUTPUT_DIR)
	rm -f $(PROJECT_NAME) $(PROJECT_NAME)-*
	@echo "$(COLOR_GREEN)✅ Cleaned$(COLOR_RESET)"

# Show help
help:
	@echo "$(COLOR_CYAN)AGamePad UHID Server - Build System$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_GREEN)Targets:$(COLOR_RESET)"
	@echo "  make                    - Build for native Linux (default)"
	@echo "  make linux              - Build for native Linux"
	@echo "  make android            - Build for Android ARM64 (default)"
	@echo "  make android-arm64      - Build for Android ARM64"
	@echo "  make android-arm        - Build for Android ARM (32-bit)"
	@echo "  make android-x86_64     - Build for Android x86_64"
	@echo "  make android-x86        - Build for Android x86 (32-bit)"
	@echo "  make android-all        - Build for all Android architectures"
	@echo "  make install            - Install Linux binary to /usr/local/bin"
	@echo "  make clean              - Clean build artifacts"
	@echo "  make help               - Show this help"
	@echo ""
	@echo "$(COLOR_GREEN)Environment Variables:$(COLOR_RESET)"
	@echo "  ANDROID_NDK_HOME        - Path to Android NDK (required for Android builds)"
	@echo "                            Default: $(ANDROID_NDK_HOME)"
	@echo "  ANDROID_API_LEVEL       - Android API level (default: $(ANDROID_API_LEVEL))"
	@echo ""
	@echo "$(COLOR_GREEN)Examples:$(COLOR_RESET)"
	@echo "  make linux"
	@echo "  make android-arm64"
	@echo "  ANDROID_NDK_HOME=~/ndk make android"
	@echo "  make android-all"
	@echo ""

# 项目名称
BINARY_NAME=joystick-gpio

# 版本信息，可以通过 make VERSION=1.0.0 来覆盖
VERSION?=$(shell git describe --tags 2>/dev/null || echo "1.0.0")

# Go 构建标志
LDFLAGS=-ldflags="-s -w -X main.Version=$(VERSION)"

# 定义目标平台列表
PLATFORMS=\
	linux/amd64 \
	linux/arm64 \
	linux/arm/v7 \
	darwin/amd64 \
	darwin/arm64 \
	windows/amd64 \
	windows/arm64

# 将平台列表转换为 OS_ARCH 格式
PLATFORMS_SPLIT=$(subst /, ,$(platform))
OS=$(word 1, $(PLATFORMS_SPLIT))
ARCH=$(word 2, $(PLATFORMS_SPLIT))
ARM_VERSION=$(word 3, $(PLATFORMS_SPLIT))

# 输出目录
DIST_DIR=dist

# 默认目标：编译当前平台
all: build

# 编译当前平台
build:
	go build $(LDFLAGS) -o $(BINARY_NAME) main.go

# 清理构建文件
clean:
	rm -rf $(BINARY_NAME) $(DIST_DIR)

# 安装依赖（如果有的话）
deps:
	go mod download

# 编译所有平台
build-all: deps
	@echo "> 正在为所有平台构建版本: $(VERSION)"
	@$(foreach platform, $(PLATFORMS), \
		$(call build-platform,$(platform)) \
	)

# 定义构建单个平台的函数
define build-platform
	@echo "> 构建 $(1)"
	@mkdir -p $(DIST_DIR)/$(1);
	@if [ "$(word 3, $(subst /, ,$(1)))" = "v7" ]; then \
		GOOS=$(OS) GOARCH=$(ARCH) GOARM=7 go build $(LDFLAGS) -o $(DIST_DIR)/$(1)/$(BINARY_NAME)$(if $(findstring windows,$(OS)),.exe,) main.go; \
	else \
		GOOS=$(OS) GOARCH=$(ARCH) go build $(LDFLAGS) -o $(DIST_DIR)/$(1)/$(BINARY_NAME)$(if $(findstring windows,$(OS)),.exe,) main.go; \
	fi
endef

# 为所有平台构建并创建压缩包
release: clean build-all
	@echo "> 创建发布压缩包"
	@$(foreach platform, $(PLATFORMS), \
		$(call create-archive,$(platform)) \
	)
	@echo "> 完成！压缩包位于 $(DIST_DIR)/ 目录"

# 定义创建压缩包的函数
define create-archive
	@echo "> 打包 $(1)"
	@cd $(DIST_DIR)/$(1) && \
	if [ "$(word 1, $(subst /, ,$(1)))" = "windows" ]; then \
		zip -r ../$(BINARY_NAME)-$(1)-$(VERSION).zip .; \
	else \
		tar -czf ../$(BINARY_NAME)-$(1)-$(VERSION).tar.gz .; \
	fi
endef

# 快速编译 Linux ARM64（树莓派等）
linux-arm64:
	GOOS=linux GOARCH=arm64 go build $(LDFLAGS) -o $(BINARY_NAME)-linux-arm64 main.go

# 快速编译 macOS ARM64（Apple Silicon）
darwin-arm64:
	GOOS=darwin GOARCH=arm64 go build $(LDFLAGS) -o $(BINARY_NAME)-darwin-arm64 main.go

# 显示帮助信息
help:
	@echo "Joystick-GPIO 构建系统"
	@echo ""
	@echo "使用方法:"
	@echo "  make all          编译当前平台 (默认)"
	@echo "  make build        编译当前平台"
	@echo "  make build-all    编译所有支持的平台"
	@echo "  make release      编译所有平台并创建压缩包"
	@echo "  make clean        清理构建文件"
	@echo "  make linux-arm64  快速编译 Linux ARM64 版本"
	@echo "  make darwin-arm64 快速编译 macOS ARM64 版本"
	@echo "  make help         显示此帮助信息"
	@echo ""
	@echo "当前版本: $(VERSION)"
	@echo "支持的平台: $(PLATFORMS)"

.PHONY: all build clean deps build-all release linux-arm64 darwin-arm64 help
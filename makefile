# Makefile for joystick-gpio multi-platform build

# 项目名称
BINARY_NAME=joystick-gpio

# 版本信息
VERSION?=$(shell git describe --tags 2>/dev/null || echo "v0.0.0-unknown")

# Go 构建标志
LDFLAGS=-ldflags="-s -w -X main.Version=$(VERSION)"

# 定义目标平台列表
PLATFORMS=linux/amd64 linux/arm64 linux/arm/7 darwin/amd64 darwin/arm64 windows/amd64 windows/arm64

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

# 安装依赖
deps:
	go mod download

# 编译所有平台
build-all: deps
	@echo "> 正在为所有平台构建版本: $(VERSION)"
	@for platform in $(PLATFORMS); do \
		echo "> 构建 $$platform"; \
		os=$$(echo $$platform | cut -d'/' -f1); \
		arch=$$(echo $$platform | cut -d'/' -f2); \
		arm_version=$$(echo $$platform | cut -d'/' -f3); \
		mkdir -p $(DIST_DIR)/$$platform; \
		\
		if [ "$$arm_version" = "7" ]; then \
			GOOS=$$os GOARCH=$$arch GOARM=7 go build $(LDFLAGS) -o $(DIST_DIR)/$$platform/$(BINARY_NAME) main.go; \
		else \
			if [ "$$os" = "windows" ]; then \
				GOOS=$$os GOARCH=$$arch go build $(LDFLAGS) -o $(DIST_DIR)/$$platform/$(BINARY_NAME).exe main.go; \
			else \
				GOOS=$$os GOARCH=$$arch go build $(LDFLAGS) -o $(DIST_DIR)/$$platform/$(BINARY_NAME) main.go; \
			fi \
		fi \
	done

# 为所有平台构建并创建压缩包
release: clean build-all
	@echo "> 创建发布压缩包"
	@for platform in $(PLATFORMS); do \
		echo "> 打包 $$platform"; \
		os=$$(echo $$platform | cut -d'/' -f1); \
		cd $(DIST_DIR)/$$platform; \
		if [ "$$os" = "windows" ]; then \
			zip -r ../$(BINARY_NAME)-$$platform-$(VERSION).zip .; \
		else \
			tar -czf ../$(BINARY_NAME)-$$platform-$(VERSION).tar.gz .; \
		fi; \
		cd - > /dev/null; \
	done
	@echo "> 完成！压缩包位于 $(DIST_DIR)/ 目录"

# 快速编译 Linux ARM64
linux-arm64:
	GOOS=linux GOARCH=arm64 go build $(LDFLAGS) -o $(BINARY_NAME)-linux-arm64 main.go

# 快速编译 macOS ARM64
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
# GPIO Joystick Controller

一个使用Go语言编写的GPIO摇杆控制器，用于读取物理摇杆设备的输入事件。

## 项目介绍

这个项目允许您将物理摇杆设备（如游戏手柄的方向键）连接到支持GPIO的设备（如树莓派），并通过Go程序读取摇杆的输入事件。它可以检测摇杆的按下和释放事件，并提供时间戳和方向信息。

## 功能特性

- 实时监听GPIO引脚状态变化
- 支持多个方向的摇杆输入（上、下、左、右）
- 提供精确的时间戳
- 优雅的程序关闭机制
- 跨平台支持（Linux、macOS、Windows）

## 硬件要求

- 支持GPIO的设备（如树莓派）
- 物理摇杆设备或按钮
- 连接线

## 安装与使用

### 克隆项目

```bash
go get github.com/guchengod/joystick-gpio
```

### 构建项目

使用make命令构建项目：

```bash
# 构建当前平台版本
make build

# 构建所有支持的平台
make build-all

# 构建发布版本并打包
make release
```

或者直接使用Go命令构建：

```bash
go build -o joystick-gpio main.go
```

### 运行程序

```bash
sudo ./joystick-gpio
```

注意：由于需要访问GPIO接口，通常需要root权限运行。

## 配置GPIO引脚

在`main.go`中配置您的GPIO引脚：

```go
pins := []int{96, 107, 106, 62}

pinNames := map[int]string{
    96:  "Up",
    107: "Down",
    106: "Left",
    62:  "Right",
}
```

请根据您的实际硬件连接修改这些引脚编号。

## 事件输出

程序运行后会输出类似以下格式的事件信息：

```
检测到事件 -> 时间: 14:30:25.123, 方向: Up (96), 状态: Pressed
检测到事件 -> 时间: 14:30:25.234, 方向: Up (96), 状态: Released
```

## 项目结构

```
.
├── main.go              # 主程序入口
├── makefile             # 构建配置
├── joystick/
│   └── joystick.go      # 摇杆控制核心逻辑
```

## API使用

如果您想在其他项目中使用摇杆功能，可以导入joystick包：

```go
import "github.com/guchengod/joystick-gpio/joystick"

// 创建摇杆实例
pins := []int{96, 107, 106, 62}
pinNames := map[int]string{
    96:  "Up",
    107: "Down",
    106: "Left",
    62:  "Right",
}

joy, err := joystick.NewJoystick(pins, pinNames)
if err != nil {
    log.Fatal(err)
}
defer joy.Close()

// 监听事件
for event := range joy.Events() {
    fmt.Printf("Event: %s %s (%d) at %s\n", 
        event.Direction, 
        event.State, 
        event.Pin, 
        event.Timestamp.Format("15:04:05.000"))
}
```

## Makefile 命令

项目包含一个功能完整的Makefile，支持多种构建选项：

```bash
make help        # 显示帮助信息
make build       # 编译当前平台版本
make build-all   # 编译所有支持的平台
make release     # 编译所有平台并创建压缩包
make clean       # 清理构建文件
make linux-arm64 # 快速编译 Linux ARM64 版本
make darwin-arm64 # 快速编译 macOS ARM64 版本
```

## 工作原理

1. 程序启动时导出指定的GPIO引脚并设置为输入模式
2. 在后台goroutine中以20ms间隔轮询各引脚状态
3. 当检测到状态变化时（0→1或1→0），生成事件并发送到事件通道
4. 主程序从事件通道接收并处理事件
5. 程序通过信号处理器优雅地处理Ctrl+C退出

## 许可证

本项目采用 MIT 许可证。详情请见 [LICENSE](LICENSE) 文件。

## 贡献

欢迎提交Issue和Pull Request来改进这个项目。
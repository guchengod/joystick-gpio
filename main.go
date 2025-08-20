package main

import (
	"fmt"
	"log"
	"os"
	"os/signal"
	"syscall"
	// 导入我们自己的joystick库，路径根据模块名调整
	"github.com/guchengod/joystick-gpio/joystick"
)

func main() {
	fmt.Println("--- Go 摇杆事件读取程序 ---")

	// 定义我们最终确定的GPIO引脚
	pins := []int{96, 107, 106, 62}

	// 为每个引脚定义一个友好的名字
	pinNames := map[int]string{
		96:  "Up",
		107: "Down",
		106: "Left",
		62:  "Right",
	}

	// 使用库来创建一个新的摇杆实例
	joy, err := joystick.NewJoystick(pins, pinNames)
	if err != nil {
		log.Fatalf("初始化摇杆失败: %v", err)
	}
	// 确保在程序退出时，能正确关闭和清理GPIO资源
	defer joy.Close()

	fmt.Println("摇杆初始化成功！正在监听事件... 按 Ctrl+C 退出。")

	// 设置一个信号处理器，用于优雅地关闭程序
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)

	// 主循环，处理事件或等待退出信号
	for {
		select {
		case event := <-joy.Events():
			// 从库的事件通道接收到一个事件
			fmt.Printf("检测到事件 -> 时间: %s, 方向: %s (%d), 状态: %s\n",
				event.Timestamp.Format("15:04:05.000"),
				event.Direction,
				event.Pin,
				event.State)
		case <-sigChan:
			// 接收到退出信号
			fmt.Println("\n收到退出信号，程序即将关闭。")
			return
		}
	}
}

package joystick

import (
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"
)

const gpioPath = "/sys/class/gpio"

// Event 代表一个摇杆事件
type Event struct {
	Timestamp time.Time // 事件发生的时间
	Pin       int       // 触发事件的GPIO全局编号
	Direction string    // 用户定义的引脚方向名，如 "Up", "Down"
	State     string    // "Pressed" (按下) 或 "Released" (松开)
}

// Joystick 代表一个摇杆设备
type Joystick struct {
	pins       []int
	pinNames   map[int]string
	valueFiles map[int]*os.File
	eventChan  chan Event
	stopChan   chan struct{}
	wg         sync.WaitGroup
}

// NewJoystick 初始化一个新的摇杆。
// pins: 需要监控的GPIO全局编号列表。
// pinNames: 一个从GPIO编号到方向名的映射，例如 map[int]string{96: "Up", 107: "Down"}。
func NewJoystick(pins []int, pinNames map[int]string) (*Joystick, error) {
	joy := &Joystick{
		pins:       pins,
		pinNames:   pinNames,
		valueFiles: make(map[int]*os.File),
		eventChan:  make(chan Event, 10), // 带缓冲的通道
		stopChan:   make(chan struct{}),
	}

	// 初始化并配置所有GPIO引脚
	for _, pin := range pins {
		if err := joy.exportGPIO(pin); err != nil {
			// 如果出错，清理已导出的引脚
			joy.cleanup()
			return nil, fmt.Errorf("导出GPIO %d 失败: %v", pin, err)
		}
		if err := joy.setDirection(pin, "in"); err != nil {
			joy.cleanup()
			return nil, fmt.Errorf("设置GPIO %d 方向失败: %v", pin, err)
		}
		// 提前打开文件句柄
		path := filepath.Join(gpioPath, fmt.Sprintf("gpio%d", pin), "value")
		file, err := os.Open(path)
		if err != nil {
			joy.cleanup()
			return nil, fmt.Errorf("无法打开 value 文件 (pin %d): %v", pin, err)
		}
		joy.valueFiles[pin] = file
	}

	// 启动一个后台goroutine来监控引脚状态变化
	joy.wg.Add(1)
	go joy.monitor()

	return joy, nil
}

// Events 返回一个只读的事件通道，用于接收摇杆事件。
func (j *Joystick) Events() <-chan Event {
	return j.eventChan
}

// Close 会停止监控并清理所有GPIO资源。
func (j *Joystick) Close() error {
	close(j.stopChan) // 发送停止信号
	j.wg.Wait()       // 等待监控goroutine结束
	j.cleanup()
	close(j.eventChan)
	return nil
}

// monitor 是在后台运行的核心循环，用于检测状态变化。
func (j *Joystick) monitor() {
	defer j.wg.Done()

	lastStates := make(map[int]string)
	buffer := make([]byte, 1)

	// 先读取一次初始状态
	for _, pin := range j.pins {
		j.valueFiles[pin].Seek(0, 0)
		j.valueFiles[pin].Read(buffer)
		lastStates[pin] = strings.TrimSpace(string(buffer))
	}

	ticker := time.NewTicker(20 * time.Millisecond) // 每20毫秒检测一次
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			for _, pin := range j.pins {
				j.valueFiles[pin].Seek(0, 0)
				_, err := j.valueFiles[pin].Read(buffer)
				if err != nil {
					continue // 暂时忽略读取错误
				}
				currentState := strings.TrimSpace(string(buffer))

				if currentState != lastStates[pin] {
					// 状态发生变化，创建并发送事件
					event := Event{
						Timestamp: time.Now(),
						Pin:       pin,
						Direction: j.pinNames[pin],
					}
					if currentState == "0" {
						event.State = "Pressed"
					} else {
						event.State = "Released"
					}
					j.eventChan <- event
					lastStates[pin] = currentState // 更新状态
				}
			}
		case <-j.stopChan:
			return // 收到停止信号，退出循环
		}
	}
}

// cleanup 负责清理所有导出的引脚和文件句柄。
func (j *Joystick) cleanup() {
	for _, file := range j.valueFiles {
		file.Close()
	}
	for _, pin := range j.pins {
		unexportGPIO(pin)
	}
}

// --- 以下是未导出的辅助函数 ---

func (j *Joystick) exportGPIO(pin int) error {
	pinStr := strconv.Itoa(pin)
	if _, err := os.Stat(filepath.Join(gpioPath, "gpio"+pinStr)); err == nil {
		return nil
	}
	exportFile, err := os.OpenFile(filepath.Join(gpioPath, "export"), os.O_WRONLY, 0644)
	if err != nil {
		return err
	}
	defer exportFile.Close()
	_, err = exportFile.WriteString(pinStr)
	time.Sleep(100 * time.Millisecond)
	return err
}

func unexportGPIO(pin int) error {
	unexportFile, err := os.OpenFile(filepath.Join(gpioPath, "unexport"), os.O_WRONLY, 0644)
	if err != nil {
		return err
	}
	defer unexportFile.Close()
	_, err = unexportFile.WriteString(strconv.Itoa(pin))
	return err
}

func (j *Joystick) setDirection(pin int, direction string) error {
	path := filepath.Join(gpioPath, fmt.Sprintf("gpio%d", pin), "direction")
	directionFile, err := os.OpenFile(path, os.O_WRONLY, 0644)
	if err != nil {
		return err
	}
	defer directionFile.Close()
	_, err = directionFile.WriteString(direction)
	return err
}

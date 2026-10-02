# MATLAB DMI 演示启动说明

## 1. 当前可启动程序位置

当前可以启动的 MATLAB 原型程序位于：

```text
C:\Users\59693\Documents\Codex\2026-07-12\c-users-59693-desktop-ro-md
```

主要文件：

```text
C:\Users\59693\Documents\Codex\2026-07-12\c-users-59693-desktop-ro-md\RemoteDMIApp.m
C:\Users\59693\Documents\Codex\2026-07-12\c-users-59693-desktop-ro-md\MinimalTrainPlant.m
C:\Users\59693\Documents\Codex\2026-07-12\c-users-59693-desktop-ro-md\launch_RemoteDMIApp.m
```

其中：

- `RemoteDMIApp.m`：DMI/HMI 主界面和演示状态机。
- `MinimalTrainPlant.m`：最小列车动力学模型，负责速度、位置、加速度变化。
- `launch_RemoteDMIApp.m`：推荐启动脚本，负责切换到正确目录、清理旧 `outputs` 路径影响并启动 App。

注意：不要使用下面这个早期输出目录中的版本作为主程序：

```text
C:\Users\59693\Documents\Codex\2026-07-12\c-users-59693-desktop-ro-md\outputs\RemoteDMIApp.m
```

该版本属于早期静态/半静态版本，容易造成界面或按钮行为与当前说明不一致。

## 2. MATLAB 中的启动方式

打开 MATLAB 后，在命令行执行：

```matlab
run('C:\Users\59693\Documents\Codex\2026-07-12\c-users-59693-desktop-ro-md\launch_RemoteDMIApp.m')
```

启动时应看到 MATLAB 输出类似：

```text
Loading RemoteDMIApp from:
C:\Users\59693\Documents\Codex\2026-07-12\c-users-59693-desktop-ro-md\RemoteDMIApp.m
```

如果 `which RemoteDMIApp` 指向 `outputs\RemoteDMIApp.m`，说明 MATLAB 路径加载了旧版本，需要先移除旧路径或重新运行启动脚本。

## 3. 演示操作方式

界面打开后，右侧功能键可用于演示：

- `启动`：开始远程调车动态演示；再次点击会暂停。
- `模式`：切换到调车相关显示。
- `数据`：刷新并输出当前速度、区段和目标距离信息。
- `其他`：切换机控/人控显示。
- `缓解`：演示制动缓解状态。
- `警惕`：触发告警/制动提示演示。

当前演示流程为早期抽象版本：

```text
故障停车
-> 远程接管
-> 请求进路
-> 道岔锁闭
-> 低速调车
-> 通过道岔
-> 目标股道
-> 换线完成
```

## 4. 当前程序与最新汇报主线的差距

当前可启动程序还没有完全替换为最新的 `C17G1 -> 咽喉区 -> XW3G` 主线。主要差距包括：

1. 代码中仍使用 `A股道`、`B股道`、`S1道岔` 等早期抽象名称。
2. 线路图仍是简化示意，不是当前高亮图对应的 `C17G1/THROAT_1/THROAT_2/XW3G` 拓扑。
3. 进路检查是定时演示流程，不是真实检查目标区段、敌对进路和道岔条件。
4. 道岔状态只有文字显示，还没有具体道岔编号、定位/反位组合。
5. 调车信号机还没有替换为 `XC17`、`SCF17`、`XCF17` 或其他真实对象。

因此，当前 MATLAB 程序适合展示“DMI 界面、速度/距离联动、远程调车流程雏形”；最新汇报材料则用于说明下一步如何把它升级为 `C17G1 -> XW3G` 候选路径仿真。

## 5. 后续建议落点

下一步应优先把当前可启动版本迁移或复制到：

```text
C:\Users\59693\Desktop\设计院\实践项目\RemoteDMIPrototype
```

然后基于该目录继续开发：

1. 新增结构化拓扑数据。
2. 将 `A股道/道岔区/B股道` 替换为 `C17G1/THROAT_1/THROAT_2/XW3G`。
3. 重写线路显示区域，让列车沿候选路径移动。
4. 增加调车进路检查项、道岔锁闭、信号开放和进路解锁的独立状态。

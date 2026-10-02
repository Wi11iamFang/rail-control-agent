# RemoteDMIPrototype

远程调车 DMI/RO 仿真原型的稳定工程目录。

## 当前基线

本目录迁入了早期可启动 MATLAB 原型：

- `src/RemoteDMIApp.m`：车载 DMI 主界面原型
- `src/MinimalTrainPlant.m`：最小列车动力学模型
- `launch/launch_RemoteDMIApp.m`：启动脚本

当前代码仍以展示型原型为定位，不代表安全级 ATP、联锁或正式工程产品。

## 当前开发方向

第一阶段围绕局部线路图建立最小双端联动闭环：

```text
局部拓扑 → 办理调车进路 → 道岔转换并锁闭 → 调车信号开放
→ 车载 DMI 同步 → 列车沿进路运行 → 区段占用转移
→ 目标停车 → 进路解锁
```

局部图暂以 `C21G1~C24G1`、`XC21~XC24`、咽喉区和 `D20/D16` 方向为参考，真实进路表、道岔编号和轨道电路编号确认前，临时对象必须明确标注为候选或占位对象。

## 目录约定

```text
src/       MATLAB 主代码
launch/    启动脚本
config/    局部拓扑与演示配置
 tests/    状态机、动力学和接口测试
docs/      工程说明和验证记录
```

## MATLAB 启动

在 MATLAB 中运行：

```matlab
run('D:\CREC_code\实践项目\RemoteDMIPrototype\launch\launch_RemoteDMIApp.m')
```

启动时应确认 MATLAB 加载的是本目录 `src/` 下的主程序，不要使用旧 `outputs/RemoteDMIApp.m`。

## Git 分支

- `master`：稳定、可汇报版本
- `develop/remote-dmi`：项目主开发线
- `feature/local-topology`：当前局部拓扑和首条候选进路实验线

不使用 Git worktree；所有分支在同一个 `D:\CREC_code` 工作目录中切换。

## 外部参考软件

车务操作仿真软件和授权/运行库不纳入仓库。参考资料留在 `实践项目/`，外部软件继续使用本机路径。

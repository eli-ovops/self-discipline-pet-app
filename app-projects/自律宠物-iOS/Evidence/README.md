# P0 证据索引

本目录只保存小型文本索引。大型录屏不进入项目目录或 Git；具体外部证据路径需用户另行确认。

每条真机证据至少记录：测试编号、日期、设备、iOS、Xcode、build、权限状态、前置状态、步骤、命令时刻、首次观察时刻、实际结果、PASS/BLOCKED/FAIL、录屏文件名和已知限制。

Simulator、Build Success、本地命令回执和截图均不能证明 Family Controls 核心闭环。

当前本地证据分两类：

- `P0-A-simulator-launch-2026-08-10.png`：iOS 27.0 iPhone 17 Simulator 启动截图。只证明 P0 壳层可渲染，不证明 Family Controls、Shield、Extension 跨进程可见性、返回主 App、解除或重锁。
- `FriendMVP/2026-08-11-visual/`：朋友测试 MVP 的猫/狗、英中双语、浅深色与动态字体截图。只证明对应 build 在 iPhone 17 Simulator 可渲染；空白启动过渡截图不作为证据，最终编号 01–06 为稳定后截图。
- `P0-A-real-device-2026-08-10/`：用户提供并保存在项目内的 iPhone 17 P0-A 真机录屏、截图与崩溃日志。其结论以目录内索引和逐项验收状态为准，不可由 Simulator 截图替代。

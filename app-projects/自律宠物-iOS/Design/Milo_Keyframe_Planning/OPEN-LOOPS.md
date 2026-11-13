# Milo Keyframe Planning — Open Loops

更新时间：2026-08-21  
当前阶段：关键帧规划已完成，等待用户审查；尚未进入图片生成、动画生产或 App 接入。

- [ ] 用户审查 5 组 P0 动作及每组 5 张关键帧，决定通过或指出需要修改的动作。— state: open — owner: 用户 — created: 2026-08-21 — unblock: 用户确认“通过”或给出具体修改意见。
- [ ] 确认是否按建议首先制作 `Goal Notice / Pact`，并以 `P0-02-KF02` 作为第一张实际 image-edit。— state: open — owner: 用户 — created: 2026-08-21 — blocker: 当前只有建议，没有图片生产授权 — unblock: 用户明确确认首组动作和允许开始生图。
- [ ] 在正式生产前标注 Milo 前爪、书本、纸张、铅笔和印章的真实像素接触坐标。— state: blocked — owner: Technical Art — created: 2026-08-21 — blocker: 当前规划只冻结了统一画布、root、baseline 与接触关系，精确接触坐标仍为 `UNKNOWN` — unblock: 首组选定后，基于对应 Approved 原图逐点标注并复核。
- [ ] 首组关键帧生成后，验收 Milo Identity Lock：脸型、头身比、眼距、虎斑、白口鼻、绿色领巾、画风、尺度、相机和 anchor 均不得漂移。— state: blocked — owner: Animation Director / 用户 — created: 2026-08-21 — blocker: 尚未生成任何关键帧 — unblock: 用户授权并完成首组 image-edit 后逐帧验收。
- [ ] 首组通过后，再决定其余 4 组 P0 的生成顺序和是否需要调整关键帧。— state: blocked — owner: 用户 / Animation Director — created: 2026-08-21 — blocker: 首组尚未验证图像模型能否稳定保持 Milo 身份与接触点 — unblock: 首组视觉验收通过。
- [ ] 补间帧、正式动画、Reduce Motion 实现和 App runtime 接入。— state: open — owner: 后续动画与开发任务 — created: 2026-08-21 — defer reason: 明确不属于本轮范围，且必须在关键帧方案与首组资产验收后另行授权。
- [ ] P1/P2 候选动作（Launch、Start、Tap Response、Gentle End）是否进入后续版本。— state: open — owner: 产品 Owner — created: 2026-08-21 — defer reason: v0.6 P0 已限制为 5 组，当前不得扩张。

## 已闭环

- [x] 审计最终 Milo-only PRD、Approved Milo 静态资产、核心流程和当前页面映射。— state: closed — owner: Animation Director / Technical Art — closed: 2026-08-21
- [x] 冻结 5 组 P0 动作，每组 5 张关键帧，共 25 张。— state: closed — owner: Animation Director — closed: 2026-08-21
- [x] 完成场景计划、JSON Manifest、Identity Anchor Contract 和 ImageGen Request Package。— state: closed — owner: Technical Art — closed: 2026-08-21
- [x] 校验 JSON、Approved 参考路径和禁止角色引用；确认本轮没有生成图片、动画或修改 App。— state: closed — owner: Technical Art — closed: 2026-08-21

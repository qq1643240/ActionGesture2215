# ActionGesture2215

面向 iPhone 15 Pro Max / iOS 17.3.1 / Relaxin RootHide 的 Action Button 手势扩展。

## 功能

- 单击、双击、长按分别保存独立的系统动作。
- 去除方向识别和方向 Hook，不使用陀螺仪或 CoreMotion。
- 每种手势提供“快捷动作”：关闭、微信扫码、微信付款、支付宝扫码、支付宝付款。
- 系统动作优先：系统动作不是“无操作”时，始终只执行系统动作；只有系统动作是“无操作”时，才执行对应快捷动作 URL。
- 无法打开目标 App 或快捷动作关闭时，回退到系统原生动作。

## 设置

打开“设置 → 操作按钮”。右上角分别提供手势菜单和快捷动作菜单；系统原生列表仍用于配置系统动作。

## RootHide 构建

本项目固定构建 RootHide `arm64e`，目标包为 `ActionGesture2215_2.2.27_arm64e.deb`。

```sh
make package FINALPACKAGE=1
```

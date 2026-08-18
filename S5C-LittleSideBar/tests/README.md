# 测试说明

静态和纯函数自检：

    osascript -l JavaScript ../S5C-LittleSideBar.jxa --self-test

真实窗口测试需要在已登录的 macOS 图形桌面中运行，并给“快捷指令”辅助功能权限。验收至少覆盖：

- 当前内置显示器，Dock 位于底部且不自动隐藏；
- 重复运行两次，窗口位置和尺寸不漂移；
- 窗口主要位于另一块显示器，以及跨越两块显示器；
- 固定尺寸窗口或系统全屏窗口能够安全失败。

读取两块显示器和 Finder 窗口的全局几何：

    swift WindowGeometryProbe.swift

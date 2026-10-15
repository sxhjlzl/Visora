<div align="center">
  <img src="../../assets/Visora.png" width="112" height="112" alt="Visora Icon" />
  <h1>Visora · 产品说明</h1>
  <p><strong>面向 macOS 的原生开源看图工具 · 图片优先、界面安静、极速流畅</strong></p>
  <p>
    <a href="../../README.md">返回首页 (中文)</a> · <a href="../README.md">English</a>
  </p>
</div>

---

## 设计理念

**Visora** 的目标是把「打开 → 看 → 关上」这条看图主线做到极简、安静、流畅：

1. **图片优先**：UI 永远不与图片争夺注意力，悬浮控件采用 macOS 26 / 27 原生 Liquid Glass 材质并支持自动隐藏。
2. **默认就要快**：启动快、后台异步解码、邻图预加载、缩略图独立降采样缓存。
3. **原生 macOS 行为**：触控板手势、全屏、右键菜单、快捷键与系统菜单栏均符合 macOS 用户直觉。
4. **专业但轻量**：提供摄影师与设计师高频需要的直方图、RAW / AVIF / SVG 支持、跨图锁定缩放、像素级插值、OCR 提取与置顶图钉板，但不膨胀为笨重的素材管理器。

---

## 技术栈

| 层级 | 技术方案 |
| :--- | :--- |
| 语言 | Swift 5.9+ |
| 界面框架 | AppKit + `NSGlassEffectView` (macOS 26/27 Liquid Glass) |
| 图像解码与保存 | `ImageIO` (`CGImageSource` / `CGImageDestination`) + `CoreImage` |
| 文字识别 (OCR) | `Vision` (`VNRecognizeTextRequest`) |
| 文件监听 | `DispatchSourceFileSystemObject` |
| 类型识别 | `UniformTypeIdentifiers` (`UTType`) |
| 工程与测试 | Swift Package Manager (`swift build` / `swift test`) |

---

## 许可证

本项目基于 [MIT License](../../LICENSE) 开源。

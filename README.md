<div align="center">
  <img src="assets/Visora.png" width="112" height="112" alt="Visora Icon" />
  <h1>Visora</h1>
  <p><strong>面向 macOS 的原生开源看图工具 · 图片优先、界面安静、极速流畅</strong></p>
  <p>
    <a href="https://github.com/sxhjlzl/Visora/actions"><img src="https://img.shields.io/github/actions/workflow/status/sxhjlzl/Visora/ci.yml?branch=main&label=CI" alt="CI Status" /></a>
    <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue" alt="macOS 14+" />
    <img src="https://img.shields.io/badge/swift-5.9%2B-orange" alt="Swift 5.9+" />
    <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green" alt="License: MIT" /></a>
  </p>
  <p>
    <strong>简体中文</strong> · <a href="docs/README.md">English</a>
  </p>
</div>

---

**Visora** 是一款基于 AppKit 原生构建的轻量级 macOS 看图工具，专注于**「即开即看、顺畅浏览、安静不打扰」**的纯粹体验。界面深度融合 **macOS Liquid Glass（液态玻璃）** 设计语言，悬浮控件随用随现、自动隐退，始终把视觉重心留给图片本身。

---

## 核心特性

- **极速看图**：后台异步解码、邻图预加载、EXIF 方向自动纠正，支持长图模式与跨图锁定缩放（`L`）。
- **文件夹浏览**：自动扫描同目录图片并实时监听文件变动，支持 `⌘F` 快速过滤、多种排序与递归浏览。
- **画布与编辑**：支持深色 / 棋盘格 / 浅色 / 环境光晕 4 种背景（`B`）、像素级锐利缩放（`N`），以及旋转、翻转并保存回原图（`⌘S`）。
- **专业工具**：内置实时 RGB 直方图、EXIF 元数据面板（`I`）、原生 Vision OCR 文字提取面板（`O`）、缩略图网格（`G`）与桌面置顶图钉板（`P`）。
- **Liquid Glass 悬浮 HUD**：顶部胶囊信息栏、底部工具栏与胶卷条自动隐藏，鼠标悬停时保持常亮，不抢夺画面注意力。

---

## 快捷键一览

| 快捷键 | 操作 | 快捷键 | 操作 |
| :--- | :--- | :--- | :--- |
| `⌘O` | 打开图片 | `←` / `→` | 上一张 / 下一张 |
| `⌘⇧O` | 打开文件夹 | `↑` / `↓` | 放大 / 缩小 |
| `⌘⇧V` | 钉住剪贴板内容 | `Space` | 切换适应窗口 / 实际尺寸 |
| `⌘S` | 保存当前旋转 / 翻转修改到原图 | `Home` / `End` | 长图模式下跳到顶部 / 底部 |
| `⌘F` / `/` | 按文件名快速过滤当前文件夹 | `[` / `]` | 向左 / 向右旋转 |
| `⌘C` | 复制当前图像内容（位图） | `H` / `V` | 水平 / 垂直镜像翻转 |
| `⌘⇧C` | 复制当前图片文件 | `B` | 切换画布背景（深色 / 棋盘格 / 浅色 / 环境光晕） |
| `⌘⌥C` | 复制当前图片路径 | `N` | 切换像素级锐利缩放 / 平滑缩放 |
| `⌘R` | 在 Finder 中显示当前图片 | `L` | 跨图锁定缩放比例与视口位置 |
| `⌫` | 移到废纸篓 | `O` | 提取图中文字 (OCR) 并打开右侧文字面板 |
| `I` | 显示 / 隐藏信息与直方图面板 | `G` / `T` | 网格模式 / 底部胶卷条 |
| `S` / `P` | 幻灯片播放 / 钉住当前图片 | `C` / `F` | 沉浸式无边框窗口 / 系统全屏 |
| `⌘,` | 偏好设置 | `Esc` | 关闭搜索栏、网格或当前窗口 |

---

## 支持的图片格式

内置原生支持 **20+ 种**常见、现代与专业相机格式（可在偏好设置中按需勾选过滤）：

- **常规与动图**：`JPEG / JPG`、`PNG`、`APNG`（动图）、`GIF`（动图）、`WebP`（静态与动图）、`BMP`、`TIFF / TIF`、`ICO`
- **现代高压缩 / 广色域**：`HEIC / HEIF`、`AVIF`、`JPEG XL (JXL)`
- **矢量图形**：`SVG`
- **相机 RAW 原片**：`DNG`、`CR2`、`CR3`、`NEF`、`ARW`、`ORF`、`RAF`、`RW2`

---

## 快速开始

### 环境要求
- **系统**：macOS 14.0+（在 macOS 26 / 27+ 上自动启用原生 Liquid Glass 视觉特性）
- **工具链**：Xcode 15+ / Swift 5.9+

### 从源码构建与运行

```bash
git clone https://github.com/sxhjlzl/Visora.git
cd Visora

# 直接编译并运行
swift run Visora

# 命令行直接打开指定图片或文件夹
swift run Visora /path/to/image.jpg
swift run Visora ~/Pictures

# 运行单元测试
swift test
```

### 打包独立 `.app` 应用

```bash
scripts/build-app.sh
open dist/Visora.app
```

---

## 项目结构

```text
Visora/
├── App/                  # AppDelegate、系统菜单、SceneCoordinator 协调器
├── Core/
│   ├── Cache/            # 带字节成本与张数双控的内存缓存
│   ├── FileSystem/       # 文件夹递归扫描与 DispatchSource 实时文件监听
│   ├── ImageDecoding/    # ImageIO 解码、EXIF 方向纠正、图像变换保存、异步缩略图
│   ├── Localization/     # 中英双语实时本地化
│   └── Storage/          # 偏好设置与最近打开持久化
├── Domain/               # 设置、排序、命令、元数据领域模型
├── Features/
│   ├── Grid/             # 缩略图网格浏览模式
│   ├── Pinboard/         # 置顶悬浮图钉参考窗口
│   ├── Preferences/      # 五标签偏好设置窗口
│   └── Viewer/           # 看图主界面（画布、欢迎页、胶卷条、直方图、OCR 面板）
└── UI/
    ├── Brand/            # 品牌色与图标组件
    ├── Components/       # macOS 26/27 AdaptiveGlassSurfaceView 液态玻璃组件
    └── Window/           # 自适应主窗口控制器
```

---

## 参与贡献

非常欢迎提交 Issue 或 Pull Request！
- 发现 Bug 或有新功能建议：请直接提交 [GitHub Issue](https://github.com/sxhjlzl/Visora/issues)。
- 提交代码前请确保本地通过 `swift test` 单元测试。

---

## 许可证

本项目基于 [MIT License](LICENSE) 开源。

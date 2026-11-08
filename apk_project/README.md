# 地铁跑酷 APK 打包说明

## 目录结构

```
subway_surfer/
├── build_apk.bat                        ← 一键打包脚本（双击运行）
├── debug.keystore                       ← 自动生成的调试签名
├── subway_surfer.apk                    ← 最终输出
└── apk_project/
    ├── AndroidManifest.xml
    ├── assets/
    │   └── game.html                    ← ★ 替换为你的游戏文件
    ├── res/
    │   ├── drawable/
    │   │   └── ic_launcher.png          ← 应用图标（96×96 PNG）
    │   └── values/
    │       └── strings.xml
    └── src/com/subwaysurfer/game/
        └── MainActivity.java
```

---

## 前提条件

| 工具 | 版本要求 | 下载地址 |
|------|----------|----------|
| JDK  | 8 或更高 | https://adoptium.net |
| Android SDK | Build-Tools 30+ | https://developer.android.com/studio#command-tools |

> **Android Studio 用户**：SDK 已自动安装，脚本能自动检测路径。
>
> **仅命令行工具用户**：下载 cmdline-tools，解压后运行：
> ```
> sdkmanager "build-tools;34.0.0" "platforms;android-34"
> ```

---

## 快速开始

### 第一步：放入游戏文件

将地铁跑酷的 HTML5 游戏文件放入 `apk_project/assets/` 目录：

```
apk_project/assets/
├── game.html      ← 游戏入口（必须是这个文件名）
├── js/
├── css/
├── images/
└── ...
```

> 如果游戏入口文件叫其他名字（如 `index.html`），
> 需修改 `MainActivity.java` 第 87 行：
> ```java
> mWebView.loadUrl("file:///android_asset/index.html");
> ```

### 第二步：一键打包

双击 `build_apk.bat`，脚本会自动完成：
1. 检测 Java / Android SDK 路径
2. 用 `aapt` 编译资源
3. 用 `javac` 编译 Java 源码
4. 用 `d8` 生成 DEX
5. 打包 + 签名（debug keystore）+ zipalign 对齐

输出：`subway_surfer.apk`

### 第三步：安装到手机

```bat
adb install -r subway_surfer.apk
```

或直接把 APK 拷贝到手机安装。

---

## 常见问题

### Q: "未找到 Android SDK"
**A:** 设置环境变量后重试：
```bat
set ANDROID_HOME=C:\Users\你的用户名\AppData\Local\Android\Sdk
build_apk.bat
```

### Q: "aapt 资源编译失败"
**A:** 检查 `AndroidManifest.xml` 和 `res/` 目录是否完整，
图标 `res/drawable/ic_launcher.png` 必须存在。

### Q: "d8 转换失败 / 找不到 d8.bat"
**A:** 需要 Build-Tools **28.0.1 及以上**（d8 在此版本引入）。
在 SDK Manager 中安装更新版本：
```bat
sdkmanager "build-tools;34.0.0"
```

### Q: 手机提示"解析包出错"
**A:** 可能原因：
- APK 未签名 → 脚本会自动签名，检查是否报错
- APK 架构不匹配 → WebView 纯 Java，不涉及 Native，通常不会出现此问题
- 手机未允许"未知来源" → 设置 → 安全 → 允许未知来源

### Q: 游戏加载空白
**A:**
1. 确认 `game.html` 存在于 `assets/` 目录
2. 检查游戏是否依赖服务器接口（纯离线游戏才能用 file:// 协议）
3. 有跨域资源的游戏需改为 http://localhost 方案（内嵌 NanoHTTPD）

---

## 技术参数

| 参数 | 值 |
|------|----|
| 包名 | `com.subwaysurfer.game` |
| 应用名 | 地铁跑酷 |
| 最小 SDK | API 21 (Android 5.0) |
| 目标 SDK | API 34 (Android 14) |
| 屏幕方向 | 竖屏锁定 |
| JavaScript | 启用 |
| 缩放 | 禁用 |
| 硬件加速 | 开启 |

---

## 高级：替换应用图标

将 96×96 或 48×48 的 PNG 图标替换：
```
apk_project/res/drawable/ic_launcher.png
```

建议同时提供多分辨率：
- `res/drawable-mdpi/ic_launcher.png`   (48×48)
- `res/drawable-hdpi/ic_launcher.png`   (72×72)
- `res/drawable-xhdpi/ic_launcher.png`  (96×96)
- `res/drawable-xxhdpi/ic_launcher.png` (144×144)

---

## 高级：升级为 Release 签名

若要发布到应用市场，需使用正式签名：

```bat
:: 生成正式 keystore
keytool -genkeypair -keystore release.keystore -alias mykey ^
    -keyalg RSA -keysize 2048 -validity 36500

:: 用 apksigner 签名
apksigner sign --ks release.keystore --out subway_surfer_release.apk subway_surfer.apk
```

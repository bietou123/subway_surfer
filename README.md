# 地铁跑酷 Subway Surfer

一个单文件的 HTML5 Canvas 三跑道跑酷小游戏：左右换道、跳跃、滑铲，吃金币、躲障碍、拿道具，边跑边躲。整个游戏只有一个 `game.html`，不依赖任何外部图片、字体、音频或网络请求；另附一个不依赖 Gradle 的 APK 打包脚本，把它封成零权限的安卓应用。

## 玩法

- 角色在三条轨道上自动向前跑，画面是伪 3D 透视。
- 撞到障碍物会掉一条命并短暂无敌；道具和商店护盾都能兜底。
- 金币可以到商店买永久升级；分数进本地排行榜。
- 连吃金币会累积连击（combo），每 10 连额外奖励金币。

## 操作

| 操作 | 键盘 | 触屏 |
| --- | --- | --- |
| 开始 / 重来 | `Enter` / `空格` | 点击「开始」「再来一次」按钮 |
| 左移 | `←` / `A` | 向左滑 |
| 右移 | `→` / `D` | 向右滑 |
| 跳跃 | `↑` / `W` / `空格` | 向上滑 |
| 滑铲 | `↓` / `S` | 向下滑 |
| 关闭弹窗 | `Esc` | 点空白处 |

开始界面还能左右切换角色、切换城市、打开排行榜，按 `Enter` 或点按钮开跑。

## 系统

| 模块 | 内容 |
| --- | --- |
| 角色 | 4 个可选角色，外观与起始加成不同 |
| 场景 | 3 张城市地图，切换即换配色与背景 |
| 道具 | 磁铁（吸附金币）、喷气背包（飞行）、双倍分数、超级鞋（跳跃加强） |
| 商店 | 磁力手套（磁铁 +3 秒）、护盾（每局免死 1 次）等永久升级 |
| 计分 | 分数、最高分、金币、连击奖励、本地排行榜 |
| 音效 | Web Audio 实时合成，没有任何音频文件 |
| 存档 | `localStorage`：金币、已购商品、角色、城市、排行榜 |

## 在浏览器里玩

直接双击 `game.html`，或：

```powershell
# 任选其一
start game.html
python -m http.server 8000   # 然后访问 http://127.0.0.1:8000/game.html
```

画布按 480×800 的逻辑分辨率自适应窗口，手机浏览器横竖屏都能用。

## 构建 APK

不依赖 Gradle / Android Studio 工程，直接用 SDK 自带的 `aapt`、`javac`、`d8`、`zipalign`、`apksigner` 手打安装包：

```powershell
# 需要 JDK（含 javac）和 Android SDK（build-tools + 任一 platform）
$env:ANDROID_HOME = "C:\path\to\Android\Sdk"
$env:JAVA_HOME   = "C:\path\to\jdk"
.\build_apk.bat
```

产物为根目录下的 `subway_surfer.apk`。脚本会：

1. 自动找最新的 `build-tools` 和可用的 `android.jar`（优先 API 34，逐级降级到 21）；
2. `aapt` 编译资源并生成 `R.java`，`javac` 编译 `MainActivity`；
3. `d8` 转 DEX，`aapt add` 打进包里；
4. 首次运行时用 `keytool` 生成 `debug.keystore`（口令是 Android 通用的 `android`，仅用于本地调试），`apksigner` 签名后 `zipalign` 对齐。

非交互环境（CI、脚本）可以加 `--no-pause` 参数跳过结尾的暂停：

```powershell
cmd /c build_apk.bat --no-pause
```

### 应用信息

- 包名：`com.subwaysurfer.game`
- 版本：1.0（versionCode 1）
- minSdk 21 / targetSdk 34，竖屏全屏
- **零权限**：不联网、不震动、不读写外部存储、不申请常亮权限（全屏界面用 `FLAG_KEEP_SCREEN_ON` 保持亮屏）。`allowBackup="false"`，存档只留在本机。
- WebView 直接加载 `file:///android_asset/game.html`，全部资源在 APK 内。

### WebView 容器

`apk_project/src/com/subwaysurfer/game/MainActivity.java` 是一个极薄的壳：全屏沉浸式、锁定竖屏、开硬件加速、关闭缩放、返回键先回退网页历史再最小化（不直接退出），页面加载完成后再次强制全屏，兼容部分机型导航栏复现的问题。

## 离线验证

```powershell
pip install playwright
python -m playwright install chromium
python tools\smoke_test.py
```

脚本用无头 Chromium 打开 `game.html`，检查控制台无报错、画布尺寸与配色正常、按 `Enter` 后画面确实在动、四个方向键不报错。全程不弹窗口，适合在桌面环境里跑。输出保持纯 ASCII，避免 Windows 控制台编码问题。

## 目录结构

```
game.html                       完整游戏（HTML + CSS + JS）
apk_project/
  AndroidManifest.xml           清单（零权限、竖屏全屏）
  src/com/subwaysurfer/game/
    MainActivity.java           WebView 容器
  assets/game.html              游戏副本（打包时嵌入）
  res/drawable/ic_launcher.png  图标
  res/values/strings.xml        应用名
build_apk.bat                   一键打包 APK（无 Gradle）
tools/smoke_test.py             无头冒烟测试
```

改了 `game.html` 之后记得同步一份到 `apk_project/assets/game.html` 再打包。

## 已知限制

- 排行榜是本地 `localStorage`，不联网，也不跨设备同步。
- 三个城市目前是同一套玩法换配色 / 背景，不是独立关卡。
- 伪 3D 视角是手写的投影，远处物体不做透视裁剪之外的遮挡排序。
- 只在桌面 Chromium / Edge 与安卓 WebView 上验证过；其他浏览器未做兼容测试。

## 许可证

MIT，见 [LICENSE](LICENSE)。

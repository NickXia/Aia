# 把 Aia 装进鸿蒙手机

> 结论先说：**这是一个 HAP 工程（不是 APK），必须用 DevEco Studio 签名后才能装。**
> 直接拷文件到手机是装不上的——鸿蒙 NEXT 不接受未签名或签名里没有本机 UDID 的包。

---

## 0. 先确认三件事，缺一件就装不进去

| 检查项 | 怎么查 | 不满足会怎样 |
| --- | --- | --- |
| 手机是 **HarmonyOS NEXT（5.0 及以上）** | 设置 → 关于手机 → 版本号看是否为 `HarmonyOS 5.x.x` | 4.x / 3.x 是兼容安卓的老架构，**只认 APK**，HAP 装不上 |
| **华为账号已实名** | 开发者联盟后台或 DevEco 登录后看认证状态 | 未实名无法申请调试证书，签名按钮点了会失败 |
| 电脑装了 **DevEco Studio**（版本和本地 SDK 对齐） | 官网 developer.huawei.com 下载 | 版本与 `modelVersion` 不匹配会 Sync 失败 |

> 如果手机是 HarmonyOS 4.2 及以下：这条路走不通。要么升级到 NEXT，要么这个工程得重写成安卓版。

---

## 1. 三条路径，先选一条

| 路径 | 门槛 | 结果 | 适合 |
| --- | --- | --- | --- |
| **真机调试**（推荐） | 数据线 + 实名账号 | 装进自己的手机，能联网浏览 | 自己用、继续开发 |
| **模拟器** | 电脑 + 下载系统镜像 | 只在电脑屏幕里跑 | 手边没设备，先看界面 |
| **应用市场发布** | 开发者认证 + 软著 + App 备案 | 任何人可下载 | 给别人用 |

**注意**：调试签名是与设备绑定的（Profile 里写着手机 UDID），所以**没有"把 HAP 发给朋友让他装"这条路**。要给别人用，只能走应用市场。

---

## 2. 真机安装：七步

### 2.1 装 DevEco Studio

官网下载 Windows 版，安装时勾选 **HarmonyOS SDK**（默认会带 API 12 及以上）。装完首次启动会要求登录华为账号。

### 2.2 打开项目

`File → Open`，选 **`Aia` 这一层目录**（含 `build-profile.json5` 的那层）。
选成 `Aia/entry` 会报"不是有效工程"。

**点了 Open 完全没反应**，说明目录里缺 hvigor 脚手架——`hvigor/hvigor-wrapper.js`（约 1.1 MB）、根目录 `hvigorw` 与 `hvigorw.bat`。缺这三个文件时 IDE 不把它当鸿蒙工程，不会 Sync、不会出运行按钮。已在 2026-10-19 从 IDE 自带的 `tools/hvigor/bin/hvigorw.js` 补齐，并把脚本里的 wrapper 路径改到 `hvigor/hvigor-wrapper.js`。

判定标准：打开后右下角应出现 **Sync** 进度条，Project 面板里 `entry` 带小手机图标而不是普通文件夹。

### 2.3 等 Sync 跑完

右下角会有进度条，首次要联网拉 hvigor 与 ohpm 依赖，3–10 分钟。
若卡在 `ohpm install`，检查网络或换镜像（`File → Settings → Build → Ohpm`）。

### 2.4 对齐 SDK 版本

`File → Project Structure → Project` 里看 `compatibleSdkVersion`。

本机现状（2026-10-19 实测）：**DevEco 26.0.0.851，仅装了 API 26（HarmonyOS 26.0.0）**，所以工程已改为：

```
"targetSdkVersion": "26.0.0(26)",
"compatibleSdkVersion": "26.0.0(26)"
```

含义：**只有 HarmonyOS 26 及以上的设备能装**。如果你的手机是 5.x / 6.0，需要先用 SDK Manager 装对应版本的 SDK，再把这两行改成那个版本（例如 `6.0.0(20)`），否则安装时会提示版本不兼容。

### 2.5 配自动签名（关键一步）

`File → Project Structure → Signing Configs` → 勾选 **Automatically generate signature** → 登录华为账号。

它会自动做三件事：申请调试证书、生成 Profile、**把你当前连接的手机 UDID 写进 Profile**。所以**先插手机再点这个**，顺序反了会签出一个不含本机的包，安装时报 9568289。

### 2.6 手机端准备

1. 设置 → 关于手机 → 连续点 **版本号** 7 次，提示"已进入开发者模式"
2. 设置 → 系统 → **开发者选项** → 打开 **USB 调试**
3. 数据线连电脑，手机弹窗选"传输文件"，并允许 USB 调试（弹窗要勾"始终允许"）
4. 电脑设备管理器里应出现 HDB 设备；DevEco 右上角设备下拉框能看到你的机型

### 2.7 运行

顶部运行配置选 `entry`，点绿色三角（或 `Shift+F10`）。
首次会编译 → 签名 → 安装 → 自动拉起，大约 1–3 分钟。之后改代码点一次就能热装。

**或者手动安装已构建的包**：

```bash
# hdc 在 SDK 的 toolchains 目录下
hdc list targets                        # 确认设备已连上
hdc install entry/build/default/outputs/default/entry-default-signed.hap
hdc shell aa start -a EntryAbility -b com.aia.browser
```

---

## 3. 报错对照表

| 现象 | 原因 | 处理 |
| --- | --- | --- |
| `The device is not authorized` | 手机没点"允许调试" | 拔线重插，看清手机弹窗 |
| `install failed, code 9568289` | 签名 Profile 里没有这台设备 | 删除 Signing Configs 重新自动签名（手机保持连接） |
| `hvigor ERROR: modelVersion` | IDE 版本与工程模板不匹配 | Project Structure 里升级 modelVersion |
| `Cannot find module '@kit.ArkWeb'` | SDK 版本低于 API 11 | 装 API 12+ 的 SDK，或调低 `compatibleSdkVersion` 后按提示改代码 |
| 界面白屏 / 图标空白 | 启动图资源或媒体引用缺失 | 看 Log 里 `Resource` 关键字，补齐 `media` 资源 |
| 编译报某个 `Web` 属性不存在 | ArkWeb 接口随 API 版本变化 | 按 IDE 提示改；不确定就发我报错原文 |

---

## 4. 两件必须说清楚的事

1. **这个工程没有经过真机编译验证。** 我这边没有鸿蒙 SDK，代码是按 API 12 的 ArkUI / ArkWeb 接口写的，首次 Sync 大概率会有几处签名差异（尤其 `preferences`、`Web` 的个别属性）。报错贴给我，我直接改，不用你自己猜。
2. **装上去也只是骨架版。** 按 `docs/02-aia-design-brief.md`，页内查找、请求桌面版、无痕、广告拦截这四项 P0 还没实现——现在的 Aia 能浏览、能多标签、能书签历史，但还不算"能日常用"。

---

## 5. 不想装 IDE 的临时办法

把 `preview/aia-preview.html` 传到手机，用手机浏览器打开，能看到完整交互和视觉（主页/网页态/标签/菜单/设置，含深色模式）。它只是界面原型，不联网、不能真的浏览网页，但用来确认"这个设计是不是我要的"够用了。

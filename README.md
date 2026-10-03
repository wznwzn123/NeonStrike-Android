# Neon Strike — Android Production Build

这是原有 Neon Strike Canvas 游戏的 Android 横屏离线版本，使用原生 WebView 壳加载本地 `assets/index.html`，不需要网络权限，也不依赖 AndroidX WebKit。

## 已包含

- 原版核心玩法保留
- 数据驱动武器：Pulse Rifle / Volt SMG / Arc Shotgun
- 移动、右侧转向、开火、ADS、换弹、切枪、Dash
- HP / 护甲、命中反馈、击杀反馈、镜头震动
- 敌人 FSM：Idle / Patrol / Detect / Chase / Attack / Search / Retreat / Dead
- 掩体与碰撞
- 设置：音量、触控灵敏度、画质、震动
- 主菜单、武器库、暂停、结算界面
- Android 横屏沉浸式模式
- 无 INTERNET 权限；音效和游戏资源均本地生成/打包
- WebView 渲染进程异常恢复

## 本地构建

环境需要 JDK 17、Android SDK 36、Build Tools 36.0.0、Gradle 9.4.1。

```bash
gradle :app:assembleDebug --stacktrace --no-daemon
```

APK：

`app/build/outputs/apk/debug/app-debug.apk`

## GitHub Actions 一键构建

项目自带 `.github/workflows/android-apk.yml`。把整个项目上传到 GitHub 后，可在 **Actions → Build Neon Strike APK → Run workflow** 执行；构建完成后在该 workflow 的 **Artifacts** 下载 `neon-strike-debug-apk`。

## 当前运行环境限制

本工作环境没有 Android SDK、Build Tools 或 Gradle，因此这里不能诚实地标记“已生成并实机验证 APK”。工程本身已按 Android 构建结构准备，并附带远程构建工作流。

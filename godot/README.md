# Neon Strike — Godot 4 重制版

这是独立于旧 HTML Canvas 版本的全新 3D 原型，旧版本保留在原项目中，不覆盖、不删除。

## 当前原型范围
- Godot 4 / 3D 第一人称视角
- CharacterBody3D 玩家移动与碰撞
- 第一人称摄像机、射线命中检测、弹匣与换弹
- 敌人追击与近距离攻击逻辑
- 程序化灰盒战术训练场、墙体与掩体
- 中文 HUD、移动端触控按钮与左侧虚拟移动区
- Android 优先使用 GL Compatibility 渲染路径

## 运行
使用 Godot 4.3 或更新的 Godot 4.x 打开此目录中的 project.godot，运行主场景。

## 诚实的当前状态
这是第一阶段可运行原型工程（持续修正构建验证问题），不是最终成品，也已配置 GitHub Actions 自动验证 Android APK 导出，并补全 Android 导出预设；尚未完成真机性能验证。下一阶段需要在 Godot 编辑器/CI 中进行项目导入、脚本解析、Android 导出模板配置与设备测试，再扩充枪械动画、音效、敌人远程攻击、关卡和优化。

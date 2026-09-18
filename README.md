# HanaBook

HanaBook 是一个本地优先、无账号、无社交属性的个人作品记录工具，适用于记录动画、漫画、小说、游戏和电影。

设计风格为 **纸质手账风**——灰紫/旧书布纹配色、衬线标题字体、柔和微动效，打造私人备忘录式的使用体验。

## 功能

- 手动新建 / 编辑作品记录，支持封面图片的自选与裁剪
- 作品库列表、网格、瀑布流三种视图，支持类型筛选和关键词搜索
- 首页时间线 + 统计书签，快速查看最近更新
- 0–10 评分（支持 0.5）、文字评价、记录日期；评分颜色区间与评分 Tag 可在设置中自定义，未配置或未匹配规则时使用中性星色且不显示 Tag
- 作品详情页与软删除
- 导出与恢复备份，兼容历史 Recallio v1 备份
- 纸质手账风格 UI，亮色 / 暗色双主题
- Windows / Android 双平台

## 桌面端键盘快捷键

| 快捷键 | 功能 |
|--------|------|
| `Ctrl+N` | 新建记录 |
| `Ctrl+F` | 搜索导入 |
| `Ctrl+B` | 备份与恢复 |
| `Ctrl+1` | 首页 |
| `Ctrl+2` | 作品库 |
| `Ctrl+3` | 搜索 |
| `Ctrl+4` | 备份 |
| `Ctrl+5` | 设置 |
| `Escape` | 返回 / 首页按两次退出 |

## 初始化与运行

确保已安装 Flutter SDK 和 Android SDK，然后使用项目脚本运行：

```powershell
# 检查环境
powershell.exe -ExecutionPolicy Bypass -File scripts\recallio_dev.ps1 doctor

# 安装依赖
powershell.exe -ExecutionPolicy Bypass -File scripts\recallio_dev.ps1 pub-get

# 静态分析
powershell.exe -ExecutionPolicy Bypass -File scripts\recallio_dev.ps1 analyze

# 运行测试
powershell.exe -ExecutionPolicy Bypass -File scripts\recallio_dev.ps1 test

# 运行 Windows 版本
powershell.exe -ExecutionPolicy Bypass -File scripts\recallio_dev.ps1 run-windows

# 构建 Android APK
powershell.exe -ExecutionPolicy Bypass -File scripts\recallio_dev.ps1 build-android-debug
```

可用任务：`clean` `pub-get` `analyze` `test` `build-windows-debug` `build-windows-release` `build-android-debug` `build-android-release` `run-windows` `doctor`

`build-android-release` 使用 `--split-per-abi`，发布时取 arm64-v8a 产物；`build-windows-release` 的产物在 `build\windows\x64\runner\Release\`。

脚本会自动管理 `PUB_CACHE`、`TEMP`、`GRADLE_USER_HOME` 等环境变量，避免 Windows 下 sqlite3 native assets 和 MSBuild PATH 过长问题。

## 隐私说明

HanaBook 默认将数据保存在当前设备本地。除非你主动使用外部搜索功能，否则应用不会访问网络。请定期导出备份包，以便迁移设备或防止数据丢失。

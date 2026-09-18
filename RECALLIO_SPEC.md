# HanaBook 项目开发规格说明

## 1. 项目定位

HanaBook 是一个本地优先、无账号、无社交属性的个人作品记录工具。

它不是 Bangumi、AniList、Animeko 或豆瓣式的 ACGN 收藏 / 社区工具，也不是作品百科资料库。第一版应保持轻量、私人工具感和手账式记录体验。

核心问题：

```txt
我记录了什么作品？
它是什么类型？
我给它几分？
我当时怎么评价它？
我是什么时候记录的？
```

支持作品类型：

- 动画
- 漫画
- 小说
- 游戏

禁止事项：

- 不添加账号。
- 不添加登录。
- 不添加云同步。
- 不添加社交功能。
- 不添加评论区。
- 不添加推荐算法。
- 不添加复杂标签系统。
- 不添加进度管理系统。
- 不添加状态追踪系统。

## 2. 第一版目标

第一版优先完成本地端 App。

首发平台：

- Windows PC
- Android 手机

第一版必须满足：

1. 可在本地安装和运行。
2. 不需要账号。
3. 不需要后端服务器。
4. 不上传用户数据。
5. 数据保存在本地。
6. 支持作品记录的增删改查。
7. 支持动画、漫画、小说、游戏四种类型。
8. 支持标题、类型、封面、评分、评价、记录日期。
9. 支持软删除。
10. 重启 App 后数据不丢。

第一版暂不做：

- 用户注册 / 登录。
- 社交动态 / 好友 / 评论区。
- 云同步 / 自建服务器。
- 在线排行榜 / 推荐算法。
- 复杂多数据源聚合。
- 状态追踪、进度管理、标签体系。

## 3. 第一版字段

新建 / 编辑记录页面只需要：

### 作品

- 标题，必填。
- 类型，必填：动画 / 漫画 / 小说 / 游戏。
- 封面，可选。

### 我的评价

- 评分，可选，0-10 分，支持 0.5。
- 评价，可选，多行文本。
- 记录日期，默认今天，可修改。

第一版 UI 不显示：

- 原名
- 别名
- 发售 / 放送 / 出版日期
- 作者 / 制作组 / 开发商
- 简介
- 状态
- 短评
- 长评
- 进度
- 平台
- 开始日期
- 完成日期
- 标签
- 剧透笔记

说明：

- “短评”和“长评”合并为一个字段，统一叫“评价”。
- 不再显示“剧透笔记”。
- 不再显示“状态”。
- 不再显示“进度”。
- 不再显示“标签”。

## 4. 技术栈

使用 Flutter 开发本地端 App。

```yaml
framework: Flutter
language: Dart
database: SQLite
database_wrapper: Drift
state_management: Riverpod
router: go_router
file_system: path_provider
file_picker: file_picker
zip: archive
network: http
image_cache: cached_network_image
uuid: uuid
date_format: intl
```

原则：

- 使用 Flutter 实现 Windows 和 Android 双端。
- 使用 SQLite 保存本地结构化数据。
- 使用 Drift 管理数据库表、查询和迁移。
- 使用 Riverpod 管理状态。
- 使用 go_router 管理页面路由。
- 使用本地应用文档目录保存数据库和封面。
- 不引入 Firebase、Supabase、Appwrite 或任何云服务。
- 不实现账号系统。
- 不使用服务端数据库。

## 5. 数据模型

长期建议使用单表 `entries` 作为第一版核心表：

```txt
id TEXT PRIMARY KEY
title TEXT NOT NULL
type TEXT NOT NULL
cover_path TEXT
rating REAL
review TEXT
record_date TEXT NOT NULL
source_provider TEXT
source_id TEXT
source_url TEXT
created_at TEXT NOT NULL
updated_at TEXT NOT NULL
deleted_at TEXT
```

字段说明：

- `title`：作品标题。
- `type`：anime / manga / novel / game。
- `cover_path`：本地封面路径。
- `rating`：0-10，可为空。
- `review`：用户评价，可为空。
- `record_date`：记录日期。
- `source_provider`：manual / bangumi / steam 等。
- `source_id`：外部来源 ID。
- `source_url`：外部来源链接。
- `deleted_at`：软删除。

当前实现仍使用 `works + records` 内部结构以降低迁移风险。UI 必须保持简化，不让用户感知复杂模型。

当前映射：

- `works.title` -> 标题。
- `works.type` -> 类型。
- `works.cover_path` -> 封面。
- `records.rating` -> 评分。
- `records.review` -> 评价。
- `records.start_date` -> 记录日期。
- `works.source_provider/source_id/source_url` -> 来源信息。

旧字段可以暂时保留在数据库和导入导出兼容层，但第一版 UI 不主动使用。

## 6. 页面规划

第一版页面：

```txt
首页
作品库
新建 / 编辑记录
作品详情
搜索导入
备份与恢复
设置
关于
```

### 6.1 首页

展示：

- 全部记录数量。
- 已评分数量。
- 有评价数量。
- 高分记录数量。
- 最近更新记录。

不要展示：

- 正在进行。
- 最近完成。
- 状态统计。
- 标签统计。
- 进度统计。

### 6.2 作品库

卡片只显示：

- 封面
- 标题
- 类型
- 评分
- 评价摘要
- 记录日期

筛选：

- 类型筛选。
- 标题 / 评价关键词搜索。

不要显示：

- 状态
- 进度
- 标签
- 平台
- 短评 / 长评区分

### 6.3 新建 / 编辑记录

页面应像轻量手账表单，不像资料录入后台。

推荐分区：

```txt
作品
我的评价
```

字段：

- 标题
- 类型
- 封面
- 评分
- 评价
- 记录日期

### 6.4 作品详情

详情页只显示：

- 封面
- 标题
- 类型
- 评分
- 评价
- 记录日期
- 来源信息，可折叠或弱化显示

不要显示百科式资料区。

### 6.5 搜索导入

未来 Bangumi 搜索导入时，搜索结果可以临时展示：

- 封面
- 标题
- 简介
- 来源

导入到本地后，第一版只需要保存：

- 标题
- 类型
- 封面
- `source_provider`
- `source_id`
- `source_url`

简介不需要在主 UI 展示。

### 6.6 备份与恢复

当前备份格式使用中性 ZIP 结构：

```txt
manifest.json
data/
  entries.json
assets/
  covers/
```

manifest 必须包含：

- `formatIdentifier`：稳定、中性且不含产品品牌的格式标识。
- `formatVersion`：当前格式版本。
- `appName`：导出应用的展示名称。
- `appVersion`：导出应用版本。
- `createdAt`：备份创建时间。

`appName` 只用于展示，导入分流不得依赖 Recallio 或 HanaBook 品牌字符串。默认文件名为 `HanaBook-backup-YYYY-MM-DD.zip`，但导入不得依赖文件名。

`data/entries.json` 当前简化为：

```json
{
  "entries": []
}
```

entry 字段使用 camelCase：

```json
{
  "id": "...",
  "title": "...",
  "type": "game",
  "coverPath": "covers/xxx.jpg",
  "rating": 9.5,
  "review": "我的评价",
  "recordDate": "2026-06-19",
  "sourceProvider": "manual",
  "sourceId": null,
  "sourceUrl": null,
  "createdAt": "...",
  "updatedAt": "...",
  "deletedAt": null
}
```

HanaBook 必须继续读取 Recallio v1 的根目录 `data.json` 与 `covers/` 结构。新旧格式通过 `formatIdentifier`、版本字段和目录特征区分；旧 manifest 中的 `app` 仅作为历史元数据，不参与合法性判断。

如果内部结构仍包含 `works / records / tags / recordTags`，可以保留读取兼容，但当前新备份格式优先使用 `entries`。

## 7. 路由

```txt
/                 首页
/library          作品库
/search           搜索导入
/works/new        手动新建记录
/works/:id        作品详情
/works/:id/edit   编辑记录
/backup           备份与恢复
/settings         设置
/about            关于
```

第一版不提供 `/tags` 入口。

## 8. 本地数据目录

应用数据建议保存在应用文档目录下：

```txt
Recallio App Data/
  data/
    recallio.sqlite
  covers/
    work_xxx.jpg
    work_xxx.webp
  backups/
```

说明：

- 数据库保存在 `data/recallio.sqlite`。
- 作品封面保存到 `covers/`。
- 导出的备份包可以默认放在 `backups/`，也允许用户选择保存位置。
- 不要只保存网络封面 URL。导入外部条目后，应尽量下载封面并保存为本地文件。

## 9. UI 风格要求

整体风格：

- 简洁。
- 轻量。
- 私人工具感。
- 不要做成后台管理系统风格。
- 不要做成社区 App 风格。

要求：

- 首页和作品库信息密度适中。
- 封面图是视觉中心。
- 表单分区清晰。
- 评价编辑区域要舒服。
- 移动端按钮点击区域要足够大。
- Windows 端不要过度移动端化。
- Android 端不要过度桌面端化。
- 空状态、错误状态、加载状态要有中文提示。

## 10. 隐私与安全

HanaBook 必须遵守：

- 不上传用户记录。
- 不上传用户评分。
- 不上传用户评价。
- 不实现追踪埋点。
- 不默认联网，除非用户主动搜索外部条目。
- 不在用户不知情的情况下访问网络。
- 不收集设备信息。
- 不要求登录。
- 不要求手机号、邮箱、密码。
- 不接入广告 SDK。

设置页或关于页需要明确说明：

```txt
HanaBook 默认将数据保存在当前设备本地。除非你主动使用外部搜索功能，否则应用不会访问网络。请定期导出备份包，以便迁移设备或防止数据丢失。
```

## 11. 开发命令

优先使用项目脚本：

```powershell
powershell.exe -ExecutionPolicy Bypass -File E:\ppfm\Recallio\scripts\recallio_dev.ps1 analyze
powershell.exe -ExecutionPolicy Bypass -File E:\ppfm\Recallio\scripts\recallio_dev.ps1 test
powershell.exe -ExecutionPolicy Bypass -File E:\ppfm\Recallio\scripts\recallio_dev.ps1 build-windows-debug
powershell.exe -ExecutionPolicy Bypass -File E:\ppfm\Recallio\scripts\recallio_dev.ps1 run-windows
```

脚本负责：

- 使用工作区 `PUB_CACHE`。
- 使用工作区 `TEMP / TMP`。
- 清理过长 `Path`。
- 避免 Windows MSBuild 环境变量过长。
- 避免 `sqlite3` native assets 反复下载。

## 12. 测试要求

至少覆盖：

- 枚举文案转换。
- 备份 manifest 解析。
- `data/entries.json` 序列化 / 反序列化。
- Recallio v1 `data.json` 兼容导入。
- ZIP 重命名后的导入。
- 评分范围校验。
- Repository 创建、编辑、软删除。
- 首页可启动。
- 新建页只显示第一版字段。
- 作品卡片只显示第一版字段。
- 详情页只显示第一版字段。

每次修改后运行：

```powershell
powershell.exe -ExecutionPolicy Bypass -File E:\ppfm\Recallio\scripts\recallio_dev.ps1 analyze
powershell.exe -ExecutionPolicy Bypass -File E:\ppfm\Recallio\scripts\recallio_dev.ps1 test
```

## 13. 阶段计划

### 阶段 1：本地记录闭环

目标：

- 实现作品库列表。
- 实现手动新建记录。
- 实现编辑记录。
- 实现详情页。
- 实现软删除。
- 实现评分、评价、记录日期。
- 支持本地选择封面并复制到 covers 目录。

验收：

- 可以手动创建动画、漫画、小说、游戏四类记录。
- 可以填写标题、类型、评分、评价、记录日期。
- 可以选择封面。
- 作品库能正常显示记录。
- 详情页能正常显示记录。
- 可以编辑记录。
- 可以软删除记录。
- 重启 App 后数据不丢。
- 不再显示状态、进度、平台、标签、简介、短评、长评、剧透笔记等复杂字段。

### 阶段 2：搜索导入

目标：

- 实现 MetadataProvider 抽象。
- 实现 BangumiProvider。
- 实现搜索结果列表。
- 导入后只保存第一版主 UI 需要的数据和来源信息。

### 阶段 3：备份与恢复

目标：

- 实现导出 `HanaBook-backup-YYYY-MM-DD.zip`。
- 实现不依赖文件名的 ZIP 导入。
- 实现 manifest.json。
- 实现 `entries` 格式 `data/entries.json`。
- 导出 `assets/covers/`。
- 兼容 Recallio v1 的 `data.json` 与 `covers/`。
- 导入前显示备份预览。
- 实现安全的覆盖导入和基础合并导入。

### 阶段 4：体验完善

目标：

- 优化首页。
- 优化作品库筛选。
- 优化详情页布局。
- 优化移动端布局。
- 修复明显 UI 问题。

## 14. Codex 开发约束

开发时请遵守：

1. 不要引入后端。
2. 不要引入账号系统。
3. 不要引入云同步。
4. 不要引入社交功能。
5. 不要擅自扩大第一版范围。
6. 不要一次性重构所有文件。
7. 每次修改尽量聚焦一个阶段目标。
8. 修改后更新必要 README 或规格文档。
9. 每次完成阶段任务后运行分析和测试。
10. 如果遇到平台权限问题，优先选择最简单、最稳妥的实现方式。

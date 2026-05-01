# CC 指令剪贴板 (CC Clipboard)

macOS 菜单栏工具 — 一键复制 Claude Code 常用指令。

点击菜单栏 📋 图标，选择指令，自动复制到剪贴板并粘贴到当前输入框。

## 快速开始

### 方式一：下载原生 App（推荐）

要求：macOS 13+，Apple Silicon（M1/M2/M3/M4）

1. 下载 [最新 Release](https://github.com/glping/cc-clipboard/releases) 中的 `CCClipboard-x.x.x.zip`
2. 解压，将 `CCClipboard.app` 拖入 `应用程序` 文件夹
3. 首次运行：**右键 → 打开**（因未签名，Gatekeeper 会拦截双击打开）
4. 菜单栏出现 📋 图标，点击即可使用

### 方式二：Python 版本

要求：macOS 10+，Python 3.8+

```bash
pip install rumps
git clone https://github.com/glping/cc-clipboard.git
cd cc-clipboard/python
python cc-clipboard.py
```

可用 `bash cc-clipboard.sh autostart` 设置开机自启。

## 功能

- 点击指令 → 自动复制并粘贴到当前输入框
- `🔍 搜索指令` — 关键词搜索所有指令
- `➕ 新增指令` — 添加自定义指令
- `✏️  编辑指令` — 修改现有指令
- `🗑 删除指令` — 删除不需要的指令
- `🔄 重新加载` — 从磁盘重新加载指令列表
- 指令数据持久化到 `~/.cc-clipboard/commands.json`（Swift 和 Python 版本共享）

## 内置指令分类

| 分类 | 说明 |
|------|------|
| 会话结束 | 收工复盘、DOC 标记 |
| DOC: 标记模板 | 知识沉淀标记模板 |
| 上下文管理 | /compact, /clear, /usage, /model |
| 模型切换 | Sonnet / Opus 一键切换 |
| 决策记录 | 触发决策记录、模板参考 |
| 知识沉淀 | ≥2 次即提升为规则/skill |
| 质量门 | TypeScript 检查、预检、数字溯源 |
| 穴居人模式 | 输出密度最大化原则 |
| MCP 审计 | MCP 列表检查、降级链 |
| 调试哲学 | 改 vault 不改 agent 等 |

## 自定义指令

支持自行增删改指令，数据保存在 `~/.cc-clipboard/commands.json`，Swift 和 Python 版本共享同一数据文件。

## 开发

### Swift 版本构建

```bash
cd swift
./build.sh
# 产出 swift/dist/CCClipboard-1.0.0.zip
```

### Python 版本

```bash
pip install -r python/requirements.txt
python python/cc-clipboard.py
```

## License

MIT

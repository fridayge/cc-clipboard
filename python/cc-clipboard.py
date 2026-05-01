#!/usr/bin/env python3
"""CC Clip — macOS menu bar Claude Code commands clipboard."""

import rumps
import json
import subprocess
import os
import sys
import functools
import time
from pathlib import Path

DATA_DIR = Path.home() / ".cc-clipboard"
DATA_FILE = DATA_DIR / "commands.json"

DEFAULT_COMMANDS = [
    {"category": "会话结束", "text": "更新 CLAUDE.md，记录今天完成了什么、下次从哪里继续", "tag": "收工"},
    {"category": "会话结束", "text": "复盘，总结教训，写入规则", "tag": "复盘"},
    {"category": "会话结束", "text": "记一条：DOC: [领域] — [教训]", "tag": "事中标记"},
    {"category": "会话结束", "text": "子项目状态已变化，更新索引表状态列", "tag": "收工"},
    {"category": "DOC: 标记模板", "text": "记一条：DOC: testing — integration tests must hit real DB, not mocks", "tag": "模板"},
    {"category": "DOC: 标记模板", "text": "记一条：DOC: architecture — webhook handlers must be idempotent", "tag": "模板"},
    {"category": "DOC: 标记模板", "text": "记一条：DOC: workflow — ≥2 次重复即提升为规则/skill", "tag": "模板"},
    {"category": "上下文管理", "text": "/compact", "tag": "压缩"},
    {"category": "上下文管理", "text": "/clear", "tag": "清空"},
    {"category": "上下文管理", "text": "/usage", "tag": "成本"},
    {"category": "上下文管理", "text": "/model", "tag": "当前模型"},
    {"category": "上下文管理", "text": "清空当前输入栏", "tag": "清输入"},
    {"category": "模型切换", "text": "/model claude-sonnet-4-6", "tag": "日常"},
    {"category": "模型切换", "text": "/model claude-opus-4-7", "tag": "复杂推理"},
    {"category": "决策记录", "text": "这个决策值得记录，写入 decisions/ 吧", "tag": "触发"},
    {"category": "决策记录", "text": "选了什么？依据？回头看的条件是什么？", "tag": "模板"},
    {"category": "知识沉淀", "text": "这是第三次做同一件事了，提升为 skill 或写入 rules", "tag": "≥2次"},
    {"category": "知识沉淀", "text": "将重复模式写入 internal_cookbook/", "tag": "cookbook"},
    {"category": "质量门", "text": "npx tsc --noEmit", "tag": "TS"},
    {"category": "质量门", "text": "grep -c 'TODO\\|placeholder\\|示例' output.html", "tag": "预检"},
    {"category": "质量门", "text": "grep -nE '[0-9]+' output.md | head -20", "tag": "数字溯源"},
    {"category": "穴居人模式", "text": "只说结论，不说废话。输出密度最大化。", "tag": "原则"},
    {"category": "穴居人模式", "text": "删除礼貌填充、结构冗余、结尾总结。", "tag": "反模式"},
    {"category": "穴居人模式", "text": "中间数据 >200 token → 写文件传路径，不嵌入 prompt。", "tag": "规则2"},
    {"category": "MCP 审计", "text": "检查当前 MCP 列表：cat .mcp.json", "tag": "审计"},
    {"category": "MCP 审计", "text": "降级链：Firecrawl → Scrapling → Apify → Browserbase → WebSearch", "tag": "降级"},
    {"category": "调试哲学", "text": "改 vault 不改 agent —— 先诊断输入再升级工具", "tag": "原则"},
    {"category": "调试哲学", "text": "CLAUDE.md 规则探针：发一个明显违规请求，看是否被拦截", "tag": "版本升级"},
    {"category": "调试哲学", "text": "Opus 4.7 下显式 Use subagent(...) 语法委托", "tag": "prompt"},
]


def load_commands():
    """Load commands from JSON, fall back to defaults."""
    if DATA_FILE.exists():
        try:
            return json.loads(DATA_FILE.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            pass
    save_commands(DEFAULT_COMMANDS)
    return list(DEFAULT_COMMANDS)


def save_commands(commands):
    """Persist commands to JSON."""
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    DATA_FILE.write_text(
        json.dumps(commands, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )


def copy_clipboard(text):
    """Copy text to macOS clipboard via pbcopy."""
    try:
        proc = subprocess.Popen(["pbcopy"], stdin=subprocess.PIPE, stdout=subprocess.PIPE)
        proc.communicate(input=text.encode("utf-8"), timeout=10)
    except Exception as e:
        rumps.alert("复制失败", str(e))


def paste_clipboard():
    """Paste clipboard into frontmost app via Cmd+V."""
    time.sleep(0.08)
    try:
        subprocess.run(
            ["osascript", "-e", 'tell application "System Events" to keystroke "v" using command down'],
            capture_output=True, timeout=5,
        )
    except Exception:
        pass


def clear_input():
    """Clear the active input field via Ctrl+E (end) + Ctrl+U (kill line)."""
    time.sleep(0.08)
    try:
        subprocess.run(
            ["osascript", "-e",
             'tell application "System Events"\n'
             'keystroke "e" using control down\n'
             'delay 0.03\n'
             'keystroke "u" using control down\n'
             'end tell'],
            capture_output=True, timeout=5,
        )
    except Exception:
        pass


def osascript_escape(s):
    """Escape a string for safe embedding in AppleScript double-quoted string."""
    return s.replace("\\", "\\\\").replace('"', '\\"')


def osascript_dialog(prompt, default=""):
    """Show an input dialog via osascript, return text or None on cancel."""
    ep = osascript_escape(prompt)
    ed = osascript_escape(default)
    script = f'''
    display dialog "{ep}" default answer "{ed}" buttons {{"取消", "确定"}} default button "确定"
    if button returned of result is "确定" then
        return text returned of result
    else
        return ""
    end if
    '''
    try:
        proc = subprocess.run(
            ["osascript", "-e", script],
            capture_output=True, text=True, timeout=30,
        )
        result = proc.stdout.strip()
        return result if result else None
    except Exception:
        return None



class CCClipboard(rumps.App):
    """Menu bar clipboard app for Claude Code commands."""

    def __init__(self):
        super().__init__("📋", title="📋")
        self.commands = load_commands()
        self.refresh_menu()

    # ── Menu building ────────────────────────────────────────────

    def refresh_menu(self):
        """Rebuild the entire menu from current commands."""
        self.menu.clear()

        self.menu.add(rumps.MenuItem("📋 CC 指令剪贴板", callback=None))
        self.menu.add(rumps.separator)

        # Flat menu: category header + commands + separator
        cats = sorted({c["category"] for c in self.commands})
        first = True
        for cat in cats:
            if not first:
                self.menu.add(rumps.separator)
            first = False
            # Category header (non-clickable)
            header = rumps.MenuItem(cat)
            header.set_callback(None)
            self.menu.add(header)
            # Commands under this category
            for item in [c for c in self.commands if c["category"] == cat]:
                label = item["text"]
                tag = item.get("tag", "")
                if tag:
                    label = f"{label}  [{tag}]"
                if item["text"] == "清空当前输入栏":
                    cmd = rumps.MenuItem(label, callback=self._on_clear_input)
                else:
                    cmd = rumps.MenuItem(label, callback=functools.partial(self._on_copy, item["text"]))
                self.menu.add(cmd)

        # ── Actions section ──
        self.menu.add(rumps.separator)
        self.menu.add(rumps.MenuItem("🔍 搜索指令...", callback=self._on_search))
        self.menu.add(rumps.MenuItem("➕ 新增指令", callback=self._on_add))
        self.menu.add(rumps.MenuItem("✏️  编辑指令", callback=self._on_edit))
        self.menu.add(rumps.MenuItem("🗑 删除指令", callback=self._on_delete))
        self.menu.add(rumps.separator)
        self.menu.add(rumps.MenuItem("🔄 重新加载", callback=self._on_reload))
        self.menu.add(rumps.MenuItem("❌ 退出", callback=self._on_quit))

    # ── Actions ──────────────────────────────────────────────────

    def _on_copy(self, text, sender=None):
        copy_clipboard(text)
        paste_clipboard()
        rumps.notification("CC Clip", "已粘贴", text[:50], sound=False)

    def _on_clear_input(self, sender=None):
        clear_input()
        rumps.notification("CC Clip", "已清空输入栏", "", sound=False)

    def _on_search(self, _):
        """Show search dialog, then let user pick from filtered results."""
        query = osascript_dialog("搜索指令（输入关键词）：")
        if not query:
            return
        query = query.lower()
        results = [c for c in self.commands
                   if query in c["text"].lower() or query in c.get("tag", "").lower()
                   or query in c["category"].lower()]
        if not results:
            rumps.alert("无结果", f"未找到匹配「{query}」的指令")
            return
        if len(results) == 1:
            copy_clipboard(results[0]["text"])
            paste_clipboard()
            rumps.notification("CC Clip", "已粘贴", results[0]["text"][:50], sound=False)
            return
        # Multiple results → prompt to pick via osascript list
        self._show_picker(results)

    def _show_picker(self, results):
        """osascript list dialog for multiple search results."""
        items = [osascript_escape(f"{r['text'][:50]}  [{r.get('tag','')}]") for r in results]
        item_str = '", "'.join(items)
        script = f'''set choices to {{"{item_str}"}}
set choice to choose from list choices with title "匹配结果" default items {{item 1 of choices}}
if choice is not false then return item 1 of choice
return ""'''
        try:
            proc = subprocess.run(
                ["osascript", "-e", script],
                capture_output=True, text=True, timeout=30,
            )
            picked = proc.stdout.strip()
            if not picked:
                return
            for r in results:
                if r["text"] in picked:
                    copy_clipboard(r["text"])
                    paste_clipboard()
                    rumps.notification("CC Clip", "已粘贴", r["text"][:50], sound=False)
                    return
        except Exception:
            pass

    def _on_add(self, _):
        """Add a new command via osascript dialogs."""
        cat = osascript_dialog("分类（如：会话结束）：")
        if cat is None or cat == "":
            return
        text = osascript_dialog("指令内容：")
        if text is None or text == "":
            return
        tag = osascript_dialog("标签（如：收工）：", default="自定义")
        if tag is None:
            return

        self.commands.append({"category": cat, "text": text, "tag": tag or "自定义"})
        save_commands(self.commands)
        self.refresh_menu()
        rumps.notification("CC Clip", "已添加", f"{text[:40]}...", sound=False)

    def _on_delete(self, _):
        """Delete a command via osascript picker list."""
        if not self.commands:
            rumps.alert("无指令", "没有可以删除的指令")
            return
        items = [osascript_escape(f"{c['category']} | {c['text'][:50]}  [{c.get('tag','')}]") for c in self.commands]
        item_str = '", "'.join(items)
        script = f'''set choices to {{"{item_str}"}}
set choice to choose from list choices with title "删除指令" with prompt "选择要删除的指令："
if choice is not false then return item 1 of choice
return ""'''
        try:
            proc = subprocess.run(
                ["osascript", "-e", script],
                capture_output=True, text=True, timeout=30,
            )
            picked = proc.stdout.strip()
            if not picked:
                return
            # Find and remove the picked command
            for i, c in enumerate(self.commands):
                label = f"{c['category']} | {c['text'][:50]}  [{c.get('tag','')}]"
                if label == picked:
                    removed = self.commands.pop(i)
                    save_commands(self.commands)
                    self.refresh_menu()
                    rumps.notification("CC Clip", "已删除", f"{removed['text'][:40]}", sound=False)
                    return
        except Exception:
            pass

    def _on_edit(self, _):
        """Edit an existing command via picker + dialogs."""
        if not self.commands:
            rumps.alert("无指令", "没有可以编辑的指令")
            return
        items = [osascript_escape(f"{c['category']} | {c['text'][:50]}  [{c.get('tag','')}]") for c in self.commands]
        item_str = '", "'.join(items)
        script = f'''set choices to {{"{item_str}"}}
	set choice to choose from list choices with title "编辑指令" with prompt "选择要编辑的指令："
	if choice is not false then return item 1 of choice
	return ""'''
        try:
            proc = subprocess.run(
                ["osascript", "-e", script],
                capture_output=True, text=True, timeout=30,
            )
            picked = proc.stdout.strip()
            if not picked:
                return
            for i, c in enumerate(self.commands):
                label = f"{c['category']} | {c['text'][:50]}  [{c.get('tag','')}]"
                if label == picked:
                    cat = osascript_dialog("分类：", default=c["category"])
                    if cat is None:
                        return
                    text = osascript_dialog("指令内容：", default=c["text"])
                    if text is None or text == "":
                        return
                    tag = osascript_dialog("标签：", default=c.get("tag", ""))
                    if tag is None:
                        return
                    self.commands[i] = {"category": cat, "text": text, "tag": tag or "自定义"}
                    save_commands(self.commands)
                    self.refresh_menu()
                    rumps.notification("CC Clip", "已编辑", f"{text[:40]}...", sound=False)
                    return
        except Exception:
            pass

    def _on_reload(self, _):
        """Reload commands from disk."""
        self.commands = load_commands()
        self.refresh_menu()
        rumps.notification("CC Clip", "已重新加载", f"{len(self.commands)} 条指令", sound=False)

    def _on_quit(self, _):
        rumps.quit_application()


if __name__ == "__main__":
    CCClipboard().run()

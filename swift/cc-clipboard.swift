import SwiftUI
import AppKit

// MARK: - Data Model

struct CommandItem: Codable, Identifiable, Equatable {
    var id = UUID()
    var category: String
    var text: String
    var tag: String

    static func == (lhs: CommandItem, rhs: CommandItem) -> Bool { lhs.id == rhs.id }
}

// MARK: - Store

class CommandStore: ObservableObject {
    @Published var commands: [CommandItem] = []
    private let filePath: String

    static let defaultCommands: [CommandItem] = [
        .init(category: "会话结束", text: "更新 CLAUDE.md，记录今天完成了什么、下次从哪里继续", tag: "收工"),
        .init(category: "会话结束", text: "复盘，总结教训，写入规则", tag: "复盘"),
        .init(category: "会话结束", text: "记一条：DOC: [领域] — [教训]", tag: "事中标记"),
        .init(category: "会话结束", text: "子项目状态已变化，更新索引表状态列", tag: "收工"),
        .init(category: "DOC: 标记模板", text: "记一条：DOC: testing — integration tests must hit real DB, not mocks", tag: "模板"),
        .init(category: "DOC: 标记模板", text: "记一条：DOC: architecture — webhook handlers must be idempotent", tag: "模板"),
        .init(category: "DOC: 标记模板", text: "记一条：DOC: workflow — ≥2 次重复即提升为规则/skill", tag: "模板"),
        .init(category: "上下文管理", text: "/compact", tag: "压缩"),
        .init(category: "上下文管理", text: "/clear", tag: "清空"),
        .init(category: "上下文管理", text: "/usage", tag: "成本"),
        .init(category: "上下文管理", text: "/model", tag: "当前模型"),
        .init(category: "上下文管理", text: "清空当前输入栏", tag: "清输入"),
        .init(category: "模型切换", text: "/model claude-sonnet-4-6", tag: "日常"),
        .init(category: "模型切换", text: "/model claude-opus-4-7", tag: "复杂推理"),
        .init(category: "决策记录", text: "这个决策值得记录，写入 decisions/ 吧", tag: "触发"),
        .init(category: "决策记录", text: "选了什么？依据？回头看的条件是什么？", tag: "模板"),
        .init(category: "知识沉淀", text: "这是第三次做同一件事了，提升为 skill 或写入 rules", tag: "≥2次"),
        .init(category: "知识沉淀", text: "将重复模式写入 internal_cookbook/", tag: "cookbook"),
        .init(category: "质量门", text: "npx tsc --noEmit", tag: "TS"),
        .init(category: "质量门", text: "grep -c 'TODO\\|placeholder\\|示例' output.html", tag: "预检"),
        .init(category: "质量门", text: "grep -nE '[0-9]+' output.md | head -20", tag: "数字溯源"),
        .init(category: "穴居人模式", text: "只说结论，不说废话。输出密度最大化。", tag: "原则"),
        .init(category: "穴居人模式", text: "删除礼貌填充、结构冗余、结尾总结。", tag: "反模式"),
        .init(category: "穴居人模式", text: "中间数据 >200 token → 写文件传路径，不嵌入 prompt。", tag: "规则2"),
        .init(category: "MCP 审计", text: "检查当前 MCP 列表：cat .mcp.json", tag: "审计"),
        .init(category: "MCP 审计", text: "降级链：Firecrawl → Scrapling → Apify → Browserbase → WebSearch", tag: "降级"),
        .init(category: "调试哲学", text: "改 vault 不改 agent —— 先诊断输入再升级工具", tag: "原则"),
        .init(category: "调试哲学", text: "CLAUDE.md 规则探针：发一个明显违规请求，看是否被拦截", tag: "版本升级"),
        .init(category: "调试哲学", text: "Opus 4.7 下显式 Use subagent(...) 语法委托", tag: "prompt"),
    ]

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let dir = home.appendingPathComponent(".cc-clipboard")
        filePath = dir.appendingPathComponent("commands.json").path
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        load()
    }

    func load() {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)),
              let decoded = try? JSONDecoder().decode([CommandItem].self, from: data) else {
            commands = Self.defaultCommands
            save()
            return
        }
        commands = decoded
    }

    func save() {
        guard let data = try? JSONEncoder().encode(commands) else { return }
        try? data.write(to: URL(fileURLWithPath: filePath), options: .atomic)
    }

    func add(_ item: CommandItem) {
        commands.append(item)
        save()
    }

    func update(_ item: CommandItem) {
        guard let i = commands.firstIndex(where: { $0.id == item.id }) else { return }
        commands[i] = item
        save()
    }

    func delete(_ item: CommandItem) {
        commands.removeAll { $0.id == item.id }
        save()
    }

    func categories() -> [String] {
        Array(Set(commands.map(\.category))).sorted()
    }

    func commands(for category: String) -> [CommandItem] {
        commands.filter { $0.category == category }
    }
}

// MARK: - App

@main
struct CCClipboardApp: App {
    @StateObject private var store = CommandStore()

    var body: some Scene {
        MenuBarExtra("CC Clip", systemImage: "list.clipboard") {
            ContentView(store: store)
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - Content

struct ContentView: View {
    @ObservedObject var store: CommandStore
    @State private var searchText = ""
    @State private var showingAdd = false
    @State private var editingItem: CommandItem?

    var filteredCategories: [(String, [CommandItem])] {
        let cats = store.categories()
        if searchText.isEmpty {
            return cats.map { ($0, store.commands(for: $0)) }
        }
        return cats.compactMap { cat in
            let items = store.commands(for: cat).filter {
                $0.text.localizedCaseInsensitiveContains(searchText) ||
                $0.tag.localizedCaseInsensitiveContains(searchText) ||
                $0.category.localizedCaseInsensitiveContains(searchText)
            }
            return items.isEmpty ? nil : (cat, items)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜索指令...", text: $searchText)
                    .textFieldStyle(.plain)
                Button(action: { showingAdd = true }) {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.plain)
                .help("新增指令")
            }
            .padding(10)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Command list
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(filteredCategories, id: \.0) { category, items in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(category)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .padding(.horizontal, 10)
                                .padding(.top, items.first?.category == filteredCategories.first?.0 ? 8 : 4)

                            ForEach(items) { item in
                                CommandRow(item: item, store: store, onEdit: { editingItem = $0 })
                            }
                        }
                    }
                }
                .padding(.bottom, 8)
            }
            .frame(height: min(CGFloat(filteredCategories.count * 80 + 40), 420))

            Divider()

            // Footer
            HStack {
                Text("\(store.commands.count) 条指令")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Button("打开数据目录") { openDataDir() }
                    .font(.caption2)
                    .buttonStyle(.link)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(width: 360)
        .sheet(isPresented: $showingAdd) {
            EditSheet(store: store, item: nil, isPresented: $showingAdd)
        }
        .sheet(item: $editingItem) { item in
            EditSheet(store: store, item: item, isPresented: Binding(
                get: { editingItem != nil },
                set: { if !$0 { editingItem = nil } }
            ))
        }
    }

    func openDataDir() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let dir = home.appendingPathComponent(".cc-clipboard")
        NSWorkspace.shared.open(dir)
    }
}

// MARK: - Command Row

struct CommandRow: View {
    let item: CommandItem
    @ObservedObject var store: CommandStore
    var onEdit: (CommandItem) -> Void

    @State private var copied = false

    var body: some View {
        HStack(spacing: 8) {
            Text(item.text)
                .font(.system(size: 12, design: .monospaced))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(item.tag)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.accentColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(4)

            Button(action: copy) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 11))
                    .frame(width: 20)
            }
            .buttonStyle(.plain)
            .help("复制")
            .foregroundColor(copied ? .green : .secondary)

            Button(action: { onEdit(item) }) {
                Image(systemName: "pencil")
                    .font(.system(size: 10))
                    .frame(width: 16)
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .help("编辑")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture { copy() }
    }

    func copy() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(item.text, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
    }
}

// MARK: - Edit Sheet

struct EditSheet: View {
    @ObservedObject var store: CommandStore
    var item: CommandItem?
    @Binding var isPresented: Bool

    @State private var category: String = ""
    @State private var text: String = ""
    @State private var tag: String = ""

    private var isEditing: Bool { item != nil }

    var body: some View {
        VStack(spacing: 16) {
            Text(isEditing ? "编辑指令" : "新增指令")
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                Text("分类").font(.caption).foregroundColor(.secondary)
                TextField("如：会话结束、质量门", text: $category)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("指令内容").font(.caption).foregroundColor(.secondary)
                TextEditor(text: $text)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(height: 60)
                    .border(Color.gray.opacity(0.3))
                    .cornerRadius(4)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("标签").font(.caption).foregroundColor(.secondary)
                TextField("如：收工、复盘", text: $tag)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                if isEditing {
                    Button("删除", role: .destructive) {
                        store.delete(item!)
                        isPresented = false
                    }
                }
                Spacer()
                Button("取消") { isPresented = false }
                Button(isEditing ? "保存" : "添加") {
                    guard !text.isEmpty else { return }
                    let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmedText.isEmpty else { return }
                    if isEditing, let existing = item {
                        var updated = existing
                        updated.category = category
                        updated.text = trimmedText
                        updated.tag = tag
                        store.update(updated)
                    } else {
                        store.add(CommandItem(category: category.isEmpty ? "未分类" : category,
                                              text: trimmedText,
                                              tag: tag.isEmpty ? "自定义" : tag))
                    }
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 380)
        .onAppear {
            if let item = item {
                category = item.category
                text = item.text
                tag = item.tag
            }
        }
    }
}

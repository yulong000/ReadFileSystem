//
//  AppDelegate.swift
//  FileSystem
//
//  Created by 魏宇龙 on 2026/1/14.
//

import Cocoa
import YLCategory_Swift_MacOS

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet var window: NSWindow!
    @IBOutlet var leftOutlineView: NSOutlineView!
    @IBOutlet var rightOutlinView: NSOutlineView!
    
    var currentPaths: Set<String>?
    var otherPaths: Set<String>?
    
    var currentRootNode: DiffNode = DiffNode(name: "/")
    var otherRootNode: DiffNode = DiffNode(name: "/")
    
    // MARK: 开始解析
    @IBAction func beginParser(_ sender: NSButton) {
        YLHud.showLoading("开始解析...", to: window)
        
        Async.global {
            self.currentPaths = YLTool.scan()
            self.currentRootNode = YLTool.build(from: self.currentPaths ?? Set())
        } main: {
            YLHud.hideHUDForWindow(self.window)
            self.leftOutlineView.reloadData()
        }
    }
    
    // MARK: 导出
    @IBAction func export(_ sender: NSButton) {
        guard let currentPath = currentPaths else {
            YLHud.showError("先点击 “开始解析”", to: window)
            return
        }
        
        NSOpenPanel.open(title: "导出", message: "导出目录结构到本地", canChooseFiles: false, canChooseDirectories: true) { [self] resp, urls in
            guard resp == .OK, let url = urls?.first else { return }
            do {
                let fileUrl = url.appendingPathComponent("DiskFileTree.json")
                try YLTool.export(paths: currentPath, to: fileUrl)
                YLHud.showSuccess("导出成功!", to: window)
            } catch {
                YLHud.showSuccess("导出失败!", to: window)
                YLLog("导出失败：\(error)")
            }
        }
    }
    
    // MARK: 对比
    @IBAction func compare(_ sender: NSButton) {
        guard let currentPaths = currentPaths, let otherPaths = otherPaths else {
            YLHud.showError("两侧内容均不能为空", to: window)
            return
        }
        currentRootNode = YLTool.diff(a: currentPaths, b: otherPaths)
        otherRootNode = YLTool.diff(a: otherPaths, b: currentPaths)
        leftOutlineView.reloadData()
        rightOutlinView.reloadData()
    }
    
    // MARK: 导入
    @IBAction func importFile(_ sender: NSButton) {
        NSOpenPanel.open(title: "导入", message: "导入其他的目录结构", canChooseFiles: true, canChooseDirectories: false) { [self] resp, urls in
            guard resp == .OK, let url = urls?.first else { return }
            do {
                let path = try YLTool.load(from: url)
                otherPaths = Set(path.paths)
                YLHud.showLoading("导入中...", to: window)
                Async.global { [self] in
                    otherRootNode = YLTool.build(from: otherPaths ?? Set())
                } main: { [self] in
                    YLHud.hideHUDForWindow(window)
                    rightOutlinView.reloadData()
                    YLHud.showSuccess("导入成功!", to: window)
                }
            } catch {
                YLHud.showSuccess("导入失败!", to: window)
                YLLog("导入失败：\(error)")
            }
        }
    }
    

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }


}

extension AppDelegate: NSOutlineViewDelegate, NSOutlineViewDataSource {
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        guard let node = item as? DiffNode else { return 1 }
        return node.children.count
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        guard let node = item as? DiffNode else { return true }
        return !node.children.isEmpty
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if outlineView == leftOutlineView {
            guard let node = item as? DiffNode else { return currentRootNode }
            return node.sortedNodes[index]
        } else {
            guard let node = item as? DiffNode else { return otherRootNode }
            return node.sortedNodes[index]
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let node = item as? DiffNode else { return nil }
        let rowView = outlineView.makeView(withIdentifier: RowView.ID, owner: self) as? RowView ?? RowView()
        rowView.model = node
        return rowView
    }
    
    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
        return 25
    }
    
    
}

class RowView: YLFlipView {
    
    static let ID = NSUserInterfaceItemIdentifier("RowView")
    
    // MARK: - 属性
    
    var model: DiffNode? {
        didSet {
            titleLabel.stringValue = model?.name ?? ""
            guard let diff = model?.diff else {
                titleLabel.textColor = .textColor
                return
            }
            switch diff {
            case .same:
                titleLabel.textColor = .textColor
            case .onlyInA:
                titleLabel.textColor = .green
            case .onlyInB:
                titleLabel.textColor = .red
            case .mixed:
                titleLabel.textColor = .yellow
            }
        }
    }
    
    // MARK: - 方法
    
    // MARK: - 初始化 & 布局
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        initialize()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initialize()
    }
    
    private func initialize() {
        addSubview(titleLabel)
    }
    
    override func layout() {
        super.layout()
        titleLabel.sizeIs(width, 22).centerEqualToSuper()
    }
    
    // MARK: - UI组件
    
    lazy var titleLabel: NSTextField = {
        let title = NSTextField(labelWithString: "")
        return title
    }()
}


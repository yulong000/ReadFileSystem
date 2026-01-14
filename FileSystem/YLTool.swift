//
//  YLTool.swift
//  FileSystem
//
//  Created by 魏宇龙 on 2026/1/14.
//
//  Copyright Tianjin Huayue Wanlian Technology Co., Ltd. All Rights Reserved.
//  天津华悦万联科技有限公司版权所有，保留一切权利。
//
    
import YLCategory_Swift_MacOS

class YLTool {
    
    /// 排除的路径
    static let defaultExcludedPrefixes: [String] = [
        "/Volumes",
        "/System/Volumes/Preboot",
        "/System/Volumes/Update",
        "/private/var/vm",
        "/dev",
        "/.Spotlight-V100"
    ]
    
    // MARK: 开始扫描路径
    static func scan(root: String = "/") -> Set<String> {
        var results = Set<String>()
        let fm = FileManager.default
        let rootUrl = root.fileUrl
        
        guard let enumerator = fm.enumerator(at: rootUrl, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return results
        }
        
        for case let url as URL in enumerator {
            let path = url.path
            if defaultExcludedPrefixes.contains(where: { path.hasPrefix($0) }) {
                enumerator.skipDescendants()
                continue
            }
            results.insert(path)
        }
        return results
    }
    
    // MARK: 导出数据
    static func export(paths: Set<String>, to url: URL) throws {
        let path = Path(root: "/", paths: paths.sorted())
        let data = try JSONEncoder().encode(path)
        try data.write(to: url)
    }
    
    // MARK: 导入数据
    static func load(from url: URL) throws -> Path {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Path.self, from: data)
    }
    
    // MARK: 合并树状图
    static func build(from paths: Set<String>) -> DiffNode {
        let root = DiffNode(name: "/")
        
        for path in paths {
            let components = path.split(separator: "/").map(String.init)
            var current = root
            
            for comp in components {
                if current.children[comp] == nil {
                    current.children[comp] = DiffNode(name: comp)
                    current.sorted()
                }
                current = current.children[comp]!
            }
        }
        
        return root
    }
    
    // MARK: 对比不同
    static func diff(a: Set<String>, b: Set<String>) -> DiffNode {
        let onlyA = a.subtracting(b)
        let onlyB = b.subtracting(a)

        var root = DiffNode(name: "/")

        for path in onlyA {
            insert(path: path, into: &root, diff: .onlyInA)
        }
        for path in onlyB {
            insert(path: path, into: &root, diff: .onlyInB)
        }

        // ⭐ 关键：第二步，统一回溯计算目录 diff
        root.updateDiffFromChildren()

        return root
    }
    
    private static func insert(path: String, into node: inout DiffNode, diff: DiffType) {
        let components = path.split(separator: "/").map(String.init)
        var current = node
        
        for (index, comp) in components.enumerated() {
            if current.children[comp] == nil {
                current.children[comp] = DiffNode(name: comp)
                current.sorted()
            }
            if index == components.count - 1 {
                current.children[comp]?.diff = diff
                current.sorted()
            }
            current = current.children[comp]!
        }
    }
    
}


struct Path: Codable {
    let root: String
    let paths: [String]
}

enum DiffType {
    case same
    case onlyInA
    case onlyInB
    case mixed
}

class DiffNode {
    let name: String
    var children: [String: DiffNode] = [:]
    var diff: DiffType = .same
    
    /// 排序后的子节点
    var sortedNodes: [DiffNode] = []
    
    init(name: String, diff: DiffType = .same) {
        self.name = name
        self.diff = diff
    }
    
    func sorted() {
        sortedNodes = children.values.sorted { $0.name < $1.name }
    }
    
    func updateDiffFromChildren() {
        if children.isEmpty {
            return
        }

        for key in children.keys {
            children[key]?.updateDiffFromChildren()
        }

        let childDiffs = Set(children.values.map { $0.diff })

        if childDiffs.count == 1 {
            diff = childDiffs.first!
        } else {
            diff = .mixed
        }
    }
}


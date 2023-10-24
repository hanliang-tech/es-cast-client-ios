//
//  EsAction.swift
//
//
//  Created by BM on 2023/10/18.
//

import Foundation

/// 发送操作
public class EsAction {
    var data: [String: Any] = [:]

    /// 初始化EsAction
    /// - Parameter data: 包含操作数据的字典
    init(data: [String: Any]) {
        self.data = data
        self.data["from"] = Bundle.main.bundleIdentifier
    }

    /// 设置操作的标志
    /// - Parameter flags: 操作标志
    /// - Returns: 返回当前的EsAction以支持链式调用
    public func flags(_ flags: Int) -> EsAction {
        data["flags"] = flags
        return self
    }

    /// 设置操作的闪屏值
    /// - Parameter splash: 闪屏值
    /// - Returns: 返回当前的EsAction以支持链式调用
    public func splash(_ splash: Splash) -> EsAction {
        data["splash"] = splash.rawValue
        return self
    }

    /// 设置操作的参数
    /// - Parameter args: 操作参数
    /// - Returns: 返回当前的EsAction以支持链式调用
    public func args(_ args: Int) -> EsAction {
        data["args"] = args
        return self
    }

    /// 设置操作的参数
    /// - Parameter args: 操作参数
    /// - Returns: 返回当前的EsAction以支持链式调用
    public func args(_ args: String) -> EsAction {
        data["args"] = args
        return self
    }

    /// 设置操作的参数
    /// - Parameter args: 操作参数
    /// - Returns: 返回当前的EsAction以支持链式调用
    public func args(_ args: [String: Any]) -> EsAction {
        if let old = data["args"] as? [String: Any] {
            data["args"] = old.merging(args) { _, new in new }
        } else {
            data["args"] = args
        }
        return self
    }
}


// MARK: - Maker

public extension EsAction {
    /// 创建一个启动ES操作的EsAction
    /// - Parameter apk: 要启动的APK的名称
    /// - Returns: 返回包含启动ES操作数据的EsAction
    static func makeStartEs(pkg: String) -> EsAction {
        EsAction(data: ["action": "start_es", "pkg": pkg])
    }

    /// 创建一个启动应用程序操作的EsAction
    /// - Parameter apk: 要启动的应用程序的名称
    /// - Returns: 返回包含启动应用程序操作数据的EsAction
    static func makeStartApp(pkg: String) -> EsAction {
        EsAction(data: ["action": "start_app", "pkg": pkg])
    }

    /// 创建一个关闭应用程序操作的EsAction
    /// - Parameters:
    ///   - pkgs: 要关闭的应用程序包的名称
    /// - Returns: 返回包含关闭应用程序操作数据的EsAction
    static func makeCloseApp(pkgs: String...) -> EsAction {
        EsAction(data: ["action": "es_cmd",
                        "args": ["intention": "es_close",
                                 "data": ["pkgs": pkgs]
                        ]]
        )
    }

    /// 创建一个远程控制操作的EsAction
    /// - Parameters:
    ///   - key: 远程控制键的枚举值
    /// - Returns: 返回包含远程控制操作数据的EsAction
    static func makeRemoteControl(key: ESRemoteControlKey) -> EsAction {
        EsAction(data: ["action": "es_cmd",
                        "args": ["intention": "es_remote_control",
                                 "data": ["keycode": key.value]
                        ]]
        )
    }

    /// 创建一个查询操作的EsAction
    /// - Parameters:
    ///   - keyword: 查询关键字
    /// - Returns: 返回包含查询操作数据的EsAction
    static func makeQuery(keyword: String) -> EsAction {
        EsAction(data: ["action": "es_cmd",
                        "args": ["intention": "es_query",
                                 "data": ["keyword": keyword]
                        ]]
        )
    }

    /// 创建一个查询应用程序列表操作的EsAction
    /// - Returns: 返回包含查询应用程序列表操作数据的EsAction
    static func makeQueryApps() -> EsAction {
        EsAction(data: ["action": "es_cmd",
                        "args": ["intention": "es_query",
                                 "data": ["keyword": "running_es_apps"]
                        ]]
        )
    }

    /// 创建一个查询顶部应用程序操作的EsAction
    /// - Returns: 返回包含查询顶部应用程序操作数据的EsAction
    static func makeQueryTopApp() -> EsAction {
        EsAction(data: ["action": "es_cmd",
                        "args": ["intention": "es_query",
                                 "data": ["keyword": "top_es_app"]
                        ]]
        )
    }

    /// 创建一个自定义操作的EsAction
    /// - Parameters:
    ///   - name: 自定义操作的名称
    /// - Returns: 返回包含自定义操作数据的EsAction
    static func makeCustom(name: String) -> EsAction {
        EsAction(data: ["action": name])
    }
}

public extension EsAction {
    /// ES远程控制键的枚举值
    enum Splash: Int {
        case display = 0
        case noIcon = 1
        case none = -1
    }
}

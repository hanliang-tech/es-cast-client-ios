//
//  ESRemoteControlKey.swift
//
//
//  Created by BM on 2023/10/18.
//

import Foundation

/// 遥控器按键
public enum ESRemoteControlKey: CustomStringConvertible, Hashable {
    // 预定义的遥控器按键
    case home // 主界面
    case back // 返回
    case up // 上
    case down // 下
    case left // 左
    case right // 右
    case ok // 确定
    case volumeUp // 音量+
    case volumeDown // 音量-
    case menu // 菜单

    // 自定义遥控器按键，包括名称和值
    case custom(name: String, value: Int)

    // 描述属性，返回按键的名称
    public var description: String {
        switch self {
        case .home: return "主界面"
        case .back: return "返回"
        case .up: return "上"
        case .down: return "下"
        case .left: return "左"
        case .right: return "右"
        case .ok: return "确定"
        case .volumeUp: return "音量+"
        case .volumeDown: return "音量-"
        case .menu: return "菜单"
        case .custom(let name, _): return name
        }
    }

    // 值属性，返回按键的整数值
    public var value: Int {
        switch self {
        case .home: return 3
        case .back: return 4
        case .up: return 19
        case .down: return 20
        case .left: return 21
        case .right: return 22
        case .ok: return 23
        case .volumeUp: return 24
        case .volumeDown: return 25
        case .menu: return 82
        case .custom(_, let value): return value
        }
    }
}

import Foundation

public enum TriggerKey: String, CaseIterable {
    case fn = "fn"
    case f5 = "f5"
    case spacebar = "spacebar"
    case mouse = "mouse"

    public var displayName: String {
        switch self {
        case .fn: return "Fn"
        case .f5: return "F5"
        case .spacebar: return "Spacebar"
        case .mouse: return "Mouse Button"
        }
    }

    public var keyLabel: String {
        switch self {
        case .fn: return "fn"
        case .f5: return "F5"
        case .spacebar: return "␣"
        case .mouse: return "🖱"
        }
    }

    public static var saved: TriggerKey {
        let raw = UserDefaults.standard.string(forKey: "triggerKey") ?? "fn"
        return TriggerKey(rawValue: raw) ?? .fn
    }

    public func save() {
        UserDefaults.standard.set(self.rawValue, forKey: "triggerKey")
    }
}

public enum TriggerMode: String, CaseIterable {
    case hold = "hold"
    case toggle = "toggle"

    public var displayName: String {
        switch self {
        case .hold: return "Hold"
        case .toggle: return "Toggle"
        }
    }

    public static var saved: TriggerMode {
        let raw = UserDefaults.standard.string(forKey: "triggerMode") ?? "hold"
        return TriggerMode(rawValue: raw) ?? .hold
    }

    public func save() {
        UserDefaults.standard.set(rawValue, forKey: "triggerMode")
    }
}

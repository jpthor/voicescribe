import Foundation

public struct KeyboardBinding: Codable, Equatable {
    public let keyCode: Int64
    public let modifiers: UInt64
    public let displayName: String

    public init(keyCode: Int64, modifiers: UInt64, displayName: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.displayName = displayName
    }

    public static let f5 = KeyboardBinding(keyCode: 96, modifiers: 0, displayName: "F5")

    public static var saved: KeyboardBinding {
        guard let data = UserDefaults.standard.data(forKey: "keyboardBinding"),
              let binding = try? JSONDecoder().decode(KeyboardBinding.self, from: data) else {
            return .f5
        }
        return binding
    }

    public func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "keyboardBinding")
        }
    }
}

public enum TriggerInputSource: Equatable {
    case keyboard
    case mouse
}

import Foundation

/// A Sendable JSON value used for TinyFish API and CDP payloads.
public enum TinyFishJSONValue: Sendable, Equatable {
    /// A JSON object.
    case object([String: TinyFishJSONValue])
    /// A JSON array.
    case array([TinyFishJSONValue])
    /// A JSON string.
    case string(String)
    /// A JSON number.
    case number(Double)
    /// A JSON Boolean.
    case bool(Bool)
    /// JSON null.
    case null

    /// Returns an object member when this value is an object.
    public subscript(_ key: String) -> TinyFishJSONValue? {
        guard case .object(let object) = self else { return nil }
        return object[key]
    }

    /// Returns the string value when this value is a string.
    public var stringValue: String? {
        guard case .string(let value) = self else { return nil }
        return value
    }

    /// Returns the numeric value when this value is a number.
    public var numberValue: Double? {
        guard case .number(let value) = self else { return nil }
        return value
    }

    /// Returns the integer value when this value is an integral number.
    public var intValue: Int? {
        guard let numberValue else { return nil }
        let rounded = numberValue.rounded()
        guard rounded == numberValue else { return nil }
        return Int(rounded)
    }

    /// Returns the Boolean value when this value is a Boolean.
    public var boolValue: Bool? {
        guard case .bool(let value) = self else { return nil }
        return value
    }

    /// Returns the array value when this value is an array.
    public var arrayValue: [TinyFishJSONValue]? {
        guard case .array(let value) = self else { return nil }
        return value
    }

    /// Returns a stable compact JSON string for display or diagnostics.
    public var compactDescription: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(self),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
    }
}

extension TinyFishJSONValue: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([TinyFishJSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: TinyFishJSONValue].self))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

import Foundation

enum JSONValue: Codable, Equatable {
    case object([String: JSONValue]), array([JSONValue]), string(String), number(Decimal), bool(Bool), null
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let value = try? c.decode(Bool.self) { self = .bool(value) }
        else if let value = try? c.decode(String.self) { self = .string(value) }
        else if let value = try? c.decode(Decimal.self) { self = .number(value) }
        else if let value = try? c.decode([JSONValue].self) { self = .array(value) }
        else { self = .object(try c.decode([String: JSONValue].self)) }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self { case .object(let x): try c.encode(x); case .array(let x): try c.encode(x); case .string(let x): try c.encode(x); case .number(let x): try c.encode(x); case .bool(let x): try c.encode(x); case .null: try c.encodeNil() }
    }
    var object: [String: JSONValue] { if case .object(let x) = self { return x }; return [:] }
    var array: [JSONValue] { if case .array(let x) = self { return x }; return [] }
    var text: String {
        switch self { case .string(let x): return x; case .number(let x): return NSDecimalNumber(decimal: x).stringValue; case .bool(let x): return x ? "true" : "false"; default: return "" }
    }
    var decimal: Decimal? { if case .number(let x) = self { return x }; return Decimal(string: text) }
    var bool: Bool { if case .bool(let x) = self { return x }; return false }
}
extension Dictionary where Key == String, Value == JSONValue {
    func text(_ key: String) -> String { self[key]?.text ?? "" }
    func list(_ key: String) -> [JSONValue] { self[key]?.array ?? [] }
}

import Foundation

// MARK: - Top-level manifest

/// Mirrors the JSON produced by `swift package dump-package`.
struct PackageManifest: Decodable {
    let name: String
    let targets: [TargetManifest]
}

// MARK: - Target

struct TargetManifest: Decodable {
    let name: String
    /// "regular" | "executable" | "test" | "system" | "plugin" | "macro"
    let type: String
    let dependencies: [TargetDependency]

    enum CodingKeys: String, CodingKey { case name, type, dependencies }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        type = try c.decode(String.self, forKey: .type)
        // `dependencies` can be absent on targets with no deps.
        dependencies = (try? c.decode([TargetDependency].self, forKey: .dependencies)) ?? []
    }
}

// MARK: - Target dependency

/// A single dependency declared on a target.
///
/// SPM encodes each dependency as a single-key object whose key identifies the
/// dependency kind and whose value is a heterogeneous positional array:
///
///   {"byName":  ["TargetName", <condition|null>]}
///   {"target":  ["TargetName", <condition|null>]}
///   {"product": ["ProductName", "PackageName", <aliases|null>, <condition|null>]}
enum TargetDependency: Decodable {
    /// Unqualified reference — resolves to a target in the same package.
    case byName(String)
    /// Explicit same-package target reference.
    case target(String)
    /// A product from an external Swift package.
    case product(name: String, package: String)

    // MARK: Decoding

    private struct DynamicKey: CodingKey {
        var stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { nil }
        init?(intValue: Int) { nil }
    }

    /// Safely decodes the first element of the positional array, which may
    /// contain a mix of String, null, and nested objects.
    private enum LooseString: Decodable {
        case value(String)
        case null

        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            if c.decodeNil() { self = .null; return }
            self = .value(try c.decode(String.self))
        }

        var string: String? {
            if case .value(let s) = self { return s }
            return nil
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicKey.self)
        guard let key = container.allKeys.first else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath,
                      debugDescription: "Dependency object has no keys"))
        }

        switch key.stringValue {
        case "byName":
            let arr = try container.decode([LooseString].self, forKey: key)
            guard let name = arr.first?.string else {
                throw DecodingError.dataCorrupted(
                    .init(codingPath: decoder.codingPath,
                          debugDescription: "byName array missing target name"))
            }
            self = .byName(name)

        case "target":
            let arr = try container.decode([LooseString].self, forKey: key)
            guard let name = arr.first?.string else {
                throw DecodingError.dataCorrupted(
                    .init(codingPath: decoder.codingPath,
                          debugDescription: "target array missing target name"))
            }
            self = .target(name)

        case "product":
            let arr = try container.decode([LooseString].self, forKey: key)
            guard arr.count >= 2,
                  let productName = arr[0].string,
                  let packageName = arr[1].string else {
                throw DecodingError.dataCorrupted(
                    .init(codingPath: decoder.codingPath,
                          debugDescription: "product array missing name or package"))
            }
            self = .product(name: productName, package: packageName)

        default:
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath,
                      debugDescription: "Unknown dependency kind: \(key.stringValue)"))
        }
    }
}

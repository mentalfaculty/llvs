//
//  Store.swift
//  llvs
//
//  Created by Drew McCormack on 31/10/2018.
//

import Foundation

public final class Store {
    
    enum Error: Swift.Error {
        case attemptToLocateUnversionedValue
    }
    
    public let rootDirectoryURL: URL
    public let valuesDirectoryURL: URL
    public let versionsDirectoryURL: URL
    public let filtersDirectoryURL: URL
    
    fileprivate let fileManager = FileManager()
    fileprivate let encoder = JSONEncoder()
    fileprivate let decoder = JSONDecoder()
    
    public init(rootDirectoryURL: URL) {
        self.rootDirectoryURL = rootDirectoryURL
        self.valuesDirectoryURL = rootDirectoryURL.appendingPathComponent("values")
        self.versionsDirectoryURL = rootDirectoryURL.appendingPathComponent("versions")
        self.filtersDirectoryURL = rootDirectoryURL.appendingPathComponent("filters")
        try? fileManager.createDirectory(at: self.rootDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        try? fileManager.createDirectory(at: self.valuesDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        try? fileManager.createDirectory(at: self.versionsDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        try? fileManager.createDirectory(at: self.filtersDirectoryURL, withIntermediateDirectories: true, attributes: nil)
    }
    
    @discardableResult public func addVersion(basedOn predecessors: Version.Predecessors?, saving values: inout [Value]) throws -> Version {
        let version = Version(predecessors: predecessors)
        values = values.map { value in
            var newValue = value
            newValue.version = version
            return newValue
        }
        
        try values.forEach { value in
            try self.store(value)
        }
        
        try store(version)
        
        return version
    }
    
    private func store(_ value: Value) throws {
        let (dir, file) = try fileSystemLocation(for: value)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        let data = try encoder.encode(value)
        try data.write(to: file)
    }
    
    internal func fetchValue(identifiedBy valueIdentifier: Value.Identifier, savedAtVersionIdentifiedBy versionIdentifier: Version.Identifier) throws -> Value? {
        let (_, file) = try fileSystemLocation(for: valueIdentifier, atVersionIdentifiedBy: versionIdentifier)
        guard let data = try? Data(contentsOf: file) else { return nil }
        let value = try decoder.decode(Value.self, from: data)
        return value
    }
    
    internal func fetchAllValues(identifiedBy valueIdentifier: Value.Identifier) throws -> [Value] {
        let valueDirectoryURL = itemURL(forRoot: valuesDirectoryURL, name: valueIdentifier.identifierString)
        let enumerator = fileManager.enumerator(at: valueDirectoryURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])!
        var values: [Value] = []
        for any in enumerator {
            guard let url = any as? URL, !url.hasDirectoryPath else { continue }
            guard let data = try? Data(contentsOf: url) else { continue }
            let value = try decoder.decode(Value.self, from: data)
            values.append(value)
        }
        return values
    }
    
    internal func allVersionIdentifiers(forValueIdentifiedBy valueIdentifier: Value.Identifier) throws -> [Version.Identifier] {
        let valueDirectoryURL = itemURL(forRoot: valuesDirectoryURL, name: valueIdentifier.identifierString)
        let enumerator = fileManager.enumerator(at: valueDirectoryURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])!
        var versionIdentifiers: [Version.Identifier] = []
        for any in enumerator {
            guard let url = any as? URL, !url.hasDirectoryPath else { continue }
            guard url.pathExtension == "json" else { continue }
            let valueDirComponents = valueDirectoryURL.standardizedFileURL.pathComponents
            let allComponents = url.standardizedFileURL.deletingPathExtension().pathComponents
            let versionComponents = allComponents[valueDirComponents.count...]
            let versionString = versionComponents.joined()
            versionIdentifiers.append(.init(identifierString: versionString))
        }
        return versionIdentifiers
    }
    
    private func fileSystemLocation(for value: Value) throws -> (directoryURL: URL, fileURL: URL) {
        guard let version = value.version else { throw Error.attemptToLocateUnversionedValue }
        return try fileSystemLocation(for: value.identifier, atVersionIdentifiedBy: version.identifier)
    }
    
    private func fileSystemLocation(for valueIdentifier: Value.Identifier, atVersionIdentifiedBy versionIdentifier: Version.Identifier) throws -> (directoryURL: URL, fileURL: URL) {
        let valueDirectoryURL = itemURL(forRoot: valuesDirectoryURL, name: valueIdentifier.identifierString)
        let versionName = versionIdentifier.identifierString + ".json"
        let fileURL = itemURL(forRoot: valueDirectoryURL, name: versionName, subDirectoryNameLength: 1)
        let directoryURL = fileURL.deletingLastPathComponent()
        return (directoryURL: directoryURL, fileURL: fileURL)
    }
    
    private func store(_ version: Version) throws {
        let (dir, file) = fileSystemLocation(for: version)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        let data = try encoder.encode(version)
        try data.write(to: file)
    }
    
    private func fileSystemLocation(for version: Version) -> (directoryURL: URL, fileURL: URL) {
        let fileURL = itemURL(forRoot: versionsDirectoryURL, name: version.identifier.identifierString)
        let directoryURL = fileURL.deletingLastPathComponent()
        return (directoryURL: directoryURL, fileURL: fileURL)
    }

}


fileprivate extension Store {
    
    func itemURL(forRoot rootDirectoryURL: URL, name: String, subDirectoryNameLength: UInt = 2) -> URL {
        guard name.count > subDirectoryNameLength else {
            return rootDirectoryURL.appendingPathComponent(name)
        }
        
        // Embed a subdirectory
        let index = name.index(name.startIndex, offsetBy: Int(subDirectoryNameLength))
        let prefix = String(name[..<index])
        let postfix = String(name[index...])
        let directory = rootDirectoryURL.appendingPathComponent(prefix).appendingPathComponent(postfix)
        
        return directory
    }
    
}
//
//  Query.swift
//  Parse
//
//  Created by Florent Vilmart on 17-07-23.
//  Copyright © 2017 Parse. All rights reserved.
//

import Foundation

public struct QueryConstraint: Encodable {
    public enum Comparator: String, CodingKey {
        case lessThan = "$lt"
        case lessThanOrEqualTo = "$lte"
        case greaterThan = "$gt"
        case greaterThanOrEqualTo = "$gte"
        case equals = "$eq"
        case notEqualTo = "$neq"
        case containedIn = "$in"
        case notContainedIn = "$nin"
        case exists = "$exists"
        case select = "$select"
        case dontSelect = "$dontSelect"
        case all = "$all"
        case regex = "$regex"
        case inQuery = "$inQuery"
    }

    var key: String
    var value: Encodable
    var op: Comparator

    public func encode(to encoder: Encoder) throws {
        if let value = value as? Date {
            return try value.encode(to: encoder)
        }
        try value.encode(to: encoder)
    }
}

public func > <T>(key: String, value: T) -> QueryConstraint where T: Encodable {
    return QueryConstraint(key: key, value: value, op: .greaterThan)
}

public func >= <T>(key: String, value: T) -> QueryConstraint where T: Encodable  {
    return QueryConstraint(key: key, value: value, op: .greaterThanOrEqualTo)
}

public func < <T>(key: String, value: T) -> QueryConstraint where T: Encodable {
    return QueryConstraint(key: key, value: value, op: .lessThan)
}

public func <= <T>(key: String, value: T) -> QueryConstraint where T: Encodable  {
    return QueryConstraint(key: key, value: value, op: .lessThanOrEqualTo)
}

public func == <T>(key: String, value: T) -> QueryConstraint where T: Encodable  {
    return QueryConstraint(key: key, value: value, op: .equals)
}

private struct InQuery<T>: Encodable where T: ParseObjectType {
    let query: Query<T>
    var className: String {
        return T.className
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(className, forKey: .className)
        try container.encode(query._where, forKey: .where)
    }

    enum CodingKeys: String, CodingKey {
        case `where`, className
    }
}

public func == <T>(key: String, value: Query<T>) -> QueryConstraint  {
    return QueryConstraint(key: key, value: InQuery(query: value), op: .inQuery)
}

internal struct QueryWhere: Encodable {
    private var _constraints = [String: [QueryConstraint]]()

    mutating func add(_ constraint: QueryConstraint) {
        var existing = _constraints[constraint.key] ?? []
        existing.append(constraint)
        _constraints[constraint.key] = existing
    }

    // This only encodes the where...
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: RawCodingKey.self)
        try _constraints.forEach { (key, value) in
            var c = container.nestedContainer(keyedBy: QueryConstraint.Comparator.self, forKey: .key(key))
            try value.forEach { (constraint) in
                try constraint.encode(to: c.superEncoder(forKey: constraint.op))
            }
        }
    }
}

public struct Query<T>: Encodable where T: ParseObjectType {
    // interpolate as GET
    private let _method: String = "GET"
    private var _limit: Int = 100
    private var _skip: Int = 0
    fileprivate var _where = QueryWhere()
    private var _keys: [String]?
    private var _include: [String]?
    private var _order: [Order]?
    private var _count: Bool?

    public enum Order: Encodable {
        case ascending(String)
        case descending(String)

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .ascending(let value):
                try container.encode(value)
            case .descending(let value):
                try container.encode("-\(value)")
            }
        }
    }


    public init(_ constraints: QueryConstraint...) {
        self.init(constraints)
    }

    public init(_ constraints: [QueryConstraint]) {
        constraints.forEach({ self._where.add($0) })
    }

    public mutating func `where`(_ constraints: QueryConstraint...) -> Query<T> {
        constraints.forEach({ self._where.add($0) })
        return self
    }

    public mutating func limit(_ value: Int) -> Query<T> {
        _limit = value
        return self
    }

    public mutating func skip(_ value: Int) -> Query<T> {
        _skip = value
        return self
    }
    
    public func find() -> RESTCommand<Query<T>, [T]> {
        return RESTCommand(method: .POST, path: "/classes/\(T.className)", body: self) {
            try getDecoder().decode(FindResult<T>.self, from: $0).results
        }
    }

    public func first() -> RESTCommand<Query<T>, T?> {
        var query = self
        query._limit = 1
        return RESTCommand(method: .POST, path: "/classes/\(T.className)", body: query) {
            try getDecoder().decode(FindResult<T>.self, from: $0).results.first
        }
    }

    public func count() -> RESTCommand<Query<T>, Int> {
        var query = self
        query._limit = 1
        query._count = true
        return RESTCommand(method: .POST, path: "/classes/\(T.className)", body: query) {
            try getDecoder().decode(FindResult<T>.self, from: $0).count ?? 0
        }
    }

    var className: String {
        return T.className
    }
    static var className: String {
        return T.className
    }

    enum CodingKeys: String, CodingKey {
        case _where = "where"
        case _method
        case _limit = "limit"
        case _skip = "skip"
        case _count = "count"
        case _keys = "keys"
        case _order = "order"
    }


}

enum RawCodingKey: CodingKey {
    case key(String)
    var stringValue: String {
        switch self {
        case .key(let str):
            return str
        }
    }
    var intValue: Int? {
        fatalError()
    }
    init?(stringValue: String) {
        self = .key(stringValue)
    }
    init?(intValue: Int) {
        fatalError()
    }
}

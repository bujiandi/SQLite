//
//  SQLite.swift
//  SQLite
//
//  Created by yFenFen on 16/5/18.
//  Copyright © 2016 yFenFen. All rights reserved.
//

import Foundation

// MARK: 空数据样式
let DBNull = DataBaseNull()

public struct DataBaseNull: CustomStringConvertible {
    public var description:String { return "Null" }
}
// MARK: - protocols 接口(创建数据表需实现以下接口)
public protocol DBTableType {
    associatedtype Column: DBTableColumn, RawRepresentable
    
    static var name:String { get }
}

public protocol DBTableColumn: Enumerable {
    var type: DataBaseColumnType { get }
    var option: DataBaseColumnOptions { get }
    
    // optional
    var defaultValue:CustomStringConvertible? { get }
}



// MARK: - enum 枚举(数据库只读模式等)
public enum DBOpenMode: Int {
    case ReadWrite
    case ReadOnly
}

// MARK: - SQLite
struct SQLite {
    static func open(mode:DBOpenMode) -> DBHandle {
        return DBHandle()
    }
}

// MARK: - 数据库操作句柄
class DBHandle {
    
    // MARK: 创建SQL句柄 用于构建链式 SQL
    func createSQLHandleWithTable<T:DBTableType>(_: T.Type) -> SQLHandle<T> {
        let handle:COpaquePointer = nil
        return SQLHandle<T>(SQLHandleBase(handle))
    }
    func createSQLHandleWithTables<T1:DBTableType,T2:DBTableType>(_: T1.Type, _: T2.Type) -> SQLHandle2<T1,T2> {
        let handle:COpaquePointer = nil
        return SQLHandle2<T1,T2>(SQLHandleBase(handle))
    }
//    func createSQLHandleWithTables<T1:DBTableType,T2:DBTableType,T3:DBTableType>(_: T1.Type, _: T2.Type, _: T3.Type) -> SQLHandle3<T1,T2,T3> {
//        let handle:COpaquePointer = nil
//        return SQLHandle3<T1,T2,T3>(handle)
//    }
//    func createSQLHandleWithTables<T1:DBTableType,T2:DBTableType,T3:DBTableType,T4:DBTableType>(_: T1.Type, _: T2.Type, _: T3.Type, _: T4.Type) -> SQLHandle4<T1,T2,T3,T4> {
//        let handle:COpaquePointer = nil
//        return SQLHandle4<T1,T2,T3,T4>(handle)
//    }
/*
    func createSQLwithTable<T1:DBTableType,T2:DBTableType,T3:DBTableType,T4:DBTableType,T5:DBTableType>(_: T1.Type, _: T2.Type, _: T3.Type, _: T4.Type, _: T5.Type) -> SQLHandle5<T1,T2,T3,T4,T5> {
        let handle:COpaquePointer = nil
        return SQLHandle5<T1,T2,T3,T4,T5>(handle)
    }
*/
}




// MARK: - ColumnState 头附加状态
public struct DataBaseColumnOptions : OptionSetType, CustomStringConvertible {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    
    static let None             = DataBaseColumnOptions(rawValue: 0)
    static let PrimaryKey       = DataBaseColumnOptions(rawValue: 1 << 0)
    static let Autoincrement    = DataBaseColumnOptions(rawValue: 1 << 1)
    static let PrimaryKeyAutoincrement: DataBaseColumnOptions = [PrimaryKey, Autoincrement]
    static let NotNull          = DataBaseColumnOptions(rawValue: 1 << 2)
    static let Unique           = DataBaseColumnOptions(rawValue: 1 << 3)
    static let Check            = DataBaseColumnOptions(rawValue: 1 << 4)
    static let ForeignKey       = DataBaseColumnOptions(rawValue: 1 << 5)
    static let ConstraintKey    = DataBaseColumnOptions(rawValue: 1 << 6)       // 属于联合主键
    static let ConstraintPrimaryKey = DataBaseColumnOptions(rawValue: 1 << 7)   // 联合主键名
    
    public var description:String {
        var result = ""
        
        if contains(.PrimaryKey)    { result.appendContentsOf(" PRIMARY KEY") }
        if contains(.Autoincrement) { result.appendContentsOf(" AUTOINCREMENT") }
        if contains(.NotNull)       { result.appendContentsOf(" NOT NULL") }
        if contains(.Unique)        { result.appendContentsOf(" UNIQUE") }
        if contains(.Check)         { result.appendContentsOf(" CHECK") }
        if contains(.ForeignKey)    { result.appendContentsOf(" FOREIGN KEY") }
        if contains(.ConstraintKey) { result.appendContentsOf(" NOT NULL") }
        
        return result
    }
}

// MARK: - ColumnType
public enum DataBaseColumnType : CInt, CustomStringConvertible {
    case Integer = 1
    case Float
    case Text
    case Blob
    case Null
    
    public var description:String {
        switch self {
        case .Integer:  return "INTEGER"
        case .Float:    return "FLOAT"
        case .Text:     return "TEXT"
        case .Blob:     return "BLOB"
        case .Null:     return "NULL"
        }
    }
}

// MARK: - 遍历枚举
public protocol Enumerable: Hashable {
    func enumerate() -> AnyGenerator<Self>
}
extension Enumerable {
    public func enumerate() -> AnyGenerator<Self> {
        return enumerateEnum(Self)
    }
}
/// Enumerate enum type with `for v in Enum`
func enumerateEnum<T: Hashable>(_: T.Type) -> AnyGenerator<T> {
    var i = 0
    return AnyGenerator {
        let next = withUnsafePointer(&i) { UnsafePointer<T>($0).memory }
        defer { i += 1 }
        return next.hashValue == i ? next : nil
    }
}
extension DBTableColumn {
    var defaultValue:CustomStringConvertible? { return nil }
}

// MARK: - SQL 构造句柄
//protocol SQLHandleBase {
//    
//    var _sql:String { set get }
//    var _handle:COpaquePointer { set get }
//    init(_ handle:COpaquePointer)
//
//    mutating func FROM<Table:DBTableType>(table:Table.Type) -> Self
//}
//
//extension SQLHandleBase {
//    
//    mutating func FROM<Table:DBTableType>(table:Table.Type) -> Self {
//        _sql += " FROM \(table.name)"
//        print(_sql)
//        return self
//    }
//}

class SQLHandleBase {
    private var _sql: String = ""
    private var _handle:COpaquePointer
    private init(_ handle:COpaquePointer) { _handle = handle }
    
    func FROM<Table:DBTableType>(table:Table.Type) -> Self {
        _sql += " FROM \(table.name)"
        print(_sql)
        return self
    }
}

final class SQLHandle<T:DBTableType>:SQLHandleBase {
    
    private init(_ handle:SQLHandleBase) {
        super.init(handle._handle)
        _sql = handle._sql
    }
    
    func SELECT(columns:T.Column...) -> SQLHandle<T> {
        _sql += " SELECT " + columns.map({ "\($0)" }).joinWithSeparator(", ")
        return self
    }
    
    func WHERE(columns:T.Column,_ condition:String = "") -> Self {
        return self
    }
    
    func AND(columns:T.Column,_ condition:String = "") -> Self {
        return self
    }
    
    func OR(columns:T.Column,_ condition:String = "") -> Self {
        return self
    }
    
    func XOR(columns:T.Column,_ condition:String = "") -> Self {
        return self
    }
    
    func IN(params:Any...) -> SQLHandle<T> {
        return self
    }
}

final class SQLHandle2<T1:DBTableType,T2:DBTableType>:SQLHandleBase {

    private init(_ handle:SQLHandleBase) {
        super.init(handle._handle)
        _sql = handle._sql
    }
    
    func SELECT(columns1:[T1.Column],_ columns2:[T2.Column]) -> Self {
        _sql = columns1.reduce(_sql + " SELECT ") { $0 + "\(T1.name).\($1), " }
        _sql += columns2.map({ "\(T2.name).\($0)" }).joinWithSeparator(", ")
        return self
    }
    
    func WHERE(columns:T2.Column,_ condition:String = "") -> Self {
        return self
    }
    
    func AND(columns:T2.Column,_ condition:String = "") -> Self {
        return self
    }
    
    func OR(columns:T2.Column,_ condition:String = "") -> Self {
        return self
    }
    
    func XOR(columns:T2.Column,_ condition:String = "") -> Self {
        return self
    }
}

//class SQLHandle3<T1:DBTableType,T2:DBTableType,T3:DBTableType> : SQLHandle2<T1,T2> {
//    
//    override init(_ handle: COpaquePointer) {
//        super.init(handle)
//    }
//    
//    func SELECT(columns1:[T1.Column],_ columns2:[T2.Column],_ columns3:[T3.Column]) -> SQLHandle3<T1,T2,T3> {
//        return self
//    }
//}
//
//class SQLHandle4<T1:DBTableType,T2:DBTableType,T3:DBTableType,T4:DBTableType> : SQLHandle3<T1,T2,T3> {
//    
//    override init(_ handle: COpaquePointer) {
//        super.init(handle)
//    }
//    
//    func SELECT(columns1:[T1.Column],_ columns2:[T2.Column],_ columns3:[T3.Column],_ columns4:[T4.Column]) -> SQLHandle4<T1,T2,T3,T4> {
//        return self
//    }
//}
/*
class SQLHandle5<T1:DBTableType,T2:DBTableType,T3:DBTableType,T4:DBTableType,T5:DBTableType> : SQLHandle4<T1,T2,T3,T4> {
    
    override init(_ handle: COpaquePointer) {
        super.init(handle)
    }
    
    func SELECT(columns1:[T1.Column],_ columns2:[T2.Column],_ columns3:[T3.Column],_ columns4:[T4.Column],_ columns5:[T5.Column]) -> SQLHandle5<T1,T2,T3,T4,T5> {
        return self
    }
}
*/
//
//  SQL.swift
//  SQLite
//
//  Created by yFenFen on 16/5/26.
//  Copyright © 2016 yFenFen. All rights reserved.
//

import Foundation


// MARK: - ColumnState 头附加状态
public struct DataBaseColumnOptions : OptionSetType, CustomStringConvertible {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    
    static let None                 = DataBaseColumnOptions(rawValue: 0)
    static let PrimaryKey           = DataBaseColumnOptions(rawValue: 1 << 0)
    static let Autoincrement        = DataBaseColumnOptions(rawValue: 1 << 1)
    static let PrimaryKeyAutoincrement: DataBaseColumnOptions = [PrimaryKey, Autoincrement]
    static let NotNull              = DataBaseColumnOptions(rawValue: 1 << 2)
    static let Unique               = DataBaseColumnOptions(rawValue: 1 << 3)
    static let Check                = DataBaseColumnOptions(rawValue: 1 << 4)
    static let ForeignKey           = DataBaseColumnOptions(rawValue: 1 << 5)
    static let DeletedKey           = DataBaseColumnOptions(rawValue: 1 << 6)
    
    
    public var description:String {
        return descriptionBy(false)
    }
    
    private func descriptionBy(morePrimaryKey:Bool) -> String {
        var result = ""
        
        if !morePrimaryKey && contains(.PrimaryKey) { result.appendContentsOf(" PRIMARY KEY") }
        if contains(.Autoincrement) { result.appendContentsOf(" AUTOINCREMENT") }
        if contains(.NotNull)       { result.appendContentsOf(" NOT NULL") }
        if contains(.Unique)        { result.appendContentsOf(" UNIQUE") }
        if contains(.Check)         { result.appendContentsOf(" CHECK") }
        if contains(.ForeignKey)    { result.appendContentsOf(" FOREIGN KEY") }
        
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

// MARK: - 空与非空对象
public protocol DBNullType: CustomStringConvertible {}
public struct DataBaseNull: DBNullType {
    public var description:String { return "NULL" }
}
public struct DataBaseNotNull: DBNullType {
    public var description:String { return "NOT NULL" }
}

// MARK: - 过滤 Any 类型中的字符串 与 nil
private func filterSQLAny<T>(rhs:T?) -> String {
    guard let v = rhs else { return "Null" }
    switch v {
    case _ as NSNull:           return "Null"
    case _ as DataBaseNull:     return "Null"
    case let value as String:   return "'\(value)'"
    case let value as NSDate:   return "\(value.timeIntervalSince1970)"
    default:                    //return "\(v)"
        let mirror = _reflect(v)
        if mirror.disposition == .Optional {
            if mirror.count == 0 { return "Null" }
            return filterSQLAny(mirror[0].1.value)
        }
        return "\(v)"
    }
}

// MARK: - SQLite 空表(仅限条件使用)
public enum DBNullTable:String, DBTableType {
    case null
    
    public var type: DataBaseColumnType {
        return .Text
    }
    public var option: DataBaseColumnOptions {
        return .None
    }
    public static let table_name:String = ""
}

// MARK: - 条件泛型传递
public class DBCondition<T1:DBTableType, T2:DBTableType>: CustomStringConvertible, CustomDebugStringConvertible {
    public let description: String
    private var column:T1
    init(_ column1:T1, _ condition:String, _ column2:T2) {
        column = column1
        description = "\(column1)\(condition)\(T2.table_name).\(column2)"
    }
    init(_ column:T1, _ condition:String) {
        self.column = column
        description = "\(column)\(condition)"
    }
    init(_ lhs:DBCondition<T1,T2>, _ condition:String) {
        column = lhs.column
        description = "\(lhs)\(condition)"
    }
    public var debugDescription: String { return "\(T1.table_name).\(description)" }
}
// MARK: - 扩展条件运算符
/// SQL 中的不等于
infix operator <> {
associativity none
precedence 130
}
public func <> <T:DBTableType>(lhs: T, rhs: Any) -> DBCondition<T,DBNullTable> {
    let text = filterSQLAny(rhs)
    if text == "Null" { return DBCondition<T,DBNullTable>(lhs, " IS NOT NULL") }
    return DBCondition<T,DBNullTable>(lhs, "<>\(text)")
}
public func == <T:DBTableType>(lhs: T, rhs: Any) -> DBCondition<T,DBNullTable> {
    let text = filterSQLAny(rhs)
    if text == "Null" { return DBCondition<T,DBNullTable>(lhs, " IS NULL") }
    return DBCondition<T,DBNullTable>(lhs, "=\(text)")
}
public func != <T:DBTableType>(lhs: T, rhs: Any) -> DBCondition<T,DBNullTable> {
    return lhs <> rhs
}
public func <  <T:DBTableType>(lhs: T, rhs: Any) -> DBCondition<T,DBNullTable> {
    return DBCondition<T,DBNullTable>(lhs, "<\(filterSQLAny(rhs))")
}
public func >  <T:DBTableType>(lhs: T, rhs: Any) -> DBCondition<T,DBNullTable> {
    return DBCondition<T,DBNullTable>(lhs, ">\(filterSQLAny(rhs))")
}
public func <= <T:DBTableType>(lhs: T, rhs: Any) -> DBCondition<T,DBNullTable> {
    return DBCondition<T,DBNullTable>(lhs, "<=\(filterSQLAny(rhs))")
}
public func >= <T:DBTableType>(lhs: T, rhs: Any) -> DBCondition<T,DBNullTable> {
    return DBCondition<T,DBNullTable>(lhs, ">=\(filterSQLAny(rhs))")
}
public func +  <T:DBTableType>(lhs: T, rhs: Any) -> DBCondition<T,DBNullTable> {
    return DBCondition<T,DBNullTable>(lhs, "+\(filterSQLAny(rhs))")
}
public func -  <T:DBTableType>(lhs: T, rhs: Any) -> DBCondition<T,DBNullTable> {
    return DBCondition<T,DBNullTable>(lhs, "-\(filterSQLAny(rhs))")
}
public func *  <T:DBTableType>(lhs: T, rhs: Any) -> DBCondition<T,DBNullTable> {
    return DBCondition<T,DBNullTable>(lhs, "*\(filterSQLAny(rhs))")
}
public func /  <T:DBTableType>(lhs: T, rhs: Any) -> DBCondition<T,DBNullTable> {
    return DBCondition<T,DBNullTable>(lhs, "/\(filterSQLAny(rhs))")
}
public func &  <T:DBTableType>(lhs: T, rhs: Any) -> DBCondition<T,DBNullTable> {
    return DBCondition<T,DBNullTable>(lhs, "&\(filterSQLAny(rhs))")
}
public func |  <T:DBTableType>(lhs: T, rhs: Any) -> DBCondition<T,DBNullTable> {
    return DBCondition<T,DBNullTable>(lhs, "|\(filterSQLAny(rhs))")
}
public func ^  <T:DBTableType>(lhs: T, rhs: Any) -> DBCondition<T,DBNullTable> {
    return DBCondition<T,DBNullTable>(lhs, "^\(filterSQLAny(rhs))")
}

// MARK: 2字段条件扩展运算符
public func <> <T1:DBTableType,T2:DBTableType>(lhs: T1, rhs: T2) -> DBCondition<T1,T2> {
    return T2.self == DBNullTable.self ? DBCondition<T1,T2>(lhs, " IS NOT NULL") : DBCondition<T1,T2>(lhs, "<>", rhs)
}
public func == <T1:DBTableType,T2:DBTableType>(lhs: T1, rhs: T2) -> DBCondition<T1,T2> {
    return T2.self == DBNullTable.self ? DBCondition<T1,T2>(lhs, " IS NULL") : DBCondition<T1,T2>(lhs, "=", rhs)
}
public func != <T1:DBTableType,T2:DBTableType>(lhs: T1, rhs: T2) -> DBCondition<T1,T2> {
    return lhs <> rhs
}
public func <  <T1:DBTableType,T2:DBTableType>(lhs: T1, rhs: T2) -> DBCondition<T1,T2> {
    return DBCondition<T1,T2>(lhs, "<", rhs)
}
public func >  <T1:DBTableType,T2:DBTableType>(lhs: T1, rhs: T2) -> DBCondition<T1,T2> {
    return DBCondition<T1,T2>(lhs, ">", rhs)
}
public func <= <T1:DBTableType,T2:DBTableType>(lhs: T1, rhs: T2) -> DBCondition<T1,T2> {
    return DBCondition<T1,T2>(lhs, "<=", rhs)
}
public func >= <T1:DBTableType,T2:DBTableType>(lhs: T1, rhs: T2) -> DBCondition<T1,T2> {
    return DBCondition<T1,T2>(lhs, ">=", rhs)
}
public func +  <T1:DBTableType,T2:DBTableType>(lhs: T1, rhs: T2) -> DBCondition<T1,T2> {
    return DBCondition<T1,T2>(lhs, "+", rhs)
}
public func -  <T1:DBTableType,T2:DBTableType>(lhs: T1, rhs: T2) -> DBCondition<T1,T2> {
    return DBCondition<T1,T2>(lhs, "-", rhs)
}
public func *  <T1:DBTableType,T2:DBTableType>(lhs: T1, rhs: T2) -> DBCondition<T1,T2> {
    return DBCondition<T1,T2>(lhs, "*", rhs)
}
public func /  <T1:DBTableType,T2:DBTableType>(lhs: T1, rhs: T2) -> DBCondition<T1,T2> {
    return DBCondition<T1,T2>(lhs, "/", rhs)
}
public func &  <T1:DBTableType,T2:DBTableType>(lhs: T1, rhs: T2) -> DBCondition<T1,T2> {
    return DBCondition<T1,T2>(lhs, "&", rhs)
}
public func |  <T1:DBTableType,T2:DBTableType>(lhs: T1, rhs: T2) -> DBCondition<T1,T2> {
    return DBCondition<T1,T2>(lhs, "|", rhs)
}
public func ^  <T1:DBTableType,T2:DBTableType>(lhs: T1, rhs: T2) -> DBCondition<T1,T2> {
    return DBCondition<T1,T2>(lhs, "^", rhs)
}


// MARK: 以下是 条件无限追加的函数
public func <> <T1:DBTableType,T2:DBTableType>(lhs: DBCondition<T1,T2>, rhs: Any) -> DBCondition<T1,T2> {
    return DBCondition<T1,T2>(lhs, "<>\(filterSQLAny(rhs))")
}
public func == <T1:DBTableType,T2:DBTableType>(lhs: DBCondition<T1,T2>, rhs: Any) -> DBCondition<T1,T2> {
    return DBCondition<T1,T2>(lhs, "=\(filterSQLAny(rhs))")
}
public func != <T1:DBTableType,T2:DBTableType>(lhs: DBCondition<T1,T2>, rhs: Any) -> DBCondition<T1,T2> {
    return lhs <> rhs
}
public func <  <T1:DBTableType,T2:DBTableType>(lhs: DBCondition<T1,T2>, rhs: Any) -> DBCondition<T1,T2> {
    return DBCondition<T1,T2>(lhs, "<\(filterSQLAny(rhs))")
}
public func >  <T1:DBTableType,T2:DBTableType>(lhs: DBCondition<T1,T2>, rhs: Any) -> DBCondition<T1,T2> {
    return DBCondition<T1,T2>(lhs, ">\(filterSQLAny(rhs))")
}
public func <= <T1:DBTableType,T2:DBTableType>(lhs: DBCondition<T1,T2>, rhs: Any) -> DBCondition<T1,T2> {
    return DBCondition<T1,T2>(lhs, "<=\(filterSQLAny(rhs))")
}
public func >= <T1:DBTableType,T2:DBTableType>(lhs: DBCondition<T1,T2>, rhs: Any) -> DBCondition<T1,T2> {
    return DBCondition<T1,T2>(lhs, ">=\(filterSQLAny(rhs))")
}
public func +  <T1:DBTableType,T2:DBTableType>(lhs: DBCondition<T1,T2>, rhs: Any) -> DBCondition<T1,T2> {
    return DBCondition<T1,T2>(lhs, "+\(filterSQLAny(rhs))")
}
public func -  <T1:DBTableType,T2:DBTableType>(lhs: DBCondition<T1,T2>, rhs: Any) -> DBCondition<T1,T2> {
    return DBCondition<T1,T2>(lhs, "-\(filterSQLAny(rhs))")
}
public func *  <T1:DBTableType,T2:DBTableType>(lhs: DBCondition<T1,T2>, rhs: Any) -> DBCondition<T1,T2> {
    return DBCondition<T1,T2>(lhs, "*\(filterSQLAny(rhs))")
}
public func /  <T1:DBTableType,T2:DBTableType>(lhs: DBCondition<T1,T2>, rhs: Any) -> DBCondition<T1,T2> {
    return DBCondition<T1,T2>(lhs, "/\(filterSQLAny(rhs))")
}
public func &  <T1:DBTableType,T2:DBTableType>(lhs: DBCondition<T1,T2>, rhs: Any) -> DBCondition<T1,T2> {
    return DBCondition<T1,T2>(lhs, "&\(filterSQLAny(rhs))")
}
public func |  <T1:DBTableType,T2:DBTableType>(lhs: DBCondition<T1,T2>, rhs: Any) -> DBCondition<T1,T2> {
    return DBCondition<T1,T2>(lhs, "|\(filterSQLAny(rhs))")
}
public func ^  <T1:DBTableType,T2:DBTableType>(lhs: DBCondition<T1,T2>, rhs: Any) -> DBCondition<T1,T2> {
    return DBCondition<T1,T2>(lhs, "^\(filterSQLAny(rhs))")
}

// MARK: - SQL构造器
public class DBSQLHandle {
    private var sql: [String] = []
    private func addCondition(condition:String, funcName:String = #function) {
        sql.append(funcName)
        sql.append(condition)
    }
}
private protocol DBSQLHandleType {
    var _handle:DBSQLHandle { get set }
    init(_ handle:DBSQLHandle?)
}

public class SQLBase: DBSQLHandleType, CustomStringConvertible {
    
    private var _handle:DBSQLHandle
    public required init(_ handle:DBSQLHandle? = nil) {
        _handle = handle ?? DBSQLHandle()
    }
    private init(_ base:String) {
        _handle = DBSQLHandle()
        _handle.sql.append(base)
    }
    
    func INTO<Table:DBTableType>(_:Table.Type) -> SQLInsert<Table> {
        _handle.addCondition(Table.table_name)
        return SQLInsert<Table>(_handle)
    }
    
    func TABLE<Table:DBTableType>(_:Table.Type) -> SQL<Table> {
        _handle.addCondition(Table.table_name)
        return SQL<Table>(_handle)
    }
    func TABLE(oldTableName:String) -> Self {
        _handle.addCondition(oldTableName)
        return self
    }
    func RENAME<Table:DBTableType>(TO _:Table.Type) -> SQL<Table> {
        _handle.sql.append("RENAME TO \(Table.table_name)")
        return SQL<Table>(_handle)
    }
    
    func FROM<Table:DBTableType>(_:Table.Type) -> SQL<Table> {
        _handle.addCondition(Table.table_name)
        return SQL<Table>(_handle)
    }
    
    func FROM<T1:DBTableType, T2:DBTableType>(_:T1.Type,_:T2.Type) -> SQL2<T1,T2> {
        _handle.sql.append("FROM \(T1.table_name), \(T2.table_name)")
        return SQL2<T1,T2>(_handle)
    }
    
    func COUNT(@noescape columns:(SQLBase,SQLBase)->SQLBase) -> SQLBase {
        _handle.sql.append("COUNT(")
        return columns(self, SQLBase(")"))
    }
    
    public var OR:SQLBase {
        _handle.sql.append("OR")
        return self
    }
    public var REPLACE:SQLBase {
        _handle.sql.append("REPLACE")
        return self
    }
    public var IGNORE:SQLBase {
        _handle.sql.append("REPLACE")
        return self
    }
    func IN(sql:SQLBase) -> Self {
        _handle.sql.append("IN(\(sql))")
        return self
    }
    
    func IN(params:Any...) -> Self {
        let text = params.map({ filterSQLAny($0) }).joinWithSeparator(", ")
        _handle.sql.append("IN(\(text))")
        return self
    }
    
    public var description: String {
        return _handle.sql.joinWithSeparator(" ")
    }
}



public class SQL<T:DBTableType>:SQLBase {
    public typealias Table = T
    
    public required init(_ handle:DBSQLHandle? = nil) { super.init(handle) }
    
    // MARK: select
    func COUNT(columns:T...) -> Self {
        _handle.sql.append("COUNT(" + columns.map({ "\($0)" }).joinWithSeparator(", ") + ")")
        return self
    }
    func SELECT(columns:T...) -> Self {
        _handle.sql.append("SELECT " + columns.map({ "\($0)" }).joinWithSeparator(", "))
        return self
    }
    func SELECT(DISTINCT columns:T...) -> Self {
        _handle.sql.append("SELECT DISTINCT " + columns.map({ "\($0)" }).joinWithSeparator(", "))
        return self
    }
    func SELECT(TOP value:Int,_ columns:T...) -> Self {
        _handle.sql.append("SELECT TOP \(value) " + columns.map({ "\($0)" }).joinWithSeparator(", "))
        return self
    }
    var SELECT:SQL {
        _handle.sql.append("SELECT")
        return self
    }
    
    // MARK: join
    var LEFT:SQL {
        _handle.sql.append("LEFT")
        return self
    }
    var RIGHT:SQL {
        _handle.sql.append("RIGHT")
        return self
    }
    func JOIN<Table:DBTableType>(_:Table.Type) -> SQL2<T,Table> {
        _handle.addCondition(Table.table_name)
        return SQL2<T,Table>(_handle)
    }
    
    // MARK: alter
    func RENAME(COLUMN oldColumnName:String, TO column:T) -> Self {
        _handle.sql.append("RENAME COLUMN \(oldColumnName) TO \(column)")
        return self
    }
    func DROP(COLUMN column:T) -> Self {
        _handle.sql.append("DROP COLUMN \(column)")
        return self
    }
    func MODIFY(column:T,_ columnType:DataBaseColumnType) -> Self {
        _handle.sql.append("MODIFY \(column) \(columnType)")
        return self
    }
    func ADD(column:T,_ columnType:DataBaseColumnType) -> Self {
        _handle.sql.append("ADD \(column) \(columnType)")
        return self
    }
    
    // MARK: where
    func WHERE(column:T) -> Self {
        _handle.addCondition("\(column)")
        return self
    }
    func WHERE(@autoclosure condition:() -> DBCondition<T,DBNullTable>) -> Self {
        _handle.addCondition(condition().description)
        return self
    }
    public func ORDER(BY columns:T...) -> Self {
        _handle.sql.append("ORDER BY " + columns.map({ "\($0)" }).joinWithSeparator(", "))
        return self
    }
    public func GROUP(BY columns:T...) -> Self {
        _handle.sql.append("GROUP BY " + columns.map({ "\($0)" }).joinWithSeparator(", "))
        return self
    }
    public func LIMIT(value:Int) -> Self {
        _handle.addCondition("\(value)")
        return self
    }
    public func LIKE(pattern:String) -> Self {
        _handle.addCondition("'\(pattern)'")
        return self
    }
    public func BETWEEN(value1:Any, AND value2:Any) -> Self {
        _handle.sql.append("BETWEEN")
        _handle.sql.append(filterSQLAny(value1))
        _handle.sql.append("AND")
        _handle.sql.append(filterSQLAny(value2))
        return self
    }
    
    public func IS<N:DBNullType>(nullValue:N) -> Self {
        _handle.addCondition(nullValue.description)
        return self
    }
    public func AND(column:T) -> Self {
        _handle.addCondition("\(column)")
        return self
    }
    public func AND(@autoclosure condition:() -> DBCondition<T,DBNullTable>) -> Self {
        _handle.addCondition(condition().description)
        return self
    }
    public func OR(column:T) -> Self {
        _handle.addCondition("\(column)")
        return self
    }
    public func OR(@autoclosure condition:() -> DBCondition<T,DBNullTable>) -> Self {
        _handle.addCondition(condition().description)
        return self
    }
    public func XOR(column:T) -> Self {
        _handle.addCondition("\(column)")
        return self
    }
    public func XOR(@autoclosure condition:() -> DBCondition<T,DBNullTable>) -> Self {
        _handle.addCondition(condition().description)
        return self
    }
    override func IN(sql: SQLBase) -> Self {
        super.IN(sql)
        return self
    }
    override func IN(params: Any...) -> Self {
        super.IN(params)
        return self
    }
    
    // MARK: update
    func SET(@autoclosure   condition :() -> DBCondition<T,DBNullTable>) -> Self {
        _handle.addCondition(condition().description)
        return self
    }
    func SET(@autoclosure   condition1:() -> DBCondition<T,DBNullTable>,
             @autoclosure _ condition2:() -> DBCondition<T,DBNullTable>) -> Self {
        _handle.addCondition([
            condition1().description,
            condition2().description
            ].joinWithSeparator(", "))
        return self
    }
    func SET(@autoclosure   condition1:() -> DBCondition<T,DBNullTable>,
             @autoclosure _ condition2:() -> DBCondition<T,DBNullTable>,
             @autoclosure _ condition3:() -> DBCondition<T,DBNullTable>) -> Self {
        _handle.addCondition([
            condition1().description,
            condition2().description,
            condition3().description
            ].joinWithSeparator(", "))
        return self
    }
    func SET(@autoclosure   condition1:() -> DBCondition<T,DBNullTable>,
             @autoclosure _ condition2:() -> DBCondition<T,DBNullTable>,
             @autoclosure _ condition3:() -> DBCondition<T,DBNullTable>,
             @autoclosure _ condition4:() -> DBCondition<T,DBNullTable>) -> Self {
        _handle.addCondition([
            condition1().description,
            condition2().description,
            condition3().description,
            condition4().description
            ].joinWithSeparator(", "))
        return self
    }
    func SET(@autoclosure   condition1:() -> DBCondition<T,DBNullTable>,
             @autoclosure _ condition2:() -> DBCondition<T,DBNullTable>,
             @autoclosure _ condition3:() -> DBCondition<T,DBNullTable>,
             @autoclosure _ condition4:() -> DBCondition<T,DBNullTable>,
             @autoclosure _ condition5:() -> DBCondition<T,DBNullTable>) -> Self {
        _handle.addCondition([
            condition1().description,
            condition2().description,
            condition3().description,
            condition4().description,
            condition5().description
            ].joinWithSeparator(", "))
        return self
    }
}


public class SQLInsert<T:DBTableType>: DBSQLHandleType {
    private var _handle:DBSQLHandle
    private var columns:[T] = []
    public required init(_ handle:DBSQLHandle?) {
        _handle = handle ?? DBSQLHandle()
    }
    
    subscript(columns:T...) -> SQLInsert<T> {
        let text = columns.map({ "\($0)" }).joinWithSeparator(", ")
        _handle.sql.append("(\(text))")
        self.columns = columns
        return self
    }
    
    func VALUES(params:Any...) -> SQL<T> {
        let text = params.map({ filterSQLAny($0) }).joinWithSeparator(", ")
        _handle.sql.append("VALUES(\(text))")
        return SQL<T>(_handle)
    }
    func VALUES<U>(values:[U], insertTo db:DBHandle, binds:(id:Int, value:U, bindSet:DBBindSet<T>) throws -> () ) throws {
        
        // 如果列字段为 * 则 遍历此表所有列
        if columns.isEmpty {
            for column in T.enumerate() where !column.option.contains(.DeletedKey)  {
                columns.append(column)
            }
        }
        let texts = [String](count: columns.count, repeatedValue: "?").joinWithSeparator(", ")
        _handle.sql.append("VALUES(\(texts))")
        // TODO: 批量插入
        let stmt = try db.query(_handle.sql.joinWithSeparator(" "))
        // 方法完成后释放 数据操作句柄
        defer { sqlite3_finalize(stmt) }
        let bindSet = DBBindSet<T>(stmt, columns)
        
        // 获取最后一次插入的ID
        db.beginTransaction()
        var flag:CInt = SQLITE_ERROR
        for i:Int in 0 ..< columns.count {
            let columnOption = columns[i].option
            let value:Int? = columnOption.contains(.PrimaryKey) || columnOption.contains(.NotNull) ? nil : 1
            try bindSet.bindValue(value, index: i + 1)
        }
        flag = sqlite3_step(stmt)
        db.rollbackTransaction()
        sqlite3_reset(stmt)
        var lastInsertID = db.lastInsertRowID       //sqlite3_last_insert_rowid(db._handle)
        db.beginTransaction()
        
        // 插入数据
        for value in values {
            try binds(id: Int(truncatingBitPattern: lastInsertID), value: value, bindSet: bindSet)
            flag = sqlite3_step(stmt)
            if flag != SQLITE_OK && flag != SQLITE_DONE {
                #if DEBUG
                    fatalError("无法绑定数据[\(dict)] 到[\(columnFields)]")
                #endif
                bindSet.bindClear()     //如果失败则绑定下一组
            } else {
                sqlite3_reset(stmt)
                if lastInsertID == db.lastInsertRowID {
                    lastInsertID += 1
                }
            }
        }
        if flag == SQLITE_OK || flag == SQLITE_DONE {
            flag = SQLITE_OK
            db.commitTransaction()
        } else {
            db.rollbackTransaction()
            let errorDescription = db.lastErrorMessage
            print(db.lastSQL)
            throw DBError(domain: errorDescription, code: Int(flag), userInfo: nil)
        }
    }
}

public class SQL2<T1:DBTableType,T2:DBTableType>:SQL<T1> {
    
    public required init(_ handle:DBSQLHandle? = nil) { super.init(handle) }
    
    // MARK: join
    func SELECT(columns1:[T1],_ columns2:[T2]) -> Self {
        var text = columns1.reduce("SELECT ") { $0 + "\(T1.table_name).\($1), " }
        text += columns2.map({ "\(T2.table_name).\($0)" }).joinWithSeparator(", ")
        _handle.sql.append(text)
        return self
    }
    
    // MARK: join
    func ON(@autoclosure condition:() -> DBCondition<T1,T2>) -> Self {
        _handle.addCondition(condition().debugDescription)
        return self
    }
    
    // MARK: where
    override func WHERE(column:T1) -> Self {
        _handle.addCondition("\(T1.table_name).\(column)")
        return self
    }
    func WHERE(column:T2) -> Self {
        _handle.addCondition("\(T2.table_name).\(column)")
        return self
    }
    func WHERE(@autoclosure condition:() -> DBCondition<T1,T2>) -> Self {
        _handle.addCondition(condition().debugDescription)
        return self
    }
    func WHERE(@autoclosure condition:() -> DBCondition<T2,DBNullTable>) -> Self {
        _handle.addCondition(condition().debugDescription)
        return self
    }
    override func WHERE(@autoclosure condition:() -> DBCondition<T1,DBNullTable>) -> Self {
        _handle.addCondition(condition().debugDescription)
        return self
    }
    public func ORDER(BY columns1:[T1],_ columns2:[T2]) -> Self {
        var text = columns1.reduce("ORDER BY ") { $0 + "\(T1.table_name).\($1), " }
        text += columns2.map({ "\(T2.table_name).\($0)" }).joinWithSeparator(", ")
        _handle.sql.append(text)
        return self
    }
    public func ORDER(BY columns:T2...) -> Self {
        _handle.sql.append("ORDER BY " + columns.map({ "\(T2.table_name).\($0)" }).joinWithSeparator(", "))
        return self
    }
    public override func ORDER(BY columns:T1...) -> Self {
        _handle.sql.append("ORDER BY " + columns.map({ "\(T1.table_name).\($0)" }).joinWithSeparator(", "))
        return self
    }
    public func GROUP(BY columns1:[T1],_ columns2:[T2]) -> Self {
        var text = columns1.reduce("GROUP BY ") { $0 + "\(T1.table_name).\($1), " }
        text += columns2.map({ "\(T2.table_name).\($0)" }).joinWithSeparator(", ")
        _handle.sql.append(text)
        return self
    }
    public func GROUP(BY columns:T2...) -> Self {
        _handle.sql.append("GROUP BY " + columns.map({ "\(T2.table_name).\($0)" }).joinWithSeparator(", "))
        return self
    }
    public override func GROUP(BY columns:T1...) -> Self {
        _handle.sql.append("GROUP BY " + columns.map({ "\(T1.table_name).\($0)" }).joinWithSeparator(", "))
        return self
    }
    public override func LIMIT(value:Int) -> Self {
        super.LIMIT(value)
        return self
    }
    public override func LIKE(pattern:String) -> Self {
        super.LIKE(pattern)
        return self
    }
    public override func BETWEEN(value1:Any, AND value2:Any) -> Self {
        super.BETWEEN(value1, AND: value2)
        return self
    }
    
    public override func IS<N:DBNullType>(nullValue:N) -> Self {
        super.IS(nullValue)
        return self
    }
    public override func AND(column:T1) -> Self {
        _handle.addCondition("\(T1.table_name).\(column)")
        return self
    }
    public func AND(column:T2) -> Self {
        _handle.addCondition("\(T2.table_name).\(column)")
        return self
    }
    public func AND(@autoclosure condition:() -> DBCondition<T1,T2>) -> Self {
        _handle.addCondition(condition().debugDescription)
        return self
    }
    public func AND(@autoclosure condition:() -> DBCondition<T2,DBNullTable>) -> Self {
        _handle.addCondition(condition().debugDescription)
        return self
    }
    public override func AND(@autoclosure condition:() -> DBCondition<T1,DBNullTable>) -> Self {
        _handle.addCondition(condition().debugDescription)
        return self
    }
    public override func OR(column:T1) -> Self {
        _handle.addCondition("\(T1.table_name).\(column)")
        return self
    }
    public func OR(column:T2) -> Self {
        _handle.addCondition("\(T2.table_name).\(column)")
        return self
    }
    public func OR(@autoclosure condition:() -> DBCondition<T1,T2>) -> Self {
        _handle.addCondition(condition().debugDescription)
        return self
    }
    public func OR(@autoclosure condition:() -> DBCondition<T2,DBNullTable>) -> Self {
        _handle.addCondition(condition().debugDescription)
        return self
    }
    public override func OR(@autoclosure condition:() -> DBCondition<T1,DBNullTable>) -> Self {
        _handle.addCondition(condition().debugDescription)
        return self
    }
    public override func XOR(column:T1) -> Self {
        _handle.addCondition("\(T1.table_name).\(column)")
        return self
    }
    public func XOR(column:T2) -> Self {
        _handle.addCondition("\(T2.table_name).\(column)")
        return self
    }
    public func XOR(@autoclosure condition:() -> DBCondition<T1,T2>) -> Self {
        _handle.addCondition(condition().debugDescription)
        return self
    }
    public func XOR(@autoclosure condition:() -> DBCondition<T2,DBNullTable>) -> Self {
        _handle.addCondition(condition().debugDescription)
        return self
    }
    public override func XOR(@autoclosure condition:() -> DBCondition<T1,DBNullTable>) -> Self {
        _handle.addCondition(condition().debugDescription)
        return self
    }
    override func IN(sql: SQLBase) -> Self {
        super.IN(sql)
        return self
    }
    override func IN(params: Any...) -> Self {
        super.IN(params)
        return self
    }
    
    // MARK: update
    func SET(@autoclosure   condition :() -> DBCondition<T1,T2>) -> Self {
        _handle.addCondition(condition().debugDescription)
        return self
    }
    func SET(@autoclosure   condition1:() -> DBCondition<T1,T2>,
             @autoclosure _ condition2:() -> DBCondition<T1,T2>) -> Self {
        _handle.addCondition([
            condition1().debugDescription,
            condition2().debugDescription
            ].joinWithSeparator(", "))
        return self
    }
    func SET(@autoclosure   condition1:() -> DBCondition<T1,T2>,
             @autoclosure _ condition2:() -> DBCondition<T1,T2>,
             @autoclosure _ condition3:() -> DBCondition<T1,T2>) -> Self {
        _handle.addCondition([
            condition1().debugDescription,
            condition2().debugDescription,
            condition3().debugDescription
            ].joinWithSeparator(", "))
        return self
    }
    func SET(@autoclosure   condition1:() -> DBCondition<T1,T2>,
             @autoclosure _ condition2:() -> DBCondition<T1,T2>,
             @autoclosure _ condition3:() -> DBCondition<T1,T2>,
             @autoclosure _ condition4:() -> DBCondition<T1,T2>) -> Self {
        _handle.addCondition([
            condition1().debugDescription,
            condition2().debugDescription,
            condition3().debugDescription,
            condition4().debugDescription
            ].joinWithSeparator(", "))
        return self
    }
    func SET(@autoclosure   condition1:() -> DBCondition<T1,T2>,
             @autoclosure _ condition2:() -> DBCondition<T1,T2>,
             @autoclosure _ condition3:() -> DBCondition<T1,T2>,
             @autoclosure _ condition4:() -> DBCondition<T1,T2>,
             @autoclosure _ condition5:() -> DBCondition<T1,T2>) -> Self {
        _handle.addCondition([
            condition1().debugDescription,
            condition2().debugDescription,
            condition3().debugDescription,
            condition4().debugDescription,
            condition5().debugDescription
            ].joinWithSeparator(", "))
        return self
    }
    
}

// MARK: - 配合 SELECT 语句
public func *  <T:DBTableType>(lhs:SQLBase, rhs:SQL<T>) -> SQL<T> {
    lhs._handle.sql.append("*")
    lhs._handle.sql.appendContentsOf(rhs._handle.sql)
    rhs._handle = lhs._handle
    return rhs
}
//public func *  <T:DBTableType>(lhs:SQLBase, rhs:SQLWhere<T>) -> SQLWhere<T> {
//    rhs._handle.sql.insertContentsOf(lhs._handle.sql, at: 0)
//    rhs._handle.sql.insert("*", atIndex: lhs._handle.sql.count)
//    return rhs
//}
public func *  <T:DBTableType>(lhs:SQLBase, rhs:SQLInsert<T>) -> SQLInsert<T> {
    lhs._handle.sql.append("*")
    lhs._handle.sql.appendContentsOf(rhs._handle.sql)
    rhs._handle = lhs._handle
    return rhs
}
public func *  (lhs:SQLBase, rhs:SQLBase) -> SQLBase {
    lhs._handle.sql.append("*")
    lhs._handle.sql.appendContentsOf(rhs._handle.sql)
    rhs._handle = lhs._handle
    return rhs
}

// MARK: - SQL语句常量于函数
/// 空数据样式
public let NULL = DataBaseNull()
public let NOT_NULL = DataBaseNotNull()

public var DB_NOW:NSTimeInterval { return NSDate().timeIntervalSince1970 }
public let DELETE:SQLBase = SQLBase("DELETE")
public let SELECT:SQLBase = SQLBase("SELECT")
public let INSERT:SQLBase = SQLBase("INSERT")
public let ALERT :SQLBase = SQLBase("ALERT")

public func SELECT(TOP value:Int) -> SQLBase {
    return SQLBase("SELECT TOP \(value)")
}

public func FROM<T:DBTableType>(_:T.Type) -> SQL<T> {
    return SQL<T>().FROM(T.self)
}
public func UPDATE<T:DBTableType>(_:T.Type) -> SQL<T> {
    let sql = SQL<T>()
    sql._handle.sql.append(#function)
    sql._handle.sql.append(T.table_name)
    return sql
}
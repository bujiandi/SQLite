//
//  SQL.swift
//  SQLite
//
//  Created by yFenFen on 16/5/26.
//  Copyright © 2016 yFenFen. All rights reserved.
//

import Foundation

// MARK: - protocols 接口(创建数据表需用枚举实现以下接口)
/// 注: enum OneTable: String, DBTableType
public protocol DBTableType: RawRepresentable, Hashable {
    static var table_name:String { get }
    
    var type: DataBaseColumnType { get }
    var option: DataBaseColumnOptions { get }
    
    // optional
    var defaultValue:CustomStringConvertible? { get }
}

// MARK: - 遍历枚举
extension DBTableType {
    public var defaultValue:CustomStringConvertible? { return nil }
    
    private static func enumerateEnum<T: Hashable>(_: T.Type) -> AnyGenerator<T> {
        var i = 0
        return AnyGenerator {
            let next = withUnsafePointer(&i) { UnsafePointer<T>($0).memory }
            defer { i += 1 }
            return next.hashValue == i ? next : nil
        }
    }
    
    public static func enumerate() -> AnyGenerator<Self> {
        return enumerateEnum(Self)
    }
}

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

// MARK: - result set 结果集
public class DBResultSet<T:DBTableType>: GeneratorType, SequenceType {
    public typealias Element = DBRowSet<T>
    
    private var _stmt:COpaquePointer = nil
    private init (_ stmt:COpaquePointer) {
        _stmt = stmt
        let length = sqlite3_column_count(_stmt);
        var columns:[String] = []
        for i:CInt in 0..<length {
            let name:UnsafePointer<CChar> = sqlite3_column_name(_stmt,i)
            columns.append(String.fromCString(name)!.lowercaseString)
        }
        //print(columns)
        _columns = columns
    }
    deinit {
        if _stmt != nil {
            sqlite3_finalize(_stmt)
        }
    }
    
    public var row:Int {
        return Int(sqlite3_data_count(_stmt))
    }
    
    public var step:CInt {
        return sqlite3_step(_stmt)
    }
    
    public func reset() {
        sqlite3_reset(_stmt)
    }
    
    public func close() {
        if _stmt != nil {
            sqlite3_finalize(_stmt)
            _stmt = nil
        }
    }
    
    public func next() -> DBRowSet<T>? {
        return step != SQLITE_ROW ? nil : DBRowSet<T>(_stmt, _columns)
    }
    
    public func firstValue() -> Int {
        if step == SQLITE_ROW {
            return Int(sqlite3_column_int(_stmt, 0))
        }
        return 0
    }
    
    private let _columns:[String]
    var columnCount:Int { return _columns.count }
    var isClosed:Bool { return _stmt == nil }
}

// MARK: rowset 基础
public class DBRowSetBase {
    private var _stmt:COpaquePointer = nil
    private let _columns:[String]
    
    private init (_ stmt:COpaquePointer,_ columns:[String]) {
        _stmt = stmt
        _columns = columns
    }
    
    public func getDictionary() -> [String:Any] {
        var dict:[String:Any] = [:]
        for i in 0..<_columns.count {
            let index = CInt(i)
            let type = sqlite3_column_type(_stmt, index);
            let key:String = _columns[i]
            var value:Any? = nil
            switch type {
            case SQLITE_INTEGER:
                value = Int64(sqlite3_column_int64(_stmt, index))
            case SQLITE_FLOAT:
                value = Double(sqlite3_column_double(_stmt, index))
            case SQLITE_TEXT:
                let text:UnsafePointer<UInt8> = sqlite3_column_text(_stmt, index)
                value = String.fromCString(UnsafePointer<CChar>(text))
            case SQLITE_BLOB:
                let data:UnsafePointer<Void> = sqlite3_column_blob(_stmt, index)
                let size:CInt = sqlite3_column_bytes(_stmt, index)
                value = NSData(bytes:data, length: Int(size))
            case SQLITE_NULL:   fallthrough     //下降关键字 执行下一 CASE
            default :           break           //什么都不执行
            }
            dict[key] = value
//            //如果出现重名则
//            if i != columnNames.indexOfObject(key) {
//                //取变量类型
//                //let tableName = String.fromCString(sqlite3_column_table_name(stmt, index))
//                //dict["\(tableName).\(key)"] = value
//                dict["\(key).\(i)"] = value
//            } else {
//                dict[key] = value
//            }
        }
        
        return dict
    }
    public func getInt64(columnIndex:Int) -> Int64 {
        return sqlite3_column_int64(_stmt, CInt(columnIndex))
    }
    public func getUInt64(columnIndex:Int) -> UInt64 {
        return UInt64(bitPattern: getInt64(columnIndex))
    }
    public func getInt(columnIndex:Int) -> Int {
        return Int(truncatingBitPattern: getInt64(columnIndex))
    }
    public func getUInt(columnIndex:Int) -> UInt {
        return UInt(truncatingBitPattern: getInt64(columnIndex))
    }
    public func getInt32(columnIndex:Int) -> Int32 {
        return Int32(truncatingBitPattern: getInt64(columnIndex))
    }
    public func getUInt32(columnIndex:Int) -> UInt32 {
        return UInt32(truncatingBitPattern: getInt64(columnIndex))
    }
    public func getBool(columnIndex:Int) -> Bool {
        return getInt64(columnIndex) != 0
    }
    public func getFloat(columnIndex:Int) -> Float {
        return Float(sqlite3_column_double(_stmt, CInt(columnIndex)))
    }
    public func getDouble(columnIndex:Int) -> Double {
        return sqlite3_column_double(_stmt, CInt(columnIndex))
    }
    public func getString(columnIndex:Int) -> String? {
        let result = sqlite3_column_text(_stmt, CInt(columnIndex))
        return String.fromCString(UnsafePointer<CChar>(result))
    }
    
    func getColumnIndex(columnName: String) -> Int {
        return _columns.indexOf({ $0 == columnName.lowercaseString }) ?? NSNotFound
    }
    
    var columnCount:Int { return _columns.count }
}

public class DBRowSet<T:DBTableType>: DBRowSetBase {
    private override init(_ stmt: COpaquePointer,_ columns:[String]) {
        super.init(stmt, columns)
    }
    
    public init <U:DBTableType>(_ rs:DBRowSet<U>) {
        super.init(rs._stmt, rs._columns)
    }
    
    public func getColumnIndex(column: T) -> Int {
        return _columns.indexOf({ $0 == "\(column)".lowercaseString }) ?? NSNotFound
    }
    
    
    public func getUInt(column: T) -> UInt {
        return UInt(truncatingBitPattern: getInt64(column))
    }
    public func getInt(column: T) -> Int {
        return Int(truncatingBitPattern: getInt64(column))
    }
    public func getInt64(column: T) -> Int64 {
        guard let index = _columns.indexOf({ $0 == "\(column)".lowercaseString }) else {
            return 0
        }
        return sqlite3_column_int64(_stmt, CInt(index))
    }
    public func getDouble(column: T) -> Double {
        guard let index = _columns.indexOf({ $0 == "\(column)".lowercaseString }) else {
            return 0
        }
        return sqlite3_column_double(_stmt, CInt(index))
    }
    public func getFloat(column: T) -> Float {
        return Float(getDouble(column))
    }
    public func getString(column: T) -> String! {
        guard let index = _columns.indexOf({ $0 == "\(column)".lowercaseString }) else {
            return nil
        }
        let result = sqlite3_column_text(_stmt, CInt(index))
        return String.fromCString(UnsafePointer<CChar>(result))
    }
    public func getData(column: T) -> NSData! {
        guard let index = _columns.indexOf({ $0 == "\(column)".lowercaseString }) else {
            return nil
        }
        let data:UnsafePointer<Void> = sqlite3_column_blob(_stmt, CInt(index))
        let size:CInt = sqlite3_column_bytes(_stmt, CInt(index))
        return NSData(bytes:data, length: Int(size))
    }
    public func getDate(column: T) -> NSDate! {
        guard let index = _columns.indexOf({ $0 == "\(column)".lowercaseString }) else {
            return nil
        }
        let columnType = sqlite3_column_type(_stmt, CInt(index))
        
        switch columnType {
        case SQLITE_INTEGER:
            fallthrough
        case SQLITE_FLOAT:
            let time = sqlite3_column_double(_stmt, CInt(index))
            return NSDate(timeIntervalSince1970: time)
        case SQLITE_TEXT:
            let result = UnsafePointer<CChar>(sqlite3_column_text(_stmt, CInt(index)))
            let date = String.fromCString(result)
            let formater = NSDateFormatter()
            formater.dateFormat = "yyyy-MM-dd HH:mm:ss"
            //formater.calendar = NSCalendar.currentCalendar()
            return formater.dateFromString(date!)
        default:
            return nil
        }
        
    }
}




public class DBBindSet<T:DBTableType> {
    
    private var _stmt:COpaquePointer
    private var _columns:[T]
    init(_ stmt: COpaquePointer,_ columns:[T]) {
        _stmt = stmt
        _columns = columns
    }
    
    var bindCount:CInt {
        return sqlite3_bind_parameter_count(_stmt)
    }
    
    func bindClear() -> CInt {
        return sqlite3_clear_bindings(_stmt)
    }
    
    func bindValue<U>(value:U?, column:T) throws {
        if let index = _columns.indexOf(column) {
            try bindValue(value, index: index + 1)
        } else {
            print("SQL中不存在 列:\(column)")
            throw DBError(domain: "SQL中不存在 列:\(column)", code: -1, userInfo: nil)
        }
    }
    // 泛型绑定
    func bindValue<U>(columnValue:U?, index:Int) throws {
        
        var flag:CInt = SQLITE_ROW
        if let v = columnValue {
            switch v {
            case _ as NSNull:
                flag = sqlite3_bind_null(_stmt,CInt(index))
            case _ as DataBaseNull:
                flag = sqlite3_bind_null(_stmt,CInt(index))
            case let value as String:
                let string:NSString = value
                flag = sqlite3_bind_text(_stmt,CInt(index),string.UTF8String,-1,nil)
            case let value as Int:
                flag = sqlite3_bind_int64(_stmt,CInt(index),CLongLong(value))
            case let value as UInt:
                flag = sqlite3_bind_int64(_stmt,CInt(index),CLongLong(value))
            case let value as Int8:
                flag = sqlite3_bind_int(_stmt,CInt(index),CInt(value))
            case let value as UInt8:
                flag = sqlite3_bind_int(_stmt,CInt(index),CInt(value))
            case let value as Int16:
                flag = sqlite3_bind_int(_stmt,CInt(index),CInt(value))
            case let value as UInt16:
                flag = sqlite3_bind_int(_stmt,CInt(index),CInt(value))
            case let value as Int32:
                flag = sqlite3_bind_int(_stmt,CInt(index),CInt(value))
            case let value as UInt32:
                flag = sqlite3_bind_int64(_stmt,CInt(index),CLongLong(value))
            case let value as Int64:
                flag = sqlite3_bind_int64(_stmt,CInt(index),CLongLong(value))
            case let value as UInt64:
                flag = sqlite3_bind_int64(_stmt,CInt(index),CLongLong(value))
            case let value as Float:
                flag = sqlite3_bind_double(_stmt,CInt(index),CDouble(value))
            case let value as Double:
                flag = sqlite3_bind_double(_stmt,CInt(index),CDouble(value))
            case let value as NSDate:
                flag = sqlite3_bind_double(_stmt,CInt(index),CDouble(value.timeIntervalSince1970))
                //            case let value as Date:
            //                return sqlite3_bind_double(_stmt,CInt(index),CDouble(value.timeIntervalSince1970))
            case let value as NSData:
                flag = sqlite3_bind_blob(_stmt,CInt(index),value.bytes,-1,nil)
            default:
                let mirror = _reflect(v)
                if mirror.disposition == .Optional {
                    if mirror.count == 0 {
                        flag = sqlite3_bind_null(_stmt,CInt(index))
                    } else {
                        try bindValue(mirror[0].1.value, index: index)
                    }
                } else {
                    let string:NSString = "\(v)"
                    flag = sqlite3_bind_text(_stmt,CInt(index),string.UTF8String,-1,nil)
                }
            }
        } else {
            flag = sqlite3_bind_null(_stmt,CInt(index))
        }
        if flag != SQLITE_OK && flag != SQLITE_ROW {
            throw DBError(domain: "批量插入失败", code: Int(flag), userInfo: nil)
        }
    }
}

// MARK: - 数据库操作句柄
public class DBHandle {
    private var _handle:COpaquePointer
    internal init (_ handle:COpaquePointer) { _handle = handle }
    
    deinit { if _handle != nil { sqlite3_close(_handle) } }
    
    var version:Int {
        get {
            var stmt:COpaquePointer = nil
            if SQLITE_OK == sqlite3_prepare_v2(_handle, "PRAGMA user_version", -1, &stmt, nil) {
                defer { sqlite3_finalize(stmt) }
                return SQLITE_ROW == sqlite3_step(stmt) ? Int(sqlite3_column_int(stmt, 0)) : 0
            }
            return -1
        }
        set { sqlite3_exec(_handle, "PRAGMA user_version = \(newValue)", nil, nil, nil) }
    }
    
    public var lastError:DBError {
        let errorCode = sqlite3_errcode(_handle)
        let errorDescription = String.fromCString(sqlite3_errmsg(_handle)) ?? ""
        return DBError(domain: errorDescription, code: Int(errorCode), userInfo: nil)
    }
    private var _lastSQL:String?
    public var lastSQL:String { return _lastSQL ?? "" }
    
    // MARK: 执行SQL
    public func exec(sql:String) throws {
        _lastSQL = sql
        let flag = sqlite3_exec(_handle, sql, nil, nil, nil)
        if flag != SQLITE_OK { throw lastError }
    }
    public func exec(sql:SQLBase) throws {
        try exec(sql.description)
    }
    
    private func query(sql:String) throws -> COpaquePointer {
        var stmt:COpaquePointer = nil
        _lastSQL = sql
        if SQLITE_OK != sqlite3_prepare_v2(_handle, sql, -1, &stmt, nil) {
            sqlite3_finalize(stmt)
            throw lastError
        }
        return stmt //DBRowSet(stmt)
    }
    
    public var lastErrorMessage:String {
        return String.fromCString(sqlite3_errmsg(_handle)) ?? ""
    }
    public var lastInsertRowID:Int64 {
        return sqlite3_last_insert_rowid(_handle)
    }
    
    
}

// MARK: - base execute sql function
extension DBHandle {
    // 单表查询
    public func query<T:DBTableType>(sql:SQL<T>) throws -> DBResultSet<T> {
        return DBResultSet<T>(try query(sql.description))
    }
    
    // 双表查询
    public func query<T1:DBTableType, T2:DBTableType>(sql:SQL2<T1, T2>) throws -> DBResultSet<T1> {
        return DBResultSet<T1>(try query(sql.description))
    }
    
    // 清空表
    public func truncateTable<T:DBTableType>(_:T.Type) throws {
        try exec(DELETE.FROM(T))
        try exec(UPDATE(SQLiteSequence).SET(.seq == 0).WHERE(.name == T.table_name))
    }
    
    // 创建表
    public func createTable<T:DBTableType>(_:T.Type) throws {
        try  createTable(T.self, otherSQL:"")
    }
    public func createTableIfNotExists<T:DBTableType>(_:T.Type) {
        try! createTable(T.self, otherSQL:" IF NOT EXISTS")
    }
    private func createTable<T:DBTableType>(_:T.Type, otherSQL:String) throws {
        var columns:[T] = []
        var primaryKeys:[T] = []
        for column in T.enumerate() where !column.option.contains(.DeletedKey) {
            if column.option.contains(.PrimaryKey) {
                primaryKeys.append(column)
            }
            columns.append(column)
        }
        
        var params:String = columns.map({ "\($0) \($0.type)\($0.option.descriptionBy(primaryKeys.count > 1))" }).joinWithSeparator(", ")
        
        if primaryKeys.count > 1 {
            let keys = primaryKeys.map({ "\($0)" }).joinWithSeparator(", ")
            params.appendContentsOf(", PRIMARY KEY (\(keys))")
        }
        
        try exec("CREATE TABLE\(otherSQL) \(T.table_name) (\(params))")
    }
}

// MARK: - transaction 事务
extension DBHandle {
    // MARK: 开启事务 BEGIN TRANSACTION
    func beginTransaction() -> CInt {
        return sqlite3_exec(_handle,"BEGIN TRANSACTION",nil,nil,nil)
    }
    // MARK: 提交事务 COMMIT TRANSACTION
    func commitTransaction() -> CInt {
        return sqlite3_exec(_handle,"COMMIT TRANSACTION",nil,nil,nil)
    }
    // MARK: 回滚事务 ROLLBACK TRANSACTION
    func rollbackTransaction() -> CInt {
        return sqlite3_exec(_handle,"ROLLBACK TRANSACTION",nil,nil,nil)
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
//    func IN(sql:SQLBase) -> Self {
//        _handle.sql.append("IN(\(sql))")
//        return self
//    }
    
    func IN<I:CollectionType>(params:I) -> Self {
        var set = Set<String>()
        params.forEach { set.insert( "\($0)" ) }
        let text = set.joinWithSeparator(", ")
        _handle.sql.append("IN(\(text))")
        return self
    }
//    func IN(params:Any...) -> Self {
//        IN(params)
//        return self
//    }
    
    public var description: String {
        return _handle.sql.joinWithSeparator(" ")
    }
}



public class SQL<T:DBTableType>:SQLBase {
    public typealias Table = T
    
    public required init(_ handle:DBSQLHandle? = nil) { super.init(handle) }
    public override init(_ base: String) { super.init(base) }
    
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
    public var DESC:SQL<T> {
        _handle.sql.append("DESC")
        return self
    }
    public func ORDER(BY text:String) -> Self {
        _handle.sql.append("ORDER BY \(text)")
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
//    override func IN(sql: SQLBase) -> SQL<T> {
//        super.IN(sql)
//        return self
//    }
    func IN<U:DBTableType>(sql: SQL<U>) -> SQL<T> {
        _handle.sql.append("IN(\(sql.description))")
        return self
    }
    func IN(params:[String]) -> Self {
        super.IN(params)
        return self
    }
//    override func IN(params: Any...) -> Self {
//        super.IN(params)
//        return self
//    }
    
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
    func VALUES<U>(values:[U], into db:DBHandle, binds:(id:Int, value:U, bindSet:DBBindSet<T>) throws -> () ) throws {
        
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
        print("创建插入句柄")
        // 方法完成后释放 数据操作句柄
        //defer { sqlite3_finalize(stmt);print("释放插入句柄") }
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
        sqlite3_finalize(stmt);print("释放插入句柄")
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
//    override func IN(sql: SQLBase) -> Self {
//        super.IN(sql)
//        return self
//    }
//    override func IN(params: Any...) -> Self {
//        super.IN(params)
//        return self
//    }
    
    // MARK: update
//    func SET(@autoclosure   condition :() -> DBCondition<T1,T2>) -> Self {
//        _handle.addCondition(condition().debugDescription)
//        return self
//    }
//    func SET(@autoclosure   condition1:() -> DBCondition<T1,T2>,
//             @autoclosure _ condition2:() -> DBCondition<T1,T2>) -> Self {
//        _handle.addCondition([
//            condition1().debugDescription,
//            condition2().debugDescription
//            ].joinWithSeparator(", "))
//        return self
//    }
//    func SET(@autoclosure   condition1:() -> DBCondition<T1,T2>,
//             @autoclosure _ condition2:() -> DBCondition<T1,T2>,
//             @autoclosure _ condition3:() -> DBCondition<T1,T2>) -> Self {
//        _handle.addCondition([
//            condition1().debugDescription,
//            condition2().debugDescription,
//            condition3().debugDescription
//            ].joinWithSeparator(", "))
//        return self
//    }
//    func SET(@autoclosure   condition1:() -> DBCondition<T1,T2>,
//             @autoclosure _ condition2:() -> DBCondition<T1,T2>,
//             @autoclosure _ condition3:() -> DBCondition<T1,T2>,
//             @autoclosure _ condition4:() -> DBCondition<T1,T2>) -> Self {
//        _handle.addCondition([
//            condition1().debugDescription,
//            condition2().debugDescription,
//            condition3().debugDescription,
//            condition4().debugDescription
//            ].joinWithSeparator(", "))
//        return self
//    }
//    func SET(@autoclosure   condition1:() -> DBCondition<T1,T2>,
//             @autoclosure _ condition2:() -> DBCondition<T1,T2>,
//             @autoclosure _ condition3:() -> DBCondition<T1,T2>,
//             @autoclosure _ condition4:() -> DBCondition<T1,T2>,
//             @autoclosure _ condition5:() -> DBCondition<T1,T2>) -> Self {
//        _handle.addCondition([
//            condition1().debugDescription,
//            condition2().debugDescription,
//            condition3().debugDescription,
//            condition4().debugDescription,
//            condition5().debugDescription
//            ].joinWithSeparator(", "))
//        return self
//    }
    
}

extension SQL {
    public func WHERE(@autoclosure condition:() -> DBCondition<T,T>) -> Self {
        _handle.addCondition(condition().description)
        return self
    }
    public func AND(@autoclosure condition:() -> DBCondition<T,T>) -> Self {
        _handle.addCondition(condition().description)
        return self
    }
    public func OR(@autoclosure condition:() -> DBCondition<T,T>) -> Self {
        _handle.addCondition(condition().description)
        return self
    }
    public func XOR(@autoclosure condition:() -> DBCondition<T,T>) -> Self {
        _handle.addCondition(condition().description)
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
public var DELETE:SQLBase { return SQLBase("DELETE") }
public var SELECT:SQLBase { return SQLBase("SELECT") }
public var INSERT:SQLBase { return SQLBase("INSERT") }
public var ALERT :SQLBase { return SQLBase("ALERT")  }

public func RANDOM() -> String { return "RANDOM()" }


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

// MARK: - SQLite 默认序列表
public enum SQLiteSequence:String, DBTableType {
    case name
    case seq
    
    public var type: DataBaseColumnType {
        switch self {
        case .name: return .Text
        case .seq : return .Integer
        }
    }
    public var option: DataBaseColumnOptions {
        switch self {
        case .name: return .PrimaryKey
        default:    return .NotNull
        }
    }
    public static let table_name:String = "sqlite_sequence"
}

public enum SQLiteMaster:String, DBTableType {
    case type
    case name
    case tbl_name
    case rootpage
    case sql
    
    public var type: DataBaseColumnType {
        switch self {
        case .rootpage: return .Integer
        default : return .Text
        }
    }
    public var option: DataBaseColumnOptions {
        return .NotNull
    }
    public static let table_name:String = "sqlite_master"
}
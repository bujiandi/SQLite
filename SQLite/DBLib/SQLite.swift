//
//  SQLite.swift
//  SQLite
//
//  Created by yFenFen on 16/5/18.
//  Copyright © 2016 yFenFen. All rights reserved.
//

import Foundation

// MARK: - ErrorType
public class DBError : NSError {}

// MARK: - protocols 接口(创建数据表需用枚举实现以下接口) 
/// 注: enum OneTable: String, DBTableType
public protocol DBTableType: RawRepresentable, Hashable {
    static var table_name:String { get }
    
    var type: DataBaseColumnType { get }
    var option: DataBaseColumnOptions { get }
    
    // optional
    var defaultValue:CustomStringConvertible? { get }
}

// MARK: - enum 枚举(数据库只读模式等)
public enum DBOpenMode: CInt {
    case ReadWrite = 0x00000002
    case ReadOnly  = 0x00000001
}

// MARK: - 数据库操作句柄
public class DBHandle {
    private var _handle:COpaquePointer
    private init (_ handle:COpaquePointer) { _handle = handle }
    
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
}

// MARK: - SQLite
public class SQLite {
    private var _path:String
    private var _onVersionUpdate:(db:DBHandle, oldVersion:Int, newVersion:Int) -> Bool
    private var _version:Int

    public var fullPath:String { return _path }
    public init(name:String, version:Int, onVersionUpdate:(db:DBHandle, oldVersion:Int, newVersion:Int) -> Bool) {
        let document = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] as NSString
        _path = document.stringByAppendingPathComponent(name)
        _version = version
        _onVersionUpdate = onVersionUpdate
    }
    public init(path:String, version:Int, onVersionUpdate:(db:DBHandle, oldVersion:Int, newVersion:Int) -> Bool) {
        _path = path
        _version = version
        _onVersionUpdate = onVersionUpdate
    }
    
    public func open(mode:DBOpenMode = .ReadWrite) throws -> DBHandle {
        var handle:COpaquePointer = nil
        let dbPath:NSString = fullPath
        let dirPath = dbPath.stringByDeletingLastPathComponent
        let fileManager:NSFileManager = NSFileManager.defaultManager()
        var isDir:ObjCBool = false
        
        if !fileManager.fileExistsAtPath(dirPath, isDirectory: &isDir) || isDir {
            try fileManager.createDirectoryAtPath(dirPath, withIntermediateDirectories: true, attributes: nil)
        }
        //sqlite3_open(dbPath.UTF8String, &handle)
        let result = sqlite3_open_v2(dbPath.UTF8String, &handle, mode.rawValue, nil)
        if result != SQLITE_OK {
            let errorDescription = String.fromCString(sqlite3_errmsg(handle)) ?? ""
            sqlite3_close(handle)
            throw DBError(domain: errorDescription, code: Int(result), userInfo: nil)
        }
        let db = DBHandle(handle)
        let oldVersion = db.version
        if _version != oldVersion {
            if _onVersionUpdate(db: db, oldVersion: oldVersion, newVersion: _version) {
                db.version = _version
            } else { print("未更新数据库版本:\(_version) old:\(oldVersion)") }
        }
        return db
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

// MARK: - base execute sql function
extension DBHandle {
    public func exec(sql:String) throws {
        _lastSQL = sql
        let flag = sqlite3_exec(_handle, sql, nil, nil, nil)
        if flag != SQLITE_OK { throw lastError }
    }
    public func exec(sql:SQLBase) throws {
        try exec(sql.description)
    }
    
    internal func query(sql:String) throws -> COpaquePointer {
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
    
    // 单表查询
    public func query<T:DBTableType>(sql:SQL<T>) throws -> DBResultSet<T> {
        return DBResultSet<T>(try query(sql.description))
    }
    
    // 双表查询
    public func query<T1:DBTableType, T2:DBTableType>(sql:SQL2<T1, T2>) throws -> DBResultSet<T1> {
        return DBResultSet<T1>(try query(sql.description))
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
    func bindValue<U>(columnValue:U?, column:T) throws {
        if let index = _columns.indexOf(column) {
            try bindValue(columnValue, index: index)
        } else { print("SQL中不存在 列:\(column)") }
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

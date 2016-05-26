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
    
    // MARK: 执行SQL
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

// MARK: - enum 枚举(数据库只读模式等)
public enum DBOpenMode: CInt {
    case ReadWrite = 0x00000002
    case ReadOnly  = 0x00000001
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





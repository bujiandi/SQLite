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


// MARK: - enum 枚举(数据库只读模式等)
public enum DBOpenMode: CInt {
    case ReadWrite = 0x00000002 // SQLITE_OPEN_READWRITE
    case ReadOnly  = 0x00000001 // SQLITE_OPEN_READONLY
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





//
//  SQLite.swift
//  SQLite
//
//  Created by yFenFen on 16/5/18.
//  Copyright © 2016 yFenFen. All rights reserved.
//

import Foundation
//#if SQLITE_SWIFT_STANDALONE
//import sqlite3
//#else
//import CSQLite
//#endif
// MARK: - ErrorType
open class DBError : NSError {}


// MARK: - enum 枚举(数据库只读模式等)
public enum DBOpenMode: CInt {
    case readWrite = 0x00000006 // SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE
    case readOnly  = 0x00000001 // SQLITE_OPEN_READONLY
}

// MARK: - SQLite
open class SQLite {
    fileprivate var _path:String
    fileprivate var _onVersionUpdate:(_ db:DBHandle, _ oldVersion:Int, _ newVersion:Int) -> Bool
    fileprivate var _version:Int
    
    open var fullPath:String { return _path }
    public init(name:String, version:Int, onVersionUpdate:@escaping (_ db:DBHandle, _ oldVersion:Int, _ newVersion:Int) -> Bool) {
        let document = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString
        _path = document.appendingPathComponent(name)
        _version = version
        _onVersionUpdate = onVersionUpdate
    }
    public init(path:String, version:Int, onVersionUpdate:@escaping (_ db:DBHandle, _ oldVersion:Int, _ newVersion:Int) -> Bool) {
        _path = path
        _version = version
        _onVersionUpdate = onVersionUpdate
    }
    
    open func open(_ mode:DBOpenMode = .readWrite) throws -> DBHandle {
        var handle:OpaquePointer? = nil
        let dbPath:NSString = fullPath as NSString
        let dirPath = dbPath.deletingLastPathComponent
        let fileManager:FileManager = FileManager.default
        var isDir:ObjCBool = false
        
        if !fileManager.fileExists(atPath: dirPath, isDirectory: &isDir) || !isDir.boolValue {
            try fileManager.createDirectory(atPath: dirPath, withIntermediateDirectories: true, attributes: nil)
        }
        let result = sqlite3_open_v2(dbPath.utf8String, &handle, mode.rawValue, nil)
        if result != SQLITE_OK {
            let errorDescription = String(cString: sqlite3_errmsg(handle)) 
            sqlite3_close(handle)
            throw DBError(domain: errorDescription, code: Int(result), userInfo: nil)
        }
        let db = DBHandle(handle)
        let oldVersion = db.version
        if _version != oldVersion {
            if _onVersionUpdate(db, oldVersion, _version) {
                db.version = _version
            } else { print("未更新数据库版本:\(_version) old:\(oldVersion)") }
        }
        return db
    }
}





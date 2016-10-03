//
//  DBErrorType.swift
//  SQLite
//
//  Created by yFenFen on 16/5/26.
//  Copyright © 2016 yFenFen. All rights reserved.
//

import Foundation

public enum SQLiteErrorType : Int, CustomStringConvertible, CustomDebugStringConvertible, Error {
    case ok         =  0//SQLITE_OK         Successful result
    case error      =  1//SQLITE_ERROR      SQL error or missing database
    case `internal` =  2//SQLITE_INTERNAL   Internal logic error in SQLite
    case perm       =  3//SQLITE_PERM       Access permission denied
    case abort      =  4//SQLITE_ABORT      Callback routine requested an abort
    case busy       =  5//SQLITE_BUSY       The database file is locked
    case locked     =  6//SQLITE_LOCKED     A table in the database is locked
    case nomem      =  7//SQLITE_NOMEM      A malloc() failed
    case readonly   =  8//SQLITE_READONLY   Attempt to write a readonly database
    case interrupt  =  9//SQLITE_INTERRUPT  Operation terminated by sqlite3_interrupt()
    case ioerr      = 10//SQLITE_IOERR      Some kind of disk I/O error occurred
    case corrupt    = 11//SQLITE_CORRUPT    The database disk image is malformed
    case notfound   = 12//SQLITE_NOTFOUND   Unknown opcode in sqlite3_file_control()
    case full       = 13//SQLITE_FULL       Insertion failed because database is full
    case cantopen   = 14//SQLITE_CANTOPEN   Unable to open the database file
    case `protocol` = 15//SQLITE_PROTOCOL   Database lock protocol error
    case empty      = 16//SQLITE_EMPTY      Database is empty
    case schema     = 17//SQLITE_SCHEMA     The database schema changed
    case toobig     = 18//SQLITE_TOOBIG     String or BLOB exceeds size limit
    case constraint = 19//SQLITE_CONSTRAINT Abort due to constraint violation
    case mismatch   = 20//SQLITE_MISMATCH   Data type mismatch
    case misuse     = 21//SQLITE_MISUSE     Library used incorrectly
    case nolfs      = 22//SQLITE_NOLFS      Uses OS features not supported on host
    case auth       = 23//SQLITE_AUTH       Authorization denied
    case format     = 24//SQLITE_FORMAT     Auxiliary database format error
    case range      = 25//SQLITE_RANGE      2nd parameter to sqlite3_bind out of range
    case notadb     = 26//SQLITE_NOTADB     File opened that is not a database file
    case notice     = 27//SQLITE_NOTICE     Notifications from sqlite3_log()
    case warning    = 28//SQLITE_WARNING    Warnings from sqlite3_log()
    case custom     = 99//CUSTOM            insert error
    case row       = 100//SQLITE_ROW        sqlite3_step() has another row ready
    case done      = 101//SQLITE_DONE       sqlite3_step() has finished executing
    
    public var description: String {
        switch Locale.current.calendar.identifier {
        case Calendar.Identifier.chinese: return chineseDescription
        default: return defaultDescription
        }
    }
    
    private var chineseDescription:String {
        switch self {
        case .ok          : return "操作成功"
        case .error       : return "SQL 语句错误 或 数据丢失"
        case .internal    : return "SQLite 内部逻辑错误"
        case .perm        : return "拒绝存取"
        case .abort       : return "回调函数请求取消操作"
        case .busy        : return "数据库被他人使用(已锁定)"
        case .locked      : return "此表被其他人使用(已锁定)"
        case .nomem       : return "内存不足"
        case .readonly    : return "不能在只读模式下写入数据库"
        case .interrupt   : return "操作被 sqlite3_interrupt() 终止"
        case .ioerr       : return "磁盘 I/O 读写发生异常"
        case .corrupt     : return "数据库磁盘镜像损坏"
        case .notfound    : return "sqlite3_file_control() 找不到文件"
        case .full        : return "数据库已满，插入失败"
        case .cantopen    : return "无法打开数据库文件"
        case .protocol    : return "数据库接口锁定"
        case .empty       : return "数据库是空的"
        case .schema      : return "数据库 schema 改变"
        case .toobig      : return "String 或 BLOB 大小超出限制"
        case .constraint  : return "违反规则强行中止"
        case .mismatch    : return "数据类型不当"
        case .misuse      : return "库Library 使用不当"
        case .nolfs       : return "系统 host 不支持"
        case .auth        : return "授权失败"
        case .format      : return "数据库格式化错误"
        case .range       : return "sqlite3_bind 第二个参数索引超出范围"
        case .notadb      : return "文件并非数据库文件"
        case .notice      : return "sqlite3_log() 通知更新"
        case .warning     : return "sqlite3_log() 警告更新"
        case .custom      : return "自定义插入失败"
        case .row         : return "sqlite3_step() 另有一行数据已经就绪"
        case .done        : return "sqlite3_step() 执行成功"
        }
    }
    
    private var defaultDescription:String {
        switch self {
        case .ok          : return "Successful result"
        case .error       : return "SQL error or missing database"
        case .internal    : return "Internal logic error in SQLite"
        case .perm        : return "Access permission denied"
        case .abort       : return "Callback routine requested an abort"
        case .busy        : return "The database file is locked"
        case .locked      : return "A table in the database is locked"
        case .nomem       : return "A malloc() failed"
        case .readonly    : return "Attempt to write a readonly database"
        case .interrupt   : return "Operation terminated by sqlite3_interrupt()"
        case .ioerr       : return "Some kind of disk I/O error occurred"
        case .corrupt     : return "The database disk image is malformed"
        case .notfound    : return "Unknown opcode in sqlite3_file_control()"
        case .full        : return "Insertion failed because database is full"
        case .cantopen    : return "Unable to open the database file"
        case .protocol    : return "Database lock protocol error"
        case .empty       : return "Database is empty"
        case .schema      : return "The database schema changed"
        case .toobig      : return "String or BLOB exceeds size limit"
        case .constraint  : return "Abort due to constraint violation"
        case .mismatch    : return "Data type mismatch"
        case .misuse      : return "Library used incorrectly"
        case .nolfs       : return "Uses OS features not supported on host"
        case .auth        : return "Authorization denied"
        case .format      : return "Auxiliary database format error"
        case .range       : return "2nd parameter to sqlite3_bind out of range"
        case .notadb      : return "File opened that is not a database file"
        case .notice      : return "Notifications from sqlite3_log()"
        case .warning     : return "Warnings from sqlite3_log()"
        case .custom      : return "custom insert error"
        case .row         : return "sqlite3_step() has another row ready"
        case .done        : return "sqlite3_step() has finished executing"
        }
    }
    
    public var debugDescription: String { return "Error code \(rawValue) is #define SQLITE_\(self) with \(description)" }
}

extension DBError {
    
    var type:SQLiteErrorType {
        return SQLiteErrorType(rawValue: code) ?? SQLiteErrorType.error
    }
}

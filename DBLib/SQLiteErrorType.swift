//
//  DBErrorType.swift
//  SQLite
//
//  Created by yFenFen on 16/5/26.
//  Copyright © 2016 yFenFen. All rights reserved.
//

import Foundation

public enum SQLiteErrorType : Int, CustomStringConvertible, CustomDebugStringConvertible, ErrorType {
    case OK         =  0//SQLITE_OK         Successful result
    case ERROR      =  1//SQLITE_ERROR      SQL error or missing database
    case INTERNAL   =  2//SQLITE_INTERNAL   Internal logic error in SQLite
    case PERM       =  3//SQLITE_PERM       Access permission denied
    case ABORT      =  4//SQLITE_ABORT      Callback routine requested an abort
    case BUSY       =  5//SQLITE_BUSY       The database file is locked
    case LOCKED     =  6//SQLITE_LOCKED     A table in the database is locked
    case NOMEM      =  7//SQLITE_NOMEM      A malloc() failed
    case READONLY   =  8//SQLITE_READONLY   Attempt to write a readonly database
    case INTERRUPT  =  9//SQLITE_INTERRUPT  Operation terminated by sqlite3_interrupt()
    case IOERR      = 10//SQLITE_IOERR      Some kind of disk I/O error occurred
    case CORRUPT    = 11//SQLITE_CORRUPT    The database disk image is malformed
    case NOTFOUND   = 12//SQLITE_NOTFOUND   Unknown opcode in sqlite3_file_control()
    case FULL       = 13//SQLITE_FULL       Insertion failed because database is full
    case CANTOPEN   = 14//SQLITE_CANTOPEN   Unable to open the database file
    case PROTOCOL   = 15//SQLITE_PROTOCOL   Database lock protocol error
    case EMPTY      = 16//SQLITE_EMPTY      Database is empty
    case SCHEMA     = 17//SQLITE_SCHEMA     The database schema changed
    case TOOBIG     = 18//SQLITE_TOOBIG     String or BLOB exceeds size limit
    case CONSTRAINT = 19//SQLITE_CONSTRAINT Abort due to constraint violation
    case MISMATCH   = 20//SQLITE_MISMATCH   Data type mismatch
    case MISUSE     = 21//SQLITE_MISUSE     Library used incorrectly
    case NOLFS      = 22//SQLITE_NOLFS      Uses OS features not supported on host
    case AUTH       = 23//SQLITE_AUTH       Authorization denied
    case FORMAT     = 24//SQLITE_FORMAT     Auxiliary database format error
    case RANGE      = 25//SQLITE_RANGE      2nd parameter to sqlite3_bind out of range
    case NOTADB     = 26//SQLITE_NOTADB     File opened that is not a database file
    case NOTICE     = 27//SQLITE_NOTICE     Notifications from sqlite3_log()
    case WARNING    = 28//SQLITE_WARNING    Warnings from sqlite3_log()
    case CUSTOM     = 99//CUSTOM            insert error
    case ROW       = 100//SQLITE_ROW        sqlite3_step() has another row ready
    case DONE      = 101//SQLITE_DONE       sqlite3_step() has finished executing
    
    public var description: String {
        switch NSLocale.currentLocale().localeIdentifier {
        case NSCalendarIdentifierChinese: return chineseDescription
        default: return defaultDescription
        }
    }
    
    private var chineseDescription:String {
        switch self {
        case .OK          : return "操作成功"
        case .ERROR       : return "SQL 语句错误 或 数据丢失"
        case .INTERNAL    : return "SQLite 内部逻辑错误"
        case .PERM        : return "拒绝存取"
        case .ABORT       : return "回调函数请求取消操作"
        case .BUSY        : return "数据库被他人使用(已锁定)"
        case .LOCKED      : return "此表被其他人使用(已锁定)"
        case .NOMEM       : return "内存不足"
        case .READONLY    : return "不能在只读模式下写入数据库"
        case .INTERRUPT   : return "操作被 sqlite3_interrupt() 终止"
        case .IOERR       : return "磁盘 I/O 读写发生异常"
        case .CORRUPT     : return "数据库磁盘镜像损坏"
        case .NOTFOUND    : return "sqlite3_file_control() 找不到文件"
        case .FULL        : return "数据库已满，插入失败"
        case .CANTOPEN    : return "无法打开数据库文件"
        case .PROTOCOL    : return "数据库接口锁定"
        case .EMPTY       : return "数据库是空的"
        case .SCHEMA      : return "数据库 schema 改变"
        case .TOOBIG      : return "String 或 BLOB 大小超出限制"
        case .CONSTRAINT  : return "违反规则强行中止"
        case .MISMATCH    : return "数据类型不当"
        case .MISUSE      : return "库Library 使用不当"
        case .NOLFS       : return "系统 host 不支持"
        case .AUTH        : return "授权失败"
        case .FORMAT      : return "数据库格式化错误"
        case .RANGE       : return "sqlite3_bind 第二个参数索引超出范围"
        case .NOTADB      : return "文件并非数据库文件"
        case .NOTICE      : return "sqlite3_log() 通知更新"
        case .WARNING     : return "sqlite3_log() 警告更新"
        case .CUSTOM      : return "自定义插入失败"
        case .ROW         : return "sqlite3_step() 另有一行数据已经就绪"
        case .DONE        : return "sqlite3_step() 执行成功"
        }
    }
    
    private var defaultDescription:String {
        switch self {
        case .OK          : return "Successful result"
        case .ERROR       : return "SQL error or missing database"
        case .INTERNAL    : return "Internal logic error in SQLite"
        case .PERM        : return "Access permission denied"
        case .ABORT       : return "Callback routine requested an abort"
        case .BUSY        : return "The database file is locked"
        case .LOCKED      : return "A table in the database is locked"
        case .NOMEM       : return "A malloc() failed"
        case .READONLY    : return "Attempt to write a readonly database"
        case .INTERRUPT   : return "Operation terminated by sqlite3_interrupt()"
        case .IOERR       : return "Some kind of disk I/O error occurred"
        case .CORRUPT     : return "The database disk image is malformed"
        case .NOTFOUND    : return "Unknown opcode in sqlite3_file_control()"
        case .FULL        : return "Insertion failed because database is full"
        case .CANTOPEN    : return "Unable to open the database file"
        case .PROTOCOL    : return "Database lock protocol error"
        case .EMPTY       : return "Database is empty"
        case .SCHEMA      : return "The database schema changed"
        case .TOOBIG      : return "String or BLOB exceeds size limit"
        case .CONSTRAINT  : return "Abort due to constraint violation"
        case .MISMATCH    : return "Data type mismatch"
        case .MISUSE      : return "Library used incorrectly"
        case .NOLFS       : return "Uses OS features not supported on host"
        case .AUTH        : return "Authorization denied"
        case .FORMAT      : return "Auxiliary database format error"
        case .RANGE       : return "2nd parameter to sqlite3_bind out of range"
        case .NOTADB      : return "File opened that is not a database file"
        case .NOTICE      : return "Notifications from sqlite3_log()"
        case .WARNING     : return "Warnings from sqlite3_log()"
        case .CUSTOM      : return "custom insert error"
        case .ROW         : return "sqlite3_step() has another row ready"
        case .DONE        : return "sqlite3_step() has finished executing"
        }
    }
    
    public var debugDescription: String { return "Error code \(rawValue) is #define SQLITE_\(self) with \(description)" }
}

extension DBError {
    
    var type:SQLiteErrorType {
        return SQLiteErrorType(rawValue: code) ?? SQLiteErrorType.ERROR
    }
}
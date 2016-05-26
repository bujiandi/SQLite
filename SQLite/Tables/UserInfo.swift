//
//  UserInfo.swift
//  SQLite
//
//  Created by yFenFen on 16/5/18.
//  Copyright © 2016 yFenFen. All rights reserved.
//

import Foundation

enum UserInfo: String, DBTableType {
    
    static let table_name = "user_info"

    case userid
    case username
    case password
    case phonenum
    
    var type: DataBaseColumnType {
        switch self {
        case .userid:   return .Integer
        case .username: return .Text
        case .password: return .Text
        case .phonenum: return .Text
        }
    }
    var option: DataBaseColumnOptions {
        switch self {
        case .userid:   return .PrimaryKeyAutoincrement
        case .username: return .NotNull
        case .password: return .NotNull
        case .phonenum: return .None
        }
    }

}

enum PayInfo: String, DBTableType {
    
    static let table_name = "pay_info"
    
    case userid
    case product
    case money
    case timestamp
    
    var type: DataBaseColumnType {
        switch self {
        case .userid:   return .Integer
        case .product:  return .Text
        case .money:    return .Float
        case .timestamp: return .Float
        }
    }
    var option: DataBaseColumnOptions {
        switch self {
        case .userid:   return .PrimaryKeyAutoincrement
        case .product:  return .NotNull
        case .money:    return .NotNull
        case .timestamp: return .None
        }
    }
}

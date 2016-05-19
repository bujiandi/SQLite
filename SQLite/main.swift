//
//  main.swift
//  SQLite
//
//  Created by yFenFen on 16/5/18.
//  Copyright © 2016 yFenFen. All rights reserved.
//

import Foundation



class Book {
    init() {
        let db = SQLite.open(.ReadWrite)
        
        let sql = db.createSQLHandleWithTables(UserInfo.self, PayInfo.self)
        
        
        sql.SELECT([.password, .phonenum], [.money, .product]).FROM(PayInfo.self).WHERE(.money, "=51239").WHERE(.product, "=9")
        
        let sql1 = db.createSQLHandleWithTable(UserInfo)
        
        sql1.SELECT(.password, .userid)

        
        sql1.SELECT(.userid, .password, .phonenum).FROM(UserInfo).WHERE(.userid, "=5")
        
        //db.query(sql)
    }
}


let book = Book()

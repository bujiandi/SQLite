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
        //let db = SQLite.open(.ReadWrite)
        
        //let sql = db.createSQLHandleWithTables(UserInfo.self, PayInfo.self)
        var abc = [1,2,3,4,5]
        abc.sortInPlace(<)
        
        let sql = SQL2<UserInfo, PayInfo>()
        
        
        
        sql.SELECT([.password, .phonenum], [.money, .product])
            .FROM(UserInfo.self, PayInfo.self)
            .WHERE(.userid, "=", .userid)
            .AND(.money, "=5")
        print(sql)
        //let sql1 = db.createSQLHandleWithTable(UserInfo)
        //let sql1 = SQL<UserInfo>()
        
        //sql1.SELECT(.password, .userid)
        
        let sql0 = SQL<UserInfo>().SELECT.COUNT(.username, .phonenum, .username).FROM(UserInfo).WHERE(.username == 2)
        print("sql0",sql0)

        let sql1 = SQL<UserInfo>().SELECT.COUNT(*).FROM(UserInfo).WHERE(.password == "32123").AND(.username == 9532)
        print("sql1",sql1)

        //sql1.SELECT(.userid, .password, .phonenum).FROM(UserInfo).WHERE(.userid < maxUserid).AND(.phonenum < 9).IN(1,2,3,4,5).DELETE.AND(.userid < 8)
        
        
        let sql2 = SELECT(TOP: 5) * FROM(PayInfo).WHERE(.money < 9).AND(.timestamp > DB_NOW).OR(.product).IS(NULL)
        print("sql2",sql2)
        
        let sql3 = DELETE.FROM(PayInfo).WHERE(.userid == 5)
        print("sql3",sql3)
        
        let sql4 = UPDATE(PayInfo).SET(.money == 9, .product == "3322").WHERE(.money + 8 - 9 != 9)
        print("sql4",sql4)
        
        let password:String? = "nihao123"
        let sql5 = SELECT * FROM(UserInfo).WHERE(.password != password)
        
        print("sql5",sql5)
        
        let sql6 = INSERT.OR.REPLACE.INTO(UserInfo)[.userid, .password, .username].VALUES(1,"33123","xiaobo")
        print("sql6",sql6)

        print(DB_NOW)
        sleep(1)
        print(DB_NOW)

        
        //db.query(sql)
    }
}


let book = Book()

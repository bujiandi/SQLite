# FFSQLite

## 特点

- 使用Swift语言
- 方便使用，链式语法。

## 使用

### 建立表模型

需继承DBTableType协议

``` swift
enum UserInfo: String, DBTableType {

    static let table_name = "UserInfo"

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
```


### 单表查询
```
let sql = SQL<UserInfo>().SELECT.COUNT(.username, .phonenum, .username).FROM(UserInfo).WHERE(.username == 2)
```

### 多表查询

```
let sql = SQL2<UserInfo, PayInfo>()
sql.SELECT([.password, .phonenum], [.money, .product]).FROM(UserInfo.self, PayInfo.self).WHERE(.userid == .userid).AND(.money == .null)
```

### 关联查询

```
let sql = SELECT * FROM(UserInfo).LEFT.JOIN(PayInfo).ON(.userid == .userid).WHERE(.password != password)
```

### 删除数据

```
let sql = DELETE.FROM(PayInfo).WHERE(.userid == 5)
```

### 插入数据

```
let sql = INSERT.OR.REPLACE.INTO(UserInfo)[.userid, .password, .username].VALUES(1,”12345”,”fenfen”)
```

### 更新数据

```
let sql = UPDATE(PayInfo).SET(.money == 9, .product == "3322").WHERE(.money + 8 - 9 != 9)
```

## License
FFSQLite is available under the MIT license. See \[the LICENSE file](./LICENSE.txt) for more information.

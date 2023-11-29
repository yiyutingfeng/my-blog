---
title: OLTP批量操作
tags:
categories:
description:
    批量操作有哪些优化方法
---

主要从减少磁盘I/O和减少网络通信来提高性能

### 使用批量插入语句

一次性插入多行数据，而不是逐行插入

``` sql
-- 创建表
CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50),
    age INT
);

-- 逐行插入
INSERT INTO users (name, age) VALUES ('John', 25);
INSERT INTO users (name, age) VALUES ('Alice', 30);
-- ...
INSERT INTO users (name, age) VALUES ('Bob', 22);

-- 批量插入
INSERT INTO users (name, age) VALUES
  ('John', 25),
  ('Alice', 30),
  -- ...
  ('Bob', 22);
```

### 使用LOAD DATA INFILE

LOAD DATA INFILE是一个高效的导入数据的方法，比INSERT语句更快。它直接从文件加载数据，而不需要逐行解析 SQL 语句。

以下是一个使用 `LOAD DATA INFILE` 的简单示例，假设有一个包含用户数据的 CSV 文件：

``` csv
John,25
Alice,30
Bob,22
```

然后可以使用以下 SQL 语句将这些数据导入到 `users` 表中：

``` sql
LOAD DATA INFILE '/path/to/your/file.csv'
INTO TABLE users
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
(name, age);
```

请注意：

- `/path/to/your/file.csv` 是你的 CSV 文件的路径，确保 OLTP 有权限读取该文件。
- `FIELDS TERMINATED BY ','` 指定字段之间的分隔符，这里使用逗号。
- `LINES TERMINATED BY '\n'` 指定行之间的分隔符，这里使用换行符。
- `(name, age)` 指定了数据文件中每行对应的列。

在执行此语句之前，请确保文件路径正确，OLTP 有权访问文件，并且文件格式与 `LOAD DATA INFILE` 语句中的格式一致。

如果你使用的 OLTP 是在安全模式下运行，可能需要考虑设置 `--secure-file-priv` 选项，以指定允许加载文件的目录。

### 关闭自动提交

在进行大量的插入、更新或删除操作时，可以关闭自动提交，这样可以减少磁盘I/O操作，提高性能。

``` sql
START TRANSACTION;
-- 执行大批量插入、更新或删除操作
COMMIT;
```

### 使用预处理语句

预处理语句是一种用于执行参数化 SQL 查询的方法。它可以帮助提高性能、防止 SQL 注入攻击，以及提高代码的可读性。

``` sql
-- 准备语句
PREPARE stmt FROM 'INSERT INTO users (name, age) VALUES (?, ?)';

-- 设置参数并执行
SET @name = 'John', @age = 25;
EXECUTE stmt USING @name, @age;

-- 重复使用
SET @name = 'Alice', @age = 30;
EXECUTE stmt USING @name, @age;

-- 还可以继续添加更多的参数
SET @name = 'Bob', @age = 22;
EXECUTE stmt USING @name, @age;

-- 完成后释放
DEALLOCATE PREPARE stmt;
```

### 合理使用索引

在大批量操作之前考虑是否需要去除或禁用一些索引，然后在操作完成后重新创建或启用索引。

``` sql
-- 禁用索引
ALTER TABLE users DISABLE KEYS;

-- 执行大批量插入操作

-- 重新启用索引
ALTER TABLE users ENABLE KEYS;
```

### 合理调整服务器参数

根据实际情况调整OLTP配置参数，例如：

```sql
-- 修改缓冲池大小
SET GLOBAL innodb_buffer_pool_size = 2G;

-- 修改日志文件大小
SET GLOBAL innodb_log_file_size = 256M;
```

### 总结

1. 尽可能减少SQL数, 例如逐行插入改为批量插入
2. 大数据量插入使用LOAD DATA INFILE
3. 关闭自动提交（启用事务，批量操作结束后, commit），可有效提升批量操作性能

---
title: Doris的数据模型
date: 2023-08-07 17:59:02
tags:
---

# Doris数据模型

Doris 数据模型上目前分为三类:
- AGGREGATE
- UNIQUE
- DUPLICATE
在 Aggregate、Unique 和 Duplicate 三种数据模型中。底层的数据存储，是按照各自建表语句中，AGGREGATE KEY、UNIQUE KEY 和 DUPLICATE KEY 中指定的列（**不支持任意列，必须为前n列**）进行排序存储的

<!-- more -->

## AGGREGATE模型

### 介绍
假设有如下数据表模式：

| ColumnName      | Type        | AggregationType | Comment              |
| --------------- | ----------- | --------------- | -------------------- |
| user_id         | LARGEINT    |                 | 用户id               |
| date            | DATE        |                 | 数据灌入日期         |
| city            | VARCHAR(20) |                 | 用户所在城市         |
| age             | SMALLINT    |                 | 用户年龄             |
| sex             | TINYINT     |                 | 用户性别             |
| last_visit_date | DATETIME    | REPLACE         | 用户最后一次访问时间 |
| cost            | BIGINT      | SUM             | 用户总消费           |
| max_dwell_time  | INT         | MAX             | 用户最大停留时间     |
| min_dwell_time  | INT         | MIN             | 用户最小停留时间     |

该模型将表中的列按照是否设置了 `AggregationType`，分为 Key (维度列) 和 Value（指标列）。没有设置 `AggregationType` 的，如 `user_id`、`date`、`age` ... 等称为 **Key**，而设置了 `AggregationType` 的称为 **Value**。

如果转换成建表语句则如下（省略建表语句中的 Partition 和 Distribution 信息）
```sql
CREATE TABLE IF NOT EXISTS example_db.example_tbl
(
    `user_id` LARGEINT NOT NULL COMMENT "用户id",
    `date` DATE NOT NULL COMMENT "数据灌入日期时间",
    `city` VARCHAR(20) COMMENT "用户所在城市",
    `age` SMALLINT COMMENT "用户年龄",
    `sex` TINYINT COMMENT "用户性别",
    `last_visit_date` DATETIME REPLACE DEFAULT "1970-01-01 00:00:00" COMMENT "用户最后一次访问时间",
    `cost` BIGINT SUM DEFAULT "0" COMMENT "用户总消费",
    `max_dwell_time` INT MAX DEFAULT "0" COMMENT "用户最大停留时间",
    `min_dwell_time` INT MIN DEFAULT "99999" COMMENT "用户最小停留时间"
)
AGGREGATE KEY(`user_id`, `date`, `city`, `age`, `sex`)
DISTRIBUTED BY HASH(`user_id`) BUCKETS 1
PROPERTIES (
"replication_allocation" = "tag.location.default: 1"
);
```

{% note warning %}
**注意**
1. `AGGREGATE KEY` 必须为前连续N列
2. 除`AGGREGATE KEY`指定的列，所有列都必须指定聚合方式
{% endnote %}

AGGREGATE KEY相同时，新旧记录进行聚合，目前有以下聚合方式：

| 聚合方式 | 说明 |
| :---: | --- |
| SUM | 求和。适用数值类型。|
| MIN | 求最小值。适合数值类型。|
| MAX |求最大值。适合数值类型。|
| REPLACE | 替换。对于维度列相同的行，指标列会按照导入的先后顺序，后导入的替换先导入的。|
| REPLACE_IF_NOT_NULL |非空值替换。和 REPLACE 的区别在于对于null值，不做替换。字段默认值要给NULL，而不能是空字符串，否则会被替换成新字符串。|
| HLL_UNION | HLL[^1]类型的列的聚合方式，通过 HyperLogLog 算法聚合。|
| BITMAP_UNION | BIMTAP[^2]类型的列的聚合方式，进行位图的并集聚合。|

[^1]: 在 Apache Doris 中，HLL（HyperLogLog）是一种用于基数估计的数据类型。它可以高效地估计一个集合中不同元素的数量，而无需存储实际的元素值。

[^2]: 在 Apache Doris 中，Bitmap 是一种用于高效压缩和查询位图索引数据的数据类型。它可以有效地表示包含大量重复值的列，并且在聚合、过滤和连接等操作中提供了显著的性能优势。

假设有以下导入数据（原始数据）：

| user_id | date       | city | age  | sex  | last_visit_date     | cost | max_dwell_time | min_dwell_time |
| ------- | ---------- | ---- | ---- | ---- | ------------------- | ---- | -------------- | -------------- |
| 10000   | 2017-10-01 | 北京 | 20   | 0    | 2017-10-01 06:00:00 | 20   | 10             | 10             |
| 10000   | 2017-10-01 | 北京 | 20   | 0    | 2017-10-01 07:00:00 | 15   | 2              | 2              |
| 10001   | 2017-10-01 | 北京 | 30   | 1    | 2017-10-01 17:05:45 | 2    | 22             | 22             |
| 10002   | 2017-10-02 | 上海 | 20   | 1    | 2017-10-02 12:59:12 | 200  | 5              | 5              |
| 10003   | 2017-10-02 | 广州 | 32   | 0    | 2017-10-02 11:20:00 | 30   | 11             | 11             |
| 10004   | 2017-10-01 | 深圳 | 35   | 0    | 2017-10-01 10:00:15 | 100  | 3              | 3              |
| 10004   | 2017-10-03 | 深圳 | 35   | 0    | 2017-10-03 10:20:22 | 11   | 6              | 6              |

那么当这批数据正确导入到 Doris 中后，Doris 中最终存储如下：

| user_id | date       | city | age  | sex  | last_visit_date     | cost | max_dwell_time | min_dwell_time |
| ------- | ---------- | ---- | ---- | ---- | ------------------- | ---- | -------------- | -------------- |
| 10000   | 2017-10-01 | 北京 | 20   | 0    | 2017-10-01 07:00:00 | 35   | 10             | 2              |
| 10001   | 2017-10-01 | 北京 | 30   | 1    | 2017-10-01 17:05:45 | 2    | 22             | 22             |
| 10002   | 2017-10-02 | 上海 | 20   | 1    | 2017-10-02 12:59:12 | 200  | 5              | 5              |
| 10003   | 2017-10-02 | 广州 | 32   | 0    | 2017-10-02 11:20:00 | 30   | 11             | 11             |
| 10004   | 2017-10-01 | 深圳 | 35   | 0    | 2017-10-01 10:00:15 | 100  | 3              | 3              |
| 10004   | 2017-10-03 | 深圳 | 35   | 0    | 2017-10-03 10:20:22 | 11   | 6              | 6              |

### 发生聚合的阶段
#### 导入阶段
原始数据在导入过程中，会根据表结构中的Key进行分组，相同Key的Value会根据表中定义的AggregationType进行聚合

由于Doris采用的是MVCC（Multi-version Cocurrent Control，多版本并发控制）机制进行的并发控制，所以每一次新的导入都是一个新的版本

#### Compaction阶段
在不断导入新数据后，虽然每个批次的数据都在导入阶段完成了聚合，但不同版本之间的数据仍存在相同key但value没有聚合的情况，这时候就需要Compaction对不同版本的数据进行合并，对数据进行二次聚合

#### 查询阶段
由于Compaction是异步的，在用户查询的数据仍存在多个版本时，为保证查询结果一致，会获取所有版本的数据，再做一次聚合，将聚合后的结果展示给用户。

经过聚合，Doris 中最终只会存储聚合后的数据。换句话说，即明细数据会丢失，用户不能够再查询到聚合前的明细数据了。经过聚合，Doris 中最终只会存储聚合后的数据。换句话说，即明细数据会丢失，用户不能够再查询到聚合前的明细数据了。

### 适用场景
AGGREGATE模型可以提前聚合数据, 极大地降低聚合查询时所需扫描的数据量和查询的计算量，非常适合有固定模式的报表类查询场景和多维分析业务。

### 缺点
该模型对 count(*) 查询很不友好。同时因为固定了 Value 列上的聚合方式，在进行其他类型的聚合查询时，需要考虑语意正确性。

假设表结构如下：

| ColumnName | Type     | AggregationType | Comment      |
| ---------- | -------- | --------------- | ------------ |
| user_id    | LARGEINT |                 | 用户id       |
| date       | DATE     |                 | 数据灌入日期 |
| cost       | BIGINT   | SUM             | 用户总消费   |

假设存储引擎中有如下两个已经导入完成的批次的数据：

**batch 1**

| user_id | date       | cost |
| ------- | ---------- | ---- |
| 10001   | 2017-11-20 | 50   |
| 10002   | 2017-11-21 | 39   |

**batch 2**

| user_id | date       | cost |
| ------- | ---------- | ---- |
| 10001   | 2017-11-20 | 1    |
| 10001   | 2017-11-21 | 5    |
| 10003   | 2017-11-22 | 22   |

可以看到，用户 10001 分属在两个导入批次中的数据还没有聚合。但是为了保证用户只能查询到如下最终聚合后的数据, 会在查询引擎中加入了聚合算子，来保证数据对外的一致性：

| user_id | date       | cost |
| ------- | ---------- | ---- |
| 10001   | 2017-11-20 | 51   |
| 10001   | 2017-11-21 | 5    |
| 10002   | 2017-11-21 | 39   |
| 10003   | 2017-11-22 | 22   |

另外，在聚合列（Value）上，执行与聚合类型不一致的聚合类查询时，要注意语意。比如我们在如上示例中执行如下查询：

```
SELECT MIN(cost) FROM table;
```

得到的结果是 5，而不是 1。

同时，这种一致性保证，在某些查询中，会极大的降低查询效率。

我们以最基本的 count(*) 查询为例：

```
SELECT COUNT(*) FROM table;
```

在其他数据库中，这类查询都会很快的返回结果。因为在实现上，我们可以通过如“导入时对行进行计数，保存 count 的统计信息”，或者在查询时“仅扫描某一列数据，获得 count 值”的方式，只需很小的开销，即可获得查询结果。但是在 Doris 的聚合模型中，这种查询的开销**非常大**。

以刚才的数据为例：

**batch 1**

| user_id | date       | cost |
| ------- | ---------- | ---- |
| 10001   | 2017-11-20 | 50   |
| 10002   | 2017-11-21 | 39   |

**batch 2**

| user_id | date       | cost |
| ------- | ---------- | ---- |
| 10001   | 2017-11-20 | 1    |
| 10001   | 2017-11-21 | 5    |
| 10003   | 2017-11-22 | 22   |

因为最终的聚合结果为：

| user_id | date       | cost |
| ------- | ---------- | ---- |
| 10001   | 2017-11-20 | 51   |
| 10001   | 2017-11-21 | 5    |
| 10002   | 2017-11-21 | 39   |
| 10003   | 2017-11-22 | 22   |

所以，`select count(*) from table;` 的正确结果应该为 **4**。但如果我们只扫描 `user_id` 这一列，如果加上查询时聚合，最终得到的结果是 **3**（10001, 10002, 10003）。而如果不加查询时聚合，则得到的结果是 **5**（两批次一共5行数据）。可见这两个结果都是不对的。

为了得到正确的结果，我们必须同时读取 `user_id` 和 `date` 这两列的数据，**再加上查询时聚合**，才能返回 **4** 这个正确的结果。也就是说，在 count(\*) 查询中，Doris 必须扫描所有的 AGGREGATE KEY 列（这里就是 `user_id` 和 `date`），并且聚合后，才能得到语意正确的结果。当聚合列非常多时，count(*) 查询需要扫描大量的数据。

因此，当业务上有频繁的 count(*) 查询时，我们建议用户通过增加一个**值恒为 1 的，聚合类型为 SUM 的列来模拟 count(\*)**。如刚才的例子中的表结构，我们修改如下：

| ColumnName | Type   | AggregateType | Comment       |
| ---------- | ------ | ------------- | ------------- |
| user_id    | BIGINT |               | 用户id        |
| date       | DATE   |               | 数据灌入日期  |
| cost       | BIGINT | SUM           | 用户总消费    |
| count      | BIGINT | SUM           | 用于计算count |

增加一个 count 列，并且导入数据中，该列值**恒为 1**。则 `select count(*) from table;` 的结果等价于 `select sum(count) from table;`。而后者的查询效率将远高于前者。不过这种方式也有使用限制，就是用户需要自行保证，不会重复导入 AGGREGATE KEY 列都相同的行。否则，`select sum(count) from table;` 只能表述原始导入的行数，而不是 `select count(*) from table;` 的语义。

另一种方式，就是 **将如上的 `count` 列的聚合类型改为 REPLACE，且依然值恒为 1**。那么 `select sum(count) from table;` 和 `select count(*) from table;` 的结果将是一致的。并且这种方式，没有导入重复行的限制。

## UNIQUE模型

UNIQUE KEY 相同时，新记录覆盖旧记录。在1.2版本之前，UNIQUE KEY 实现上和 AGGREGATE KEY 的 REPLACE 聚合方法一样，二者本质上相同，自1.2版本UNIQUE KEY引入了merge on write实现，该实现有更好的聚合查询性能。适用于有更新需求的分析业务。

```sql
CREATE TABLE sales_order
(
    orderid     BIGINT,
    status      TINYINT,
    username    VARCHAR(32),
    amount      BIGINT DEFAULT '0'
)
UNIQUE KEY(orderid)
DISTRIBUTED BY HASH(orderid) BUCKETS 10;
```

## DUPLICATE模型

只指定排序列，相同的行不会合并。适用于数据无需提前聚合的分析业务。等价于有序表

```sql
CREATE TABLE session_data
(
    visitorid   SMALLINT,
    sessionid   BIGINT,
    visittime   DATETIME,
    city        CHAR(20),
    province    CHAR(20),
    ip          varchar(32),
    brower      CHAR(20),
    url         VARCHAR(1024)
)
DUPLICATE KEY(visitorid, sessionid)
DISTRIBUTED BY HASH(sessionid, visitorid) BUCKETS 10;
```
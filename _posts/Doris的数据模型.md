---
title: Doris的数据模型
date: 2023-08-07 17:59:02
tags:
    - Doris
    - Aggregate模型
    - Unique模型
    - Duplicate模型
categories:
    - Doris
description:
    Doris的数据模型
---


# Doris数据模型

Doris 数据模型上目前分为三类:

- AGGREGATE（聚合模型）
- UNIQUE（唯一主键模型）
- DUPLICATE（明细模型）

{% note info %}
**说明**

1. 在 Aggregate、Unique 和 Duplicate 三种数据模型中。底层的数据存储，是按照各自建表语句中，AGGREGATE KEY、UNIQUE KEY 和 DUPLICATE KEY 中指定的列（**不支持任意列，必须为前n列**）进行排序存储的
2. 三种模型都涉及前缀索引，即在排序的基础上，实现的一种根据给定前缀列，快速查询数据的索引方式，属于Doris内建的智能索引之一。
3. 在查询过滤时使用AGGREGATE KEY、UNIQUE KEY 和 DUPLICATE KEY 中的指定列时，可以提高查询效率。
4. 数据模型在建表时就已经确定，且无法修改
{% endnote %}

**适用场景**：

- AGGREGATE 模型适合有固定模式的报表类查询场景和多维分析业务
- UNIQUE 模型适用于有主键唯一性约束需求的某些多维分析业务
- DUPLICATE 模型适用于既没有主键，也没有聚合需求的场景

## AGGREGATE模型

### 数据聚合

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

### 时序图

1. insert与compact阶段
以某一批次加载中`insert`阶段与`compaction`阶段的聚合操作,以聚合方法为`SUM`为例,时序图如下：
![](/images/Doris的数据模型/insert_and_compaction_agg.png)

2. 查询阶段
![](/images/Doris的数据模型/select_agg.png)

聚合方法在工厂类`AggregateFunctionSimpleFactory`中注册，使用时通过`AggregateFunctionSimpleFactory`获取对应聚合方法类的指针`AggregateFunctionPtr`执行聚合操作

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

``` sql
SELECT MIN(cost) FROM table;
```

得到的结果是 5，而不是 1。

同时，这种一致性保证，在某些查询中，会极大的降低查询效率。

我们以最基本的 count(*) 查询为例：

``` sql
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

在1.2版本之前，该模型本质上是聚合模型的一个特例，也是一种简化的表结构表示方式。实现上和 AGGREGATE 模型 的 REPLACE 聚合方法一样，二者本质上相同，由于实现方式是读时合并（merge on read)，因此在一些聚合查询上性能不佳，自1.2版本 UNIQUE 模型引入新的实现方式，写时合并（merge on write），通过在写入时做一些额外的工作，实现了最优的查询性能，该实现有更好的聚合查询性能。默认情况下写时合并是关闭的。

### 读时合并（与聚合模型相同的实现方式）

| ColumnName    | Type         | IsKey | Comment      |
| ------------- | ------------ | ----- | ------------ |
| user_id       | BIGINT       | Yes   | 用户id       |
| username      | VARCHAR(50)  | Yes   | 用户昵称     |
| city          | VARCHAR(20)  | No    | 用户所在城市 |
| age           | SMALLINT     | No    | 用户年龄     |
| sex           | TINYINT      | No    | 用户性别     |
| phone         | LARGEINT     | No    | 用户电话     |
| address       | VARCHAR(500) | No    | 用户住址     |
| register_time | DATETIME     | No    | 用户注册时间 |

这是一个典型的用户基础信息表。这类数据没有聚合需求，只需保证主键唯一性。（这里的主键为 user_id + username）。那么我们的建表语句如下：

```sql
CREATE TABLE IF NOT EXISTS example_db.example_tbl
(
    `user_id` LARGEINT NOT NULL COMMENT "用户id",
    `username` VARCHAR(50) NOT NULL COMMENT "用户昵称",
    `city` VARCHAR(20) COMMENT "用户所在城市",
    `age` SMALLINT COMMENT "用户年龄",
    `sex` TINYINT COMMENT "用户性别",
    `phone` LARGEINT COMMENT "用户电话",
    `address` VARCHAR(500) COMMENT "用户地址",
    `register_time` DATETIME COMMENT "用户注册时间"
)
UNIQUE KEY(`user_id`, `username`)
DISTRIBUTED BY HASH(`user_id`) BUCKETS 1
PROPERTIES (
"replication_allocation" = "tag.location.default: 1"
);
```

而这个表结构，完全同等于以下使用聚合模型描述的表结构：

| ColumnName    | Type         | AggregationType | Comment      |
| ------------- | ------------ | --------------- | ------------ |
| user_id       | BIGINT       |                 | 用户id       |
| username      | VARCHAR(50)  |                 | 用户昵称     |
| city          | VARCHAR(20)  | REPLACE         | 用户所在城市 |
| age           | SMALLINT     | REPLACE         | 用户年龄     |
| sex           | TINYINT      | REPLACE         | 用户性别     |
| phone         | LARGEINT     | REPLACE         | 用户电话     |
| address       | VARCHAR(500) | REPLACE         | 用户住址     |
| register_time | DATETIME     | REPLACE         | 用户注册时间 |

及建表语句：

```sql
CREATE TABLE IF NOT EXISTS example_db.example_tbl
(
    `user_id` LARGEINT NOT NULL COMMENT "用户id",
    `username` VARCHAR(50) NOT NULL COMMENT "用户昵称",
    `city` VARCHAR(20) REPLACE COMMENT "用户所在城市",
    `age` SMALLINT REPLACE COMMENT "用户年龄",
    `sex` TINYINT REPLACE COMMENT "用户性别",
    `phone` LARGEINT REPLACE COMMENT "用户电话",
    `address` VARCHAR(500) REPLACE COMMENT "用户地址",
    `register_time` DATETIME REPLACE COMMENT "用户注册时间"
)
AGGREGATE KEY(`user_id`, `username`)
DISTRIBUTED BY HASH(`user_id`) BUCKETS 1
PROPERTIES (
"replication_allocation" = "tag.location.default: 1"
);
```

### 写时合并

Unqiue 模型的写时合并实现，与聚合模型是完全不同的两种模型了，查询性能更接近于 Duplicate 模型，在有主键约束需求的场景上相比聚合模型有较大的查询性能优势，尤其是在聚合查询以及需要用索引过滤大量数据的查询中。

写时合并默认关闭，用户可以通过添加下面的property来开启

``` sql
"enable_unique_key_merge_on_write" = "true"
```

仍然以上面的表为例，建表语句为

```sql
CREATE TABLE IF NOT EXISTS example_db.example_tbl
(
    `user_id` LARGEINT NOT NULL COMMENT "用户id",
    `username` VARCHAR(50) NOT NULL COMMENT "用户昵称",
    `city` VARCHAR(20) COMMENT "用户所在城市",
    `age` SMALLINT COMMENT "用户年龄",
    `sex` TINYINT COMMENT "用户性别",
    `phone` LARGEINT COMMENT "用户电话",
    `address` VARCHAR(500) COMMENT "用户地址",
    `register_time` DATETIME COMMENT "用户注册时间"
)
UNIQUE KEY(`user_id`, `username`)
DISTRIBUTED BY HASH(`user_id`) BUCKETS 1
PROPERTIES (
"replication_allocation" = "tag.location.default: 1",
"enable_unique_key_merge_on_write" = "true"
);
```

使用这种建表语句建出来的表结构，与聚合模型就完全不同了：

| ColumnName    | Type         | AggregationType | Comment      |
| ------------- | ------------ | --------------- | ------------ |
| user_id       | BIGINT       |                 | 用户id       |
| username      | VARCHAR(50)  |                 | 用户昵称     |
| city          | VARCHAR(20)  | NONE            | 用户所在城市 |
| age           | SMALLINT     | NONE            | 用户年龄     |
| sex           | TINYINT      | NONE            | 用户性别     |
| phone         | LARGEINT     | NONE            | 用户电话     |
| address       | VARCHAR(500) | NONE            | 用户住址     |
| register_time | DATETIME     | NONE            | 用户注册时间 |

在开启了写时合并选项的Unique表上，数据在导入阶段就会去将被覆盖和被更新的数据进行标记删除，同时将新的数据写入新的文件。在查询的时候，所有被标记删除的数据都会在文件级别被过滤掉，读取出来的数据就都是最新的数据，消除掉了读时合并中的数据聚合过程，并且能够在很多情况下支持多种谓词的下推。因此在许多场景都能带来比较大的性能提升，尤其是在有聚合查询的情况下。

{% note warning %}
1. 新的`Merge-on-write`实现默认关闭，且只能在建表时通过指定`property`的方式打开。
2. 旧的`Merge-on-read`的实现无法无缝升级到新版本的实现（数据组织方式完全不同），如果需要改为使用写时合并的实现版本，需要手动执行`insert into unique-mow-table select * from source table`.
3. 在Unique模型上独有的`delete sign`和`sequence col`，在写时合并的新版实现中仍可以正常使用，用法没有变化。
{% endnote %}

### Unique模型的写时合并实现

Unique模型的写时合并实现没有聚合模型的局限性，还是以刚才的数据为例，写时合并为每次导入的rowset增加了对应的delete bitmap，来标记哪些数据被覆盖。第一批数据导入后状态如下

**batch 1**

| user_id | date       | cost | delete bit |
| ------- | ---------- | ---- | ---------- |
| 10001   | 2017-11-20 | 50   | false      |
| 10002   | 2017-11-21 | 39   | false      |

当第二批数据导入完成后，第一批数据中重复的行就会被标记为已删除，此时两批数据状态如下

**batch 1**

| user_id | date       | cost | delete bit |
| ------- | ---------- | ---- | ---------- |
| 10001   | 2017-11-20 | 50   | **true**   |
| 10002   | 2017-11-21 | 39   | false      |

**batch 2**

| user_id | date       | cost | delete bit |
| ------- | ---------- | ---- | ---------- |
| 10001   | 2017-11-20 | 1    | false      |
| 10001   | 2017-11-21 | 5    | false      |
| 10003   | 2017-11-22 | 22   | false      |

在查询时，所有在delete bitmap中被标记删除的数据都不会读出来，因此也无需进行做任何数据聚合，上述数据中有效的行数为4行，查询出的结果也应该是4行，也就可以采取开销最小的方式来获取结果，即前面提到的“仅扫描某一列数据，获得 count 值”的方式。

据官方文档介绍，在测试环境中，count(*) 查询在 Unique 模型的写时合并实现上的性能，相比聚合模型有10倍以上的提升。

### 写时合并时序图

![](/images/Doris的数据模型/merge_on_write_unique.png)

### 缺点

1. 无法利用 ROLLUP 等预聚合带来的查询优势。对于聚合查询有较高性能需求的用户，推荐使用自1.2版本加入的写时合并实现。
2. Unique 模型仅支持整行更新，如果用户既需要唯一主键约束，又需要更新部分列（例如将多张源表导入到一张 doris 表的情形），则可以考虑使用 Aggregate 模型，同时将非主键列的聚合类型设置为 REPLACE_IF_NOT_NULL。

## DUPLICATE模型

Duplicate 数据模型用于满足在某些多维分析场景下，数据既没有主键，也没有聚合需求的场景。

这种数据模型区别于 Aggregate 和 Unique 模型。数据完全按照导入文件中的数据进行存储，不会有任何聚合。即使两行数据完全相同，也都会保留。 而在建表语句中指定的 DUPLICATE KEY，只是用来指明底层数据按照那些列进行排序。

| ColumnName | Type          | SortKey | Comment      |
| ---------- | ------------- | ------- | ------------ |
| timestamp  | DATETIME      | Yes     | 日志时间     |
| type       | INT           | Yes     | 日志类型     |
| error_code | INT           | Yes     | 错误码       |
| error_msg  | VARCHAR(1024) | No      | 错误详细信息 |
| op_id      | BIGINT        | No      | 负责人id     |
| op_time    | DATETIME      | No      | 处理时间     |

建表语句如下：

```sql
CREATE TABLE IF NOT EXISTS example_db.example_tbl
(
    `timestamp` DATETIME NOT NULL COMMENT "日志时间",
    `type` INT NOT NULL COMMENT "日志类型",
    `error_code` INT COMMENT "错误码",
    `error_msg` VARCHAR(1024) COMMENT "错误详细信息",
    `op_id` BIGINT COMMENT "负责人id",
    `op_time` DATETIME COMMENT "处理时间"
)
DUPLICATE KEY(`timestamp`, `type`, `error_code`)
DISTRIBUTED BY HASH(`type`) BUCKETS 1
PROPERTIES (
"replication_allocation" = "tag.location.default: 1"
);
```

这种数据模型区别于 Aggregate 和 Unique 模型。数据完全按照导入文件中的数据进行存储，不会有任何聚合。即使两行数据完全相同，也都会保留。 而在建表语句中指定的 DUPLICATE KEY，只是用来指明底层数据按照那些列进行排序。

### 时序图

与[Aggregate模型一样，仅没有聚合操作](#时序图)

### 适用场景

适用于既没有聚合需求，又没有主键唯一性约束的原始数据的存储

### 缺点

无法利用预聚合的特性

## 参考资料

[Doris 2.0.0 版源码](https://github.com/apache/doris/tree/branch-2.0)
[Doris官方文档-数据表设计>数据模型](https://doris.apache.org/zh-CN/docs/dev/data-table/data-model)
[Doris官方文档-数据表设计>索引>索引概述](https://doris.apache.org/zh-CN/docs/dev/data-table/index/index-overview)
[Doris官方文档-数据表设计>最佳实践](https://doris.apache.org/zh-CN/docs/dev/data-table/best-practice)
<br>[悄悄学习Doris，偷偷惊艳所有人 | Apache Doris四万字小总结](https://zhuanlan.zhihu.com/p/426919326)
[Doris数据模型----三种数据模型讲解的非常到位](https://www.modb.pro/db/583790)
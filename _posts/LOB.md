---
title: CirroData LOB 数据类型
date: 2022-07-05 14:28:32
tags:
    - LOB
    - CLOB
    - BLOB
categories:
    - CirroData
description:
    - CirroData LOB类型
---

### LOB类型

| 类型 | 存储对象 |
| :---: | :---: |
| BLOB | 存储二进制数据 |
| CLOB | 存储字符数据，使用UTF-8编码 |

### LOB存储方式

| 数据长度 | 存储类型 | 存放位置 |
| :---: | :---: | :---: |
| <= 4KB | LOB_INLINE | 以dp文件存储 |
| > 4KB | LOB_LOCATOR | hdfs指定位置 |

{% note info %}
#### 说明
存储类型为LOB_LOCATOR时,不代表dp为空,dp文件存放的lob索引文件名偏移量等信息;
先读取dp中lob索引文件的信息,根据信息再从索引文件中获取lob数据文件的文件名偏移量等信息,最后根据索引信息获取lob具体数据
{% endnote %}

LOB_LOCATOR存储位置

1. 正常情况:

```
/xcloud_name/cluster_name.data/db_name/schema_name/table_id/session_id/LOB/lob_file_name
```

2. LLVM计算:

```
/xcloud_name/cluster_name.data/SYS.TEMP/db_name/schema_name/session_id/LOB/lob_file_name
```

{% note warning %}
#### 注意

Writer会根据数据长度设置Lob存储类型
读取lob数据时，需要根据存储类型区分读取方式，LOB_INLINE直接从lob中读取，LOB_LOCATOR使用Reader读取
{% endnote %}

``` c++
static const int32_t LOB_INLINE_SIZE = 4 * 1024;
```

### LOB文件命名

#### 普通文件

- 索引文件

``` bash
lob.[trans_id].[unique_id].[hostname]_[pid].index
```

- 数据文件

``` bash
lob.[trans_id].[unique_id].[hostname]_[pid]
```

#### llvm计算文件

- 索引文件

``` bash
lob.llvm.[unique_id].[hostname]_[pid].index
```

- 数据文件

``` bash
lob.llvm.[unique_id].[hostname]_[pid]
```

{% note info %}
#### 说明

索引文件和数据文件成对出现，索引文件的文件名仅比数据文件的文件名多`.index`后缀
{% endnote %}

### 相关配置参数

{% tabs lob, 1 %}
<!-- tab 3.0 -->
| 参数名 | 说明 | 参数类型 | 默认值 | 参数值范围 |
| --- | --- | --- | --- | --- |
| compaction_lob_file_valid_threshold | 每个lob数据文件中允许无效的lob个数占总lob个数的比例小于该比例. | double | 0.5 | (0, 1] |
| compaction_lob_tiny_file_num_threshold | compaction时,LOB微小文件必须进行compaction的数据阈值.微小文件的数量超过该值时,也必须进行compaction. | int32 | 50 | [1, 100] |
| compaction_lob_tiny_file_size_threshold | lob compaction的时候,LOB文件大小小于该临界值的文件认为是小文件. | int64 | 1073741824 | [128MB, 4GB] |
| lob_index_cache_num | LOB Writer中的索引Cache的数量.用于写入LOB数据. | int32 | 1024 | [128, 4096] |
| lob_insert_cache_size | 内部表加载时,用于拷贝LOB数据的缓存大小. | int32 | 1048576 | [1MB, 2GB) |
| max_lob_size | LOB类型支持最大数据长度. | int64 | 4294967296 | [16MB, 8GB] |
| lob_compression_type | LOB数据文件中的压缩类型.uncompressed: 表示不压缩;lz4: 表示lz4. | string | uncompressed | uncompresse,lz4 |
<!-- endtab -->

<!-- tab 3.0之前的版本 -->
| 参数名 | 说明 | 参数类型 | 默认值 | 参数值范围 |
| --- | --- | --- | --- | --- |
| lob_delete_factor | 每个lob数据文件中允许无效的lob个数占总lob个数的比例小于该比例. | double | 0.5 | (0, 1] |
| lob_compaction_small_files_cnt | LOB小文件的数量达到该临界值的时候，也需要进行compaction. | int32 | 50 | [1, 100] |
| lob_compaction_small_file_size | lob compaction的时候,LOB文件大小小于该临界值的文件认为是小文件. | int64 | 1073741824 | <div style="white-space: nowrap">[128MB, 4GB]</div> |
| lob_writer_cache_index_cnt | 每一个lob Writer缓存的lob索引的数量. | int32 | 1024 | [128, 4096] |
| lob_copy_data_length | local insert时候，拷贝数据需要的缓存长度. | int32 | 1048576 | [1MB, 2GB) |
| lob_max_data_size | lob类型支持最大数据长度为4G. | int64 | 4294967296 | [16MB, 8GB] |
| lob_compressionType | lob数据压缩方式，默认0：表示不压缩，1：表示lz4. | int32 | 0 | {0, 1} |
<!-- endtab -->
{% endtabs %}

### LOB文件大小

单个lob文件最大1TB

### lob触发compaction的两种机制

1. update操作，lob文件中无效lob比例 >= `lob_delete_factor`
2. lob小文件数量 >= `lob_compaction_small_files_cnt`

{% note info %}
#### 说明

1. update操作才会产生无效数据，delete不会
2. LOCATOR存储的lob,若update后的数据长度小于4KB,是不会进行compaction的，此时lob属于INLINE存储，原lob仅增加delete标记
{% endnote %}


{% note danger %}
#### 使用为NULL的LOB

lob为null，其成员函数几乎都不可使用，强制使用会访问空指针（`m_lobInfo = null`），导致崩溃，可使用`XCLob::IsNull()`方法判断lob是否为null
{% endnote %}

### export clob

支持导出真实数据，如果数据太长，依然用`<CLOB>`替代真实数据,长度限制查看配置,导出和导入用的同一套配置参数`csv_file_with_clob_max_buffer_size`和`csv_file_max_buffer_size`

### blob加载多媒体文件

通过csv文件进行加载，csv文件中写入多媒体文件的路径

示例：
存在`/home/gaoyuanfeng/3.0/blob_insert.csv`该路径的csv文件，文件内容如下

``` csv
"/home/gaoyuanfeng/3.0/picture2.png"
"/home/gaoyuanfeng/3.0/picture2.png"
```

inset使用`/*+LOB_FROM_EXTFILE*/`hit进行加载

``` sql
CREATE TABLE BLOB_TEST(picture BLOB);
INSERT INTO /*+LOB_FROM_EXTFILE*/ BLOB_TEST '/home/gaoyuanfeng/3.0/blob_insert.csv' SEPARATOR ';' DELIMITER '"';
```

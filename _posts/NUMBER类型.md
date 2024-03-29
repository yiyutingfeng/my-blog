---
title: CirroData NUMBER 数据类型
date: 2022-07-11 11:24:55
tags:
categories:
description:
   - CirroData NUMBER 数据类型介绍
---

## number可表示范围
   (-1E252, -1E-260], 0, [1E-260, 1E252)

## number精度与刻度

### 精度

**说明**：精度（precision）是NUMBER表示的数字中，精确的有效数字位数（NUMBER中记录的数字有可能超过精度，但是不保证精度范围之外的数字精确）。
**取值范围**：[1, 38]。

### 刻度

**说明**：刻度（scale）是精确到小数点后的位数。scale > 0时，表示该类型精确到小数点后scale位；scale = 0时，表示该类型为整数；scale < 0时，表示该类型精确到小数点前-scale位。
**取值范围**：[-84, 127]。


## number存储规则

number类型占24个字节，每2个字节作为一个单元，共12个单元，每个单位最大可存储4位数字。
第一个单元是索引部分，既用于表示数值正负，也用于记录数值整数部分占用多少个单元，剩余11个单元用于存储具体数值，称为数值部分。

### 索引部分存储规则

``` c++
const IndexType XCNumber::S_POSITIVE_INDEX_BASE = 192;
const IndexType XCNumber::S_NEGATIVE_INDEX_BASE = 63;
const IndexType XCNumber::S_ZERO_INDEX_BASE = 128;
```

#### 正数

   索引值 = `S_POSITIVE_INDEX_BASE` + 整数部分单元格的个数
   例如: 数值1234567.1234567存储位number类型，索引值 = 192 + 2 = 194

   若索引值n小于`S_POSITIVE_INDEX_BASE`，则表示有效数字前有`192-n`个单元格是0
   例如0.000000123   索引值为191

   索引值取值范围[128, 255]

#### 负数

   索引值 = `S_NEGATIVE_INDEX_BASE` - 整数部分单元格的个数
   例如: 数值-1234567.1234567存储为number类型，索引值 = 63 - 2 = 61

   若索引值n大于`S_NEGATIVE_INDEX_BASE`，则表示有效数字前有`n-63`个单元格是0
   例如: -0.000000000123   索引值是65

   索引值取值范围[0, 127]

#### 0

   索引值 = `S_ZERO_INDEX_BASE` = 128

   > 注意: 0的索引值是128，但索引值为128的数不一定是0，例如1E-260的索引值也是128

### 数值部分存储规则

``` c++
const TailType XCNumber::S_POSITIVE_TAIL = 0;
const TailType XCNumber::S_NEGATIVE_TAIL = 10002;
const TailType XCNumbeer::S_POSITIVE_BASE = 1;
const TailType XCNumber::S_NEGATIVE_BASE = 10001;
```

以1234567.1234567举例

#### 数值划分

1. 整数部分: 每4位占一个单元，从低位开始划分，从高位开始存储
   例如: 1234567  共7位，占2个单元，123 占数值部分第1个单元，4567占第2个单元
2. 小数部分: 每4位占一个单元，从高位开始划分，从高位开始存储，低位不满4字节末尾填充0补齐
   例如: .1234567 共7位，占2个单元，1234占数值部分第3个单元，5670占第4个单元

1234567.1234567的按单元个划分如下
| 123 | 4567 | 1234 | 5670 |
| --- | --- | --- | --- |

#### 数值存储

1. **正数**: 默认11个单元初始化为`S_POSITIVE_TAIL`,存储内容为原值单元划分后的值加上`S_POSITIVE_BASE`，即每个单元初始化为0，每个单元的值为：原值 + 1

   例如: 1234567.1234567
   初始单元格:
   | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
   | --- | --- | --- | --- | --- | --- |--- | --- | --- | --- | --- |

   原值单元格划分为:
   | 123 | 4567 | 1234 | 5670 |
   | --- | --- | --- | --- |

   实际存储为:
   | 124 | 4568 | 1235 | 5671 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
   | --- | --- | --- | --- | --- | --- |--- | --- | --- | --- | --- |

2. **负数**: 默认11个单元初始化为`S_NEGATIVE_TAIL`,存储内容为`S_NEGATIVE_BASE`减去原值单元划分后的值，即每个单元初始化为10002，每个单元的值为：10001 - 原值

   例如: -1234567.1234567
   初始单元格:
   | 10002 | 10002 | 10002 | 10002 | 10002 | 10002 | 10002 | 10002 | 10002 | 10002 | 10002 |
   | --- | --- | --- | --- | --- | --- |--- | --- | --- | --- | --- |

   原值单元格划分为:
   | 123 | 4567 | 1234 | 5670 |
   | --- | --- | --- | --- |

   实际存储为:
   | 9878 | 5434 | 8767 | 4331 | 10002 | 10002 | 10002 | 10002 | 10002 | 10002 | 10002 |
   | --- | --- | --- | --- | --- | --- |--- | --- | --- | --- | --- |

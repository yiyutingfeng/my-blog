########################################################################
#                 北京东方国信科技股份有限公司 版权所有                #
########################################################################
#   @@BEGAIN_INTERNAL_LEGAL@@                                          #
#                                                                      #
#                   Copyright(C) Description                           #
# Beijing Orient National Communication Science & Technology Co.,Ltd.  #
# Unpublished work-rights reserVed under the China Copyright Act.      #
# Use,duplication, or disclosure by the government is subject to       #
# restrictions set forth in the BONC commercial license agreement.     #
#                                                                      #
#   @@END_INTERNAL_LEGAL@@                                             #
#                                                                      #
########################################################################
# File Name: oltp_test_script.sh
# File Version: 1.0
# Description:
########################################################################
# Modify History:
#   1. Modify Time: Oct 16, 2023 05:08:51 PM
#   Author: gaoyuanfeng
#   Description: Creation
########################################################################

#!/bin/bash

# 函数：显示脚本使用方法
function show_usage {
    echo "使用方法: $0 [-f SQL_FILE] [-d DB_NAME] [-h]"
    echo "  -f SQL_FILE  指定包含SQL查询的文件(可选), 每批次SQL应包含在一对双引号中"
    echo "  -d DB_NAME   指定要使用的数据库名称(可选), 若不存在会自动创建"
    echo "  -h           显示脚本使用方法"
    exit 1
}

set -e

# 设置默认的数据库名称
DEFAULT_DB_NAME="oltp_test_db"

# 解析命令行参数
while getopts "f:d:h" opt; do
    case $opt in
        f) SQL_FILE="$OPTARG";;
        d) DB_NAME="$OPTARG";;
        h) show_usage;;
    esac
done

# 使用默认值如果参数未提供
DB_NAME=${DB_NAME:-$DEFAULT_DB_NAME}

# 检查 SQL 文件是否存在
if [ -n "$SQL_FILE" ] && [ ! -f "$SQL_FILE" ]; then
    echo "指定的 SQL 文件不存在: $SQL_FILE"
    exit 1
fi

# 用于存储 SQL 查询的数组
SQL_QUERIES=()

# 初始化结果变量
SUCCESS_QUERIES=0
FAILED_QUERIES=0

# 函数，解析 SQL 查询
parse_sql() {
    local in_sql=false
    local current_query=""
    while IFS= read -r line; do
        # 去掉行前后的空白字符
        line=$(echo "$line" | awk '{$1=$1};1')
        if [ "$in_sql" = true ]; then
            if [ -n "$current_query" ]; then
                current_query="$current_query"$'\n'"$line"
            else
                current_query="$line"
            fi
            if [[ "$line" == *\" ]]; then
                current_query="${current_query:0:-1}"
                SQL_QUERIES+=("$current_query")
                in_sql=false
            fi
        elif [[ "$line" == \"* ]]; then
            current_query="${line:1}"
            in_sql=true
        fi
    done < "$1"
}

# 函数：获取 MySQL 配置信息
function get_mysql_config {
    local param="$1"
    local value=$(grep -E "^$param\s*=" "$MY_CNF" | awk -F '=' '{print $2}' | tr -d '[:space:]')
    echo "$value"
}

# 函数：执行 SQL 查询
function execute_sql_query {
    local SQL_QUERY="$1"
    local DB_NAME="$2"
    local QUERY_RESULT

    QUERY_RESULT="$($MYSQL_BIN -h "$DB_HOST" -u "$DB_USER" -P "$MYSQL_PORT" -D "$DB_NAME" --table -e "$SQL_QUERY" 2>&1)"

    if [ $? -eq 0 ]; then
        SUCCESS_QUERIES=$((SUCCESS_QUERIES + 1))
        echo "---------------- 分割线 ----------------"
        echo "成功: SQL查询 #$SUCCESS_QUERIES"
        echo "查询内容:"
        echo "$SQL_QUERY"
        echo "查询结果:"
        echo "$QUERY_RESULT"
    else
        FAILED_QUERIES=$((FAILED_QUERIES + 1))
        echo "---------------- 分割线 ----------------"
        echo -e "\e[31m失败\e[0m: SQL查询 #$FAILED_QUERIES"
        echo "查询内容:"
        echo "$SQL_QUERY"
        echo "错误信息:"
        echo "$QUERY_RESULT"
    fi
}

# 函数：检查数据库是否存在，如果不存在则创建
function create_database_if_not_exists {
    local DB_NAME="$1"

    local QUERY_RESULT="$($MYSQL_BIN -h "$DB_HOST" -u "$DB_USER" -P "$MYSQL_PORT" -sN -B -e "SHOW DATABASES LIKE '$DB_NAME'")"

    if [[ "$QUERY_RESULT" == *"ERROR"* ]]; then
        echo "查询数据库出现错误: $QUERY_RESULT"
    else
        if [ -z "$QUERY_RESULT" ]; then
            local CREATE_RESULT="$($MYSQL_BIN -h "$DB_HOST" -u "$DB_USER" -P "$MYSQL_PORT" --table -e "CREATE DATABASE $DB_NAME; SHOW DATABASES;")"

            if [ $? -eq 0 ]; then
                echo "$DB_NAME 数据库创建成功: CREATE DATABASE $DB_NAME; SHOW DATABASES;"
                echo "$CREATE_RESULT"
            else
                echo "$DB_NAME 数据库创建失败"
                echo "错误信息: $CREATE_RESULT"
                exit 1
            fi
        else
            echo -e "\e[31m先检查使用的SQL中是否包含删库操作(默认SQL包含!!!)\e[0m"
            read -p "数据库 $DB_NAME 已存在. 是否继续使用该数据库? (y/n): " -r
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo "请指定数据库名称。"
                show_usage
            fi
        fi
    fi
}

# 设置变量
readonly INSTALL_DIR=$(pwd)
readonly MY_CNF="$INSTALL_DIR/my.cnf"
readonly MYSQL_BIN="$INSTALL_DIR/bin/mysql"

# MySQL连接信息
readonly DB_HOST="127.0.0.1"
readonly DB_USER="root"
readonly DB_DATABASE="$DB_NAME"  # 使用命令行参数提供的数据库名称
readonly MYSQL_PORT=$(get_mysql_config 'port')

# 设置环境变量
export LD_LIBRARY_PATH="$INSTALL_DIR/lib:$LD_LIBRARY_PATH"

# 检查数据库是否存在，如果不存在则创建
create_database_if_not_exists "$DB_DATABASE"

# 定义默认 SQL 查询语句
DEFAULT_SQL_QUERIES=(
    # 建表
    "CREATE TABLE IF NOT EXISTS oltp_test_table (
        user_id INT AUTO_INCREMENT PRIMARY KEY,
        data_insert_date_time DATETIME NOT NULL,
        user_city VARCHAR(255) NOT NULL,
        user_age INT,
        user_gender ENUM('Male', 'Female', 'Other') NOT NULL,
        last_visit_time DATETIME NOT NULL,
        total_spending DECIMAL(10, 2) NOT NULL,
        max_stay_duration INT NOT NULL COMMENT 'In seconds',
        min_stay_duration INT NOT NULL COMMENT 'In seconds'
    );
    SHOW TABLES;"

    # 插入数据
    "INSERT INTO oltp_test_table (data_insert_date_time, user_city, user_age, user_gender, last_visit_time, total_spending, max_stay_duration, min_stay_duration)
     VALUES ('2023-01-10 20:37:00', 'Beijing', 35, 'Male', '2023-01-15 13:16:00', 463.00, 5900, 76),
            ('2023-01-11 21:45:00', 'Tianjin', 25, 'Female', '2023-01-16 14:20:00', 520.50, 4000, 60),
            ('2023-01-12 22:52:00', 'Shandong', 30, 'Male', '2023-01-17 16:40:00', 375.75, 3500, 45),
            ('2023-01-13 23:59:00', 'Anhui', 28, 'Male', '2023-01-18 19:30:00', 320.25, 4200, 55),
            ('2023-01-14 10:15:00', 'Shenzhen', 33, 'Female', '2023-01-19 08:45:00', 400.50, 4800, 70),
            ('2023-01-15 16:45:00', 'Chongqing', 29, 'Male', '2023-01-20 14:10:00', 275.75, 3600, 40),
            ('2023-01-16 08:00:00', 'Shandong', 35, 'Female', '2023-01-21 12:00:00', 600.00, 3000, 50),
            ('2023-01-17 14:30:00', 'Shenzhen', 28, 'Male', '2023-01-22 16:20:00', 450.75, 3500, 45);
     SELECT * FROM oltp_test_table;"

    # 更新数据
    "UPDATE oltp_test_table SET user_city = 'Chongqing' WHERE user_id = 3;
     SELECT user_city FROM oltp_test_table WHERE user_id = 3;"

    # 聚合 (sum 和 count)
    "SELECT COUNT(user_id), SUM(total_spending) FROM oltp_test_table;"

    # 条件查询
    "SELECT user_id, user_city, user_age, total_spending
     FROM oltp_test_table
     WHERE user_id > 1 AND user_city = 'Chongqing' AND user_age < 30 AND max_stay_duration BETWEEN 2000 AND 5000;"

    "SELECT user_id, total_spending
     FROM oltp_test_table t1
     WHERE max_stay_duration IN (3000, 3500, 5000) AND user_age IN (30, 35) AND user_city IN ('Chongqing', 'Shenzhen');"

    # 排序
    "SELECT * FROM oltp_test_table
     WHERE user_id > 4 AND user_age BETWEEN 20 AND 35
     ORDER BY total_spending;"

    # 正则表达式
    "SELECT user_id, user_age, max_stay_duration
     FROM oltp_test_table
     WHERE user_city REGEXP 'Beijing|Shandong';"

    # 表联结
    "SELECT t1.user_id, t1.user_city, t1.user_age
     FROM oltp_test_table AS t1, oltp_test_table AS t2
     WHERE t1.user_id = t2.user_id AND t2.user_age > 20;"

    # 子查询
    "SELECT user_id, user_city, user_age, max_stay_duration, total_spending, min_stay_duration
     FROM (SELECT * FROM oltp_test_table WHERE min_stay_duration BETWEEN 0 AND 90) AS A
     WHERE A.max_stay_duration > 4000;"

    # LIMIT
    "SELECT * FROM oltp_test_table LIMIT 3;"

    # 视图
    "CREATE VIEW v_product AS SELECT user_id, user_age, total_spending FROM oltp_test_table;
     SELECT * FROM v_product;"

    # 存储过程
    "DELIMITER //
     CREATE PROCEDURE productpricing()
     BEGIN
         SELECT user_id, total_spending, max_stay_duration, min_stay_duration
         FROM oltp_test_table
         WHERE user_id > 4 AND user_age BETWEEN 20 AND 35
         ORDER BY total_spending;
     END //
     DELIMITER ;
     CALL productpricing();
     DROP PROCEDURE productpricing;"

    # 触发器
    "CREATE TRIGGER newproduct AFTER INSERT ON oltp_test_table FOR EACH ROW SELECT 'Product added' INTO @result;
     INSERT INTO oltp_test_table (data_insert_date_time, user_city, user_age, user_gender, last_visit_time, total_spending, max_stay_duration, min_stay_duration)
         VALUES (NOW(), 'Beijing', 35, 'Male', NOW(), 463.00, 5900, 76);
     SELECT @result;
     DROP TRIGGER newproduct;"

    # 事务 - ROLLBACK
    "SELECT count(*) FROM oltp_test_table;
     START TRANSACTION;
     DELETE FROM oltp_test_table;
     SELECT count(*) FROM oltp_test_table;
     ROLLBACK;
     SELECT count(*) FROM oltp_test_table;"

    # 事务 - COMMIT
    "SELECT user_id FROM oltp_test_table;
     START TRANSACTION;
     DELETE FROM oltp_test_table WHERE user_id = 2;
     COMMIT;
     SELECT user_id FROM oltp_test_table;"

    # 删除
    "SELECT user_id FROM oltp_test_table;
     DELETE FROM oltp_test_table WHERE user_id = 3;
     SELECT user_id FROM oltp_test_table;"

    # 删表
    "SHOW TABLES LIKE 'oltp_test_table';
     DROP TABLE IF EXISTS oltp_test_table;
     SHOW TABLES LIKE 'oltp_test_table';"  # 验证表是否被成功删除

    # 删库
    "DROP DATABASE IF EXISTS $DB_DATABASE"
)

# 如果提供了 SQL 文件，将文件内容中每一对双引号中的内容作为一个查询
if [ -n "$SQL_FILE" ]; then
    # 调用函数解析 SQL 查询
    parse_sql "$SQL_FILE"
else
    SQL_QUERIES=("${DEFAULT_SQL_QUERIES[@]}")
fi

# 建立数据库连接并执行查询
set +e  # 禁用错误处理

for SQL_QUERY in "${SQL_QUERIES[@]}"; do
    SQL_QUERY=$(echo "$SQL_QUERY" | awk '{$1=$1};1') # 删除行首空白字符
    execute_sql_query "$SQL_QUERY" "$DB_DATABASE"
done

set -e  # 启用错误处理

# 打印总结
echo "执行完成，成功查询数: $SUCCESS_QUERIES, 失败查询数: $FAILED_QUERIES"

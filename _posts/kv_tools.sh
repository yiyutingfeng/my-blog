#!/bin/bash
# 支持单节点或多节点配置kv组件
#
# 单节点配置要求:
# ARBITER_RPC_PORT 与 CARRIER_RPC_PORT 分别至少配置3个端口号, IP个数仅配置1个
#
# 多节点配置要求:
# ARBITER_RPC_PORT 与 CARRIER_RPC_PORT 分别仅配置1个端口号, IP个数至少配置3个
# 每个节点下的该脚本配置需一致

# arbiter rpc_port 需修改
ARBITER_RPC_PORT=(15353 15354 15355)

# carrier rpc_port 需修改
CARRIER_RPC_PORT=(15356 15357 15358)

# kv部署节点,至少3个节点,需修改,不填表示仅在当前节点配置kv组件
IP=()

# 旧版包名是'ckv',若为旧版kv,则需修改为'ckv'
KV_NAME="CirroKV"

##############################################
# 函数定义
##############################################
# 解压安装包
# $1: 安装包路径
# $2: 解压目录
function extract_package {
    local package_path=$1
    local extract_dir=$2
    local package_name=$(basename "${package_path}")

    if [ "${package_name##*.}" == "zip" ]
    then
        # unzip支持解压zip
        unzip "${package_path}" -d "${extract_dir}" > /dev/null
    elif [ "${package_name##*.}" == "tar" ] || [ "${package_name##*.}" == "gz" ] || [ "${package_name##*.}" == "bz2" ] || [ "${package_name##*.}" == "xz" ]
    then
        # tar支持解压tar、tar.gz、tar.bz2、tar.xz
        tar xf "${package_path}" -C "${extract_dir}" > /dev/null
    else
        echo "不支持的安装包格式"
        exit -1
    fi

    echo "解压完成"
}

# 检查端口是否被占用
# $1: 端口号
function check_port {
    local port=$1
    local netstat_result=$(netstat -ant)

    # 检查端口是否已经被占用
    if grep -q "${port}" <<< "${netstat_result}"
    then
        echo "${port}端口可能还未释放,10后重试..."
        # 设置超时时间为60秒
        local timeout=60
        # 获取当前时间戳
        local start_time=$(date +%s)
        # 循环等待端口释放
        while true
        do
            # 判断超时时间是否到达
            if [ $(($(date +%s)-start_time)) -ge $timeout ]
            then
                echo -e "\e[31m${port}端口释放超时，请更换端口号\e[0m"
                exit -1
            fi
            # 等待10秒
            sleep 10
            echo "10s后再次重试..."
            # 再次执行netstat命令并保存结果
            netstat_result=$(netstat -ant)
            # 判断端口是否已经被释放
            if ! grep -q "${port}" <<< "${netstat_result}"
            then
                return
            fi
        done
    fi
}

# 修改配置文件
# $1: 配置文件路径
# $2: 要修改的选项名称
# $3: 要修改的选项值
function edit_config {
    local config_file="$1"
    local option_name="$2"
    local option_value="$3"

    if [ -e "${config_file}" ]
    then
        # 获取选项所在行号
        local line=$(grep -nA10 ">${option_name}" ${config_file} | grep "current" | cut -d '-' -f 1)
        # 生成替换字符串
        local replace_str="<current>${option_value}</current>"
        # 替换字符串中的特殊字符
        local replace_str_escaped=$(echo $replace_str | sed 's/\//\\\//g')
        # 设置选项值
        sed -i "${line}s/.*/    ${replace_str_escaped}/" "${config_file}"
    else
        echo "找不到配置文件 ${config_file}"
        exit -1
    fi

    echo "修改配置文件 ${config_file} 完成"
}

# 启动 kv
# $1: kv目录
function start_kv {
    local kv_dir=$1

    if [ ! -d "${kv_dir}" ]
    then
        return
    fi

    local kv_start_script=$(find "${kv_dir}" -name "start-ckv.sh")

    # 若kv_start_script为空,则说明该kv目录下没有start-ckv.sh脚本,则不启动kv
    if [ -z "${kv_start_script}" ]
    then
        return
    fi

    if ! ps -ef | grep ${kv_dir} | grep -q "arbiter"
    then
        # 启动 arbiter server
        ${kv_start_script} --arbiter=1
    fi

    if ! ps -ef | grep ${kv_dir} | grep -q "carrier"
    then
        # 启动 carrier server
        ${kv_start_script} --carrier=1
    fi
}

# 停止 kv
# $1: kv目录
function stop_kv {
    local kv_dir=$1

    if [ ! -d "${kv_dir}" ]
    then
        return
    fi

    local kv_stop_script=$(find "${kv_dir}" -name "stop-ckv.sh")

    # 若kv_stop_script为空,则说明该kv目录下没有stop-ckv.sh脚本,则不停止kv
    if [ -z "${kv_stop_script}" ]
    then
        return
    fi

    if ps -ef | grep ${kv_dir} | grep -q "arbiter"
    then
        # 停止 arbiter server
        ${kv_stop_script} --arbiter=1
    fi

    # 检查进程是否存在,存在则kill
    local arbiter_pid = $(ps -ef | grep ${kv_dir} | grep "arbiter" | awk '{print $2}')
    if [ -n "${arbiter_pid}" ]
    then
        echo "kill arbiter server"
        kill -9 ${arbiter_pid}
    fi

    # 检查进程是否存在,存在则kill

    if ps -ef | grep ${kv_dir} | grep -q "carrier"
    then
        # 停止 carrier server
        ${kv_stop_script} --carrier=1
    fi

    # 检查进程是否存在,存在则kill
    local carrier_pid = $(ps -ef | grep ${kv_dir} | grep "carrier" | awk '{print $2}')
    if [ -n "${carrier_pid}" ]
    then
        echo "kill carrier server"
        kill -9 ${carrier_pid}
    fi
}

# 清理 kv
# $1: kv目录
function clean_kv {
    local kv_dir=$1

    if [ ! -d "${kv_dir}" ]
    then
        return
    fi

    local kv_clean_script=$(find "${kv_dir}" -name "clean-ckv.sh")

    # 若kv_clean_script为空,则说明该kv目录下没有clean-ckv.sh脚本,则不清理kv
    if [ -z "${kv_clean_script}" ]
    then
        return
    fi

    # 先停止 kv
    stop_kv "${kv_dir}"

    # 清理 kv
    ${kv_clean_script} --all=1
}

# 部署kv
# $1: kv目录
function deploy_kv {
    local kv_dir=$1
    local arbiter_rpc_port=$2
    local carrier_rpc_port=$3
    local arbiter_addr_list=$4
    local package_path=$(ls -t *${KV_NAME}*.tar.gz | head -1)

    # 检查函数参数是否为空
    if [ -z "${kv_dir}" ] || [ -z "${arbiter_rpc_port}" ] || [ -z "${carrier_rpc_port}" ] || [ -z "${arbiter_addr_list}" ]
    then
        echo "函数参数不能为空"
        exit -1
    fi

    # 检查端口是否被占用
    check_port "${arbiter_rpc_port}"
    check_port "${carrier_rpc_port}"

    if [ -z "${package_path}" ]
    then
        echo "找不到安装包"
        exit -1
    fi

    if [ ! -d "${kv_dir}" ]
    then
        mkdir -p "${kv_dir}"
    fi

    # 若未解压过,则解压安装包
    if [ ! -d "${kv_dir}/${KV_NAME}" ]
    then
        extract_package "${package_path}" "${kv_dir}"
    fi

    local arbiter_conf_file=$(find "${kv_dir}" -name "config_arbiter.xml")
    local carrier_conf_file=$(find "${kv_dir}" -name "config_carrier.xml")
    local ckv_admin_conf_file=$(find "${kv_dir}" -name "config_ckv_admin.xml")

    declare -a arbiter_data_dir carrier_data_dir arbiter_options_name carrier_options_name arbiter_options_value carrier_options_value
    # kv数据目录
    arbiter_data_dir=(".ab_data" ".ab_wal")
    carrier_data_dir=(".cr_data" ".cr_wal" ".cr_conf")

    # 创建 arbiter 数据目录
    local i=0
    for ((i=0; i<${#arbiter_data_dir[@]}; ++i))
    do
        if [ ! -d "${kv_dir}/${arbiter_data_dir[i]}" ]
        then
            mkdir -p "${kv_dir}/${arbiter_data_dir[i]}"
        fi
    done

    arbiter_options_name=("rpc_port" "arbiter_addr_list" "data_dir" "wal_dir")
    carrier_options_name=("rpc_port" "arbiter_addr_list" "data_dir" "wal_dir" "conf_dir")
    arbiter_options_value=("${arbiter_rpc_port}" "${arbiter_addr_list}" "${kv_dir}/${arbiter_data_dir[0]}" "${kv_dir}/${arbiter_data_dir[1]}")
    carrier_options_value=("${carrier_rpc_port}" "${arbiter_addr_list}" "${kv_dir}/${carrier_data_dir[0]}" "${kv_dir}/${carrier_data_dir[1]}" "${kv_dir}/${carrier_data_dir[2]}")

    local kv_start_script=$(find "${kv_dir}" -name "start-ckv.sh")

    # 修改 arbiter 配置文件
    local j=0
    for ((j=0; j<${#arbiter_options_name[@]}; ++j))
    do
        edit_config "${arbiter_conf_file}" "${arbiter_options_name[j]}" "${arbiter_options_value[j]}"
    done

    # 修改 carrier 配置文件
    local k=0
    for ((k=0; k<${#carrier_options_name[@]}; ++k))
    do
        edit_config "${carrier_conf_file}" "${carrier_options_name[k]}" "${carrier_options_value[k]}"
    done

    local ckv_admin_options_name="ckv_admin_arbiter_address_list"
    local ckv_admin_options_value="${arbiter_addr_list}"

    # 修改 ckv-admin 配置文件
    edit_config "${ckv_admin_conf_file}" "${ckv_admin_options_name}" "${ckv_admin_options_value}"

    # 启动 kv
    start_kv "${kv_dir}"
}

# 查看 kv 状态
# $1: kv目录
function status_kv {
    local kv_dir=$1

    if [ ! -d "${kv_dir}" ]
    then
        return
    fi

    local kv_admin_script=$(find "${kv_dir}" -name "ckv-admin.sh")

    # 查看 kv 状态
    ${kv_admin_script} arbiter list
    ${kv_admin_script} carrier list
}

# 主函数
# $1: 可选参数
function main {
    local optional=$1
    declare -a nodes kv_root_dirs

    if [[ ${#IP[@]} -eq 0 ]]
    then
        local local_node=$(hostname -i | awk '{print $1}')
        nodes+=(${local_node})
    fi

    local home=$(pwd)
    local arbiter_size=${#ARBITER_RPC_PORT[@]}
    local carrier_size=${#CARRIER_RPC_PORT[@]}
    local ip_size=${#nodes[@]}

    # ip数为1,端口数不小于3,即单节点多kv
    if [[ ${ip_size} -eq 1 ]] && [[ ${arbiter_size} -eq ${carrier_size} ]] && [[ ${arbiter_size} -ge 3 ]] && [[ ${carrier_size} -ge 3 ]]
    then
        local i=0
        for ((i=0; i<${#ARBITER_RPC_PORT[@]}; ++i))
        do
            kv_root_dirs+=(${home}/kv_store_${i})
        done
    elif [[ ${ip_size} -ge 3 ]] && [[ ${arbiter_size} -eq ${carrier_size} ]] && [[ ${arbiter_size} -eq 1 ]] && [[ ${carrier_size} -eq 1 ]]
    then
        kv_root_dirs=("${home}")
    else
        echo "请检查kv_tools.sh配置是否正确"
        echo "ip数为${ip_size},arbiter_rpc_port数为${arbiter_size},carrier_rpc_port数为${carrier_size}"
        exit -1
    fi

    local arbiter_addr_list=""
    local j=0
    for ((j=0; j<${#nodes[@]}; ++j))
    do
        local host_name=$(awk -v s=${nodes[j]} '$1==s{print $2}' /etc/hosts)
        if [[ ${host_name} ]]
        then
            local k=0
            for ((k=0; k<${#ARBITER_RPC_PORT[@]}; ++k))
            do
                arbiter_addr_list+="${host_name}:${ARBITER_RPC_PORT[k]},"
            done
        else
            echo "/etc/hosts中找不到${nodes[j]}对应的hostname"
            exit -1
        fi
    done

    # 去除末尾的逗号
    arbiter_addr_list=$(echo "$arbiter_addr_list" | sed 's/,$//')

    local kv_dir_size=${#kv_root_dirs[@]}
    local n=0
    for ((n=0; n <${kv_dir_size}; ++n))
    do
        case ${optional} in
            "deploy")
                deploy_kv "${kv_root_dirs[n]}" "${ARBITER_RPC_PORT[n]}" "${CARRIER_RPC_PORT[n]}" "${arbiter_addr_list}"
                ;;
            "start")
                start_kv "${kv_root_dirs[n]}"
                ;;
            "stop")
                stop_kv "${kv_root_dirs[n]}"
                ;;
            "clean")
                clean_kv "${kv_root_dirs[n]}"
                ;;
            "restart")
                stop_kv "${kv_root_dirs[n]}"
                start_kv "${kv_root_dirs[n]}"
                ;;
            "update")
                stop_kv "${kv_root_dirs[n]}"
                rm -rf "${kv_root_dirs[n]}"
                deploy_kv "${kv_root_dirs[n]}" "${ARBITER_RPC_PORT[n]}" "${CARRIER_RPC_PORT[n]}" "${arbiter_addr_list}"
                ;;
            "status")
                status_kv "${kv_root_dirs[n]}"
                exit 0
                ;;
            *)
                echo "Usage: ./kv_tools.sh [deploy|start|stop|clean|restart|update|status]"
                echo "deploy: 部署kv"
                echo "start: 启动kv"
                echo "stop: 停止kv"
                echo "clean: 清理kv"
                echo "restart: 重启kv"
                echo "update: 更新kv"
                echo "status: 查看kv状态"
                exit -1
                ;;
        esac
    done

    if [[ ${optional} == "deploy" ]] || [[ ${optional} == "update" ]]
    then
        # 等待 kv 启动完成
        sleep 5
        # 查看 kv 状态
        status_kv "${kv_root_dirs[0]}"
        echo -e "CirroEngine配置参数 client_arbiter_address_list: \e[1;32m${arbiter_addr_list}\e[0m"
    fi
}

main "$1"

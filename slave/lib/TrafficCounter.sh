#!/bin/bash

# 传入参数
ACTION=$1
PORT=$2
BANDWIDTH=$3
FORWARDPORT=$4
FORWARDIP=$5
METHOD=$6
NODEBANDWIDTH=$7
BURST=$8

# 默认配置
IPTABLES=/usr/sbin/iptables
TC=/usr/sbin/tc
CHAIN_NAME_TCP="TLG-TCP-$PORT"
CHAIN_NAME_UDP="TLG-UDP-$PORT"

# 获取默认网络接口
NIC=$(ip route | grep default | awk '{print $5}')

# 检查 iptables 和 tc 是否可用
if ! command -v $IPTABLES &>/dev/null; then
    echo "错误: 未找到 iptables 命令。请安装 iptables。"
    exit 1
fi

if ! command -v $TC &>/dev/null; then
    echo "错误: 未找到 tc 命令。请安装 iproute2。"
    exit 1
fi

# 禁用规则
function disable() {
    echo "清除规则... "
    if [ "$METHOD" == "iptables" ]; then
        $IPTABLES -w -D FORWARD -p tcp --sport $FORWARDPORT -s "$FORWARDIP"/32 -j $CHAIN_NAME_TCP 2>/dev/null
        $IPTABLES -w -D FORWARD -p udp --sport $FORWARDPORT -s "$FORWARDIP"/32 -j $CHAIN_NAME_UDP 2>/dev/null
    else
        $IPTABLES -w -D INPUT -p tcp --dport $PORT 2>/dev/null
        $IPTABLES -w -D INPUT -p udp --dport $PORT 2>/dev/null
        $IPTABLES -w -D OUTPUT -p tcp --sport $PORT -j $CHAIN_NAME_TCP 2>/dev/null
        $IPTABLES -w -D OUTPUT -p udp --sport $PORT -j $CHAIN_NAME_UDP 2>/dev/null
    fi
    $IPTABLES -w -F $CHAIN_NAME_TCP 2>/dev/null
    $IPTABLES -w -X $CHAIN_NAME_TCP 2>/dev/null
    $IPTABLES -w -F $CHAIN_NAME_UDP 2>/dev/null
    $IPTABLES -w -X $CHAIN_NAME_UDP 2>/dev/null
}

# 启用带宽限制规则
function enable() {
    echo "设置带宽规则... "
    disable

    # 决定速率是否使用突发带宽
    if [ "$BURST" == "true" ]; then
        SPEEDLIMIT=$NODEBANDWIDTH
    else
        SPEEDLIMIT=$BANDWIDTH
    fi

    # 添加带宽限制规则
    if ! $TC class add dev $NIC parent 1:1 classid 1:"$BANDWIDTH" htb rate "${BANDWIDTH}Mbit" ceil "${SPEEDLIMIT}Mbit"; then
        echo "错误: 无法设置带宽限制 (class add dev $NIC)"
        exit 1
    fi

    # 配置队列规则
    if ! $TC qdisc add dev $NIC parent 1:"$BANDWIDTH" handle "$BANDWIDTH": sfq perturb 5; then
        echo "错误: 无法配置队列规则 (qdisc add dev $NIC)"
        exit 1
    fi

    # 配置过滤规则
    if ! $TC filter add dev $NIC parent 1:0 protocol ip prio 1 handle $BANDWIDTH fw classid 1:"$BANDWIDTH"; then
        echo "错误: 无法配置过滤规则 (filter add dev $NIC)"
        exit 1
    fi

    # 创建 iptables 链
    $IPTABLES -w -N $CHAIN_NAME_TCP 2>/dev/null || echo "链 $CHAIN_NAME_TCP 已存在，继续..."
    $IPTABLES -w -N $CHAIN_NAME_UDP 2>/dev/null || echo "链 $CHAIN_NAME_UDP 已存在，继续..."

    # 配置 iptables 规则
    if [ "$METHOD" == "iptables" ]; then
        $IPTABLES -w -A FORWARD -p tcp --sport $FORWARDPORT -s "$FORWARDIP"/32 -j $CHAIN_NAME_TCP || {
            echo "错误: 无法添加 FORWARD 规则 (TCP)"
            exit 1
        }
        $IPTABLES -w -A FORWARD -p udp --sport $FORWARDPORT -s "$FORWARDIP"/32 -j $CHAIN_NAME_UDP || {
            echo "错误: 无法添加 FORWARD 规则 (UDP)"
            exit 1
        }
        $IPTABLES -w -A $CHAIN_NAME_TCP -j MARK --set-mark="$BANDWIDTH" || {
            echo "错误: 无法设置 MARK 规则 (TCP)"
            exit 1
        }
        $IPTABLES -w -A $CHAIN_NAME_UDP -j MARK --set-mark="$BANDWIDTH" || {
            echo "错误: 无法设置 MARK 规则 (UDP)"
            exit 1
        }
    else
        $IPTABLES -w -A INPUT -p tcp --dport $PORT || {
            echo "错误: 无法添加 INPUT 规则 (TCP)"
            exit 1
        }
        $IPTABLES -w -A INPUT -p udp --dport $PORT || {
            echo "错误: 无法添加 INPUT 规则 (UDP)"
            exit 1
        }
        $IPTABLES -w -A OUTPUT -p tcp --sport $PORT -j $CHAIN_NAME_TCP || {
            echo "错误: 无法添加 OUTPUT 规则 (TCP)"
            exit 1
        }
        $IPTABLES -w -A OUTPUT -p udp --sport $PORT -j $CHAIN_NAME_UDP || {
            echo "错误: 无法添加 OUTPUT 规则 (UDP)"
            exit 1
        }
        $IPTABLES -w -A $CHAIN_NAME_TCP -j MARK --set-mark="$BANDWIDTH" || {
            echo "错误: 无法设置 MARK 规则 (TCP)"
            exit 1
        }
        $IPTABLES -w -A $CHAIN_NAME_UDP -j MARK --set-mark="$BANDWIDTH" || {
            echo "错误: 无法设置 MARK 规则 (UDP)"
            exit 1
        }
    fi

    echo "带宽规则已成功启用"
}


# 显示流量统计
function show() {
    echo "显示流量统计... "
    in_bytes=$($IPTABLES -w -L $CHAIN_NAME_TCP -Z -vnx | tail -2 | head -1 | awk '{print $2}')
    out_bytes=$($IPTABLES -w -L $CHAIN_NAME_UDP -Z -vnx | tail -2 | head -1 | awk '{print $2}')
    echo "[$PORT,$in_bytes,$out_bytes]"
}

# 根据参数执行不同操作
case "$ACTION" in
    enable)
        echo "启用带宽限制规则 $PORT"
        enable
        echo "完成"
        ;;
    disable)
        echo "禁用带宽限制规则 $PORT"
        disable
        echo "完成"
        ;;
    show)
        show
        ;;
    *)
        echo "无效的操作，请使用 enable、disable 或 show"
        exit 1
        ;;
esac

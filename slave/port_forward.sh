#!/bin/bash

# 动态获取命令路径
IPTABLES=$(command -v iptables)
TC=$(command -v tc)
PHP=$(command -v php)

# 日志记录函数，仅在终端打印
log() {
    local level="$1"
    local message="$2"
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') [$level] $message"
}

# 检查依赖命令是否存在
for cmd in iptables tc php; do
    if ! command -v $cmd &> /dev/null; then
        log "ERROR" "$cmd 未安装，请安装后再运行脚本。"
        exit 1
    fi
done

log "INFO" "所有依赖命令已检测到。"

# 解析 config.php
nic=$(grep -E "^\\\$nic" /usr/local/PortForward/slave/config.php | awk -F"'" '{print $2}')
node_bw_max=$(grep -E "^\\\$node_bw_max" /usr/local/PortForward/slave/config.php | awk -F"'" '{print $2}')

if [[ -z "$nic" || -z "$node_bw_max" ]]; then
    log "ERROR" "未能正确解析 config.php 文件中的主网卡或节点最大带宽参数。"
    exit 1
fi

log "INFO" "解析到的网卡：$nic，最大带宽：${node_bw_max}Mbit。"

# 清理 iptables 规则
log "INFO" "清理 iptables 规则..."
sleep 60
$IPTABLES -w -F
$IPTABLES -w -F FORWARD
$IPTABLES -w -F -t nat
$IPTABLES -w -X
$IPTABLES -w -X -t nat
log "INFO" "iptables 规则清理完成。"

# 设置 tc 带宽控制
log "INFO" "设置 tc 带宽控制，网卡：$nic，最大带宽：${node_bw_max}Mbit..."
$TC qdisc del dev "$nic" root 2>/dev/null
$TC qdisc add dev "$nic" root handle 1: htb 2>/dev/null
$TC class add dev "$nic" parent 1:0 classid 1:1 htb rate "${node_bw_max}Mbit" 2>/dev/null

if [[ $? -ne 0 ]]; then
    log "ERROR" "tc 带宽控制设置失败，请检查网卡名称和最大带宽配置。"
    exit 1
fi
log "INFO" "tc 带宽控制设置成功。"

# 循环运行 PHP 脚本
log "INFO" "开始循环运行 PHP 脚本..."
while :; do
    for i in {1..30}; do
        log "INFO" "执行 Traffic_Checker.php..."
        $PHP /usr/local/PortForward/slave/Traffic_Checker.php
        
        log "INFO" "执行 Port_Checker.php..."
        $PHP /usr/local/PortForward/slave/Port_Checker.php
        
        log "INFO" "等待 60 秒..."
        sleep 60
    done
done

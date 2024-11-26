#!/bin/bash

# 动态获取命令路径
IPTABLES=$(command -v iptables)
TC=$(command -v tc)
PHP=$(command -v php)

# 检查依赖命令是否存在
for cmd in iptables tc php; do
    if ! command -v $cmd &> /dev/null; then
        echo "Error: $cmd 未安装，请安装后再运行脚本。"
        exit 1
    fi
done

# 解析 config.php
nic=$(grep -E "^\\\$nic" /usr/local/PortForward/slave/config.php | awk -F"'" '{print $2}')
node_bw_max=$(grep -E "^\\\$node_bw_max" /usr/local/PortForward/slave/config.php | awk -F"'" '{print $2}')

if [[ -z "$nic" || -z "$node_bw_max" ]]; then
    echo "Error: 未能正确解析 config.php 文件中的主网卡或节点最大带宽参数。"
    exit 1
fi

# 清理 iptables 规则
sleep 60
$IPTABLES -w -F
$IPTABLES -w -F FORWARD
$IPTABLES -w -F -t nat
$IPTABLES -w -X
$IPTABLES -w -X -t nat

# 设置 tc 带宽控制
$TC qdisc del dev "$nic" root 2>/dev/null
$TC qdisc add dev "$nic" root handle 1: htb 2>/dev/null
$TC class add dev "$nic" parent 1:0 classid 1:1 htb rate "${node_bw_max}Mbit" 2>/dev/null

if [[ $? -ne 0 ]]; then
    echo "Error: tc 带宽控制设置失败，请检查网卡名称和最大带宽配置。"
    exit 1
fi

# 循环运行 PHP 脚本
while :; do
    for i in {1..30}; do
        $PHP /usr/local/PortForward/slave/Traffic_Checker.php
        $PHP /usr/local/PortForward/slave/Port_Checker.php
        sleep 60
    done
done

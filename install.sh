#!/usr/bin/env bash

# 定义变量
REPO_URL="https://github.com/<your-username>/<your-repo>.git"
INSTALL_DIR="/usr/local/PortForward"
BIN_DIR="/usr/bin"
BRANCH="main"
GITHUB_PROXY="https://ghp.ci/"
Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[Message]${Font_color_suffix}"
Error="${Red_font_prefix}[ERROR]${Font_color_suffix}"
Tip="${Green_font_prefix}[Tip]${Font_color_suffix}"

# 默认值
NIC=""
URL=""
KEY=""
SOURCEIP=""
MAGNIFICATION=0.5
NODE_BW_MAX=100
BURST=false

# 检查依赖
check_dependencies() {
    for cmd in git unzip wget curl; do
        if ! command -v $cmd &> /dev/null; then
            echo -e " ${Error} 缺少必要工具：$cmd，请安装后再运行脚本。"
            exit 1
        fi
    done
}

# 下载工具
download_tool() {
    local url=$1
    local output=$2
    wget -q "$url" -O "$output" || {
        echo -e " ${Error} 下载 $output 失败！URL: $url"
        exit 1
    }
}

# 从 GitHub 拉取文件
fetch_files() {
    if [[ $USE_PROXY == true ]]; then
        REPO_URL="${GITHUB_PROXY}${REPO_URL}"
    fi

    if [[ -d "$INSTALL_DIR" ]]; then
        cd "$INSTALL_DIR" && git pull || {
            echo -e " ${Error} 更新失败！"
            exit 1
        }
    else
        git clone -b "$BRANCH" "$REPO_URL" "$INSTALL_DIR" || {
            echo -e " ${Error} 克隆仓库失败！"
            exit 1
        }
    fi
}

# 生成配置文件
generate_config() {
    cat > /usr/local/PortForward/slave/config.php <<EOF
<?php
\$nic = '${NIC}'; // 主网卡名称
\$url = '${URL}';
\$key = '${KEY}'; // 在 WHMCS 设置的 key
\$sourceip = '${SOURCEIP}'; // 主网卡 IP 地址
\$magnification = '${MAGNIFICATION}'; // 流量倍率
\$node_bw_max = '${NODE_BW_MAX}'; // 节点最大带宽
\$burst = '${BURST}'; // 带宽突发
?>
EOF

    echo -e " ${Info} config.php 文件生成完成。"
}

# 解析参数
parse_args() {
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
        -nic) NIC="$2"; shift ;;
        -url) URL="$2"; shift ;;
        -key) KEY="$2"; shift ;;
        -sourceip) SOURCEIP="$2"; shift ;;
        -magnification) MAGNIFICATION="$2"; shift ;;
        -node_bw_max) NODE_BW_MAX="$2"; shift ;;
        -burst) BURST="$2"; shift ;;
        *) echo -e "${Error} 未知参数: $1"; exit 1 ;;
        esac
        shift
    done

    # 参数验证
    if [[ -z "$NIC" || -z "$URL" || -z "$KEY" ]]; then
        echo -e "${Error} 参数缺失。请提供 -nic, -url 和 -key 参数。"
        exit 1
    fi
}

# 安装函数
Install() {
    check_dependencies

    echo -e " ${Tip} 正在安装必要依赖..."
    apt update && apt install -y wget git unzip curl php

    echo -e " ${Tip} 下载主程序文件..."
    fetch_files

    echo -e " ${Tip} 移动文件到目标目录..."
    mkdir -p /usr/local/PortForward
    mv -f slave /usr/local/PortForward/
    chmod +x -R /usr/local/PortForward/slave

    # 生成配置文件
    generate_config

    echo -e " ${Tip} 安装完成，配置 systemd 服务..."
    mv /usr/local/PortForward/slave/port_forward.sh /usr/local/bin/port_forward.sh
    mv /usr/local/PortForward/slave/port_forward.service /etc/systemd/system/port_forward.service
    systemctl daemon-reload
    systemctl enable port_forward
    echo net.ipv4.ip_forward = 1 >> /etc/sysctl.conf
    sysctl -p

    echo -e " ${Info} 安装完成，请根据需求启动服务。"
}

# 主函数
main() {
    parse_args "$@"
    Install
}

main "$@"

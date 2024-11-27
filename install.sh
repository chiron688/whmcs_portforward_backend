#!/usr/bin/env bash

# Define variables
REPO_URL="https://github.com/chiron688/whmcs_portforward_backend.git"
INSTALL_DIR="/usr/local/PortForward"
BIN_DIR="/usr/bin"
BRANCH="main"
GITHUB_PROXY="https://ghp.ci/"
Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[Message]${Font_color_suffix}"
Error="${Red_font_prefix}[ERROR]${Font_color_suffix}"
Tip="${Green_font_prefix}[Tip]${Font_color_suffix}"

# Initialize variables for command-line arguments
nic=""
url=""
key=""
sourceip=""
magnification=""
node_bw_max=""
burst=""
USE_PROXY=false

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -nic)
            nic="$2"
            shift 2
            ;;
        -url)
            url="$2"
            shift 2
            ;;
        -key)
            key="$2"
            shift 2
            ;;
        -sourceip)
            sourceip="$2"
            shift 2
            ;;
        -magnification)
            magnification="$2"
            shift 2
            ;;
        -node_bw_max)
            node_bw_max="$2"
            shift 2
            ;;
        -burst)
            burst="$2"
            shift 2
            ;;
        -use_proxy)
            USE_PROXY=true
            shift 1
            ;;
        -h|--help)
            echo "Usage: bash install.sh [options]"
            echo "Options:"
            echo "  -nic             Network interface name"
            echo "  -url             WHMCS API URL"
            echo "  -key             WHMCS API key"
            echo "  -sourceip        Source IP address"
            echo "  -magnification   Traffic magnification (default: 0.5)"
            echo "  -node_bw_max     Node maximum bandwidth (default: 100)"
            echo "  -burst           Bandwidth burst (default: false)"
            echo "  -use_proxy       Use GitHub proxy"
            echo "  -h, --help       Display this help message"
            exit 0
            ;;
        *)
            echo -e "${Error} Unknown option: $1"
            exit 1
            ;;
    esac
done

# Check dependencies
check_dependencies() {
    for cmd in git unzip wget curl; do
        if ! command -v $cmd &> /dev/null; then
            echo -e " ${Error} Missing required tool: $cmd. Please install it and re-run the script."
            exit 1
        fi
    done
}

# System check
check_sys() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        release=$ID
    elif command -v lsb_release &> /dev/null; then
        release=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
    else
        echo -e "${Error} Unable to detect the system type."
        exit 1
    fi
    bit=$(uname -m)
}

# Fetch files from GitHub
fetch_files() {
    if [[ $USE_PROXY == true ]]; then
        REPO_URL="${GITHUB_PROXY}${REPO_URL}"
    fi

    if [[ -d "$INSTALL_DIR" ]]; then
        cd "$INSTALL_DIR" && git pull || {
            echo -e " ${Error} Update failed!"
            exit 1
        }
    else
        git clone -b "$BRANCH" "$REPO_URL" "$INSTALL_DIR" || {
            echo -e " ${Error} Failed to clone repository!"
            exit 1
        }
    fi
}

# Function to download and check existing files
download_file() {
    local url="$1"
    local dest="$2"
    if [[ -f "$dest" ]]; then
        echo -e " ${Info} File $dest already exists, skipping download."
    else
        echo -e " ${Tip} Downloading $dest..."
        wget -O "$dest" "$url" || {
            echo -e " ${Error} Failed to download $url"
            exit 1
        }
    fi
}
# Get default network interface
get_default_nic() {
    local default_nic=$(ip route | grep default | awk '{print $5}' | head -n 1)
    if [[ -z "$default_nic" ]]; then
        echo "unknown"
    else
        echo "$default_nic"
    fi
}

# Generate configuration
generate_config() {
    # If nic is not provided, attempt to detect it
    if [[ -z "$nic" ]]; then
        local detected_nic=$(get_default_nic)
        echo -e " ${Tip} Detected primary network interface: ${detected_nic}"
        read -p "Please enter the network interface name (default: ${detected_nic}): " nic_input
        nic=${nic_input:-$detected_nic}
    fi

    # If url is not provided, prompt for it
    if [[ -z "$url" ]]; then
        read -p "Please enter the WHMCS API URL (e.g., https://www.example.com/modules/addons/PortForward/apicall.php): " url_input
        while [[ -z "$url_input" ]]; do
            echo -e " ${Error} API URL cannot be empty. Please re-enter."
            read -p "Please enter the API URL: " url_input
        done
        url="$url_input"
    fi

    # If key is not provided, prompt for it
    if [[ -z "$key" ]]; then
        read -p "Please enter the WHMCS API key: " key_input
        while [[ -z "$key_input" ]]; do
            echo -e " ${Error} API key cannot be empty. Please re-enter."
            read -p "Please enter the WHMCS API key: " key_input
        done
        key="$key_input"
    fi

    # If source IP is not provided, attempt to detect it
    if [[ -z "$sourceip" ]]; then
        local detected_ip=$(ip addr show "$nic" | grep "inet " | awk '{print $2}' | cut -d/ -f1 | head -n 1)
        if [[ -z "$detected_ip" ]]; then
            detected_ip="unknown"
        fi
        echo -e " ${Tip} Detected IP address for ${nic}: ${detected_ip}"
        read -p "Please enter the source IP address (default: ${detected_ip}): " ip_input
        sourceip=${ip_input:-$detected_ip}
    fi

    # Set default values if not provided
    magnification=${magnification:-0.5}
    node_bw_max=${node_bw_max:-100}
    burst=${burst:-false}

    # Generate the configuration file
    cat > /usr/local/PortForward/slave/config.php <<EOF
<?php
\$nic = '${nic}'; // Network interface name
\$url = '${url}';
\$key = '${key}'; // WHMCS API key
\$sourceip = '${sourceip}'; // Source IP address
\$magnification = '${magnification}'; // Traffic magnification
\$node_bw_max = '${node_bw_max}'; // Node maximum bandwidth
\$burst = '${burst}'; // Bandwidth burst
?>
EOF

    echo -e " ${Info} config.php has been generated."
}

# Install function
Install() {
    check_sys
    check_dependencies

    if [[ ${release} == "centos" ]]; then
        # CentOS installation logic
        yum install wget unzip git -y
        cat /etc/redhat-release | grep 7\..* | grep -i centos >/dev/null
        if [[ $? -ne 0 ]]; then
            echo -e " ${Error} CentOS 6/8 is not supported. Please use CentOS 7 x64."
            exit 1
        fi
        echo -e " ${Tip} Installing EPEL and Webtatic..."
        rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
        rpm -Uvh https://mirror.webtatic.com/yum/el7/webtatic-release.rpm
        echo -e " ${Tip} Installing PHP 7.0..."
        yum install -y php70w php70w-cli php70w-common php70w-gd php70w-ldap php70w-mbstring php70w-mcrypt php70w-mysql php70w-pdo
    elif [[ ${release} == "debian" || ${release} == "ubuntu" ]]; then
        # Debian and Ubuntu installation logic
        apt update
        echo -e " ${Tip} Installing PHP and dependencies..."
        apt install -y wget git unzip curl software-properties-common lsb-release ca-certificates apt-transport-https gnupg2

        if [[ ${release} == "ubuntu" ]]; then
            # For Ubuntu, add the PPA
            add-apt-repository ppa:ondrej/php -y
            apt update
        fi

        # Install PHP (use version 8.2 or the default available in repositories)
        apt install -y php php-cli php-common php-gd php-ldap php-mbstring php-mysql php-pdo
    else
        echo -e " ${Error} Unsupported system. Please use a supported system."
        exit 1
    fi

    # Define versions
    BROOK_VERSION="v20210701"
    GOST_VERSION="2.12.0"
    TINYMAPPER_VERSION="20200818.0"
    GOPROXY_VERSION="v14.7"


    echo -e " ${Tip} Installing Brook..."
    if [[ -f /usr/bin/brook ]]; then
        echo -e " ${Info} Brook is already installed."
    else
        download_file "https://ghp.ci/https://github.com/txthinking/brook/releases/download/${BROOK_VERSION}/brook_linux_amd64" "/usr/bin/brook"
        chmod +x /usr/bin/brook
    fi

    echo -e " ${Tip} Installing Gost..."
    if [[ -f /usr/bin/gost ]]; then
        echo -e " ${Info} Gost is already installed."
    else
        # 下载文件
        download_file "https://ghp.ci/https://github.com/ginuerzh/gost/releases/download/v${GOST_VERSION}/gost_${GOST_VERSION}_linux_amd64.tar.gz" "gost.tar.gz"
        
        # 解压文件
        echo -e " ${Tip} Extracting gost.tar.gz..."
        tar -xzf gost.tar.gz || {
            echo -e " ${Error} Failed to extract gost.tar.gz!"
            exit 1
        }

        # 检查解压结果是否有目标文件
        if [[ -f "gost" ]]; then
            echo -e " ${Tip} Moving Gost binary to /usr/bin..."
            mv -f gost /usr/bin/gost
            chmod +x /usr/bin/gost
            echo -e " ${Tip} Gost installed successfully."
        else
            echo -e " ${Error} Gost binary not found after extraction!"
            exit 1
        fi

        # 清理临时文件
        rm -f gost.tar.gz
    fi


    echo -e " ${Tip} Installing tinyPortMapper..."
    if [[ -f /usr/bin/tinymapper ]]; then
        echo -e " ${Info} tinyPortMapper is already installed."
    else
        download_file "https://ghp.ci/https://github.com/wangyu-/tinyPortMapper/releases/download/${TINYMAPPER_VERSION}/tinymapper_binaries.tar.gz" "tinymapper.tar.gz"
        if [[ ! -f tinymapper_amd64 ]]; then
            tar -xzf tinymapper.tar.gz --wildcards "*_amd64"
        fi
        if [[ -f tinymapper_amd64 ]]; then
            mv -f tinymapper_amd64 /usr/bin/tinymapper
            chmod +x /usr/bin/tinymapper
        else
            echo -e " ${Error} Failed to locate tinymapper binary after extraction."
            exit 1
        fi
        rm -f tinymapper.tar.gz
    fi

    echo -e " ${Tip} Installing goproxy..."
    if [[ -f /usr/bin/goproxy ]]; then
        echo -e " ${Info} goproxy is already installed."
    else
        download_file "https://ghp.ci/https://github.com/snail007/goproxy/releases/download/${GOPROXY_VERSION}/proxy-linux-amd64.tar.gz" "proxy.tar.gz"
        if [[ ! -f proxy ]]; then
            tar -xzf proxy.tar.gz proxy
        fi
        if [[ -f proxy ]]; then
            mv -f proxy /usr/bin/goproxy
            chmod +x /usr/bin/goproxy
        else
            echo -e " ${Error} Failed to locate proxy binary after extraction."
            exit 1
        fi
        rm -f proxy.tar.gz
    fi

    # Disable firewalls based on the release type
    if [[ ${release} == "centos" ]]; then
        echo -e " ${Tip} Disabling Firewalld..."
        systemctl stop firewalld || echo -e " ${Warn} Failed to stop firewalld."
        systemctl disable firewalld || echo -e " ${Warn} Failed to disable firewalld."
    else
        if command -v ufw &> /dev/null; then
            echo -e " ${Tip} Disabling UFW firewall..."
            ufw disable || echo -e " ${Warn} Failed to disable UFW."
        else
            echo -e " ${Info} UFW is not installed; skipping UFW disable step."
        fi
    fi

    fetch_files
    # 确保进入 INSTALL_DIR 并检查 slave 目录
    cd "$INSTALL_DIR" || exit 1

    if [[ -d "slave" ]]; then
        echo -e " ${Tip} Moving main program to the target directory..."
        mkdir -p /usr/local/PortForward
        cp -r slave /usr/local/PortForward/ || {
            echo -e " ${Error} Failed to copy slave directory!"
            exit 1
        }
        chmod +x -R /usr/local/PortForward/slave
    else
        echo -e " ${Error} 'slave' directory not found in the repository!"
        exit 1
    fi

    # Generate configuration file
    echo -e " ${Tip} Generating configuration file..."
    generate_config || {
        echo -e " ${Error} Failed to generate configuration file!"
        exit 1
    }

    echo -e " ${Tip} Adding systemd service..."
    if [[ -f /usr/local/PortForward/slave/port_forward.sh && -f /usr/local/PortForward/slave/port_forward.service ]]; then
        cp /usr/local/PortForward/slave/port_forward.sh /usr/local/bin/port_forward.sh || {
            echo -e " ${Error} Failed to copy port_forward.sh!"
            exit 1
        }
        cp /usr/local/PortForward/slave/port_forward.service /etc/systemd/system/port_forward.service || {
            echo -e " ${Error} Failed to copy port_forward.service!"
            exit 1
        }
        systemctl daemon-reload || {
            echo -e " ${Error} Failed to reload systemd daemon!"
            exit 1
        }
        systemctl enable port_forward || {
            echo -e " ${Error} Failed to enable port_forward service!"
            exit 1
        }
    else
        echo -e " ${Error} Required files 'port_forward.sh' or 'port_forward.service' not found!"
        exit 1
    fi

    echo -e " ${Tip} Enabling IP forwarding..."
    echo net.ipv4.ip_forward = 1 >> /etc/sysctl.conf || {
        echo -e " ${Error} Failed to update sysctl.conf!"
        exit 1
    }
    sysctl -p || {
        echo -e " ${Error} Failed to apply sysctl settings!"
        exit 1
    }

    echo -e " ${Tip} Installation complete."
    exit 0

}

# Start the script
Install

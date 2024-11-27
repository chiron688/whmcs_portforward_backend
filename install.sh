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

# Function to download the latest release from GitHub
download_latest() {
    local repo=$1
    local binary_name=$2
    local dest_path=$3

    # Fetch the latest release URL using GitHub API
    local latest_url=$(curl -sL "https://api.github.com/repos/${repo}/releases/latest" | grep "browser_download_url" | grep "${binary_name}" | cut -d '"' -f 4)

    if [[ -n "$latest_url" ]]; then
        echo -e " ${Tip} Downloading ${binary_name} from ${repo}..."
        download_tool "$latest_url" "$dest_path"
    else
        echo -e " ${Error} Failed to fetch latest release for ${binary_name} from ${repo}."
        exit 1
    fi
}

# Download tool
download_tool() {
    local url=$1
    local output=$2
    wget -q "$url" -O "$output" || {
        echo -e " ${Error} Failed to download $output from URL: $url"
        exit 1
    }
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

    echo -e " ${Tip} Installing Brook..."
    download_latest "txthinking/brook" "linux_amd64" "/usr/bin/brook"

    echo -e " ${Tip} Installing Gost..."
    download_latest "ginuerzh/gost" "linux-amd64" "gost.gz"
    gunzip gost.gz
    mv -f gost /usr/bin/gost
    chmod +x /usr/bin/gost

    echo -e " ${Tip} Installing tinyPortMapper..."
    download_latest "wangyu-/tinyPortMapper" "binaries.tar.gz" "tinymapper.tar.gz"
    tar -xzf tinymapper.tar.gz --wildcards "*_amd64"
    mv -f tinymapper_amd64 /usr/bin/tinymapper
    chmod +x /usr/bin/tinymapper

    echo -e " ${Tip} Installing goproxy..."
    download_latest "snail007/goproxy" "linux-amd64.tar.gz" "proxy.tar.gz"
    tar -xzf proxy.tar.gz proxy
    mv -f proxy /usr/bin/goproxy
    chmod +x /usr/bin/goproxy

    if [[ ${release} == "centos" ]]; then
        echo -e " ${Tip} Disabling Firewalld..."
        systemctl stop firewalld
        systemctl disable firewalld
    else
        echo -e " ${Tip} Disabling UFW firewall..."
        ufw disable
    fi

    echo -e " ${Tip} Downloading main program files..."

    fetch_files

    echo -e " ${Tip} Moving main program to the target directory..."
    mkdir -p /usr/local/PortForward
    mv -f slave /usr/local/PortForward/
    chmod +x -R /usr/local/PortForward/slave

    # Generate configuration file
    generate_config

    echo -e " ${Tip} Adding systemd service..."
    mv /usr/local/PortForward/slave/port_forward.sh /usr/local/bin/port_forward.sh
    mv /usr/local/PortForward/slave/port_forward.service /etc/systemd/system/port_forward.service
    systemctl daemon-reload
    systemctl enable port_forward
    echo net.ipv4.ip_forward = 1 >> /etc/sysctl.conf
    sysctl -p
    echo -e " ${Tip} Installation complete."
    exit
}

# Start the script
Install

PortForward 安装脚本
该脚本用于快速安装和配置 PortForward 被控程序，并支持通过命令行参数传递必要的配置。

使用说明
运行脚本
克隆或下载本仓库到本地：

bash
复制代码
git clone https://github.com/<your-username>/<your-repo>.git
cd <your-repo>
运行安装脚本，并传递参数：

bash
复制代码
bash install.sh -nic 'ens192' -url 'https://portal.jiasu.ai/modules/addons/PortForward/apicall.php' -key 'your_api_key' -sourceip '192.168.1.1' -magnification 0.5 -node_bw_max 100 -burst false
参数说明
参数	描述	是否必填	默认值
-nic	主网卡名称，用于网络通信	是	无
-url	WHMCS 接口地址（如 https://your-whmcs-site/apicall.php）	是	无
-key	WHMCS 接口密钥	是	无
-sourceip	主网卡 IP 地址（若不传则自动检测）	否	自动检测
-magnification	流量倍率	否	0.5
-node_bw_max	节点最大带宽（单位 Mbps）	否	100
-burst	是否启用带宽突发（true 或 false）	否	false
示例
示例 1：基本配置
bash
复制代码
bash install.sh -nic 'ens192' -url 'https://portal.jiasu.ai/modules/addons/PortForward/apicall.php' -key 'your_api_key'
示例 2：完整配置
bash
复制代码
bash install.sh -nic 'ens192' -url 'https://portal.jiasu.ai/modules/addons/PortForward/apicall.php' -key 'your_api_key' -sourceip '192.168.1.1' -magnification 1.0 -node_bw_max 200 -burst true
功能说明
自动化安装
自动检测和安装所需的依赖工具（wget, git, curl, php 等）。
支持不同 Linux 发行版（Debian/Ubuntu/CentOS）的环境适配。
自动从 GitHub 拉取主程序文件。
配置生成
根据命令行传递的参数自动生成配置文件 /usr/local/PortForward/slave/config.php。

服务管理
脚本会自动创建 systemd 服务，用于管理 PortForward 被控程序。

启动服务：

bash
复制代码
systemctl start port_forward
查看服务状态：

bash
复制代码
systemctl status port_forward
停止服务：

bash
复制代码
systemctl stop port_forward


```shell
bash <(curl -L -s https://ghp.ci/https://raw.githubusercontent.com/chiron688/whmcs_portforward_backend/main/install.sh) \
    -nic 'ens192' \
    -url 'https://www.demo.com/modules/addons/PortForward/apicall.php' \
    -key 'your_api_key' \
    -sourceip '192.168.1.1' \
    -magnification 0.5 \
    -node_bw_max 100 \
    -burst false
```

# 参数说明

| 参数              | 描述                                                         | 是否必填 | 默认值       |
|------------------|--------------------------------------------------------------|----------|--------------|
| `-nic`          | 主网卡名称，用于网络通信                                      | 是       | 无           |
| `-url`          | WHMCS 接口地址（如 `https://your-whmcs-site/apicall.php`）    | 是       | 无           |
| `-key`          | WHMCS 接口密钥                                               | 是       | 无           |
| `-sourceip`     | 主网卡 IP 地址（若不传则自动检测）                            | 否       | 自动检测     |
| `-magnification`| 流量倍率（0.5倍为单向计费，1为双向计费）                                                     | 否       | 0.5          |
| `-node_bw_max`  | 节点最大带宽（单位 Mbps）                                     | 否       | 100          |
| `-burst`        | 是否启用带宽突发（`true` 或 `false`）                        | 否       | false        |

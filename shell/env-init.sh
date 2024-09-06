#!/bin/bash

# 环境初始化
# 定义变量，用于标识是否需要配置docker代理
USE_DOCKER_PROXY="false"
DOCKER_PROXY="http://192.168.124.7:7890/"
echo "Docker proxy is set to $DOCKER_PROXY"

echo "========== 安装git =========="
# 1. 安装git
yum install -y git

echo "========== 安装docker =========="
# 2. 安装docker
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
sudo yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 3. 如果需要配置docker代理地址
# 判断是否需要docker代理
if [ "$USE_DOCKER_PROXY" = "true" ]; then
  echo "========== 配置docker代理 =========="
  # 设置docker代理
  sudo mkdir -p /etc/systemd/system/docker.service.d
  sudo tee /etc/systemd/system/docker.service.d/http-proxy.conf <<-EOF
[Service]
Environment="HTTP_PROXY=${DOCKER_PROXY}" "HTTPS_PROXY=${DOCKER_PROXY}" "NO_PROXY=localhost,127.0.0.1,::1,/var/run/docker.sock"
EOF
fi

echo "========== 启动docker =========="
# 4. 启动docker服务
sudo systemctl daemon-reload
sudo systemctl restart docker

echo "========== 配置docker开机自启 =========="
# 设置docker开机自启
sudo systemctl enable docker.service
sudo systemctl enable containerd.service

echo "========== deploy依赖初始环境完成 =========="

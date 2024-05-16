#!/bin/bash
# 引用环境变量
source ./common.env
# 检查 Docker 网络是否存在
function common_check_docker_network {
  # 检查网络是否存在
  if docker network ls --format '{{.Name}}' | grep -q "^${ENV_DOCKER_NETWORK_NAME}$"; then
    echo "检查 Docker 网络 ${ENV_DOCKER_NETWORK_NAME} 已存在"
  else
    # 创建网络
    echo "Docker 网络不存在，创建 ${ENV_DOCKER_NETWORK_NAME}"
    docker network create "${ENV_DOCKER_NETWORK_NAME}"
  fi
}


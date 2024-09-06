#!/bin/bash

set -e # 如果命令失败，则立即退出

PROJECT_NAME="energy-api"
PORT=9991                # 服务端口
PROFILE_ACTIVE="prod" # java -jar -Dspring.profiles.active=dev java部署环境

ENV_ROOT_DIR="/home"
ENV_APP_DIR="app"
LOG_DIR="${ENV_ROOT_DIR}/${ENV_APP_DIR}/${PROJECT_NAME}/logs"

ACR_URL=registry.cn-beijing.aliyuncs.com
IMAGE_URL="$ACR_URL/你的命名空间/${PROJECT_NAME}"
ACR_USERNAME="你的ACR账户"
ACR_PWD="你的ACR密码"

# 检查是否提供了版本号参数
if [ -z "$1" ]; then
  echo "Error: No version specified."
  echo "Usage: $0 <version>"
  exit 1
fi

VERSION="$1" # 镜像版本号

main() {
  local start_time=$(date +%s)

  echo "====================  登陆 acr ===================="
  docker login --username="$ACR_USERNAME" -p="$ACR_PWD" "$ACR_URL"
  echo "====================  拉取制品 ===================="
  docker pull ${IMAGE_URL}:${VERSION}

  echo "==================== 停止旧应用容器 ===================="
  docker stop "$PROJECT_NAME" || true
  docker rm "$PROJECT_NAME" || true

  docker image prune -f
  docker builder prune -f

  echo "==================== 启动新应用容器 ===================="
  docker run -itd \
    --name "$PROJECT_NAME" \
    --restart always \
    -p "$PORT":"$PORT" \
    -v "$LOG_DIR":/logs \
    -e "SPRING_PROFILES_ACTIVE=$PROFILE_ACTIVE" \
    "$IMAGE_URL:$VERSION"

  local end_time=$(date +%s)
  local duration=$((end_time - start_time))
  echo "==================== 整体执行耗时为: ${duration} 秒===================="

  echo "==================== 查看日志 ===================="
  docker logs  "$PROJECT_NAME"
}

# 执行主函数
main "$@"

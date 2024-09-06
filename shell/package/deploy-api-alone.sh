#!/bin/bash
# 以下脚本使用了 阿里云 ACR 作为私有镜像仓库

set -e # 如果命令失败，则立即退出

ENV_ROOT_DIR="/home"
ENV_APP_DIR="app"
ENV_DOWNLOAD_DIR="download"
ENV_DOCKER_SH="deploy-api-docker.sh" # 应用机器docker脚本

ENV_GIT_USERNAME="你的git账户"
ENV_GIT_PASSWORD="你的账户密码"
ENV_GIT_HOST="你的git仓库host"
ENV_GIT_PROTOCOL="https"
GIT_PATH="你的仓库地址"

BRANCH_NAME="main" #分支名
PROJECT_NAME="sz-service-admin"
VERSION="latest"         # 镜像版本号
# 根磁盘路径
APP_TMP_PATH="${ENV_ROOT_DIR}/${ENV_DOWNLOAD_DIR}/${PROJECT_NAME}" #项目下载路径

DEPLOY_VERSION=$(date +%Y%m%d%H%M%S)
APP_POM_PATH="${APP_TMP_PATH}/${DEPLOY_VERSION}"
APP_TARGET_PATH="${APP_POM_PATH}/sz-service/sz-service-admin/target"
APP_CONFIG_PATH="${APP_POM_PATH}/sz-service/sz-service-admin/src/main/resources/config" # 子级配置文件目录
DEPLOY_DIR="${ENV_ROOT_DIR}/${ENV_APP_DIR}/${PROJECT_NAME}/${DEPLOY_VERSION}"           # 部署文件备份地址

PROJECT_REPO="${ENV_GIT_PROTOCOL}://${ENV_GIT_USERNAME}:${ENV_GIT_PASSWORD}@${ENV_GIT_HOST}/${GIT_PATH}" # git clone 地址
USE_ENV_CONFIG=true                                               # 是否使用环境变量配置文件
CONFIG_DIR="${ENV_ROOT_DIR}/${ENV_CONF_DIR}/${PROJECT_NAME}"      # 环境变量配置文件目录

REMOTE_USER="root"       # 应用机的用户名
REMOTE_HOST="你的应用机器IP" # 应用机的主机名或IP地址
IMAGE_URL="registry.cn-beijing.aliyuncs.com/xxxx/xxxx"  # 阿里ACR镜像仓库地址
ACR_USERNAME="你的ACR账户" # ACR账户
ACR_PWD="你的ACR密码" # ACR固定密码

main() {
  local start_time=$(date +%s)
  echo "========== 正在拉取项目代码 =========="
  mkdir -p "$APP_TMP_PATH"
  cd "$APP_TMP_PATH" || exit

  git clone -b "$BRANCH_NAME" "$PROJECT_REPO" "$DEPLOY_VERSION"
  cd "$APP_POM_PATH" || exit

  # 如果使用环境变量配置文件
  if [ "$USE_ENV_CONFIG" = "true" ]; then
    mkdir -p "${CONFIG_DIR}"
    echo "========== 替换环境变量配置文件 =========="
    if [ -n "$(ls -A "${CONFIG_DIR}")" ]; then
      cp -rf "${CONFIG_DIR}"/* "${APP_CONFIG_PATH}"
    else
      echo "${CONFIG_DIR} 目录为空，跳过复制操作"
    fi
  fi

  mkdir -p "${DEPLOY_DIR}"
  # 移动Dockerfile到部署目录
  mv Dockerfile "${DEPLOY_DIR}"

  echo "========== 拉取完成，开始打包 =========="
  docker run --rm \
    --name "$PROJECT_NAME"-maven \
    -v "${APP_POM_PATH}":/app \
    -v "${ENV_PUBLIC_MAVEN_REPOSITORY}/${PROJECT_NAME}":/custom-maven-repo \
    maven:3.9.6 \
    mvn -f /app clean package -Dmaven.repo.local=/custom-maven-repo -Dmaven.test.skip=true
  # 移动jar包到部署目录
  mv "${APP_TARGET_PATH}"/*.jar "${DEPLOY_DIR}"
  # 删除源代码文件
  rm -rf "$APP_POM_PATH"

  echo "========== 打包完成 =========="
  # 切换到Dockerfile目录
  cd "$DEPLOY_DIR" || exit

  echo "====================  删除旧镜像 ===================="
  docker image prune -f
  docker builder prune -f

  echo "==================== 构建 Docker 镜像 ===================="
  docker build -t "$PROJECT_NAME:${VERSION}" "$DEPLOY_DIR"

  echo "==================== 上传 Image 到制品库 ===================="
  docker login --username="$ACR_USERNAME" -p="$ACR_PWD"  registry.cn-beijing.aliyuncs.com
  docker tag "$PROJECT_NAME:${VERSION}" ${IMAGE_URL}:"${VERSION}"
  echo "==================== Image 推送 ===================="
  docker push ${IMAGE_URL}:"${VERSION}"

  echo "==================== 登陆应用机 ===================="
  # 提示用户输入密码
  read -s -p "Enter password for $REMOTE_USER@$REMOTE_HOST: " REMOTE_PASS
  echo

  echo "==================== 应用机拉取镜像 ===================="
  # 确保环境变量 IMAGE_URL 和 VERSION 已经设置
  if [ -z "$IMAGE_URL" ] || [ -z "$VERSION" ]; then
    echo "Error: IMAGE_URL or VERSION is not set."
    exit 1
  fi

  sshpass -p "$REMOTE_PASS" ssh -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_HOST" "bash /home/deploy/$ENV_DOCKER_SH $VERSION"
  local end_time=$(date +%s)
  local duration=$((end_time - start_time))
  echo "==================== 整体执行耗时为: ${duration} 秒===================="
}

# 执行主函数
main "$@"

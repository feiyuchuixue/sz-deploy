#!/bin/bash
# 以下脚本使用 打包机和 应用机模式，此脚本在打包机中运行。
# 引用公共函数和变量
set -e # 如果命令失败，则立即退出

ENV_ROOT_DIR="/home"
ENV_APP_DIR="app"
ENV_DOWNLOAD_DIR="download"

ENV_GIT_USERNAME="你的git账户"
ENV_GIT_PASSWORD="你的git密码"
ENV_GIT_HOST="你的git地址host" # 如gitee.com
ENV_GIT_PROTOCOL="https"
GIT_PATH="你的仓库地址" # 如feiyuchuixue/sz-admin.git

# 定义变量
BRANCH_NAME="main"      # 分支名
PROJECT_NAME="sz-admin" # 项目名称

PROJECT_REPO="${ENV_GIT_PROTOCOL}://${ENV_GIT_USERNAME}:${ENV_GIT_PASSWORD}@${ENV_GIT_HOST}/${GIT_PATH}" # git clone 地址

APP_TMP_PATH="${ENV_ROOT_DIR}/${ENV_DOWNLOAD_DIR}/${PROJECT_NAME}"                     # 项目下载路径
DEPLOY_VERSION=$(date +%Y%m%d%H%M%S)                                                   # 部署版本号
APP_PACKAGE_JSON_PATH="${APP_TMP_PATH}/${DEPLOY_VERSION}"                              # 项目package.json路径
PUBLIC_NODE_MODULES_REPOSITORY="${ENV_PUBLIC_NODE_MODULES_REPOSITORY}/${PROJECT_NAME}" # 挂载node_modules地址
DEPLOY_DIR="${ENV_ROOT_DIR}/${ENV_APP_DIR}/${PROJECT_NAME}/${DEPLOY_VERSION}"          # 部署文件备份地址

USE_ENV_CONFIG="true"
CONFIG_DIR="${ENV_ROOT_DIR}/${ENV_CONF_DIR}/${PROJECT_NAME}" # 环境变量配置文件目录
BUILD_DIR="/home/build/${PROJECT_NAME}" # build后的输出地址
BUILD_BACK_DIR="/home/build/${PROJECT_NAME}/back" # 历史版本记录

PACKAGE_FILE="dist.zip"
REMOTE_USER="root" # 应用机的用户名
REMOTE_HOST="你的主机IP" # 应用机的主机名或IP地址
REMOTE_DIR="/home/tmp" # 应用机上的目标目录
TARGET_DIR="/home/app/nginx/static" # 应用机上的目标目录

# 主执行函数
main() {
  local start_time=$(date +%s)
  # 拉取项目代码
  echo "========== 正在拉取项目代码 =========="
  mkdir -p "$APP_TMP_PATH"
  cd "$APP_TMP_PATH" || exit
  git clone -b "$BRANCH_NAME" "$PROJECT_REPO" "$DEPLOY_VERSION"
  cd "$DEPLOY_VERSION" || exit

    # 如果使用环境变量配置文件
  if [ "$USE_ENV_CONFIG" = "true" ]; then
    mkdir -p "${CONFIG_DIR}"
    echo "========== 替换环境变量配置文件 =========="
    if [ -n "$(ls -A "${CONFIG_DIR}")" ]; then
      cp -rf "${CONFIG_DIR}/.env.production" "${APP_PACKAGE_JSON_PATH}"
    else
      echo "${CONFIG_DIR} 目录为空，跳过复制操作"
    fi
  fi

  mkdir -p "$DEPLOY_DIR"
  mv ./nginx "$DEPLOY_DIR"

  echo "========== 拉取完成，开始打包 =========="
  # 构建项目
  #  npm加速有两种方式：
  # 1. 使用国内镜像源  npm config set registry https://registry.npmmirror.com/
  # 2. 使用代理加速 npm config set proxy http://192.168.1.1:xxxx
  docker run --rm \
    --name "$PROJECT_NAME"-node \
    -v "${APP_PACKAGE_JSON_PATH}":/app \
    -v "${PUBLIC_NODE_MODULES_REPOSITORY}":/app/node_modules \
    -w /app \
    node:21 \
    sh -c "npm config set registry https://registry.npmmirror.com/ && npm install -g pnpm && pnpm install && pnpm run build"
  echo "========== 打包完成 =========="
  ls -l
  pwd
  mkdir -p "$BUILD_DIR"
  rm -rf "$BUILD_DIR/dist"
  mkdir -p "$BUILD_BACK_DIR/$DEPLOY_VERSION"
  cp -rf "${APP_PACKAGE_JSON_PATH}/dist" "$BUILD_BACK_DIR/$DEPLOY_VERSION"
  # 移动dist目录到部署目录
  mv "${APP_PACKAGE_JSON_PATH}/dist" "$BUILD_DIR"
  echo "=============压缩================"
  cd "$BUILD_DIR"
  zip -r dist.zip "./dist" > /dev/null

  # 提示用户输入密码
  read -s -p "Enter password for $REMOTE_USER@$REMOTE_HOST: " REMOTE_PASS
  echo

  # 将文件传输到应用机
  echo "Transferring package to remote host..."
  sshpass -p "$REMOTE_PASS" scp "$PACKAGE_FILE" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR"

  # 在应用机上解压文件，并将文件复制到目标目录
  echo "Cleaning up target directory on remote host..."
  sshpass -p "$REMOTE_PASS" ssh "$REMOTE_USER@$REMOTE_HOST" "rm -rf $TARGET_DIR/$PROJECT_NAME"

  echo "Extracting package on remote host..."
  sshpass -p "$REMOTE_PASS" ssh "$REMOTE_USER@$REMOTE_HOST" "unzip -o $REMOTE_DIR/$PACKAGE_FILE -d $REMOTE_DIR > /dev/null"

  echo "Copying extracted files to target directory..."
  sshpass -p "$REMOTE_PASS" ssh "$REMOTE_USER@$REMOTE_HOST" "mv $REMOTE_DIR/dist $TARGET_DIR/$PROJECT_NAME"

  # 可选：删除应用机上的压缩包
  echo "Cleaning up..."
  sshpass -p "$REMOTE_PASS" ssh "$REMOTE_USER@$REMOTE_HOST" "rm $REMOTE_DIR/$PACKAGE_FILE"

  echo "Deployment complete!"

  echo "========== 清理 =========="
  # 删除源代码文件
  rm -rf "$APP_PACKAGE_JSON_PATH"

  local end_time=$(date +%s)
  local duration=$((end_time - start_time))
  echo "==================== 整体执行耗时为: ${duration} 秒===================="

}

# 执行主函数
main "$@"

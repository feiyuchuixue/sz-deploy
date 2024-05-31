#!/bin/bash

# 引用公共函数和变量
source ./common.sh

set -e # 如果命令失败，则立即退出

BRANCH_NAME="main" #分支名
PROJECT_NAME="sz-service-websocket"
PORT=9993                # 服务端口
PROFILE_ACTIVE="preview" # java -jar -Dspring.profiles.active=dev java部署环境
# 根磁盘路径
APP_TMP_PATH="${ENV_ROOT_DIR}/${ENV_DOWNLOAD_DIR}/${PROJECT_NAME}" #项目下载路径

DEPLOY_VERSION=$(date +%Y%m%d%H%M%S)
APP_POM_PATH="${APP_TMP_PATH}/${DEPLOY_VERSION}"
APP_TARGET_PATH="${APP_POM_PATH}/sz-service/sz-service-websocket/target"
APP_CONFIG_PATH="${APP_POM_PATH}/sz-service/sz-service-websocket/src/main/resources/config" # 子级配置文件目录
DEPLOY_DIR="${ENV_ROOT_DIR}/${ENV_APP_DIR}/${PROJECT_NAME}/${DEPLOY_VERSION}"           # 部署文件备份地址
LOG_DIR="${ENV_ROOT_DIR}/${ENV_APP_DIR}/${PROJECT_NAME}/logs"

USE_GIT_SSH=true                                                                                         # 是否使用git（github） ssh
GIT_PATH="dev/sz-boot-parent.git"                                                                        # git项目路径
GIT_PATH_SSH="feiyuchuixue/sz-boot-parent.git"                                                           # git项目路径
PROJECT_REPO="${ENV_GIT_PROTOCOL}://${ENV_GIT_USERNAME}:${ENV_GIT_PASSWORD}@${ENV_GIT_HOST}/${GIT_PATH}" # git clone 地址
PROJECT_REPO_SSH="git@${ENV_GIT_HOST_SSH}:$GIT_PATH_SSH"

USE_ENV_CONFIG=true                                          # 是否使用环境变量配置文件
CONFIG_DIR="${ENV_ROOT_DIR}/${ENV_CONF_DIR}/${PROJECT_NAME}" # 环境变量配置文件目录
main() {
  local start_time=$(date +%s)
  echo "========== 正在拉取项目代码 =========="
  mkdir -p "$APP_TMP_PATH"
  cd "$APP_TMP_PATH" || exit

  # 如果使用github ssh clone 需要设置认证密钥。这里设置的认证密钥目录在~/.ssh/id_rsa下
  if [ "$USE_GIT_SSH" = "true" ]; then
    git config --global core.sshCommand "ssh -i ~/.ssh/id_rsa"
    # 将PROJECT_REPO_SSH 的值赋值给  PROJECT_REPO
    PROJECT_REPO="$PROJECT_REPO_SSH"
  fi
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
  docker build -t "$PROJECT_NAME" "$DEPLOY_DIR"

  echo "==================== 停止旧应用容器 ===================="
  docker stop "$PROJECT_NAME" || true
  docker rm "$PROJECT_NAME" || true

  echo "==================== 启动新应用容器 ===================="
  docker run -itd \
    --name "$PROJECT_NAME" \
    --restart always \
    -p "$PORT":"$PORT" \
    -v "$LOG_DIR":/logs \
    -e "SPRING_PROFILES_ACTIVE=$PROFILE_ACTIVE" \
    "$PROJECT_NAME"
  # 检查Docker网络
  common_check_docker_network
  # 连接Docker网络
  docker network connect "$ENV_DOCKER_NETWORK_NAME" "$PROJECT_NAME"
  local end_time=$(date +%s)
  local duration=$((end_time - start_time))
  echo "==================== 整体执行耗时为: ${duration} 秒===================="

  echo "==================== 查看日志 ===================="
  docker logs -f "$PROJECT_NAME"
}

# 执行主函数
main "$@"

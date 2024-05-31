#!/bin/bash
# 引用公共函数和变量
source ./common.sh
set -e # 如果命令失败，则立即退出

# 定义变量
BRANCH_NAME="main"      # 分支名
PROJECT_NAME="sz-admin" # 项目名称

USE_GIT_SSH=true                                                                                         # 是否使用Git SSH
GIT_PATH="feiyuchuixue/sz-admin.git"                                                                              # git项目路径
GIT_PATH_SSH="feiyuchuixue/sz-admin.git"                                                                 # git项目路径                                                                                       # 是否使用git（github） ssh
PROJECT_REPO="${ENV_GIT_PROTOCOL}://${ENV_GIT_USERNAME}:${ENV_GIT_PASSWORD}@${ENV_GIT_HOST}/${GIT_PATH}" # git clone 地址
PROJECT_REPO_SSH="git@${ENV_GIT_HOST_SSH}:$GIT_PATH_SSH"

USE_NPM_PROXY=true                                           # 是否使用npm镜像代理
NPM_CONFIG_REGISTRY="https://mirrors.cloud.tencent.com/npm/" # npm镜像加速地址

APP_TMP_PATH="${ENV_ROOT_DIR}/${ENV_DOWNLOAD_DIR}/${PROJECT_NAME}"                     # 项目下载路径
DEPLOY_VERSION=$(date +%Y%m%d%H%M%S)                                                   # 部署版本号
APP_PACKAGE_JSON_PATH="${APP_TMP_PATH}/${DEPLOY_VERSION}"                              # 项目package.json路径
PUBLIC_NODE_MODULES_REPOSITORY="${ENV_PUBLIC_NODE_MODULES_REPOSITORY}/${PROJECT_NAME}" # 挂载node_modules地址
DEPLOY_DIR="${ENV_ROOT_DIR}/${ENV_APP_DIR}/${PROJECT_NAME}/${DEPLOY_VERSION}"          # 部署文件备份地址

# 主执行函数
main() {
  local start_time=$(date +%s)
  # 拉取项目代码
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
  cd "$DEPLOY_VERSION" || exit
  mkdir -p "$DEPLOY_DIR"
  mv ./nginx "$DEPLOY_DIR"

  echo "========== 拉取完成，开始打包 =========="
  # 检查环境变量USE_NPM_PROXY的值
  if [ "$USE_NPM_PROXY" == "true" ]; then
    # 如果USE_NPM_PROXY为true，则使用npm代理
    local proxy_arg="-e NPM_CONFIG_REGISTRY=${NPM_CONFIG_REGISTRY}"
  else
    # 如果USE_NPM_PROXY不为true，则不使用npm代理
    local proxy_arg=""
  fi
  # 构建项目
  docker run --rm \
    --name "$PROJECT_NAME"-node \
    "$proxy_arg" \
    -v "${APP_PACKAGE_JSON_PATH}":/app \
    -v "${PUBLIC_NODE_MODULES_REPOSITORY}":/app/node_modules \
    -w /app \
    node:21 \
    sh -c "npm install -g pnpm && pnpm install && pnpm run build"
  echo "========== 打包完成 =========="
  ls -l
  pwd
  # 移动dist目录到部署目录
  mv "${APP_PACKAGE_JSON_PATH}/dist" "$DEPLOY_DIR"
  cd "$DEPLOY_DIR"
  echo "DEPLOY_DIR == $DEPLOY_DIR"
  ls -l
  mkdir -p "$ENV_NGINX_STATIC_DIR/$PROJECT_NAME"
  rm -rf "$ENV_NGINX_STATIC_DIR/$PROJECT_NAME"          # 删除之前的静态资源路径
  cp -rf "./dist" "$ENV_NGINX_STATIC_DIR/$PROJECT_NAME" # 复制静态资源到nginx路径下

  mkdir -p "$ENV_NGINX_CNF_DIR"
  find "./nginx" -type f -name "*.conf" -exec cp -f {} "$ENV_NGINX_CNF_DIR"/ \;

  echo "========== 清理 =========="
  # 删除源代码文件
  rm -rf "$APP_PACKAGE_JSON_PATH"

  local end_time=$(date +%s)
  local duration=$((end_time - start_time))
  echo "==================== 整体执行耗时为: ${duration} 秒===================="

  # 查看新应用容器的日志
  echo "==================== 查看日志 ===================="
  tail -f "$ENV_NGINX_LOG_DIR/default.access.log"
  echo "==================== 部署完成 ===================="
}

# 执行主函数
main "$@"

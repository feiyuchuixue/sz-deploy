#!/bin/bash
# 引用公共函数和变量
source ./common.sh
set -e # 如果命令失败，则立即退出

# 映射端口变量
PORT_MAPPINGS=(
  "9800:9800"
  "80:80"
  "443:443"
)

PROJECT_NAME="nginx"                            # 项目名称
USE_ENV_CONFIG=true                                          # 是否使用环境变量配置文件
CONFIG_DIR="${ENV_ROOT_DIR}/${ENV_CONF_DIR}/${PROJECT_NAME}" # 环境变量配置文件目录

# 平滑重载NGINX配置
reload_nginx() {
  echo "==================== 平滑重载NGINX配置 ===================="
  docker exec "$PROJECT_NAME" nginx -s reload
}

# 获取NGINX容器的状态
get_container_status() {
  docker inspect -f '{{.State.Running}}' "$PROJECT_NAME" 2>/dev/null || echo "false"
}

run_nginx() {
  echo "==================== 启动新应用容器 ===================="
  docker run -itd \
    --name "$PROJECT_NAME" \
    --restart always \
    $(printf -- ' -p %s' "${PORT_MAPPINGS[@]}") \
    -e TZ=Asia/Shanghai \
    -v "${ENV_NGINX_LOG_DIR}":/var/log/nginx \
    -v "${ENV_NGINX_STATIC_DIR}":/usr/share/nginx \
    -v "${ENV_NGINX_CNF_DIR}":/etc/nginx/conf.d \
    -v "${ENV_NGINX_CERT_DIR}":/etc/nginx/cert \
    nginx:1.25.4

  echo "==================== 加入网络 ===================="
  # 加入网络
  docker network connect "$ENV_DOCKER_NETWORK_NAME" "$PROJECT_NAME"
}

# 检查并删除同名容器
check_and_remove_duplicate_container() {
  local duplicate_container_id
  duplicate_container_id=$(docker ps -aqf "name=$PROJECT_NAME")
  if [ -n "$duplicate_container_id" ]; then
    echo "发现同名容器 $PROJECT_NAME，删除中..."
    docker stop "$PROJECT_NAME" >/dev/null
    docker rm "$PROJECT_NAME" >/dev/null
    echo "同名容器 $PROJECT_NAME 已删除"
  fi
}

ask_restart_container() {
  # 交互式询问用户是否认为端口发生了改变
  read -p "是否需要重启容器？(y/n): " answer
  case "$answer" in
  [Yy]*)
    echo "重新启动容器"
    check_and_remove_duplicate_container
    run_nginx
    ;;
  [Nn]*)
    echo "不执行任何操作"
    ;;
  *)
    echo "无效输入，请输入 y 或 n"
    ;;
  esac
}

check_use_env_config() {
    # 如果使用环境变量配置文件
  if [ "$USE_ENV_CONFIG" = "true" ]; then
    mkdir -p "${CONFIG_DIR}"
    echo "========== 替换环境变量配置文件 =========="
    cp -rf "${CONFIG_DIR}"/* "${ENV_NGINX_CNF_DIR}"
  fi
}

# 如果NGINX容器不存在或者处于非运行状态，执行初始化操作
if [ "$(get_container_status)" != "true" ]; then
  mkdir -p "$NGINX_LOG_DIR"
  mkdir -p "$NGINX_STATIC_DIR"
  mkdir -p "$NGINX_CNF_DIR"
  mkdir -p "$NGINX_CERT_DIR"

  echo "NGINX容器不存在或者处于非运行状态，执行初始化操作"
  echo "====================  删除旧镜像 ===================="
  docker image prune -f

  check_and_remove_duplicate_container
  check_use_env_config
  run_nginx
  echo "==================== 打印nginx日志 ===================="
  docker logs -f "$PROJECT_NAME"

else
  echo "NGINX容器存在且处于运行状态"
  echo "NGINX平滑重载"
  check_use_env_config
  reload_nginx
  ask_restart_container
fi

echo "部署完成"

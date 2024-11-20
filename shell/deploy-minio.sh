#!/bin/bash

# 引用公共函数和变量
source ./common.sh
set -e # 如果命令失败，则立即退出

TZ="Asia/Shanghai" # 时区

PROJECT_NAME="minio"           # 项目名称
ROOT_USER="用户名"                # minio 用户名1
ROOT_PWD="密码"                  # minio 密码
DATA_DIR="/mnt/minio/data"     # minio文件存储磁盘
CONFIG_DIR="/mnt/minio/config" # minio配置路径

WEB_PORT="9000"                                # minio API
SERVER_PORT="9001"                             # minio控制台
MINIO_DOMAIN="https://your.domain.com"         # minio API域名
MINIO_DOMAIN_BROWSER="https://your.domain.com" # minio 域名

echo "========== 更新服务器时间 =========="
# 1. 更新服务器时间
# 更新时区
yum -y install ntpdate
# 向阿里云服务器同步时间
ntpdate time1.aliyun.com
# 删除本地时间并设置时区为上海
rm -rf /etc/localtime
ln -s /usr/share/zoneinfo/"$TZ" /etc/localtime
echo "========== 当前服务器时间 =========="
# 查看时间
date -R || date

echo "========== 创建磁盘映射文件夹 =========="
# 2. 创建磁盘映射文件夹
mkdir -p "$DATA_DIR"
mkdir -p "$CONFIG_DIR"

echo "========== 下载minio =========="
# 3. docker 下载 minio
docker pull minio/minio

echo "========== 运行minio =========="
# 4. 运行minio镜像，设置账户密码，映射
docker run -d \
  --name $PROJECT_NAME \
  -p "$WEB_PORT":"$WEB_PORT" \
  -p "$SERVER_PORT":"$SERVER_PORT" \
  --privileged=true \
  -e "MINIO_ROOT_USER=$ROOT_USER" \
  -e "MINIO_ROOT_PASSWORD=$ROOT_PWD" \
  -e "MINIO_SERVER_URL=$MINIO_DOMAIN" \
  -e "MINIO_BROWSER_REDIRECT_URL=$MINIO_DOMAIN_BROWSER" \
  -e "TZ=$TZ" \
  -v "$DATA_DIR":/data \
  -v "$CONFIG_DIR":/root/.minio \
  minio/minio server \
  --console-address ":$SERVER_PORT" \
  --address ":$WEB_PORT" /data

echo "========== 加入minio网络 =========="
# 检查Docker网络
common_check_docker_network
# 连接Docker网络
docker network connect "$ENV_DOCKER_NETWORK_NAME" "$PROJECT_NAME"
echo "========== minio 日志 =========="
docker logs -f minio

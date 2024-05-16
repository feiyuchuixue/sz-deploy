#!/bin/bash

TZ="Asia/Shanghai" # 时区

PROJECT_NAME=“minio”
ROOT_USER="admin"              # minio 用户名
ROOT_PWD="Szadmin123"          # minio 密码
DATA_DIR="/mnt/minio/data"     # minio文件存储磁盘
CONFIG_DIR="/mnt/minio/config" # minio配置路径

WEB_PORT="9000"    # minio控制台
SERVER_PORT="9001" # minio API

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
  --name minio \
  -p "$WEB_PORT":"$WEB_PORT" \
  -p "$SERVER_PORT":"$SERVER_PORT" \
  --privileged=true \
  -e "MINIO_ROOT_USER=$ROOT_USER" \
  -e "MINIO_ROOT_PASSWORD=$ROOT_PWD" \
  -e "TZ=$TZ" \
  -v "$DATA_DIR":/data \
  -v "$CONFIG_DIR":/root/.minio \
  minio/minio server \
  --console-address ":$WEB_PORT" \
  --address ":$SERVER_PORT" /data
  # 加入网络
docker network connect sz "$PROJECT_NAME"

docker logs -f minio

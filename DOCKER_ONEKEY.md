# Docker 一键部署

项目根目录新增了一键脚本：`docker-onekey.sh`，会自动完成以下操作：

1. 自动探测本机 IP（也可手动指定）
2. 自动写入 `TangSengDaoDaoServer/docker/tsdd/configs/tsdd.yaml` 的 `external.ip`
3. 自动写入 `TangSengDaoDaoServer/docker/tsdd/configs/wk.yaml` 的 `external.ip`
4. 自动更新 `TangSengDaoDaoServer/docker/tsdd/.env` 中的 `API_URL` 和 MinIO 地址
5. 启动 `docker compose`（默认包含 web profile）
6. Web 服务使用 `TangSengDaoDaoWeb` 进行完整 IM 前端构建

## 快速开始

```bash
chmod +x ./docker-onekey.sh
./docker-onekey.sh up
```

## 常用命令

```bash
# 指定外网/LAN IP
./docker-onekey.sh up --ip 192.168.1.20

# 仅启动后端（不启动 web）
./docker-onekey.sh up --no-web

# 重新拉起（不强制重建镜像）
./docker-onekey.sh restart

# 查看状态
./docker-onekey.sh ps

# 查看日志
./docker-onekey.sh logs
./docker-onekey.sh logs tangsengdaodaoserver

# 停止
./docker-onekey.sh down
```

## 默认端口

```text
8090  TangSengDaoDaoServer API
5100  WuKongIM TCP
5200  WuKongIM WebSocket
5300  WuKongIM Monitor
9000  MinIO API
9001  MinIO Console
82    Web（启用 web profile 时）
```

访问完整 IM Web：

```text
http://你的服务器IP:82
```

## 注意事项

1. 首次 `up` 会构建镜像，耗时取决于网络和机器性能。
2. 如果自动探测 IP 不准确，请使用 `--ip` 指定。
3. 配置与数据目录位于 `TangSengDaoDaoServer/docker/tsdd/`。

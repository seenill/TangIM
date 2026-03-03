#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK_DIR="${ROOT_DIR}/TangSengDaoDaoServer/docker/tsdd"
ENV_FILE="${STACK_DIR}/.env"
TSDD_CONFIG="${STACK_DIR}/configs/tsdd.yaml"
WK_CONFIG="${STACK_DIR}/configs/wk.yaml"

usage() {
  cat <<'EOF'
用法:
  ./docker-onekey.sh [up|restart|down|ps|logs|config] [选项]

命令:
  up        一键部署（默认命令，会构建镜像并启动）
  restart   重新拉起（不强制重建镜像）
  down      停止并删除容器
  ps        查看容器状态
  logs      查看日志，可选服务名：logs tangsengdaodaoserver
  config    渲染并检查 compose 配置

选项:
  --ip, -i <IP>   指定 external.ip（默认自动探测本机IP）
  --no-web        不启动 web profile
  --with-web      启动 web profile（默认）
  --help, -h      显示帮助

示例:
  ./docker-onekey.sh up
  ./docker-onekey.sh up --ip 192.168.1.20
  ./docker-onekey.sh up --no-web
  ./docker-onekey.sh logs tangsengdaodaoserver
EOF
}

ensure_prerequisites() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "未找到 docker，请先安装 Docker Desktop 或 Docker Engine。" >&2
    exit 1
  fi

  if docker compose version >/dev/null 2>&1; then
    return
  fi

  if command -v docker-compose >/dev/null 2>&1; then
    return
  fi

  echo "未找到 docker compose（或 docker-compose）。" >&2
  exit 1
}

compose() {
  if docker compose version >/dev/null 2>&1; then
    (cd "$STACK_DIR" && docker compose "$@")
  else
    (cd "$STACK_DIR" && docker-compose "$@")
  fi
}

detect_local_ip() {
  local ip=""
  local iface=""

  if command -v ip >/dev/null 2>&1; then
    ip="$(ip route get 1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}')"
  fi

  if [ -z "$ip" ] && command -v route >/dev/null 2>&1 && command -v ipconfig >/dev/null 2>&1; then
    iface="$(route -n get default 2>/dev/null | awk '/interface:/{print $2; exit}')"
    if [ -n "$iface" ]; then
      ip="$(ipconfig getifaddr "$iface" 2>/dev/null || true)"
    fi
  fi

  if [ -z "$ip" ] && command -v hostname >/dev/null 2>&1; then
    ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
  fi

  echo "$ip"
}

upsert_env() {
  local key="$1"
  local value="$2"
  local file="$3"
  local tmp
  local found=0

  tmp="$(mktemp)"

  if [ -f "$file" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      if [[ "$line" == "${key}="* ]]; then
        printf '%s=%s\n' "$key" "$value" >>"$tmp"
        found=1
      else
        printf '%s\n' "$line" >>"$tmp"
      fi
    done <"$file"
  fi

  if [ "$found" -eq 0 ]; then
    printf '%s=%s\n' "$key" "$value" >>"$tmp"
  fi

  mv "$tmp" "$file"
}

update_external_ip_in_yaml() {
  local file="$1"
  local external_ip="$2"
  local tmp

  tmp="$(mktemp)"

  awk -v new_ip="$external_ip" '
    BEGIN {
      in_external = 0
      updated = 0
    }
    {
      if ($0 ~ /^[[:space:]]*external:[[:space:]]*(#.*)?$/) {
        in_external = 1
        print
        next
      }

      if (in_external == 1 && $0 ~ /^[[:space:]]*ip:[[:space:]]*"/) {
        sub(/"[^"]*"/, "\"" new_ip "\"")
        updated = 1
        in_external = 0
        print
        next
      }

      if (in_external == 1 && $0 ~ /^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*:[[:space:]]*/) {
        in_external = 0
      }

      print
    }
    END {
      if (updated == 0) {
        exit 2
      }
    }
  ' "$file" >"$tmp" || {
    rm -f "$tmp"
    echo "更新 external.ip 失败: $file" >&2
    exit 1
  }

  mv "$tmp" "$file"
}

prepare_runtime_dirs() {
  mkdir -p \
    "${STACK_DIR}/logs/wk" \
    "${STACK_DIR}/logs/tsdd" \
    "${STACK_DIR}/miniodata" \
    "${STACK_DIR}/mysqldata"
}

start_stack() {
  local with_web="$1"
  local with_build="$2"

  local args=(up -d)
  if [ "$with_build" -eq 1 ]; then
    args+=(--build)
  fi

  if [ "$with_web" -eq 1 ]; then
    compose --profile web "${args[@]}"
  else
    compose "${args[@]}"
  fi
}

ensure_prerequisites

if [ ! -d "$STACK_DIR" ]; then
  echo "未找到部署目录: $STACK_DIR" >&2
  exit 1
fi

if [ ! -f "$TSDD_CONFIG" ] || [ ! -f "$WK_CONFIG" ]; then
  echo "缺少配置文件，请检查: $TSDD_CONFIG 和 $WK_CONFIG" >&2
  exit 1
fi

action="up"
action_set=0
with_web=1
input_ip="${EXTERNAL_IP:-}"
positional=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    up|start|restart|down|ps|status|logs|config)
      if [ "$action_set" -eq 0 ]; then
        action="$1"
        action_set=1
      else
        positional+=("$1")
      fi
      shift
      ;;
    --ip|-i)
      if [ "$#" -lt 2 ]; then
        echo "参数错误: --ip 需要一个IP值" >&2
        exit 1
      fi
      input_ip="$2"
      shift 2
      ;;
    --no-web)
      with_web=0
      shift
      ;;
    --with-web)
      with_web=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      positional+=("$1")
      shift
      ;;
  esac
done

case "$action" in
  up|start|restart)
    external_ip="$input_ip"
    if [ -z "$external_ip" ]; then
      external_ip="$(detect_local_ip)"
    fi

    if [ -z "$external_ip" ]; then
      echo "无法自动探测IP，请使用 --ip 手动指定。" >&2
      exit 1
    fi

    prepare_runtime_dirs

    update_external_ip_in_yaml "$TSDD_CONFIG" "$external_ip"
    update_external_ip_in_yaml "$WK_CONFIG" "$external_ip"

    # TangSengDaoDaoWeb 在容器内通过 nginx 反向代理访问后端服务。
    # 这里必须是 docker 网络内可访问的服务名地址，而不是宿主机 127.0.0.1。
    upsert_env "API_URL" "http://tangsengdaodaoserver:8090/" "$ENV_FILE"
    upsert_env "MINIO_SERVER_URL" "http://${external_ip}:9000" "$ENV_FILE"
    upsert_env "MINIO_BROWSER_REDIRECT_URL" "http://${external_ip}:9001" "$ENV_FILE"

    if [ "$action" = "restart" ]; then
      start_stack "$with_web" 0
    else
      start_stack "$with_web" 1
    fi

    echo ""
    echo "部署完成，访问地址："
    echo "API:     http://${external_ip}:8090"
    echo "WuKong:  tcp://${external_ip}:5100  ws://${external_ip}:5200"
    echo "MinIO:   http://${external_ip}:9001"
    if [ "$with_web" -eq 1 ]; then
      echo "Web:     http://${external_ip}:82"
    fi
    echo ""
    compose ps
    ;;
  down)
    compose down
    ;;
  ps|status)
    compose ps
    ;;
  logs)
    if [ "${#positional[@]}" -gt 0 ]; then
      compose logs -f "${positional[0]}"
    else
      compose logs -f
    fi
    ;;
  config)
    compose config
    ;;
  *)
    echo "不支持的命令: $action" >&2
    usage
    exit 1
    ;;
esac

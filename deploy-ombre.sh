#!/bin/bash
# ============================================
# Ombre Brain 二改版 一键部署脚本
# 仓库：Yinglianchun/Ombre-Brain (Haven/Rain Fork)
# 服务器：腾讯云香港 43.128.46.197
# ============================================
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }

echo "=========================================="
echo "  Ombre Brain 二改版 一键部署"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================="
echo ""

# ---- 1. 检查 Docker ----
if ! command -v docker &>/dev/null; then
    warn "Docker 未安装，开始安装..."
    curl -fsSL https://get.docker.com | sudo sh
    sudo usermod -aG docker $USER
    log "Docker 已安装。如果之前不在 docker 组，请重新登录后再次运行本脚本。"
    if ! groups | grep -q docker; then
        warn "当前用户不在 docker 组，请执行: newgrp docker 或重新登录"
    fi
fi

if ! docker compose version &>/dev/null; then
    err "需要 Docker Compose v2。请升级 Docker。"
fi

log "Docker 环境就绪"

# ---- 2. Clone 仓库 ----
REPO_DIR="/opt/Ombre-Brain"
if [ -d "$REPO_DIR/.git" ]; then
    log "仓库已存在，更新..."
    cd "$REPO_DIR"
    git pull --ff-only origin main
else
    log "克隆仓库..."
    sudo mkdir -p "$REPO_DIR"
    sudo chown -R $USER:$USER /opt/Ombre-Brain
    git clone https://github.com/Yinglianchun/Ombre-Brain.git "$REPO_DIR"
    cd "$REPO_DIR"
fi

# ---- 3. 创建数据目录 ----
log "创建数据目录..."
sudo mkdir -p /srv/ombre-brain/buckets /srv/ombre-brain/state
sudo chown -R $USER:$USER /srv/ombre-brain

# ---- 4. 生成配置（如果不存在） ----
if [ ! -f /srv/ombre-brain/config.yaml ]; then
    log "生成 config.yaml..."
    cp "$REPO_DIR/config.example.yaml" /srv/ombre-brain/config.yaml

    # 自动填一些默认值
    cat >> /srv/ombre-brain/config.yaml <<'YAML'

# ---- 年年定制（部署后请手动修改） ----
# identity:
#   ai_name: "念安"
#   user_name: "思年"
#   user_display_name: "年年"
#   user_aliases:
#     - "年年"
#     - "思年"
#     - "小朋友"
# gateway:
#   default_session_id: "nianan-main"
#   upstream_base_url: "https://api.deepseek.com/v1"
#   upstream_default_model: "deepseek-chat"
#   upstream_models:
#     - "deepseek-chat"
#     - "deepseek-reasoner"
# reflection:
#   timezone: "Asia/Shanghai"
YAML

    log "config.yaml 已生成 → /srv/ombre-brain/config.yaml"
    warn "请编辑 /srv/ombre-brain/config.yaml 修改 identity 和 gateway 配置！"
else
    log "config.yaml 已存在，跳过"
fi

# ---- 5. 生成 .env（如果不存在） ----
if [ ! -f /opt/Ombre-Brain/.env ]; then
    log "生成 .env 模板..."
    cat > /opt/Ombre-Brain/.env <<'ENV'
# ========== Ombre Brain 二改版 环境变量 ==========
# 生成随机 token: openssl rand -hex 32

# 内部 LLM（脱水/打标）
OMBRE_API_KEY=sk-your-key-here
OMBRE_COMPRESS_BASE_URL=https://api.deepseek.com/v1
OMBRE_COMPRESS_MODEL=deepseek-chat

# Embedding
OMBRE_EMBEDDING_API_KEY=sk-your-key-here
OMBRE_EMBEDDING_BASE_URL=https://api.siliconflow.cn/v1
OMBRE_EMBEDDING_MODEL=BAAI/bge-m3
OMBRE_EMBEDDING_FORMAT=openai_compat

# Gateway 上游模型
OMBRE_GATEWAY_UPSTREAM_API_KEY=sk-your-key-here

# Gateway Token（客户端连接用，自己生成随机值！）
OMBRE_GATEWAY_TOKEN=change-me-to-random-string

# Dashboard 密码
OMBRE_DASHBOARD_PASSWORD=change-me

# 部署
OMBRE_TRANSPORT=streamable-http
ENV

    log ".env 已生成 → /opt/Ombre-Brain/.env"
    warn "请编辑 /opt/Ombre-Brain/.env 填入真实 Key！"
else
    log ".env 已存在，跳过"
fi

# ---- 6. 启动 ----
log "构建并启动容器..."
cd "$REPO_DIR"
docker compose -f compose.hk.yml up -d --build --force-recreate ombre-brain ombre-gateway

# ---- 7. 等待启动 ----
sleep 5

# ---- 8. 验证 ----
echo ""
log "验证服务..."
if curl -sf http://127.0.0.1:18001/health > /dev/null 2>&1; then
    log "ombre-brain :18001 ✓"
else
    warn "ombre-brain :18001 未就绪，查看日志: docker compose -f $REPO_DIR/compose.hk.yml logs ombre-brain"
fi

if curl -sf http://127.0.0.1:18002/health > /dev/null 2>&1; then
    log "ombre-gateway :18002 ✓"
else
    warn "ombre-gateway :18002 未就绪，查看日志: docker compose -f $REPO_DIR/compose.hk.yml logs ombre-gateway"
fi

echo ""
echo "=========================================="
echo "  部署完成！"
echo "=========================================="
echo ""
echo "  Dashboard:  http://43.128.46.197:18001/dashboard"
echo "  MCP:        http://43.128.46.197:18001/mcp"
echo "  Gateway:    http://43.128.46.197:18002/v1"
echo ""
echo "  下一步："
echo "  1. 编辑 config.yaml: nano /srv/ombre-brain/config.yaml"
echo "  2. 编辑 .env:        nano /opt/Ombre-Brain/.env"
echo "  3. 重启:             cd /opt/Ombre-Brain && docker compose -f compose.hk.yml restart"
echo "  4. 打开 Dashboard 设置密码"
echo ""
echo "  常用命令："
echo "  看日志:  docker compose -f /opt/Ombre-Brain/compose.hk.yml logs -f"
echo "  重启:    docker compose -f /opt/Ombre-Brain/compose.hk.yml restart"
echo "  更新:    cd /opt/Ombre-Brain && git pull && docker compose -f compose.hk.yml up -d --build"
echo ""

#!/bin/bash
set -euo pipefail

# ============================================================
# Flash Card 项目部署脚本
# 用途：代码审查通过后，自动部署前后端到树莓派，并构建 APK
# 运行环境：Bash (Git Bash / WSL / Linux / macOS)
# ============================================================

# ---------- 配置区（请根据你的环境修改） ----------
RPI_HOST="rpi"                           # ~/.ssh/config 中的 Host 别名
RPI_BACKEND_DIR="/home/joe/flash-card-backend"
RPI_FRONTEND_DIR="/home/joe/flash-card-web"
SYSTEMD_SERVICE="flashcard-api.service"
WEB_SERVICE="flashcard-web.service"
PYTHON_VENV="$RPI_BACKEND_DIR/venv"
BACKEND_PORT="8887"
HEALTH_CHECK_URL="http://192.168.3.11:$BACKEND_PORT/docs"
# 修复 .ssh/config 中 RemoteCommand/RequestTTY 与非交互式命令冲突
SSH_OPTS="-o RemoteCommand=none -o RequestTTY=no"
# --------------------------------------------------

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ---------- 1. Git 检查 ----------
check_git() {
    info "检查 Git 仓库状态..."

    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        error "当前目录不是 Git 仓库。请先运行：git init && git remote add origin <你的仓库地址>"
    fi

    local branch
    branch=$(git symbolic-ref --short HEAD)
    if [[ "$branch" != "main" ]]; then
        error "当前不在 main 分支（当前: $branch）。请切换到 main 分支后再部署。"
    fi

    if ! git diff-index --quiet HEAD --; then
        error "工作区有未提交的修改，请先提交或暂存。"
    fi

    # 获取本地和远程的提交哈希
    local local_hash remote_hash
    local_hash=$(git rev-parse main)
    remote_hash=$(git rev-parse origin/main 2>/dev/null || echo "")

    if [[ -z "$remote_hash" ]]; then
        warn "未检测到远程仓库 origin/main，跳过远程同步检查。"
    elif [[ "$local_hash" != "$remote_hash" ]]; then
        error "本地 main 分支与远程不同步。请先 push：git push origin main"
    fi

    ok "Git 检查通过（main 分支，工作区干净，已同步远程）"
}

# ---------- 2. 测试 ----------
run_backend_tests() {
    info "运行后端测试..."
    cd backend

    # 优先使用 venv 中的 Python（兼容 Windows Git Bash）
    local py_cmd="python"
    if [ -f "venv/Scripts/python.exe" ]; then
        py_cmd="venv/Scripts/python.exe"
    elif [ -f ".venv/Scripts/python.exe" ]; then
        py_cmd=".venv/Scripts/python.exe"
    elif [ -f "venv/bin/python" ]; then
        py_cmd="venv/bin/python"
    elif [ -f ".venv/bin/python" ]; then
        py_cmd=".venv/bin/python"
    fi

    if [ -f "requirements.txt" ]; then
        if ! $py_cmd -m pytest --version > /dev/null 2>&1; then
            warn "本地未安装 pytest，尝试安装..."
            $py_cmd -m pip install pytest pytest-asyncio > /dev/null 2>&1 || error "安装 pytest 失败"
        fi
        $py_cmd -m pytest -q || error "后端测试失败"
    else
        warn "backend/requirements.txt 不存在，跳过后端测试"
    fi
    cd ..
    ok "后端测试通过"
}

run_mobile_tests() {
    info "运行移动端测试..."
    cd mobile
    if command -v flutter > /dev/null 2>&1; then
        flutter test || error "移动端测试失败"
    else
        warn "未检测到 flutter 命令，跳过移动端测试"
    fi
    cd ..
    ok "移动端测试通过"
}

# ---------- 3. SSH 连接检查 ----------
check_ssh() {
    info "检查 SSH 连接到树莓派 ($RPI_HOST)..."
    if ! ssh $SSH_OPTS -o ConnectTimeout=5 "$RPI_HOST" "echo OK" > /dev/null 2>&1; then
        error "无法通过 SSH 连接到 $RPI_HOST。请检查：\n  1. 树莓派是否开机且网络通畅\n  2. ~/.ssh/config 配置是否正确\n  3. 私钥是否已加载（Windows 可运行 ssh-add）"
    fi
    ok "SSH 连接正常"
}

# ---------- 4. 后端部署 ----------
deploy_backend() {
    info "部署后端到树莓派..."

    if command -v rsync > /dev/null 2>&1; then
        rsync -avz -e "ssh $SSH_OPTS" \
            --exclude='.venv' \
            --exclude='__pycache__' \
            --exclude='*.pyc' \
            --exclude='.git' \
            --exclude='.env' \
            --exclude='*.db' \
            --exclude='tests/' \
            --delete \
            backend/ "$RPI_HOST:$RPI_BACKEND_DIR/"
    else
        warn "rsync 未安装，使用 tar+ssh 管道作为备选..."
        tar czf - \
            --exclude='.venv' \
            --exclude='__pycache__' \
            --exclude='*.pyc' \
            --exclude='.git' \
            --exclude='.env' \
            --exclude='*.db' \
            --exclude='tests/' \
            -C backend . \
            | ssh $SSH_OPTS "$RPI_HOST" "mkdir -p '$RPI_BACKEND_DIR' && tar xzf - -C '$RPI_BACKEND_DIR'"
    fi

    # 在树莓派上安装依赖并重启服务
    ssh $SSH_OPTS "$RPI_HOST" "
        set -e
        echo '安装 Python 依赖...'
        if [ ! -d '$PYTHON_VENV' ]; then
            echo '虚拟环境不存在，创建中...'
            python3 -m venv '$PYTHON_VENV'
        fi
        source '$PYTHON_VENV/bin/activate'
        pip install --upgrade pip -q
        pip install -r '$RPI_BACKEND_DIR/requirements.txt' -q

        echo '重启服务...'
        sudo systemctl restart $SYSTEMD_SERVICE
        sudo systemctl status $SYSTEMD_SERVICE --no-pager
    "

    # 健康检查
    info "等待服务启动并执行健康检查..."
    local retries=10
    local wait_sec=3
    for i in $(seq 1 $retries); do
        sleep $wait_sec
        if curl -sf "$HEALTH_CHECK_URL" > /dev/null 2>&1; then
            ok "后端服务启动成功 ($HEALTH_CHECK_URL)"
            return 0
        fi
        info "健康检查第 $i/$retries 次重试..."
    done

    error "后端服务健康检查失败，请手动检查：ssh $RPI_HOST 'sudo journalctl -u $SYSTEMD_SERVICE -n 50'"
}

# ---------- 5. 前端部署 ----------
deploy_frontend() {
    info "构建前端..."
    cd web-admin

    if ! command -v npm > /dev/null 2>&1; then
        error "未检测到 npm，请先安装 Node.js"
    fi

    # 安装依赖并构建
    npm ci
    npm run build
    cd ..

    info "部署前端到树莓派..."
    if command -v rsync > /dev/null 2>&1; then
        rsync -avz -e "ssh $SSH_OPTS" --delete web-admin/dist/ "$RPI_HOST:$RPI_FRONTEND_DIR/"
    else
        warn "rsync 未安装，使用 scp 作为备选..."
        ssh $SSH_OPTS "$RPI_HOST" "rm -rf '$RPI_FRONTEND_DIR'/*"
        scp -r -o RemoteCommand=none -o RequestTTY=no web-admin/dist/* "$RPI_HOST:$RPI_FRONTEND_DIR/"
    fi

    # 重启前端服务
    ssh $SSH_OPTS "$RPI_HOST" "sudo systemctl restart $WEB_SERVICE && sudo systemctl status $WEB_SERVICE --no-pager"

    ok "前端部署完成"
}

# ---------- 6. APK 构建 ----------
build_apk() {
    info "构建 APK..."
    cd mobile

    if ! command -v flutter > /dev/null 2>&1; then
        warn "未检测到 flutter 命令，跳过 APK 构建"
        cd ..
        return 0
    fi

    flutter build apk --release

    local apk_path="build/app/outputs/flutter-apk/app-release.apk"
    if [ -f "$apk_path" ]; then
        ok "APK 构建成功"
        echo ""
        echo "  文件路径: $(pwd)/$apk_path"
        ls -lh "$apk_path" | awk '{print "  文件大小:", $5}'
        echo ""
    else
        error "APK 构建失败，未找到输出文件"
    fi
    cd ..
}

# ---------- 变更检测 ----------
detect_changes() {
    local changed_files
    changed_files=$(git diff-tree --no-commit-id --name-only -r HEAD 2>/dev/null || echo "")

    if [[ -z "$changed_files" ]]; then
        warn "无法获取变更文件列表，将执行全部步骤"
        return
    fi

    if echo "$changed_files" | grep -q "^backend/"; then
        RUN_BACKEND=true
        info "检测到 backend/ 变更，将执行后端测试与部署"
    fi
    if echo "$changed_files" | grep -q "^web-admin/"; then
        RUN_FRONTEND=true
        info "检测到 web-admin/ 变更，将执行前端构建与部署"
    fi
    if echo "$changed_files" | grep -q "^mobile/"; then
        RUN_MOBILE=true
        info "检测到 mobile/ 变更，将执行移动端测试与 APK 构建"
    fi

    # 根目录或其他目录的变更可能影响全部组件
    if [[ "$RUN_BACKEND" == false && "$RUN_FRONTEND" == false && "$RUN_MOBILE" == false ]]; then
        info "检测到根目录文件变更，执行全部部署步骤"
        RUN_BACKEND=true
        RUN_FRONTEND=true
        RUN_MOBILE=true
    fi
}

# ---------- 参数解析 ----------
SKIP_GIT_CHECK=false
DETECT_CHANGES=false
SKIP_BACKEND=false
SKIP_FRONTEND=false
SKIP_APK=false

for arg in "$@"; do
    case $arg in
        --skip-git-check)
            SKIP_GIT_CHECK=true
            shift
            ;;
        --detect-changes)
            DETECT_CHANGES=true
            shift
            ;;
        --skip-backend)
            SKIP_BACKEND=true
            shift
            ;;
        --skip-frontend)
            SKIP_FRONTEND=true
            shift
            ;;
        --skip-apk)
            SKIP_APK=true
            shift
            ;;
    esac
done

# ---------- 主流程 ----------
main() {
    echo "========================================"
    echo "  Flash Card 自动部署脚本"
    echo "========================================"
    echo ""

    if [[ "$SKIP_GIT_CHECK" != true ]]; then
        check_git
    else
        info "跳过 Git 检查（由 hook 触发）"
    fi

    # 默认全量部署
    RUN_BACKEND=true
    RUN_FRONTEND=true
    RUN_MOBILE=true

    # 智能检测变更范围
    if [[ "$DETECT_CHANGES" == true ]]; then
        RUN_BACKEND=false
        RUN_FRONTEND=false
        RUN_MOBILE=false
        detect_changes
    fi

    # 应用手动跳过参数
    if [[ "$SKIP_BACKEND" == true ]]; then
        RUN_BACKEND=false
        info "手动跳过后端部署"
    fi
    if [[ "$SKIP_FRONTEND" == true ]]; then
        RUN_FRONTEND=false
        info "手动跳过前端部署"
    fi
    if [[ "$SKIP_APK" == true ]]; then
        RUN_MOBILE=false
        info "手动跳过 APK 构建"
    fi

    # 汇总本次执行内容
    echo ""
    info "本次执行步骤："
    [[ "$RUN_BACKEND" == true ]] && echo "  - 后端测试 + 部署"
    [[ "$RUN_FRONTEND" == true ]] && echo "  - 前端构建 + 部署"
    [[ "$RUN_MOBILE" == true ]] && echo "  - 移动端测试 + APK 构建"
    if [[ "$RUN_BACKEND" != true && "$RUN_FRONTEND" != true && "$RUN_MOBILE" != true ]]; then
        ok "没有需要执行的步骤，跳过部署"
        echo "========================================"
        return 0
    fi
    echo ""

    # 执行 SSH 检查（只要需要部署就需要 SSH）
    if [[ "$RUN_BACKEND" == true || "$RUN_FRONTEND" == true ]]; then
        check_ssh
    fi

    # 后端
    if [[ "$RUN_BACKEND" == true ]]; then
        run_backend_tests
        deploy_backend
    fi

    # 前端
    if [[ "$RUN_FRONTEND" == true ]]; then
        deploy_frontend
    fi

    # 移动端（APK 构建）
    if [[ "$RUN_MOBILE" == true ]]; then
        run_mobile_tests
        build_apk
    fi

    echo "========================================"
    ok "全部部署完成！"
    echo "========================================"
}

main "$@"

#!/usr/bin/env bash
# issue-nginx-certs.sh
# 用户态 acme.sh 证书签发脚本
# 默认:
#   证书: ~/nginx/certs/<domain>/
#   HTTP-01: ~/nginx/acme/www/
#   acme.sh: ~/.acme.sh/

set -Eeuo pipefail

trap 'printf "错误：脚本失败 %s:%s\n" "${BASH_SOURCE[0]}" "$LINENO" >&2' ERR

OUTPUT_ROOT="${SSL_OUTPUT_ROOT:-$HOME/nginx/certs}"
WEBROOT="${ACME_WEBROOT:-$HOME/nginx/acme/www}"
KEY_LENGTH="${ACME_KEYLENGTH:-ec-256}"
RELOAD_CMD="${ACME_RELOAD_CMD:-docker exec nginx nginx -t && docker exec nginx nginx -s reload}"

ACME_HOME="${ACME_HOME:-$HOME/.acme.sh}"
ACME_SCRIPT="${ACME_SCRIPT:-$ACME_HOME/acme.sh}"

die() {
    printf '错误：%s\n' "$*" >&2
    exit 1
}

install_acme() {
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL https://get.acme.sh | sh -s email="${ACME_EMAIL:-}"
    elif command -v wget >/dev/null 2>&1; then
        wget -O - https://get.acme.sh | sh -s email="${ACME_EMAIL:-}"
    else
        die "缺少 curl 或 wget，无法安装 acme.sh"
    fi

    ACME_SCRIPT="$HOME/.acme.sh/acme.sh"

    [[ -x "$ACME_SCRIPT" ]] ||
        die "acme.sh 安装失败: $ACME_SCRIPT"
}

if [[ ! -x "$ACME_SCRIPT" ]]; then
    printf '未发现 acme.sh，开始安装...\n'
    install_acme
fi

run_acme() {
    env \
        HOME="$HOME" \
        LE_WORKING_DIR="$ACME_HOME" \
        LE_CONFIG_HOME="$ACME_HOME" \
        "$ACME_SCRIPT" \
        --home "$ACME_HOME" \
        "$@"
}

validate_domain() {
    local domain="$1"

    [[ "$domain" != -* ]] ||
        die "域名不能以 - 开头: $domain"

    [[ "$domain" != *'*'* ]] ||
        die "HTTP-01 不支持通配符: $domain"

    [[ "$domain" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] ||
        die "域名包含非法字符: $domain"

    [[ "$domain" != *..* ]] ||
        die "域名格式错误: $domain"
}

DOMAINS=()
ISSUE_ARGS=()

while (($# > 0)); do
    case "$1" in
        -f|--force)
            ISSUE_ARGS+=(--force)
            ;;
        --staging|--test)
            ISSUE_ARGS+=(--staging)
            ;;
        -w|--webroot)
            [[ $# -ge 2 ]] || die "$1 缺少参数"
            WEBROOT="$2"
            shift
            ;;
        -k|--keylength)
            [[ $# -ge 2 ]] || die "$1 缺少参数"
            KEY_LENGTH="$2"
            shift
            ;;
        --server)
            [[ $# -ge 2 ]] || die "$1 缺少参数"
            ISSUE_ARGS+=(--server "$2")
            shift
            ;;
        --reloadcmd)
            [[ $# -ge 2 ]] || die "$1 缺少参数"
            RELOAD_CMD="$2"
            shift
            ;;
        --no-reload)
            RELOAD_CMD=""
            ;;
        -h|--help)
            cat <<EOF
用法:
  $0 [选项] domain1 domain2 ...

说明:
    使用 acme.sh 通过 HTTP-01 为一个或多个域名签发证书，并将证书安装到
    输出目录。首次运行时，如果未找到 acme.sh，脚本会自动安装它。
    执行 HTTP-01 验证前，请确保域名的 80 端口能够访问以下目录对应的内容:
        $WEBROOT

选项:
  -f, --force
            强制重新签发证书，即使当前证书仍然有效

    --staging, --test
            使用测试 CA 签发，适合调试，生成的证书不受浏览器信任

  -w, --webroot DIR
            指定 HTTP-01 验证目录，默认: $WEBROOT

  -k, --keylength LENGTH
            指定密钥类型，默认: $KEY_LENGTH
            可选值: ec-256、ec-384、ec-521、2048、3072、4096、8192

  --server SERVER
            指定证书颁发机构，例如 letsencrypt、zerossl

    --reloadcmd CMD
            证书安装成功后执行的 reload 命令，默认:
                $RELOAD_CMD

  --no-reload
            安装证书后不执行 reload 命令

    -h, --help
            显示此帮助信息

环境变量:
    SSL_OUTPUT_ROOT  证书输出根目录，默认: $HOME/nginx/certs
    ACME_WEBROOT     HTTP-01 验证目录，默认: $HOME/nginx/acme/www
    ACME_KEYLENGTH   默认密钥类型，默认: ec-256
    ACME_RELOAD_CMD  默认 reload 命令
    ACME_HOME        acme.sh 工作目录，默认: $HOME/.acme.sh
    ACME_SCRIPT      acme.sh 可执行文件路径
    ACME_EMAIL       安装 acme.sh 时注册的邮箱

示例:
    $0 example.com
    $0 example.com www.example.com
    $0 --staging -w /var/www/acme example.com
    $0 --no-reload --keylength 2048 example.com
EOF
            exit 0
            ;;
        --)
            shift
            while (($# > 0)); do
                DOMAINS+=("$1")
                shift
            done
            break
            ;;
        -*)
            die "未知参数: $1"
            ;;
        *)
            DOMAINS+=("$1")
            ;;
    esac
    shift
done

((${#DOMAINS[@]} > 0)) || die "没有指定域名"

case "$KEY_LENGTH" in
    ec-256|ec-384|ec-521|2048|3072|4096|8192)
        ;;
    *)
        die "不支持的 keylength: $KEY_LENGTH"
        ;;
esac

mkdir -p "$WEBROOT" "$OUTPUT_ROOT"

declare -A SEEN=()

for domain in "${DOMAINS[@]}"; do
    validate_domain "$domain"

    [[ -n "${SEEN[$domain]:-}" ]] && continue
    SEEN[$domain]=1

    domain_dir="$OUTPUT_ROOT/$domain"

    [[ ! -L "$domain_dir" ]] ||
        die "拒绝符号链接目录: $domain_dir"

    mkdir -p "$domain_dir"

    cert_file="$domain_dir/cert.pem"
    key_file="$domain_dir/key.pem"
    ca_file="$domain_dir/ca.pem"
    fullchain_file="$domain_dir/fullchain.pem"

    printf '\n==== %s ====\n' "$domain"

    issue_args=(
        --issue
        --domain "$domain"
        --webroot "$WEBROOT"
        --keylength "$KEY_LENGTH"
    )

    issue_args+=("${ISSUE_ARGS[@]}")

    rc=0
    run_acme "${issue_args[@]}" || rc=$?

    # acme.sh 返回 2 表示证书仍有效，不需要重新申请
    # 继续 install-cert，确保输出目录同步
    if ((rc != 0 && rc != 2)); then
        printf '失败: %s 签发失败\n' "$domain" >&2
        continue
    fi

    install_args=(
        --install-cert
        --domain "$domain"
        --cert-file "$cert_file"
        --key-file "$key_file"
        --ca-file "$ca_file"
        --fullchain-file "$fullchain_file"
    )

    if [[ -n "$RELOAD_CMD" ]]; then
        install_args+=(--reloadcmd "$RELOAD_CMD")
    fi

    if [[ "$KEY_LENGTH" == ec-* ]]; then
        install_args+=(--ecc)
    fi

    if ! run_acme "${install_args[@]}"; then
        printf '警告: %s reload 失败，但证书已安装\n' "$domain" >&2
    fi

    [[ -s "$cert_file" ]] || die "证书文件为空: $cert_file"
    [[ -s "$key_file" ]] || die "私钥文件为空: $key_file"
    [[ -s "$fullchain_file" ]] || die "完整链文件为空: $fullchain_file"

    chmod 0644 "$cert_file" "$ca_file" "$fullchain_file"
    chmod 0600 "$key_file"

    printf '完成:\n'
    printf '  cert:       %s\n' "$cert_file"
    printf '  fullchain:  %s\n' "$fullchain_file"
    printf '  key:        %s\n' "$key_file"
done

printf '\n全部域名处理完成\n'
#!/usr/bin/env bash
#===============================================================================
#
#          FILE: DockerProxy_Install.sh
# 
#         USAGE: ./DockerProxy_Install.sh
#
#   DESCRIPTION: 自建Docker镜像加速服务，基于官方 registry 一键部署Docker、K8s、Quay、Ghcr镜像加速\管理服务.支持部署到Render.
# 
#  ORGANIZATION: DingQz dqzboy.com 浅时光博客
#===============================================================================

echo
cat << EOF

    ██████╗  ██████╗  ██████╗██╗  ██╗███████╗██████╗     ██████╗ ██████╗  ██████╗ ██╗  ██╗██╗   ██╗
    ██╔══██╗██╔═══██╗██╔════╝██║ ██╔╝██╔════╝██╔══██╗    ██╔══██╗██╔══██╗██╔═══██╗╚██╗██╔╝╚██╗ ██╔╝
    ██║  ██║██║   ██║██║     █████╔╝ █████╗  ██████╔╝    ██████╔╝██████╔╝██║   ██║ ╚███╔╝  ╚████╔╝ 
    ██║  ██║██║   ██║██║     ██╔═██╗ ██╔══╝  ██╔══██╗    ██╔═══╝ ██╔══██╗██║   ██║ ██╔██╗   ╚██╔╝  
    ██████╔╝╚██████╔╝╚██████╗██║  ██╗███████╗██║  ██║    ██║     ██║  ██║╚██████╔╝██╔╝ ██╗   ██║   
    ╚═════╝  ╚═════╝  ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝    ╚═╝     ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝   ╚═╝   

                                    博客: dqzboy.com 浅时光博客
                        项目地址: https://github.com/dqzboy/Docker-Proxy
                                                                 
EOF

echo "----------------------------------------------------------------------------------------------------------"
echo -e "\033[32m机场推荐\033[0m(\033[34m按量不限时，解锁ChatGPT\033[0m)：\033[34;4mhttps://mojie.mx/#/register?code=CG6h8Irm\033[0m"
echo "----------------------------------------------------------------------------------------------------------"
echo
echo

GREEN="\033[0;32m"
RED="\033[31m"
YELLOW="\033[33m"
RESET="\033[0m"
BLUE="\033[0;34m"
MAGENTA="\033[0;35m"
CYAN="\033[0;36m"
WHITE="\033[1;37m"
BLACK="\033[0;30m"
LIGHT_GREEN="\033[1;32m"
LIGHT_RED="\033[1;31m"
LIGHT_YELLOW="\033[1;33m"
LIGHT_BLUE="\033[1;34m"
LIGHT_MAGENTA="\033[1;35m"
LIGHT_CYAN="\033[1;36m"
BOLD="\033[1m"
UNDERLINE="\033[4m"
BLINK="\033[5m"
REVERSE="\033[7m"

INFO="[${GREEN}INFO${RESET}]"
ERROR="[${RED}ERROR${RESET}]"
WARN="[${YELLOW}WARN${RESET}]"
function INFO() {
    echo -e "${INFO} ${1}"
}
function ERROR() {
    echo -e "${ERROR} ${1}"
}
function WARN() {
    echo -e "${WARN} ${1}"
}

function PROMPT_Y_N() {
    echo -e "[${LIGHT_GREEN}y${RESET}/${LIGHT_BLUE}n${RESET}]: "
}

PROMPT_YES_NO=$(PROMPT_Y_N)

function SEPARATOR() {
    echo -e "${INFO}${BOLD}${LIGHT_BLUE}======================== ${1} ========================${RESET}"
}


PROXY_DIR="/data/registry-proxy"
mkdir -p ${PROXY_DIR}
cd "${PROXY_DIR}"

GITRAW="https://raw.githubusercontent.com/dqzboy/Docker-Proxy/main"
CNGITRAW="https://gitee.com/boydqz/Docker-Proxy/raw/main"

IMAGE_NAME="registry"
UI_IMAGE_NAME="dqzboy/docker-registry-ui"
DOCKER_COMPOSE_FILE="docker-compose.yaml"

attempts=0
maxAttempts=3


function CHECK_OS() {
SEPARATOR "检查环境"
OSVER=$(cat /etc/os-release | grep -o '[0-9]' | head -n 1)

if [ -f /etc/os-release ]; then
    . /etc/os-release
else
    echo "无法确定发行版"
    exit 1
fi

case "$ID" in
    "centos")
        repo_type="centos"
        ;;
    "debian")
        repo_type="debian"
        ;;
    "rhel")
        repo_type="rhel"
        ;;
    "ubuntu")
        repo_type="ubuntu"
        ;;
    "opencloudos")
        repo_type="centos"
        ;;
    "rocky")
        repo_type="centos"
        ;;
    *)
        WARN "此脚本目前不支持您的系统: $ID"
        exit 1
        ;;
esac

INFO "System release:: $NAME"
INFO "System version: $VERSION"
INFO "System ID: $ID"
INFO "System ID Like: $ID_LIKE"
}

function CHECK_PACKAGE_MANAGER() {
    if command -v dnf &> /dev/null; then
        package_manager="dnf"
    elif command -v yum &> /dev/null; then
        package_manager="yum"
    elif command -v apt-get &> /dev/null; then
        package_manager="apt-get"
    elif command -v apt &> /dev/null; then
        package_manager="apt"
    else
        ERROR "不受支持的软件包管理器."
        exit 1
    fi
}

function CHECK_PKG_MANAGER() {
    if command -v rpm &> /dev/null; then
        pkg_manager="rpm"
    elif command -v dpkg &> /dev/null; then
        pkg_manager="dpkg"
    elif command -v apt &> /dev/null; then
        pkg_manager="apt"
    else
        ERROR "无法确定包管理系统."
        exit 1
    fi
}

function CHECKMEM() {
memory_usage=$(free | awk '/^Mem:/ {printf "%.2f", $3/$2 * 100}')
memory_usage=${memory_usage%.*}

if [[ $memory_usage -gt 90 ]]; then
    read -e -p "$(WARN "内存占用率${LIGHT_RED}高于 70%($memory_usage%)${RESET} 是否继续安装? ${PROMPT_YES_NO}")" continu
    if [ "$continu" == "n" ] || [ "$continu" == "N" ]; then
        exit 1
    fi
else
    INFO "内存资源充足.请继续 ${LIGHT_GREEN}($memory_usage%)${RESET}"
fi
}

function CHECKFIRE() {
systemctl stop firewalld &> /dev/null
systemctl disable firewalld &> /dev/null
systemctl stop iptables &> /dev/null
systemctl disable iptables &> /dev/null
ufw disable &> /dev/null
INFO "防火墙已被禁用."

if [[ "$repo_type" == "centos" || "$repo_type" == "rhel" ]]; then
    if sestatus | grep "SELinux status" | grep -q "enabled"; then
        WARN "SELinux 已启用。禁用 SELinux..."
        setenforce 0
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        INFO "SELinux 已被禁用."
    else
        INFO "SELinux 已被禁用."
    fi
fi
}


function CHECKBBR() {
kernel_version=$(uname -r | awk -F "-" '{print $1}')

read -e -p "$(WARN "是否开启${LIGHT_CYAN}BBR${RESET},优化网络带宽提高网络性能? ${PROMPT_YES_NO}")" choice_bbr
case $choice_bbr in
    y | Y)
        version_compare=$(echo "${kernel_version} 4.9" | awk '{if ($1 >= $2) print "yes"; else print "no"}')
        if [ "$version_compare" != "yes" ]; then
            WARN "你的内核版本小于4.9，无法启动BBR，需要你手动升级内核"
            exit 0
        fi
        sysctl net.ipv4.tcp_available_congestion_control | grep -q "bbr"
        if [ $? -eq 0 ]; then
            INFO "你的服务器已经启动BBR"
        else
            INFO "开启BBR中..."

            modprobe tcp_bbr
            if [ $? -eq 0 ]; then
                INFO "BBR模块添加成功."
            else 
                ERROR "BBR模块添加失败，请执行 ${LIGHT_CYAN}sysctl -p${RESET} 检查."
                exit 1
            fi

            if [ ! -d /etc/modules-load.d/ ]; then
                mkdir -p /etc/modules-load.d/
            fi

            if [ ! -f /etc/modules-load.d/tcp_bbr.conf ]; then
                touch /etc/modules-load.d/tcp_bbr.conf
            fi

            if ! grep -q "tcp_bbr" /etc/modules-load.d/tcp_bbr.conf ; then
                echo 'tcp_bbr' >> /etc/modules-load.d/tcp_bbr.conf
            fi

            for setting in "net.core.default_qdisc=fq" "net.ipv4.tcp_congestion_control=bbr"; do
                if ! grep -q "$setting" /etc/sysctl.conf; then
                    echo "$setting" >> /etc/sysctl.conf
                fi
            done       

            sysctl -p &> /dev/null
            if [ $? -ne 0 ]; then
                ERROR "应用sysctl设置过程中发生了一个错误，请执行 ${LIGHT_CYAN}sysctl -p${RESET} 检查."
                exit 2
            fi

            lsmod | grep tcp_bbr
            if [ $? -eq 0 ]; then
                INFO "BBR已经成功开启。"
            else
                ERROR "BBR开启失败，请执行 ${LIGHT_CYAN}sysctl -p${RESET} 检查."
                exit 3
            fi

            WARN "如果BBR开启后未生效，请执行 ${LIGHT_BLUE}reboot${RESET} 重启服务器使其BBR模块生效"
        fi
    ;;
    n | N)
        INFO "不开启BBR"
    ;;
    *)
        WARN "输入了无效的选择。请重新输入${LIGHT_GREEN}y${RESET} 或 ${LIGHT_YELLOW}n${RESET}"
        CHECKBBR
    ;;
esac
}


function INSTALL_PACKAGE(){
SEPARATOR "安装依赖"
INFO "检查依赖安装情况，请稍等 ..."
TIMEOUT=300
PACKAGES_APT=(
    lsof jq wget apache2-utils tar
)
PACKAGES_YUM=(
    epel-release lsof jq wget yum-utils httpd-tools tar
)

if [ "$package_manager" = "dnf" ] || [ "$package_manager" = "yum" ]; then
    for package in "${PACKAGES_YUM[@]}"; do
        if $pkg_manager -q "$package" &>/dev/null; then
            INFO "${LIGHT_GREEN}已经安装${RESET} $package ..."
        else
            INFO "${LIGHT_CYAN}正在安装${RESET} $package ..."

            start_time=$(date +%s)

            $package_manager -y install "$package" --skip-broken > /dev/null 2>&1 &
            install_pid=$!

            while [[ $(($(date +%s) - $start_time)) -lt $TIMEOUT ]] && kill -0 $install_pid &>/dev/null; do
                sleep 1
            done

            if kill -0 $install_pid &>/dev/null; then
                WARN "$package 的安装时间超过 ${LIGHT_YELLOW}$TIMEOUT 秒${RESET}。是否继续? [${LIGHT_GREEN}y${RESET}/${LIGHT_YELLOW}n${RESET}]"
                read -r continue_install
                if [ "$continue_install" != "y" ]; then
                    ERROR "$package 的安装超时。退出脚本。"
                    exit 1
                else
                    continue
                fi
            fi

            wait $install_pid
            if [ $? -ne 0 ]; then
                ERROR "$package 安装失败。请检查系统安装源，然后再次运行此脚本！请尝试手动执行安装: ${LIGHT_BLUE}$package_manager -y install $package${RESET}"
                exit 1
            fi
        fi
    done
elif [ "$package_manager" = "apt-get" ] || [ "$package_manager" = "apt" ];then
    dpkg --configure -a &>/dev/null
    $package_manager update &>/dev/null
    for package in "${PACKAGES_APT[@]}"; do
        if $pkg_manager -s "$package" &>/dev/null; then
            INFO "已经安装 $package ..."
        else
            INFO "正在安装 $package ..."
            $package_manager install -y $package > /dev/null 2>&1
            if [ $? -ne 0 ]; then
                ERROR "安装 $package 失败,请检查系统安装源之后再次运行此脚本！请尝试手动执行安装: ${LIGHT_BLUE}$package_manager -y install $package${RESET}"
                exit 1
            fi
        fi
    done
else
    ERROR "无法确定包管理系统,脚本无法继续执行,请检查!"
    exit 1
fi
}


function INSTALL_CADDY() {
SEPARATOR "安装Caddy"
start_caddy() {
systemctl enable caddy.service &>/dev/null
systemctl restart caddy.service

status=$(systemctl is-active caddy)

if [ "$status" = "active" ]; then
    INFO "Caddy 服务运行正常，请继续..."
else
    ERROR "Caddy 服务未运行，会导致服务无法正常安装运行，请检查后再次执行脚本！"
    ERROR "-----------服务启动失败，请查看错误日志 ↓↓↓-----------"
      journalctl -u caddy.service --no-pager
    ERROR "-----------服务启动失败，请查看错误日志 ↑↑↑-----------"
    exit 1
fi
}

check_caddy() {
if pgrep "caddy" > /dev/null; then
    INFO "Caddy 已在运行."
else
    WARN "Caddy 未运行。尝试启动 Caddy..."
    start_attempts=3

    for ((i=1; i<=$start_attempts; i++)); do
        start_caddy
        if pgrep "caddy" > /dev/null; then
            INFO "Caddy 已成功启动."
            break
        else
            if [ $i -eq $start_attempts ]; then
                ERROR "Caddy 在尝试 $start_attempts 后无法启动。请检查配置"
                exit 1
            else
                WARN "在 $i 时间内启动 Caddy 失败。重试..."
            fi
        fi
    done
fi
}

if [ "$package_manager" = "dnf" ]; then
    if which caddy &>/dev/null; then
        INFO "Caddy 已经安装."
    else
        INFO "正在安装Caddy程序，请稍候..."

        $package_manager -y install 'dnf-command(copr)' &>/dev/null
        $package_manager -y copr enable @caddy/caddy &>/dev/null
        while [ $attempts -lt $maxAttempts ]; do
            $package_manager -y install caddy &>/dev/null

            if [ $? -ne 0 ]; then
                ((attempts++))
                WARN "正在尝试安装Caddy >>> (Attempt: $attempts)"

                if [ $attempts -eq $maxAttempts ]; then
                    ERROR "Caddy installation failed. Please try installing manually."
                    echo "命令: $package_manager -y install 'dnf-command(copr)' && $package_manager -y copr enable @caddy/caddy && $package_manager -y install caddy"
                    exit 1
                fi
            else
                INFO "已安装 Caddy."
                break
            fi
        done
    fi
    check_caddy

elif [ "$package_manager" = "yum" ]; then
    if which caddy &>/dev/null; then
        INFO "Caddy 已经安装."
    else
        INFO "正在安装Caddy程序，请稍候..."

        $package_manager -y install yum-plugin-copr &>/dev/null
        $package_manager -y copr enable @caddy/caddy &>/dev/null
        while [ $attempts -lt $maxAttempts ]; do
            $package_manager -y install caddy &>/dev/null
            if [ $? -ne 0 ]; then
                ((attempts++))
                WARN "正在尝试安装Caddy >>> (Attempt: $attempts)"

                if [ $attempts -eq $maxAttempts ]; then
                    ERROR "Caddy installation failed. Please try installing manually."
                    echo "命令: $package_manager -y install 'dnf-command(copr)' && $package_manager -y copr enable @caddy/caddy && $package_manager -y install caddy"
                    exit 1
                fi
            else
                INFO "已安装 Caddy."
                break
            fi
        done
    fi

    check_caddy

elif [ "$package_manager" = "apt" ] || [ "$package_manager" = "apt-get" ];then
    dpkg --configure -a &>/dev/null
    $package_manager update &>/dev/null
    if $pkg_manager -s "caddy" &>/dev/null; then
        INFO "Caddy 已安装，跳过..."
    else
        INFO "安装 Caddy 请稍等 ..."
        $package_manager install -y debian-keyring debian-archive-keyring apt-transport-https &>/dev/null
        curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg &>/dev/null
        curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list &>/dev/null
        $package_manager update &>/dev/null
        $package_manager install -y caddy &>/dev/null
        if [ $? -ne 0 ]; then
            ERROR "安装 Caddy 失败,请检查系统安装源之后再次运行此脚本！请尝试手动执行安装：$package_manager -y install caddy"
            exit 1
        fi
    fi

    check_caddy
else
    WARN "无法确定包管理系统."
    exit 1
fi
}

function CONFIG_CADDY() {
SEPARATOR "配置Caddy"
while true; do
    INFO "${LIGHT_GREEN}>>> 域名解析主机记录(即域名前缀):${RESET} ${LIGHT_CYAN}ui、hub、gcr、ghcr、k8sgcr、k8s、quay、mcr、elastic${RESET}"
    WARN "${LIGHT_GREEN}>>> 只需选择你部署的服务进行解析即可${RESET},${LIGHT_YELLOW}无需将上面提示中所有的主机记录进行解析${RESET}"
    read -e -p "$(WARN "是否配置Caddy,实现自动HTTPS? 执行前需提前在DNS服务商选择部署的服务进行解析主机记录 ${PROMPT_YES_NO}")" caddy_conf
    case "$caddy_conf" in
        y|Y )
            read -e -p "$(INFO "请输入你的域名${LIGHT_BLUE}[例: baidu.com]${RESET} ${LIGHT_RED}不可为空${RESET}: ")" caddy_domain           
            read -e -p "$(INFO "请输入要配置的${LIGHT_MAGENTA}主机记录${RESET}，用逗号分隔${LIGHT_BLUE}[例: ui,hub]${RESET}: ")" selected_records
            IFS=',' read -r -a records_array <<< "$selected_records"

            declare -A record_templates
            record_templates[ui]="ui.$caddy_domain {
    reverse_proxy localhost:50000 {
        header_up Host {host}
        header_up Origin {scheme}://{host}
        header_up X-Forwarded-For {remote_addr}
        header_up X-Forwarded-Proto {scheme}
        header_up X-Forwarded-Ssl on
        header_up X-Forwarded-Port {server_port}
        header_up X-Forwarded-Host {host}
    }
}"
            record_templates[hub]="hub.$caddy_domain {
    reverse_proxy localhost:51000 {
        header_up Host {host}
        header_up X-Real-IP {remote_addr}
        header_up X-Forwarded-For {remote_addr}
        header_up X-Nginx-Proxy true
    }
}"
            record_templates[ghcr]="ghcr.$caddy_domain {
    reverse_proxy localhost:52000 {
        header_up Host {host}
        header_up X-Real-IP {remote_addr}
        header_up X-Forwarded-For {remote_addr}
        header_up X-Nginx-Proxy true
    }
}"
            record_templates[gcr]="gcr.$caddy_domain {
    reverse_proxy localhost:53000 {
        header_up Host {host}
        header_up X-Real-IP {remote_addr}
        header_up X-Forwarded-For {remote_addr}
        header_up X-Nginx-Proxy true
    }
}"
            record_templates[k8sgcr]="k8sgcr.$caddy_domain {
    reverse_proxy localhost:54000 {
        header_up Host {host}
        header_up X-Real-IP {remote_addr}
        header_up X-Forwarded-For {remote_addr}
        header_up X-Nginx-Proxy true
    }
}"
            record_templates[k8s]="k8s.$caddy_domain {
    reverse_proxy localhost:55000 {
        header_up Host {host}
        header_up X-Real-IP {remote_addr}
        header_up X-Forwarded-For {remote_addr}
        header_up X-Nginx-Proxy true
    }
}"
            record_templates[quay]="quay.$caddy_domain {
    reverse_proxy localhost:56000 {
        header_up Host {host}
        header_up X-Real-IP {remote_addr}
        header_up X-Forwarded-For {remote_addr}
        header_up X-Nginx-Proxy true
    }
}"
            record_templates[mcr]="mcr.$caddy_domain {
    reverse_proxy localhost:57000 {
        header_up Host {host}
        header_up X-Real-IP {remote_addr}
        header_up X-Forwarded-For {remote_addr}
        header_up X-Nginx-Proxy true
    }
}"
            record_templates[elastic]="elastic.$caddy_domain {
    reverse_proxy localhost:58000 {
        header_up Host {host}
        header_up X-Real-IP {remote_addr}
        header_up X-Forwarded-For {remote_addr}
        header_up X-Nginx-Proxy true
    }
}"
            > /etc/caddy/Caddyfile
            for record in "${records_array[@]}"; do
                if [[ -n "${record_templates[$record]}" ]]; then
                    echo "${record_templates[$record]}" >> /etc/caddy/Caddyfile
                fi
            done

            start_attempts=3
            for ((i=1; i<=$start_attempts; i++)); do
                start_caddy
                if pgrep "caddy" > /dev/null; then
                    INFO "重新载入配置成功. Caddy服务启动完成"
                    break
                else
                    if [ $i -eq $start_attempts ]; then
                        ERROR "Caddy 在尝试 $start_attempts 后无法启动。请检查配置"
                        exit 1
                    else
                        WARN "第 $i 次启动 Caddy 失败。重试..."
                    fi
                fi
            done
            break;;
        n|N )
            WARN "退出配置 Caddy 操作。"
            break;;
        * )
            INFO "请输入 ${LIGHT_GREEN}y${RESET} 或 ${LIGHT_YELLOW}n${RESET}";;
    esac
done
}


function INSTALL_NGINX() {
SEPARATOR "安装Nginx"
start_nginx() {
systemctl enable nginx &>/dev/null
systemctl restart nginx

status=$(systemctl is-active nginx)

if [ "$status" = "active" ]; then
    INFO "Nginx 服务运行正常，请继续..."
else
    ERROR "Nginx 服务未运行，会导致服务无法正常安装运行，请检查后再次执行脚本！"
    ERROR "-----------服务启动失败，请查看错误日志 ↓↓↓-----------"
      journalctl -u nginx.service --no-pager
    ERROR "-----------服务启动失败，请查看错误日志 ↑↑↑-----------"
    exit 1
fi
}

check_nginx() {
if pgrep "nginx" > /dev/null; then
    INFO "Nginx 已在运行."
else
    WARN "Nginx 未运行。尝试启动 Nginx..."
    start_attempts=3

    for ((i=1; i<=$start_attempts; i++)); do
        start_nginx
        if pgrep "nginx" > /dev/null; then
            INFO "Nginx 已成功启动."
            break
        else
            if [ $i -eq $start_attempts ]; then
                ERROR "Nginx 在尝试 $start_attempts 次后无法启动。请检查配置"
                exit 1
            else
                WARN "第 $i 次启动 Nginx 失败。重试..."
            fi
        fi
    done
fi
}

if [ "$package_manager" = "dnf" ] || [ "$package_manager" = "yum" ]; then
    if which nginx &>/dev/null; then
        INFO "Nginx 已经安装."
    else
        INFO "正在安装Nginx程序，请稍候..."
        NGINX="nginx-1.24.0-1.el${OSVER}.ngx.x86_64.rpm"

        rm -f ${NGINX}
        wget http://nginx.org/packages/centos/${OSVER}/x86_64/RPMS/${NGINX} &>/dev/null
        while [ $attempts -lt $maxAttempts ]; do
            $package_manager -y install ${NGINX} &>/dev/null

            if [ $? -ne 0 ]; then
                ((attempts++))
                WARN "正在尝试安装Nginx >>> (Attempt: $attempts)"

                if [ $attempts -eq $maxAttempts ]; then
                    ERROR "Nginx installation failed. Please try installing manually."
                    rm -f ${NGINX}
                    echo "命令: wget http://nginx.org/packages/centos/${OSVER}/x86_64/RPMS/${NGINX} && $package_manager -y install ${NGINX}"
                    exit 1
                fi
            else
                INFO "已安装 Nginx."
                rm -f ${NGINX}
                break
            fi
        done
    fi

    check_nginx

elif [ "$package_manager" = "apt-get" ] || [ "$package_manager" = "apt" ];then
    dpkg --configure -a &>/dev/null
    $package_manager update &>/dev/null
    if $pkg_manager -s "nginx" &>/dev/null; then
        INFO "nginx 已安装，跳过..."
    else
        INFO "安装 nginx 请稍等 ..."
        $package_manager install -y nginx > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            ERROR "安装 nginx 失败,请检查系统安装源之后再次运行此脚本！请尝试手动执行安装：$package_manager -y install nginx"
            exit 1
        fi
    fi

    check_nginx
else
    WARN "无法确定包管理系统."
    exit 1
fi
}

function CONFIG_NGINX() {
SEPARATOR "配置Nginx"
while true; do
    WARN "自行安装的 Nginx ${LIGHT_RED}请勿执行此操作${RESET}，${LIGHT_BLUE}以防覆盖原有配置${RESET}"
    INFO "${LIGHT_GREEN}>>> 域名解析主机记录(即域名前缀):${RESET} ${LIGHT_CYAN}ui、hub、gcr、ghcr、k8sgcr、k8s、quay、mcr、elastic${RESET}"
    WARN "${LIGHT_GREEN}>>> 只需选择你部署的服务进行解析即可${RESET},${LIGHT_YELLOW}无需将上面提示中所有的主机记录进行解析${RESET}"
    read -e -p "$(WARN "是否配置 Nginx？配置完成后需在DNS服务商对部署的服务进行解析主机记录 ${PROMPT_YES_NO}")" nginx_conf
    case "$nginx_conf" in
        y|Y )
            read -e -p "$(INFO "请输入你的域名${LIGHT_BLUE}[例: baidu.com]${RESET} ${LIGHT_RED}不可为空${RESET}: ")" nginx_domain
            
            read -e -p "$(INFO "请输入要配置的${LIGHT_MAGENTA}主机记录${RESET}，用逗号分隔${LIGHT_BLUE}[例: ui,hub]${RESET}: ")" selected_records
            IFS=',' read -r -a records_array <<< "$selected_records"

            declare -A record_templates
            record_templates[ui]="server {
    listen       80;
    #listen       443 ssl;
    server_name  ui.$nginx_domain;
    #ssl_certificate /path/to/your_domain_name.crt;
    #ssl_certificate_key /path/to/your_domain_name.key;
    #ssl_session_timeout 1d;
    #ssl_session_cache   shared:SSL:50m;
    #ssl_session_tickets off;
    #ssl_protocols TLSv1.2 TLSv1.3;
    #ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:HIGH:!aNULL:!MD5:!RC4:!DHE;
    #ssl_prefer_server_ciphers on;
    #ssl_buffer_size 8k;
    proxy_connect_timeout 600;
    proxy_send_timeout    600;
    proxy_read_timeout    600;
    send_timeout          600;
    location / {
        proxy_pass   http://localhost:50000;
        proxy_set_header  Host \$host;
        proxy_set_header  Origin \$scheme://\$host;
        proxy_set_header  X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header  X-Forwarded-Proto \$scheme;
        proxy_set_header  X-Forwarded-Ssl on; 
        proxy_set_header  X-Forwarded-Port \$server_port;
        proxy_set_header  X-Forwarded-Host \$host;
    }
}"
            record_templates[hub]="server {
    listen       80;
    #listen       443 ssl;
    server_name  hub.$nginx_domain;
    #ssl_certificate /path/to/your_domain_name.crt;
    #ssl_certificate_key /path/to/your_domain_name.key;
    #ssl_session_timeout 1d;
    #ssl_session_cache   shared:SSL:50m;
    #ssl_session_tickets off;
    #ssl_protocols TLSv1.2 TLSv1.3;
    #ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:HIGH:!aNULL:!MD5:!RC4:!DHE;
    #ssl_prefer_server_ciphers on;
    #ssl_buffer_size 8k;
    proxy_connect_timeout 600;
    proxy_send_timeout    600;
    proxy_read_timeout    600;
    send_timeout          600;
    location / {
        proxy_pass   http://localhost:51000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;        
        proxy_set_header X-Nginx-Proxy true;
        proxy_buffering off;
        proxy_redirect off;
    }
}"
            record_templates[ghcr]="server {
    listen       80;
    #listen       443 ssl;
    server_name  ghcr.$nginx_domain;
    #ssl_certificate /path/to/your_domain_name.crt;
    #ssl_certificate_key /path/to/your_domain_name.key;
    #ssl_session_timeout 1d;
    #ssl_session_cache   shared:SSL:50m;
    #ssl_session_tickets off;
    #ssl_protocols TLSv1.2 TLSv1.3;
    #ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:HIGH:!aNULL:!MD5:!RC4:!DHE;
    #ssl_prefer_server_ciphers on;
    #ssl_buffer_size 8k;
    proxy_connect_timeout 600;
    proxy_send_timeout    600;
    proxy_read_timeout    600;
    send_timeout          600;
    location / {
        proxy_pass   http://localhost:52000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;        
        proxy_set_header X-Nginx-Proxy true;
        proxy_buffering off;
        proxy_redirect off;
    }
}"
            record_templates[gcr]="server {
    listen       80;
    #listen       443 ssl;
    server_name  gcr.$nginx_domain;
    #ssl_certificate /path/to/your_domain_name.crt;
    #ssl_certificate_key /path/to/your_domain_name.key;
    #ssl_session_timeout 1d;
    #ssl_session_cache   shared:SSL:50m;
    #ssl_session_tickets off;
    #ssl_protocols TLSv1.2 TLSv1.3;
    #ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:HIGH:!aNULL:!MD5:!RC4:!DHE;
    #ssl_prefer_server_ciphers on;
    #ssl_buffer_size 8k;
    proxy_connect_timeout 600;
    proxy_send_timeout    600;
    proxy_read_timeout    600;
    send_timeout          600;
    location / {
        proxy_pass   http://localhost:53000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;        
        proxy_set_header X-Nginx-Proxy true;
        proxy_buffering off;
        proxy_redirect off;
    }
}"
            record_templates[k8sgcr]="server {
    listen       80;
    #listen       443 ssl;
    server_name  k8sgcr.$nginx_domain;
    #ssl_certificate /path/to/your_domain_name.crt;
    #ssl_certificate_key /path/to/your_domain_name.key;
    #ssl_session_timeout 1d;
    #ssl_session_cache   shared:SSL:50m;
    #ssl_session_tickets off;
    #ssl_protocols TLSv1.2 TLSv1.3;
    #ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:HIGH:!aNULL:!MD5:!RC4:!DHE;
    #ssl_prefer_server_ciphers on;
    #ssl_buffer_size 8k;
    proxy_connect_timeout 600;
    proxy_send_timeout    600;
    proxy_read_timeout    600;
    send_timeout          600;
    location / {
        proxy_pass   http://localhost:54000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;        
        proxy_set_header X-Nginx-Proxy true;
        proxy_buffering off;
        proxy_redirect off;
    }
}"
            record_templates[k8s]="server {
    listen       80;
    #listen       443 ssl;
    server_name  k8s.$nginx_domain;
    #ssl_certificate /path/to/your_domain_name.crt;
    #ssl_certificate_key /path/to/your_domain_name.key;
    #ssl_session_timeout 1d;
    #ssl_session_cache   shared:SSL:50m;
    #ssl_session_tickets off;
    #ssl_protocols TLSv1.2 TLSv1.3;
    #ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:HIGH:!aNULL:!MD5:!RC4:!DHE;
    #ssl_prefer_server_ciphers on;
    #ssl_buffer_size 8k;
    proxy_connect_timeout 600;
    proxy_send_timeout    600;
    proxy_read_timeout    600;
    send_timeout          600;
    location / {
        proxy_pass   http://localhost:55000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;        
        proxy_set_header X-Nginx-Proxy true;
        proxy_buffering off;
        proxy_redirect off;
    }
}"
            record_templates[quay]="server {
    listen       80;
    #listen       443 ssl;
    server_name  quay.$nginx_domain;
    #ssl_certificate /path/to/your_domain_name.crt;
    #ssl_certificate_key /path/to/your_domain_name.key;
    #ssl_session_timeout 1d;
    #ssl_session_cache   shared:SSL:50m;
    #ssl_session_tickets off;
    #ssl_protocols TLSv1.2 TLSv1.3;
    #ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:HIGH:!aNULL:!MD5:!RC4:!DHE;
    #ssl_prefer_server_ciphers on;
    #ssl_buffer_size 8k;
    proxy_connect_timeout 600;
    proxy_send_timeout    600;
    proxy_read_timeout    600;
    send_timeout          600;
    location / {
        proxy_pass   http://localhost:56000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;        
        proxy_set_header X-Nginx-Proxy true;
        proxy_buffering off;
        proxy_redirect off;
    }
}"
            record_templates[mcr]="server {
    listen       80;
    #listen       443 ssl;
    server_name  mcr.$nginx_domain;
    #ssl_certificate /path/to/your_domain_name.crt;
    #ssl_certificate_key /path/to/your_domain_name.key;
    #ssl_session_timeout 1d;
    #ssl_session_cache   shared:SSL:50m;
    #ssl_session_tickets off;
    #ssl_protocols TLSv1.2 TLSv1.3;
    #ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:HIGH:!aNULL:!MD5:!RC4:!DHE;
    #ssl_prefer_server_ciphers on;
    #ssl_buffer_size 8k;
    proxy_connect_timeout 600;
    proxy_send_timeout    600;
    proxy_read_timeout    600;
    send_timeout          600;
    location / {
        proxy_pass   http://localhost:57000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;        
        proxy_set_header X-Nginx-Proxy true;
        proxy_buffering off;
        proxy_redirect off;
    }
}"
            record_templates[elastic]="server {
    listen       80;
    #listen       443 ssl;
    server_name  elastic.$nginx_domain;
    #ssl_certificate /path/to/your_domain_name.crt;
    #ssl_certificate_key /path/to/your_domain_name.key;
    #ssl_session_timeout 1d;
    #ssl_session_cache   shared:SSL:50m;
    #ssl_session_tickets off;
    #ssl_protocols TLSv1.2 TLSv1.3;
    #ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:HIGH:!aNULL:!MD5:!RC4:!DHE;
    #ssl_prefer_server_ciphers on;
    #ssl_buffer_size 8k;
    proxy_connect_timeout 600;
    proxy_send_timeout    600;
    proxy_read_timeout    600;
    send_timeout          600;
    location / {
        proxy_pass   http://localhost:58000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;        
        proxy_set_header X-Nginx-Proxy true;
        proxy_buffering off;
        proxy_redirect off;
    }
}"
            > /etc/nginx/conf.d/docker-proxy.conf
            for record in "${records_array[@]}"; do
                if [[ -n "${record_templates[$record]}" ]]; then
                    echo "${record_templates[$record]}" >> /etc/nginx/conf.d/docker-proxy.conf
                fi
            done

            start_attempts=3
            for ((i=1; i<=$start_attempts; i++)); do
                start_nginx
                if pgrep "nginx" > /dev/null; then
                    INFO "重新载入配置成功. Nginx服务启动完成"
                    break
                else
                    if [ $i -eq $start_attempts ]; then
                        ERROR "Nginx 在尝试 $start_attempts 后无法启动。请检查配置"
                        exit 1
                    else
                        WARN "第 $i 次启动 Nginx 失败。重试..."
                    fi
                fi
            done
            break;;
        n|N )
            WARN "退出配置 Nginx 操作。"
            break;;
        * )
            INFO "请输入 ${LIGHT_GREEN}y${RESET} 或 ${LIGHT_YELLOW}n${RESET}";;
    esac
done
}


function CHECK_DOCKER() {
status=$(systemctl is-active docker)

if [ "$status" = "active" ]; then
    INFO "Docker 服务运行正常，请继续..."
else
    ERROR "Docker 服务未运行，会导致服务无法正常安装运行，请检查后再次执行脚本！"
    ERROR "-----------服务启动失败，请查看错误日志 ↓↓↓-----------"
      journalctl -u docker.service --no-pager
    ERROR "-----------服务启动失败，请查看错误日志 ↑↑↑-----------"
    exit 1
fi
}


function INSTALL_DOCKER() {
repo_file="docker-ce.repo"
url="https://download.docker.com/linux/$repo_type"
MAX_ATTEMPTS=3
attempt=0
success=false

if [ "$repo_type" = "centos" ] || [ "$repo_type" = "rhel" ]; then
    if ! command -v docker &> /dev/null;then
      while [[ $attempt -lt $MAX_ATTEMPTS ]]; do
        attempt=$((attempt + 1))
        WARN "Docker 未安装，正在进行安装..."
        yum-config-manager --add-repo $url/$repo_file &>/dev/null
        $package_manager -y install docker-ce &>/dev/null
        if [ $? -eq 0 ]; then
            success=true
            break
        fi
        ERROR "Docker 安装失败，正在尝试重新下载 (尝试次数: $attempt)"
      done

      if $success; then
         INFO "Docker 安装成功，版本为：$(docker --version)"
         systemctl restart docker &>/dev/null
         CHECK_DOCKER
         systemctl enable docker &>/dev/null
      else
         ERROR "Docker 安装失败，请尝试手动安装"
         exit 1
      fi
    else
      INFO "Docker 已安装，安装版本为：$(docker --version)"
      systemctl restart docker | grep -E "ERROR|ELIFECYCLE|WARN"
    fi
elif [ "$repo_type" == "ubuntu" ]; then
    if ! command -v docker &> /dev/null;then
      while [[ $attempt -lt $MAX_ATTEMPTS ]]; do
        attempt=$((attempt + 1))
        WARN "Docker 未安装，正在进行安装..."
        curl -fsSL $url/gpg | sudo apt-key add - &>/dev/null
        add-apt-repository "deb [arch=amd64] $url $(lsb_release -cs) stable" <<< $'\n' &>/dev/null
        $package_manager -y install docker-ce docker-ce-cli containerd.io &>/dev/null
        if [ $? -eq 0 ]; then
            success=true
            break
        fi
        ERROR "Docker 安装失败，正在尝试重新下载 (尝试次数: $attempt)"
      done

      if $success; then
         INFO "Docker 安装成功，版本为：$(docker --version)"
         systemctl restart docker &>/dev/null
         CHECK_DOCKER
         systemctl enable docker &>/dev/null
      else
         ERROR "Docker 安装失败，请尝试手动安装"
         exit 1
      fi
    else
      INFO "Docker 已安装，安装版本为：$(docker --version)"
      systemctl restart docker | grep -E "ERROR|ELIFECYCLE|WARN"
    fi
elif [ "$repo_type" == "debian" ]; then
    if ! command -v docker &> /dev/null;then
      while [[ $attempt -lt $MAX_ATTEMPTS ]]; do
        attempt=$((attempt + 1))

        WARN "Docker 未安装，正在进行安装..."
        curl -fsSL $url/gpg | sudo apt-key add - &>/dev/null
        add-apt-repository "deb [arch=amd64] $url $(lsb_release -cs) stable" <<< $'\n' &>/dev/null
        $package_manager -y install docker-ce docker-ce-cli containerd.io &>/dev/null
        if [ $? -eq 0 ]; then
            success=true
            break
        fi
        ERROR "Docker 安装失败，正在尝试重新下载 (尝试次数: $attempt)"
      done

      if $success; then
         INFO "Docker 安装成功，版本为：$(docker --version)"
         systemctl restart docker &>/dev/null
         CHECK_DOCKER
         systemctl enable docker &>/dev/null
      else
         ERROR "Docker 安装失败，请尝试手动安装"
         exit 1
      fi
    else
        INFO "Docker 已安装，安装版本为：$(docker --version)"
        systemctl restart docker &>/dev/null
        CHECK_DOCKER
    fi
else
    ERROR "不支持的操作系统."
    exit 1
fi
}


function INSTALL_COMPOSE() {
SEPARATOR "安装Docker Compose"

TAG=`curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r '.tag_name'`
url="https://github.com/docker/compose/releases/download/$TAG/docker-compose-$(uname -s)-$(uname -m)"
MAX_ATTEMPTS=3
attempt=0
success=false
save_path="/usr/local/bin"

chmod +x $save_path/docker-compose &>/dev/null
if ! command -v docker-compose &> /dev/null || [ -z "$(docker-compose --version)" ]; then
    WARN "Docker Compose 未安装或安装不完整，正在进行安装..."    
    while [ $attempt -lt $MAX_ATTEMPTS ]; do
        attempt=$((attempt + 1))
        wget --continue -q $url -O $save_path/docker-compose
        if [ $? -eq 0 ]; then
            chmod +x $save_path/docker-compose
            version_check=$(docker-compose --version)
            if [ -n "$version_check" ]; then
                success=true
                chmod +x $save_path/docker-compose
                break
            else
                WARN "Docker Compose 下载的文件不完整，正在尝试重新下载 (尝试次数: $attempt)"
                rm -f $save_path/docker-compose
            fi
        fi

        ERROR "Docker Compose 下载失败，正在尝试重新下载 (尝试次数: $attempt)"
    done

    if $success; then
        INFO "Docker Compose 安装成功，版本为：$(docker-compose --version)"
    else
        ERROR "Docker Compose 下载失败，请尝试手动安装docker-compose"
        exit 1
    fi
else
    chmod +x $save_path/docker-compose
    INFO "Docker Compose 已经安装，版本为：$(docker-compose --version)"
fi
}

function INSTALL_DOCKER_CN() {
MAX_ATTEMPTS=3
attempt=0
success=false
cpu_arch=$(uname -m)
save_path="/opt/docker_tgz"
mkdir -p $save_path
docker_ver="docker-26.1.4.tgz"

case $cpu_arch in
  "arm64")
    url="https://raw.gitcode.com/dqzboy/docker/blobs/686ed74bf10e53fbec21f4c8d0eb4ae68b458198/$docker_ver"
    ;;
  "aarch64")
    url="https://raw.gitcode.com/dqzboy/docker/blobs/686ed74bf10e53fbec21f4c8d0eb4ae68b458198/$docker_ver"
    ;;
  "x86_64")
    url="https://raw.gitcode.com/dqzboy/docker/blobs/f4cf4ec4167a4e6e4debc61d7b0be0d9b729a93a/$docker_ver"
    ;;
  *)
    ERROR "不支持的CPU架构: $cpu_arch"
    exit 1
    ;;
esac


if ! command -v docker &> /dev/null; then
  while [ $attempt -lt $MAX_ATTEMPTS ]; do
    attempt=$((attempt + 1))
    WARN "Docker 未安装，正在进行安装..."
    wget -P "$save_path" "$url" &>/dev/null
    if [ $? -eq 0 ]; then
        success=true
        break
    fi
    ERROR "Docker 安装失败，正在尝试重新下载 (尝试次数: $attempt)"
  done

  if $success; then
     tar -xzf $save_path/$docker_ver -C $save_path
     \cp $save_path/docker/* /usr/bin/ &>/dev/null
     rm -rf $save_path
     INFO "Docker 安装成功，版本为：$(docker --version)"
     
     cat > /usr/lib/systemd/system/docker.service <<EOF
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
After=network-online.target firewalld.service
Wants=network-online.target
[Service]
Type=notify
ExecStart=/usr/bin/dockerd
ExecReload=/bin/kill -s HUP 
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
TimeoutStartSec=0
Delegate=yes
KillMode=process
Restart=on-failure
StartLimitBurst=3
StartLimitInterval=60s
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl restart docker &>/dev/null
    CHECK_DOCKER
    systemctl enable docker &>/dev/null
  else
    ERROR "Docker 安装失败，请尝试手动安装"
    exit 1
  fi
else 
    INFO "Docker 已安装，安装版本为：$(docker --version)"
    systemctl restart docker &>/dev/null
    CHECK_DOCKER
fi
}


function INSTALL_COMPOSE_CN() {
SEPARATOR "安装Docker Compose"
MAX_ATTEMPTS=3
attempt=0
cpu_arch=$(uname -m)
success=false
save_path="/usr/local/bin"

case $cpu_arch in
  "arm64")
    url="https://raw.gitcode.com/dqzboy/docker/blobs/b373da5a65a002691d78cf8d279704e85253d18a/docker-compose-linux-aarch64"
    ;;
  "aarch64")
    url="https://raw.gitcode.com/dqzboy/docker/blobs/b373da5a65a002691d78cf8d279704e85253d18a/docker-compose-linux-aarch64"
    ;;
  "x86_64")
    url="https://raw.gitcode.com/dqzboy/docker/blobs/3cd18cebe93acf81597b9c18f6770bf1bc5fa6dc/docker-compose-linux-x86_64"
    ;;
  *)
    ERROR "不支持的CPU架构: $cpu_arch"
    exit 1
    ;;
esac


chmod +x $save_path/docker-compose &>/dev/null
if ! command -v docker-compose &> /dev/null || [ -z "$(docker-compose --version)" ]; then
    WARN "Docker Compose 未安装或安装不完整，正在进行安装..."    
    while [ $attempt -lt $MAX_ATTEMPTS ]; do
        attempt=$((attempt + 1))
        wget --continue -q $url -O $save_path/docker-compose
        if [ $? -eq 0 ]; then
            chmod +x $save_path/docker-compose
            version_check=$(docker-compose --version)
            if [ -n "$version_check" ]; then
                success=true
                chmod +x $save_path/docker-compose
                break
            else
                WARN "Docker Compose 下载的文件不完整，正在尝试重新下载 (尝试次数: $attempt)"
                rm -f $save_path/docker-compose
            fi
        fi

        ERROR "Docker Compose 下载失败，正在尝试重新下载 (尝试次数: $attempt)"
    done

    if $success; then
        INFO "Docker Compose 安装成功，版本为：$(docker-compose --version)"
    else
        ERROR "Docker Compose 下载失败，请尝试手动安装docker-compose"
        exit 1
    fi
else
    chmod +x $save_path/docker-compose
    INFO "Docker Compose 安装成功，版本为：$(docker-compose --version)"
fi
}


function append_auth_config() {
    local file=$1
    local auth_config="

auth:
  htpasswd:
    realm: basic-realm
    path: /auth/htpasswd"

    echo -e "$auth_config" | sudo tee -a "$file" > /dev/null

    sed -ri "s@#- ./htpasswd:/auth/htpasswd@- ./htpasswd:/auth/htpasswd@g" ${PROXY_DIR}/docker-compose.yaml &>/dev/null
}

function update_docker_registry_url() {
    local container_name=$1
    if [[ -f "${PROXY_DIR}/docker-compose.yaml" ]]; then
        sed -ri "s@- DOCKER_REGISTRY_URL=http://reg-docker-hub:5000@- DOCKER_REGISTRY_URL=http://${container_name}:5000@g" ${PROXY_DIR}/docker-compose.yaml
    else
        ERROR "文件 ${LIGHT_CYAN}${PROXY_DIR}/docker-compose.yaml${RESET} ${LIGHT_RED}不存在${RESET},导致容器无法应用新配置"
        exit 1
    fi
}


function CONFIG_FILES() {
while true; do
    read -e -p "$(INFO "安装环境确认 [${LIGHT_GREEN}国外输1${RESET} ${LIGHT_YELLOW}国内输2${RESET}] > ")" install_docker_reg
    case "$install_docker_reg" in
        1 )
            files=(
                "dockerhub reg-docker-hub ${GITRAW}/config/registry-hub.yml"
                "gcr reg-gcr ${GITRAW}/config/registry-gcr.yml"
                "ghcr reg-ghcr ${GITRAW}/config/registry-ghcr.yml"
                "quay reg-quay ${GITRAW}/config/registry-quay.yml"
                "k8sgcr reg-k8s-gcr ${GITRAW}/config/registry-k8sgcr.yml"
                "k8s reg-k8s ${GITRAW}/config/registry-k8s.yml"
                "mcr reg-mcr ${GITRAW}/config/registry-mcr.yml"
                "elastic reg-elastic ${GITRAW}/config/registry-elastic.yml"
            )
            break;;
        2 )
            files=(
                "dockerhub reg-docker-hub ${CNGITRAW}/config/registry-hub.yml"
                "gcr reg-gcr ${CNGITRAW}/config/registry-gcr.yml"
                "ghcr reg-ghcr ${CNGITRAW}/config/registry-ghcr.yml"
                "quay reg-quay ${CNGITRAW}/config/registry-quay.yml"
                "k8sgcr reg-k8s-gcr ${CNGITRAW}/config/registry-k8sgcr.yml"
                "k8s reg-k8s ${CNGITRAW}/config/registry-k8s.yml"
                "mcr reg-mcr ${CNGITRAW}/config/registry-mcr.yml"
                "elastic reg-elastic ${CNGITRAW}/config/registry-elastic.yml"
            )
            break;;
        * )
            INFO "请输入 ${LIGHT_GREEN}1${RESET} 表示国外 或者 ${LIGHT_YELLOW}2${RESET} 表示大陆";;
    esac
done
}

function DOWN_CONFIG() {
    selected_names=()
    selected_files=()
    selected_containers=()

    echo -e "${YELLOW}-------------------------------------------------${RESET}"
    echo -e "${GREEN}1)${RESET} ${BOLD}docker hub${RESET}"
    echo -e "${GREEN}2)${RESET} ${BOLD}gcr${RESET}"
    echo -e "${GREEN}3)${RESET} ${BOLD}ghcr${RESET}"
    echo -e "${GREEN}4)${RESET} ${BOLD}quay${RESET}"
    echo -e "${GREEN}5)${RESET} ${BOLD}k8s-gcr${RESET}"
    echo -e "${GREEN}6)${RESET} ${BOLD}k8s${RESET}"
    echo -e "${GREEN}7)${RESET} ${BOLD}mcr${RESET}"
    echo -e "${GREEN}8)${RESET} ${BOLD}elastic${RESET}"
    echo -e "${GREEN}9)${RESET} ${BOLD}all${RESET}"
    echo -e "${GREEN}0)${RESET} ${BOLD}exit${RESET}"
    echo -e "${YELLOW}-------------------------------------------------${RESET}"

    read -e -p "$(INFO "输入序号下载对应配置文件,${LIGHT_YELLOW}空格分隔${RESET}多个选项. ${LIGHT_CYAN}all下载所有${RESET} > ")" choices_reg
    while [[ ! "$choices_reg" =~ ^([0-9]+[[:space:]]*)+$ ]]; do
        WARN "无效输入，请重新输入${LIGHT_YELLOW} 0-9 ${RESET}序号"
        read -e -p "$(INFO "输入序号下载对应配置文件,${LIGHT_YELLOW}空格分隔${RESET}多个选项. ${LIGHT_CYAN}all下载所有${RESET} > ")" choices_reg
    done


    if [[ "$choices_reg" == "9" ]]; then
        for file in "${files[@]}"; do
            file_name=$(echo "$file" | cut -d' ' -f1)
            container_name=$(echo "$file" | cut -d' ' -f2)
            file_url=$(echo "$file" | cut -d' ' -f3-)
            selected_names+=("$file_name")
            selected_containers+=("$container_name")
            selected_files+=("$file_url")
            wget -NP ${PROXY_DIR}/ $file_url &>/dev/null
        done
        selected_all=true
    elif [[ "$choices_reg" == "0" ]]; then
        WARN "退出下载配置! 首次安装如果没有配置无法启动服务,只能启动UI服务"
        return
    else
        for choice in ${choices_reg}; do
            if [[ $choice =~ ^[0-9]+$ ]] && ((choice > 0 && choice <= ${#files[@]})); then
                file_name=$(echo "${files[$((choice - 1))]}" | cut -d' ' -f1)
                container_name=$(echo "${files[$((choice - 1))]}" | cut -d' ' -f2)
                file_url=$(echo "${files[$((choice - 1))]}" | cut -d' ' -f3-)
                selected_names+=("$file_name")
                selected_containers+=("$container_name")
                selected_files+=("$file_url")
                wget -NP ${PROXY_DIR}/ $file_url &>/dev/null
            else
                WARN "无效输入，请重新输入${LIGHT_YELLOW} 0-9 ${RESET}序号" 
            fi
        done

        selected_all=false


        if [[ "$main_choice" != "5" ]]; then
            first_selected_container=${selected_containers[0]}
            update_docker_registry_url "$first_selected_container"
        fi
    fi

    WARN "${LIGHT_GREEN}>>> 提示:${RESET} ${LIGHT_CYAN}配置认证后,执行镜像拉取需先通过 docker login登入后使用.访问UI需输入账号密码${RESET}"
    read -e -p "$(INFO "是否需要配置镜像仓库访问账号和密码? ${PROMPT_YES_NO}")" config_auth
    while [[ "$config_auth" != "y" && "$config_auth" != "n" ]]; do
        WARN "无效输入，请输入 ${LIGHT_GREEN}y${RESET} 或 ${LIGHT_YELLOW}n${RESET}"
        read -e -p "$(INFO "是否需要配置镜像仓库访问账号和密码? ${PROMPT_YES_NO}")" config_auth
    done

    if [[ "$config_auth" == "y" ]]; then
        while true; do

            read -e -p "$(INFO "请输入账号名称: ")" username
            if [[ -z "$username" ]]; then
                ERROR "用户名不能为空。请重新输入"
            else
                break
            fi
        done

        while true; do
            read -e -p "$(INFO "请输入账号密码: ")" password
            if [[ -z "$password" ]]; then
                ERROR "密码不能为空。请重新输入"
            else
                break
            fi
        done

        htpasswd -Bbn "$username" "$password" > ${PROXY_DIR}/htpasswd

        for file_url in "${selected_files[@]}"; do
            yml_name=$(basename "$file_url")
            append_auth_config "${PROXY_DIR}/${yml_name}"
        done
    fi

    WARN "${LIGHT_GREEN}>>> 提示:${RESET} ${LIGHT_BLUE}Proxy代理缓存过期时间${RESET} ${MAGENTA}单位:ns、us、ms、s、m、h.默认ns,0表示禁用${RESET}"
    read -e -p "$(INFO "是否要修改缓存时间? ${PROMPT_YES_NO}")" modify_cache
    while [[ "$modify_cache" != "y" && "$modify_cache" != "n" ]]; do
        WARN "无效输入，请输入 ${LIGHT_GREEN}y${RESET} 或 ${LIGHT_YELLOW}n${RESET}"
        read -e -p "$(INFO "是否要修改缓存时间? ${PROMPT_YES_NO}")" modify_cache
    done

    if [[ "$modify_cache" == "y" ]]; then
        while true; do
            read -e -p "$(INFO "请输入新的缓存时间值: ")" new_ttl
            for file_url in "${selected_files[@]}"; do
                yml_name=$(basename "$file_url")
                sed -ri "s/ttl: 168h/ttl: ${new_ttl}/g" ${PROXY_DIR}/${yml_name} &>/dev/null
            done
            break
        done
    fi
}


# 一键部署调此函数
function PROXY_HTTP() {
read -e -p "$(INFO "是否添加代理? ${PROMPT_YES_NO}")" modify_config
case $modify_config in
  [Yy]* )
    read -e -p "$(INFO "输入代理地址 ${LIGHT_MAGENTA}(eg: host:port)${RESET}: ")" url
    while [[ -z "$url" ]]; do
      WARN "代理${LIGHT_YELLOW}地址不能为空${RESET}，请重新输入!"
      read -e -p "$(INFO "输入代理地址 ${LIGHT_MAGENTA}(eg: host:port)${RESET}: ")" url
    done
    sed -i "s@#- http=http://host:port@- http_proxy=http://${url}@g" ${PROXY_DIR}/docker-compose.yaml
    sed -i "s@#- https=http://host:port@- https_proxy=http://${url}@g" ${PROXY_DIR}/docker-compose.yaml

    INFO "你配置代理地址为: ${CYAN}http://${url}${RESET}"
    ;;
  [Nn]* )
    WARN "跳过添加代理配置"
    ;;
  * )
    ERROR "无效的输入。请重新输入${LIGHT_GREEN}Y or N ${RESET}的选项"
    PROXY_HTTP
    ;;
esac
}


# 7) 本机Docker代理,调此函数
function DOCKER_PROXY_HTTP() {
WARN "${BOLD}${LIGHT_GREEN}提示:${RESET} ${LIGHT_CYAN}配置本机Docker服务走代理，加速本机Docker镜像下载${RESET}"
read -e -p "$(INFO "是否添加本机Docker服务代理? ${PROMPT_YES_NO}")" modify_proxy
case $modify_proxy in
  [Yy]* )
    read -e -p "$(INFO "输入代理地址 ${LIGHT_MAGENTA}(eg: host:port)${RESET}: ")" url
    while [[ -z "$url" ]]; do
      WARN "代理${LIGHT_YELLOW}地址不能为空${RESET}，请重新输入。"
      read -e -p "$(INFO "输入代理地址 ${LIGHT_MAGENTA}(eg: host:port)${RESET}: ")" url
    done

    INFO "你配置代理地址为: ${CYAN}http://${url}${RESET}"
    ;;
  [Nn]* )
    WARN "退出本机Docker服务代理配置"
    exit 1
    ;;
  * )
    ERROR "无效的输入。请重新输入${LIGHT_GREEN}Y or N ${RESET}的选项"
    DOCKER_PROXY_HTTP
    ;;
esac
}


function ADD_DOCKERD_PROXY() {
mkdir -p /etc/systemd/system/docker.service.d


if [ ! -f /etc/systemd/system/docker.service.d/http-proxy.conf ]; then
    cat > /etc/systemd/system/docker.service.d/http-proxy.conf <<EOF
[Service]
Environment="HTTP_PROXY=http://$url"
Environment="HTTPS_PROXY=http://$url"
EOF
    systemctl daemon-reload
    systemctl restart docker &>/dev/null
    CHECK_DOCKER
    CHECK_DOCKER_PROXY "$url"
else
    if ! grep -q "HTTP_PROXY=http://$url" /etc/systemd/system/docker.service.d/http-proxy.conf || ! grep -q "HTTPS_PROXY=http://$url" /etc/systemd/system/docker.service.d/http-proxy.conf; then
        cat >> /etc/systemd/system/docker.service.d/http-proxy.conf <<EOF
[Service]
Environment="HTTP_PROXY=http://$url"
Environment="HTTPS_PROXY=http://$url"
EOF
        systemctl daemon-reload
        systemctl restart docker &>/dev/null
        CHECK_DOCKER
        CHECK_DOCKER_PROXY "$url"
    else
        if [[ "$main_choice" = "7" ]]; then
            WARN "已经存在相同的代理配置,${LIGHT_RED}请勿重复配置${RESET}"
        fi       
    fi
fi
}

function CHECK_DOCKER_PROXY() {
    local url=$1
    local http_proxy=$(docker info 2>/dev/null | grep -i "HTTP Proxy" | awk -F ': ' '{print $2}')
    local https_proxy=$(docker info 2>/dev/null | grep -i "HTTPS Proxy" | awk -F ': ' '{print $2}')

    if [[ "$http_proxy" == "http://$url" && "$https_proxy" == "http://$url" ]]; then
        INFO "Docker 代理${LIGHT_GREEN}配置成功${RESET}，当前 HTTP Proxy: ${LIGHT_CYAN}$http_proxy${RESET}, HTTPS Proxy: ${LIGHT_CYAN}$https_proxy${RESET}"
    else
        ERROR "Docker 代理${LIGHT_RED}配置失败${RESET}，请检查配置并重新执行配置"
        DOCKER_PROXY_HTTP
    fi
}



function START_CONTAINER() {
    if [ "$modify_config" = "y" ] || [ "$modify_config" = "Y" ]; then
        ADD_DOCKERD_PROXY
    else
        INFO "拉取服务镜像并启动服务中，请稍等..."
    fi

    if [ "$selected_all" = true ]; then
        docker-compose up -d --force-recreate
    else
        docker-compose up -d "${selected_names[@]}" registry-ui
    fi
}

function RESTART_CONTAINER() {
    if [ "$selected_all" = true ]; then
        docker-compose restart
    else
        docker-compose restart "${selected_names[@]}"
    fi
}

function INSTALL_DOCKER_PROXY() {
SEPARATOR "部署Docker Proxy"
CONFIG_FILES
if [[ "$install_docker_reg" == "1" ]]; then
    wget -NP ${PROXY_DIR}/ ${GITRAW}/docker-compose.yaml &>/dev/null
elif [[ "$install_docker_reg" == "2" ]]; then
    wget -NP ${PROXY_DIR}/ ${CNGITRAW}/docker-compose.yaml &>/dev/null
fi
DOWN_CONFIG
PROXY_HTTP
START_CONTAINER
}


function STOP_REMOVE_CONTAINER() {
    if [[ -f "${PROXY_DIR}/${DOCKER_COMPOSE_FILE}" ]]; then
        INFO "停止和移除所有容器"
        docker-compose -f "${PROXY_DIR}/${DOCKER_COMPOSE_FILE}" down --remove-orphans
    else 
        WARN "${LIGHT_YELLOW}容器未运行，无需删除${RESET}"
        exit 1
    fi
}


function UPDATE_CONFIG() {
while true; do
    read -e -p "$(WARN "是否更新配置，更新前请确保您已备份现有配置，此操作不可逆? ${PROMPT_YES_NO}")" update_conf
    case "$update_conf" in
        y|Y )
            CONFIG_FILES
            DOWN_CONFIG
            RESTART_CONTAINER
            break;;
        n|N )
            WARN "退出配置更新操作。"
            break;;
        * )
            INFO "请输入 ${LIGHT_GREEN}y${RESET} 或 ${LIGHT_YELLOW}n${RESET}";;
    esac
done
}

function REMOVE_NONE_TAG() {
    docker images | grep "^${IMAGE_NAME}.*<none>" | awk '{print $3}' | xargs -r docker rmi
    images=$(docker images ${IMAGE_NAME} --format '{{.Repository}}:{{.Tag}}')
    latest=$(echo "$images" | sort -V | tail -n1)
    for image in $images
    do
      if [ "$image" != "$latest" ];then
        docker rmi $image
      fi
    done
}


function PACKAGE() {
while true; do
    read -e -p "$(INFO "是否执行软件包安装? ${PROMPT_YES_NO}")" choice_package
    case "$choice_package" in
        y|Y )
            INSTALL_PACKAGE
            break;;
        n|N )
            WARN "跳过软件包安装步骤。"
            break;;
        * )
            INFO "请输入 ${LIGHT_GREEN}y${RESET} 或 ${LIGHT_YELLOW}n${RESET}";;
    esac
done
}


function INSTALL_WEB() {
while true; do
    SEPARATOR "安装WEB服务"
    read -e -p "$(INFO "是否安装WEB服务? (用来通过域名方式访问加速服务) ${PROMPT_YES_NO}")" choice_service
    if [[ "$choice_service" =~ ^[YyNn]$ ]]; then
        if [[ "$choice_service" == "Y" || "$choice_service" == "y" ]]; then
            while true; do
                read -e -p "$(INFO "选择安装的WEB服务。安装${LIGHT_CYAN}Caddy可自动开启HTTPS${RESET} [Nginx/Caddy]: ")" web_service
                if [[ "$web_service" =~ ^(nginx|Nginx|caddy|Caddy)$ ]]; then
                    if [[ "$web_service" == "nginx" || "$web_service" == "Nginx" ]]; then
                        INSTALL_NGINX
                        CONFIG_NGINX
                        break
                    elif [[ "$web_service" == "caddy" || "$web_service" == "Caddy" ]]; then
                        INSTALL_CADDY
                        CONFIG_CADDY
                        break
                    fi
                else
                    WARN "请输入 ${LIGHT_CYAN}nginx${RESET} 或 ${LIGHT_BLUE}caddy${RESET}"
                fi
            done
            break
        else
            WARN "跳过WEB服务的安装。"
            break
        fi
    else
        INFO "请输入 ${LIGHT_GREEN}y${RESET} 或 ${LIGHT_YELLOW}n${RESET}"
    fi
done
}


function RESTART_SERVICE() {
    services=(
        "dockerhub"
        "gcr"
        "ghcr"
        "quay"
        "k8sgcr"
        "k8s"
        "mcr"
        "elastic"
    )

    selected_services=()

    WARN "重启服务请在${LIGHT_GREEN}docker-compose.yaml${RESET}文件存储目录下执行脚本.默认安装路径: ${LIGHT_BLUE}${PROXY_DIR}${RESET}"
    echo -e "${YELLOW}-------------------------------------------------${RESET}"
    echo -e "${GREEN}1)${RESET} ${BOLD}docker hub${RESET}"
    echo -e "${GREEN}2)${RESET} ${BOLD}gcr${RESET}"
    echo -e "${GREEN}3)${RESET} ${BOLD}ghcr${RESET}"
    echo -e "${GREEN}4)${RESET} ${BOLD}quay${RESET}"
    echo -e "${GREEN}5)${RESET} ${BOLD}k8s-gcr${RESET}"
    echo -e "${GREEN}6)${RESET} ${BOLD}k8s${RESET}"
    echo -e "${GREEN}7)${RESET} ${BOLD}mcr${RESET}"
    echo -e "${GREEN}8)${RESET} ${BOLD}elastic${RESET}"
    echo -e "${GREEN}9)${RESET} ${BOLD}all${RESET}"
    echo -e "${GREEN}0)${RESET} ${BOLD}exit${RESET}"
    echo -e "${YELLOW}-------------------------------------------------${RESET}"

    read -e -p "$(INFO "输入序号选择对应服务,${LIGHT_YELLOW}空格分隔${RESET}多个选项. ${LIGHT_CYAN}all选择所有${RESET} > ")"  restart_service

    if [[ "$restart_service" == "9" ]]; then
        for service_name in "${services[@]}"; do
            if docker-compose ps --services | grep -q "^${service_name}$"; then
                selected_services+=("$service_name")               
            else
                WARN "服务 ${service_name}未运行，跳过重启。"
            fi
        done
        INFO "重启的服务: ${selected_services[*]}"
    elif [[ "$restart_service" == "0" ]]; then
        WARN "退出重启服务!"
        exit 1
    else
        for choice in ${restart_service}; do
            if [[ $choice =~ ^[0-9]+$ ]] && ((choice >0 && choice <= ${#services[@]})); then
                service_name="${services[$((choice -1))]}"
                if docker-compose ps --services | grep -q "^${service_name}$"; then
                    selected_services+=("$service_name")
                    INFO "重启的服务: ${selected_services[*]}"
                else
                    WARN "服务 ${service_name} 未运行，跳过重启。"
                    
                fi
            else
                ERROR "无效的选择: $choice. 请重新${LIGHT_GREEN}选择0-9${RESET}的选项" 
                RESTART_SERVICE
            fi
        done
    fi
}

function UPDATE_SERVICE() {
    services=(
        "dockerhub"
        "gcr"
        "ghcr"
        "quay"
        "k8sgcr"
        "k8s"
        "mcr"
        "elastic"
    )

    selected_services=()

    WARN "更新服务请在${LIGHT_GREEN}docker-compose.yaml${RESET}文件存储目录下执行脚本.默认安装路径: ${LIGHT_BLUE}${PROXY_DIR}${RESET}"
    echo -e "${YELLOW}-------------------------------------------------${RESET}"
    echo -e "${GREEN}1)${RESET} ${BOLD}docker hub${RESET}"
    echo -e "${GREEN}2)${RESET} ${BOLD}gcr${RESET}"
    echo -e "${GREEN}3)${RESET} ${BOLD}ghcr${RESET}"
    echo -e "${GREEN}4)${RESET} ${BOLD}quay${RESET}"
    echo -e "${GREEN}5)${RESET} ${BOLD}k8s-gcr${RESET}"
    echo -e "${GREEN}6)${RESET} ${BOLD}k8s${RESET}"
    echo -e "${GREEN}7)${RESET} ${BOLD}mcr${RESET}"
    echo -e "${GREEN}8)${RESET} ${BOLD}elastic${RESET}"
    echo -e "${GREEN}9)${RESET} ${BOLD}all${RESET}"
    echo -e "${GREEN}0)${RESET} ${BOLD}exit${RESET}"
    echo -e "${YELLOW}-------------------------------------------------${RESET}"

    read -e -p "$(INFO "输入序号选择对应服务,${LIGHT_YELLOW}空格分隔${RESET}多个选项. ${LIGHT_CYAN}all选择所有${RESET} > ")"  choices_service

    if [[ "$choices_service" == "9" ]]; then
        for service_name in "${services[@]}"; do
            if docker-compose ps --services | grep -q "^${service_name}$"; then
                selected_services+=("$service_name")               
            else
                WARN "服务 ${service_name}未运行，跳过更新。"
            fi
        done
        INFO "更新的服务: ${selected_services[*]}"
    elif [[ "$choices_service" == "0" ]]; then
        WARN "退出更新服务!"
        exit 1
    else
        for choice in ${choices_service}; do
            if [[ $choice =~ ^[0-9]+$ ]] && ((choice >0 && choice <= ${#services[@]})); then
                service_name="${services[$((choice -1))]}"
                if docker-compose ps --services | grep -q "^${service_name}$"; then
                    selected_services+=("$service_name")
                    INFO "更新的服务: ${selected_services[*]}"
                else
                    WARN "服务 ${service_name} 未运行，跳过更新。"
                    
                fi
            else
                ERROR "无效的选择: $choice. 请重新${LIGHT_GREEN}选择0-9${RESET}的选项"
                UPDATE_SERVICE
            fi
        done
    fi
}


function PROMPT(){
PUBLIC_IP=$(curl -s https://ifconfig.me)
ALL_IPS=$(hostname -I)
INTERNAL_IP=$(echo "$ALL_IPS" | awk '$1!="127.0.0.1" && $1!="::1" && $1!="docker0" {print $1}')

echo
INFO "=================感谢您的耐心等待，安装已经完成=================="
INFO
INFO "请用浏览器访问 UI 面板: "
INFO "公网访问地址: ${UNDERLINE}http://$PUBLIC_IP:50000${RESET}"
INFO "内网访问地址: ${UNDERLINE}http://$INTERNAL_IP:50000${RESET}"
INFO
INFO "服务安装路径: ${LIGHT_BLUE}${PROXY_DIR}${RESET}"
INFO 
INFO "作者博客: https://dqzboy.com"
INFO "技术交流: https://t.me/dqzboyblog"
INFO "代码仓库: https://github.com/dqzboy/Docker-Proxy"
INFO  
INFO "如果使用的是云服务器，且配置了域名与证书，请至安全组开放80、443端口；否则开放对应服务的监听端口"
INFO
INFO "================================================================"
}


function ALL_IN_ONE() {
CHECK_OS
CHECK_PACKAGE_MANAGER
CHECK_PKG_MANAGER
CHECKMEM
CHECKFIRE
CHECKBBR
PACKAGE
INSTALL_WEB
while true; do
    SEPARATOR "安装Docker"
    read -e -p "$(INFO "安装环境确认 [${LIGHT_GREEN}国外输1${RESET} ${LIGHT_YELLOW}国内输2${RESET}] > ")" deploy_docker
    case "$deploy_docker" in
        1 )
            INSTALL_DOCKER
            INSTALL_COMPOSE
            break;;
        2 )
            INSTALL_DOCKER_CN
            INSTALL_COMPOSE_CN
            break;;
        * )
            INFO "请输入 ${LIGHT_GREEN}1${RESET} 表示国外 或者 ${LIGHT_YELLOW}2${RESET} 表示大陆";;
    esac
done

INSTALL_DOCKER_PROXY
PROMPT
}


function COMP_INST() {
SEPARATOR "安装组件"
echo -e "1) ${BOLD}安装${LIGHT_GREEN}环境依赖${RESET}"
echo -e "2) ${BOLD}安装${LIGHT_GREEN}Docker${RESET}"
echo -e "3) ${BOLD}安装${LIGHT_MAGENTA}Compose${RESET}"
echo -e "4) ${BOLD}安装${GREEN}Nginx${RESET}"
echo -e "5) ${BOLD}安装${LIGHT_CYAN}Caddy${RESET}"
echo -e "6) ${BOLD}配置${LIGHT_YELLOW}Nginx${RESET}"
echo -e "7) ${BOLD}配置${CYAN}Caddy${RESET}"
echo -e "8) ${BOLD}返回${LIGHT_RED}主菜单${RESET}"
echo -e "0) ${BOLD}退出脚本${RESET}"
echo "---------------------------------------------------------------"
read -e -p "$(INFO "输入${LIGHT_CYAN}对应数字${RESET}并按${LIGHT_GREEN}Enter${RESET}键 > ")"  comp_choice

case $comp_choice in
    1)
        CHECK_OS
        CHECK_PACKAGE_MANAGER
        CHECK_PKG_MANAGER
        CHECKMEM
        PACKAGE
        COMP_INST
        ;;
    2)
        CHECK_OS
        CHECK_PACKAGE_MANAGER
        CHECK_PKG_MANAGER
        while true; do
            SEPARATOR "安装Docker"
            read -e -p "$(INFO "安装环境确认 [${LIGHT_GREEN}国外输1${RESET} ${LIGHT_YELLOW}国内输2${RESET}] > ")" deploy_docker
            case "$deploy_docker" in
                1 )
                    INSTALL_DOCKER
                    break;;
                2 )
                    INSTALL_DOCKER_CN
                    break;;
                * )
                    INFO "请输入 ${LIGHT_GREEN}1${RESET} 表示国外 或者 ${LIGHT_YELLOW}2${RESET} 表示大陆";;
            esac
        done
        COMP_INST
        ;;
    3)
        CHECK_OS
        CHECK_PACKAGE_MANAGER
        CHECK_PKG_MANAGER
        while true; do
            read -e -p "$(INFO "安装环境确认 [${LIGHT_GREEN}国外输1${RESET} ${LIGHT_YELLOW}国内输2${RESET}] > ")" deploy_compose
            case "$deploy_compose" in
                1 )
                    INSTALL_COMPOSE
                    break;;
                2 )
                    INSTALL_COMPOSE_CN
                    break;;
                * )
                    INFO "请输入 ${LIGHT_GREEN}1${RESET} 表示国外 或者 ${LIGHT_YELLOW}2${RESET} 表示大陆";;
            esac
        done
        COMP_INST
        ;;
    4)
        CHECK_OS
        CHECK_PACKAGE_MANAGER
        CHECK_PKG_MANAGER
        INSTALL_NGINX
        COMP_INST
        ;;
    5)
        CHECK_OS
        CHECK_PACKAGE_MANAGER
        CHECK_PKG_MANAGER
        INSTALL_CADDY
        COMP_INST
        ;;
    6)
        CONFIG_NGINX
        COMP_INST
        ;;
    7)
        CONFIG_CADDY
        COMP_INST
        ;;
    8)
        main_menu
        ;;
    0)
        exit 1
        ;;
    *)
        WARN "输入了无效的选择。请重新运行脚本并${LIGHT_GREEN}选择1-7${RESET}的选项."
        ;;
esac
}


function ADD_SYS_CMD() {
MAX_ATTEMPTS=3
attempt=0
success=false

TARGET_PATH="/usr/bin/hub"

while true; do
    read -e -p "$(INFO "安装环境确认 [${LIGHT_GREEN}国外输1${RESET} ${LIGHT_YELLOW}国内输2${RESET}] > ")" sys_cmd
    case "$sys_cmd" in
        1 )
            DOWNLOAD_URL="https://raw.githubusercontent.com/dqzboy/Docker-Proxy/main/install/DockerProxy_Install.sh"
            break;;
        2 )
            DOWNLOAD_URL="https://cdn.jsdelivr.net/gh/dqzboy/Docker-Proxy/install/DockerProxy_Install.sh"
            break;;
        * )
            INFO "请输入 ${LIGHT_GREEN}1${RESET} 表示国外 或者 ${LIGHT_YELLOW}2${RESET} 表示大陆";;
    esac
done

if ! command -v hub &> /dev/null; then
  while [[ $attempt -lt $MAX_ATTEMPTS ]]; do
    attempt=$((attempt + 1))
    WARN "脚本未设置为系统命令，正在进行安装命令..."
    wget -O "$TARGET_PATH" "$DOWNLOAD_URL" &>/dev/null
    if [ $? -eq 0 ]; then
        success=true
        chmod +x "$TARGET_PATH"
        break
    fi
    ERROR "设置系统命令失败，正在重新安装命令 (尝试次数: $attempt)"
  done

  if $success; then
     INFO "设置系统命令成功，命令行输入 ${LIGHT_GREEN}hub${RESET} 运行"
  else
     ERROR "设置系统命令失败"
     exit 1
  fi
else
    INFO "设置系统命令成功，命令行输入 ${LIGHT_GREEN}hub${RESET} 运行"
    chmod +x "$TARGET_PATH"
fi
}

function main_menu() {
echo -e "╔════════════════════════════════════════════════════╗"
echo -e "║                                                    ║"
echo -e "║                ${LIGHT_CYAN}欢迎使用Docker-Proxy${RESET}                ║"
echo -e "║                                                    ║"
echo -e "║          TG频道: ${UNDERLINE}https://t.me/dqzboyblog${RESET}           ║"
echo -e "║                                                    ║"
echo -e "║                                       ${LIGHT_BLUE}by dqzboy${RESET}    ║"
echo -e "║                                                    ║"
echo -e "╚════════════════════════════════════════════════════╝"
echo
SEPARATOR "请选择操作"
echo -e "1) ${BOLD}${LIGHT_GREEN}一键${RESET}部署"
echo -e "2) ${BOLD}${LIGHT_MAGENTA}组件${RESET}安装"
echo -e "3) ${BOLD}${LIGHT_YELLOW}重启${RESET}服务"
echo -e "4) ${BOLD}${GREEN}更新${RESET}服务"
echo -e "5) ${BOLD}${LIGHT_CYAN}更新${RESET}配置"
echo -e "6) ${BOLD}${LIGHT_RED}卸载${RESET}服务"
echo -e "7) 本机${BOLD}${CYAN}Docker代理${RESET}"
echo -e "8) 设置成${BOLD}${YELLOW}系统命令${RESET}"
echo -e "0) ${BOLD}退出脚本${RESET}"
echo "---------------------------------------------------------------"
read -e -p "$(INFO "输入${LIGHT_CYAN}对应数字${RESET}并按${LIGHT_GREEN}Enter${RESET}键 > ")" main_choice


case $main_choice in
    1)
        ALL_IN_ONE
        ;;
    2)
        COMP_INST
        ;;
    3)
        SEPARATOR "重启服务"
        RESTART_SERVICE
        if [ ${#selected_services[@]} -eq 0 ]; then
            ERROR "没有需要重启的服务,请重新选择"
            RESTART_SERVICE
        else
            docker-compose stop ${selected_services[*]}
            docker-compose up -d --force-recreate ${selected_services[*]}
        fi
        SEPARATOR "重启完成"
        ;;
    4)
        SEPARATOR "更新服务"
        UPDATE_SERVICE
        if [ ${#selected_services[@]} -eq 0 ]; then
            ERROR "没有需要更新的服务,请重新选择"
            UPDATE_SERVICE
        else
            docker-compose pull ${selected_services[*]}
            docker-compose up -d --force-recreate ${selected_services[*]}
        fi
        SEPARATOR "更新完成"
        ;;
    5)
        SEPARATOR "更新配置"
        UPDATE_CONFIG
        SEPARATOR "更新完成"
        ;;
    6)
        SEPARATOR "卸载服务"
        WARN "${LIGHT_RED}注意:${RESET} ${LIGHT_MAGENTA}卸载服务会一同将项目本地的镜像缓存删除，请执行卸载之前确定是否需要备份本地的镜像缓存文件${RESET}"
        while true; do
            read -e -p "$(INFO "本人${LIGHT_RED}已知晓后果,确认卸载${RESET}服务? ${PROMPT_YES_NO}")" uninstall
            case "$uninstall" in
                y|Y )
                    STOP_REMOVE_CONTAINER
                    REMOVE_NONE_TAG
                    docker rmi --force $(docker images -q ${IMAGE_NAME}) &>/dev/null
                    docker rmi --force $(docker images -q ${UI_IMAGE_NAME}) &>/dev/null
                    if [ -d "${PROXY_DIR}" ]; then
                        rm -rf "${PROXY_DIR}" &>/dev/null
                    fi
                    if [ -f "/usr/bin/hub" ]; then
                        rm -f /usr/bin/hub &>/dev/null
                    fi
                    INFO "${LIGHT_YELLOW}服务已经卸载,感谢你的使用!${RESET}"
                    SEPARATOR "=========="
                    break;;
                n|N )
                    WARN "退出卸载服务."
                    break;;
                * )
                    INFO "请输入 ${LIGHT_GREEN}y${RESET} 或 ${LIGHT_YELLOW}n${RESET}";;
            esac
        done
        ;;
    7)
        SEPARATOR "配置本机Docker代理"
        DOCKER_PROXY_HTTP
        ADD_DOCKERD_PROXY
        SEPARATOR "Docker代理配置完成"
        ;;
    8)
        SEPARATOR "设置脚本为系统命令"
        ADD_SYS_CMD
        SEPARATOR "系统命令设置完成"
        ;;
    0)
        exit 1
        ;;
    *)
        WARN "输入了无效的选择。请重新${LIGHT_GREEN}选择0-7${RESET}的选项."
        sleep 2; main_menu
        ;;
esac
}

main_menu
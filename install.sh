#!/bin/bash

export LANG=en_US.UTF-8

# --- Мультиязычный блок текста ---
declare -A MSG

select_language() {
    echo "Select language / Выберите язык:"
    echo "1) English"
    echo "2) Русский"
    read -p "Choice / Выбор (1-2): " LANG_CHOICE
    
    if [ "$LANG_CHOICE" == "2" ]; then
        MSG[welcome]="=== Установка Remnawave Node ==="
        MSG[ask_node_port]="Введите внутренний порт ноды [по умолчанию: 8080]: "
        MSG[ask_secret]="Введите секретный ключ ноды (Secret Key): "
        MSG[ask_bbr3]="Хотите установить BBR3? (y/n): "
        MSG[ask_ipv6]="Хотите отключить IPv6? (y/n): "
        MSG[ask_ss_enable]="Хотите настроить SelfSteal (Caddy)? (y/n): "
        MSG[ask_domain]="Введите домен для SelfSteal (например, node.example.com): "
        MSG[ask_ss_port]="Введите порт для SelfSteal [по умолчанию: 9443]: "
        MSG[updating]="[1/7] Обновление системы..."
        MSG[enabling_bbr]="[2/7] Включение стандартного BBR..."
        MSG[installing_bbr3]="Установка BBR3..."
        MSG[disabling_ipv6]="Отключение IPv6 (без перезагрузки)..."
        MSG[installing_docker]="[3/7] Установка Docker..."
        MSG[conf_node]="[4/7] Настройка Remnawave Node..."
        MSG[conf_selfsteal]="[5/7] Настройка SelfSteal (Caddy)..."
        MSG[conf_html]="[6/7] Создание заглушки index.html..."
        MSG[running_containers]="[7/7] Запуск контейнеров..."
        MSG[success]="Установка успешно завершена!"
        MSG[err_empty]="Ошибка: Поле не может быть пустым."
    else
        MSG[welcome]="=== Remnawave Node Installation ==="
        MSG[ask_node_port]="Enter internal node port [default: 8080]: "
        MSG[ask_secret]="Enter node Secret Key: "
        MSG[ask_bbr3]="Do you want to install BBR3? (y/n): "
        MSG[ask_ipv6]="Do you want to disable IPv6? (y/n): "
        MSG[ask_ss_enable]="Do you want to configure SelfSteal (Caddy)? (y/n): "
        MSG[ask_domain]="Enter domain for SelfSteal (e.g., node.example.com): "
        MSG[ask_ss_port]="Enter port for SelfSteal [default: 9443]: "
        MSG[updating]="[1/7] Updating system packages..."
        MSG[enabling_bbr]="[2/7] Enabling standard BBR..."
        MSG[installing_bbr3]="Installing BBR3..."
        MSG[disabling_ipv6]="Disabling IPv6 (without reboot)..."
        MSG[installing_docker]="[3/7] Installing Docker..."
        MSG[conf_node]="[4/7] Configuring Remnawave Node..."
        MSG[conf_selfsteal]="[5/7] Configuring SelfSteal (Caddy)..."
        MSG[conf_html]="[6/7] Creating index.html template..."
        MSG[running_containers]="[7/7] Starting containers..."
        MSG[success]="Installation completed successfully!"
        MSG[err_empty]="Error: Field cannot be empty."
    fi
}

select_language
clear
echo "${MSG[welcome]}"
echo "============================================="

# --- Сбор обязательных данных для Ноды ---
read -p "${MSG[ask_node_port]}" NODE_PORT
NODE_PORT=${NODE_PORT:-8080}

read -p "${MSG[ask_secret]}" SECRET_KEY
if [ -z "$SECRET_KEY" ]; then echo "${MSG[err_empty]}"; exit 1; fi

# --- Запрос опциональных системных настроек ---
read -p "${MSG[ask_bbr3]}" WANT_BBR3
read -p "${MSG[ask_ipv6]}" WANT_IPV6

# --- Запрос настройки SelfSteal ---
read -p "${MSG[ask_ss_enable]}" WANT_SELFSTEAL

if [[ "$WANT_SELFSTEAL" =~ ^[YyДд]$ ]]; then
    read -p "${MSG[ask_domain]}" SELF_STEAL_DOMAIN
    if [ -z "$SELF_STEAL_DOMAIN" ]; then echo "${MSG[err_empty]}"; exit 1; fi

    read -p "${MSG[ask_ss_port]}" SELF_STEAL_PORT
    SELF_STEAL_PORT=${SELF_STEAL_PORT:-9443}
fi

echo "============================================="

# 1. Обновление системы
echo "${MSG[updating]}"
apt update && apt upgrade -y

# 2. Включение базового BBR
echo "${MSG[enabling_bbr]}"
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p

# Опционально: BBR3
if [[ "$WANT_BBR3" =~ ^[YyДд]$ ]]; then
    echo "${MSG[installing_bbr3]}"
    bash <(curl -sSL https://raw.githubusercontent.com/ivan-nginx/bbr3/main/optimize_network.sh)
fi

# Опционально: Отключение IPv6 (Чистый метод без сторонних скриптов и перезагрузок)
if [[ "$WANT_IPV6" =~ ^[YyДд]$ ]]; then
    echo "${MSG[disabling_ipv6]}"
    
    # Записываем конфигурацию для сохранения после перезагрузки
    cat <<EOF >> /etc/sysctl.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF

    # Применяем изменения прямо сейчас
    sysctl -p
fi

# 3. Установка Docker
echo "${MSG[installing_docker]}"
sudo curl -fsSL https://get.docker.com | sh

# 4. Настройка Remnawave Node
echo "${MSG[conf_node]}"
mkdir -p /opt/remnanode && cd /opt/remnanode

cat <<EOF > docker-compose.yml
services:
  remnanode:
    container_name: remnanode
    hostname: remnanode
    image: remnawave/node:latest
    network_mode: host
    restart: always
    cap_add:
      - NET_ADMIN
    ulimits:
      nofile:
        soft: 1048576
        hard: 1048576
    environment:
      - NODE_PORT=${NODE_PORT}
      - SECRET_KEY="${SECRET_KEY}"
EOF

docker compose up -d

# 5. Опциональная настройка SelfSteel (Caddy)
if [[ "$WANT_SELFSTEAL" =~ ^[YyДд]$ ]]; then
    echo "${MSG[conf_selfsteal]}"
    mkdir -p /opt/selfsteel && cd /opt/selfsteel

    cat <<'EOF' > Caddyfile
{
    https_port {$SELF_STEAL_PORT}
    default_bind 127.0.0.1
    servers {
        listener_wrappers {
            proxy_protocol {
                allow 127.0.0.1/32
            }
            tls
        }
    }
    auto_https disable_redirects
}

http://{$SELF_STEAL_DOMAIN} {
    bind 0.0.0.0
    redir https://{$SELF_STEAL_DOMAIN}{uri} permanent
}

https://{$SELF_STEAL_DOMAIN} {
    root * /var/www/html
    try_files {path} /index.html
    file_server
}

:{$SELF_STEAL_PORT} {
    tls internal
    respond 204
}

:80 {
    bind 0.0.0.0
    respond 204
}
EOF

    cat <<EOF > .env
SELF_STEAL_DOMAIN=${SELF_STEAL_DOMAIN}
SELF_STEAL_PORT=${SELF_STEAL_PORT}
EOF

    cat <<EOF > docker-compose.yml
services:
  caddy:
    image: caddy:latest
    container_name: caddy-remnawave
    restart: unless-stopped
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - ../html:/var/www/html
      - ./logs:/var/log/caddy
      - caddy_data_selfsteal:/data
      - caddy_config_selfsteal:/config
    env_file:
      - .env
    network_mode: "host"

volumes:
  caddy_data_selfsteal:
  caddy_config_selfsteal:
EOF

    # 6. Создание HTML сайта-заглушки
    echo "${MSG[conf_html]}"
    mkdir -p /opt/html && cd /opt/html

    cat <<EOF > index.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>My Website</title>
</head>
<body>
    <h1>Welcome to My Website</h1>
    <p>This is the homepage.</p>
</body>
</html>
EOF

    # 7. Запуск контейнеров SelfSteel
    echo "${MSG[running_containers]}"
    cd /opt/selfsteel
    docker compose up -d
fi

echo "============================================="
echo -e "\033[0;32m${MSG[success]}\033[0m"
echo "Remnanode Port: $NODE_PORT"
if [[ "$WANT_SELFSTEAL" =~ ^[YyДд]$ ]]; then
    echo "SelfSteal Domain: $SELF_STEAL_DOMAIN"
    echo "SelfSteal Port: $SELF_STEAL_PORT"
fi
echo "============================================="

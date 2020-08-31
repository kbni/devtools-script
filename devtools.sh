#!/usr/bin/env bash

# Defaults
DEVTOOLS_HTPASSWD="/etc/nginx/dev.htpasswd"
DEVTOOLS_DOMAIN="dev.kbni.net.au"
DEVTOOLS_EMAIL="admin@kbni.net"

#
SCRIPT_DIR=$(realpath "$(dirname "${BASH_SOURCE[0]}")")
DOCKER_PATH=$(which docker)
NGINX_PATH=$(which nginx)


check_env_in_files() {
    if ! grep --silent "^${1}" "${SCRIPT_DIR}/.env"; then
        if ! grep --silent "^${1}" "${SCRIPT_DIR}/env.sh"; then
            echo "Set $1 in env.sh or .env!" > /dev/stderr
            return 1
        fi
    fi
    return 0
}

check_env() {
    env_error=0
    check_env_in_files MONGO_ADMIN_USERNAME || env_error=1
    check_env_in_files MONGO_ADMIN_PASSWORD || env_error=1
    check_env_in_files RABBITMQ_ERLANG_COOKIE || env_error=1

    if [ $env_error -eq 1 ]; then
        exit 1
    fi
    if [ -f "${SCRIPT_DIR}/env.sh" ]; then
        source "${SCRIPT_DIR}/env.sh"
    fi
}

setup_portainer() {
    docker stop portainer &> /dev/null
    docker kill portainer &> /dev/null
    docker rm portainer &> /dev/null
    docker run -d --name=portainer -p 8000:8000 -p 9000:9000 --restart=always \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v portainer_data:/data portainer/portainer
}

restart_nginx() {
    sudo nginx -t || {
        echo "Failed to validate nginx settings" > /dev/stderr
        exit 1
    }
    sudo systemctl restart nginx || {
        echo "Failed to restart nginx" > /dev/stderr
        exit 1
    }
}

setup_nginx() {
    if [[ ! "$DEVTOOLS_DOMAIN" = "localhost" ]]; then
        if ! sudo test -f "/etc/nginx/ssl/dhparam.pem"; then
            mkdir /etc/nginx/ssl
            chmod 600 /etc/nginx/ssl
            sudo openssl dhparam -dsaparam -out /etc/nginx/ssl/dhparam.pem 2048
        fi
    fi

    sudo rm -v /etc/nginx/sites-enabled/default /etc/nginx/sites-enabled/{http,https}.conf &>/dev/null | true
    sudo cp -vr "${SCRIPT_DIR}/nginx/includes" /etc/nginx/
    sudo cp -vr "${SCRIPT_DIR}/nginx/conf.d" /etc/nginx/
    sudo cp -v "${SCRIPT_DIR}/nginx/http.conf" /etc/nginx/sites-enabled/

    if [[ ! "$DEVTOOLS_DOMAIN" = "localhost" ]]; then
        if ! sudo test -f "/etc/letsencrypt/live/${DEVTOOLS_DOMAIN}/privkey.pem"; then
            restart_nginx
            sudo certbot certonly -n --webroot -w /var/www/html -d ${DEVTOOLS_DOMAIN} --agree-tos -m ${DEVTOOLS_EMAIL}
        fi

        if sudo test -f "/etc/letsencrypt/live/${DEVTOOLS_DOMAIN}/privkey.pem"; then
            sudo cp -v "${SCRIPT_DIR}/nginx/https.conf" /etc/nginx/sites-enabled/
            sudo sed -i "s/DOMAIN_NAME/${DEVTOOLS_DOMAIN}/" /etc/nginx/sites-enabled/https.conf
            sudo sed -i "s#DEVTOOLS_HTPASSWD#${DEVTOOLS_HTPASSWD}#" /etc/nginx/includes/dev-host.conf
        fi
    fi

    restart_nginx
}

setup_docker() {
    # https://docs.docker.com/engine/install/ubuntu/
    sudo apt-get update
    sudo apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg-agent \
        software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose
    sudo docker run hello-world
}

htpasswd() {
    if ! test -f "$DEVTOOLS_HTPASSWD"; then
        sudo touch "$DEVTOOLS_HTPASSWD"
        sudo chown root:www-data "$DEVTOOLS_HTPASSWD"
        sudo chmod g=r-wx,o= "$DEVTOOLS_HTPASSWD"
    fi
    sudo htpasswd "$DEVTOOLS_HTPASSWD" "$@"
}

case $1 in
    setup)
        check_env
        case $2 in
            all)
                setup_docker
                setup_portainer
                setup_nginx
                ;;
            portainer) setup_portainer ;;
            docker) setup_docker ;;
            nginx) setup_nginx ;;
        esac
        ;;
    htpasswd)
        shift
        htpasswd "$@"
        ;;
esac
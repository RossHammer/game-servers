#!/bin/bash

WEBHOOK=https://discordapp.com/api/webhooks/475448222781931530/v5fk3PPT26K24moz9qF5-Sp8Eqpxy81CI2EdptL0b_mWb64sZf7qVsZgfr-EL2DIi-dt
discord() {
    curl -X POST -F "content=$1" "$WEBHOOK"
}

yum upgrade -y

curl -L https://github.com/itzg/rcon-cli/releases/download/1.4.0/rcon-cli_1.4.0_linux_amd64.tar.gz | tar -xzf - -C /bin
curl -L https://www.factorio.com/get-download/latest/headless/linux64 | tar -xJ -f - -C /opt
aws s3 sync --no-progress s3://glitch/factorio/game /opt/factorio

nohup /opt/factorio/bin/x64/factorio --start-server /opt/factorio/saves/save.zip \
    --rcon-port 27015 --rcon-password "$(jq -r .game_password /opt/factorio/data/server-settings.json)" \
    --server-settings /opt/factorio/data/server-settings.json --console-log /var/log/factorio_chat.log \
    >> /var/log/factorio.log &
FACTORIO_PID=$!
sleep 10
echo "Factorio running pid:$FACTORIO_PID"
discord "Factorio running at: $(curl http://169.254.169.254/latest/meta-data/public-ipv4)"

stop_server() {
    [ -z "$SHUTDOWN" ] || sleep 60
    SHUTDOWN=1
    echo "$2"
    rcon "$2"
    discord "$2"
    sleep $1

    STOP_TIME=$(date +%s)
    if kill -0 $FACTORIO_PID; then
        upload $STOP_TIME
        kill $FACTORIO_PID
        ( sleep 60; kill -9 $FACTORIO_PID ) &
        wait $FACTORIO_PID
    fi
    upload $STOP_TIME
    poweroff
    exit
}

upload() {
    aws s3 cp --no-progress /opt/factorio/saves/save.zip s3://glitch/factorio/game/saves/
    aws s3 cp --no-progress /opt/factorio/saves/save.zip s3://glitch/factorio/logs/$1/
    aws s3 cp --no-progress /var/log/factorio.log s3://glitch/factorio/logs/$1/
    aws s3 cp --no-progress /var/log/factorio_chat.log s3://glitch/factorio/logs/$1/
    aws s3 cp --no-progress /var/log/cloud-init-output.log s3://glitch/factorio/logs/$1/
}

rcon() {
    if kill -0 $FACTORIO_PID; then
        rcon-cli --password pass $*
    else
        >&2 echo "Factorio not running"
        return 1
    fi
}

LAST_ONLINE=$(date -d '+10 min' +%s)
while true; do
    if ! kill -0 $FACTORIO_PID; then
        stop_server 0 "Factorio shut down"
    fi
    if [ -z $(curl -Is http://169.254.169.254/latest/meta-data/spot/termination-time | head -1 | grep 404 | cut -d ' ' -f 2) ]; then
        stop_server 30 "Spot instance is terminating will be shutting down in 30 seconds"
    fi

    if [ $(rcon /players online | head -1 |grep -Po '\d+') -gt 0 ]; then
        LAST_ONLINE=$(date +%s)
    fi

    if [ "$LAST_ONLINE" -lt $(date -d '-10 min' +%s) ]; then
        stop_server 5 "No one online recently shutting down"
    fi

    sleep 5
done

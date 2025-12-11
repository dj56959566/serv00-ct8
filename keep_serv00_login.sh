#!/bin/bash

green="\033[32m"
yellow="\033[33m"
red="\033[31m"
purple() { echo -e "\033[35m$1\033[0m"; }
re="\033[0m"

echo ""
purple "=== serv00 | ct8 Djkyc一键保活脚本（最终美化版）===\n"

# Telegram 推送（支持换行与 Markdown）
send_tg() {
    local message="$1"
    [[ -z "$TG_TOKEN" || -z "$CHAT_ID" ]] && return
    curl -s -X POST "https://api.telegram.org/bot$TG_TOKEN/sendMessage" \
        -d "chat_id=$CHAT_ID" \
        -d "parse_mode=Markdown" \
        --data-urlencode "text=$message" >/dev/null
}

# 参数检查
if [[ $# -lt 1 ]]; then
    echo "用法: $0 <accounts.json>"
    exit 1
fi

accounts_file="$1"
TG_TOKEN="$2"
CHAT_ID="$3"

accounts=$(jq -c '.[]' "$accounts_file")
total_accounts=$(echo "$accounts" | wc -l)

echo "::info::共检测到 $total_accounts 个账户"
echo "----------------------------"

success_list=""
fail_list=""
success_count=0
fail_count=0

# SSH 测试函数（带重试）
try_login() {
    local ip="$1"
    local username="$2"
    local password="$3"
    local port="${4:-22}"

    sshpass -p "$password" ssh \
        -p "$port" \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o ConnectTimeout=20 \
        -o ServerAliveInterval=10 \
        -o ServerAliveCountMax=2 \
        -tt "$username@$ip" "echo ok; sleep 1; exit" >/dev/null 2>&1
}

# 遍历所有账户
for account in $accounts; do
    ip=$(echo "$account" | jq -r '.ip')
    username=$(echo "$account" | jq -r '.username')
    password=$(echo "$account" | jq -r '.password')
    port=$(echo "$account" | jq -r '.port // 22')

    echo "正在激活：$username@$ip ..."

    # 第一次尝试
    if try_login "$ip" "$username" "$password" "$port"; then
        success_list+="🟢 $username@$ip"$'\n'
        ((success_count++))
        send_tg $'🟢 *serv00/ct8 激活成功*\n账号：`'"$username@$ip"'`'
    else
        echo "第一次失败，准备重试..."
        sleep 3
        
        # 第二次尝试
        if try_login "$ip" "$username" "$password" "$port"; then
            success_list+="🟢 $username@$ip"$'\n'
            ((success_count++))
            send_tg $'🟢 *serv00/ct8 激活成功（重试成功）*\n账号：`'"$username@$ip"'`'
        else
            fail_list+="🔴 $username@$ip"$'\n'
            ((fail_count++))
            send_tg $'🔴 *serv00/ct8 激活失败*\n账号：`'"$username@$ip"'`'
        fi
    fi

    echo "----------------------------"
done

# 最终总结
summary=$'📊 *serv00/ct8 批量激活结果*\n'
summary+=$'-------------------------\n'
summary+=$'*成功：* '"$success_count"$'\n'
summary+=$'*失败：* '"$fail_count"$'\n\n'

summary+=$'*成功列表：*\n'
summary+="${success_list:-无}"$'\n'

summary+=$'*失败列表：*\n'
summary+="${fail_list:-无}"$'\n'

# 发送总结
send_tg "$summary"

# 控制台输出总结
echo -e "$summary"

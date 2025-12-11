# 平台识别
detect_platform() {
    local host="$1"

    if [[ "$host" == *"serv00.com"* ]]; then
        echo "serv00"
    elif [[ "$host" == *.ct8.* ]]; then
        echo "CT8"
    else
        echo "未知平台"
    fi
}

# 遍历所有账户
for account in $accounts; do
    ip=$(echo "$account" | jq -r '.ip')
    username=$(echo "$account" | jq -r '.username')
    password=$(echo "$account" | jq -r '.password')
    port=$(echo "$account" | jq -r '.port // 22')

    masked_user=$(mask_username "$username")
    platform=$(detect_platform "$ip")   # ← 自动识别 serv00 / CT8

    echo "正在激活：[$platform] $masked_user@$ip ..."

    # 第一次尝试
    if try_login "$ip" "$username" "$password" "$port"; then
        success_list+="🟢 [$platform] $masked_user@$ip"$'\n'
        ((success_count++))

        send_tg $'🟢 *'"$platform"$' 激活成功*\n账号：`'"$masked_user@$ip"'`'
    else
        echo "第一次失败，准备重试..."
        sleep 2
        
        # 第二次重试
        if try_login "$ip" "$username" "$password" "$port"; then
            success_list+="🟢 [$platform] $masked_user@$ip"$'\n'
            ((success_count++))

            send_tg $'🟢 *'"$platform"$' 激活成功（重试成功）*\n账号：`'"$masked_user@$ip"'`'
        else
            fail_list+="🔴 [$platform] $masked_user@$ip"$'\n'
            ((fail_count++))

            send_tg $'🔴 *'"$platform"$' 激活失败*\n账号：`'"$masked_user@$ip"'`'
        fi
    fi

    echo "----------------------------"
done

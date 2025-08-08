#!/bin/bash

DB_FILE="blocked_rules.db"

if [[ "$1" == "3" ]]; then
    if [[ ! -f "$DB_FILE" ]]; then
        echo "[!] Rule database not found: $DB_FILE"
        exit 1
    fi

    if ! command -v dig &> /dev/null; then
        echo "[!] 'dig' not found. Install with: sudo apt install dnsutils"
        exit 1
    fi

    while IFS='|' read -r domain action direction ipv4s ipv6s; do
        domain=$(echo "$domain" | xargs)
        action=$(echo "$action" | xargs)
        direction=$(echo "$direction" | xargs)
        old_ipv4s=$(echo "$ipv4s" | xargs)
        old_ipv6s=$(echo "$ipv6s" | xargs)

        echo "[*] Checking domain: $domain"

        new_ipv4s=$(dig +short A "$domain" | grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}$' | tr '\n' ',' | sed 's/,$//')
        new_ipv6s=$(dig +short AAAA "$domain" | grep ':' | tr '\n' ',' | sed 's/,$//')

        if [[ "$new_ipv4s" != "$old_ipv4s" || "$new_ipv6s" != "$old_ipv6s" ]]; then
            echo "[!] IPs changed for $domain"

            for ip in $(echo "$old_ipv4s" | tr ',' ' '); do
                [[ -z "$ip" ]] && continue
                case "$direction" in
                    I) iptables -D INPUT -s "$ip" -j DROP 2>/dev/null ;;
                    O) iptables -D OUTPUT -d "$ip" -j DROP 2>/dev/null ;;
                    B)
                        iptables -D INPUT -s "$ip" -j DROP 2>/dev/null
                        iptables -D OUTPUT -d "$ip" -j DROP 2>/dev/null ;;
                esac
            done

            for ip in $(echo "$old_ipv6s" | tr ',' ' '); do
                [[ -z "$ip" ]] && continue
                case "$direction" in
                    I) ip6tables -D INPUT -s "$ip" -j DROP 2>/dev/null ;;
                    O) ip6tables -D OUTPUT -d "$ip" -j DROP 2>/dev/null ;;
                    B)
                        ip6tables -D INPUT -s "$ip" -j DROP 2>/dev/null
                        ip6tables -D OUTPUT -d "$ip" -j DROP 2>/dev/null ;;
                esac
            done

            for ip in $(echo "$new_ipv4s" | tr ',' ' '); do
                [[ -z "$ip" ]] && continue
                case "$direction" in
                    I) iptables -A INPUT -s "$ip" -j DROP ;;
                    O) iptables -A OUTPUT -d "$ip" -j DROP ;;
                    B)
                        iptables -A INPUT -s "$ip" -j DROP
                        iptables -A OUTPUT -d "$ip" -j DROP ;;
                esac
            done

            for ip in $(echo "$new_ipv6s" | tr ',' ' '); do
                [[ -z "$ip" ]] && continue
                case "$direction" in
                    I) ip6tables -A INPUT -s "$ip" -j DROP ;;
                    O) ip6tables -A OUTPUT -d "$ip" -j DROP ;;
                    B)
                        ip6tables -A INPUT -s "$ip" -j DROP
                        ip6tables -A OUTPUT -d "$ip" -j DROP ;;
                esac
            done

            sed -i "/^$domain |/d" "$DB_FILE"
            echo "$domain | $action | $direction | $new_ipv4s | $new_ipv6s" >> "$DB_FILE"
            echo "[✓] Updated rules for $domain"
        else
            echo "[=] No change for $domain"
        fi
        echo
    done < "$DB_FILE"

    echo "[✓] Auto-update complete."
    exit 0
fi


if [[ $EUID -ne 0 ]]; then
    echo "[!] Please run this script as root with "sudo ./domain_blocker"."
    exit 1
fi


clear
echo "==============================================="
echo "          Domain Blocker Tool - v1.3"
echo "==============================================="
echo " [1] Run the Domain Blocker"
echo " [2] Schedule auto-update blocker to run every 24 hours"
echo " [3] IF you need to help how to use it  "
echo " [0] Exit"
echo "==============================================="
echo "-- By BnHany"

read -p "Enter your choice: " choice

case "$choice" in
    1)
        clear
        echo "==============================================="
        echo "          Domain Blocking Tool Started"
        echo "==============================================="
        echo "-- By BnHany"

        read -p "Enter domain(s) or URL(s), separated by spaces or commas: " domains_input
        domains=$(echo "$domains_input" | tr ',' ' ' | xargs -n1 | sort -u)

        if [[ -z "$domains" ]]; then
            echo "[!] No valid domains entered."
            exit 1
        fi

        if ! command -v dig &> /dev/null; then
            echo "[!] 'dig' command not found. Please install it:"
            echo "    sudo apt install dnsutils"
            exit 1
        fi

        declare -A domain_ip_map

        for domain in $domains; do
            if ! [[ "$domain" =~ ^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)+[a-zA-Z]{2,}$ ]]; then
                echo "[!] Skipping invalid domain format: $domain"
                continue
            fi

            echo "[*] Resolving domain: $domain"
            ip_list=$(dig +short A "$domain" | grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}$')
            ip6_list=$(dig +short AAAA "$domain" | grep ':')

            if [[ -z "${domain_ip_map[$domain]}" ]]; then
                domain_ip_map[$domain]="$ip_list"$'\n'"$ip6_list"
            else
                domain_ip_map[$domain]+=$'\n'"$ip_list"$'\n'"$ip6_list"
            fi
        done

        if [[ ${#domain_ip_map[@]} -eq 0 ]]; then
            echo "[!] No valid domains resolved."
            exit 1
        fi

        read -p "Do you want to (B)lock or (U)nblock these domains? [B/U]: " action
        action=$(echo "$action" | tr '[:lower:]' '[:upper:]')

        if [[ "$action" != "B" && "$action" != "U" ]]; then
            echo "[!] Invalid action. Please enter B or U."
            exit 1
        fi

        while true; do
            read -p "Target traffic: (I)ncoming, (O)utgoing, or (B)oth? [I/O/B]: " direction
            direction=$(echo "$direction" | tr '[:lower:]' '[:upper:]')
            case "$direction" in
                I|O|B) break ;;
                *) echo " Invalid option. Please enter I, O, or B." ;;
            esac
        done

        for domain in "${!domain_ip_map[@]}"; do
            ip_list=$(echo "${domain_ip_map[$domain]}" | sort -u)
            ipv4s=""
            ipv6s=""

            while read -r ip; do
                [[ -z "$ip" ]] && continue

                if [[ "$ip" =~ : ]]; then
                    ipv6s+="$ip,"
                    table="ip6tables"
                    source_flag="-s"
                    dest_flag="-d"
                else
                    ipv4s+="$ip,"
                    table="iptables"
                    source_flag="-s"
                    dest_flag="-d"
                fi

                for dir in $direction; do
                    if [[ "$action" == "B" ]]; then
                        case "$dir" in
                            I) $table -C INPUT $source_flag "$ip" -j DROP 2>/dev/null || $table -A INPUT $source_flag "$ip" -j DROP ;;
                            O) $table -C OUTPUT $dest_flag "$ip" -j DROP 2>/dev/null || $table -A OUTPUT $dest_flag "$ip" -j DROP ;;
                            B)
                                $table -C INPUT $source_flag "$ip" -j DROP 2>/dev/null || $table -A INPUT $source_flag "$ip" -j DROP
                                $table -C OUTPUT $dest_flag "$ip" -j DROP 2>/dev/null || $table -A OUTPUT $dest_flag "$ip" -j DROP
                                ;;
                        esac
                    else
                        case "$dir" in
                            I) while $table -C INPUT $source_flag "$ip" -j DROP 2>/dev/null; do $table -D INPUT $source_flag "$ip" -j DROP; done ;;
                            O) while $table -C OUTPUT $dest_flag "$ip" -j DROP 2>/dev/null; do $table -D OUTPUT $dest_flag "$ip" -j DROP; done ;;
                            B)
                                while $table -C INPUT $source_flag "$ip" -j DROP 2>/dev/null; do $table -D INPUT $source_flag "$ip" -j DROP; done
                                while $table -C OUTPUT $dest_flag "$ip" -j DROP 2>/dev/null; do $table -D OUTPUT $dest_flag "$ip" -j DROP; done
                                ;;
                        esac
                    fi
                done

            done <<< "$ip_list"

            ipv4s=$(echo "$ipv4s" | sed 's/,$//')
            ipv6s=$(echo "$ipv6s" | sed 's/,$//')

            sed -i "/^$domain |/d" "$DB_FILE"
            echo "$domain | $action | $direction | $ipv4s | $ipv6s" >> "$DB_FILE"
        done

        echo "[✓] All actions completed and saved to $DB_FILE."
        ;;


    2)
        clear
        echo "==============================================="
        echo "       Auto-Update Domain Rules Scheduler"
        echo "==============================================="
        echo "-- By BnHany"

        CRON_CMD="bash $(realpath "$0") 3 >/dev/null 2>&1"
        CRON_JOB="0 3 * * * root $CRON_CMD"

        if grep -Fxq "$CRON_JOB" /etc/crontab; then
            echo "[=] Cron job already exists. No changes made."
        else
            echo "$CRON_JOB" >> /etc/crontab
            echo "[✓] Auto-update has been scheduled to run daily at 3:00 AM."
        fi

        echo
        echo "[*] Running the update immediately..."

        bash "$0" 3
        ;;



    3)
        clear
        echo "======================================================================================================="
        echo "Read the WriteUp : "
        echo "======================================================================================================="
        echo "-- By BnHany"
        ;;
    
    0)
        echo "Exiting..."
        exit 0
        ;;

    *)
        echo "[!] Invalid choice. Exiting."
        exit 1
        ;;
esac


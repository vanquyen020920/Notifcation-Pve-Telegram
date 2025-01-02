#!/bin/bash

bot_token=""
chat_id=""

index_file="/var/log/pve/tasks/index"
log_dir="/var/log/pve/tasks"

# Monitor the index file to detect new UPIDs
tail -Fn0 "$index_file" | while read -r line; do
    if [[ "$line" == *":vzdump:"* ]]; then
        upid=$(echo "$line" | awk '{print $1}')
        echo "Detected new UPID: $upid"

        clean_upid="${upid%%:vzdump::*}"
        folder="${clean_upid: -1:1}"

        if [[ ! "$folder" =~ [0-9A-Fa-f] ]]; then
            echo "Invalid folder: $folder"
            continue
        fi

        log_file="$log_dir/$folder/$upid"
        echo "Log file path: $log_file"

        if [[ -f "$log_file" ]]; then
            echo "Log file found: $log_file"
            log_content=$(cat "$log_file")
            echo "Reading log file content"

            node=$(echo "$log_content" | grep -oP "INFO: starting new backup job.*--node \K\S+" | head -n 1)
            if [ -z "$node" ]; then node="Unknown"; fi

            success_vms=()
            failed_vms=()
            total_time=0

            while IFS= read -r line; do
                if [[ "$line" =~ "INFO: Finished Backup of VM" ]]; then
                    vmid=$(echo "$line" | grep -oP "VM \K\d+")
                    
                    # Extract time in format (00:00:07) and convert to seconds
                    time_str=$(echo "$line" | grep -oP "\(\d{2}:\d{2}:\d{2}\)" | sed 's/[()]//g')
                    hours=$(echo "$time_str" | cut -d: -f1)
                    minutes=$(echo "$time_str" | cut -d: -f2)
                    seconds=$(echo "$time_str" | cut -d: -f3)

                    # Convert time to total seconds
                    total_seconds=$((hours * 3600 + minutes * 60 + seconds))

                    success_vms+=("$vmid")
                    total_time=$((total_time + total_seconds))
                elif [[ "$line" =~ "ERROR: Backup of VM" ]]; then
                    vmid=$(echo "$line" | grep -oP "VM \K\d+")
                    failed_vms+=("$vmid")
                fi
            done <<< "$log_content"

            # Format total time
            total_time_str=$(printf "%dmin %ds" $((total_time / 60)) $((total_time % 60)))

            # Send notification for successful backups
            if [[ ${#success_vms[@]} -gt 0 ]]; then
                success_message=$(printf "*Proxmox Backup Notification*\n*Node:* %s\n*VMID:* %s\n*Status:* ✅ Success\n*Total Time:* %s" \
                    "$node" "$(IFS=,; echo "${success_vms[*]}")" "$total_time_str")
                curl -s -X POST "https://api.telegram.org/bot$bot_token/sendMessage" \
                    -d "chat_id=$chat_id" \
                    -d "text=$success_message" \
                    -d "parse_mode=Markdown"
            fi

            # Send notification for failed backups
            if [[ ${#failed_vms[@]} -gt 0 ]]; then
                failed_message=$(printf "*Proxmox Backup Notification*\n*Node:* %s\n*VMID:* %s\n*Status:* ❌ Failed" \
                    "$node" "$(IFS=,; echo "${failed_vms[*]}")")
                curl -s -X POST "https://api.telegram.org/bot$bot_token/sendMessage" \
                    -d "chat_id=$chat_id" \
                    -d "text=$failed_message" \
                    -d "parse_mode=Markdown"
            fi
        else
            echo "Log file not found: $log_file"
        fi
    fi
done

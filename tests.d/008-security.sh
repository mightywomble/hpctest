#!/bin/bash

# ==============================================================================
# Test Script: Security & Accounts
# Category: Security & Accounts
# Description: MOTD, SSH keys, user accounts, shadow file, home directories
# ==============================================================================

source "$(dirname "$0")/../config.sh"

# Test: MOTD
test_motd() {
    local motd_files
    motd_files=$( ( [ -f /etc/motd ] && echo /etc/motd; ls -1 /etc/update-motd.d/* 2>/dev/null ) | sed '/^$/d' )
    
    if [[ -n "$motd_files" ]]; then
        local count
        count=$(echo "$motd_files" | wc -l | awk '{print $1}')
        local status="pass"
        local note="Found MOTD files"
        if (( count > 1 )); then
            status="partial"
            note="Multiple files (${count})"
        fi
        local file_list=$(echo "$motd_files" | tr '\n' '; ')
        output_html_result "MOTD" "cat /etc/motd; ls /etc/update-motd.d" "$file_list" "$status" "$note" "motd" "Security & Accounts" "text"
    else
        output_html_result "MOTD" "cat /etc/motd" "No MOTD files found" "partial" "" "motd" "Security & Accounts" "text"
    fi
}

# Test: SSH Keys Audit
test_ssh_keys() {
    local files
    files=$(find /root/.ssh /home -maxdepth 3 \( -name 'id_*' -o -name '*.pub' -o -name 'authorized_keys' \) 2>/dev/null)
    
    if [[ -z "$files" ]]; then
        output_html_result "SSH Keys Audit" "find ~/.ssh /home/*/.ssh" "No SSH key files found" "partial" "Metadata only; contents redacted" "ssh-keys" "Security & Accounts" "text"
    else
        local count=$(echo "$files" | wc -l)
        local result_summary="Found ${count} SSH key-related files"
        output_html_result "SSH Keys Audit" "find ~/.ssh /home/*/.ssh" "$result_summary" "partial" "Metadata only; contents redacted" "ssh-keys" "Security & Accounts" "text"
    fi
}

# Test: /etc/passwd
test_passwd() {
    local p
    p=$(cat /etc/passwd 2>&1)
    local line_count=$(echo "$p" | wc -l)
    output_html_result "/etc/passwd" "cat /etc/passwd" "$p" "pass" "Total lines: $line_count" "etc-passwd" "Security & Accounts" "text"
}

# Test: /etc/shadow (redacted)
test_shadow() {
    if [[ -r /etc/shadow ]]; then
        local users_with_pw
        users_with_pw=$(awk -F: '($2!="!" && $2!="*" && $2!=""){print $1}' /etc/shadow 2>/dev/null)
        local count=0
        if [[ -n "$users_with_pw" ]]; then
            count=$(echo "$users_with_pw" | wc -l)
        fi
        local status="pass"
        local note="${count} account(s) with passwords set"
        output_html_result "/etc/shadow (redacted)" "analyzed" "Shadow file analyzed and redacted" "$status" "$note" "etc-shadow" "Security & Accounts" "text"
    else
        output_html_result "/etc/shadow (redacted)" "N/A" "Not readable" "partial" "Requires root" "etc-shadow" "Security & Accounts" "text"
    fi
}

# Test: Home Directories
test_home_dirs() {
    local homelist
    homelist=$(ls -1 /home 2>/dev/null)
    local home_count=$(echo "$homelist" | wc -l)
    local status="pass"
    local note="Home count: $home_count"
    output_html_result "Home Directories" "ls /home and /etc/passwd" "$homelist" "$status" "$note" "home-dirs" "Security & Accounts" "text"
}

# Run all tests
test_motd
test_ssh_keys
test_passwd
test_shadow
test_home_dirs

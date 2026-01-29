#!/bin/bash

# ==============================================================================
# Test Script: Software & Packages
# Category: Software & Packages
# Description: Process list, installed packages, manually installed software
# ==============================================================================

source "$(dirname "$0")/../config.sh"

# Test: Process List
psout=$(ps axfcu 2>&1)
output_html_result "Process List" "ps axfcu" "$psout" "pass" "" "process-list" "Software & Packages" "text"

# Test: Installed Packages
q=$(dpkg-query -W -f='${Package}\t${Version}\n' 2>/dev/null)
if [[ -n "$q" ]]; then
    pkg_count=$(echo "$q" | wc -l)
    output_html_result "Installed Packages" "dpkg-query -W" "Total: $pkg_count packages" "pass" "Package and version inventory" "installed-packages" "Software & Packages" "numeric"
else
    output_html_result "Installed Packages" "dpkg-query -W" "No package data" "partial" "dpkg-query returned no results" "installed-packages" "Software & Packages" "numeric"
fi

# Test: Manually Installed Software
manual=$(apt-mark showmanual 2>/dev/null | sort -u)
if [[ -n "$manual" ]]; then
    manual_count=$(echo "$manual" | wc -l)
    output_html_result "Manually installed software" "apt-mark showmanual | sort" "Total: $manual_count manual packages" "pass" "From apt-mark showmanual" "manual-packages" "Software & Packages" "numeric"
else
    output_html_result "Manually installed software" "apt-mark showmanual | sort" "None detected" "partial" "" "manual-packages" "Software & Packages" "numeric"
fi

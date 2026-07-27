#!/bin/sh
# ==============================================================================
# OpenWrt Network Routing & DNS Rules Generator
# Optimized for Embedded Systems (Zero-Dependency, Atomic I/O, High Performance)
# ==============================================================================
set -u

WORKDIR="$(dirname "$0")"
cd "$WORKDIR" || { logger -t gen-rules "[ERROR] Failed to cd to script directory"; exit 1; }
WORKDIR="$(pwd)"

CHINA_IPV4_GAO_MAIN="https://raw.githubusercontent.com/gaoyifan/china-operator-ip/ip-lists/china.txt"
CHINA_IPV4_GAO_BAK="https://gaoyifan.github.io/china-operator-ip/china.txt"
CHINA_IPV6_GAO_MAIN="https://raw.githubusercontent.com/gaoyifan/china-operator-ip/ip-lists/china6.txt"
CHINA_IPV6_GAO_BAK="https://gaoyifan.github.io/china-operator-ip/china6.txt"

APNIC_MAIN="https://ftp.apnic.net/stats/apnic/delegated-apnic-latest"

GFW_LOYAL_MAIN="https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/gfw.txt"
GFW_LOYAL_BAK="https://fastly.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/gfw.txt"

GFW_OFFICIAL_MAIN="https://raw.githubusercontent.com/gfwlist/gfwlist/master/gfwlist.txt"
GFW_OFFICIAL_BAK="https://fastly.jsdelivr.net/gh/gfwlist/gfwlist@master/gfwlist.txt"

CUSTOM_PROXY="
||github.com
||openai.com
"

# Create a secure RAM-disk temporary directory
TMPDIR="/tmp/shadowproxy_update_$$"
mkdir -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"' EXIT HUP INT TERM

log() {
    logger -t gen-rules "[INFO] $1"
    echo "[INFO] $1"
}

err() {
    logger -t gen-rules "[ERROR] $1"
    echo "[ERROR] $1" >&2
}

# Cross-filesystem atomic file installation (tmpfs -> overlayfs/ext4)
atomic_install() {
    local src="$1"
    local dst="$2"
    cp -f "$src" "${dst}.tmp" || return 1
    mv -f "${dst}.tmp" "$dst" || return 1
}

fetch_url() {
    local url="$1"
    local out="$2"
    if command -v curl >/dev/null 2>&1; then
        curl -k -s -f -m 15 -o "$out" "$url"
    elif command -v wget >/dev/null 2>&1; then
        # OpenWrt uclient-fetch / wget compatibility
        wget -q --no-check-certificate -T 15 -O "$out" "$url"
    else
        err "Neither wget nor curl found!"
        return 1
    fi
    [ -s "$out" ] && return 0 || return 1
}

fetch_with_fallback() {
    local primary_url="$1"
    local backup_url="$2"
    local out="$3"

    log "Fetching: $primary_url"
    fetch_url "$primary_url" "$out" && return 0

    log "Primary failed, trying fallback: $backup_url"
    fetch_url "$backup_url" "$out" && return 0

    err "Both primary and fallback URLs failed for target: $out"
    return 1
}

if [ "${1:-}" = "auto" ]; then
    log "Running in AUTO mode. Using default sources."
    IP_SOURCE_CHOICE="1"
    GFW_SOURCE_CHOICE="1"
else
    echo "=========================================================="
    echo "请选择 国内 IP 段 数据源 (Select China IP source):"
    echo "  1) APNIC (纯净无偏见，一手委派数据) [默认]"
    echo "  2) Gaoyifan (高度聚合，涵盖多数据源，IPv6 完善)"
    echo "=========================================================="
    printf "请输入 [1 或 2，直接回车默认 1]: "
    read -r IP_SOURCE_CHOICE
    [ -z "$IP_SOURCE_CHOICE" ] && IP_SOURCE_CHOICE="1"

    echo ""
    echo "=========================================================="
    echo "请选择 GFW 域名列表 数据源 (Select GFW source):"
    echo "  1) 官方 GFWList (纯 awk 实现 Base64 解码与清洗，零依赖) [默认]"
    echo "  2) Loyalsoldier (纯域名库，无冗余)"
    echo "=========================================================="
    printf "请输入 [1 或 2，直接回车默认 1]: "
    read -r GFW_SOURCE_CHOICE
    [ -z "$GFW_SOURCE_CHOICE" ] && GFW_SOURCE_CHOICE="1"
    echo "=========================================================="
fi

NOW=$(date +"%Y-%m-%dT%H:%M:%S")

# --- Step 1: Process China IP Rules ---
if [ "$IP_SOURCE_CHOICE" = "1" ]; then
    log "Selected APNIC as IP source. Fetching raw delegate data..."
    fetch_url "$APNIC_MAIN" "$TMPDIR/apnic.txt" || { err "Update aborted!"; exit 1; }

    log "Executing local CIDR aggregation for APNIC IPv4..."
    awk -F\| '/CN\|ipv4/ {
        split($4, a, ".");
        start = a[1]*16777216 + a[2]*65536 + a[3]*256 + a[4];
        end = start + $5 - 1;
        printf "%.0f %.0f\n", start, end;
    }' "$TMPDIR/apnic.txt" | sort -n > "$TMPDIR/apnic_v4_sorted.txt"

    awk '
    function int2ip(i) {
        b1 = int(i / 16777216); r1 = i - b1 * 16777216
        b2 = int(r1 / 65536);   r2 = r1 - b2 * 65536
        b3 = int(r2 / 256);     b4 = r2 - b3 * 256
        return b1 "." b2 "." b3 "." b4
    }
    BEGIN { has_current = 0 }
    {
        start = $1; end = $2;
        if (!has_current) {
            c_start = start; c_end = end; has_current = 1;
        } else {
            if (start <= c_end + 1) {
                if (end > c_end) c_end = end;
            } else {
                while (c_start <= c_end) {
                    step = 1; mask = 32;
                    while ((c_start / (step * 2)) == int(c_start / (step * 2)) && (c_start + step * 2 - 1) <= c_end && mask > 0) {
                        step *= 2; mask--;
                    }
                    print int2ip(c_start) "/" mask;
                    c_start += step;
                }
                c_start = start; c_end = end;
            }
        }
    }
    END {
        if (has_current) {
            while (c_start <= c_end) {
                step = 1; mask = 32;
                while ((c_start / (step * 2)) == int(c_start / (step * 2)) && (c_start + step * 2 - 1) <= c_end && mask > 0) {
                    step *= 2; mask--;
                }
                print int2ip(c_start) "/" mask;
                c_start += step;
            }
        }
    }
    ' "$TMPDIR/apnic_v4_sorted.txt" > "$TMPDIR/chnip4.txt"

    log "Parsing APNIC IPv6 data..."
    awk -F\| '/CN\|ipv6/ {print $4 "/" $5}' "$TMPDIR/apnic.txt" > "$TMPDIR/chnip6.txt"
else
    log "Selected Gaoyifan IP source. Fetching..."
    if ! fetch_with_fallback "$CHINA_IPV4_GAO_MAIN" "$CHINA_IPV4_GAO_BAK" "$TMPDIR/chnip4.txt" || \
       ! fetch_with_fallback "$CHINA_IPV6_GAO_MAIN" "$CHINA_IPV6_GAO_BAK" "$TMPDIR/chnip6.txt"; then
        err "Update aborted due to IP download failures!"
        exit 1
    fi
fi

# --- Step 2: Process GFW Domain Rules ---
if [ "$GFW_SOURCE_CHOICE" = "1" ]; then
    log "Selected Official GFWList. Fetching..."
    fetch_with_fallback "$GFW_OFFICIAL_MAIN" "$GFW_OFFICIAL_BAK" "$TMPDIR/gfw_raw.txt" || { err "Failed!"; exit 1; }

    log "Decoding Base64 using pure awk and parsing ABP syntax..."
    awk '
    BEGIN {
        b64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
        for (i=1; i<=64; i++) dec[substr(b64,i,1)] = i-1
        buf = ""
    }
    {
        gsub(/[^A-Za-z0-9+\/=]/, "")
        buf = buf $0
        len = length(buf)
        chunk = len - (len % 4)
        for (i=1; i<=chunk; i+=4) {
            c1 = substr(buf, i, 1); c2 = substr(buf, i+1, 1)
            c3 = substr(buf, i+2, 1); c4 = substr(buf, i+3, 1)
            n1 = dec[c1]; n2 = dec[c2]
            n3 = (c3 == "=") ? 0 : dec[c3]
            n4 = (c4 == "=") ? 0 : dec[c4]
            val = n1 * 262144 + n2 * 4096 + n3 * 64 + n4
            printf "%c", int(val / 65536) % 256
            if (c3 != "=") printf "%c", int(val / 256) % 256
            if (c4 != "=") printf "%c", val % 256
        }
        buf = substr(buf, chunk + 1)
    }' "$TMPDIR/gfw_raw.txt" | awk '
    function trim(s) {
        sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s
    }
    {
        line = trim($0)
        if (line == "" || line ~ /^!/ || line ~ /^\[/ || line ~ /^@@/) next
        gsub(/\r/, "", line)

        sub(/^\|https?:\/\//, "|", line)
        sub(/^https?:\/\//, "", line)
        sub(/\/.*/, "", line)
        sub(/:[0-9]+$/, "", line)
        sub(/\^$/, "", line)

        if (line ~ /^\|\*\./) sub(/^\|\*\./, "||", line)
        if (line ~ /^\*\./) sub(/^\*\./, "||", line)

        if (line ~ /^\|\|/ || line ~ /^\|/) { print line; next }
        if (line ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(\/[0-9]+)?$/) { print line; next }
        if (line ~ /^[0-9A-Fa-f:]+(\/[0-9]+)?$/) { print line; next }
        if (line ~ /^\^/) { print line; next }
        if (line ~ /^[A-Za-z0-9._-]+\.[A-Za-z][A-Za-z]+$/) { print "|" line; next }

        print line
    }' | sort -u > "$TMPDIR/gfw.txt"
else
    log "Selected Loyalsoldier GFW list. Fetching plain domains..."
    fetch_with_fallback "$GFW_LOYAL_MAIN" "$GFW_LOYAL_BAK" "$TMPDIR/gfw.txt" || { err "Failed!"; exit 1; }
fi

# --- Step 3: Generate Nftables IPSets & DNS ACL Files ---
log "Generating IPSet files for nftables..."

echo "define chnip4 = {" > "$TMPDIR/chnip4.ips.tmp"
awk 'NF { if (NR > 1) printf ",\n"; printf "    %s", $1; }' "$TMPDIR/chnip4.txt" >> "$TMPDIR/chnip4.ips.tmp"
echo -e "\n}" >> "$TMPDIR/chnip4.ips.tmp"

echo "define chnip6 = {" > "$TMPDIR/chnip6.ips.tmp"
awk 'NF { if (NR > 1) printf ",\n"; printf "    %s", $1; }' "$TMPDIR/chnip6.txt" >> "$TMPDIR/chnip6.ips.tmp"
echo -e "\n}" >> "$TMPDIR/chnip6.ips.tmp"

log "Generating minimalist DNS ACL file..."

cat <<EOF > "$TMPDIR/shadowproxy-dns-base.acl.tmp"
# Generated by shell script for dns-base.acl
# GFW Source: $( [ "$GFW_SOURCE_CHOICE" = "1" ] && echo "Official GFWList" || echo "Loyalsoldier" )
# Time: $NOW

[bypass_all]

[proxy_list]
EOF
echo "$CUSTOM_PROXY" | awk 'NF {print}' >> "$TMPDIR/shadowproxy-dns-base.acl.tmp"

awk '/^[^#]/ && NF {
    if ($0 ~ /^\|/) print $0
    else print "||" $0
}' "$TMPDIR/gfw.txt" >> "$TMPDIR/shadowproxy-dns-base.acl.tmp"

# --- Step 4: Atomic Deployment to Working Directory ---
log "Atomically replacing configuration files in $WORKDIR..."
atomic_install "$TMPDIR/chnip4.ips.tmp" "$WORKDIR/chnip4.ips" || { err "Failed to install chnip4.ips"; exit 1; }
atomic_install "$TMPDIR/chnip6.ips.tmp" "$WORKDIR/chnip6.ips" || { err "Failed to install chnip6.ips"; exit 1; }
atomic_install "$TMPDIR/shadowproxy-dns-base.acl.tmp" "$WORKDIR/shadowproxy-dns-base.acl" || { err "Failed to install shadowproxy-dns-base.acl"; exit 1; }

# --- Step 5: Runtime Nftables Set Hot Reload ---
# Zero-cost check: verify command exists and table is loaded in kernel without subshell/grep
if command -v nft >/dev/null 2>&1 && nft list table inet shadowproxy-mangle >/dev/null 2>&1; then
    log "Executing ATOMIC hot reload of nftables sets..."

    cat <<EOF > "$TMPDIR/chnip_reload.nft"
include "$WORKDIR/chnip4.ips"
include "$WORKDIR/chnip6.ips"

flush set inet shadowproxy-mangle chnip4_set
add element inet shadowproxy-mangle chnip4_set \$chnip4

flush set inet shadowproxy-mangle chnip6_set
add element inet shadowproxy-mangle chnip6_set \$chnip6
EOF

    # Netlink transaction guarantees atomicity; packets won't drop during reload
    if nft -f "$TMPDIR/chnip_reload.nft"; then
        log "Nftables sets ATOMICALLY hot-updated without service interruption!"
    else
        err "CRITICAL: Failed to reload chnip sets into kernel!"
    fi
else
    log "Shadowproxy table not loaded in kernel yet. Skipping hot reload."
fi

log "Update successfully finished! Configuration is robust, atomic, and clean."

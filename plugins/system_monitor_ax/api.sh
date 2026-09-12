#!/system/bin/sh
# =============================================================================
# system_monitor_ax — 实时系统监控面板
# -----------------------------------------------------------------------------
# 纯只读采集：/proc 文件系统 + dumpsys。shell(uid 2000) 可完整读取，
# 这些就是非 root 环境下唯一可信的数据来源（旧版本依赖 dumpsys 文本抓取
# 且未做数值兜底，字段缺失时 WebUI 会显示 NaN）。
# =============================================================================
MODDIR=$(cd "${0%/*}/.." 2>/dev/null && pwd)
. "$MODDIR/scripts/axcore.sh"
ax_init "$MODDIR"

# --- 内存（/proc/meminfo，单位 KB）-----------------------------------------
_mem_total() { ax_num "$(ax_mem_field MemTotal)"; }
_mem_free() {
    _a=$(ax_num "$(ax_mem_field MemFree)")
    _b=$(ax_num "$(ax_mem_field Buffers)")
    _c=$(ax_num "$(ax_mem_field Cached)")
    _s=$(ax_num "$(ax_mem_field SReclaimable)")
    echo $((_a + _b + _c + _s))
}
_mem_avail() {
    _a=$(ax_num "$(ax_mem_field MemAvailable)")
    [ "$_a" -gt 0 ] && echo "$_a" || _mem_free
}

# --- CPU 使用率：对 /proc/stat 取两次快照求差值 -----------------------------
_cpu_busy() {
    _read() {
        read -r _c _u _n _s _i _iow _irq _sirq _st < /proc/stat 2>/dev/null || return 1
        _idle=$((_i + _iow))
        _tot=$((_u + _n + _s + _i + _iow + _irq + _sirq + _st))
        echo "$_idle $_tot"
    }
    _a=$(_read)
    sleep 1
    _b=$(_read)
    [ -z "$_a" ] || [ -z "$_b" ] && { echo 0; return; }
    _i1=$(echo "$_a" | cut -d' ' -f1); _t1=$(echo "$_a" | cut -d' ' -f2)
    _i2=$(echo "$_b" | cut -d' ' -f1); _t2=$(echo "$_b" | cut -d' ' -f2)
    _di=$((_i2 - _i1)); _dt=$((_t2 - _t1))
    if [ "$_dt" -le 0 ]; then echo 0; else echo $(( (_dt - _di) * 100 / _dt )); fi
}

# --- 网络速率：/proc/net/dev 两次采样差值（KB/s）-----------------------------
_net() {
    _read() {
        awk 'NR>2 {gsub(/:/,"",$1); if ($1=="lo") next; rx+=$2; tx+=$10} END {print int(rx)" "int(tx)}' \
            /proc/net/dev 2>/dev/null || echo "0 0"
    }
    _a=$(_read); sleep 1; _b=$(_read)
    _r1=$(echo "$_a" | cut -d' ' -f1); _t1=$(echo "$_a" | cut -d' ' -f2)
    _r2=$(echo "$_b" | cut -d' ' -f1); _t2=$(echo "$_b" | cut -d' ' -f2)
    _rx=$(( (_r2 - _r1) / 1024 )); _tx=$(( (_t2 - _t1) / 1024 ))
    [ "$_rx" -lt 0 ] && _rx=0
    [ "$_tx" -lt 0 ] && _tx=0
    echo "$_rx $_tx"
}

ax_status() {
    _t=$(_mem_total)
    _a=$(_mem_avail)
    _u=$((_t - _a))
    _pct=0
    [ "$_t" -gt 0 ] && _pct=$((_u * 100 / _t))

    _bt=$(ax_num "$(ax_battery_field level)")
    _temp=$(ax_num "$(ax_battery_field temperature)")
    _cur=$(ax_num "$(ax_battery_field current_now)")

    # /data 分区使用率
    _d=$(df -k /data 2>/dev/null | awk 'NR==2 {print $2" "$3" "$4}')
    _dsize=$(echo "$_d" | cut -d' ' -f1)
    _dused=$(echo "$_d" | cut -d' ' -f2)
    _dfree=$(echo "$_d" | cut -d' ' -f3)
    _dpct=0
    [ "$(ax_num "$_dsize")" -gt 0 ] && _dpct=$(( (ax_num "$_dused") * 100 / (ax_num "$_dsize") ))

    _cp=$(_cpu_busy)
    _n=$(_net)
    _nrx=$(echo "$_n" | cut -d' ' -f1)
    _ntx=$(echo "$_n" | cut -d' ' -f2)

    ax_json_begin
    ax_json_kv cpu "${_cp:-0}"
    ax_json_kv mem "$_pct"
    ax_json_kv memused "$((_u / 1024))"
    ax_json_kv memtotal "$((_t / 1024))"
    ax_json_kv batt "${_bt:-0}"
    ax_json_kv temp "$((_temp / 10))"
    ax_json_kv cur "$(( (_cur / 1000) ))"
    ax_json_kv disk "$_dpct"
    ax_json_kv diskfree "$(( (ax_num "$_dfree") / 1024 ))"
    ax_json_kv nrx "${_nrx:-0}"
    ax_json_kv ntx "${_ntx:-0}"
    ax_json_end
}

ax_custom() {
    case "$1" in
    shot)
        _f="/sdcard/ax_shot_$(date +%H%M%S).png"
        if screencap -p "$_f" 2>/dev/null && [ -s "$_f" ]; then
            ax_ok "截图已保存：$_f"
            ax_result ok
        else
            ax_err "截图失败，请在系统授权后重试"
            ax_result fail
        fi
        ;;
    trim)
        ax_head "回收应用缓存"
        pm trim-caches 999999999999 2>/dev/null
        rm -rf /data/local/tmp/* 2>/dev/null
        rm -rf /sdcard/DCIM/.thumbnails 2>/dev/null
        rm -f /sdcard/*.log /sdcard/Download/*.tmp 2>/dev/null
        ax_ok "缓存回收完成"
        ax_result ok
        ;;
    restartui)
        _old=$(pidof com.android.systemui 2>/dev/null)
        killall com.android.systemui 2>/dev/null || am force-stop --user 0 com.android.systemui 2>/dev/null
        sleep 2
        _new=$(pidof com.android.systemui 2>/dev/null)
        if [ "$_old" != "$_new" ]; then
            ax_ok "SystemUI 已重启"
            ax_result ok
        else
            ax_warn "SystemUI 未重启（部分 ROM 禁止 shell 结束该系统进程）"
            ax_result ok
        fi
        ;;
    top)
        ax_head "CPU 占用 TOP 10"
        top -n 1 -b 2>/dev/null | head -16 || ps -A -o PID,PCY,NAME 2>/dev/null | head -16
        ax_result ok
        ;;
    *) return 1 ;;
    esac
}

. "$MODDIR/scripts/dispatch.sh"

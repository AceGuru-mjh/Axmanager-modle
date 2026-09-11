#!/system/bin/sh
# =============================================================================
# device_info_ax — 设备信息总览
# -----------------------------------------------------------------------------
# 纯只读：getprop / /proc / dumpsys。不修改任何系统设置，
# 因此本插件不产生回滚记录（这也是它绝对安全的原因）。
# =============================================================================
MODDIR=$(cd "${0%/*}/.." 2>/dev/null && pwd)
. "$MODDIR/scripts/axcore.sh"
ax_init "$MODDIR"

_ram_mb() { echo $(( (ax_num "$(ax_mem_field MemTotal)") / 1024 )); }
_screen() { wm size 2>/dev/null | tail -1 | sed 's/.*: //'; }
_density() { wm density 2>/dev/null | grep -oE '[0-9]+' | head -1; }
_uptime_h() { awk '{printf "%.1f", $1/3600}' /proc/uptime 2>/dev/null; }
_disk_free() { df -h /data 2>/dev/null | awk 'NR==2{print $4}'; }
_cpu_hw() { getprop ro.hardware; }
_soc() { getprop ro.board.platform; }

ax_custom() {
    case "$1" in
    dump)
        ax_head "设备"
        ax_info "机型：$(getprop ro.product.model) · 品牌 $(getprop ro.product.brand)"
        ax_info "设备代号：$(getprop ro.product.device)"
        ax_info "制造商：$(getprop ro.product.manufacturer)"
        ax_head "系统"
        ax_info "Android $(getprop ro.build.version.release) · API $(ax_api)"
        ax_info "构建号：$(getprop ro.build.display.id)"
        ax_info "安全补丁：$(getprop ro.build.version.security_patch)"
        ax_info "SELinux：$(getprop ro.build.selinux 2>/dev/null)$(getenforce 2>/dev/null)"
        ax_head "硬件"
        ax_info "平台：$(_soc) · hardware $(_cpu_hw)"
        ax_info "CPU 核心：$(ax_cpu_cores) · ABI $(getprop ro.product.cpu.abi)"
        ax_info "内存：$(_ram_mb) MB"
        ax_info "屏幕：$(_screen) · $(_density) dpi"
        ax_info "GPU：$(getprop ro.hardware.vulkan 2>/dev/null)$(getprop ro.opengles.version 2>/dev/null | sed 's/^/ OpenGL ES /')"
        ax_head "系统状态"
        ax_info "运行时间：$(_uptime_h) 小时"
        ax_info "存储可用：$(_disk_free)"
        _t=$(ax_num "$(ax_battery_field temperature)")
        ax_info "电池：$(ax_battery_field level)% · $((_t / 10))℃ · $(ax_battery_field health)"
        ax_head "运行环境"
        ax_info "运行身份：uid $(ax_uid)（$([ "$AXERON" = true ] && echo 'AxManager' || echo '未知宿主')）"
        ax_info "BusyBox：$([ -x /data/user_de/0/com.android.shell/axeron/bin/busybox ] && echo 可用 || echo 未找到)"
        ax_result ok
        ;;
    export)
        _f="/sdcard/ax_device_info.txt"
        {
            echo "=== 设备信息 $(date) ==="
            getprop | grep -E 'ro.product|ro.build|ro.board|ro.hardware' | sort
            echo ""
            echo "=== CPU / 内存 ==="
            grep -E 'processor|Hardware|model name' /proc/cpuinfo | head -8
            grep -E 'MemTotal|MemAvailable' /proc/meminfo
            echo ""
            echo "=== 电池 ==="
            dumpsys battery
            echo ""
            echo "=== 存储 ==="
            df -h
        } >"$_f" 2>&1
        [ -s "$_f" ] && ax_ok "已导出：$_f" || ax_err "导出失败"
        ax_result ok
        ;;
    sensors)
        ax_head "传感器"
        dumpsys sensorservice 2>/dev/null | grep -E 'Sensor Type|String Type' | head -30
        ax_result ok
        ;;
    features)
        ax_head "系统特性"
        pm list features 2>/dev/null | head -30
        ax_result ok
        ;;
    *) return 1 ;;
    esac
}

ax_status() {
    _t=$(ax_num "$(ax_battery_field temperature)")
    ax_json_begin
    ax_json_kv model "$(getprop ro.product.model)"
    ax_json_kv android "$(getprop ro.build.version.release)"
    ax_json_kv soc "$(_soc)"
    ax_json_kv cores "$(ax_cpu_cores)"
    ax_json_kv ram "$(_ram_mb)"
    ax_json_kv screen "$(_screen)"
    ax_json_kv level "$(ax_num "$(ax_battery_field level)")"
    ax_json_kv temp "$((_t / 10))"
    ax_json_kv uptime "$(_uptime_h)"
    ax_json_kv free "$(_disk_free)"
    ax_json_end
}

. "$MODDIR/scripts/dispatch.sh"

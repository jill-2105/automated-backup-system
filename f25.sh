#!/bin/bash
# =================================================================
# f25.sh - Automated Backup System (Fall 2025)
# =================================================================
# ====== GLOBAL VARIABLES ======
BACKUP_ROOT="/home/patel7hb/backup"
LOG_FILE="/home/patel7hb/backup/f25log.txt"
STATE_FILE="/home/patel7hb/.f25state"
PID_FILE="/home/patel7hb/.f25.pid"
# File types array (populated from args)
FILE_TYPES=()
# ====== HELPER FUNCTIONS ======
# Function to create directory structure
setup_dirs() {
    mkdir -p "$BACKUP_ROOT/fbup"
    mkdir -p "$BACKUP_ROOT/ibup"
    mkdir -p "$BACKUP_ROOT/dbup"
    mkdir -p "$BACKUP_ROOT/isbup"
}
# ====== STEP 1: Full Backup (HYBRID - Simplified + Uniqueness) ======
step1_full_backup() {
    local seq=0
    local timestamp
    local tarname
    local tarpath
    local tmp_list
    local backup_marker="fbup_init_v1"
    
    # ===== SEQUENCE TRACKING =====
    if [[ -f "$STATE_FILE" ]]; then
        seq=$(grep "fbup_seq:" "$STATE_FILE" 2>/dev/null | cut -d: -f2 | cut -d' ' -f1)
        [[ -z "$seq" ]] && seq=0
    fi
    ((seq++))
    
    tarname="fbup-${seq}.tar"
    tarpath="$BACKUP_ROOT/fbup/$tarname"
    mkdir -p "$BACKUP_ROOT/fbup"
    
    # ===== FILE COLLECTION =====
    tmp_list=$(mktemp "/tmp/f25_files.XXXXXX")
    
    if [[ "${FILE_TYPES[0]}" == "*" ]]; then
        find /home/patel7hb -type f -print0 > "$tmp_list" 2>/dev/null
    else
        for ext in "${FILE_TYPES[@]}"; do
            find /home/patel7hb -type f -name "*${ext}" -print0 >> "$tmp_list" 2>/dev/null
        done
    fi
    
    # ===== NO-FILE CHECK =====
    if [[ ! -s "$tmp_list" ]]; then
        timestamp=$(date "+%a %d %b %Y %I:%M:%S %p %Z")
        echo "$timestamp No changes-Incremental backup was not created" >> "$LOG_FILE"
        rm -f "$tmp_list"
        return 0
    fi
    
    # ===== TAR CREATION =====
    tar -cf "$tarpath" --null -T "$tmp_list" 2>/dev/null
    
    # ===== LOGGING & STATE UPDATE =====
    timestamp=$(date "+%a %d %b %Y %I:%M:%S %p %Z")
    echo "$timestamp $tarname was created" >> "$LOG_FILE"
    
    # Update state with timestamp for next steps
    echo "fbup_seq:${seq} backup_marker:${backup_marker} full_time:${timestamp}" > "$STATE_FILE"
    
    rm -f "$tmp_list"
}

# ====== STEP 2: Incremental Backup (After Step 1) ======
step2_incremental_backup() {
    local seq=0
    local timestamp
    local tarname
    local tarpath
    local tmp_list
    local ref_time=""
    local last_line
    
    # ===== SEQUENCE TRACKING =====
    if [[ -f "$STATE_FILE" ]]; then
        seq=$(grep "ibup_seq:" "$STATE_FILE" 2>/dev/null | tail -1 | cut -d: -f2 | cut -d' ' -f1)
        [[ -z "$seq" ]] && seq=0
    fi
    ((seq++))
    
    # ===== REFERENCE TIME (From Step 1) =====
    if [[ -f "$STATE_FILE" ]]; then
        last_line=$(grep "full_time:" "$STATE_FILE" 2>/dev/null | head -1)
        ref_time="${last_line#*full_time:}"
    fi
    
    if [[ -z "$ref_time" ]]; then
        timestamp=$(date "+%a %d %b %Y %I:%M:%S %p %Z")
        echo "$timestamp No changes-Incremental backup was not created" >> "$LOG_FILE"
        return 0
    fi

    tarname="ibup-${seq}.tar"
    tarpath="$BACKUP_ROOT/ibup/$tarname"
    mkdir -p "$BACKUP_ROOT/ibup"
    
    # ===== FILE COLLECTION (find -newermt) =====
    tmp_list=$(mktemp "/tmp/f25_inc_files.XXXXXX")
    
    if [[ "${FILE_TYPES[0]}" == "*" ]]; then
        find /home/patel7hb -type f -newermt "$ref_time" -print0 > "$tmp_list" 2>/dev/null
    else
        for ext in "${FILE_TYPES[@]}"; do
            find /home/patel7hb -type f -name "*${ext}" -newermt "$ref_time" -print0 >> "$tmp_list" 2>/dev/null
        done
    fi
    
    # ===== NO-FILE CHECK & TAR =====
    if [[ ! -s "$tmp_list" ]]; then
        timestamp=$(date "+%a %d %b %Y %I:%M:%S %p %Z")
        echo "$timestamp No changes-Incremental backup was not created" >> "$LOG_FILE"
        rm -f "$tmp_list"
        return 0
    fi
    
    tar -cf "$tarpath" --null -T "$tmp_list" 2>/dev/null
    
    # ===== LOGGING & STATE UPDATE =====
    timestamp=$(date "+%a %d %b %Y %I:%M:%S %p %Z")
    echo "$timestamp $tarname was created" >> "$LOG_FILE"
    
    # Append state so Step 3 can still see full_time
    echo "ibup_seq:${seq} type:incremental" >> "$STATE_FILE"
    
    rm -f "$tmp_list"
}

# ====== STEP 3: Differential Backup (Since Step 1) ======
step3_differential_backup() {
    local seq=0
    local timestamp
    local tarname
    local tarpath
    local tmp_list
    local ref_time_str=""
    local ref_seconds=0
    local last_line
    
    # ===== SEQUENCE TRACKING =====
    if [[ -f "$STATE_FILE" ]]; then
        seq=$(grep "dbup_seq:" "$STATE_FILE" 2>/dev/null | tail -1 | cut -d: -f2 | cut -d' ' -f1)
        [[ -z "$seq" ]] && seq=0
    fi
    ((seq++))
    
    # ===== REFERENCE TIME (From Step 1) =====
    if [[ -f "$STATE_FILE" ]]; then
        last_line=$(grep "full_time:" "$STATE_FILE" 2>/dev/null | head -1)
        ref_time_str="${last_line#*full_time:}"
    fi
    
    if [[ -z "$ref_time_str" ]]; then
        timestamp=$(date "+%a %d %b %Y %I:%M:%S %p %Z")
        echo "$timestamp No changes-Incremental backup was not created" >> "$LOG_FILE"
        return 0
    fi
    
    ref_seconds=$(date -d "$ref_time_str" +%s 2>/dev/null)
    
    tarname="dbup-${seq}.tar"
    tarpath="$BACKUP_ROOT/dbup/$tarname"
    mkdir -p "$BACKUP_ROOT/dbup"
    
    # ===== FILE COLLECTION (Manual Stat Loop) =====
    tmp_list=$(mktemp "/tmp/f25_diff_files.XXXXXX")
    
    if [[ "${FILE_TYPES[0]}" == "*" ]]; then
        while IFS= read -r -d '' file; do
            if [ -f "$file" ]; then
                mtime=$(stat -c %Y "$file" 2>/dev/null)
                if [[ "$mtime" -gt "$ref_seconds" ]]; then
                    echo "$file" >> "$tmp_list"
                fi
            fi
        done < <(find /home/patel7hb -type f -print0 2>/dev/null)
    else
        for ext in "${FILE_TYPES[@]}"; do
            while IFS= read -r -d '' file; do
                if [ -f "$file" ]; then
                    mtime=$(stat -c %Y "$file" 2>/dev/null)
                    if [[ "$mtime" -gt "$ref_seconds" ]]; then
                        echo "$file" >> "$tmp_list"
                    fi
                fi
            done < <(find /home/patel7hb -type f -name "*${ext}" -print0 2>/dev/null)
        done
    fi
    
    # ===== NO-FILE CHECK & TAR =====
    if [[ ! -s "$tmp_list" ]]; then
        timestamp=$(date "+%a %d %b %Y %I:%M:%S %p %Z")
        echo "$timestamp No changes-Incremental backup was not created" >> "$LOG_FILE"
        rm -f "$tmp_list"
        return 0
    fi
    
    tar -cf "$tarpath" --null --files-from="$tmp_list" 2>/dev/null
    
    timestamp=$(date "+%a %d %b %Y %I:%M:%S %p %Z")
    echo "$timestamp $tarname was created" >> "$LOG_FILE"
    
    echo "dbup_seq:${seq} type:differential" >> "$STATE_FILE"
    
    rm -f "$tmp_list"
}

# ====== STEP 4: Incremental Backup (After Step 2) ======
step4_incremental_after_step2() {
    local seq=0
    local timestamp
    local tarname
    local tarpath
    local tmp_list
    local ref_seconds=0
    local latest_ibup
    local ref_file
    
    # ===== SEQUENCE TRACKING (Shared ibup_seq) =====
    if [[ -f "$STATE_FILE" ]]; then
        seq=$(grep "ibup_seq:" "$STATE_FILE" 2>/dev/null | tail -1 | cut -d: -f2 | cut -d' ' -f1)
        [[ -z "$seq" ]] && seq=0
    fi
    ((seq++))
    
    # ===== REFERENCE TIME (From latest ibup file) =====
    if [[ -d "$BACKUP_ROOT/ibup" ]]; then
        latest_ibup=$(ls -t "$BACKUP_ROOT/ibup"/ibup-*.tar 2>/dev/null | head -1)
        if [[ -n "$latest_ibup" ]]; then
            ref_seconds=$(stat -c "%Y" "$latest_ibup" 2>/dev/null)
        fi
    fi
    [[ -z "$ref_seconds" ]] && ref_seconds=0
    
    tarname="ibup-${seq}.tar"
    tarpath="$BACKUP_ROOT/ibup/$tarname"
    mkdir -p "$BACKUP_ROOT/ibup"
    
    # ===== FILE COLLECTION (Touch Reference) =====
    tmp_list=$(mktemp "/tmp/f25_inc2_files.XXXXXX")
    ref_file=$(mktemp "/tmp/f25_ref.XXXXXX")
    
    if [[ "$ref_seconds" -gt 0 ]]; then
        touch -d "@$ref_seconds" "$ref_file"
    else
        touch -d "1970-01-01" "$ref_file"
    fi
    
    if [[ "${FILE_TYPES[0]}" == "*" ]]; then
        find /home/patel7hb -type f -newer "$ref_file" -print0 > "$tmp_list" 2>/dev/null
    else
        for ext in "${FILE_TYPES[@]}"; do
            find /home/patel7hb -type f -name "*${ext}" -newer "$ref_file" -print0 >> "$tmp_list" 2>/dev/null
        done
    fi
    
    # ===== NO-FILE CHECK & TAR =====
    if [[ ! -s "$tmp_list" ]]; then
        timestamp=$(date "+%a %d %b %Y %I:%M:%S %p %Z")
        echo "$timestamp No changes-Incremental backup was not created" >> "$LOG_FILE"
        rm -f "$tmp_list" "$ref_file"
        return 0
    fi
    
    tar -cf "$tarpath" --null -T "$tmp_list" 2>/dev/null
    
    timestamp=$(date "+%a %d %b %Y %I:%M:%S %p %Z")
    echo "$timestamp $tarname was created" >> "$LOG_FILE"
    
    echo "ibup_seq:${seq} step4_time:${timestamp}" >> "$STATE_FILE"
    
    rm -f "$tmp_list" "$ref_file"
}

# ====== STEP 5: Size-Filtered Incremental (After Step 4, >40KB) ======
step5_incremental_size_backup() {
    local seq=0
    local timestamp
    local tarname
    local tarpath
    local tmp_list
    local tmp_filtered
    local ref_time_str=""
    local size_bytes=0
    local min_size=$((40 * 1024))
    local last_line
    
    # ===== SEQUENCE TRACKING =====
    if [[ -f "$STATE_FILE" ]]; then
        seq=$(grep "isbup_seq:" "$STATE_FILE" 2>/dev/null | tail -1 | cut -d: -f2 | cut -d' ' -f1)
        [[ -z "$seq" ]] && seq=0
    fi
    ((seq++))
    
    # ===== REFERENCE TIME (From Step 4) =====
    if [[ -f "$STATE_FILE" ]]; then
        last_line=$(grep "step4_time:" "$STATE_FILE" 2>/dev/null | tail -1)
        ref_time_str="${last_line#*step4_time:}"
    fi
    
    if [[ -z "$ref_time_str" ]]; then
        timestamp=$(date "+%a %d %b %Y %I:%M:%S %p %Z")
        echo "$timestamp No changes-Incremental backup was not created" >> "$LOG_FILE"
        return 0
    fi
    
    tarname="isbup-${seq}.tar"
    tarpath="$BACKUP_ROOT/isbup/$tarname"
    mkdir -p "$BACKUP_ROOT/isbup"
    
    # ===== FILE COLLECTION (Two-Pass) =====
    tmp_list=$(mktemp "/tmp/f25_step5_raw.XXXXXX")
    tmp_filtered=$(mktemp "/tmp/f25_step5_final.XXXXXX")
    
    if [[ "${FILE_TYPES[0]}" == "*" ]]; then
        find /home/patel7hb -type f -newermt "$ref_time_str" -print0 > "$tmp_list" 2>/dev/null
    else
        for ext in "${FILE_TYPES[@]}"; do
            find /home/patel7hb -type f -name "*${ext}" -newermt "$ref_time_str" -print0 >> "$tmp_list" 2>/dev/null
        done
    fi
    
    while IFS= read -r -d '' file; do
        if [ -f "$file" ]; then
            size_bytes=$(stat -c %s "$file" 2>/dev/null)
            if [[ "$size_bytes" -gt "$min_size" ]]; then
                echo "$file" >> "$tmp_filtered"
            fi
        fi
    done < "$tmp_list"
    
    # ===== NO-FILE CHECK & TAR =====
    if [[ ! -s "$tmp_filtered" ]]; then
        timestamp=$(date "+%a %d %b %Y %I:%M:%S %p %Z")
        echo "$timestamp No changes-Incremental backup was not created" >> "$LOG_FILE"
        rm -f "$tmp_list" "$tmp_filtered"
        return 0
    fi
    
    tar -cf "$tarpath" --null --files-from="$tmp_filtered" 2>/dev/null
    
    timestamp=$(date "+%a %d %b %Y %I:%M:%S %p %Z")
    echo "$timestamp $tarname was created" >> "$LOG_FILE"
    
    echo "isbup_seq:${seq} type:size_filtered" >> "$STATE_FILE"
    
    rm -f "$tmp_list" "$tmp_filtered"
}

# =================================================================
# MAIN EXECUTION LOGIC
# =================================================================

# 1. Check for STATUS command
if [[ "$1" == "status" ]]; then
    if [[ -f "$PID_FILE" ]]; then
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo "f25.sh is running (PID: $pid)"
        else
            echo "f25.sh is not running (stale PID file)"
            rm -f "$PID_FILE"
        fi
    else
        echo "f25.sh is not running"
    fi
    exit 0
fi

# 2. Self-Backgrounding Logic
if [[ "$1" != "--daemon" ]]; then
    # Store original arguments
    original_args=("${@}")
    
    # Setup directories immediately
    setup_dirs
    
    # Clear state file on new run (optional, safer for testing)
    # rm -f "$STATE_FILE"
    
    # Run self in background
    nohup "$0" --daemon "${original_args[@]}" > /dev/null 2>&1 &
    
    # Save PID
    echo $! > "$PID_FILE"
    echo "f25.sh started in background (PID: $!)"
    exit 0
fi

# 3. DAEMON MODE (Running in background)
shift # Remove --daemon argument

# Parse File Types
if [[ $# -eq 0 ]]; then
    FILE_TYPES=("*")
else
    FILE_TYPES=("${@}")
fi

# Ensure directories exist
setup_dirs

# Log startup
timestamp=$(date "+%a %d %b %Y %I:%M:%S %p %Z")
# echo "$timestamp Daemon started" >> "$LOG_FILE"

# 4. Continuous Loop
current_step=1

while true; do
    case $current_step in
        1)
            step1_full_backup
            current_step=2
            ;;
        2)
            step2_incremental_backup
            current_step=3
            ;;
        3)
            step3_differential_backup
            current_step=4
            ;;
        4)
            step4_incremental_after_step2
            current_step=5
            ;;
        5)
            step5_incremental_size_backup
            current_step=1
            ;;
    esac
    
    # Sleep 2 minutes between steps
    sleep 10
done

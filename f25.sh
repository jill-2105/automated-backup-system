#!/bin/bash

# ====== Global Variables ======
BACKUP_ROOT="/home/patel7hb/backup"
STATE_FILE="/home/patel7hb/.f25state"
LOG_FILE="/home/patel7hb/backup/f25log.txt"
PID_FILE="/home/patel7hb/.f25.pid"

# File types to backup (from command line arguments)
FILE_TYPES=()

# ====== Helper Functions ======

# Initialize directory structure
setupdirs() {
    mkdir -p "$BACKUP_ROOT/fbup"
    mkdir -p "$BACKUP_ROOT/ibup"
    mkdir -p "$BACKUP_ROOT/dbup"
    mkdir -p "$BACKUP_ROOT/isbup"
}

# Initialize state file with counters and timestamps
initstate() {
    if [ ! -f "$STATE_FILE" ]; then
        echo "fbup=0 ibup=0 dbup=0 isbup=0" > "$STATE_FILE"
        echo "fbup_time=0 ibup_time=0 dbup_time=0 isbup_time=0" >> "$STATE_FILE"
    fi
}

# Read counter value for backup type
readcount() {
    local btype=$1
    local count=$(grep "${btype}=" "$STATE_FILE" | head -1 | cut -d'=' -f2)
    echo "$count"
}

# Write counter value for backup type
writecount() {
    local btype=$1
    local newval=$2
    sed -i "s/${btype}=[0-9]*/${btype}=${newval}/" "$STATE_FILE"
}

# Get last backup timestamp for backup type
getlasttime() {
    local btype=$1
    local timestamp=$(grep "${btype}_time=" "$STATE_FILE" | cut -d'=' -f2)
    echo "$timestamp"
}

# Save current timestamp for backup type
savelasttime() {
    local btype=$1
    local timestamp=$(date +%s)
    sed -i "s/${btype}_time=[0-9]*/${btype}_time=${timestamp}/" "$STATE_FILE"
}

# Write log entry for successful backup
writelog() {
    local tarname=$1
    local timestamp=$(date "+%a %d %b %Y %I:%M:%S %p %Z")
    echo "$timestamp $tarname was created" >> "$LOG_FILE"
}

# Write log entry when no changes detected
writenolog() {
    local timestamp=$(date "+%a %d %b %Y %I:%M:%S %p %Z")
    echo "$timestamp No changes-Incremental backup was not created" >> "$LOG_FILE"
}

# ====== Status Command ======
if [ "$1" = "status" ]; then
    if [ -f "$PID_FILE" ]; then
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo "f25.sh is running (PID: $pid)"
        else
            echo "f25.sh is not running (stale PID file)"
            rm "$PID_FILE"
        fi
    else
        echo "f25.sh is not running"
    fi
    exit 0
fi

# ====== Self-Backgrounding Logic ======
if [ "$1" != "--daemon" ]; then
    # Not running as daemon yet, background ourselves
    original_args=("${@}")

    # Setup directories and state before backgrounding
    setupdirs
    initstate

    # Restart script in background with daemon flag
    nohup "$0" --daemon "${original_args[@]}" > /dev/null 2>&1 &

    # Save PID for status checking
    echo $! > "$PID_FILE"

    echo "f25.sh started in background (PID: $!)"
    exit 0
fi

# ====== Main Daemon Execution ======
# If we reach here, we're running as daemon
shift  # Remove --daemon flag

# Parse file type arguments
if [ $# -eq 0 ]; then
    # No arguments - backup all file types
    FILE_TYPES=("*")
else
    # Store provided file types
    FILE_TYPES=("${@}")
fi

# Ensure directories exist
setupdirs
initstate

echo "Daemon started with file types: ${FILE_TYPES[@]}" >> "$LOG_FILE"

# ====== Main Loop (Placeholder for Phase 2) ======
current_step=1

while true; do
    case $current_step in
        1)
            echo "Step 1: Full backup would run here"
            sleep 120
            current_step=2
            ;;
        2)
            echo "Step 2: Incremental backup would run here"
            sleep 120
            current_step=3
            ;;
        3)
            echo "Step 3: Differential backup would run here"
            sleep 120
            current_step=4
            ;;
        4)
            echo "Step 4: Incremental backup would run here"
            sleep 120
            current_step=5
            ;;
        5)
            echo "Step 5: Size-filtered backup would run here"
            sleep 120
            current_step=1
            ;;
    esac
done
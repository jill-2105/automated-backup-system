# Automated Backup System (f25.sh)

## Overview

The **f25.sh** script is an automated backup system that implements a sophisticated multi-level backup strategy. It creates and manages full backups, incremental backups, differential backups, and incremental-since-backup backups to efficiently store and track file changes over time.

## Features

- **Full Backup (FBup)**: Complete backup of all specified files
- **Incremental Backup (IBup)**: Backs up files modified since the previous backup
- **Differential Backup (DBup)**: Backs up files modified since the last full backup
- **Incremental-Since-Backup (ISBup)**: Incremental backups of files modified since the last differential backup
- **Flexible File Type Selection**: Specify file types to back up (e.g., `.txt`, `.pdf`) or use `*` for all files
- **Comprehensive Logging**: Detailed logs track all backup operations with timestamps
- **State Management**: Maintains state files to track backup sequences and timing information

## Requirements

- **OS**: Linux/Unix-based system (uses bash, tar, find, etc.)
- **Directories**: 
  - Backup location: `/home/patel7hb/backup`
  - Working directory: `/home/patel7hb`
- **Permissions**: Write access to home directory and backup directories

## Installation & Usage

### Basic Syntax

```bash
./f25.sh [file_type1] [file_type2] ...
```

### Parameters

- **file_type**: File extension(s) to back up (e.g., `.txt`, `.pdf`)
- Use `*` to back up all files in the home directory

### Example Commands

```bash
# Backup only .txt and .pdf files
./f25.sh .txt .pdf

# Backup all files
./f25.sh *
```

## How It Works

### Backup Levels

1. **Full Backup (fbup)**: Creates a complete snapshot of all files matching the specified types
   - Stored as: `fbup-{seq}.tar`
   - Runs on the first execution

2. **Incremental Backup (ibup)**: Captures files modified since the previous backup
   - Stored as: `ibup-{seq}.tar`
   - References the timestamp from the full backup

3. **Differential Backup (dbup)**: Captures files modified since the last full backup
   - Stored as: `dbup-{seq}.tar`
   - Provides a reference point for ISBup

4. **Incremental-Since-Backup (isbup)**: Captures files modified since the last differential backup
   - Stored as: `isbup-{seq}.tar`
   - Most efficient for frequent backups

### File Organization

```
~/backup/
├── fbup/           # Full backups
│   └── fbup-1.tar
├── ibup/           # Incremental backups
│   └── ibup-1.tar
├── dbup/           # Differential backups
│   └── dbup-1.tar
├── isbup/          # Incremental-since-backup backups
│   └── isbup-1.tar
└── f25log.txt      # Detailed operation log
```

### State Management

- **~/.f25state**: Stores backup sequence numbers and timestamps for reference
- **~/.f25.pid**: Process ID file for daemon management
- **~/backup/f25log.txt**: Comprehensive log of all operations

## Test Procedure

### Terminal 1 (Monitoring)

```bash
echo "=== MONITORING LOG ==="
while [ ! -f ~/backup/f25log.txt ]; do 
  sleep 0.5
done
tail -f ~/backup/f25log.txt
```

### Terminal 2 (Testing)

1. **Setup**: Clean previous backups
   ```bash
   rm -rf ~/testbackup
   ```

2. **Start the daemon**:
   ```bash
   ./f25.sh .txt .pdf
   ```

3. **Create new file** (wait for fbup-1.tar):
   ```bash
   echo "new file c" > ~/test_data/c.txt
   ```

4. **Create another new file** (wait for ibup-1.tar):
   ```bash
   echo "diff file d" > ~/test_data/d.pdf
   ```

5. **Modify existing file** (wait for dbup-1.tar):
   ```bash
   echo "update to c" >> ~/test_data/c.txt
   ```

6. **Create large file** (wait for ibup-2.tar):
   ```bash
   dd if=/dev/zero of=~/test_data/big.txt bs=1024 count=50
   ```

7. **Final backup** (wait for isbup-1.tar):
   ```bash
   # Script will complete automatically
   ```

## Log Output Example

```
Mon 07 Dec 2025 02:45:30 PM UTC fbup-1.tar was created
Mon 07 Dec 2025 02:45:31 PM UTC ibup-1.tar was created
Mon 07 Dec 2025 02:45:32 PM UTC dbup-1.tar was created
Mon 07 Dec 2025 02:45:33 PM UTC ibup-2.tar was created
Mon 07 Dec 2025 02:45:34 PM UTC isbup-1.tar was created
```

## Troubleshooting

### No backups created
- Verify files exist matching the specified file types
- Check directory permissions: `ls -la ~/backup`
- Ensure `find` command can access the directory

### Permission denied errors
- Make script executable: `chmod +x f25.sh`
- Verify write permissions to backup directory

### Check log file
- Monitor real-time logs: `tail -f ~/backup/f25log.txt`
- View all logs: `cat ~/backup/f25log.txt`

## Notes

- Backup sequences are tracked independently for each backup level
- State file maintains references for consistency across backup levels
- The system handles empty file lists gracefully (no backup created if no changes detected)
- Timestamps follow the format: `Day DD Mon YYYY HH:MM:SS AM/PM TIMEZONE`

## Course Information

- **Institution**: University of Windsor
- **Course**: COMP 8567 - Advanced Systems Programming
- **Semester**: Term 2 (Fall 2025)

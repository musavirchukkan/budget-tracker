#!/bin/bash

# Database Backup Script for Budget Tracker
# Run this script daily via cron job

set -e

# Configuration
BACKUP_DIR="/var/www/budget-tracker/backups"
DB_NAME="budget_tracker"
DB_USER="budget_user"
RETENTION_DAYS=7
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="budget_tracker_${DATE}.sql"
LOG_FILE="/var/log/backup.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Logging function
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1" | tee -a "$LOG_FILE"
}

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

log "🗄️ Starting database backup..."

# Check if PostgreSQL is running
if ! pgrep -x postgres >/dev/null; then
    log_error "PostgreSQL is not running"
    exit 1
fi

# Create database backup
log "Creating backup: $BACKUP_FILE"
if sudo -u postgres pg_dump "$DB_NAME" > "$BACKUP_DIR/$BACKUP_FILE"; then
    log "✅ Database backup created successfully"
    
    # Compress backup
    if gzip "$BACKUP_DIR/$BACKUP_FILE"; then
        log "✅ Backup compressed: ${BACKUP_FILE}.gz"
        BACKUP_FILE="${BACKUP_FILE}.gz"
    else
        log_warning "Failed to compress backup"
    fi
    
    # Get backup size
    BACKUP_SIZE=$(du -h "$BACKUP_DIR/$BACKUP_FILE" | cut -f1)
    log "📊 Backup size: $BACKUP_SIZE"
    
else
    log_error "Failed to create database backup"
    exit 1
fi

# Clean up old backups
log "🧹 Cleaning up old backups (keeping last $RETENTION_DAYS days)..."
find "$BACKUP_DIR" -name "budget_tracker_*.sql*" -mtime +$RETENTION_DAYS -delete
REMAINING_BACKUPS=$(find "$BACKUP_DIR" -name "budget_tracker_*.sql*" | wc -l)
log "📁 Remaining backups: $REMAINING_BACKUPS"

# Create backup manifest
cat > "$BACKUP_DIR/latest.json" << EOF
{
    "latest_backup": "$BACKUP_FILE",
    "created_at": "$(date -Iseconds)",
    "size": "$BACKUP_SIZE",
    "database": "$DB_NAME",
    "retention_days": $RETENTION_DAYS,
    "total_backups": $REMAINING_BACKUPS
}
EOF

# Test backup integrity (optional)
log "🔍 Testing backup integrity..."
if gzip -t "$BACKUP_DIR/$BACKUP_FILE" 2>/dev/null; then
    log "✅ Backup integrity test passed"
else
    log_error "Backup integrity test failed"
fi

# Optional: Upload to cloud storage (uncomment if needed)
# upload_to_s3() {
#     if command -v aws >/dev/null 2>&1; then
#         log "☁️ Uploading backup to S3..."
#         aws s3 cp "$BACKUP_DIR/$BACKUP_FILE" "s3://your-backup-bucket/budget-tracker/" || log_warning "S3 upload failed"
#     fi
# }
# upload_to_s3

log "🎉 Backup process completed successfully!"

# Send notification (optional)
# if command -v curl >/dev/null 2>&1; then
#     curl -X POST "https://hooks.slack.com/your-webhook-url" \
#         -H 'Content-type: application/json' \
#         --data "{\"text\":\"✅ Budget Tracker backup completed: $BACKUP_FILE ($BACKUP_SIZE)\"}" || true
# fi

exit 0
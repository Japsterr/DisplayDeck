#!/bin/bash

# Database Backup and Restore Script for DisplayDeck
# Supports PostgreSQL with S3 storage and local backups

set -euo pipefail

# Configuration
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-displaydeck_prod}"
DB_USER="${DB_USER:-displaydeck_user}"
DB_PASSWORD="${DB_PASSWORD:-}"
DB_PASSWORD_FILE="${DB_PASSWORD_FILE:-}"

BACKUP_DIR="${BACKUP_DIR:-/backups}"
BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"
BACKUP_RETENTION_WEEKS="${BACKUP_RETENTION_WEEKS:-4}"
BACKUP_RETENTION_MONTHS="${BACKUP_RETENTION_MONTHS:-12}"

# S3 Configuration
S3_BUCKET="${S3_BUCKET:-}"
AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-}"
AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-}"
AWS_ACCESS_KEY_ID_FILE="${AWS_ACCESS_KEY_ID_FILE:-}"
AWS_SECRET_ACCESS_KEY_FILE="${AWS_SECRET_ACCESS_KEY_FILE_FILE:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Load password from file if specified
load_credentials() {
    if [[ -n "$DB_PASSWORD_FILE" && -f "$DB_PASSWORD_FILE" ]]; then
        DB_PASSWORD=$(cat "$DB_PASSWORD_FILE")
    fi
    
    if [[ -n "$AWS_ACCESS_KEY_ID_FILE" && -f "$AWS_ACCESS_KEY_ID_FILE" ]]; then
        AWS_ACCESS_KEY_ID=$(cat "$AWS_ACCESS_KEY_ID_FILE")
    fi
    
    if [[ -n "$AWS_SECRET_ACCESS_KEY_FILE" && -f "$AWS_SECRET_ACCESS_KEY_FILE" ]]; then
        AWS_SECRET_ACCESS_KEY=$(cat "$AWS_SECRET_ACCESS_KEY_FILE")
    fi
}

# Check dependencies
check_dependencies() {
    local missing_deps=()
    
    if ! command -v pg_dump &> /dev/null; then
        missing_deps+=("postgresql-client")
    fi
    
    if ! command -v gzip &> /dev/null; then
        missing_deps+=("gzip")
    fi
    
    if [[ -n "$S3_BUCKET" ]] && ! command -v aws &> /dev/null; then
        missing_deps+=("awscli")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        error "Missing dependencies: ${missing_deps[*]}"
        info "Install with: apt-get install -y ${missing_deps[*]}"
        exit 1
    fi
}

# Setup directories
setup_directories() {
    mkdir -p "$BACKUP_DIR"/{daily,weekly,monthly}
    
    if [[ ! -w "$BACKUP_DIR" ]]; then
        error "Backup directory is not writable: $BACKUP_DIR"
        exit 1
    fi
}

# Configure AWS CLI if S3 is used
configure_aws() {
    if [[ -n "$S3_BUCKET" ]]; then
        if [[ -z "$AWS_ACCESS_KEY_ID" || -z "$AWS_SECRET_ACCESS_KEY" ]]; then
            error "S3 bucket specified but AWS credentials not provided"
            exit 1
        fi
        
        aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID"
        aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY"
        aws configure set default.region "${AWS_DEFAULT_REGION:-us-east-1}"
        aws configure set default.output json
        
        # Test S3 access
        if ! aws s3 ls "s3://$S3_BUCKET" &> /dev/null; then
            error "Cannot access S3 bucket: $S3_BUCKET"
            exit 1
        fi
        
        log "AWS CLI configured for S3 bucket: $S3_BUCKET"
    fi
}

# Create database backup
create_backup() {
    local backup_type="$1"  # daily, weekly, monthly
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$BACKUP_DIR/${backup_type}/displaydeck_${backup_type}_${timestamp}.sql"
    local compressed_file="${backup_file}.gz"
    
    log "Creating $backup_type backup..."
    
    # Set PGPASSWORD if password is provided
    if [[ -n "$DB_PASSWORD" ]]; then
        export PGPASSWORD="$DB_PASSWORD"
    fi
    
    # Create backup with pg_dump
    if pg_dump \
        --host="$DB_HOST" \
        --port="$DB_PORT" \
        --username="$DB_USER" \
        --dbname="$DB_NAME" \
        --no-password \
        --verbose \
        --clean \
        --if-exists \
        --create \
        --format=plain \
        --encoding=UTF8 \
        > "$backup_file" 2>/tmp/pg_dump.log; then
        
        # Compress backup
        gzip "$backup_file"
        
        # Calculate file size
        local file_size=$(du -h "$compressed_file" | cut -f1)
        log "$backup_type backup created: $(basename "$compressed_file") (${file_size})"
        
        # Upload to S3 if configured
        if [[ -n "$S3_BUCKET" ]]; then
            upload_to_s3 "$compressed_file" "$backup_type"
        fi
        
        # Create checksum
        sha256sum "$compressed_file" > "${compressed_file}.sha256"
        
        echo "$compressed_file"
    else
        error "Failed to create $backup_type backup"
        cat /tmp/pg_dump.log
        exit 1
    fi
    
    # Unset PGPASSWORD
    unset PGPASSWORD
}

# Upload backup to S3
upload_to_s3() {
    local backup_file="$1"
    local backup_type="$2"
    local s3_key="displaydeck/${backup_type}/$(basename "$backup_file")"
    
    log "Uploading to S3: s3://$S3_BUCKET/$s3_key"
    
    if aws s3 cp "$backup_file" "s3://$S3_BUCKET/$s3_key" \
        --storage-class STANDARD_IA \
        --metadata "backup-type=$backup_type,created=$(date -Iseconds)"; then
        
        log "Upload successful: s3://$S3_BUCKET/$s3_key"
        
        # Upload checksum
        aws s3 cp "${backup_file}.sha256" "s3://$S3_BUCKET/${s3_key}.sha256"
    else
        error "Failed to upload to S3"
        return 1
    fi
}

# Restore database from backup
restore_database() {
    local backup_file="$1"
    local target_db="${2:-$DB_NAME}"
    
    if [[ ! -f "$backup_file" ]]; then
        error "Backup file not found: $backup_file"
        exit 1
    fi
    
    warning "This will restore database '$target_db' from backup: $(basename "$backup_file")"
    read -p "Are you sure? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log "Restore cancelled"
        exit 0
    fi
    
    log "Restoring database from backup..."
    
    # Set PGPASSWORD if password is provided
    if [[ -n "$DB_PASSWORD" ]]; then
        export PGPASSWORD="$DB_PASSWORD"
    fi
    
    # Decompress if needed
    local sql_file="$backup_file"
    if [[ "$backup_file" == *.gz ]]; then
        sql_file="${backup_file%.gz}"
        gunzip -c "$backup_file" > "$sql_file"
    fi
    
    # Restore database
    if psql \
        --host="$DB_HOST" \
        --port="$DB_PORT" \
        --username="$DB_USER" \
        --dbname=postgres \
        --no-password \
        --file="$sql_file" \
        --single-transaction \
        --set ON_ERROR_STOP=on \
        2>/tmp/psql_restore.log; then
        
        log "Database restored successfully"
        
        # Clean up decompressed file if it was created
        if [[ "$backup_file" == *.gz ]]; then
            rm -f "$sql_file"
        fi
    else
        error "Failed to restore database"
        cat /tmp/psql_restore.log
        exit 1
    fi
    
    unset PGPASSWORD
}

# Download backup from S3
download_from_s3() {
    local s3_path="$1"
    local local_path="$2"
    
    log "Downloading from S3: $s3_path"
    
    if aws s3 cp "$s3_path" "$local_path"; then
        log "Downloaded: $(basename "$local_path")"
        
        # Download and verify checksum if available
        if aws s3 cp "${s3_path}.sha256" "${local_path}.sha256" 2>/dev/null; then
            if sha256sum -c "${local_path}.sha256"; then
                log "Checksum verified"
            else
                warning "Checksum verification failed"
            fi
        fi
        
        echo "$local_path"
    else
        error "Failed to download from S3"
        return 1
    fi
}

# Clean up old backups
cleanup_backups() {
    log "Cleaning up old backups..."
    
    # Daily backups - keep for specified days
    find "$BACKUP_DIR/daily" -name "*.gz" -mtime +$BACKUP_RETENTION_DAYS -delete
    find "$BACKUP_DIR/daily" -name "*.sha256" -mtime +$BACKUP_RETENTION_DAYS -delete
    
    # Weekly backups - keep for specified weeks
    local weeks_in_days=$((BACKUP_RETENTION_WEEKS * 7))
    find "$BACKUP_DIR/weekly" -name "*.gz" -mtime +$weeks_in_days -delete
    find "$BACKUP_DIR/weekly" -name "*.sha256" -mtime +$weeks_in_days -delete
    
    # Monthly backups - keep for specified months (approximate)
    local months_in_days=$((BACKUP_RETENTION_MONTHS * 30))
    find "$BACKUP_DIR/monthly" -name "*.gz" -mtime +$months_in_days -delete
    find "$BACKUP_DIR/monthly" -name "*.sha256" -mtime +$months_in_days -delete
    
    log "Backup cleanup completed"
}

# List available backups
list_backups() {
    log "Local backups in $BACKUP_DIR:"
    
    echo ""
    echo "Daily backups:"
    ls -lh "$BACKUP_DIR/daily"/*.gz 2>/dev/null || echo "  No daily backups found"
    
    echo ""
    echo "Weekly backups:"
    ls -lh "$BACKUP_DIR/weekly"/*.gz 2>/dev/null || echo "  No weekly backups found"
    
    echo ""
    echo "Monthly backups:"
    ls -lh "$BACKUP_DIR/monthly"/*.gz 2>/dev/null || echo "  No monthly backups found"
    
    if [[ -n "$S3_BUCKET" ]]; then
        echo ""
        echo "S3 backups:"
        aws s3 ls "s3://$S3_BUCKET/displaydeck/" --recursive --human-readable 2>/dev/null || echo "  Cannot list S3 backups"
    fi
}

# Verify backup integrity
verify_backup() {
    local backup_file="$1"
    
    if [[ ! -f "$backup_file" ]]; then
        error "Backup file not found: $backup_file"
        return 1
    fi
    
    log "Verifying backup integrity: $(basename "$backup_file")"
    
    # Check if file is a valid gzip file
    if [[ "$backup_file" == *.gz ]]; then
        if gzip -t "$backup_file"; then
            log "Gzip integrity: OK"
        else
            error "Gzip integrity: FAILED"
            return 1
        fi
    fi
    
    # Check checksum if available
    if [[ -f "${backup_file}.sha256" ]]; then
        if sha256sum -c "${backup_file}.sha256"; then
            log "Checksum: OK"
        else
            error "Checksum: FAILED"
            return 1
        fi
    fi
    
    # Basic SQL syntax check (for uncompressed files)
    local sql_file="$backup_file"
    local temp_file=""
    
    if [[ "$backup_file" == *.gz ]]; then
        temp_file=$(mktemp)
        gunzip -c "$backup_file" > "$temp_file"
        sql_file="$temp_file"
    fi
    
    if head -n 10 "$sql_file" | grep -q "PostgreSQL database dump"; then
        log "SQL format: OK"
    else
        warning "SQL format: Cannot verify PostgreSQL dump header"
    fi
    
    # Clean up temp file
    if [[ -n "$temp_file" ]]; then
        rm -f "$temp_file"
    fi
    
    log "Backup verification completed"
}

# Show usage information
show_usage() {
    cat << EOF
Usage: $0 [COMMAND] [OPTIONS]

Commands:
    daily               Create daily backup
    weekly              Create weekly backup  
    monthly             Create monthly backup
    restore <file>      Restore from backup file
    download <s3_path>  Download backup from S3
    list               List available backups
    verify <file>      Verify backup integrity
    cleanup            Clean up old backups
    help               Show this help message

Environment Variables:
    DB_HOST                    Database host (default: localhost)
    DB_PORT                    Database port (default: 5432)
    DB_NAME                    Database name (default: displaydeck_prod)
    DB_USER                    Database user (default: displaydeck_user)
    DB_PASSWORD               Database password
    DB_PASSWORD_FILE          File containing database password
    BACKUP_DIR                Backup directory (default: /backups)
    BACKUP_RETENTION_DAYS     Daily backup retention (default: 30)
    BACKUP_RETENTION_WEEKS    Weekly backup retention (default: 4)
    BACKUP_RETENTION_MONTHS   Monthly backup retention (default: 12)
    S3_BUCKET                 S3 bucket for remote storage
    AWS_ACCESS_KEY_ID         AWS access key
    AWS_SECRET_ACCESS_KEY     AWS secret key

Examples:
    $0 daily                                    # Create daily backup
    $0 restore /backups/daily/backup.sql.gz   # Restore from local backup
    $0 download s3://bucket/backup.sql.gz      # Download and restore from S3
    $0 verify /backups/daily/backup.sql.gz     # Verify backup integrity
    $0 list                                    # List all available backups

EOF
}

# Main execution
main() {
    local command="${1:-}"
    
    case "$command" in
        "daily"|"weekly"|"monthly")
            load_credentials
            check_dependencies
            setup_directories
            configure_aws
            create_backup "$command"
            cleanup_backups
            ;;
        "restore")
            if [[ -z "${2:-}" ]]; then
                error "Restore requires backup file path"
                show_usage
                exit 1
            fi
            load_credentials
            check_dependencies
            restore_database "$2" "${3:-}"
            ;;
        "download")
            if [[ -z "${2:-}" ]]; then
                error "Download requires S3 path"
                show_usage
                exit 1
            fi
            load_credentials
            setup_directories
            configure_aws
            local_file="$BACKUP_DIR/$(basename "$2")"
            download_from_s3 "$2" "$local_file"
            ;;
        "list")
            load_credentials
            if [[ -n "$S3_BUCKET" ]]; then
                configure_aws
            fi
            list_backups
            ;;
        "verify")
            if [[ -z "${2:-}" ]]; then
                error "Verify requires backup file path"
                show_usage
                exit 1
            fi
            verify_backup "$2"
            ;;
        "cleanup")
            setup_directories
            cleanup_backups
            ;;
        "help"|"--help"|"-h")
            show_usage
            ;;
        *)
            error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Handle script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
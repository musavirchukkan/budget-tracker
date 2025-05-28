#!/bin/bash

# Deployment script for Budget Tracker
# This script handles the complete deployment process

set -e  # Exit on any error

echo "🚀 Starting deployment process..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   print_error "This script should not be run as root"
   exit 1
fi

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | xargs)
    print_status "Environment variables loaded"
else
    print_error ".env file not found"
    exit 1
fi

# Stop services
print_status "Stopping services..."
sudo systemctl stop gunicorn || true
sudo systemctl stop nginx || true

# Backup database
print_status "Creating database backup..."
sudo -u postgres pg_dump budget_tracker > "backup_$(date +%Y%m%d_%H%M%S).sql" || true

# Update Python dependencies
print_status "Updating backend dependencies..."
cd backend
python3 -m pip install --upgrade pip
python3 -m pip install -r requirements.txt --user
cd ..

# Update Node dependencies and build frontend
print_status "Building frontend..."
cd frontend
npm ci --production
npm run build
cd ..

# Copy built frontend to nginx directory
print_status "Copying frontend files..."
sudo rm -rf /var/www/html/budget-tracker/*
sudo cp -r frontend/dist/* /var/www/html/budget-tracker/
sudo chown -R www-data:www-data /var/www/html/budget-tracker/

# Django operations
print_status "Running Django operations..."
cd backend
python3 manage.py collectstatic --noinput
python3 manage.py makemigrations
python3 manage.py migrate
cd ..

# Update file permissions
print_status "Updating permissions..."
sudo chown -R $USER:www-data /var/www/budget-tracker/
sudo chmod -R 755 /var/www/budget-tracker/
sudo chmod -R 775 backend/staticfiles/

# Restart services
print_status "Restarting services..."
sudo systemctl daemon-reload
sudo systemctl start gunicorn
sudo systemctl enable gunicorn
sudo systemctl start nginx
sudo systemctl enable nginx

# Wait for services to start
sleep 5

# Health checks
print_status "Performing health checks..."

# Check if Gunicorn is running
if ! pgrep -f gunicorn > /dev/null; then
    print_error "Gunicorn is not running"
    sudo journalctl -u gunicorn -n 20
    exit 1
fi

# Check if Nginx is running
if ! pgrep nginx > /dev/null; then
    print_error "Nginx is not running"
    sudo journalctl -u nginx -n 20
    exit 1
fi

# Check database connection
cd backend
if ! python3 manage.py check --database default; then
    print_error "Database connection failed"
    exit 1
fi
cd ..

# Test API endpoint
if ! curl -f http://localhost:8000/api/health/ > /dev/null 2>&1; then
    print_warning "API health check failed, but continuing..."
fi

# Clean up old backups (keep last 5)
print_status "Cleaning up old backups..."
ls -t backup_*.sql 2>/dev/null | tail -n +6 | xargs -r rm

print_status "🎉 Deployment completed successfully!"
print_status "Frontend: https://${DOMAIN_NAME}"
print_status "API: https://${DOMAIN_NAME}/api"
print_status "Admin: https://${DOMAIN_NAME}/admin"

echo "📊 Service Status:"
sudo systemctl status gunicorn --no-pager -l
sudo systemctl status nginx --no-pager -l
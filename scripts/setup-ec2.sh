#!/bin/bash

# EC2 Initial Setup Script for Budget Tracker
# Run this script on your EC2 instance to set up the environment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}==== $1 ====${NC}"
}

# Check if running as ubuntu user
if [ "$USER" != "ubuntu" ] && [ "$USER" != "ec2-user" ]; then
    print_warning "This script is designed for ubuntu/ec2-user. Current user: $USER"
fi

print_header "BUDGET TRACKER EC2 SETUP"

# Update system
print_status "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install required packages
print_status "Installing required packages..."
sudo apt install -y \
    python3 \
    python3-pip \
    python3-venv \
    postgresql \
    postgresql-contrib \
    nginx \
    git \
    curl \
    wget \
    htop \
    unzip \
    certbot \
    python3-certbot-nginx

# Install Node.js 18
print_status "Installing Node.js 18..."
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Verify installations
print_status "Verifying installations..."
python3 --version
node --version
npm --version
psql --version

# Setup PostgreSQL
print_header "SETTING UP POSTGRESQL"
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Get database password from user
echo -n "Enter a secure password for the database user: "
read -s DB_PASSWORD
echo

# Create database and user
print_status "Creating database and user..."
sudo -u postgres psql << EOF
CREATE DATABASE budget_tracker;
CREATE USER budget_user WITH PASSWORD '$DB_PASSWORD';
ALTER ROLE budget_user SET client_encoding TO 'utf8';
ALTER ROLE budget_user SET default_transaction_isolation TO 'read committed';
ALTER ROLE budget_user SET timezone TO 'UTC';
GRANT ALL PRIVILEGES ON DATABASE budget_tracker TO budget_user;
\q
EOF

# Create application directory
print_status "Creating application directory..."
sudo mkdir -p /var/www/budget-tracker
sudo chown $USER:www-data /var/www/budget-tracker
cd /var/www/budget-tracker

# Clone repository (you'll need to replace with your repo URL)
print_status "Enter your GitHub repository URL:"
read REPO_URL
git clone $REPO_URL .

# Create Python virtual environment
print_status "Creating Python virtual environment..."
python3 -m venv venv
source venv/bin/activate

# Install Python dependencies
print_status "Installing Python dependencies..."
pip install --upgrade pip
pip install -r backend/requirements.txt
pip install gunicorn psycopg2-binary

# Install Node dependencies
print_status "Installing Node dependencies..."
cd frontend
npm install
npm run build
cd ..

# Create environment file
print_status "Creating environment configuration..."
cat > .env << EOF
SECRET_KEY=your-secret-key-here-change-this-in-production
DEBUG=False
ALLOWED_HOSTS=localhost,127.0.0.1,your-domain.com
DATABASE_URL=postgresql://budget_user:$DB_PASSWORD@localhost:5432/budget_tracker
VITE_API_URL=https://your-domain.com/api
EOF

print_warning "Please edit .env file with your actual domain and secret key!"

# Setup Django
print_status "Setting up Django..."
cd backend
python3 manage.py makemigrations
python3 manage.py migrate
python3 manage.py collectstatic --noinput
python3 manage.py create_test_data
cd ..

# Create Gunicorn service
print_status "Creating Gunicorn service..."
sudo tee /etc/systemd/system/gunicorn.service > /dev/null << EOF
[Unit]
Description=gunicorn daemon for Budget Tracker
After=network.target

[Service]
User=$USER
Group=www-data
WorkingDirectory=/var/www/budget-tracker/backend
ExecStart=/var/www/budget-tracker/venv/bin/gunicorn --access-logfile - --workers 3 --bind 127.0.0.1:8000 budget_tracker.wsgi:application
ExecReload=/bin/kill -s HUP \$MAINPID
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Create Nginx configuration
print_status "Creating Nginx configuration..."
sudo mkdir -p /var/www/html/budget-tracker

# Copy built frontend files
sudo cp -r frontend/dist/* /var/www/html/budget-tracker/
sudo chown -R www-data:www-data /var/www/html/budget-tracker/

# Create Nginx site configuration
sudo tee /etc/nginx/sites-available/budget-tracker > /dev/null << 'EOF'
server {
    listen 80;
    server_name your-domain.com www.your-domain.com;
    
    # Frontend
    location / {
        root /var/www/html/budget-tracker;
        index index.html;
        try_files $uri $uri/ /index.html;
    }
    
    # API
    location /api/ {
        proxy_pass http://127.0.0.1:8000/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # Admin
    location /admin/ {
        proxy_pass http://127.0.0.1:8000/admin/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # Static files
    location /static/ {
        alias /var/www/budget-tracker/backend/staticfiles/;
    }
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
}
EOF

# Enable Nginx site
sudo ln -sf /etc/nginx/sites-available/budget-tracker /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Test Nginx configuration
sudo nginx -t

# Start services
print_status "Starting services..."
sudo systemctl daemon-reload
sudo systemctl start gunicorn
sudo systemctl enable gunicorn
sudo systemctl restart nginx
sudo systemctl enable nginx

# Setup firewall
print_status "Configuring firewall..."
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw --force enable

print_header "SETUP COMPLETED!"
echo
print_status "✅ Database: PostgreSQL configured"
print_status "✅ Application: Deployed to /var/www/budget-tracker"
print_status "✅ Services: Gunicorn and Nginx configured"
print_status "✅ Firewall: UFW configured"
echo
print_warning "📝 NEXT STEPS:"
echo "1. Update your domain DNS to point to this EC2 instance"
echo "2. Edit /var/www/budget-tracker/.env with your actual domain"
echo "3. Update Nginx config with your domain: sudo nano /etc/nginx/sites-available/budget-tracker"
echo "4. Restart Nginx: sudo systemctl restart nginx"
echo "5. Setup SSL certificate: sudo certbot --nginx -d your-domain.com -d www.your-domain.com"
echo "6. Add GitHub secrets for CI/CD deployment"
echo
print_status "Test credentials:"
echo "Email: test@example.com"
echo "Password: testpass123"
echo
print_status "Database password (save this): $DB_PASSWORD"
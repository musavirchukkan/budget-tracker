#!/bin/bash

# 🎯 ONE-COMMAND LOCAL SETUP FOR INTERVIEWERS
# This script sets up the entire Budget Tracker application locally with Docker

set -e

# Colors for beautiful output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Emojis for better UX
ROCKET="🚀"
CHECK="✅"
WARNING="⚠️"
INFO="ℹ️"
FIRE="🔥"
COMPUTER="💻"
DATABASE="🗄️"
FRONTEND="🎨"
BACKEND="⚙️"

print_header() {
    echo -e "\n${BLUE}==== $1 ====${NC}"
}

print_success() {
    echo -e "${GREEN}${CHECK} $1${NC}"
}

print_info() {
    echo -e "${CYAN}${INFO} $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}${WARNING} $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_step() {
    echo -e "${PURPLE}${ROCKET} $1${NC}"
}

# ASCII Art Banner
print_banner() {
    echo -e "${CYAN}"
    cat << "EOF"
    ____            __            __     ______                __            
   / __ )__  ______/ /___ ____  / /_   /_  __/________ ______/ /_____  _____
  / __  / / / / __  / __ `/ _ \/ __/    / / / ___/ __ `/ ___/ //_/ _ \/ ___/
 / /_/ / /_/ / /_/ / /_/ /  __/ /_     / / / /  / /_/ / /__/ ,< /  __/ /    
/_____/\__,_/\__,_/\__, /\___/\__/    /_/ /_/   \__,_/\___/_/|_|\___/_/     
                  /____/                                                    
EOF
    echo -e "${NC}"
    echo -e "${GREEN}${FIRE} Personal Budget Tracker - Interview Setup ${FIRE}${NC}\n"
}

# Check prerequisites
check_prerequisites() {
    print_header "CHECKING PREREQUISITES"
    
    # Check Docker
    if command -v docker >/dev/null 2>&1; then
        DOCKER_VERSION=$(docker --version | cut -d' ' -f3 | cut -d',' -f1)
        print_success "Docker found: $DOCKER_VERSION"
    else
        print_error "Docker is not installed!"
        echo -e "${YELLOW}Please install Docker Desktop from: https://www.docker.com/products/docker-desktop${NC}"
        exit 1
    fi
    
    # Check Docker Compose
    if command -v docker-compose >/dev/null 2>&1; then
        COMPOSE_VERSION=$(docker-compose --version | cut -d' ' -f3 | cut -d',' -f1)
        print_success "Docker Compose found: $COMPOSE_VERSION"
    else
        print_error "Docker Compose is not installed!"
        echo -e "${YELLOW}Please install Docker Compose from: https://docs.docker.com/compose/install/${NC}"
        exit 1
    fi
    
    # Check if Docker is running
    if docker info >/dev/null 2>&1; then
        print_success "Docker daemon is running"
    else
        print_error "Docker daemon is not running!"
        echo -e "${YELLOW}Please start Docker Desktop and try again${NC}"
        exit 1
    fi
    
    # Check available ports
    print_info "Checking port availability..."
    for port in 3000 8000 5433 6380; do
        if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
            print_warning "Port $port is in use. Stopping existing services might be needed."
        else
            print_success "Port $port is available"
        fi
    done
}

# Clean up any existing containers
cleanup_existing() {
    print_header "CLEANING UP EXISTING CONTAINERS"
    
    # Stop and remove containers if they exist
    if docker-compose -f docker-compose.local.yml ps -q 2>/dev/null | grep -q .; then
        print_step "Stopping existing containers..."
        docker-compose -f docker-compose.local.yml down -v --remove-orphans >/dev/null 2>&1 || true
        print_success "Cleaned up existing containers"
    else
        print_info "No existing containers to cleanup"
    fi
    
    # Remove dangling images
    if docker images -q -f dangling=true | grep -q .; then
        print_step "Removing dangling images..."
        docker rmi $(docker images -q -f dangling=true) >/dev/null 2>&1 || true
        print_success "Cleaned up dangling images"
    fi
}

# Setup environment
setup_environment() {
    print_header "SETTING UP ENVIRONMENT"
    
    # Create .env file for local development
    if [ ! -f .env.local ]; then
        print_step "Creating local environment file..."
        cat > .env.local << EOF
# Local Development Environment
SECRET_KEY=local-dev-secret-key-change-in-production
DEBUG=True
DATABASE_URL=postgresql://budget_user:budget_local_pass@db:5432/budget_tracker
REDIS_URL=redis://redis:6379/0
ALLOWED_HOSTS=localhost,127.0.0.1,backend
CORS_ALLOWED_ORIGINS=http://localhost:3000,http://127.0.0.1:3000
VITE_API_URL=http://localhost:8000/api

# Database
POSTGRES_DB=budget_tracker
POSTGRES_USER=budget_user
POSTGRES_PASSWORD=budget_local_pass

# Redis
REDIS_PASSWORD=
EOF
        print_success "Environment file created"
    else
        print_info "Environment file already exists"
    fi
}

# Start services
start_services() {
    print_header "STARTING DOCKER SERVICES"
    
    print_step "Building and starting all services..."
    print_info "This may take a few minutes on first run (downloading images, installing packages)..."
    
    # Start services with progress
    docker-compose -f docker-compose.local.yml up --build -d
    
    print_success "All services started successfully!"
}

# Wait for services to be ready
wait_for_services() {
    print_header "WAITING FOR SERVICES TO BE READY"
    
    print_step "Waiting for database to be ready..."
    timeout=60
    while ! docker-compose -f docker-compose.local.yml exec -T db pg_isready -U budget_user >/dev/null 2>&1; do
        sleep 2
        timeout=$((timeout - 2))
        if [ $timeout -le 0 ]; then
            print_error "Database failed to start within 60 seconds"
            exit 1
        fi
        echo -n "."
    done
    print_success "Database is ready!"
    
    print_step "Waiting for backend API to be ready..."
    timeout=120
    while ! curl -f http://localhost:8000/api/health/ >/dev/null 2>&1; do
        sleep 3
        timeout=$((timeout - 3))
        if [ $timeout -le 0 ]; then
            print_error "Backend API failed to start within 2 minutes"
            print_info "Checking backend logs:"
            docker-compose -f docker-compose.local.yml logs backend | tail -20
            exit 1
        fi
        echo -n "."
    done
    print_success "Backend API is ready!"
    
    print_step "Waiting for frontend to be ready..."
    timeout=60
    while ! curl -f http://localhost:3000 >/dev/null 2>&1; do
        sleep 2
        timeout=$((timeout - 2))
        if [ $timeout -le 0 ]; then
            print_error "Frontend failed to start within 60 seconds"
            print_info "Checking frontend logs:"
            docker-compose -f docker-compose.local.yml logs frontend | tail -20
            exit 1
        fi
        echo -n "."
    done
    print_success "Frontend is ready!"
}

# Display success information
show_success_info() {
    print_header "🎉 SETUP COMPLETED SUCCESSFULLY!"
    
    echo -e "${GREEN}"
    cat << "EOF"
    ╔═══════════════════════════════════════════════════════════╗
    ║                 🎯 BUDGET TRACKER READY! 🎯                ║
    ╚═══════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    echo -e "${CYAN}📱 Access URLs:${NC}"
    echo -e "   ${ROCKET} Frontend:   ${GREEN}http://localhost:3000${NC}"
    echo -e "   ${BACKEND} Backend API: ${GREEN}http://localhost:8000/api${NC}"
    echo -e "   ${DATABASE} Admin Panel: ${GREEN}http://localhost:8000/admin${NC}"
    echo -e "   ${INFO} Health Check: ${GREEN}http://localhost:8000/api/health/${NC}"
    
    echo -e "\n${CYAN}🔑 Test Credentials:${NC}"
    echo -e "   Email:    ${GREEN}test@example.com${NC}"
    echo -e "   Password: ${GREEN}testpass123${NC}"
    
    echo -e "\n${CYAN}🛠️ Useful Commands:${NC}"
    echo -e "   View logs:     ${YELLOW}docker-compose -f docker-compose.local.yml logs -f${NC}"
    echo -e "   Stop services: ${YELLOW}docker-compose -f docker-compose.local.yml down${NC}"
    echo -e "   Restart:       ${YELLOW}docker-compose -f docker-compose.local.yml restart${NC}"
    echo -e "   Clean reset:   ${YELLOW}docker-compose -f docker-compose.local.yml down -v${NC}"
    
    echo -e "\n${CYAN}📊 Key Features to Test:${NC}"
    echo -e "   ${CHECK} Interactive D3.js charts (Pie, Bar, Line)"
    echo -e "   ${CHECK} Transaction management with pagination"
    echo -e "   ${CHECK} Budget vs actual spending comparison"
    echo -e "   ${CHECK} Category management with colors"
    echo -e "   ${CHECK} Responsive design on mobile"
    echo -e "   ${CHECK} Real-time data filtering and search"
    
    echo -e "\n${GREEN}${FIRE} The application is now running with sample data! ${FIRE}${NC}"
    echo -e "${YELLOW}Open your browser and go to: http://localhost:3000${NC}\n"
}

# Show service status
show_service_status() {
    print_header "SERVICE STATUS"
    
    echo -e "${CYAN}Container Status:${NC}"
    docker-compose -f docker-compose.local.yml ps
    
    echo -e "\n${CYAN}Resource Usage:${NC}"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" $(docker-compose -f docker-compose.local.yml ps -q) 2>/dev/null || true
}

# Main execution
main() {
    clear
    print_banner
    
    # Confirmation prompt
    echo -e "${YELLOW}This will set up the Budget Tracker application locally using Docker.${NC}"
    echo -e "${YELLOW}Make sure Docker Desktop is running before proceeding.${NC}\n"
    
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Setup cancelled by user.${NC}"
        exit 0
    fi
    
    # Execute setup steps
    check_prerequisites
    cleanup_existing
    setup_environment
    start_services
    wait_for_services
    show_service_status
    show_success_info
    
    # Optional: Open browser
    if command -v python3 >/dev/null 2>&1; then
        read -p "Would you like to open the application in your browser? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sleep 2
            python3 -c "import webbrowser; webbrowser.open('http://localhost:3000')" 2>/dev/null || true
        fi
    fi
}

# Error handling
trap 'print_error "Setup failed! Check the logs above for details."; exit 1' ERR

# Run main function
main "$@"
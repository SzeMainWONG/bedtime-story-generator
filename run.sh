#!/bin/bash

# ============================================
# 🚀 Project Setup Script
# ============================================

# Colors for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Function to print colored output
print_error() {
    echo -e "${RED}❌ ERROR: $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_header() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo ""
}

print_menu() {
    echo ""
    echo -e "${MAGENTA}┌─────────────────────────────────────────────────────┐${NC}"
    echo -e "${MAGENTA}│            SELECT RUNNING MODE                    │${NC}"
    echo -e "${MAGENTA}├─────────────────────────────────────────────────────┤${NC}"
    echo -e "${MAGENTA}│  ${GREEN}1${NC}) Run from Cloud (refer to owner for URL)        │${NC}"
    echo -e "${MAGENTA}│  ${GREEN}2${NC}) Run from Local (with database checks)           │${NC}"
    echo -e "${MAGENTA}└─────────────────────────────────────────────────────┘${NC}"
    echo ""
}

# ============================================
# 0. SELECT RUNNING MODE
# ============================================
print_header "Welcome to Bedtime Story App"

print_menu
read -p "Please select an option (1 or 2): " RUN_MODE

# Validate input
while [[ "$RUN_MODE" != "1" && "$RUN_MODE" != "2" ]]; do
    print_error "Invalid selection. Please enter 1 or 2."
    read -p "Please select an option (1 or 2): " RUN_MODE
done

if [ "$RUN_MODE" = "1" ]; then
    print_header "Cloud Mode Selected"
    print_info "Running from Cloud (refer to owner for URL)"
    print_info "No local database checks will be performed."
    echo ""
    print_info "To run the app from cloud:"
    echo "  - Contact the project owner for the cloud URL"
    echo "  - Or check the deployment documentation"
    echo ""
    print_success "Script completed in Cloud mode!"
    exit 0
fi

print_success "Local Mode Selected"
print_info "Running local setup with database checks..."

# ============================================
# 1. LOAD ENVIRONMENT VARIABLES
# ============================================
print_header "Loading Environment Variables"

if [ ! -f .env ]; then
    print_error ".env file not found in current directory"
    echo "Please create a .env file with DATABASE_URL=postgresql://..."
    exit 1
fi

print_info "Loading .env file..."
export $(grep -v '^#' .env | xargs)

if [ -z "$DATABASE_URL" ]; then
    print_error "DATABASE_URL is not set in .env file"
    echo "Please add: DATABASE_URL=postgresql://user:password@localhost:5432/dbname"
    exit 1
fi

print_success "DATABASE_URL loaded"

# ============================================
# 2. CHECK POSTGRESQL CONNECTION
# ============================================
print_header "Checking PostgreSQL Connection"

# Extract host, port, user, and password from DATABASE_URL
DB_HOST=$(echo $DATABASE_URL | sed -n 's/.*@\([^:]*\):.*/\1/p')
DB_PORT=$(echo $DATABASE_URL | sed -n 's/.*:\([0-9]*\)\/.*/\1/p')
DB_USER=$(echo $DATABASE_URL | sed -n 's/.*\/\/\([^:]*\):.*/\1/p')
DB_PASS=$(echo $DATABASE_URL | sed -n 's/.*:\([^@]*\)@.*/\1/p')

# Set defaults if not found
if [ -z "$DB_HOST" ]; then
    DB_HOST="localhost"
fi
if [ -z "$DB_PORT" ]; then
    DB_PORT="5432"
fi

print_info "Checking PostgreSQL at $DB_HOST:$DB_PORT..."

# Export password for non-interactive commands
export PGPASSWORD="$DB_PASS"

if pg_isready -h "$DB_HOST" -p "$DB_PORT" > /dev/null 2>&1; then
    print_success "PostgreSQL is running and ready"
else
    print_error "PostgreSQL is not running or not accessible at $DB_HOST:$DB_PORT"
    echo ""
    echo "Try starting PostgreSQL with:"
    echo "  - On Ubuntu/WSL: sudo service postgresql start"
    echo "  - On macOS: brew services start postgresql"
    echo "  - On Windows: net start postgresql-x64-15"
    unset PGPASSWORD
    exit 1
fi

# ============================================
# 3. SETUP VIRTUAL ENVIRONMENT
# ============================================
print_header "Setting Up Python Virtual Environment"

if [ ! -d "venv" ]; then
    print_warning "Virtual environment not found. Creating one..."
    python3 -m venv venv
    if [ $? -eq 0 ]; then
        print_success "Virtual environment created successfully"
    else
        print_error "Failed to create virtual environment"
        unset PGPASSWORD
        exit 1
    fi
else
    print_success "Virtual environment already exists"
fi

print_info "Activating virtual environment..."
source venv/bin/activate

if [ $? -ne 0 ]; then
    print_error "Failed to activate virtual environment"
    unset PGPASSWORD
    exit 1
fi
print_success "Virtual environment activated"

# ============================================
# 4. INSTALL DEPENDENCIES
# ============================================
print_header "Installing Python Dependencies"

if [ ! -f "requirements.txt" ]; then
    print_warning "requirements.txt not found. Skipping dependency installation."
else
    print_info "Installing dependencies from requirements.txt..."
    pip install -r requirements.txt
    if [ $? -eq 0 ]; then
        print_success "Dependencies installed successfully"
    else
        print_error "Failed to install dependencies"
        unset PGPASSWORD
        exit 1
    fi
fi

# ============================================
# 5. CHECK DATABASE AND STORIES TABLE
# ============================================
print_header "Checking Database and Stories Table"

# Extract database name from DATABASE_URL
DB_NAME=$(echo $DATABASE_URL | sed -n 's/.*\/\([^?]*\)/\1/p')

# Set default if not found
if [ -z "$DB_NAME" ]; then
    DB_NAME="llm_question_log"
fi

print_info "Database name: $DB_NAME"
print_info "Checking if database '$DB_NAME' exists..."

# Check if database exists
DB_EXISTS=$(psql -h "$DB_HOST" -U "$DB_USER" -t -c "SELECT 1 FROM pg_database WHERE datname = '$DB_NAME';" 2>&1 | xargs)

# Check if the command failed due to authentication
if echo "$DB_EXISTS" | grep -q "FATAL\|password"; then
    print_error "Authentication failed. Please check your DATABASE_URL in .env"
    echo ""
    echo "Your DATABASE_URL: $DATABASE_URL"
    echo ""
    echo "Make sure the username and password are correct."
    echo "Format: postgresql://username:password@host:port/database"
    unset PGPASSWORD
    exit 1
fi

if [ "$DB_EXISTS" = "1" ]; then
    print_success "✅ Database '$DB_NAME' exists"
else
    print_warning "Database '$DB_NAME' does not exist. Creating..."
    
    # Create the database
    createdb -h "$DB_HOST" -U "$DB_USER" "$DB_NAME" 2>&1
    
    if [ $? -eq 0 ]; then
        print_success "✅ Database '$DB_NAME' created successfully"
    else
        print_error "Failed to create database '$DB_NAME'"
        echo ""
        echo "Try creating the database manually:"
        echo "  PGPASSWORD='$DB_PASS' createdb -h $DB_HOST -U $DB_USER $DB_NAME"
        echo ""
        echo "Or if you're using the default postgres user:"
        echo "  sudo -u postgres createdb $DB_NAME"
        unset PGPASSWORD
        exit 1
    fi
fi

# Now check if stories table exists
print_info "Checking if 'stories' table exists..."

TABLE_EXISTS=$(psql "$DATABASE_URL" -t -c "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'stories');" 2>&1 | xargs)

# Check if the command failed due to authentication
if echo "$TABLE_EXISTS" | grep -q "FATAL\|password"; then
    print_error "Authentication failed when checking stories table"
    unset PGPASSWORD
    exit 1
fi

if [ "$TABLE_EXISTS" = "t" ]; then
    print_success "✅ 'stories' table exists"
    
    # Get row count
    ROW_COUNT=$(psql "$DATABASE_URL" -t -c "SELECT COUNT(*) FROM stories;" 2>&1 | xargs)
    if ! echo "$ROW_COUNT" | grep -q "ERROR\|FATAL"; then
        print_info "Total rows in stories table: $ROW_COUNT"
    fi
else
    print_warning "'stories' table does NOT exist. Creating from migration file..."
    
    # Check if migration file exists
    if [ ! -f "sql/002_create_stories.sql" ]; then
        print_error "Migration file not found: sql/002_create_stories.sql"
        echo ""
        echo "Please create the migration file or create the table manually:"
        echo "  PGPASSWORD='$DB_PASS' psql \"\$DATABASE_URL\" -c \"CREATE TABLE stories (id SERIAL PRIMARY KEY, title TEXT, content TEXT);\""
        unset PGPASSWORD
        exit 1
    fi
    
    # Run the migration
    print_info "Running migration: sql/002_create_stories.sql"
    psql "$DATABASE_URL" -f sql/002_create_stories.sql 2>&1
    
    if [ $? -eq 0 ]; then
        print_success "✅ 'stories' table created successfully"
        
        # Verify creation
        TABLE_EXISTS=$(psql "$DATABASE_URL" -t -c "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'stories');" 2>&1 | xargs)
        if [ "$TABLE_EXISTS" = "t" ]; then
            print_success "✅ 'stories' table verified"
        else
            print_error "Table creation verification failed"
            unset PGPASSWORD
            exit 1
        fi
    else
        print_error "Failed to create 'stories' table"
        echo ""
        echo "You can create the table manually with:"
        echo "  PGPASSWORD='$DB_PASS' psql \"\$DATABASE_URL\" -c \"CREATE TABLE stories (id SERIAL PRIMARY KEY, title TEXT, content TEXT);\""
        unset PGPASSWORD
        exit 1
    fi
fi

# Unset the password for security
unset PGPASSWORD

# ============================================
# 6. ADDITIONAL DATABASE INFO (Optional)
# ============================================
print_header "Database Summary"

# Show all tables
print_info "All tables in database:"
psql "$DATABASE_URL" -t -c "\dt" 2>/dev/null | grep -v "^$" | while read line; do
    echo "  📊 $line"
done

# Show database size
DB_SIZE=$(psql "$DATABASE_URL" -t -c "SELECT pg_database_size(current_database()) / 1024 / 1024 || ' MB';" 2>/dev/null | xargs)
print_info "Database size: $DB_SIZE"

# ============================================
# 7. FINISH
# ============================================
print_header "✅ Setup Complete!"

print_success "Your project is ready!"
echo ""
print_info "Virtual environment: ACTIVE (venv)"
print_info "Database: CONNECTED ($DATABASE_URL)"
print_info "Database exists: ✓"
print_info "Stories table: EXISTS ✓"
echo ""

print_info "To query the stories table:"
echo "  psql \"\$DATABASE_URL\" -c \"SELECT * FROM stories LIMIT 10;\""
echo ""

print_info "To deactivate virtual environment:"
echo "  deactivate"
echo ""

echo -e "${GREEN}✨ Virtual environment is active. Happy coding!${NC}"
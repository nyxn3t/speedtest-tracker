#!/usr/bin/env bash

set -e

echo "🐇 Speedtest Tracker - Coolify Deployment Helper"
echo "================================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to print status
print_status() {
    if [ "$1" = "ok" ]; then
        echo -e "${GREEN}✓${NC} $2"
    elif [ "$1" = "warn" ]; then
        echo -e "${YELLOW}⚠${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
    fi
}

echo "Stap 1: Environment Check"
echo "--------------------------"

# Check PHP
if command_exists php; then
    PHP_VERSION=$(php -r "echo PHP_VERSION;")
    print_status "ok" "PHP $PHP_VERSION geïnstalleerd"
else
    print_status "fail" "PHP niet gevonden (installeer PHP 8.2+ of gebruik Docker methode)"
fi

# Check Composer
if command_exists composer; then
    print_status "ok" "Composer geïnstalleerd"
else
    print_status "warn" "Composer niet gevonden (optioneel, gebruik Docker als alternatief)"
fi

# Check Docker
if command_exists docker; then
    print_status "ok" "Docker geïnstalleerd"
else
    print_status "warn" "Docker niet gevonden (nodig voor Docker-based key generatie)"
fi

echo ""
echo "Stap 2: APP_KEY Generatie"
echo "-------------------------"

APP_KEY=""

# Try to generate APP_KEY
if [ -f "vendor/autoload.php" ] && command_exists php; then
    echo "Gebruik lokale PHP installatie..."
    APP_KEY=$(php artisan key:generate --show 2>/dev/null || echo "")
    if [ ! -z "$APP_KEY" ]; then
        print_status "ok" "APP_KEY gegenereerd met lokale PHP"
    fi
fi

# Fallback to Docker if local PHP failed
if [ -z "$APP_KEY" ] && command_exists docker; then
    echo "Lokale methode gefaald, probeer Docker..."

    # Install dependencies first
    print_status "warn" "Installeer dependencies met Docker..."
    docker run --rm -v "$(pwd):/app" -w /app composer:latest \
        composer install --no-dev --optimize-autoloader --quiet 2>/dev/null || true

    # Generate key
    APP_KEY=$(docker run --rm -v "$(pwd):/app" -w /app php:8.4-cli \
        php artisan key:generate --show 2>/dev/null || echo "")

    if [ ! -z "$APP_KEY" ]; then
        print_status "ok" "APP_KEY gegenereerd met Docker"
    fi
fi

# Fallback to manual generation
if [ -z "$APP_KEY" ] && command_exists openssl; then
    echo "Automatische methoden gefaald, gebruik openssl..."
    RANDOM_KEY=$(openssl rand -base64 32)
    APP_KEY="base64:$RANDOM_KEY"
    print_status "ok" "APP_KEY gegenereerd met openssl"
fi

if [ -z "$APP_KEY" ]; then
    print_status "fail" "Kon geen APP_KEY genereren!"
    echo ""
    echo "Handmatige oplossing:"
    echo "1. Installeer PHP 8.2+ of Docker"
    echo "2. Run: openssl rand -base64 32"
    echo "3. Voeg 'base64:' toe aan het begin"
    exit 1
fi

echo ""
echo "✅ Gegenereerde APP_KEY:"
echo "========================"
echo -e "${GREEN}$APP_KEY${NC}"
echo ""

echo "Stap 3: Environment Variables Template"
echo "---------------------------------------"

cat > .env.coolify.example << EOF
# ⚠️ VERPLICHTE VARIABLES - Zonder deze crasht de applicatie!
APP_KEY=$APP_KEY
APP_ENV=production
APP_DEBUG=false
APP_URL=https://network.makkerlab.nl
DB_CONNECTION=sqlite

# 📝 Aanbevolen voor productie
LOG_LEVEL=warning
LOG_CHANNEL=stack
SESSION_DRIVER=cookie
SESSION_LIFETIME=10080
CACHE_STORE=database
QUEUE_CONNECTION=database

# 📧 Mail configuratie (optioneel - voor notificaties)
# MAIL_MAILER=smtp
# MAIL_HOST=smtp.example.com
# MAIL_PORT=587
# MAIL_USERNAME=
# MAIL_PASSWORD=
# MAIL_ENCRYPTION=tls
# MAIL_FROM_ADDRESS=noreply@makkerlab.nl
# MAIL_FROM_NAME="Speedtest Tracker"
EOF

print_status "ok" "Environment template aangemaakt: .env.coolify.example"

echo ""
echo "Stap 4: Verificatie Checklist"
echo "------------------------------"

# Check if .env exists
if [ -f ".env" ]; then
    print_status "ok" ".env bestand bestaat"

    # Check if APP_KEY is set in .env
    if grep -q "APP_KEY=base64:" .env 2>/dev/null; then
        print_status "ok" "APP_KEY is ingesteld in .env"
    else
        print_status "fail" "APP_KEY ontbreekt in .env!"
    fi
else
    print_status "warn" ".env bestand bestaat niet (normaal voor Coolify deployment)"
fi

# Check storage directories
if [ -d "storage" ]; then
    print_status "ok" "Storage directory bestaat"
else
    print_status "fail" "Storage directory ontbreekt!"
fi

# Check bootstrap/cache
if [ -d "bootstrap/cache" ]; then
    print_status "ok" "Bootstrap cache directory bestaat"
else
    print_status "fail" "Bootstrap cache directory ontbreekt!"
fi

echo ""
echo "📋 Volgende Stappen voor Coolify:"
echo "==================================="
echo ""
echo "1. Ga naar je applicatie in Coolify"
echo "2. Klik op 'Environment Variables'"
echo "3. Kopieer de inhoud van .env.coolify.example"
echo "4. Plak de variables in Coolify (één per regel)"
echo "5. Pas APP_URL aan naar jouw domein"
echo "6. Klik 'Save'"
echo "7. Deploy opnieuw"
echo ""
echo "8. Na succesvolle deployment, run in container terminal:"
echo "   php artisan migrate --force"
echo ""
echo "9. Verifieer deployment:"
echo "   - Container status = Running (geen restarts)"
echo "   - Browser: https://network.makkerlab.nl"
echo "   - Geen errors in logs"
echo ""
echo "✅ Setup voltooid!"
echo ""
echo "📚 Zie COOLIFY_DEPLOYMENT.md voor gedetailleerde instructies"
echo ""

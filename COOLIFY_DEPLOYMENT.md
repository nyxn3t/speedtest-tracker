# Coolify Deployment Guide voor Speedtest Tracker

## Waarom crasht de container? 🔍

De container crasht omdat **Laravel een APP_KEY vereist** om te kunnen starten. Wanneer je `php artisan serve` uitvoert zonder APP_KEY, crasht de applicatie onmiddellijk.

### Container Startup Process
1. Container start → `start-container` script
2. Supervisord start → voert `php artisan serve --host=0.0.0.0 --port=80` uit
3. Laravel bootstrap → **FAALT als APP_KEY ontbreekt**
4. Container crasht → restart loop (10x restarts)

## Oplossing: Verplichte Environment Variables 🔧

### Stap 1: Genereer APP_KEY

Je hebt **3 opties** om een APP_KEY te genereren:

#### Optie A: Met composer (lokaal)
```bash
# In de repository directory
composer install --no-dev --optimize-autoloader
php artisan key:generate --show
```

#### Optie B: Met Docker (zonder lokale PHP)
```bash
docker run --rm -v $(pwd):/app -w /app composer:latest composer install --no-dev --optimize-autoloader
docker run --rm -v $(pwd):/app -w /app php:8.4-cli php artisan key:generate --show
```

#### Optie C: Handmatig genereren
```bash
# Genereer random base64 string (32 bytes)
echo "base64:$(openssl rand -base64 32)"
```

De output ziet er zo uit: `base64:AbCdEf1234567890...`

### Stap 2: Configureer Environment Variables in Coolify

Ga naar je applicatie in Coolify en voeg deze environment variables toe:

#### ⚠️ VERPLICHT (zonder deze crasht de app):
```bash
APP_KEY=base64:JouwGegenereerdeKeyHier==
APP_ENV=production
APP_DEBUG=false
APP_URL=https://network.makkerlab.nl
DB_CONNECTION=sqlite
```

#### 📝 Aanbevolen (voor productie):
```bash
# Logging
LOG_LEVEL=warning
LOG_CHANNEL=stack

# Session
SESSION_DRIVER=cookie
SESSION_LIFETIME=10080

# Cache
CACHE_STORE=database

# Queue
QUEUE_CONNECTION=database

# Mail (optioneel - voor notificaties)
MAIL_MAILER=smtp
MAIL_HOST=your-smtp-host.com
MAIL_PORT=587
MAIL_USERNAME=your-email@example.com
MAIL_PASSWORD=your-password
MAIL_ENCRYPTION=tls
MAIL_FROM_ADDRESS=noreply@makkerlab.nl
MAIL_FROM_NAME="Speedtest Tracker"
```

### Stap 3: Nixpacks Build Configuratie

Nixpacks detecteert automatisch Laravel, maar je kunt het optimaliseren met een `nixpacks.toml`:

```toml
[phases.setup]
nixPkgs = ["nodejs_22", "php84", "php84Packages.composer"]

[phases.install]
cmds = [
  "composer install --no-dev --optimize-autoloader --no-interaction --prefer-dist",
  "npm ci --only=production"
]

[phases.build]
cmds = [
  "npm run build",
  "php artisan config:cache",
  "php artisan route:cache",
  "php artisan view:cache"
]

[start]
cmd = "php artisan serve --host=0.0.0.0 --port=3000"
```

**Let op**: Als je `nixpacks.toml` toevoegt, commit en push naar je repository!

### Stap 4: Database Migraties

Na de eerste succesvolle deployment moet je de database initialiseren:

1. **Via Coolify Terminal** (in de container):
```bash
php artisan migrate --force
php artisan db:seed --force  # Optioneel, voor demo data
```

2. **Of voeg toe aan build commands** in Coolify:
```
php artisan migrate --force
```

### Stap 5: Storage Permissies

Zorg dat storage directories schrijfbaar zijn. Voeg toe aan build commands:
```bash
chmod -R 775 storage bootstrap/cache
```

## Deployment Checklist ✅

- [ ] APP_KEY gegenereerd en toegevoegd aan environment variables
- [ ] Alle verplichte environment variables ingesteld
- [ ] APP_URL ingesteld op juiste domein
- [ ] DB_CONNECTION ingesteld (sqlite voor standaard)
- [ ] Container gedeployed zonder crashes
- [ ] Database migraties uitgevoerd
- [ ] Applicatie bereikbaar via browser
- [ ] Inloggen werkt (standaard credentials controleren)

## Troubleshooting 🔍

### Container blijft crashen?

1. **Check logs in Coolify**:
   - Ga naar "Logs" tab
   - Kijk naar de runtime logs (niet build logs)
   - Zoek naar error messages van Laravel

2. **Veelvoorkomende errors**:

```
RuntimeException: No application encryption key has been specified.
→ Oplossing: APP_KEY ontbreekt of is incorrect

SQLSTATE[HY000]: General error: 1 no such table
→ Oplossing: Migraties zijn niet uitgevoerd (run: php artisan migrate --force)

file_put_contents(/var/www/html/storage/framework/sessions/...): Failed to open stream
→ Oplossing: Storage directories niet schrijfbaar (run: chmod -R 775 storage)
```

3. **Open een terminal in de container** (in Coolify):
```bash
# Check of APP_KEY is ingesteld
php artisan tinker --execute="echo config('app.key');"

# Check database connectie
php artisan migrate:status

# Check storage permissies
ls -la storage/
```

### Applicatie draait maar geeft errors?

1. **Check de logs**:
```bash
tail -f storage/logs/laravel.log
```

2. **Clear cache** (na environment wijzigingen):
```bash
php artisan config:clear
php artisan cache:clear
php artisan view:clear
```

## Verificatie 🎯

Na succesvolle deployment:

1. **Container status** = Running (geen restarts)
2. **Browser toegang** → https://network.makkerlab.nl werkt
3. **Geen errors** in logs
4. **Login pagina** wordt getoond

## Standaard Login Credentials 🔑

Check de documentatie of database seeders voor standaard credentials:
```bash
# In container terminal
php artisan tinker --execute="App\Models\User::first();"
```

## Support & Documentatie 📚

- Officiële docs: https://docs.speedtest-tracker.dev
- Environment variables: https://docs.speedtest-tracker.dev/getting-started/environment-variables
- Installation guide: https://docs.speedtest-tracker.dev/getting-started/installation
- GitHub: https://github.com/alexjustesen/speedtest-tracker

---

**Nog steeds problemen?** Share de **runtime logs** (niet build logs) uit Coolify!

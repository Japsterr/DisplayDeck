#!/bin/bash

# DisplayDeck Deployment Script
# This script sets up the DisplayDeck application using Docker Compose

set -e

echo "🚀 Starting DisplayDeck deployment..."

# Check if Docker and Docker Compose are installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi

if ! command -v docker-compose &> /dev/null && ! command -v docker compose &> /dev/null; then
    echo "❌ Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Create environment file if it doesn't exist
if [ ! -f .env ]; then
    echo "📝 Creating environment file..."
    cp .env.example .env
    echo "⚠️  Please edit .env file with your production settings before proceeding."
    echo "   Pay special attention to SECRET_KEY, database passwords, and ALLOWED_HOSTS."
    read -p "Press Enter to continue once you've configured .env..."
fi

# Choose deployment type
echo "Please choose deployment type:"
echo "1) Development (with hot reload)"
echo "2) Production (optimized build)"
read -p "Enter choice (1 or 2): " choice

case $choice in
    1)
        echo "🛠️  Starting development environment..."
        docker-compose -f docker-compose.dev.yml up --build -d
        ;;
    2)
        echo "🏭 Starting production environment..."
        docker-compose up --build -d
        ;;
    *)
        echo "❌ Invalid choice. Exiting."
        exit 1
        ;;
esac

# Wait for services to be ready
echo "⏳ Waiting for services to start..."
sleep 10

# Check if services are running
if [ "$choice" = "1" ]; then
    COMPOSE_FILE="docker-compose.dev.yml"
else
    COMPOSE_FILE="docker-compose.yml"
fi

if [ "$choice" = "1" ]; then
    docker-compose -f $COMPOSE_FILE exec backend python manage.py migrate
    docker-compose -f $COMPOSE_FILE exec backend python manage.py collectstatic --noinput
    echo "🌱 Creating superuser for development..."
    docker-compose -f $COMPOSE_FILE exec backend python manage.py createsuperuser --noinput --email admin@displaydeck.com --username admin || true
else
    docker-compose exec backend python manage.py migrate
    docker-compose exec backend python manage.py collectstatic --noinput
fi

echo ""
echo "✅ DisplayDeck deployment complete!"
echo ""
echo "🌐 Application URLs:"
if [ "$choice" = "1" ]; then
    echo "   Frontend:  http://localhost:3000"
    echo "   Backend:   http://localhost:8000"
    echo "   Admin:     http://localhost:8000/admin"
    echo "   API Docs:  http://localhost:8000/api/schema/swagger-ui/"
else
    echo "   Application: http://localhost"
    echo "   Admin:       http://localhost/admin"
    echo "   API Docs:    http://localhost/api/schema/swagger-ui/"
fi
echo ""
echo "📊 To view logs: docker-compose logs -f"
echo "🛑 To stop:      docker-compose down"
echo "🔄 To restart:   docker-compose restart"
echo ""
echo "📱 Mobile app development:"
echo "   cd mobile && npm start"
echo ""
echo "📺 Android TV development:"
echo "   Open android-display folder in Android Studio"
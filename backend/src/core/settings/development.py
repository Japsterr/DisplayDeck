"""
Development settings for DisplayDeck project.
"""

from .base import *

# SECURITY WARNING: don't run with debug turned on in production!
DEBUG = True

ALLOWED_HOSTS = ['localhost', '127.0.0.1', '0.0.0.0']

# Development-specific apps
INSTALLED_APPS += [
    'django_extensions',
    'debug_toolbar',
]

# Development middleware
MIDDLEWARE += [
    'debug_toolbar.middleware.DebugToolbarMiddleware',
]

# Debug toolbar configuration
INTERNAL_IPS = [
    '127.0.0.1',
    'localhost',
]

# Email backend for development
EMAIL_BACKEND = 'django.core.mail.backends.console.EmailBackend'

# Static files configuration for development
STATICFILES_STORAGE = 'django.contrib.staticfiles.storage.StaticFilesStorage'

# Logging level for development
LOGGING['root']['level'] = 'DEBUG'
LOGGING['loggers']['django']['level'] = 'DEBUG'

# Development database - use SQLite by default for easier setup
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': BASE_DIR / 'db.sqlite3',
    }
}

# Uncomment to use PostgreSQL instead of SQLite
# if not config('USE_SQLITE', default=True, cast=bool):
#     DATABASES['default'] = {
#         'ENGINE': 'django.db.backends.postgresql',
#         'NAME': config('DB_NAME', default='displaydeck_dev'),
#         'USER': config('DB_USER', default='postgres'),
#         'PASSWORD': config('DB_PASSWORD', default='postgres'),
#         'HOST': config('DB_HOST', default='localhost'),
#         'PORT': config('DB_PORT', default='5432'),
#     }

# CORS settings for development - Allow all origins for easier testing
CORS_ALLOW_ALL_ORIGINS = True

# Additional allowed origins for development
CORS_ALLOWED_ORIGINS += [
    # Expo development
    "http://localhost:19000",  # Expo Metro bundler
    "http://localhost:19001",  # Expo DevTools
    "http://localhost:19002",  # Expo web
    "http://localhost:19006",  # Expo web (webpack)
    
    # React Native development
    "http://10.0.2.2:3000",    # Android emulator
    "http://192.168.1.100:3000",  # Local network (adjust IP as needed)
    
    # Android TV testing
    "http://localhost:8080",
    "http://127.0.0.1:8080",
    
    # Additional development servers
    "http://localhost:4000",
    "http://localhost:5000",
    "http://localhost:8000",
]

# Additional allowed headers for development/testing
CORS_ALLOWED_HEADERS += [
    'x-test-token',
    'x-debug-mode',
    'x-simulation-mode',
]

# More permissive settings for development
CORS_ALLOW_CREDENTIALS = True
CORS_PREFLIGHT_MAX_AGE = 3600  # 1 hour (shorter for development)
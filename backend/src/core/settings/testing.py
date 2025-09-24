"""
Test settings for DisplayDeck project.
"""

from .base import *

# SECURITY WARNING: don't run with debug turned on in production!
DEBUG = True

# Use in-memory database for tests
DATABASES['default'] = {
    'ENGINE': 'django.db.backends.sqlite3',
    'NAME': ':memory:',
}

# Disable migrations for faster tests
class DisableMigrations:
    def __contains__(self, item):
        return True
    
    def __getitem__(self, item):
        return None

MIGRATION_MODULES = DisableMigrations()

# Use dummy cache for tests
CACHES['default'] = {
    'BACKEND': 'django.core.cache.backends.dummy.DummyCache',
}

# Password hashing - use faster hasher for tests
PASSWORD_HASHERS = [
    'django.contrib.auth.hashers.MD5PasswordHasher',
]

# Email backend for tests
EMAIL_BACKEND = 'django.core.mail.backends.locmem.EmailBackend'

# Channels - use in-memory channel layer for tests
CHANNEL_LAYERS = {
    'default': {
        'BACKEND': 'channels.layers.InMemoryChannelLayer',
    },
}

# Media files for tests
MEDIA_ROOT = '/tmp/displaydeck_test_media'

# JWT settings for tests - shorter lifetimes
SIMPLE_JWT['ACCESS_TOKEN_LIFETIME'] = timedelta(minutes=5)
SIMPLE_JWT['REFRESH_TOKEN_LIFETIME'] = timedelta(minutes=10)

# Logging for tests - only errors
LOGGING['root']['level'] = 'ERROR'
LOGGING['loggers']['django']['level'] = 'ERROR'
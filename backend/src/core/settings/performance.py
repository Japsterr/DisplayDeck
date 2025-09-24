"""
Performance optimization settings and configurations for DisplayDeck.
This file contains optimized settings for production deployment.
"""

import os
from .base import DEBUG, TIME_ZONE, REST_FRAMEWORK

# Database Connection Optimization
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': os.getenv('DB_NAME', 'displaydeck'),
        'USER': os.getenv('DB_USER', 'postgres'),
        'PASSWORD': os.getenv('DB_PASSWORD', 'postgres'),
        'HOST': os.getenv('DB_HOST', 'localhost'),
        'PORT': os.getenv('DB_PORT', '5432'),
        # Connection pooling and optimization
        'CONN_MAX_AGE': 600,  # 10 minutes
        'OPTIONS': {
            'MAX_CONNS': 20,
            'charset': 'utf8mb4',
        },
    }
}

# Enhanced Redis Configuration with Connection Pooling
REDIS_URL = os.getenv('REDIS_URL', 'redis://localhost:6379/0')

CACHES = {
    'default': {
        'BACKEND': 'django_redis.cache.RedisCache',
        'LOCATION': REDIS_URL,
        'OPTIONS': {
            'CLIENT_CLASS': 'django_redis.client.DefaultClient',
            'CONNECTION_POOL_KWARGS': {
                'max_connections': 50,
                'retry_on_timeout': True,
            },
            'SERIALIZER': 'django_redis.serializers.json.JSONSerializer',
            'COMPRESSOR': 'django_redis.compressors.zlib.ZlibCompressor',
        },
        'TIMEOUT': 300,  # 5 minutes default
        'KEY_PREFIX': 'displaydeck',
        'VERSION': 1,
    },
    # Separate cache for sessions
    'sessions': {
        'BACKEND': 'django_redis.cache.RedisCache',
        'LOCATION': f"{REDIS_URL}/1",
        'OPTIONS': {
            'CLIENT_CLASS': 'django_redis.client.DefaultClient',
        },
        'TIMEOUT': 86400,  # 24 hours
    },
    # Cache for menu data (longer TTL)
    'menus': {
        'BACKEND': 'django_redis.cache.RedisCache',
        'LOCATION': f"{REDIS_URL}/2",
        'OPTIONS': {
            'CLIENT_CLASS': 'django_redis.client.DefaultClient',
        },
        'TIMEOUT': 3600,  # 1 hour
    }
}

# Session Configuration
SESSION_ENGINE = 'django.contrib.sessions.backends.cache'
SESSION_CACHE_ALIAS = 'sessions'
SESSION_COOKIE_AGE = 86400  # 24 hours
SESSION_SAVE_EVERY_REQUEST = False

# Database Query Optimization
DATABASE_ENGINE_OPTIONS = {
    'CONN_MAX_AGE': 600,
    'AUTOCOMMIT': True,
    'ATOMIC_REQUESTS': False,
}

# Enhanced Logging for Performance Monitoring
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'verbose': {
            'format': '{levelname} {asctime} {module} {process:d} {thread:d} {message}',
            'style': '{',
        },
        'performance': {
            'format': '{asctime} PERF {name} {message}',
            'style': '{',
        },
    },
    'handlers': {
        'console': {
            'level': 'INFO',
            'class': 'logging.StreamHandler',
            'formatter': 'verbose',
        },
        'performance': {
            'level': 'INFO',
            'class': 'logging.StreamHandler',
            'formatter': 'performance',
        },
    },
    'loggers': {
        'django.db.backends': {
            'handlers': ['console'],
            'level': 'WARNING',  # Only log slow queries
            'propagate': False,
        },
        'performance': {
            'handlers': ['performance'],
            'level': 'INFO',
            'propagate': False,
        },
    },
}

# Static Files Optimization
STATICFILES_STORAGE = 'whitenoise.storage.CompressedManifestStaticFilesStorage'

# Static files optimization
WHITENOISE_USE_FINDERS = True
WHITENOISE_AUTOREFRESH = True
WHITENOISE_MANIFEST_STRICT = False

# Compression settings
WHITENOISE_SKIP_COMPRESS_EXTENSIONS = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'zip', 'gz', 'tgz', 'bz2', 'tbz', 'xz']

# Media files optimization for production
if not DEBUG:
    # Use S3 or similar for media files in production
    DEFAULT_FILE_STORAGE = 'storages.backends.s3boto3.S3Boto3Storage'
    AWS_STORAGE_BUCKET_NAME = os.getenv('AWS_STORAGE_BUCKET_NAME', 'displaydeck-media')
    AWS_S3_REGION_NAME = os.getenv('AWS_S3_REGION_NAME', 'us-east-1')
    AWS_S3_CUSTOM_DOMAIN = os.getenv('AWS_S3_CUSTOM_DOMAIN', '')
    AWS_DEFAULT_ACL = None
    AWS_S3_OBJECT_PARAMETERS = {
        'CacheControl': 'max-age=86400',  # 24 hours
    }

# Performance-oriented middleware order
MIDDLEWARE = [
    # Security first
    'django.middleware.security.SecurityMiddleware',
    
    # Static files (whitenoise should be early)
    'whitenoise.middleware.WhiteNoiseMiddleware',
    
    # CORS (should be early for preflight requests)
    'corsheaders.middleware.CorsMiddleware',
    
    # Caching middleware (early for better performance)
    'django.middleware.cache.UpdateCacheMiddleware',
    
    # Core Django middleware
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    
    # Custom authentication (after Django auth)
    'apps.authentication.middleware.CrossPlatformAuthMiddleware',
    
    # Tenant middleware (after authentication)
    'common.middleware.TenantMiddleware',
    
    # Messages and other middleware
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
    
    # Cache fetch middleware (should be last)
    'django.middleware.cache.FetchFromCacheMiddleware',
]

# Cache settings for different components
CACHE_MIDDLEWARE_ALIAS = 'default'
CACHE_MIDDLEWARE_SECONDS = 300  # 5 minutes
CACHE_MIDDLEWARE_KEY_PREFIX = 'displaydeck'

# Performance monitoring
PERFORMANCE_MONITORING = {
    'SLOW_QUERY_THRESHOLD': 0.5,  # Log queries slower than 500ms
    'SLOW_REQUEST_THRESHOLD': 2.0,  # Log requests slower than 2 seconds
    'ENABLE_PROFILING': os.getenv('ENABLE_PROFILING', 'False').lower() == 'true',
}

# Email optimization
EMAIL_TIMEOUT = 30
EMAIL_USE_LOCALTIME = True

# File upload optimization
FILE_UPLOAD_MAX_MEMORY_SIZE = 5 * 1024 * 1024  # 5MB
DATA_UPLOAD_MAX_MEMORY_SIZE = 10 * 1024 * 1024  # 10MB
FILE_UPLOAD_TEMP_DIR = '/tmp'

# Security optimizations
SECURE_CONTENT_TYPE_NOSNIFF = True
SECURE_BROWSER_XSS_FILTER = True
SECURE_HSTS_SECONDS = 31536000  # 1 year
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SECURE_HSTS_PRELOAD = True

# Django REST Framework performance optimizations
REST_FRAMEWORK.update({
    'DEFAULT_RENDERER_CLASSES': [
        'rest_framework.renderers.JSONRenderer',
        # Remove BrowsableAPIRenderer in production for performance
    ],
    'DEFAULT_PAGINATION_CLASS': 'rest_framework.pagination.LimitOffsetPagination',
    'PAGE_SIZE': 25,  # Smaller page size for better performance
    'DEFAULT_THROTTLE_CLASSES': [
        'rest_framework.throttling.AnonRateThrottle',
        'rest_framework.throttling.UserRateThrottle'
    ],
    'DEFAULT_THROTTLE_RATES': {
        'anon': '100/hour',
        'user': '1000/hour',
        'display': '10000/hour',  # Higher rate for display devices
    }
})

# Celery Configuration for Background Tasks
CELERY_BROKER_URL = REDIS_URL + '/3'
CELERY_RESULT_BACKEND = REDIS_URL + '/4'
CELERY_ACCEPT_CONTENT = ['json']
CELERY_TASK_SERIALIZER = 'json'
CELERY_RESULT_SERIALIZER = 'json'
CELERY_TIMEZONE = TIME_ZONE
CELERY_ENABLE_UTC = True

# Celery Performance Settings
CELERY_WORKER_CONCURRENCY = 4
CELERY_WORKER_PREFETCH_MULTIPLIER = 4
CELERY_TASK_COMPRESSION = 'gzip'
CELERY_RESULT_COMPRESSION = 'gzip'

# Task routing for performance
CELERY_TASK_ROUTES = {
    'apps.menus.tasks.sync_menu_to_displays': {'queue': 'high_priority'},
    'apps.displays.tasks.health_check': {'queue': 'monitoring'},
    'apps.analytics.tasks.process_events': {'queue': 'analytics'},
    'apps.media.tasks.optimize_images': {'queue': 'media'},
}

# WebSocket Performance Settings
CHANNEL_LAYERS = {
    'default': {
        'BACKEND': 'channels_redis.core.RedisChannelLayer',
        'CONFIG': {
            'hosts': [REDIS_URL + '/5'],
            'capacity': 1500,
            'expiry': 60,
            'group_expiry': 86400,
            'channel_capacity': {
                'http.request': 200,
                'http.response.*': 10,
                'websocket.send': 20,
                'websocket.receive': 10,
            }
        },
    },
}

# Custom cache decorators and utilities for views
CACHE_TIMEOUTS = {
    'menu_list': 300,      # 5 minutes
    'menu_detail': 600,    # 10 minutes
    'business_info': 1800, # 30 minutes
    'display_status': 60,  # 1 minute
    'analytics': 3600,     # 1 hour
}

# Image optimization settings
IMAGE_OPTIMIZATION = {
    'JPEG_QUALITY': 85,
    'WEBP_QUALITY': 80,
    'MAX_WIDTH': 1920,
    'MAX_HEIGHT': 1080,
    'THUMBNAIL_SIZES': [
        (150, 150),   # Thumbnail
        (300, 300),   # Small
        (600, 600),   # Medium
        (1200, 1200), # Large
    ]
}

# Database connection health check
DATABASE_HEALTH_CHECK = {
    'TIMEOUT': 5,
    'RETRY_COUNT': 3,
    'RETRY_DELAY': 1,
}

# Monitoring and alerting
MONITORING = {
    'ENABLE_APM': os.getenv('ENABLE_APM', 'False').lower() == 'true',
    'APM_SERVICE_NAME': 'displaydeck-backend',
    'HEALTH_CHECK_INTERVAL': 30,  # seconds
    'ERROR_THRESHOLD': 10,  # errors per minute
}
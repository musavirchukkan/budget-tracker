from django.http import JsonResponse
from django.db import connection
from django.core.cache import cache
from django.conf import settings
import time
import sys

def health_check(request):
    """
    Health check endpoint for monitoring and deployment verification
    """
    health_status = {
        'status': 'healthy',
        'timestamp': int(time.time()),
        'version': '1.0.0',
        'environment': 'production' if not settings.DEBUG else 'development',
        'checks': {}
    }
    
    # Database check
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
            cursor.fetchone()
        health_status['checks']['database'] = {
            'status': 'healthy',
            'message': 'Database connection successful'
        }
    except Exception as e:
        health_status['status'] = 'unhealthy'
        health_status['checks']['database'] = {
            'status': 'unhealthy',
            'message': f'Database connection failed: {str(e)}'
        }
    
    # Cache check (if using cache)
    try:
        test_key = 'health_check_test'
        test_value = 'test_value'
        cache.set(test_key, test_value, 10)
        retrieved_value = cache.get(test_key)
        
        if retrieved_value == test_value:
            health_status['checks']['cache'] = {
                'status': 'healthy',
                'message': 'Cache is working'
            }
        else:
            health_status['checks']['cache'] = {
                'status': 'warning',
                'message': 'Cache test failed'
            }
    except Exception as e:
        health_status['checks']['cache'] = {
            'status': 'warning',
            'message': f'Cache check failed: {str(e)}'
        }
    
    # System info
    health_status['system'] = {
        'python_version': sys.version,
        'django_version': settings.SECRET_KEY[:10] + '...' if settings.SECRET_KEY else 'Not set'
    }
    
    # Return appropriate HTTP status
    status_code = 200 if health_status['status'] == 'healthy' else 503
    
    return JsonResponse(health_status, status=status_code)
"""
Database optimization utilities and management commands for DisplayDeck.
Includes query optimization, index management, and performance monitoring.
"""

import logging
import time
from typing import Dict, List, Any, Optional
from django.core.management.base import BaseCommand
from django.db import connection, transaction
from django.conf import settings
from django.core.cache import cache

logger = logging.getLogger(__name__)


class DatabaseOptimizer:
    """
    Database optimization utilities for PostgreSQL.
    """
    
    @staticmethod
    def analyze_slow_queries(threshold_ms: float = 1000) -> List[Dict[str, Any]]:
        """
        Analyze slow queries using pg_stat_statements extension.
        """
        with connection.cursor() as cursor:
            try:
                cursor.execute("""
                    SELECT 
                        query,
                        calls,
                        total_exec_time / calls as avg_time_ms,
                        total_exec_time,
                        rows / calls as avg_rows,
                        100.0 * shared_blks_hit / nullif(shared_blks_hit + shared_blks_read, 0) as hit_percent
                    FROM pg_stat_statements 
                    WHERE calls > 10
                        AND total_exec_time / calls > %s
                    ORDER BY avg_time_ms DESC
                    LIMIT 20;
                """, [threshold_ms])
                
                columns = [desc[0] for desc in cursor.description]
                return [dict(zip(columns, row)) for row in cursor.fetchall()]
                
            except Exception as e:
                logger.error(f"Error analyzing slow queries: {e}")
                return []
    
    @staticmethod
    def get_table_statistics() -> Dict[str, Any]:
        """
        Get table size and activity statistics.
        """
        with connection.cursor() as cursor:
            cursor.execute("""
                SELECT 
                    schemaname,
                    tablename,
                    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size,
                    pg_total_relation_size(schemaname||'.'||tablename) as size_bytes,
                    n_tup_ins as inserts,
                    n_tup_upd as updates,
                    n_tup_del as deletes,
                    n_live_tup as live_rows,
                    n_dead_tup as dead_rows,
                    last_vacuum,
                    last_autovacuum,
                    last_analyze,
                    last_autoanalyze
                FROM pg_stat_user_tables 
                ORDER BY size_bytes DESC;
            """)
            
            columns = [desc[0] for desc in cursor.description]
            return [dict(zip(columns, row)) for row in cursor.fetchall()]
    
    @staticmethod
    def get_index_usage() -> List[Dict[str, Any]]:
        """
        Analyze index usage and identify unused indexes.
        """
        with connection.cursor() as cursor:
            cursor.execute("""
                SELECT 
                    schemaname,
                    tablename,
                    indexname,
                    idx_tup_read,
                    idx_tup_fetch,
                    idx_scan,
                    pg_size_pretty(pg_relation_size(indexrelid)) as size
                FROM pg_stat_user_indexes 
                WHERE idx_scan = 0
                    OR idx_tup_read = 0
                ORDER BY pg_relation_size(indexrelid) DESC;
            """)
            
            columns = [desc[0] for desc in cursor.description]
            return [dict(zip(columns, row)) for row in cursor.fetchall()]
    
    @staticmethod
    def optimize_queries() -> Dict[str, Any]:
        """
        Apply various query optimizations.
        """
        optimizations = {
            'vacuum_analyze': False,
            'reindex': False,
            'update_statistics': False
        }
        
        with connection.cursor() as cursor:
            try:
                # Update table statistics
                cursor.execute("ANALYZE;")
                optimizations['update_statistics'] = True
                
                # Check if vacuum is needed
                cursor.execute("""
                    SELECT count(*) FROM pg_stat_user_tables 
                    WHERE n_dead_tup > n_live_tup * 0.1;
                """)
                
                tables_need_vacuum = cursor.fetchone()[0]
                
                if tables_need_vacuum > 0:
                    # Run vacuum analyze on tables with many dead tuples
                    cursor.execute("""
                        SELECT 'VACUUM ANALYZE ' || schemaname || '.' || tablename || ';'
                        FROM pg_stat_user_tables 
                        WHERE n_dead_tup > n_live_tup * 0.1;
                    """)
                    
                    vacuum_commands = [row[0] for row in cursor.fetchall()]
                    
                    for command in vacuum_commands:
                        cursor.execute(command)
                    
                    optimizations['vacuum_analyze'] = True
                
            except Exception as e:
                logger.error(f"Error during query optimization: {e}")
        
        return optimizations
    
    @staticmethod
    def create_missing_indexes() -> List[str]:
        """
        Suggest missing indexes based on query patterns.
        """
        suggestions = []
        
        with connection.cursor() as cursor:
            try:
                # Find tables with sequential scans
                cursor.execute("""
                    SELECT 
                        schemaname,
                        tablename,
                        seq_scan,
                        seq_tup_read,
                        n_live_tup,
                        seq_tup_read::float / seq_scan as avg_seq_read
                    FROM pg_stat_user_tables 
                    WHERE seq_scan > 0 
                        AND seq_tup_read::float / seq_scan > 1000
                        AND n_live_tup > 10000
                    ORDER BY avg_seq_read DESC;
                """)
                
                for row in cursor.fetchall():
                    schemaname, tablename, seq_scan, seq_tup_read, n_live_tup, avg_seq_read = row
                    
                    suggestions.append(
                        f"Consider adding index to {schemaname}.{tablename} "
                        f"(avg {avg_seq_read:.0f} rows per sequential scan)"
                    )
                
            except Exception as e:
                logger.error(f"Error analyzing missing indexes: {e}")
        
        return suggestions
    
    def optimize_queries(self) -> Dict[str, Any]:
        """
        Apply query optimizations based on analysis.
        """
        optimizations = {
            'update_statistics': False,
            'vacuum_analyze': False,
            'indexes_created': [],
            'errors': []
        }
        
        try:
            with connection.cursor() as cursor:
                # Update table statistics
                if connection.vendor == 'postgresql':
                    cursor.execute("ANALYZE;")
                    optimizations['update_statistics'] = True
                    
                    # Get tables with high dead tuple ratio for vacuuming
                    cursor.execute("""
                        SELECT schemaname, tablename, n_dead_tup, n_live_tup,
                               CASE WHEN n_live_tup > 0 
                                    THEN n_dead_tup::float / n_live_tup 
                                    ELSE 0 
                               END as dead_ratio
                        FROM pg_stat_user_tables 
                        WHERE n_dead_tup > 1000
                        AND (n_dead_tup::float / GREATEST(n_live_tup, 1)) > 0.2
                        ORDER BY dead_ratio DESC
                        LIMIT 10;
                    """)
                    
                    tables_to_vacuum = cursor.fetchall()
                    
                    for table_info in tables_to_vacuum:
                        schema, table, dead_tup, live_tup, ratio = table_info
                        try:
                            cursor.execute(f'VACUUM ANALYZE "{schema}"."{table}";')
                            optimizations['vacuum_analyze'] = True
                        except Exception as e:
                            optimizations['errors'].append(f"Failed to vacuum {schema}.{table}: {str(e)}")
                
        except Exception as e:
            optimizations['errors'].append(f"Optimization error: {str(e)}")
        
        return optimizations
    
    def get_index_usage(self) -> List[Dict[str, Any]]:
        """
        Analyze index usage and identify unused indexes.
        """
        unused_indexes = []
        
        try:
            with connection.cursor() as cursor:
                if connection.vendor == 'postgresql':
                    cursor.execute("""
                        SELECT 
                            schemaname,
                            tablename,
                            indexname,
                            idx_tup_read,
                            idx_tup_fetch,
                            idx_scan,
                            pg_size_pretty(pg_relation_size(indexrelid)) as size
                        FROM pg_stat_user_indexes 
                        JOIN pg_index ON pg_stat_user_indexes.indexrelid = pg_index.indexrelid
                        WHERE idx_scan < 10
                        AND NOT indisunique  -- Don't suggest removing unique indexes
                        AND NOT indisprimary -- Don't suggest removing primary key indexes
                        ORDER BY pg_relation_size(indexrelid) DESC;
                    """)
                    
                    unused_indexes = [
                        {
                            'schema': row[0],
                            'tablename': row[1], 
                            'indexname': row[2],
                            'tuple_reads': row[3],
                            'tuple_fetches': row[4],
                            'scans': row[5],
                            'size': row[6]
                        }
                        for row in cursor.fetchall()
                    ]
                
        except Exception as e:
            logger.error(f"Error analyzing index usage: {str(e)}")
        
        return unused_indexes
    
    @staticmethod
    def monitor_connections() -> Dict[str, Any]:
        """
        Monitor database connections and performance.
        """
        with connection.cursor() as cursor:
            cursor.execute("""
                SELECT 
                    count(*) as total_connections,
                    count(*) FILTER (WHERE state = 'active') as active_connections,
                    count(*) FILTER (WHERE state = 'idle') as idle_connections,
                    count(*) FILTER (WHERE state = 'idle in transaction') as idle_in_transaction,
                    max(extract(epoch from now() - query_start)) as longest_query_seconds,
                    max(extract(epoch from now() - state_change)) as longest_idle_seconds
                FROM pg_stat_activity 
                WHERE datname = current_database();
            """)
            
            row = cursor.fetchone()
            return {
                'total_connections': row[0],
                'active_connections': row[1],
                'idle_connections': row[2],
                'idle_in_transaction': row[3],
                'longest_query_seconds': row[4] or 0,
                'longest_idle_seconds': row[5] or 0,
            }


class CacheOptimizer:
    """
    Cache optimization and management utilities.
    """
    
    @staticmethod
    def analyze_cache_performance() -> Dict[str, Any]:
        """
        Analyze cache hit rates and performance.
        """
        try:
            # Get cache statistics from Redis
            cache_stats = cache._cache.get_stats() if hasattr(cache._cache, 'get_stats') else {}
            
            # Calculate hit rate
            hits = cache_stats.get('hits', 0)
            misses = cache_stats.get('misses', 0)
            total_requests = hits + misses
            
            hit_rate = (hits / total_requests * 100) if total_requests > 0 else 0
            
            return {
                'hit_rate_percent': round(hit_rate, 2),
                'total_hits': hits,
                'total_misses': misses,
                'total_requests': total_requests,
                'cache_stats': cache_stats
            }
            
        except Exception as e:
            logger.error(f"Error analyzing cache performance: {e}")
            return {'error': str(e)}
    
    @staticmethod
    def optimize_cache_keys() -> Dict[str, Any]:
        """
        Analyze and optimize cache key patterns.
        """
        # This would require Redis-specific commands
        # Implementation depends on cache backend
        return {
            'optimizations_applied': [],
            'recommendations': [
                'Use consistent key naming patterns',
                'Set appropriate TTL values',
                'Avoid storing large objects in cache',
                'Use cache versioning for breaking changes'
            ]
        }
    
    @staticmethod
    def clear_expired_keys():
        """
        Clear expired cache keys to free memory.
        """
        try:
            # Force cleanup of expired keys
            cache.clear()
            return True
        except Exception as e:
            logger.error(f"Error clearing expired keys: {e}")
            return False


class QueryProfiler:
    """
    Query profiling and analysis utilities.
    """
    
    def __init__(self):
        self.query_log = []
        self.enabled = getattr(settings, 'ENABLE_QUERY_PROFILING', False)
    
    def start_profiling(self):
        """Start query profiling session."""
        self.query_log = []
        self.enabled = True
    
    def stop_profiling(self):
        """Stop query profiling and return results."""
        self.enabled = False
        return self.analyze_queries()
    
    def log_query(self, query: str, duration: float, params: Optional[List] = None):
        """Log a query execution."""
        if not self.enabled:
            return
            
        self.query_log.append({
            'query': query,
            'duration': duration,
            'params': params,
            'timestamp': time.time()
        })
    
    def analyze_queries(self) -> Dict[str, Any]:
        """Analyze logged queries and provide insights."""
        if not self.query_log:
            return {'total_queries': 0}
        
        total_queries = len(self.query_log)
        total_time = sum(q['duration'] for q in self.query_log)
        avg_time = total_time / total_queries
        
        # Find slow queries
        slow_queries = [q for q in self.query_log if q['duration'] > 100]  # >100ms
        
        # Find duplicate queries
        query_counts = {}
        for query in self.query_log:
            sql = query['query'][:100]  # First 100 chars for grouping
            query_counts[sql] = query_counts.get(sql, 0) + 1
        
        duplicates = {sql: count for sql, count in query_counts.items() if count > 1}
        
        return {
            'total_queries': total_queries,
            'total_time_ms': round(total_time, 2),
            'average_time_ms': round(avg_time, 2),
            'slow_queries': len(slow_queries),
            'duplicate_patterns': len(duplicates),
            'slowest_query': max(self.query_log, key=lambda x: x['duration']) if self.query_log else None,
            'duplicates': duplicates
        }


class OptimizationCommand(BaseCommand):
    """
    Django management command for database optimization.
    Usage: python manage.py optimize_database
    """
    
    help = 'Optimize database performance and analyze queries'
    
    def add_arguments(self, parser):
        parser.add_argument(
            '--analyze-only',
            action='store_true',
            help='Only analyze performance, do not apply optimizations'
        )
        
        parser.add_argument(
            '--slow-query-threshold',
            type=float,
            default=1000,
            help='Slow query threshold in milliseconds (default: 1000)'
        )
    
    def handle(self, *args, **options):
        self.stdout.write(self.style.SUCCESS('Starting database optimization...'))
        
        optimizer = DatabaseOptimizer()
        cache_optimizer = CacheOptimizer()
        
        # Analyze slow queries
        self.stdout.write('Analyzing slow queries...')
        slow_queries = optimizer.analyze_slow_queries(options['slow_query_threshold'])
        
        if slow_queries:
            self.stdout.write(f'Found {len(slow_queries)} slow queries:')
            for query in slow_queries[:5]:  # Show top 5
                self.stdout.write(f"  - {query['avg_time_ms']:.2f}ms: {query['query'][:100]}...")
        else:
            self.stdout.write('No slow queries found.')
        
        # Analyze table statistics
        self.stdout.write('Analyzing table statistics...')
        table_stats = optimizer.get_table_statistics()
        
        if table_stats:
            self.stdout.write('Largest tables:')
            for table in table_stats[:5]:
                self.stdout.write(f"  - {table['tablename']}: {table['size']} ({table['live_rows']} rows)")
        
        # Check index usage
        self.stdout.write('Checking index usage...')
        unused_indexes = optimizer.get_index_usage()
        
        if unused_indexes:
            self.stdout.write(f'Found {len(unused_indexes)} potentially unused indexes:')
            for idx in unused_indexes[:5]:
                self.stdout.write(f"  - {idx['indexname']}: {idx['size']}")
        
        # Analyze cache performance
        self.stdout.write('Analyzing cache performance...')
        cache_stats = cache_optimizer.analyze_cache_performance()
        
        if 'error' not in cache_stats:
            self.stdout.write(f"Cache hit rate: {cache_stats['hit_rate_percent']:.1f}%")
            self.stdout.write(f"Total requests: {cache_stats['total_requests']}")
        
        # Apply optimizations if not analyze-only
        if not options['analyze_only']:
            self.stdout.write('Applying optimizations...')
            
            optimizations = optimizer.optimize_queries()
            
            if optimizations['update_statistics']:
                self.stdout.write('✓ Updated table statistics')
            
            if optimizations['vacuum_analyze']:
                self.stdout.write('✓ Vacuumed tables with high dead tuple ratio')
            
            # Get missing index suggestions
            index_suggestions = optimizer.create_missing_indexes()
            
            if index_suggestions:
                self.stdout.write('Index recommendations:')
                for suggestion in index_suggestions:
                    self.stdout.write(f"  - {suggestion}")
        
        # Monitor connections
        connection_stats = optimizer.monitor_connections()
        self.stdout.write(f"Database connections: {connection_stats['active_connections']} active, {connection_stats['total_connections']} total")
        
        if connection_stats['longest_query_seconds'] > 30:
            self.stdout.write(
                self.style.WARNING(f"Warning: Longest running query: {connection_stats['longest_query_seconds']:.1f}s")
            )
        
        self.stdout.write(self.style.SUCCESS('Database optimization completed!'))


# Export utilities for use in other modules
__all__ = [
    'DatabaseOptimizer',
    'CacheOptimizer', 
    'QueryProfiler',
    'OptimizationCommand'
]
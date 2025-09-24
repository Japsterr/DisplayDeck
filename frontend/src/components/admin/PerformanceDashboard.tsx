/**
 * Performance Dashboard Component for DisplayDeck Admin Panel
 * Provides real-time monitoring of system performance metrics
 */

import React, { useState, useEffect } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Progress } from '@/components/ui/progress';
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { 
  Activity, 
  Database, 
  Zap, 
  AlertTriangle, 
  CheckCircle, 
  RefreshCw,
  TrendingUp,
  Clock
} from 'lucide-react';

interface PerformanceMetrics {
  timestamp: number;
  health_score: number;
  performance: {
    avg_response_time: number;
    requests: number;
    slow_requests: number;
    avg_queries_per_request: number;
  };
  database: {
    health: {
      status: string;
      active_connections: number;
      cache_hit_ratio: number;
    };
    connections: {
      total_connections: number;
      active_connections: number;
      idle_connections: number;
      longest_query_seconds: number;
    };
    table_count: number;
    largest_tables: Array<{
      tablename: string;
      size: string;
      live_rows: number;
    }>;
  };
  cache: {
    hit_rate_percent: number;
    total_hits: number;
    total_misses: number;
    total_requests: number;
  };
  recommendations: Array<{
    type: string;
    priority: 'low' | 'medium' | 'high' | 'critical';
    message: string;
    action: string;
  }>;
}

interface SlowQuery {
  query: string;
  avg_time_ms: number;
  calls: number;
  total_time_ms: number;
}

export const PerformanceDashboard: React.FC = () => {
  const [metrics, setMetrics] = useState<PerformanceMetrics | null>(null);
  const [slowQueries, setSlowQueries] = useState<SlowQuery[]>([]);
  const [loading, setLoading] = useState(true);
  const [autoRefresh, setAutoRefresh] = useState(true);
  const [refreshInterval] = useState(30000); // 30 seconds

  // Fetch performance data
  const fetchPerformanceData = async () => {
    try {
      setLoading(true);
      
      // Fetch main dashboard metrics
      const metricsResponse = await fetch('/api/performance/dashboard/', {
        headers: {
          'Authorization': `Bearer ${localStorage.getItem('token')}`
        }
      });
      
      if (metricsResponse.ok) {
        const metricsData = await metricsResponse.json();
        setMetrics(metricsData);
      }

      // Fetch slow queries
      const queriesResponse = await fetch('/api/performance/slow-queries/', {
        headers: {
          'Authorization': `Bearer ${localStorage.getItem('token')}`
        }
      });
      
      if (queriesResponse.ok) {
        const queriesData = await queriesResponse.json();
        setSlowQueries(queriesData.slow_queries || []);
      }
      
    } catch (error) {
      console.error('Failed to fetch performance data:', error);
    } finally {
      setLoading(false);
    }
  };

  // Auto-refresh effect
  useEffect(() => {
    fetchPerformanceData();
    
    let interval: number;
    if (autoRefresh) {
      interval = setInterval(fetchPerformanceData, refreshInterval);
    }
    
    return () => {
      if (interval) {
        clearInterval(interval);
      }
    };
  }, [autoRefresh, refreshInterval]);

  // Trigger database optimization
  const optimizeDatabase = async () => {
    try {
      const response = await fetch('/api/performance/optimize/', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${localStorage.getItem('token')}`
        },
        body: JSON.stringify({ 
          analyze_only: false,
          clear_cache: true 
        })
      });

      if (response.ok) {
        // Refresh data after optimization
        setTimeout(fetchPerformanceData, 2000);
      }
    } catch (error) {
      console.error('Failed to optimize database:', error);
    }
  };

  const getHealthScoreColor = (score: number) => {
    if (score >= 90) return 'text-green-600';
    if (score >= 70) return 'text-yellow-600';
    if (score >= 50) return 'text-orange-600';
    return 'text-red-600';
  };

  const getPriorityColor = (priority: string) => {
    switch (priority) {
      case 'critical': return 'destructive';
      case 'high': return 'destructive';
      case 'medium': return 'default';
      case 'low': return 'secondary';
      default: return 'default';
    }
  };

  if (loading && !metrics) {
    return (
      <div className="flex items-center justify-center h-64">
        <RefreshCw className="w-8 h-8 animate-spin" />
        <span className="ml-2">Loading performance data...</span>
      </div>
    );
  }

  if (!metrics) {
    return (
      <Alert>
        <AlertTriangle className="h-4 w-4" />
        <AlertTitle>Unable to Load Performance Data</AlertTitle>
        <AlertDescription>
          Failed to fetch performance metrics. Please check your connection and try again.
        </AlertDescription>
      </Alert>
    );
  }

  return (
    <div className="space-y-6 p-6">
      {/* Header */}
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-3xl font-bold">Performance Dashboard</h1>
          <p className="text-muted-foreground">
            Monitor system health and optimize performance
          </p>
        </div>
        
        <div className="flex items-center gap-4">
          <Button
            variant="outline"
            onClick={() => setAutoRefresh(!autoRefresh)}
            className="flex items-center gap-2"
          >
            <Activity className="w-4 h-4" />
            Auto Refresh: {autoRefresh ? 'On' : 'Off'}
          </Button>
          
          <Button 
            onClick={fetchPerformanceData}
            disabled={loading}
            className="flex items-center gap-2"
          >
            <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
            Refresh
          </Button>
          
          <Button 
            onClick={optimizeDatabase}
            variant="secondary"
            className="flex items-center gap-2"
          >
            <Zap className="w-4 h-4" />
            Optimize
          </Button>
        </div>
      </div>

      {/* Health Score */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <CheckCircle className="w-5 h-5" />
            System Health Score
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="flex items-center gap-4">
            <div className={`text-4xl font-bold ${getHealthScoreColor(metrics.health_score)}`}>
              {metrics.health_score}%
            </div>
            <Progress 
              value={metrics.health_score} 
              className="flex-1 h-3"
            />
            <Badge variant={metrics.health_score >= 80 ? 'default' : 'destructive'}>
              {metrics.health_score >= 80 ? 'Healthy' : 'Needs Attention'}
            </Badge>
          </div>
        </CardContent>
      </Card>

      <Tabs defaultValue="overview" className="space-y-6">
        <TabsList>
          <TabsTrigger value="overview">Overview</TabsTrigger>
          <TabsTrigger value="database">Database</TabsTrigger>
          <TabsTrigger value="queries">Slow Queries</TabsTrigger>
          <TabsTrigger value="recommendations">Recommendations</TabsTrigger>
        </TabsList>

        {/* Overview Tab */}
        <TabsContent value="overview" className="space-y-6">
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
            {/* Response Time */}
            <Card>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium">Avg Response Time</CardTitle>
                <Clock className="h-4 w-4 text-muted-foreground" />
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold">
                  {metrics.performance.avg_response_time.toFixed(2)}ms
                </div>
                <p className="text-xs text-muted-foreground">
                  {metrics.performance.slow_requests} slow requests
                </p>
              </CardContent>
            </Card>

            {/* Cache Hit Rate */}
            <Card>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium">Cache Hit Rate</CardTitle>
                <Zap className="h-4 w-4 text-muted-foreground" />
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold">
                  {metrics.cache.hit_rate_percent.toFixed(1)}%
                </div>
                <p className="text-xs text-muted-foreground">
                  {metrics.cache.total_hits.toLocaleString()} hits
                </p>
              </CardContent>
            </Card>

            {/* Database Connections */}
            <Card>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium">DB Connections</CardTitle>
                <Database className="h-4 w-4 text-muted-foreground" />
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold">
                  {metrics.database.connections.active_connections}
                </div>
                <p className="text-xs text-muted-foreground">
                  {metrics.database.connections.total_connections} total
                </p>
              </CardContent>
            </Card>

            {/* Request Volume */}
            <Card>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium">Request Volume</CardTitle>
                <TrendingUp className="h-4 w-4 text-muted-foreground" />
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold">
                  {metrics.performance.requests.toLocaleString()}
                </div>
                <p className="text-xs text-muted-foreground">
                  {metrics.performance.avg_queries_per_request.toFixed(1)} queries/req
                </p>
              </CardContent>
            </Card>
          </div>
        </TabsContent>

        {/* Database Tab */}
        <TabsContent value="database" className="space-y-6">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {/* Database Health */}
            <Card>
              <CardHeader>
                <CardTitle>Database Health</CardTitle>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="flex justify-between items-center">
                  <span>Status:</span>
                  <Badge variant={metrics.database.health.status === 'healthy' ? 'default' : 'destructive'}>
                    {metrics.database.health.status}
                  </Badge>
                </div>
                
                <div className="flex justify-between items-center">
                  <span>Active Connections:</span>
                  <span className="font-mono">{metrics.database.connections.active_connections}</span>
                </div>
                
                <div className="flex justify-between items-center">
                  <span>Idle Connections:</span>
                  <span className="font-mono">{metrics.database.connections.idle_connections}</span>
                </div>
                
                <div className="flex justify-between items-center">
                  <span>Longest Query:</span>
                  <span className="font-mono">
                    {metrics.database.connections.longest_query_seconds.toFixed(1)}s
                  </span>
                </div>
              </CardContent>
            </Card>

            {/* Largest Tables */}
            <Card>
              <CardHeader>
                <CardTitle>Largest Tables</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="space-y-2">
                  {metrics.database.largest_tables.map((table) => (
                    <div key={table.tablename} className="flex justify-between items-center">
                      <span className="font-mono text-sm">{table.tablename}</span>
                      <div className="text-right">
                        <div className="text-sm font-medium">{table.size}</div>
                        <div className="text-xs text-muted-foreground">
                          {table.live_rows.toLocaleString()} rows
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              </CardContent>
            </Card>
          </div>
        </TabsContent>

        {/* Slow Queries Tab */}
        <TabsContent value="queries" className="space-y-6">
          <Card>
            <CardHeader>
              <CardTitle>Slow Queries (&gt;1000ms)</CardTitle>
            </CardHeader>
            <CardContent>
              {slowQueries.length > 0 ? (
                <div className="space-y-4">
                  {slowQueries.map((query, index) => (
                    <div key={index} className="border rounded-lg p-4">
                      <div className="flex justify-between items-start mb-2">
                        <Badge variant="destructive">
                          {query.avg_time_ms.toFixed(2)}ms avg
                        </Badge>
                        <div className="text-sm text-muted-foreground">
                          {query.calls} calls • {query.total_time_ms.toFixed(2)}ms total
                        </div>
                      </div>
                      <pre className="text-sm bg-muted p-2 rounded overflow-x-auto">
                        <code>{query.query}</code>
                      </pre>
                    </div>
                  ))}
                </div>
              ) : (
                <div className="text-center py-8 text-muted-foreground">
                  No slow queries detected
                </div>
              )}
            </CardContent>
          </Card>
        </TabsContent>

        {/* Recommendations Tab */}
        <TabsContent value="recommendations" className="space-y-6">
          <Card>
            <CardHeader>
              <CardTitle>Performance Recommendations</CardTitle>
            </CardHeader>
            <CardContent>
              {metrics.recommendations.length > 0 ? (
                <div className="space-y-4">
                  {metrics.recommendations.map((rec, index) => (
                    <Alert key={index}>
                      <AlertTriangle className="h-4 w-4" />
                      <div className="flex justify-between items-start">
                        <div className="flex-1">
                          <AlertTitle className="flex items-center gap-2">
                            {rec.type.charAt(0).toUpperCase() + rec.type.slice(1)}
                            <Badge variant={getPriorityColor(rec.priority) as any}>
                              {rec.priority}
                            </Badge>
                          </AlertTitle>
                          <AlertDescription className="mt-1">
                            {rec.message}
                          </AlertDescription>
                        </div>
                      </div>
                    </Alert>
                  ))}
                </div>
              ) : (
                <div className="text-center py-8 text-muted-foreground">
                  <CheckCircle className="w-12 h-12 mx-auto mb-4 text-green-500" />
                  No performance issues detected!
                </div>
              )}
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>
    </div>
  );
};
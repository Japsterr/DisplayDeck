/**
 * Mobile Performance Monitor Component for DisplayDeck
 * Provides real-time performance monitoring for React Native app
 */

import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  ScrollView,
  RefreshControl,
  StyleSheet,
  Alert,
  Switch,
} from 'react-native';
import { Card } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';
import { Badge } from '@/components/ui/Badge';
import AsyncStorage from '@react-native-async-storage/async-storage';
import NetInfo from '@react-native-netinfo/netinfo';
import { NativePerformanceMonitor } from '@/utils/performance/optimization';

interface PerformanceMetrics {
  timestamp: number;
  health_score: number;
  app_metrics: {
    memory_usage_mb: number;
    cpu_usage_percent: number;
    battery_level: number;
    network_type: string;
    fps: number;
  };
  cache_metrics: {
    cache_size_mb: number;
    hit_rate_percent: number;
    offline_items: number;
  };
  api_metrics: {
    avg_response_time: number;
    success_rate_percent: number;
    failed_requests: number;
    total_requests: number;
  };
  recommendations: Array<{
    type: string;
    priority: 'low' | 'medium' | 'high' | 'critical';
    message: string;
  }>;
}

export const MobilePerformanceMonitor: React.FC = () => {
  const [metrics, setMetrics] = useState<PerformanceMetrics | null>(null);
  const [loading, setLoading] = useState(true);
  const [monitoring, setMonitoring] = useState(true);
  const [refreshing, setRefreshing] = useState(false);

  const performanceMonitor = new NativePerformanceMonitor();

  // Collect performance metrics
  const collectMetrics = async () => {
    try {
      setLoading(true);

      // Get device metrics
      const memoryInfo = await performanceMonitor.getMemoryInfo();
      const batteryLevel = await performanceMonitor.getBatteryLevel();
      const fpsInfo = await performanceMonitor.getFPS();

      // Get network info
      const networkState = await NetInfo.fetch();

      // Get cache metrics
      const cacheSize = await getCacheSize();
      const offlineItems = await getOfflineItemsCount();

      // Get API metrics from AsyncStorage
      const apiMetrics = await getStoredApiMetrics();

      // Calculate health score
      const healthScore = calculateHealthScore({
        memory: memoryInfo.usedMB,
        battery: batteryLevel,
        fps: fpsInfo.current,
        networkType: networkState.type,
        apiSuccessRate: apiMetrics.success_rate_percent
      });

      // Generate recommendations
      const recommendations = generateRecommendations({
        memory: memoryInfo.usedMB,
        battery: batteryLevel,
        fps: fpsInfo.current,
        cacheSize,
        apiSuccessRate: apiMetrics.success_rate_percent
      });

      const newMetrics: PerformanceMetrics = {
        timestamp: Date.now(),
        health_score: healthScore,
        app_metrics: {
          memory_usage_mb: memoryInfo.usedMB,
          cpu_usage_percent: 0, // Not easily available in RN
          battery_level: batteryLevel,
          network_type: networkState.type || 'unknown',
          fps: fpsInfo.current
        },
        cache_metrics: {
          cache_size_mb: cacheSize,
          hit_rate_percent: 85, // Estimated based on offline capability
          offline_items: offlineItems
        },
        api_metrics: apiMetrics,
        recommendations
      };

      setMetrics(newMetrics);

      // Store metrics for trend analysis
      await AsyncStorage.setItem('performance_metrics', JSON.stringify(newMetrics));

    } catch (error) {
      console.error('Failed to collect performance metrics:', error);
      Alert.alert('Error', 'Failed to collect performance metrics');
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  };

  // Get cache size
  const getCacheSize = async (): Promise<number> => {
    try {
      const keys = await AsyncStorage.getAllKeys();
      let totalSize = 0;

      for (const key of keys) {
        const item = await AsyncStorage.getItem(key);
        if (item) {
          totalSize += new Blob([item]).size;
        }
      }

      return Math.round(totalSize / (1024 * 1024) * 100) / 100; // MB
    } catch (error) {
      console.error('Error calculating cache size:', error);
      return 0;
    }
  };

  // Get offline items count
  const getOfflineItemsCount = async (): Promise<number> => {
    try {
      const keys = await AsyncStorage.getAllKeys();
      const offlineKeys = keys.filter(key => 
        key.startsWith('offline_') || 
        key.startsWith('menu_') || 
        key.startsWith('business_')
      );
      return offlineKeys.length;
    } catch (error) {
      console.error('Error counting offline items:', error);
      return 0;
    }
  };

  // Get stored API metrics
  const getStoredApiMetrics = async () => {
    try {
      const stored = await AsyncStorage.getItem('api_metrics');
      if (stored) {
        return JSON.parse(stored);
      }
    } catch (error) {
      console.error('Error getting API metrics:', error);
    }

    return {
      avg_response_time: 0,
      success_rate_percent: 100,
      failed_requests: 0,
      total_requests: 0
    };
  };

  // Calculate overall health score
  const calculateHealthScore = (factors: {
    memory: number;
    battery: number;
    fps: number;
    networkType: string;
    apiSuccessRate: number;
  }) => {
    let score = 100;

    // Memory penalty (assume 512MB is high usage)
    if (factors.memory > 512) score -= 20;
    else if (factors.memory > 256) score -= 10;

    // Battery penalty
    if (factors.battery < 20) score -= 15;
    else if (factors.battery < 50) score -= 5;

    // FPS penalty (60 FPS is ideal)
    if (factors.fps < 30) score -= 20;
    else if (factors.fps < 45) score -= 10;

    // Network penalty
    if (factors.networkType === 'none') score -= 30;
    else if (factors.networkType === '2g') score -= 15;

    // API success rate penalty
    if (factors.apiSuccessRate < 90) score -= 15;
    else if (factors.apiSuccessRate < 95) score -= 5;

    return Math.max(0, Math.min(100, score));
  };

  // Generate performance recommendations
  const generateRecommendations = (factors: {
    memory: number;
    battery: number;
    fps: number;
    cacheSize: number;
    apiSuccessRate: number;
  }) => {
    const recommendations = [];

    if (factors.memory > 300) {
      recommendations.push({
        type: 'memory',
        priority: factors.memory > 500 ? 'high' : 'medium',
        message: `High memory usage (${factors.memory}MB). Consider clearing cache or restarting the app.`
      });
    }

    if (factors.battery < 20) {
      recommendations.push({
        type: 'battery',
        priority: 'high',
        message: 'Low battery level. Enable battery optimization mode to extend usage time.'
      });
    }

    if (factors.fps < 40) {
      recommendations.push({
        type: 'performance',
        priority: 'medium',
        message: `Low frame rate (${factors.fps} FPS). Close other apps or restart device for better performance.`
      });
    }

    if (factors.cacheSize > 100) {
      recommendations.push({
        type: 'cache',
        priority: 'medium',
        message: `Large cache size (${factors.cacheSize}MB). Consider clearing old cached data.`
      });
    }

    if (factors.apiSuccessRate < 95) {
      recommendations.push({
        type: 'network',
        priority: 'medium',
        message: `API success rate is ${factors.apiSuccessRate}%. Check network connection or try again later.`
      });
    }

    return recommendations;
  };

  // Clear cache and optimize
  const optimizeApp = async () => {
    try {
      Alert.alert(
        'Optimize App',
        'This will clear cached data and restart performance monitoring. Continue?',
        [
          { text: 'Cancel', style: 'cancel' },
          { 
            text: 'Optimize', 
            onPress: async () => {
              // Clear non-essential cache
              const keys = await AsyncStorage.getAllKeys();
              const keysToRemove = keys.filter(key => 
                key.startsWith('cache_') || 
                key.startsWith('temp_')
              );
              
              if (keysToRemove.length > 0) {
                await AsyncStorage.multiRemove(keysToRemove);
              }

              // Restart monitoring
              await collectMetrics();
              
              Alert.alert('Success', 'App optimization completed');
            }
          }
        ]
      );
    } catch (error) {
      console.error('Error optimizing app:', error);
      Alert.alert('Error', 'Failed to optimize app');
    }
  };

  // Monitor performance at intervals
  useEffect(() => {
    collectMetrics();

    let interval: NodeJS.Timeout;
    if (monitoring) {
      interval = setInterval(collectMetrics, 60000); // Every minute
    }

    return () => {
      if (interval) {
        clearInterval(interval);
      }
    };
  }, [monitoring]);

  const onRefresh = () => {
    setRefreshing(true);
    collectMetrics();
  };

  const getHealthScoreColor = (score: number) => {
    if (score >= 90) return styles.healthGood;
    if (score >= 70) return styles.healthWarning;
    return styles.healthCritical;
  };

  const getPriorityColor = (priority: string) => {
    switch (priority) {
      case 'critical': return 'error';
      case 'high': return 'warning';
      case 'medium': return 'info';
      default: return 'default';
    }
  };

  if (loading && !metrics) {
    return (
      <View style={styles.loadingContainer}>
        <Text style={styles.loadingText}>Loading performance data...</Text>
      </View>
    );
  }

  return (
    <ScrollView
      style={styles.container}
      refreshControl={
        <RefreshControl refreshing={refreshing} onRefresh={onRefresh} />
      }
    >
      {/* Header */}
      <View style={styles.header}>
        <Text style={styles.title}>Performance Monitor</Text>
        <View style={styles.monitoringToggle}>
          <Text style={styles.toggleLabel}>Auto Monitor</Text>
          <Switch
            value={monitoring}
            onValueChange={setMonitoring}
          />
        </View>
      </View>

      {metrics && (
        <>
          {/* Health Score */}
          <Card style={styles.healthCard}>
            <Text style={styles.cardTitle}>System Health</Text>
            <View style={styles.healthScoreContainer}>
              <Text style={[styles.healthScore, getHealthScoreColor(metrics.health_score)]}>
                {metrics.health_score}%
              </Text>
              <Badge 
                variant={metrics.health_score >= 80 ? 'success' : 'error'}
                style={styles.healthBadge}
              >
                {metrics.health_score >= 80 ? 'Healthy' : 'Needs Attention'}
              </Badge>
            </View>
          </Card>

          {/* App Metrics */}
          <Card style={styles.card}>
            <Text style={styles.cardTitle}>App Performance</Text>
            <View style={styles.metricsGrid}>
              <View style={styles.metric}>
                <Text style={styles.metricLabel}>Memory Usage</Text>
                <Text style={styles.metricValue}>
                  {metrics.app_metrics.memory_usage_mb.toFixed(1)} MB
                </Text>
              </View>
              
              <View style={styles.metric}>
                <Text style={styles.metricLabel}>Battery Level</Text>
                <Text style={styles.metricValue}>
                  {(metrics.app_metrics.battery_level * 100).toFixed(0)}%
                </Text>
              </View>
              
              <View style={styles.metric}>
                <Text style={styles.metricLabel}>Frame Rate</Text>
                <Text style={styles.metricValue}>
                  {metrics.app_metrics.fps.toFixed(0)} FPS
                </Text>
              </View>
              
              <View style={styles.metric}>
                <Text style={styles.metricLabel}>Network</Text>
                <Text style={styles.metricValue}>
                  {metrics.app_metrics.network_type.toUpperCase()}
                </Text>
              </View>
            </View>
          </Card>

          {/* Cache & API Metrics */}
          <Card style={styles.card}>
            <Text style={styles.cardTitle}>Data & Network</Text>
            <View style={styles.metricsGrid}>
              <View style={styles.metric}>
                <Text style={styles.metricLabel}>Cache Size</Text>
                <Text style={styles.metricValue}>
                  {metrics.cache_metrics.cache_size_mb.toFixed(1)} MB
                </Text>
              </View>
              
              <View style={styles.metric}>
                <Text style={styles.metricLabel}>Offline Items</Text>
                <Text style={styles.metricValue}>
                  {metrics.cache_metrics.offline_items}
                </Text>
              </View>
              
              <View style={styles.metric}>
                <Text style={styles.metricLabel}>API Success</Text>
                <Text style={styles.metricValue}>
                  {metrics.api_metrics.success_rate_percent.toFixed(1)}%
                </Text>
              </View>
              
              <View style={styles.metric}>
                <Text style={styles.metricLabel}>Response Time</Text>
                <Text style={styles.metricValue}>
                  {metrics.api_metrics.avg_response_time.toFixed(0)}ms
                </Text>
              </View>
            </View>
          </Card>

          {/* Recommendations */}
          {metrics.recommendations.length > 0 && (
            <Card style={styles.card}>
              <Text style={styles.cardTitle}>Recommendations</Text>
              {metrics.recommendations.map((rec, index) => (
                <View key={index} style={styles.recommendation}>
                  <Badge variant={getPriorityColor(rec.priority)} style={styles.priorityBadge}>
                    {rec.priority.toUpperCase()}
                  </Badge>
                  <Text style={styles.recommendationText}>{rec.message}</Text>
                </View>
              ))}
            </Card>
          )}

          {/* Actions */}
          <Card style={styles.card}>
            <Button
              title="Optimize App"
              onPress={optimizeApp}
              style={styles.optimizeButton}
            />
          </Card>
        </>
      )}
    </ScrollView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  loadingText: {
    fontSize: 16,
    color: '#666',
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 16,
    backgroundColor: 'white',
    borderBottomWidth: 1,
    borderBottomColor: '#e0e0e0',
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#333',
  },
  monitoringToggle: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  toggleLabel: {
    fontSize: 14,
    color: '#666',
  },
  healthCard: {
    margin: 16,
    padding: 20,
  },
  cardTitle: {
    fontSize: 18,
    fontWeight: '600',
    marginBottom: 16,
    color: '#333',
  },
  healthScoreContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  healthScore: {
    fontSize: 48,
    fontWeight: 'bold',
  },
  healthGood: {
    color: '#22c55e',
  },
  healthWarning: {
    color: '#f59e0b',
  },
  healthCritical: {
    color: '#ef4444',
  },
  healthBadge: {
    marginLeft: 16,
  },
  card: {
    margin: 16,
    marginTop: 0,
    padding: 16,
  },
  metricsGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'space-between',
  },
  metric: {
    width: '48%',
    marginBottom: 16,
  },
  metricLabel: {
    fontSize: 12,
    color: '#666',
    marginBottom: 4,
  },
  metricValue: {
    fontSize: 20,
    fontWeight: '600',
    color: '#333',
  },
  recommendation: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    marginBottom: 12,
    gap: 12,
  },
  priorityBadge: {
    marginTop: 2,
  },
  recommendationText: {
    flex: 1,
    fontSize: 14,
    color: '#333',
    lineHeight: 20,
  },
  optimizeButton: {
    marginTop: 8,
  },
});
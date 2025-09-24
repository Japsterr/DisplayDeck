import { useState, useEffect, useCallback } from 'react';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { webSocketService } from '@/services/websocket';
import { apiService } from '@/services/api';
import { queryKeys } from './useApi';
import { toast } from '@/lib/toast';

export interface DisplayStatus {
  id: string;
  name: string;
  location: string;
  is_online: boolean;
  is_paired: boolean;
  last_heartbeat: string | null;
  current_menu?: string;
  device_info: {
    device_type: string;
    resolution: string;
    user_agent: string;
  };
  connection_quality: 'excellent' | 'good' | 'poor' | 'offline';
  uptime_percentage: number;
}

export interface DisplayGroup {
  id: string;
  name: string;
  displays: DisplayStatus[];
  total_displays: number;
  online_displays: number;
  offline_displays: number;
}

export interface UseDisplaysOptions {
  businessId?: string;
  enableRealTimeUpdates?: boolean;
  refreshInterval?: number;
  groupByLocation?: boolean;
}

export interface DisplayMetrics {
  total: number;
  online: number;
  offline: number;
  paired: number;
  unpaired: number;
  uptime_average: number;
  last_updated: Date;
}

export function useDisplays(options: UseDisplaysOptions = {}) {
  const {
    businessId,
    enableRealTimeUpdates = true,
    refreshInterval = 30000, // 30 seconds
    groupByLocation = false,
  } = options;

  const queryClient = useQueryClient();
  const [metrics, setMetrics] = useState<DisplayMetrics>({
    total: 0,
    online: 0,
    offline: 0,
    paired: 0,
    unpaired: 0,
    uptime_average: 0,
    last_updated: new Date(),
  });

  const [alerts, setAlerts] = useState<string[]>([]);

  // Fetch display data with real-time updates
  const { data: displays = [], isLoading, error, refetch } = useQuery({
    queryKey: businessId ? queryKeys.businessDisplays(businessId) : queryKeys.displays,
    queryFn: () => {
      if (businessId) {
        return apiService.getBusinessDisplays(businessId);
      }
      // Mock implementation for all displays
      return Promise.resolve([]);
    },
    enabled: !!businessId,
    refetchInterval: refreshInterval,
    staleTime: 15000, // 15 seconds
  });

  // Transform display data to include status information
  const displayStatuses: DisplayStatus[] = displays.map(display => {
    const lastHeartbeat = display.last_heartbeat ? new Date(display.last_heartbeat) : null;
    const now = new Date();
    const minutesSinceHeartbeat = lastHeartbeat ? 
      (now.getTime() - lastHeartbeat.getTime()) / (1000 * 60) : Infinity;

    let connectionQuality: DisplayStatus['connection_quality'] = 'offline';
    let isOnline = false;

    if (display.is_paired && lastHeartbeat) {
      if (minutesSinceHeartbeat < 2) {
        connectionQuality = 'excellent';
        isOnline = true;
      } else if (minutesSinceHeartbeat < 5) {
        connectionQuality = 'good';
        isOnline = true;
      } else if (minutesSinceHeartbeat < 15) {
        connectionQuality = 'poor';
        isOnline = true;
      } else {
        connectionQuality = 'offline';
        isOnline = false;
      }
    }

    return {
      id: display.id,
      name: display.name,
      location: display.location,
      is_online: isOnline,
      is_paired: display.is_paired,
      last_heartbeat: display.last_heartbeat || null,
      current_menu: display.assigned_menu,
      device_info: {
        device_type: display.device_type,
        resolution: display.resolution,
        user_agent: (display as any).device_info?.user_agent || 'Unknown',
      },
      connection_quality: connectionQuality,
      uptime_percentage: calculateUptimePercentage(display.last_heartbeat || null, display.created_at),
    };
  });

  // Group displays by location if requested
  const displayGroups: DisplayGroup[] = groupByLocation ? 
    groupDisplaysByLocation(displayStatuses) : 
    [{
      id: 'all',
      name: 'All Displays',
      displays: displayStatuses,
      total_displays: displayStatuses.length,
      online_displays: displayStatuses.filter(d => d.is_online).length,
      offline_displays: displayStatuses.filter(d => !d.is_online).length,
    }];

  // Calculate metrics
  const calculateMetrics = useCallback((displays: DisplayStatus[]): DisplayMetrics => {
    const total = displays.length;
    const online = displays.filter(d => d.is_online).length;
    const offline = total - online;
    const paired = displays.filter(d => d.is_paired).length;
    const unpaired = total - paired;
    const uptime_average = displays.reduce((sum, d) => sum + d.uptime_percentage, 0) / 
      (total || 1);

    return {
      total,
      online,
      offline,
      paired,
      unpaired,
      uptime_average,
      last_updated: new Date(),
    };
  }, []);

  // Update metrics when display data changes
  useEffect(() => {
    setMetrics(calculateMetrics(displayStatuses));
  }, [displayStatuses, calculateMetrics]);

  // Real-time WebSocket updates
  useEffect(() => {
    if (!enableRealTimeUpdates) return;

    const handleDisplayStatus = (event: CustomEvent) => {
      const { display_id, status, last_heartbeat } = event.detail;
      
      // Update specific display in cache
      if (businessId) {
        queryClient.setQueryData(
          queryKeys.businessDisplays(businessId),
          (oldData: any[]) => {
            if (!oldData) return oldData;
            
            return oldData.map(display => 
              display.id === display_id 
                ? { ...display, last_heartbeat, is_active: status === 'online' }
                : display
            );
          }
        );
      }

      // Show alert for status changes
      const displayName = displayStatuses.find(d => d.id === display_id)?.name || display_id;
      
      if (status === 'offline') {
        const alert = `Display "${displayName}" went offline`;
        setAlerts(prev => [...prev, alert]);
        
        toast({
          title: 'Display Offline',
          description: alert,
          variant: 'destructive',
        });
      } else if (status === 'online') {
        setAlerts(prev => prev.filter(alert => !alert.includes(displayName)));
        
        toast({
          title: 'Display Online',
          description: `Display "${displayName}" is back online`,
        });
      }
    };

    window.addEventListener('display-status-changed', handleDisplayStatus as EventListener);

    return () => {
      window.removeEventListener('display-status-changed', handleDisplayStatus as EventListener);
    };
  }, [enableRealTimeUpdates, businessId, displayStatuses, queryClient]);

  // Auto-connect WebSocket when component mounts
  useEffect(() => {
    if (enableRealTimeUpdates && !webSocketService.isConnected) {
      webSocketService.connect().catch(error => {
        console.warn('Failed to connect to WebSocket:', error);
      });
    }
  }, [enableRealTimeUpdates]);

  // Subscribe to display status updates
  useEffect(() => {
    if (!enableRealTimeUpdates || !businessId) return;

    webSocketService.joinRoom(`business_${businessId}_displays`);

    return () => {
      webSocketService.leaveRoom(`business_${businessId}_displays`);
    };
  }, [enableRealTimeUpdates, businessId]);

  // Display management actions
  const refreshDisplayStatus = useCallback(() => {
    refetch();
  }, [refetch]);

  const getDisplayById = useCallback((displayId: string): DisplayStatus | undefined => {
    return displayStatuses.find(d => d.id === displayId);
  }, [displayStatuses]);

  const getOfflineDisplays = useCallback((): DisplayStatus[] => {
    return displayStatuses.filter(d => !d.is_online);
  }, [displayStatuses]);

  const getDisplaysByQuality = useCallback((quality: DisplayStatus['connection_quality']): DisplayStatus[] => {
    return displayStatuses.filter(d => d.connection_quality === quality);
  }, [displayStatuses]);

  const clearAlert = useCallback((alert: string) => {
    setAlerts(prev => prev.filter(a => a !== alert));
  }, []);

  const clearAllAlerts = useCallback(() => {
    setAlerts([]);
  }, []);

  return {
    // Data
    displays: displayStatuses,
    displayGroups,
    metrics,
    alerts,
    
    // State
    isLoading,
    error,
    
    // Actions
    refreshDisplayStatus,
    getDisplayById,
    getOfflineDisplays,
    getDisplaysByQuality,
    clearAlert,
    clearAllAlerts,
    
    // WebSocket connection status
    isConnected: webSocketService.isConnected,
    connectionState: webSocketService.connectionState,
  };
}

// Helper function to calculate uptime percentage
function calculateUptimePercentage(lastHeartbeat: string | null, createdAt: string): number {
  if (!lastHeartbeat) return 0;

  const now = new Date();
  const created = new Date(createdAt);
  const lastSeen = new Date(lastHeartbeat);
  
  const totalTime = now.getTime() - created.getTime();
  const onlineTime = lastSeen.getTime() - created.getTime();
  
  if (totalTime <= 0) return 100;
  
  const percentage = (onlineTime / totalTime) * 100;
  return Math.max(0, Math.min(100, percentage));
}

// Helper function to group displays by location
function groupDisplaysByLocation(displays: DisplayStatus[]): DisplayGroup[] {
  const groups = new Map<string, DisplayStatus[]>();
  
  displays.forEach(display => {
    const location = display.location || 'Unknown Location';
    if (!groups.has(location)) {
      groups.set(location, []);
    }
    groups.get(location)!.push(display);
  });
  
  return Array.from(groups.entries()).map(([location, displays]) => ({
    id: location.toLowerCase().replace(/\s+/g, '_'),
    name: location,
    displays,
    total_displays: displays.length,
    online_displays: displays.filter(d => d.is_online).length,
    offline_displays: displays.filter(d => !d.is_online).length,
  }));
}

// Hook for individual display monitoring
export function useDisplayStatus(displayId: string) {
  const { data: display, isLoading, error, refetch } = useQuery({
    queryKey: queryKeys.display(displayId),
    queryFn: () => apiService.getDisplay(displayId),
    enabled: !!displayId,
    refetchInterval: 10000, // 10 seconds for individual display
    staleTime: 5000,
  });

  const { data: status, isLoading: statusLoading } = useQuery({
    queryKey: ['display-status', displayId],
    queryFn: () => apiService.getDisplayStatus(displayId),
    enabled: !!displayId,
    refetchInterval: 5000, // 5 seconds for status
    staleTime: 2000,
  });

  return {
    display,
    status,
    isLoading: isLoading || statusLoading,
    error,
    refresh: refetch,
  };
}
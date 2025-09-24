import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  RefreshControl,
  Dimensions,
} from 'react-native';
import { useAuth } from '../../navigation/AppNavigation';

const { width } = Dimensions.get('window');

interface BusinessStats {
  totalBusinesses: number;
  activeDisplays: number;
  offlineDisplays: number;
  totalMenus: number;
  recentUpdates: number;
}

interface QuickStat {
  title: string;
  value: string;
  change: string;
  changeType: 'positive' | 'negative' | 'neutral';
  color: string;
}

export default function DashboardScreen() {
  const { user, logout } = useAuth();
  const [loading, setLoading] = useState(false);
  const [stats, setStats] = useState<BusinessStats>({
    totalBusinesses: 3,
    activeDisplays: 12,
    offlineDisplays: 2,
    totalMenus: 8,
    recentUpdates: 5,
  });

  const quickStats: QuickStat[] = [
    {
      title: 'Active Displays',
      value: stats.activeDisplays.toString(),
      change: '+2 from yesterday',
      changeType: 'positive',
      color: '#10b981',
    },
    {
      title: 'Offline Displays',
      value: stats.offlineDisplays.toString(),
      change: '-1 from yesterday',
      changeType: 'positive',
      color: '#ef4444',
    },
    {
      title: 'Total Menus',
      value: stats.totalMenus.toString(),
      change: 'No change',
      changeType: 'neutral',
      color: '#6366f1',
    },
    {
      title: 'Recent Updates',
      value: stats.recentUpdates.toString(),
      change: '+3 today',
      changeType: 'positive',
      color: '#f59e0b',
    },
  ];

  const recentActivity = [
    {
      id: 1,
      title: 'Menu Updated',
      description: 'Dinner Menu - Main Restaurant',
      time: '2 hours ago',
      type: 'menu',
    },
    {
      id: 2,
      title: 'Display Offline',
      description: 'Display #3 - Entrance',
      time: '4 hours ago',
      type: 'display',
    },
    {
      id: 3,
      title: 'New Display Paired',
      description: 'Display #15 - Bar Area',
      time: '1 day ago',
      type: 'display',
    },
    {
      id: 4,
      title: 'Price Changes',
      description: 'Updated 12 items in Lunch Menu',
      time: '2 days ago',
      type: 'menu',
    },
  ];

  const handleRefresh = async () => {
    setLoading(true);
    // Simulate API call
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    // Mock data update
    setStats(prev => ({
      ...prev,
      activeDisplays: prev.activeDisplays + Math.floor(Math.random() * 2),
      recentUpdates: prev.recentUpdates + 1,
    }));
    
    setLoading(false);
  };

  const getActivityIcon = (type: string) => {
    switch (type) {
      case 'menu':
        return '📋';
      case 'display':
        return '🖥️';
      default:
        return '📱';
    }
  };

  return (
    <ScrollView 
      style={styles.container}
      refreshControl={
        <RefreshControl
          refreshing={loading}
          onRefresh={handleRefresh}
          tintColor="#007bff"
        />
      }
    >
      <View style={styles.header}>
        <Text style={styles.greeting}>Welcome back,</Text>
        <Text style={styles.userName}>{user?.name || 'User'}</Text>
      </View>

      <View style={styles.statsContainer}>
        <Text style={styles.sectionTitle}>Overview</Text>
        <View style={styles.statsGrid}>
          {quickStats.map((stat, index) => (
            <TouchableOpacity key={index} style={styles.statCard}>
              <View style={[styles.statIcon, { backgroundColor: `${stat.color}20` }]}>
                <View style={[styles.statDot, { backgroundColor: stat.color }]} />
              </View>
              <Text style={styles.statValue}>{stat.value}</Text>
              <Text style={styles.statTitle}>{stat.title}</Text>
              <Text style={[
                styles.statChange, 
                { color: stat.changeType === 'positive' ? '#10b981' : stat.changeType === 'negative' ? '#ef4444' : '#6b7280' }
              ]}>
                {stat.change}
              </Text>
            </TouchableOpacity>
          ))}
        </View>
      </View>

      <View style={styles.businessOverview}>
        <Text style={styles.sectionTitle}>Business Overview</Text>
        <TouchableOpacity style={styles.businessCard}>
          <View style={styles.businessInfo}>
            <Text style={styles.businessCount}>{stats.totalBusinesses}</Text>
            <Text style={styles.businessLabel}>Active Businesses</Text>
          </View>
          <View style={styles.businessActions}>
            <TouchableOpacity style={styles.actionButton}>
              <Text style={styles.actionButtonText}>Manage</Text>
            </TouchableOpacity>
          </View>
        </TouchableOpacity>
      </View>

      <View style={styles.activityContainer}>
        <View style={styles.activityHeader}>
          <Text style={styles.sectionTitle}>Recent Activity</Text>
          <TouchableOpacity>
            <Text style={styles.viewAllText}>View All</Text>
          </TouchableOpacity>
        </View>
        
        {recentActivity.map((activity) => (
          <TouchableOpacity key={activity.id} style={styles.activityItem}>
            <View style={styles.activityIcon}>
              <Text style={styles.activityEmoji}>
                {getActivityIcon(activity.type)}
              </Text>
            </View>
            <View style={styles.activityContent}>
              <Text style={styles.activityTitle}>{activity.title}</Text>
              <Text style={styles.activityDescription}>{activity.description}</Text>
              <Text style={styles.activityTime}>{activity.time}</Text>
            </View>
          </TouchableOpacity>
        ))}
      </View>

      <View style={styles.quickActions}>
        <Text style={styles.sectionTitle}>Quick Actions</Text>
        <View style={styles.actionGrid}>
          <TouchableOpacity style={styles.quickActionButton}>
            <Text style={styles.quickActionEmoji}>📋</Text>
            <Text style={styles.quickActionText}>Add Menu</Text>
          </TouchableOpacity>
          
          <TouchableOpacity style={styles.quickActionButton}>
            <Text style={styles.quickActionEmoji}>🖥️</Text>
            <Text style={styles.quickActionText}>Pair Display</Text>
          </TouchableOpacity>
          
          <TouchableOpacity style={styles.quickActionButton}>
            <Text style={styles.quickActionEmoji}>📊</Text>
            <Text style={styles.quickActionText}>View Reports</Text>
          </TouchableOpacity>
          
          <TouchableOpacity style={styles.quickActionButton}>
            <Text style={styles.quickActionEmoji}>⚙️</Text>
            <Text style={styles.quickActionText}>Settings</Text>
          </TouchableOpacity>
        </View>
      </View>

      <TouchableOpacity style={styles.logoutButton} onPress={logout}>
        <Text style={styles.logoutButtonText}>Logout</Text>
      </TouchableOpacity>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f8f9fa',
  },
  header: {
    padding: 20,
    paddingTop: 10,
  },
  greeting: {
    fontSize: 16,
    color: '#6b7280',
    marginBottom: 4,
  },
  userName: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#1f2937',
  },
  sectionTitle: {
    fontSize: 20,
    fontWeight: '600',
    color: '#1f2937',
    marginBottom: 16,
  },
  statsContainer: {
    paddingHorizontal: 20,
    marginBottom: 24,
  },
  statsGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'space-between',
  },
  statCard: {
    backgroundColor: 'white',
    borderRadius: 12,
    padding: 16,
    width: (width - 60) / 2,
    marginBottom: 12,
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.05,
    shadowRadius: 8,
    elevation: 2,
  },
  statIcon: {
    width: 32,
    height: 32,
    borderRadius: 8,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 12,
  },
  statDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
  },
  statValue: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#1f2937',
    marginBottom: 4,
  },
  statTitle: {
    fontSize: 14,
    color: '#6b7280',
    marginBottom: 4,
  },
  statChange: {
    fontSize: 12,
    fontWeight: '500',
  },
  businessOverview: {
    paddingHorizontal: 20,
    marginBottom: 24,
  },
  businessCard: {
    backgroundColor: 'white',
    borderRadius: 12,
    padding: 20,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.05,
    shadowRadius: 8,
    elevation: 2,
  },
  businessInfo: {
    flex: 1,
  },
  businessCount: {
    fontSize: 32,
    fontWeight: 'bold',
    color: '#007bff',
    marginBottom: 4,
  },
  businessLabel: {
    fontSize: 16,
    color: '#6b7280',
  },
  businessActions: {
    marginLeft: 16,
  },
  actionButton: {
    backgroundColor: '#007bff',
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 8,
  },
  actionButtonText: {
    color: 'white',
    fontSize: 14,
    fontWeight: '600',
  },
  activityContainer: {
    paddingHorizontal: 20,
    marginBottom: 24,
  },
  activityHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 16,
  },
  viewAllText: {
    color: '#007bff',
    fontSize: 14,
    fontWeight: '500',
  },
  activityItem: {
    backgroundColor: 'white',
    borderRadius: 12,
    padding: 16,
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 8,
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 1,
    },
    shadowOpacity: 0.03,
    shadowRadius: 4,
    elevation: 1,
  },
  activityIcon: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: '#f3f4f6',
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 12,
  },
  activityEmoji: {
    fontSize: 18,
  },
  activityContent: {
    flex: 1,
  },
  activityTitle: {
    fontSize: 14,
    fontWeight: '600',
    color: '#1f2937',
    marginBottom: 2,
  },
  activityDescription: {
    fontSize: 13,
    color: '#6b7280',
    marginBottom: 2,
  },
  activityTime: {
    fontSize: 12,
    color: '#9ca3af',
  },
  quickActions: {
    paddingHorizontal: 20,
    marginBottom: 32,
  },
  actionGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'space-between',
  },
  quickActionButton: {
    backgroundColor: 'white',
    borderRadius: 12,
    padding: 16,
    width: (width - 60) / 2,
    alignItems: 'center',
    marginBottom: 12,
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.05,
    shadowRadius: 8,
    elevation: 2,
  },
  quickActionEmoji: {
    fontSize: 24,
    marginBottom: 8,
  },
  quickActionText: {
    fontSize: 14,
    fontWeight: '500',
    color: '#374151',
  },
  logoutButton: {
    marginHorizontal: 20,
    backgroundColor: '#dc2626',
    borderRadius: 8,
    padding: 16,
    alignItems: 'center',
    marginBottom: 32,
  },
  logoutButtonText: {
    color: 'white',
    fontSize: 16,
    fontWeight: '600',
  },
});
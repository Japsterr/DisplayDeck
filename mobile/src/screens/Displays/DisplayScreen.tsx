import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  Alert,
  Modal,
  RefreshControl,
  Dimensions,
} from 'react-native';
import { BarCodeScanner } from 'expo-barcode-scanner';

const { width, height } = Dimensions.get('window');

interface Display {
  id: string;
  name: string;
  location: string;
  status: 'online' | 'offline' | 'pairing';
  lastSeen: string;
  business: string;
  assignedMenu?: string;
  resolution: string;
}

export default function DisplayScreen() {
  const [displays, setDisplays] = useState<Display[]>([
    {
      id: '1',
      name: 'Main Entrance Display',
      location: 'Front Door',
      status: 'online',
      lastSeen: '2 minutes ago',
      business: 'Main Restaurant',
      assignedMenu: 'Dinner Menu',
      resolution: '1920x1080',
    },
    {
      id: '2',
      name: 'Bar Display',
      location: 'Bar Area',
      status: 'online',
      lastSeen: '1 minute ago',
      business: 'Main Restaurant',
      assignedMenu: 'Drinks Menu',
      resolution: '1280x720',
    },
    {
      id: '3',
      name: 'Kitchen Display',
      location: 'Kitchen',
      status: 'offline',
      lastSeen: '2 hours ago',
      business: 'Main Restaurant',
      resolution: '1024x768',
    },
  ]);

  const [loading, setLoading] = useState(false);
  const [showScanner, setShowScanner] = useState(false);
  const [hasPermission, setHasPermission] = useState<boolean | null>(null);
  const [scanned, setScanned] = useState(false);

  useEffect(() => {
    (async () => {
      const { status } = await BarCodeScanner.requestPermissionsAsync();
      setHasPermission(status === 'granted');
    })();
  }, []);

  const handleRefresh = async () => {
    setLoading(true);
    // Simulate API call
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    // Mock data update - randomly change some display statuses
    setDisplays(prev => prev.map(display => ({
      ...display,
      status: Math.random() > 0.7 ? 'offline' : display.status,
      lastSeen: display.status === 'online' ? 'Just now' : display.lastSeen,
    })));
    
    setLoading(false);
  };

  const handleBarCodeScanned = ({ type, data }: { type: string; data: string }) => {
    setScanned(true);
    
    // Mock QR code processing
    if (data.startsWith('displaydeck://pair/')) {
      const displayId = data.replace('displaydeck://pair/', '');
      Alert.alert(
        'Display Found',
        `Do you want to pair with display: ${displayId}?`,
        [
          { text: 'Cancel', style: 'cancel' },
          { text: 'Pair', onPress: () => handlePairDisplay(displayId) },
        ]
      );
    } else {
      Alert.alert('Invalid QR Code', 'This QR code is not a DisplayDeck pairing code.');
    }
    
    setShowScanner(false);
  };

  const handlePairDisplay = async (displayId: string) => {
    try {
      // Simulate pairing process
      const newDisplay: Display = {
        id: displayId,
        name: `Display ${displayId}`,
        location: 'Unknown',
        status: 'pairing',
        lastSeen: 'Just now',
        business: 'Main Restaurant',
        resolution: '1920x1080',
      };

      setDisplays(prev => [...prev, newDisplay]);

      // Simulate successful pairing after 3 seconds
      setTimeout(() => {
        setDisplays(prev => prev.map(display => 
          display.id === displayId 
            ? { ...display, status: 'online' as const }
            : display
        ));
        Alert.alert('Success', `Display ${displayId} has been paired successfully!`);
      }, 3000);

    } catch (error) {
      Alert.alert('Error', 'Failed to pair display. Please try again.');
    }
  };

  const handleDisplayAction = (display: Display, action: string) => {
    switch (action) {
      case 'restart':
        Alert.alert(
          'Restart Display',
          `Are you sure you want to restart ${display.name}?`,
          [
            { text: 'Cancel', style: 'cancel' },
            { 
              text: 'Restart', 
              style: 'destructive',
              onPress: () => {
                // Simulate restart
                setDisplays(prev => prev.map(d => 
                  d.id === display.id 
                    ? { ...d, status: 'offline' as const }
                    : d
                ));
                setTimeout(() => {
                  setDisplays(prev => prev.map(d => 
                    d.id === display.id 
                      ? { ...d, status: 'online' as const, lastSeen: 'Just now' }
                      : d
                  ));
                }, 5000);
              }
            }
          ]
        );
        break;
      case 'unpair':
        Alert.alert(
          'Unpair Display',
          `Are you sure you want to unpair ${display.name}?`,
          [
            { text: 'Cancel', style: 'cancel' },
            { 
              text: 'Unpair', 
              style: 'destructive',
              onPress: () => {
                setDisplays(prev => prev.filter(d => d.id !== display.id));
              }
            }
          ]
        );
        break;
      case 'assign_menu':
        Alert.alert('Assign Menu', 'Menu assignment feature coming soon!');
        break;
      default:
        break;
    }
  };

  const openQRScanner = () => {
    if (hasPermission === null) {
      Alert.alert('Permission Required', 'Please grant camera permission to scan QR codes.');
      return;
    }
    if (hasPermission === false) {
      Alert.alert('No Camera Access', 'Camera permission is required to scan QR codes.');
      return;
    }
    setScanned(false);
    setShowScanner(true);
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'online':
        return '#10b981';
      case 'offline':
        return '#ef4444';
      case 'pairing':
        return '#f59e0b';
      default:
        return '#6b7280';
    }
  };

  const getStatusText = (status: string) => {
    switch (status) {
      case 'online':
        return 'Online';
      case 'offline':
        return 'Offline';
      case 'pairing':
        return 'Pairing...';
      default:
        return 'Unknown';
    }
  };

  const onlineDisplays = displays.filter(d => d.status === 'online').length;
  const offlineDisplays = displays.filter(d => d.status === 'offline').length;

  return (
    <View style={styles.container}>
      <ScrollView
        refreshControl={
          <RefreshControl
            refreshing={loading}
            onRefresh={handleRefresh}
            tintColor="#007bff"
          />
        }
      >
        <View style={styles.header}>
          <View style={styles.statsContainer}>
            <View style={styles.statItem}>
              <Text style={styles.statValue}>{displays.length}</Text>
              <Text style={styles.statLabel}>Total Displays</Text>
            </View>
            <View style={styles.statItem}>
              <Text style={[styles.statValue, { color: '#10b981' }]}>{onlineDisplays}</Text>
              <Text style={styles.statLabel}>Online</Text>
            </View>
            <View style={styles.statItem}>
              <Text style={[styles.statValue, { color: '#ef4444' }]}>{offlineDisplays}</Text>
              <Text style={styles.statLabel}>Offline</Text>
            </View>
          </View>

          <TouchableOpacity style={styles.pairButton} onPress={openQRScanner}>
            <Text style={styles.pairButtonText}>📱 Pair New Display</Text>
          </TouchableOpacity>
        </View>

        <View style={styles.displaysContainer}>
          <Text style={styles.sectionTitle}>Your Displays</Text>
          
          {displays.map((display) => (
            <View key={display.id} style={styles.displayCard}>
              <View style={styles.displayHeader}>
                <View style={styles.displayInfo}>
                  <Text style={styles.displayName}>{display.name}</Text>
                  <Text style={styles.displayLocation}>📍 {display.location}</Text>
                </View>
                <View style={[styles.statusBadge, { backgroundColor: getStatusColor(display.status) }]}>
                  <Text style={styles.statusText}>{getStatusText(display.status)}</Text>
                </View>
              </View>

              <View style={styles.displayDetails}>
                <View style={styles.detailRow}>
                  <Text style={styles.detailLabel}>Business:</Text>
                  <Text style={styles.detailValue}>{display.business}</Text>
                </View>
                <View style={styles.detailRow}>
                  <Text style={styles.detailLabel}>Resolution:</Text>
                  <Text style={styles.detailValue}>{display.resolution}</Text>
                </View>
                {display.assignedMenu && (
                  <View style={styles.detailRow}>
                    <Text style={styles.detailLabel}>Menu:</Text>
                    <Text style={styles.detailValue}>{display.assignedMenu}</Text>
                  </View>
                )}
                <View style={styles.detailRow}>
                  <Text style={styles.detailLabel}>Last Seen:</Text>
                  <Text style={styles.detailValue}>{display.lastSeen}</Text>
                </View>
              </View>

              <View style={styles.displayActions}>
                <TouchableOpacity 
                  style={styles.actionButton}
                  onPress={() => handleDisplayAction(display, 'assign_menu')}
                >
                  <Text style={styles.actionButtonText}>📋 Menu</Text>
                </TouchableOpacity>
                
                <TouchableOpacity 
                  style={styles.actionButton}
                  onPress={() => handleDisplayAction(display, 'restart')}
                  disabled={display.status === 'offline'}
                >
                  <Text style={[
                    styles.actionButtonText,
                    display.status === 'offline' && styles.disabledText
                  ]}>
                    🔄 Restart
                  </Text>
                </TouchableOpacity>
                
                <TouchableOpacity 
                  style={[styles.actionButton, styles.dangerButton]}
                  onPress={() => handleDisplayAction(display, 'unpair')}
                >
                  <Text style={[styles.actionButtonText, styles.dangerText]}>🗑️ Unpair</Text>
                </TouchableOpacity>
              </View>
            </View>
          ))}

          {displays.length === 0 && (
            <View style={styles.emptyState}>
              <Text style={styles.emptyStateTitle}>No Displays Found</Text>
              <Text style={styles.emptyStateText}>
                Tap "Pair New Display" to scan a QR code and add your first display
              </Text>
            </View>
          )}
        </View>
      </ScrollView>

      {/* QR Scanner Modal */}
      <Modal
        visible={showScanner}
        animationType="slide"
        presentationStyle="pageSheet"
        onRequestClose={() => setShowScanner(false)}
      >
        <View style={styles.scannerContainer}>
          <View style={styles.scannerHeader}>
            <TouchableOpacity 
              style={styles.cancelButton}
              onPress={() => setShowScanner(false)}
            >
              <Text style={styles.cancelButtonText}>Cancel</Text>
            </TouchableOpacity>
            <Text style={styles.scannerTitle}>Scan Display QR Code</Text>
            <View style={styles.placeholder} />
          </View>

          <View style={styles.scanner}>
            <BarCodeScanner
              onBarCodeScanned={scanned ? undefined : handleBarCodeScanned}
              style={StyleSheet.absoluteFillObject}
            />
            <View style={styles.scannerOverlay}>
              <View style={styles.scannerFrame} />
            </View>
          </View>

          <View style={styles.scannerInstructions}>
            <Text style={styles.instructionsText}>
              Position the QR code within the frame to pair a new display
            </Text>
          </View>
        </View>
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f8f9fa',
  },
  header: {
    padding: 20,
    backgroundColor: 'white',
    borderBottomWidth: 1,
    borderBottomColor: '#e5e7eb',
  },
  statsContainer: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    marginBottom: 20,
  },
  statItem: {
    alignItems: 'center',
  },
  statValue: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#1f2937',
    marginBottom: 4,
  },
  statLabel: {
    fontSize: 14,
    color: '#6b7280',
  },
  pairButton: {
    backgroundColor: '#007bff',
    borderRadius: 8,
    padding: 16,
    alignItems: 'center',
  },
  pairButtonText: {
    color: 'white',
    fontSize: 16,
    fontWeight: '600',
  },
  displaysContainer: {
    padding: 20,
  },
  sectionTitle: {
    fontSize: 20,
    fontWeight: '600',
    color: '#1f2937',
    marginBottom: 16,
  },
  displayCard: {
    backgroundColor: 'white',
    borderRadius: 12,
    padding: 16,
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
  displayHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: 12,
  },
  displayInfo: {
    flex: 1,
  },
  displayName: {
    fontSize: 16,
    fontWeight: '600',
    color: '#1f2937',
    marginBottom: 4,
  },
  displayLocation: {
    fontSize: 14,
    color: '#6b7280',
  },
  statusBadge: {
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 12,
    marginLeft: 12,
  },
  statusText: {
    color: 'white',
    fontSize: 12,
    fontWeight: '600',
  },
  displayDetails: {
    marginBottom: 16,
  },
  detailRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 4,
  },
  detailLabel: {
    fontSize: 14,
    color: '#6b7280',
    flex: 1,
  },
  detailValue: {
    fontSize: 14,
    color: '#1f2937',
    flex: 2,
    textAlign: 'right',
  },
  displayActions: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  actionButton: {
    flex: 1,
    backgroundColor: '#f3f4f6',
    borderRadius: 8,
    padding: 8,
    marginHorizontal: 2,
    alignItems: 'center',
  },
  actionButtonText: {
    fontSize: 12,
    color: '#374151',
    fontWeight: '500',
  },
  dangerButton: {
    backgroundColor: '#fef2f2',
  },
  dangerText: {
    color: '#dc2626',
  },
  disabledText: {
    color: '#9ca3af',
  },
  emptyState: {
    alignItems: 'center',
    paddingVertical: 40,
  },
  emptyStateTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: '#374151',
    marginBottom: 8,
  },
  emptyStateText: {
    fontSize: 14,
    color: '#6b7280',
    textAlign: 'center',
    lineHeight: 20,
  },
  // Scanner styles
  scannerContainer: {
    flex: 1,
    backgroundColor: 'black',
  },
  scannerHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingTop: 50,
    paddingHorizontal: 20,
    paddingBottom: 20,
    backgroundColor: 'white',
  },
  cancelButton: {
    padding: 8,
  },
  cancelButtonText: {
    color: '#007bff',
    fontSize: 16,
  },
  scannerTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: '#1f2937',
  },
  placeholder: {
    width: 60,
  },
  scanner: {
    flex: 1,
    position: 'relative',
  },
  scannerOverlay: {
    flex: 1,
    backgroundColor: 'transparent',
    justifyContent: 'center',
    alignItems: 'center',
  },
  scannerFrame: {
    width: 250,
    height: 250,
    borderWidth: 2,
    borderColor: '#007bff',
    borderRadius: 12,
    backgroundColor: 'transparent',
  },
  scannerInstructions: {
    backgroundColor: 'white',
    padding: 20,
  },
  instructionsText: {
    fontSize: 16,
    color: '#374151',
    textAlign: 'center',
    lineHeight: 24,
  },
});
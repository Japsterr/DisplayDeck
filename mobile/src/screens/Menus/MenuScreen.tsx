import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  TextInput,
  Modal,
  Alert,
  RefreshControl,
} from 'react-native';

interface MenuItem {
  id: string;
  name: string;
  description: string;
  price: number;
  category: string;
  available: boolean;
  imageUrl?: string;
}

interface Menu {
  id: string;
  name: string;
  description: string;
  items: MenuItem[];
  lastUpdated: string;
  isActive: boolean;
}

export default function MenuScreen() {
  const [menus, setMenus] = useState<Menu[]>([
    {
      id: '1',
      name: 'Dinner Menu',
      description: 'Our signature dinner offerings',
      lastUpdated: '2 hours ago',
      isActive: true,
      items: [
        {
          id: '1',
          name: 'Grilled Salmon',
          description: 'Fresh Atlantic salmon with seasonal vegetables',
          price: 28.99,
          category: 'Main Course',
          available: true,
        },
        {
          id: '2',
          name: 'Caesar Salad',
          description: 'Crisp romaine with house-made dressing',
          price: 14.99,
          category: 'Salads',
          available: true,
        },
        {
          id: '3',
          name: 'Beef Tenderloin',
          description: 'Premium cut with truffle sauce',
          price: 42.99,
          category: 'Main Course',
          available: false,
        },
      ],
    },
    {
      id: '2',
      name: 'Lunch Menu',
      description: 'Light and delicious lunch options',
      lastUpdated: '1 day ago',
      isActive: true,
      items: [
        {
          id: '4',
          name: 'Club Sandwich',
          description: 'Triple-decker with fresh ingredients',
          price: 16.99,
          category: 'Sandwiches',
          available: true,
        },
        {
          id: '5',
          name: 'Soup of the Day',
          description: 'Ask your server about today\'s selection',
          price: 8.99,
          category: 'Soups',
          available: true,
        },
      ],
    },
  ]);

  const [loading, setLoading] = useState(false);
  const [selectedMenu, setSelectedMenu] = useState<Menu | null>(null);
  const [showMenuModal, setShowMenuModal] = useState(false);
  const [showItemModal, setShowItemModal] = useState(false);
  const [selectedItem, setSelectedItem] = useState<MenuItem | null>(null);
  const [editingItem, setEditingItem] = useState<Partial<MenuItem>>({});

  const handleRefresh = async () => {
    setLoading(true);
    // Simulate API call
    await new Promise(resolve => setTimeout(resolve, 2000));
    setLoading(false);
  };

  const openMenuDetails = (menu: Menu) => {
    setSelectedMenu(menu);
    setShowMenuModal(true);
  };

  const openItemEditor = (item?: MenuItem) => {
    if (item) {
      setSelectedItem(item);
      setEditingItem({ ...item });
    } else {
      setSelectedItem(null);
      setEditingItem({
        name: '',
        description: '',
        price: 0,
        category: 'Main Course',
        available: true,
      });
    }
    setShowItemModal(true);
  };

  const saveMenuItem = () => {
    if (!editingItem.name || !editingItem.description || editingItem.price === 0) {
      Alert.alert('Error', 'Please fill in all required fields.');
      return;
    }

    if (selectedItem) {
      // Update existing item
      setMenus(prev => prev.map(menu => ({
        ...menu,
        items: menu.items.map(item => 
          item.id === selectedItem.id 
            ? { ...item, ...editingItem } as MenuItem
            : item
        ),
      })));
    } else {
      // Add new item to selected menu
      if (!selectedMenu) return;
      
      const newItem: MenuItem = {
        ...editingItem as MenuItem,
        id: Date.now().toString(),
      };

      setMenus(prev => prev.map(menu => 
        menu.id === selectedMenu.id 
          ? { ...menu, items: [...menu.items, newItem] }
          : menu
      ));
    }

    setShowItemModal(false);
    setEditingItem({});
  };

  const deleteMenuItem = (itemId: string) => {
    Alert.alert(
      'Delete Item',
      'Are you sure you want to delete this menu item?',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Delete',
          style: 'destructive',
          onPress: () => {
            setMenus(prev => prev.map(menu => ({
              ...menu,
              items: menu.items.filter(item => item.id !== itemId),
            })));
            setShowMenuModal(false);
          },
        },
      ]
    );
  };

  const toggleItemAvailability = (itemId: string) => {
    setMenus(prev => prev.map(menu => ({
      ...menu,
      items: menu.items.map(item => 
        item.id === itemId 
          ? { ...item, available: !item.available }
          : item
      ),
    })));
  };

  const getItemCountByCategory = (menu: Menu) => {
    const categories: { [key: string]: number } = {};
    menu.items.forEach(item => {
      categories[item.category] = (categories[item.category] || 0) + 1;
    });
    return categories;
  };

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
          <Text style={styles.title}>Menu Management</Text>
          <TouchableOpacity style={styles.addButton}>
            <Text style={styles.addButtonText}>+ New Menu</Text>
          </TouchableOpacity>
        </View>

        <View style={styles.menusContainer}>
          {menus.map((menu) => {
            const categories = getItemCountByCategory(menu);
            const availableItems = menu.items.filter(item => item.available).length;
            
            return (
              <TouchableOpacity
                key={menu.id}
                style={styles.menuCard}
                onPress={() => openMenuDetails(menu)}
              >
                <View style={styles.menuHeader}>
                  <View style={styles.menuInfo}>
                    <Text style={styles.menuName}>{menu.name}</Text>
                    <Text style={styles.menuDescription}>{menu.description}</Text>
                  </View>
                  <View style={[
                    styles.statusBadge,
                    { backgroundColor: menu.isActive ? '#10b981' : '#6b7280' }
                  ]}>
                    <Text style={styles.statusText}>
                      {menu.isActive ? 'Active' : 'Inactive'}
                    </Text>
                  </View>
                </View>

                <View style={styles.menuStats}>
                  <View style={styles.statItem}>
                    <Text style={styles.statValue}>{menu.items.length}</Text>
                    <Text style={styles.statLabel}>Total Items</Text>
                  </View>
                  <View style={styles.statItem}>
                    <Text style={[styles.statValue, { color: '#10b981' }]}>
                      {availableItems}
                    </Text>
                    <Text style={styles.statLabel}>Available</Text>
                  </View>
                  <View style={styles.statItem}>
                    <Text style={styles.statValue}>
                      {Object.keys(categories).length}
                    </Text>
                    <Text style={styles.statLabel}>Categories</Text>
                  </View>
                </View>

                <Text style={styles.lastUpdated}>
                  Last updated: {menu.lastUpdated}
                </Text>
              </TouchableOpacity>
            );
          })}
        </View>
      </ScrollView>

      {/* Menu Details Modal */}
      <Modal
        visible={showMenuModal}
        animationType="slide"
        presentationStyle="pageSheet"
        onRequestClose={() => setShowMenuModal(false)}
      >
        <View style={styles.modalContainer}>
          <View style={styles.modalHeader}>
            <TouchableOpacity onPress={() => setShowMenuModal(false)}>
              <Text style={styles.cancelText}>Done</Text>
            </TouchableOpacity>
            <Text style={styles.modalTitle}>{selectedMenu?.name}</Text>
            <TouchableOpacity onPress={() => openItemEditor()}>
              <Text style={styles.addText}>+ Add Item</Text>
            </TouchableOpacity>
          </View>

          <ScrollView style={styles.itemsList}>
            {selectedMenu?.items.map((item) => (
              <View key={item.id} style={styles.itemCard}>
                <View style={styles.itemHeader}>
                  <View style={styles.itemInfo}>
                    <Text style={styles.itemName}>{item.name}</Text>
                    <Text style={styles.itemCategory}>{item.category}</Text>
                    <Text style={styles.itemDescription}>{item.description}</Text>
                  </View>
                  <View style={styles.itemPrice}>
                    <Text style={styles.priceValue}>${item.price.toFixed(2)}</Text>
                    <View style={[
                      styles.availabilityBadge,
                      { backgroundColor: item.available ? '#10b981' : '#ef4444' }
                    ]}>
                      <Text style={styles.availabilityText}>
                        {item.available ? 'Available' : 'Unavailable'}
                      </Text>
                    </View>
                  </View>
                </View>

                <View style={styles.itemActions}>
                  <TouchableOpacity
                    style={styles.actionButton}
                    onPress={() => openItemEditor(item)}
                  >
                    <Text style={styles.actionText}>✏️ Edit</Text>
                  </TouchableOpacity>
                  
                  <TouchableOpacity
                    style={styles.actionButton}
                    onPress={() => toggleItemAvailability(item.id)}
                  >
                    <Text style={styles.actionText}>
                      {item.available ? '❌ Disable' : '✅ Enable'}
                    </Text>
                  </TouchableOpacity>
                  
                  <TouchableOpacity
                    style={[styles.actionButton, styles.deleteButton]}
                    onPress={() => deleteMenuItem(item.id)}
                  >
                    <Text style={[styles.actionText, styles.deleteText]}>
                      🗑️ Delete
                    </Text>
                  </TouchableOpacity>
                </View>
              </View>
            ))}
          </ScrollView>
        </View>
      </Modal>

      {/* Item Editor Modal */}
      <Modal
        visible={showItemModal}
        animationType="slide"
        presentationStyle="formSheet"
        onRequestClose={() => setShowItemModal(false)}
      >
        <View style={styles.modalContainer}>
          <View style={styles.modalHeader}>
            <TouchableOpacity onPress={() => setShowItemModal(false)}>
              <Text style={styles.cancelText}>Cancel</Text>
            </TouchableOpacity>
            <Text style={styles.modalTitle}>
              {selectedItem ? 'Edit Item' : 'Add Item'}
            </Text>
            <TouchableOpacity onPress={saveMenuItem}>
              <Text style={styles.saveText}>Save</Text>
            </TouchableOpacity>
          </View>

          <ScrollView style={styles.formContainer}>
            <View style={styles.inputGroup}>
              <Text style={styles.inputLabel}>Name *</Text>
              <TextInput
                style={styles.input}
                value={editingItem.name}
                onChangeText={(text) => setEditingItem(prev => ({ ...prev, name: text }))}
                placeholder="Enter item name"
                placeholderTextColor="#9ca3af"
              />
            </View>

            <View style={styles.inputGroup}>
              <Text style={styles.inputLabel}>Description *</Text>
              <TextInput
                style={[styles.input, styles.textArea]}
                value={editingItem.description}
                onChangeText={(text) => setEditingItem(prev => ({ ...prev, description: text }))}
                placeholder="Enter item description"
                placeholderTextColor="#9ca3af"
                multiline
                numberOfLines={3}
              />
            </View>

            <View style={styles.inputGroup}>
              <Text style={styles.inputLabel}>Price *</Text>
              <TextInput
                style={styles.input}
                value={editingItem.price?.toString() || ''}
                onChangeText={(text) => {
                  const price = parseFloat(text) || 0;
                  setEditingItem(prev => ({ ...prev, price }));
                }}
                placeholder="0.00"
                placeholderTextColor="#9ca3af"
                keyboardType="decimal-pad"
              />
            </View>

            <View style={styles.inputGroup}>
              <Text style={styles.inputLabel}>Category</Text>
              <View style={styles.categoryButtons}>
                {['Appetizers', 'Main Course', 'Desserts', 'Beverages', 'Salads', 'Soups'].map((category) => (
                  <TouchableOpacity
                    key={category}
                    style={[
                      styles.categoryButton,
                      editingItem.category === category && styles.selectedCategory
                    ]}
                    onPress={() => setEditingItem(prev => ({ ...prev, category }))}
                  >
                    <Text style={[
                      styles.categoryButtonText,
                      editingItem.category === category && styles.selectedCategoryText
                    ]}>
                      {category}
                    </Text>
                  </TouchableOpacity>
                ))}
              </View>
            </View>

            <View style={styles.inputGroup}>
              <View style={styles.switchRow}>
                <Text style={styles.inputLabel}>Available</Text>
                <TouchableOpacity
                  style={[
                    styles.switch,
                    { backgroundColor: editingItem.available ? '#007bff' : '#d1d5db' }
                  ]}
                  onPress={() => setEditingItem(prev => ({ ...prev, available: !prev.available }))}
                >
                  <View style={[
                    styles.switchThumb,
                    { transform: [{ translateX: editingItem.available ? 20 : 2 }] }
                  ]} />
                </TouchableOpacity>
              </View>
            </View>
          </ScrollView>
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
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 20,
    backgroundColor: 'white',
    borderBottomWidth: 1,
    borderBottomColor: '#e5e7eb',
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#1f2937',
  },
  addButton: {
    backgroundColor: '#007bff',
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 8,
  },
  addButtonText: {
    color: 'white',
    fontSize: 14,
    fontWeight: '600',
  },
  menusContainer: {
    padding: 20,
  },
  menuCard: {
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
  menuHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: 12,
  },
  menuInfo: {
    flex: 1,
  },
  menuName: {
    fontSize: 18,
    fontWeight: '600',
    color: '#1f2937',
    marginBottom: 4,
  },
  menuDescription: {
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
  menuStats: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    marginBottom: 12,
    paddingVertical: 12,
    backgroundColor: '#f9fafb',
    borderRadius: 8,
  },
  statItem: {
    alignItems: 'center',
  },
  statValue: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#1f2937',
    marginBottom: 4,
  },
  statLabel: {
    fontSize: 12,
    color: '#6b7280',
  },
  lastUpdated: {
    fontSize: 12,
    color: '#9ca3af',
    textAlign: 'center',
  },
  // Modal styles
  modalContainer: {
    flex: 1,
    backgroundColor: '#f8f9fa',
  },
  modalHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 16,
    backgroundColor: 'white',
    borderBottomWidth: 1,
    borderBottomColor: '#e5e7eb',
  },
  modalTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: '#1f2937',
  },
  cancelText: {
    color: '#6b7280',
    fontSize: 16,
  },
  addText: {
    color: '#007bff',
    fontSize: 16,
    fontWeight: '600',
  },
  saveText: {
    color: '#007bff',
    fontSize: 16,
    fontWeight: '600',
  },
  itemsList: {
    flex: 1,
    padding: 16,
  },
  itemCard: {
    backgroundColor: 'white',
    borderRadius: 12,
    padding: 16,
    marginBottom: 12,
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 1,
    },
    shadowOpacity: 0.03,
    shadowRadius: 4,
    elevation: 1,
  },
  itemHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 12,
  },
  itemInfo: {
    flex: 1,
  },
  itemName: {
    fontSize: 16,
    fontWeight: '600',
    color: '#1f2937',
    marginBottom: 2,
  },
  itemCategory: {
    fontSize: 12,
    color: '#007bff',
    fontWeight: '500',
    marginBottom: 4,
  },
  itemDescription: {
    fontSize: 14,
    color: '#6b7280',
    lineHeight: 20,
  },
  itemPrice: {
    alignItems: 'flex-end',
    marginLeft: 12,
  },
  priceValue: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#1f2937',
    marginBottom: 4,
  },
  availabilityBadge: {
    paddingHorizontal: 6,
    paddingVertical: 2,
    borderRadius: 8,
  },
  availabilityText: {
    color: 'white',
    fontSize: 10,
    fontWeight: '600',
  },
  itemActions: {
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
  actionText: {
    fontSize: 12,
    color: '#374151',
    fontWeight: '500',
  },
  deleteButton: {
    backgroundColor: '#fef2f2',
  },
  deleteText: {
    color: '#dc2626',
  },
  // Form styles
  formContainer: {
    flex: 1,
    padding: 16,
  },
  inputGroup: {
    marginBottom: 20,
  },
  inputLabel: {
    fontSize: 16,
    fontWeight: '500',
    color: '#374151',
    marginBottom: 8,
  },
  input: {
    backgroundColor: 'white',
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 12,
    fontSize: 16,
    borderWidth: 1,
    borderColor: '#d1d5db',
  },
  textArea: {
    height: 80,
    textAlignVertical: 'top',
  },
  categoryButtons: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    marginTop: 8,
  },
  categoryButton: {
    backgroundColor: '#f3f4f6',
    borderRadius: 16,
    paddingHorizontal: 12,
    paddingVertical: 6,
    marginRight: 8,
    marginBottom: 8,
  },
  selectedCategory: {
    backgroundColor: '#007bff',
  },
  categoryButtonText: {
    fontSize: 14,
    color: '#374151',
    fontWeight: '500',
  },
  selectedCategoryText: {
    color: 'white',
  },
  switchRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  switch: {
    width: 44,
    height: 24,
    borderRadius: 12,
    justifyContent: 'center',
    position: 'relative',
  },
  switchThumb: {
    width: 20,
    height: 20,
    borderRadius: 10,
    backgroundColor: 'white',
    position: 'absolute',
  },
});
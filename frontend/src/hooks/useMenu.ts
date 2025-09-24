import { useState, useCallback, useEffect } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { apiService } from '@/services/api';
import { webSocketService } from '@/services/websocket';
import { toast } from '@/lib/toast';
import { queryKeys } from './useApi';

export interface MenuItem {
  id: string;
  name: string;
  description: string;
  price: number;
  category: string;
  is_available: boolean;
  image_url?: string;
  display_order: number;
}

export interface MenuCategory {
  id: string;
  name: string;
  description: string;
  display_order: number;
  items: MenuItem[];
}

export interface Menu {
  id: string;
  name: string;
  description: string;
  business: string;
  categories: MenuCategory[];
  version: number;
  is_published: boolean;
  created_at: string;
  updated_at: string;
}

export interface MenuState {
  menu: Menu | null;
  isLoading: boolean;
  isDirty: boolean;
  lastSaved: Date | null;
  pendingChanges: string[];
}

export interface UseMenuOptions {
  menuId?: string;
  enableOptimisticUpdates?: boolean;
  enableRealTimeUpdates?: boolean;
  autoSave?: boolean;
  autoSaveDelay?: number;
}

export function useMenu(options: UseMenuOptions = {}) {
  const {
    menuId,
    enableOptimisticUpdates = true,
    enableRealTimeUpdates = true,
    autoSave = false,
    autoSaveDelay = 2000,
  } = options;

  const queryClient = useQueryClient();
  const [state, setState] = useState<MenuState>({
    menu: null,
    isLoading: false,
    isDirty: false,
    lastSaved: null,
    pendingChanges: [],
  });

  const [autoSaveTimeout, setAutoSaveTimeout] = useState<number | null>(null);

  // Update menu mutation with optimistic updates
  const updateMenuMutation = useMutation({
    mutationFn: ({ id, data }: { id: string; data: any }) => 
      apiService.updateMenu(id, data),
    onMutate: async ({ id, data }) => {
      if (!enableOptimisticUpdates) return;

      // Cancel outgoing refetches
      await queryClient.cancelQueries({ queryKey: queryKeys.menu(id) });

      // Snapshot previous value
      const previousMenu = queryClient.getQueryData(queryKeys.menu(id));

      // Optimistically update
      queryClient.setQueryData(queryKeys.menu(id), (old: Menu | undefined) => {
        if (!old) return old;
        return { ...old, ...data };
      });

      return { previousMenu };
    },
    onError: (_, { id }, context) => {
      // Rollback on error
      if (context?.previousMenu) {
        queryClient.setQueryData(queryKeys.menu(id), context.previousMenu);
      }
      
      toast({
        title: 'Update Failed',
        description: 'Failed to update menu. Changes have been reverted.',
        variant: 'destructive',
      });
    },
    onSuccess: () => {
      setState(prev => ({
        ...prev,
        isDirty: false,
        lastSaved: new Date(),
        pendingChanges: [],
      }));

      toast({
        title: 'Menu Updated',
        description: 'Menu changes saved successfully!',
      });
    },
    onSettled: (_, __, { id }) => {
      queryClient.invalidateQueries({ queryKey: queryKeys.menu(id) });
    },
  });

  // Update item price with optimistic updates
  const updateItemPriceMutation = useMutation({
    mutationFn: ({ itemId, price }: { menuId: string; itemId: string; price: number }) =>
      apiService.updateMenuItemPrice(itemId, price.toString()),
    onMutate: async ({ menuId, itemId, price }) => {
      if (!enableOptimisticUpdates) return;

      await queryClient.cancelQueries({ queryKey: queryKeys.menu(menuId) });
      const previousMenu = queryClient.getQueryData(queryKeys.menu(menuId));

      // Optimistically update the price
      queryClient.setQueryData(queryKeys.menu(menuId), (old: Menu | undefined) => {
        if (!old) return old;
        
        return {
          ...old,
          categories: old.categories.map(category => ({
            ...category,
            items: category.items.map(item =>
              item.id === itemId ? { ...item, price } : item
            ),
          })),
        };
      });

      return { previousMenu };
    },
    onError: (_, { menuId }, context) => {
      if (context?.previousMenu) {
        queryClient.setQueryData(queryKeys.menu(menuId), context.previousMenu);
      }
      
      toast({
        title: 'Price Update Failed',
        description: 'Failed to update item price. Change has been reverted.',
        variant: 'destructive',
      });
    },
    onSuccess: (_, { menuId, itemId, price }) => {
      toast({
        title: 'Price Updated',
        description: `Item price updated to $${price.toFixed(2)}`,
      });

      // Broadcast to WebSocket for real-time updates
      webSocketService.sendMessage({
        type: 'price_update',
        data: { menu_id: menuId, item_id: itemId, price },
      });
    },
  });

  // Local state update functions
  const updateMenu = useCallback((updates: Partial<Menu>) => {
    setState(prev => {
      const newMenu = prev.menu ? { ...prev.menu, ...updates } : null;
      return {
        ...prev,
        menu: newMenu,
        isDirty: true,
        pendingChanges: [...prev.pendingChanges, `menu_${Date.now()}`],
      };
    });

    // Auto-save if enabled
    if (autoSave && menuId) {
      if (autoSaveTimeout) {
        clearTimeout(autoSaveTimeout);
      }

      const timeout = setTimeout(() => {
        updateMenuMutation.mutate({ id: menuId, data: updates });
      }, autoSaveDelay);

      setAutoSaveTimeout(timeout);
    }
  }, [menuId, autoSave, autoSaveDelay, autoSaveTimeout, updateMenuMutation]);

  const updateMenuItem = useCallback((itemId: string, updates: Partial<MenuItem>) => {
    setState(prev => {
      if (!prev.menu) return prev;

      const newMenu = {
        ...prev.menu,
        categories: prev.menu.categories.map(category => ({
          ...category,
          items: category.items.map(item =>
            item.id === itemId ? { ...item, ...updates } : item
          ),
        })),
      };

      return {
        ...prev,
        menu: newMenu,
        isDirty: true,
        pendingChanges: [...prev.pendingChanges, `item_${itemId}_${Date.now()}`],
      };
    });
  }, []);

  const updateItemPrice = useCallback((itemId: string, price: number) => {
    if (!menuId) return;

    updateItemPriceMutation.mutate({ menuId, itemId, price });
  }, [menuId, updateItemPriceMutation]);

  const addMenuItem = useCallback((categoryId: string, item: Omit<MenuItem, 'id'>) => {
    const newItem: MenuItem = {
      ...item,
      id: `temp_${Date.now()}`, // Temporary ID until saved
    };

    setState(prev => {
      if (!prev.menu) return prev;

      const newMenu = {
        ...prev.menu,
        categories: prev.menu.categories.map(category =>
          category.id === categoryId
            ? { ...category, items: [...category.items, newItem] }
            : category
        ),
      };

      return {
        ...prev,
        menu: newMenu,
        isDirty: true,
        pendingChanges: [...prev.pendingChanges, `add_item_${Date.now()}`],
      };
    });
  }, []);

  const removeMenuItem = useCallback((itemId: string) => {
    setState(prev => {
      if (!prev.menu) return prev;

      const newMenu = {
        ...prev.menu,
        categories: prev.menu.categories.map(category => ({
          ...category,
          items: category.items.filter(item => item.id !== itemId),
        })),
      };

      return {
        ...prev,
        menu: newMenu,
        isDirty: true,
        pendingChanges: [...prev.pendingChanges, `remove_item_${itemId}_${Date.now()}`],
      };
    });
  }, []);

  const reorderItems = useCallback((categoryId: string, itemIds: string[]) => {
    setState(prev => {
      if (!prev.menu) return prev;

      const newMenu = {
        ...prev.menu,
        categories: prev.menu.categories.map(category => {
          if (category.id !== categoryId) return category;

          const reorderedItems = itemIds
            .map(id => category.items.find(item => item.id === id))
            .filter(Boolean)
            .map((item, index) => ({ ...item!, display_order: index }));

          return { ...category, items: reorderedItems };
        }),
      };

      return {
        ...prev,
        menu: newMenu,
        isDirty: true,
        pendingChanges: [...prev.pendingChanges, `reorder_${categoryId}_${Date.now()}`],
      };
    });
  }, []);

  const saveChanges = useCallback(() => {
    if (!menuId || !state.menu || !state.isDirty) return;

    updateMenuMutation.mutate({
      id: menuId,
      data: state.menu,
    });
  }, [menuId, state.menu, state.isDirty, updateMenuMutation]);

  const discardChanges = useCallback(() => {
    if (menuId) {
      queryClient.refetchQueries({ queryKey: queryKeys.menu(menuId) });
    }
    
    setState(prev => ({
      ...prev,
      isDirty: false,
      pendingChanges: [],
    }));
  }, [menuId, queryClient]);

  // Real-time update listeners
  useEffect(() => {
    if (!enableRealTimeUpdates || !menuId) return;

    const handleMenuUpdate = (event: CustomEvent) => {
      const { menuId: updatedMenuId } = event.detail;
      
      if (updatedMenuId === menuId) {
        queryClient.invalidateQueries({ queryKey: queryKeys.menu(menuId) });
        
        toast({
          title: 'Menu Updated',
          description: 'Menu has been updated by another user.',
        });
      }
    };

    const handlePriceUpdate = (event: CustomEvent) => {
      const { menu_id: updatedMenuId } = event.detail;
      
      if (updatedMenuId === menuId) {
        queryClient.invalidateQueries({ queryKey: queryKeys.menu(menuId) });
      }
    };

    window.addEventListener('menu-updated', handleMenuUpdate as EventListener);
    window.addEventListener('price-updated', handlePriceUpdate as EventListener);

    return () => {
      window.removeEventListener('menu-updated', handleMenuUpdate as EventListener);
      window.removeEventListener('price-updated', handlePriceUpdate as EventListener);
    };
  }, [enableRealTimeUpdates, menuId, queryClient]);

  // Sync state with React Query data
  useEffect(() => {
    if (menuId) {
      const menuData = queryClient.getQueryData(queryKeys.menu(menuId)) as Menu;
      if (menuData) {
        setState(prev => ({
          ...prev,
          menu: menuData,
          isLoading: false,
        }));
      }
    }
  }, [menuId, queryClient]);

  // Cleanup auto-save timeout
  useEffect(() => {
    return () => {
      if (autoSaveTimeout) {
        clearTimeout(autoSaveTimeout);
      }
    };
  }, [autoSaveTimeout]);

  return {
    // State
    menu: state.menu,
    isLoading: state.isLoading || updateMenuMutation.isPending,
    isDirty: state.isDirty,
    lastSaved: state.lastSaved,
    pendingChanges: state.pendingChanges,
    isUpdating: updateMenuMutation.isPending,
    
    // Actions
    updateMenu,
    updateMenuItem,
    updateItemPrice,
    addMenuItem,
    removeMenuItem,
    reorderItems,
    saveChanges,
    discardChanges,
    
    // Mutation states
    updateError: updateMenuMutation.error,
    priceUpdateError: updateItemPriceMutation.error,
  };
}
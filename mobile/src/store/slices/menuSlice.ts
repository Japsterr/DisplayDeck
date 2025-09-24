import { createSlice, PayloadAction } from '@reduxjs/toolkit';

export interface MenuItem {
  id: string;
  name: string;
  description: string;
  price: number;
  category: string;
  available: boolean;
  image_url?: string;
}

export interface Menu {
  id: string;
  name: string;
  description: string;
  business_id: string;
  items: MenuItem[];
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

interface MenuState {
  menus: Menu[];
  selectedMenu: Menu | null;
  loading: boolean;
  error: string | null;
  lastSync: string | null;
  pendingChanges: string[]; // Menu IDs with pending changes
}

const initialState: MenuState = {
  menus: [],
  selectedMenu: null,
  loading: false,
  error: null,
  lastSync: null,
  pendingChanges: [],
};

const menuSlice = createSlice({
  name: 'menu',
  initialState,
  reducers: {
    setLoading: (state, action: PayloadAction<boolean>) => {
      state.loading = action.payload;
      if (action.payload) {
        state.error = null;
      }
    },
    setError: (state, action: PayloadAction<string>) => {
      state.error = action.payload;
      state.loading = false;
    },
    setMenus: (state, action: PayloadAction<Menu[]>) => {
      state.menus = action.payload;
      state.loading = false;
      state.error = null;
      state.lastSync = new Date().toISOString();
    },
    addMenu: (state, action: PayloadAction<Menu>) => {
      state.menus.push(action.payload);
    },
    updateMenu: (state, action: PayloadAction<Menu>) => {
      const index = state.menus.findIndex(m => m.id === action.payload.id);
      if (index !== -1) {
        state.menus[index] = action.payload;
        // Mark as having pending changes
        if (!state.pendingChanges.includes(action.payload.id)) {
          state.pendingChanges.push(action.payload.id);
        }
      }
    },
    deleteMenu: (state, action: PayloadAction<string>) => {
      state.menus = state.menus.filter(m => m.id !== action.payload);
      state.pendingChanges = state.pendingChanges.filter(id => id !== action.payload);
    },
    selectMenu: (state, action: PayloadAction<Menu>) => {
      state.selectedMenu = action.payload;
    },
    clearSelection: (state) => {
      state.selectedMenu = null;
    },
    updateMenuItem: (state, action: PayloadAction<{
      menuId: string;
      item: MenuItem;
    }>) => {
      const menu = state.menus.find(m => m.id === action.payload.menuId);
      if (menu) {
        const itemIndex = menu.items.findIndex(i => i.id === action.payload.item.id);
        if (itemIndex !== -1) {
          menu.items[itemIndex] = action.payload.item;
        } else {
          menu.items.push(action.payload.item);
        }
        // Mark menu as having pending changes
        if (!state.pendingChanges.includes(action.payload.menuId)) {
          state.pendingChanges.push(action.payload.menuId);
        }
      }
    },
    deleteMenuItem: (state, action: PayloadAction<{
      menuId: string;
      itemId: string;
    }>) => {
      const menu = state.menus.find(m => m.id === action.payload.menuId);
      if (menu) {
        menu.items = menu.items.filter(i => i.id !== action.payload.itemId);
        // Mark menu as having pending changes
        if (!state.pendingChanges.includes(action.payload.menuId)) {
          state.pendingChanges.push(action.payload.menuId);
        }
      }
    },
    markSynced: (state, action: PayloadAction<string>) => {
      state.pendingChanges = state.pendingChanges.filter(id => id !== action.payload);
    },
    clearPendingChanges: (state) => {
      state.pendingChanges = [];
    },
  },
});

export const {
  setLoading,
  setError,
  setMenus,
  addMenu,
  updateMenu,
  deleteMenu,
  selectMenu,
  clearSelection,
  updateMenuItem,
  deleteMenuItem,
  markSynced,
  clearPendingChanges,
} = menuSlice.actions;

export default menuSlice.reducer;
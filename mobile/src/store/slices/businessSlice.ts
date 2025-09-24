import { createSlice, PayloadAction } from '@reduxjs/toolkit';

export interface Business {
  id: string;
  name: string;
  description: string;
  address: string;
  phone: string;
  email: string;
  timezone: string;
  is_active: boolean;
  created_at: string;
}

interface BusinessState {
  businesses: Business[];
  selectedBusiness: Business | null;
  loading: boolean;
  error: string | null;
}

const initialState: BusinessState = {
  businesses: [],
  selectedBusiness: null,
  loading: false,
  error: null,
};

const businessSlice = createSlice({
  name: 'business',
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
    setBusinesses: (state, action: PayloadAction<Business[]>) => {
      state.businesses = action.payload;
      state.loading = false;
      state.error = null;
    },
    addBusiness: (state, action: PayloadAction<Business>) => {
      state.businesses.push(action.payload);
    },
    updateBusiness: (state, action: PayloadAction<Business>) => {
      const index = state.businesses.findIndex(b => b.id === action.payload.id);
      if (index !== -1) {
        state.businesses[index] = action.payload;
      }
    },
    deleteBusiness: (state, action: PayloadAction<string>) => {
      state.businesses = state.businesses.filter(b => b.id !== action.payload);
    },
    selectBusiness: (state, action: PayloadAction<Business>) => {
      state.selectedBusiness = action.payload;
    },
    clearSelection: (state) => {
      state.selectedBusiness = null;
    },
  },
});

export const {
  setLoading,
  setError,
  setBusinesses,
  addBusiness,
  updateBusiness,
  deleteBusiness,
  selectBusiness,
  clearSelection,
} = businessSlice.actions;

export default businessSlice.reducer;
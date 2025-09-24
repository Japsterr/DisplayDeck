import React, { createContext, useContext, useEffect, useReducer, useCallback } from 'react';
import { apiService, type User, type LoginRequest, type RegisterRequest } from '@/services/api';
import { useNavigate } from 'react-router-dom';
import { toast } from '@/lib/toast';

interface AuthState {
  user: User | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  error: string | null;
}

type AuthAction =
  | { type: 'AUTH_START' }
  | { type: 'AUTH_SUCCESS'; payload: User }
  | { type: 'AUTH_ERROR'; payload: string }
  | { type: 'AUTH_LOGOUT' }
  | { type: 'CLEAR_ERROR' };

const initialState: AuthState = {
  user: null,
  isAuthenticated: false,
  isLoading: true,
  error: null,
};

function authReducer(state: AuthState, action: AuthAction): AuthState {
  switch (action.type) {
    case 'AUTH_START':
      return { ...state, isLoading: true, error: null };
    case 'AUTH_SUCCESS':
      return {
        ...state,
        user: action.payload,
        isAuthenticated: true,
        isLoading: false,
        error: null,
      };
    case 'AUTH_ERROR':
      return {
        ...state,
        user: null,
        isAuthenticated: false,
        isLoading: false,
        error: action.payload,
      };
    case 'AUTH_LOGOUT':
      return {
        ...state,
        user: null,
        isAuthenticated: false,
        isLoading: false,
        error: null,
      };
    case 'CLEAR_ERROR':
      return { ...state, error: null };
    default:
      return state;
  }
}

interface AuthContextType extends AuthState {
  login: (credentials: LoginRequest) => Promise<void>;
  register: (userData: RegisterRequest) => Promise<void>;
  logout: () => Promise<void>;
  clearError: () => void;
  checkAuth: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [state, dispatch] = useReducer(authReducer, initialState);
  const navigate = useNavigate();

  const checkAuth = useCallback(async () => {
    if (!apiService.isAuthenticated()) {
      dispatch({ type: 'AUTH_LOGOUT' });
      return;
    }

    dispatch({ type: 'AUTH_START' });
    try {
      const user = await apiService.getCurrentUser();
      dispatch({ type: 'AUTH_SUCCESS', payload: user });
    } catch (error) {
      // Try to refresh token first
      try {
        await apiService.refreshToken();
        const user = await apiService.getCurrentUser();
        dispatch({ type: 'AUTH_SUCCESS', payload: user });
      } catch (refreshError) {
        apiService.clearTokens();
        dispatch({ type: 'AUTH_LOGOUT' });
      }
    }
  }, []);

  const login = useCallback(async (credentials: LoginRequest) => {
    dispatch({ type: 'AUTH_START' });
    try {
      const response = await apiService.login(credentials);
      dispatch({ type: 'AUTH_SUCCESS', payload: response.user });
      toast({
        title: 'Success',
        description: 'You have been logged in successfully.',
      });
      navigate('/dashboard');
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Login failed';
      dispatch({ type: 'AUTH_ERROR', payload: message });
      toast({
        title: 'Error',
        description: message,
        variant: 'destructive',
      });
      throw error;
    }
  }, [navigate]);

  const register = useCallback(async (userData: RegisterRequest) => {
    dispatch({ type: 'AUTH_START' });
    try {
      await apiService.register(userData);
      toast({
        title: 'Success',
        description: 'Account created successfully! Please check your email to verify your account.',
      });
      navigate('/login');
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Registration failed';
      dispatch({ type: 'AUTH_ERROR', payload: message });
      toast({
        title: 'Error',
        description: message,
        variant: 'destructive',
      });
      throw error;
    }
  }, [navigate]);

  const logout = useCallback(async () => {
    try {
      await apiService.logout();
    } catch (error) {
      console.warn('Logout API call failed:', error);
    }
    dispatch({ type: 'AUTH_LOGOUT' });
    toast({
      title: 'Success',
      description: 'You have been logged out.',
    });
    navigate('/login');
  }, [navigate]);

  const clearError = useCallback(() => {
    dispatch({ type: 'CLEAR_ERROR' });
  }, []);

  // Check authentication status on mount
  useEffect(() => {
    checkAuth();
  }, [checkAuth]);

  const value: AuthContextType = {
    ...state,
    login,
    register,
    logout,
    clearError,
    checkAuth,
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}
// API service for DisplayDeck
const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:8000/api/v1';

export interface User {
  id: string;
  email: string;
  first_name: string;
  last_name: string;
  is_active: boolean;
  date_joined: string;
}

export interface LoginRequest {
  email: string;
  password: string;
}

export interface LoginResponse {
  access: string;
  refresh: string;
  user: User;
}

export interface RegisterRequest {
  email: string;
  password: string;
  password_confirm: string;
  first_name: string;
  last_name: string;
}

export interface PasswordResetRequest {
  email: string;
}

export interface PasswordResetConfirmRequest {
  token: string;
  new_password: string;
  new_password_confirm: string;
}

export interface Business {
  id: string;
  name: string;
  business_type: string;
  description: string;
  email: string;
  phone_number: string;
  address_line_1: string;
  address_line_2?: string;
  city: string;
  state_province: string;
  postal_code: string;
  country: string;
  created_at: string;
  updated_at: string;
}

export interface BusinessCreateRequest {
  name: string;
  business_type: string;
  description: string;
  email: string;
  phone_number: string;
  address_line_1: string;
  address_line_2?: string;
  city: string;
  state_province: string;
  postal_code: string;
  country: string;
}

export interface Menu {
  id: string;
  business: string;
  name: string;
  description: string;
  is_active: boolean;
  version: number;
  published_version?: number;
  categories: MenuCategory[];
  created_at: string;
  updated_at: string;
}

export interface MenuCategory {
  id: string;
  menu: string;
  name: string;
  description: string;
  display_order: number;
  is_active: boolean;
  items: MenuItem[];
  created_at: string;
  updated_at: string;
}

export interface MenuItem {
  id: string;
  category: string;
  name: string;
  description: string;
  price: string;
  is_available: boolean;
  display_order: number;
  image?: string;
  allergens?: string[];
  dietary_info?: string[];
  preparation_time?: number;
  created_at: string;
  updated_at: string;
}

export interface MenuCreateRequest {
  business: string;
  name: string;
  description: string;
  categories?: MenuCategoryCreateRequest[];
}

export interface MenuCategoryCreateRequest {
  name: string;
  description: string;
  display_order: number;
  items?: MenuItemCreateRequest[];
}

export interface MenuItemCreateRequest {
  name: string;
  description: string;
  price: string;
  display_order: number;
  allergens?: string[];
  dietary_info?: string[];
  preparation_time?: number;
}

export interface Display {
  id: string;
  business: string;
  name: string;
  location: string;
  device_type: string;
  orientation: 'landscape' | 'portrait';
  resolution: string;
  is_active: boolean;
  last_heartbeat?: string;
  pairing_code?: string;
  is_paired: boolean;
  assigned_menu?: string;
  created_at: string;
  updated_at: string;
}

export interface DisplayCreateRequest {
  business: string;
  name: string;
  location: string;
  device_type: string;
  orientation: 'landscape' | 'portrait';
  resolution: string;
}

export interface DisplayPairRequest {
  pairing_code: string;
  device_info: {
    device_type: string;
    resolution: string;
    user_agent: string;
  };
}

class ApiService {
  private getAuthHeaders() {
    const token = localStorage.getItem('access_token');
    return {
      'Content-Type': 'application/json',
      ...(token && { Authorization: `Bearer ${token}` }),
    };
  }

  private async request<T>(
    endpoint: string,
    options: RequestInit = {}
  ): Promise<T> {
    const url = `${API_BASE_URL}${endpoint}`;
    
    const response = await fetch(url, {
      ...options,
      headers: {
        ...this.getAuthHeaders(),
        ...options.headers,
      },
    });

    if (!response.ok) {
      let errorMessage = 'An error occurred';
      try {
        const errorData = await response.json();
        errorMessage = errorData.detail || errorData.error || JSON.stringify(errorData);
      } catch {
        errorMessage = response.statusText;
      }
      throw new Error(errorMessage);
    }

    return response.json();
  }

  // Authentication methods
  async login(credentials: LoginRequest): Promise<LoginResponse> {
    const response = await this.request<LoginResponse>('/auth/login/', {
      method: 'POST',
      body: JSON.stringify(credentials),
    });

    // Store tokens
    localStorage.setItem('access_token', response.access);
    localStorage.setItem('refresh_token', response.refresh);

    return response;
  }

  async register(userData: RegisterRequest): Promise<{ message: string }> {
    return this.request('/auth/register/', {
      method: 'POST',
      body: JSON.stringify(userData),
    });
  }

  async requestPasswordReset(data: PasswordResetRequest): Promise<{ message: string }> {
    return this.request('/auth/password-reset-request/', {
      method: 'POST',
      body: JSON.stringify(data),
    });
  }

  async confirmPasswordReset(data: PasswordResetConfirmRequest): Promise<{ message: string }> {
    return this.request('/auth/password-reset-confirm/', {
      method: 'POST',
      body: JSON.stringify(data),
    });
  }

  async refreshToken(): Promise<{ access: string }> {
    const refresh = localStorage.getItem('refresh_token');
    if (!refresh) {
      throw new Error('No refresh token available');
    }

    const response = await this.request<{ access: string }>('/auth/refresh/', {
      method: 'POST',
      body: JSON.stringify({ refresh }),
    });

    localStorage.setItem('access_token', response.access);
    return response;
  }

  async logout(): Promise<void> {
    const refresh = localStorage.getItem('refresh_token');
    if (refresh) {
      try {
        await this.request('/auth/logout/', {
          method: 'POST',
          body: JSON.stringify({ refresh }),
        });
      } catch (error) {
        console.warn('Logout request failed:', error);
      }
    }

    // Clear tokens regardless of API call success
    localStorage.removeItem('access_token');
    localStorage.removeItem('refresh_token');
  }

  async getCurrentUser(): Promise<User> {
    return this.request<User>('/auth/me/');
  }

  // Token utility methods
  isAuthenticated(): boolean {
    return !!localStorage.getItem('access_token');
  }

  clearTokens(): void {
    localStorage.removeItem('access_token');
    localStorage.removeItem('refresh_token');
  }

  // Business methods
  async getBusinesses(): Promise<Business[]> {
    return this.request<Business[]>('/businesses/');
  }

  async getBusiness(id: string): Promise<Business> {
    return this.request<Business>(`/businesses/${id}/`);
  }

  async createBusiness(data: BusinessCreateRequest): Promise<Business> {
    return this.request<Business>('/businesses/', {
      method: 'POST',
      body: JSON.stringify(data),
    });
  }

  async updateBusiness(id: string, data: Partial<BusinessCreateRequest>): Promise<Business> {
    return this.request<Business>(`/businesses/${id}/`, {
      method: 'PUT',
      body: JSON.stringify(data),
    });
  }

  async deleteBusiness(id: string): Promise<void> {
    await this.request(`/businesses/${id}/`, {
      method: 'DELETE',
    });
  }

  // Menu methods
  async getBusinessMenus(businessId: string): Promise<Menu[]> {
    return this.request<Menu[]>(`/businesses/${businessId}/menus/`);
  }

  async getMenu(id: string): Promise<Menu> {
    return this.request<Menu>(`/menus/${id}/`);
  }

  async createMenu(data: MenuCreateRequest): Promise<Menu> {
    return this.request<Menu>(`/businesses/${data.business}/menus/`, {
      method: 'POST',
      body: JSON.stringify(data),
    });
  }

  async updateMenu(id: string, data: Partial<MenuCreateRequest>): Promise<Menu> {
    return this.request<Menu>(`/menus/${id}/`, {
      method: 'PUT',
      body: JSON.stringify(data),
    });
  }

  async deleteMenu(id: string): Promise<void> {
    await this.request(`/menus/${id}/`, {
      method: 'DELETE',
    });
  }

  async publishMenu(id: string): Promise<Menu> {
    return this.request<Menu>(`/menus/${id}/publish/`, {
      method: 'POST',
    });
  }

  // Menu Category methods
  async createMenuCategory(menuId: string, data: MenuCategoryCreateRequest): Promise<MenuCategory> {
    return this.request<MenuCategory>(`/menus/${menuId}/categories/`, {
      method: 'POST',
      body: JSON.stringify(data),
    });
  }

  async updateMenuCategory(id: string, data: Partial<MenuCategoryCreateRequest>): Promise<MenuCategory> {
    return this.request<MenuCategory>(`/menu-categories/${id}/`, {
      method: 'PUT',
      body: JSON.stringify(data),
    });
  }

  async deleteMenuCategory(id: string): Promise<void> {
    await this.request(`/menu-categories/${id}/`, {
      method: 'DELETE',
    });
  }

  // Menu Item methods
  async createMenuItem(categoryId: string, data: MenuItemCreateRequest): Promise<MenuItem> {
    return this.request<MenuItem>(`/menu-categories/${categoryId}/items/`, {
      method: 'POST',
      body: JSON.stringify(data),
    });
  }

  async updateMenuItem(id: string, data: Partial<MenuItemCreateRequest>): Promise<MenuItem> {
    return this.request<MenuItem>(`/menu-items/${id}/`, {
      method: 'PUT',
      body: JSON.stringify(data),
    });
  }

  async deleteMenuItem(id: string): Promise<void> {
    await this.request(`/menu-items/${id}/`, {
      method: 'DELETE',
    });
  }

  async updateMenuItemPrice(id: string, price: string): Promise<MenuItem> {
    return this.request<MenuItem>(`/menu-items/${id}/price/`, {
      method: 'PATCH',
      body: JSON.stringify({ price }),
    });
  }

  // Display methods
  async getBusinessDisplays(businessId: string): Promise<Display[]> {
    return this.request<Display[]>(`/businesses/${businessId}/displays/`);
  }

  async getDisplay(id: string): Promise<Display> {
    return this.request<Display>(`/displays/${id}/`);
  }

  async createDisplay(data: DisplayCreateRequest): Promise<Display> {
    return this.request<Display>(`/businesses/${data.business}/displays/`, {
      method: 'POST',
      body: JSON.stringify(data),
    });
  }

  async updateDisplay(id: string, data: Partial<DisplayCreateRequest>): Promise<Display> {
    return this.request<Display>(`/displays/${id}/`, {
      method: 'PUT',
      body: JSON.stringify(data),
    });
  }

  async deleteDisplay(id: string): Promise<void> {
    await this.request(`/displays/${id}/`, {
      method: 'DELETE',
    });
  }

  async pairDisplay(data: DisplayPairRequest): Promise<Display> {
    return this.request<Display>('/displays/pair/', {
      method: 'POST',
      body: JSON.stringify(data),
    });
  }

  async generatePairingCode(businessId: string): Promise<{ pairing_code: string; expires_at: string }> {
    return this.request('/displays/generate-pairing-code/', {
      method: 'POST',
      body: JSON.stringify({ business: businessId }),
    });
  }

  async assignMenuToDisplay(displayId: string, menuId: string): Promise<Display> {
    return this.request<Display>(`/displays/${displayId}/menu/`, {
      method: 'PUT',
      body: JSON.stringify({ menu: menuId }),
    });
  }

  async getDisplayStatus(id: string): Promise<{
    is_online: boolean;
    last_heartbeat: string;
    current_menu?: string;
    device_info: any;
  }> {
    return this.request(`/displays/${id}/status/`);
  }
}

export const apiService = new ApiService();
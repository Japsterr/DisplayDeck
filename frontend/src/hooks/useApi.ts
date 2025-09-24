import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { apiService } from '@/services/api';
import { toast } from '@/lib/toast';
import { useAuth } from '@/contexts/AuthContext';

// Query Keys
export const queryKeys = {
  businesses: ['businesses'] as const,
  business: (id: string) => ['business', id] as const,
  businessMenus: (businessId: string) => ['business-menus', businessId] as const,
  businessDisplays: (businessId: string) => ['business-displays', businessId] as const,
  menus: ['menus'] as const,
  menu: (id: string) => ['menu', id] as const,
  displays: ['displays'] as const,
  display: (id: string) => ['display', id] as const,
  media: (businessId: string) => ['media', businessId] as const,
  currentUser: ['current-user'] as const,
};

// Authentication Hooks
export function useCurrentUser() {
  const { user } = useAuth();
  
  return useQuery({
    queryKey: queryKeys.currentUser,
    queryFn: () => apiService.getCurrentUser(),
    enabled: !!user,
    staleTime: 5 * 60 * 1000, // 5 minutes
  });
}

// Business Hooks
export function useBusinesses() {
  return useQuery({
    queryKey: queryKeys.businesses,
    queryFn: () => apiService.getBusinesses(),
    staleTime: 2 * 60 * 1000, // 2 minutes
  });
}

export function useBusiness(id: string) {
  return useQuery({
    queryKey: queryKeys.business(id),
    queryFn: () => apiService.getBusiness(id),
    enabled: !!id,
    staleTime: 2 * 60 * 1000,
  });
}

export function useCreateBusiness() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: apiService.createBusiness,
    onSuccess: (data) => {
      queryClient.invalidateQueries({ queryKey: queryKeys.businesses });
      toast({
        title: 'Success',
        description: `Business "${data.name}" created successfully!`,
      });
    },
    onError: (error) => {
      toast({
        title: 'Error',
        description: error instanceof Error ? error.message : 'Failed to create business',
        variant: 'destructive',
      });
    },
  });
}

export function useUpdateBusiness() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ id, data }: { id: string; data: any }) => apiService.updateBusiness(id, data),
    onSuccess: (data, variables) => {
      queryClient.invalidateQueries({ queryKey: queryKeys.businesses });
      queryClient.invalidateQueries({ queryKey: queryKeys.business(variables.id) });
      toast({
        title: 'Success',
        description: `Business "${data.name}" updated successfully!`,
      });
    },
    onError: (error) => {
      toast({
        title: 'Error',
        description: error instanceof Error ? error.message : 'Failed to update business',
        variant: 'destructive',
      });
    },
  });
}

export function useDeleteBusiness() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (id: string) => apiService.deleteBusiness(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.businesses });
      toast({
        title: 'Success',
        description: 'Business deleted successfully!',
      });
    },
    onError: (error) => {
      toast({
        title: 'Error',
        description: error instanceof Error ? error.message : 'Failed to delete business',
        variant: 'destructive',
      });
    },
  });
}

// Menu Hooks
export function useBusinessMenus(businessId: string) {
  return useQuery({
    queryKey: queryKeys.businessMenus(businessId),
    queryFn: () => apiService.getBusinessMenus(businessId),
    enabled: !!businessId,
    staleTime: 1 * 60 * 1000, // 1 minute
  });
}

export function useMenu(id: string) {
  return useQuery({
    queryKey: queryKeys.menu(id),
    queryFn: () => apiService.getMenu(id),
    enabled: !!id,
    staleTime: 1 * 60 * 1000,
  });
}

export function useCreateMenu() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ businessId, data }: { businessId: string; data: any }) => 
      apiService.createMenu({ business: businessId, ...data }),
    onSuccess: (data, variables) => {
      queryClient.invalidateQueries({ queryKey: queryKeys.businessMenus(variables.businessId) });
      toast({
        title: 'Success',
        description: `Menu "${data.name}" created successfully!`,
      });
    },
    onError: (error) => {
      toast({
        title: 'Error',
        description: error instanceof Error ? error.message : 'Failed to create menu',
        variant: 'destructive',
      });
    },
  });
}

export function useUpdateMenu() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ id, data }: { id: string; data: any }) => apiService.updateMenu(id, data),
    onSuccess: (data, variables) => {
      queryClient.invalidateQueries({ queryKey: queryKeys.menu(variables.id) });
      // Also invalidate business menus if we have the business ID
      queryClient.invalidateQueries({ queryKey: queryKeys.businesses });
      toast({
        title: 'Success',
        description: `Menu "${data.name}" updated successfully!`,
      });
    },
    onError: (error) => {
      toast({
        title: 'Error',
        description: error instanceof Error ? error.message : 'Failed to update menu',
        variant: 'destructive',
      });
    },
  });
}

export function useDeleteMenu() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (id: string) => apiService.deleteMenu(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.businesses });
      toast({
        title: 'Success',
        description: 'Menu deleted successfully!',
      });
    },
    onError: (error) => {
      toast({
        title: 'Error',
        description: error instanceof Error ? error.message : 'Failed to delete menu',
        variant: 'destructive',
      });
    },
  });
}

// Display Hooks
export function useBusinessDisplays(businessId: string) {
  return useQuery({
    queryKey: queryKeys.businessDisplays(businessId),
    queryFn: () => apiService.getBusinessDisplays(businessId),
    enabled: !!businessId,
    staleTime: 30 * 1000, // 30 seconds for display data
    refetchInterval: 60 * 1000, // Auto-refresh every minute
  });
}

export function useDisplay(id: string) {
  return useQuery({
    queryKey: queryKeys.display(id),
    queryFn: () => apiService.getDisplay(id),
    enabled: !!id,
    staleTime: 30 * 1000,
    refetchInterval: 30 * 1000, // More frequent updates for individual displays
  });
}

export function useCreateDisplay() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ businessId, data }: { businessId: string; data: any }) =>
      apiService.createDisplay({ business: businessId, ...data }),
    onSuccess: (data, variables) => {
      queryClient.invalidateQueries({ queryKey: queryKeys.businessDisplays(variables.businessId) });
      toast({
        title: 'Success',
        description: `Display "${data.name}" created successfully!`,
      });
    },
    onError: (error) => {
      toast({
        title: 'Error',
        description: error instanceof Error ? error.message : 'Failed to create display',
        variant: 'destructive',
      });
    },
  });
}

export function useUpdateDisplay() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ id, data }: { id: string; data: any }) => apiService.updateDisplay(id, data),
    onSuccess: (data, variables) => {
      queryClient.invalidateQueries({ queryKey: queryKeys.display(variables.id) });
      queryClient.invalidateQueries({ queryKey: queryKeys.businesses });
      toast({
        title: 'Success',
        description: `Display "${data.name}" updated successfully!`,
      });
    },
    onError: (error) => {
      toast({
        title: 'Error',
        description: error instanceof Error ? error.message : 'Failed to update display',
        variant: 'destructive',
      });
    },
  });
}

export function useDeleteDisplay() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (id: string) => apiService.deleteDisplay(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.businesses });
      toast({
        title: 'Success',
        description: 'Display deleted successfully!',
      });
    },
    onError: (error) => {
      toast({
        title: 'Error',
        description: error instanceof Error ? error.message : 'Failed to delete display',
        variant: 'destructive',
      });
    },
  });
}

export function usePairDisplay() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: apiService.pairDisplay,
    onSuccess: (data) => {
      queryClient.invalidateQueries({ queryKey: queryKeys.businesses });
      toast({
        title: 'Success',
        description: `Display "${data.name}" paired successfully!`,
      });
    },
    onError: (error) => {
      toast({
        title: 'Pairing Failed',
        description: error instanceof Error ? error.message : 'Failed to pair display',
        variant: 'destructive',
      });
    },
  });
}

// Media Hooks
export function useMedia(businessId: string) {
  return useQuery({
    queryKey: queryKeys.media(businessId),
    queryFn: () => {
      // Mock implementation - replace with actual API call when available
      return Promise.resolve([]);
    },
    enabled: !!businessId,
    staleTime: 5 * 60 * 1000,
  });
}

export function useUploadMedia() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({ businessId, files }: { businessId: string; files: File[] }) => {
      // Mock implementation - replace with actual API call when available
      return Promise.resolve(files.map(file => ({
        id: Math.random().toString(36).substring(7),
        name: file.name,
        url: URL.createObjectURL(file),
        file_type: file.type,
        file_size: file.size,
        uploaded_at: new Date().toISOString(),
      })));
    },
    onSuccess: (data, variables) => {
      queryClient.invalidateQueries({ queryKey: queryKeys.media(variables.businessId) });
      toast({
        title: 'Success',
        description: `${data.length} file(s) uploaded successfully!`,
      });
    },
    onError: (error) => {
      toast({
        title: 'Upload Failed',
        description: error instanceof Error ? error.message : 'Failed to upload files',
        variant: 'destructive',
      });
    },
  });
}
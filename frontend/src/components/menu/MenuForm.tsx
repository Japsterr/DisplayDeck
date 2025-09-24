import { useState } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { apiService, type Menu, type MenuCreateRequest } from '@/services/api';
import { toast } from '@/lib/toast';
import { X } from 'lucide-react';

interface MenuFormData {
  business: string;
  name: string;
  description: string;
}

interface MenuFormProps {
  businessId: string;
  menu?: Menu;
  onSuccess?: () => void;
  onCancel?: () => void;
}

export function MenuForm({ businessId, menu, onSuccess, onCancel }: MenuFormProps) {
  const queryClient = useQueryClient();
  const isEditing = !!menu;

  const [formData, setFormData] = useState<MenuFormData>({
    business: businessId,
    name: menu?.name || '',
    description: menu?.description || '',
  });

  const [errors, setErrors] = useState<Record<string, string>>({});

  const createMenuMutation = useMutation({
    mutationFn: (data: MenuCreateRequest) => apiService.createMenu(data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['business-menus', businessId] });
      queryClient.invalidateQueries({ queryKey: ['menus'] });
      toast({
        title: 'Success',
        description: 'Menu created successfully!',
      });
      onSuccess?.();
    },
    onError: (error) => {
      toast({
        title: 'Error',
        description: error instanceof Error ? error.message : 'Failed to create menu',
        variant: 'destructive',
      });
    },
  });

  const updateMenuMutation = useMutation({
    mutationFn: (data: Partial<MenuCreateRequest>) => apiService.updateMenu(menu!.id, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['business-menus', businessId] });
      queryClient.invalidateQueries({ queryKey: ['menu', menu!.id] });
      toast({
        title: 'Success',
        description: 'Menu updated successfully!',
      });
      onSuccess?.();
    },
    onError: (error) => {
      toast({
        title: 'Error',
        description: error instanceof Error ? error.message : 'Failed to update menu',
        variant: 'destructive',
      });
    },
  });

  const validateForm = (): boolean => {
    const newErrors: Record<string, string> = {};

    if (!formData.name.trim()) {
      newErrors.name = 'Menu name is required';
    }

    if (!formData.description.trim()) {
      newErrors.description = 'Menu description is required';
    }

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => {
    const { name, value } = e.target;
    setFormData(prev => ({ ...prev, [name]: value }));
    
    // Clear field error when user starts typing
    if (errors[name]) {
      setErrors(prev => {
        const newErrors = { ...prev };
        delete newErrors[name];
        return newErrors;
      });
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!validateForm()) {
      return;
    }

    if (isEditing) {
      updateMenuMutation.mutate(formData);
    } else {
      createMenuMutation.mutate(formData);
    }
  };

  const isLoading = createMenuMutation.isPending || updateMenuMutation.isPending;

  return (
    <Card className="w-full max-w-lg mx-auto">
      <CardHeader className="flex flex-row items-center justify-between">
        <div>
          <CardTitle>{isEditing ? 'Edit Menu' : 'Create New Menu'}</CardTitle>
          <CardDescription>
            {isEditing ? 'Update your menu information' : 'Create a new digital menu for your business'}
          </CardDescription>
        </div>
        {onCancel && (
          <Button variant="ghost" size="sm" onClick={onCancel}>
            <X className="h-4 w-4" />
          </Button>
        )}
      </CardHeader>
      <CardContent>
        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label htmlFor="name" className="block text-sm font-medium text-gray-700">
              Menu Name *
            </label>
            <Input
              id="name"
              name="name"
              value={formData.name}
              onChange={handleInputChange}
              className={errors.name ? 'border-red-500' : ''}
              placeholder="Lunch Menu, Dinner Specials, etc."
            />
            {errors.name && (
              <p className="mt-1 text-sm text-red-600">{errors.name}</p>
            )}
          </div>

          <div>
            <label htmlFor="description" className="block text-sm font-medium text-gray-700">
              Description *
            </label>
            <textarea
              id="description"
              name="description"
              value={formData.description}
              onChange={handleInputChange}
              rows={3}
              className={`w-full px-3 py-2 border rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 ${
                errors.description ? 'border-red-500' : 'border-gray-300'
              }`}
              placeholder="Brief description of this menu..."
            />
            {errors.description && (
              <p className="mt-1 text-sm text-red-600">{errors.description}</p>
            )}
          </div>

          <div className="flex justify-end space-x-3 pt-4">
            {onCancel && (
              <Button type="button" variant="outline" onClick={onCancel}>
                Cancel
              </Button>
            )}
            <Button type="submit" disabled={isLoading}>
              {isLoading ? (isEditing ? 'Updating...' : 'Creating...') : (isEditing ? 'Update Menu' : 'Create Menu')}
            </Button>
          </div>
        </form>
      </CardContent>
    </Card>
  );
}
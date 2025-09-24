import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { apiService, type Menu, type MenuCategory, type MenuItem } from '@/services/api';
import { toast } from '@/lib/toast';
import { 
  ArrowLeft, 
  Plus, 
  Edit, 
  Trash2, 
  Save, 
  Eye,
  GripVertical,
  DollarSign
} from 'lucide-react';

interface MenuBuilderProps {
  menu: Menu;
  onCancel: () => void;
  onSave: () => void;
}

interface CategoryFormData {
  name: string;
  description: string;
  display_order: number;
}

interface ItemFormData {
  name: string;
  description: string;
  price: string;
  display_order: number;
  allergens: string[];
  dietary_info: string[];
  preparation_time?: number;
}

export function MenuBuilder({ menu, onCancel, onSave }: MenuBuilderProps) {
  const queryClient = useQueryClient();
  const [showCategoryForm, setShowCategoryForm] = useState(false);
  const [showItemForm, setShowItemForm] = useState<string | null>(null); // category ID

  const { data: fullMenu, isLoading } = useQuery({
    queryKey: ['menu', menu.id],
    queryFn: () => apiService.getMenu(menu.id),
    initialData: menu,
  });

  const createCategoryMutation = useMutation({
    mutationFn: (data: CategoryFormData) => apiService.createMenuCategory(menu.id, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['menu', menu.id] });
      setShowCategoryForm(false);
      toast({
        title: 'Success',
        description: 'Category created successfully!',
      });
    },
    onError: (error) => {
      toast({
        title: 'Error',
        description: error instanceof Error ? error.message : 'Failed to create category',
        variant: 'destructive',
      });
    },
  });

  const createItemMutation = useMutation({
    mutationFn: ({ categoryId, data }: { categoryId: string; data: ItemFormData }) => 
      apiService.createMenuItem(categoryId, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['menu', menu.id] });
      setShowItemForm(null);
      toast({
        title: 'Success',
        description: 'Item created successfully!',
      });
    },
    onError: (error) => {
      toast({
        title: 'Error',
        description: error instanceof Error ? error.message : 'Failed to create item',
        variant: 'destructive',
      });
    },
  });

  const deleteCategoryMutation = useMutation({
    mutationFn: (id: string) => apiService.deleteMenuCategory(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['menu', menu.id] });
      toast({
        title: 'Success',
        description: 'Category deleted successfully!',
      });
    },
    onError: (error) => {
      toast({
        title: 'Error',
        description: error instanceof Error ? error.message : 'Failed to delete category',
        variant: 'destructive',
      });
    },
  });

  const deleteItemMutation = useMutation({
    mutationFn: (id: string) => apiService.deleteMenuItem(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['menu', menu.id] });
      toast({
        title: 'Success',
        description: 'Item deleted successfully!',
      });
    },
    onError: (error) => {
      toast({
        title: 'Error',
        description: error instanceof Error ? error.message : 'Failed to delete item',
        variant: 'destructive',
      });
    },
  });

  const handleDeleteCategory = (category: MenuCategory) => {
    if (window.confirm(`Are you sure you want to delete "${category.name}"? This will also delete all items in this category.`)) {
      deleteCategoryMutation.mutate(category.id);
    }
  };

  const handleDeleteItem = (item: MenuItem) => {
    if (window.confirm(`Are you sure you want to delete "${item.name}"?`)) {
      deleteItemMutation.mutate(item.id);
    }
  };

  if (isLoading) {
    return (
      <div className="flex items-center justify-center min-h-[400px]">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto"></div>
          <p className="mt-4 text-gray-600">Loading menu...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center space-x-4">
          <Button variant="ghost" onClick={onCancel}>
            <ArrowLeft className="h-4 w-4 mr-2" />
            Back to Menus
          </Button>
          <div>
            <h2 className="text-2xl font-bold text-gray-900">Menu Builder</h2>
            <p className="text-gray-600">{fullMenu?.name}</p>
          </div>
        </div>
        <div className="flex space-x-2">
          <Button variant="outline">
            <Eye className="h-4 w-4 mr-2" />
            Preview
          </Button>
          <Button onClick={onSave}>
            <Save className="h-4 w-4 mr-2" />
            Save Changes
          </Button>
        </div>
      </div>

      {/* Add Category Button */}
      <Card>
        <CardContent className="p-6">
          <div className="flex items-center justify-between">
            <div>
              <h3 className="text-lg font-medium">Categories</h3>
              <p className="text-sm text-gray-500">Organize your menu items into categories</p>
            </div>
            <Button onClick={() => setShowCategoryForm(true)}>
              <Plus className="h-4 w-4 mr-2" />
              Add Category
            </Button>
          </div>
        </CardContent>
      </Card>

      {/* Category Form */}
      {showCategoryForm && (
        <CategoryForm
          onSubmit={(data) => createCategoryMutation.mutate(data)}
          onCancel={() => setShowCategoryForm(false)}
          isLoading={createCategoryMutation.isPending}
          nextOrder={fullMenu?.categories?.length || 0}
        />
      )}

      {/* Categories */}
      {fullMenu?.categories?.map((category) => (
        <Card key={category.id}>
          <CardHeader>
            <div className="flex items-center justify-between">
              <div className="flex items-center space-x-3">
                <GripVertical className="h-4 w-4 text-gray-400" />
                <div>
                  <CardTitle className="text-lg">{category.name}</CardTitle>
                  <CardDescription>{category.description}</CardDescription>
                </div>
              </div>
              <div className="flex space-x-1">
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={() => setShowItemForm(category.id)}
                >
                  <Plus className="h-4 w-4" />
                </Button>
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={() => handleDeleteCategory(category)}
                  disabled={deleteCategoryMutation.isPending}
                >
                  <Trash2 className="h-4 w-4" />
                </Button>
              </div>
            </div>
          </CardHeader>
          <CardContent>
            {/* Item Form */}
            {showItemForm === category.id && (
              <div className="mb-4">
                <ItemForm
                  onSubmit={(data) => createItemMutation.mutate({ categoryId: category.id, data })}
                  onCancel={() => setShowItemForm(null)}
                  isLoading={createItemMutation.isPending}
                  nextOrder={category.items?.length || 0}
                />
              </div>
            )}

            {/* Items */}
            <div className="space-y-3">
              {category.items?.length === 0 ? (
                <div className="text-center py-8">
                  <p className="text-gray-500">No items in this category yet</p>
                  <Button
                    variant="outline"
                    size="sm"
                    className="mt-2"
                    onClick={() => setShowItemForm(category.id)}
                  >
                    <Plus className="h-4 w-4 mr-2" />
                    Add First Item
                  </Button>
                </div>
              ) : (
                category.items?.map((item) => (
                  <div
                    key={item.id}
                    className="flex items-center justify-between p-3 border rounded-lg hover:bg-gray-50"
                  >
                    <div className="flex items-center space-x-3">
                      <GripVertical className="h-4 w-4 text-gray-400" />
                      <div>
                        <div className="flex items-center space-x-2">
                          <h4 className="font-medium">{item.name}</h4>
                          <span className="text-sm font-semibold text-green-600">
                            ${item.price}
                          </span>
                        </div>
                        <p className="text-sm text-gray-600">{item.description}</p>
                        {item.allergens && item.allergens.length > 0 && (
                          <div className="mt-1">
                            <span className="text-xs text-orange-600">
                              Allergens: {item.allergens.join(', ')}
                            </span>
                          </div>
                        )}
                      </div>
                    </div>
                    <div className="flex items-center space-x-1">
                      <Button
                        variant="ghost"
                        size="sm"
                        // TODO: Implement edit item functionality
                        disabled
                      >
                        <Edit className="h-4 w-4" />
                      </Button>
                      <Button
                        variant="ghost"
                        size="sm"
                        onClick={() => handleDeleteItem(item)}
                        disabled={deleteItemMutation.isPending}
                      >
                        <Trash2 className="h-4 w-4" />
                      </Button>
                    </div>
                  </div>
                ))
              )}
            </div>
          </CardContent>
        </Card>
      ))}

      {/* Empty State */}
      {!fullMenu?.categories || fullMenu.categories.length === 0 ? (
        <Card>
          <CardContent className="text-center py-12">
            <div className="w-16 h-16 bg-gray-100 rounded-lg flex items-center justify-center mx-auto mb-4">
              <Plus className="h-8 w-8 text-gray-400" />
            </div>
            <h3 className="text-lg font-medium text-gray-900 mb-2">No categories yet</h3>
            <p className="text-gray-500 mb-6">
              Start building your menu by adding categories
            </p>
            <Button onClick={() => setShowCategoryForm(true)}>
              <Plus className="h-4 w-4 mr-2" />
              Add Your First Category
            </Button>
          </CardContent>
        </Card>
      ) : null}
    </div>
  );
}

// Category Form Component
function CategoryForm({ 
  onSubmit, 
  onCancel, 
  isLoading, 
  nextOrder 
}: { 
  onSubmit: (data: CategoryFormData) => void;
  onCancel: () => void;
  isLoading: boolean;
  nextOrder: number;
}) {
  const [formData, setFormData] = useState<CategoryFormData>({
    name: '',
    description: '',
    display_order: nextOrder,
  });

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (formData.name.trim()) {
      onSubmit(formData);
    }
  };

  return (
    <Card>
      <CardHeader>
        <CardTitle>Add New Category</CardTitle>
      </CardHeader>
      <CardContent>
        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <Input
              placeholder="Category name (e.g., Appetizers, Main Courses)"
              value={formData.name}
              onChange={(e) => setFormData(prev => ({ ...prev, name: e.target.value }))}
            />
          </div>
          <div>
            <textarea
              placeholder="Description (optional)"
              value={formData.description}
              onChange={(e) => setFormData(prev => ({ ...prev, description: e.target.value }))}
              className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              rows={2}
            />
          </div>
          <div className="flex space-x-2">
            <Button type="button" variant="outline" onClick={onCancel}>
              Cancel
            </Button>
            <Button type="submit" disabled={isLoading || !formData.name.trim()}>
              {isLoading ? 'Adding...' : 'Add Category'}
            </Button>
          </div>
        </form>
      </CardContent>
    </Card>
  );
}

// Item Form Component
function ItemForm({ 
  onSubmit, 
  onCancel, 
  isLoading, 
  nextOrder 
}: { 
  onSubmit: (data: ItemFormData) => void;
  onCancel: () => void;
  isLoading: boolean;
  nextOrder: number;
}) {
  const [formData, setFormData] = useState<ItemFormData>({
    name: '',
    description: '',
    price: '',
    display_order: nextOrder,
    allergens: [],
    dietary_info: [],
  });

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (formData.name.trim() && formData.price.trim()) {
      onSubmit(formData);
    }
  };

  return (
    <Card>
      <CardHeader>
        <CardTitle>Add New Item</CardTitle>
      </CardHeader>
      <CardContent>
        <form onSubmit={handleSubmit} className="space-y-4">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <Input
              placeholder="Item name"
              value={formData.name}
              onChange={(e) => setFormData(prev => ({ ...prev, name: e.target.value }))}
            />
            <div className="relative">
              <DollarSign className="absolute left-3 top-2.5 h-4 w-4 text-gray-400" />
              <Input
                placeholder="0.00"
                type="number"
                step="0.01"
                className="pl-8"
                value={formData.price}
                onChange={(e) => setFormData(prev => ({ ...prev, price: e.target.value }))}
              />
            </div>
          </div>
          <textarea
            placeholder="Description"
            value={formData.description}
            onChange={(e) => setFormData(prev => ({ ...prev, description: e.target.value }))}
            className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            rows={3}
          />
          <div className="flex space-x-2">
            <Button type="button" variant="outline" onClick={onCancel}>
              Cancel
            </Button>
            <Button 
              type="submit" 
              disabled={isLoading || !formData.name.trim() || !formData.price.trim()}
            >
              {isLoading ? 'Adding...' : 'Add Item'}
            </Button>
          </div>
        </form>
      </CardContent>
    </Card>
  );
}
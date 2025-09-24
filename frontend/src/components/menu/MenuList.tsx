import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { apiService, type Business, type Menu } from '@/services/api';
import { MenuForm } from './MenuForm';
import { MenuBuilder } from './MenuBuilder';
import { Plus, Menu as MenuIcon, Eye, Edit, Trash2, Play, Settings } from 'lucide-react';
import { toast } from '@/lib/toast';

interface MenuListProps {
  businesses: Business[];
}

export function MenuList({ businesses }: MenuListProps) {
  const queryClient = useQueryClient();
  const [selectedBusinessId, setSelectedBusinessId] = useState<string>(
    businesses.length > 0 ? businesses[0].id : ''
  );
  const [showCreateForm, setShowCreateForm] = useState(false);
  const [editingMenu, setEditingMenu] = useState<Menu | null>(null);
  const [buildingMenu, setBuildingMenu] = useState<Menu | null>(null);

  const { data: menus, isLoading, error } = useQuery({
    queryKey: ['business-menus', selectedBusinessId],
    queryFn: () => selectedBusinessId ? apiService.getBusinessMenus(selectedBusinessId) : Promise.resolve([]),
    enabled: !!selectedBusinessId,
  });

  const deleteMenuMutation = useMutation({
    mutationFn: (id: string) => apiService.deleteMenu(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['business-menus', selectedBusinessId] });
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

  const publishMenuMutation = useMutation({
    mutationFn: (id: string) => apiService.publishMenu(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['business-menus', selectedBusinessId] });
      toast({
        title: 'Success',
        description: 'Menu published successfully!',
      });
    },
    onError: (error) => {
      toast({
        title: 'Error',
        description: error instanceof Error ? error.message : 'Failed to publish menu',
        variant: 'destructive',
      });
    },
  });

  const handleEdit = (menu: Menu) => {
    setEditingMenu(menu);
    setShowCreateForm(false);
    setBuildingMenu(null);
  };

  const handleBuild = (menu: Menu) => {
    setBuildingMenu(menu);
    setShowCreateForm(false);
    setEditingMenu(null);
  };

  const handleDelete = async (menu: Menu) => {
    if (window.confirm(`Are you sure you want to delete "${menu.name}"? This action cannot be undone.`)) {
      deleteMenuMutation.mutate(menu.id);
    }
  };

  const handlePublish = async (menu: Menu) => {
    if (window.confirm(`Are you sure you want to publish "${menu.name}"? This will make it live for displays.`)) {
      publishMenuMutation.mutate(menu.id);
    }
  };

  const handleFormSuccess = () => {
    setShowCreateForm(false);
    setEditingMenu(null);
    setBuildingMenu(null);
  };

  const handleFormCancel = () => {
    setShowCreateForm(false);
    setEditingMenu(null);
    setBuildingMenu(null);
  };

  // If no businesses, show message to create business first
  if (businesses.length === 0) {
    return (
      <Card>
        <CardContent className="text-center py-12">
          <div className="w-16 h-16 bg-gray-100 rounded-lg flex items-center justify-center mx-auto mb-4">
            <MenuIcon className="h-8 w-8 text-gray-400" />
          </div>
          <h3 className="text-lg font-medium text-gray-900 mb-2">No businesses found</h3>
          <p className="text-gray-500 mb-6">
            You need to create a business before you can create menus
          </p>
          <Button onClick={() => window.location.href = '/businesses'}>
            Go to Businesses
          </Button>
        </CardContent>
      </Card>
    );
  }

  // Show menu builder if building a menu
  if (buildingMenu) {
    return (
      <MenuBuilder
        menu={buildingMenu}
        onCancel={handleFormCancel}
        onSave={handleFormSuccess}
      />
    );
  }

  // Show create/edit form
  if (showCreateForm || editingMenu) {
    return (
      <MenuForm
        businessId={selectedBusinessId}
        menu={editingMenu || undefined}
        onSuccess={handleFormSuccess}
        onCancel={handleFormCancel}
      />
    );
  }

  if (isLoading) {
    return (
      <div className="flex items-center justify-center min-h-[400px]">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto"></div>
          <p className="mt-4 text-gray-600">Loading menus...</p>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="flex items-center justify-center min-h-[400px]">
        <div className="text-center">
          <div className="w-12 h-12 bg-red-100 rounded-lg flex items-center justify-center mx-auto mb-4">
            <span className="text-red-600 font-bold">!</span>
          </div>
          <p className="text-red-600 mb-4">Failed to load menus</p>
          <Button onClick={() => queryClient.invalidateQueries({ queryKey: ['business-menus', selectedBusinessId] })}>
            Try Again
          </Button>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h2 className="text-2xl font-bold text-gray-900">Digital Menus</h2>
          <p className="text-gray-600">Create and manage your digital menus</p>
        </div>
        <div className="flex items-center space-x-4">
          {/* Business Selector */}
          <select
            value={selectedBusinessId}
            onChange={(e) => setSelectedBusinessId(e.target.value)}
            className="px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          >
            {businesses.map((business) => (
              <option key={business.id} value={business.id}>
                {business.name}
              </option>
            ))}
          </select>
          <Button onClick={() => setShowCreateForm(true)}>
            <Plus className="h-4 w-4 mr-2" />
            Create Menu
          </Button>
        </div>
      </div>

      {!menus || menus.length === 0 ? (
        <Card>
          <CardContent className="text-center py-12">
            <div className="w-16 h-16 bg-gray-100 rounded-lg flex items-center justify-center mx-auto mb-4">
              <MenuIcon className="h-8 w-8 text-gray-400" />
            </div>
            <h3 className="text-lg font-medium text-gray-900 mb-2">No menus yet</h3>
            <p className="text-gray-500 mb-6">
              Create your first menu to get started with your digital menu board
            </p>
            <Button onClick={() => setShowCreateForm(true)}>
              <Plus className="h-4 w-4 mr-2" />
              Create Your First Menu
            </Button>
          </CardContent>
        </Card>
      ) : (
        <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
          {menus.map((menu) => (
            <Card key={menu.id} className="hover:shadow-md transition-shadow">
              <CardHeader>
                <div className="flex items-start justify-between">
                  <div className="flex items-center space-x-3">
                    <div className="w-10 h-10 bg-green-100 rounded-lg flex items-center justify-center">
                      <MenuIcon className="h-5 w-5 text-green-600" />
                    </div>
                    <div>
                      <CardTitle className="text-lg">{menu.name}</CardTitle>
                      <CardDescription>{menu.description}</CardDescription>
                    </div>
                  </div>
                  <div className="flex space-x-1">
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={() => handleEdit(menu)}
                      title="Edit menu details"
                    >
                      <Settings className="h-4 w-4" />
                    </Button>
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={() => handleBuild(menu)}
                      title="Edit menu content"
                    >
                      <Edit className="h-4 w-4" />
                    </Button>
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={() => handleDelete(menu)}
                      disabled={deleteMenuMutation.isPending}
                      title="Delete menu"
                    >
                      <Trash2 className="h-4 w-4" />
                    </Button>
                  </div>
                </div>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="flex items-center justify-between text-sm">
                  <span className="text-gray-500">Version:</span>
                  <span className="font-medium">{menu.version}</span>
                </div>
                
                <div className="flex items-center justify-between text-sm">
                  <span className="text-gray-500">Published:</span>
                  <span className={menu.published_version ? 'text-green-600' : 'text-gray-400'}>
                    {menu.published_version ? `v${menu.published_version}` : 'Not published'}
                  </span>
                </div>

                <div className="flex items-center justify-between text-sm">
                  <span className="text-gray-500">Categories:</span>
                  <span className="font-medium">{menu.categories?.length || 0}</span>
                </div>

                <div className="flex items-center justify-between text-sm">
                  <span className="text-gray-500">Items:</span>
                  <span className="font-medium">
                    {menu.categories?.reduce((total, category) => total + (category.items?.length || 0), 0) || 0}
                  </span>
                </div>

                <div className="flex space-x-2 pt-2">
                  <Button
                    size="sm"
                    variant="outline"
                    onClick={() => handleBuild(menu)}
                    className="flex-1"
                  >
                    <Eye className="h-4 w-4 mr-1" />
                    Preview
                  </Button>
                  <Button
                    size="sm"
                    onClick={() => handlePublish(menu)}
                    disabled={publishMenuMutation.isPending}
                    className="flex-1"
                  >
                    <Play className="h-4 w-4 mr-1" />
                    Publish
                  </Button>
                </div>

                <div className="pt-3 border-t">
                  <p className="text-xs text-gray-500">
                    Updated {new Date(menu.updated_at).toLocaleDateString()}
                  </p>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}
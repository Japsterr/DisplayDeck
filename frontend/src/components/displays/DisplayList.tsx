import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { apiService, type Business, type Display } from '@/services/api';
import { DisplayForm } from './DisplayForm';
import { DisplayPairing } from './DisplayPairing';
import { 
  Plus, 
  Monitor, 
  Wifi, 
  WifiOff, 
  Edit, 
  Trash2, 
  Settings, 
  QrCode,
  MapPin,
  Clock,
  Tv
} from 'lucide-react';
import { toast } from '@/lib/toast';

interface DisplayListProps {
  businesses: Business[];
}

export function DisplayList({ businesses }: DisplayListProps) {
  const queryClient = useQueryClient();
  const [selectedBusinessId, setSelectedBusinessId] = useState<string>(
    businesses.length > 0 ? businesses[0].id : ''
  );
  const [showCreateForm, setShowCreateForm] = useState(false);
  const [showPairing, setShowPairing] = useState(false);
  const [editingDisplay, setEditingDisplay] = useState<Display | null>(null);
  const [assigningMenuTo, setAssigningMenuTo] = useState<Display | null>(null);

  const { data: displays, isLoading, error } = useQuery({
    queryKey: ['business-displays', selectedBusinessId],
    queryFn: () => selectedBusinessId ? apiService.getBusinessDisplays(selectedBusinessId) : Promise.resolve([]),
    enabled: !!selectedBusinessId,
  });

  const { data: menus } = useQuery({
    queryKey: ['business-menus', selectedBusinessId],
    queryFn: () => selectedBusinessId ? apiService.getBusinessMenus(selectedBusinessId) : Promise.resolve([]),
    enabled: !!selectedBusinessId && !!assigningMenuTo,
  });

  const deleteDisplayMutation = useMutation({
    mutationFn: (id: string) => apiService.deleteDisplay(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['business-displays', selectedBusinessId] });
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

  const assignMenuMutation = useMutation({
    mutationFn: ({ displayId, menuId }: { displayId: string; menuId: string }) =>
      apiService.assignMenuToDisplay(displayId, menuId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['business-displays', selectedBusinessId] });
      setAssigningMenuTo(null);
      toast({
        title: 'Success',
        description: 'Menu assigned to display successfully!',
      });
    },
    onError: (error) => {
      toast({
        title: 'Error',
        description: error instanceof Error ? error.message : 'Failed to assign menu',
        variant: 'destructive',
      });
    },
  });

  const handleEdit = (display: Display) => {
    setEditingDisplay(display);
    setShowCreateForm(false);
    setShowPairing(false);
  };

  const handleDelete = async (display: Display) => {
    if (window.confirm(`Are you sure you want to delete "${display.name}"? This action cannot be undone.`)) {
      deleteDisplayMutation.mutate(display.id);
    }
  };

  const handleAssignMenu = (display: Display) => {
    setAssigningMenuTo(display);
  };

  const handleMenuSelect = (menuId: string) => {
    if (assigningMenuTo) {
      assignMenuMutation.mutate({
        displayId: assigningMenuTo.id,
        menuId,
      });
    }
  };

  const handleFormSuccess = () => {
    setShowCreateForm(false);
    setEditingDisplay(null);
    setShowPairing(false);
  };

  const handleFormCancel = () => {
    setShowCreateForm(false);
    setEditingDisplay(null);
    setShowPairing(false);
    setAssigningMenuTo(null);
  };

  const getStatusColor = (display: Display) => {
    if (!display.is_paired) return 'text-gray-400';
    if (!display.last_heartbeat) return 'text-red-500';
    
    const lastHeartbeat = new Date(display.last_heartbeat);
    const now = new Date();
    const diffMinutes = (now.getTime() - lastHeartbeat.getTime()) / (1000 * 60);
    
    if (diffMinutes < 5) return 'text-green-500';
    if (diffMinutes < 30) return 'text-yellow-500';
    return 'text-red-500';
  };

  const getStatusIcon = (display: Display) => {
    if (!display.is_paired) return <WifiOff className="h-4 w-4 text-gray-400" />;
    
    const statusColor = getStatusColor(display);
    return <Wifi className={`h-4 w-4 ${statusColor}`} />;
  };

  const getStatusText = (display: Display) => {
    if (!display.is_paired) return 'Not paired';
    if (!display.last_heartbeat) return 'Offline';
    
    const lastHeartbeat = new Date(display.last_heartbeat);
    const now = new Date();
    const diffMinutes = (now.getTime() - lastHeartbeat.getTime()) / (1000 * 60);
    
    if (diffMinutes < 5) return 'Online';
    if (diffMinutes < 30) return 'Inactive';
    return 'Offline';
  };

  // If no businesses, show message to create business first
  if (businesses.length === 0) {
    return (
      <Card>
        <CardContent className="text-center py-12">
          <div className="w-16 h-16 bg-gray-100 rounded-lg flex items-center justify-center mx-auto mb-4">
            <Monitor className="h-8 w-8 text-gray-400" />
          </div>
          <h3 className="text-lg font-medium text-gray-900 mb-2">No businesses found</h3>
          <p className="text-gray-500 mb-6">
            You need to create a business before you can manage displays
          </p>
          <Button onClick={() => window.location.href = '/businesses'}>
            Go to Businesses
          </Button>
        </CardContent>
      </Card>
    );
  }

  // Show pairing interface
  if (showPairing) {
    return (
      <DisplayPairing
        businessId={selectedBusinessId}
        onSuccess={handleFormSuccess}
        onCancel={handleFormCancel}
      />
    );
  }

  // Show create/edit form
  if (showCreateForm || editingDisplay) {
    return (
      <DisplayForm
        businessId={selectedBusinessId}
        display={editingDisplay || undefined}
        onSuccess={handleFormSuccess}
        onCancel={handleFormCancel}
      />
    );
  }

  // Show menu assignment modal
  if (assigningMenuTo && menus) {
    return (
      <Card className="w-full max-w-lg mx-auto">
        <CardHeader>
          <CardTitle>Assign Menu to {assigningMenuTo.name}</CardTitle>
          <CardDescription>
            Choose which menu to display on this device
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          {menus.length === 0 ? (
            <div className="text-center py-8">
              <p className="text-gray-500">No menus available</p>
              <p className="text-sm text-gray-400 mt-2">
                Create a menu first to assign it to displays
              </p>
              <Button 
                variant="outline" 
                className="mt-4"
                onClick={() => window.location.href = '/menus'}
              >
                Go to Menus
              </Button>
            </div>
          ) : (
            <>
              <div className="space-y-2">
                {menus.map((menu) => (
                  <div
                    key={menu.id}
                    className="flex items-center justify-between p-3 border rounded-lg hover:bg-gray-50"
                  >
                    <div>
                      <h4 className="font-medium">{menu.name}</h4>
                      <p className="text-sm text-gray-600">{menu.description}</p>
                      <p className="text-xs text-gray-500">
                        {menu.categories?.length || 0} categories, Version {menu.version}
                      </p>
                    </div>
                    <Button
                      size="sm"
                      onClick={() => handleMenuSelect(menu.id)}
                      disabled={assignMenuMutation.isPending}
                    >
                      {assignMenuMutation.isPending ? 'Assigning...' : 'Assign'}
                    </Button>
                  </div>
                ))}
              </div>
              <div className="flex space-x-2">
                <Button variant="outline" onClick={handleFormCancel}>
                  Cancel
                </Button>
              </div>
            </>
          )}
        </CardContent>
      </Card>
    );
  }

  if (isLoading) {
    return (
      <div className="flex items-center justify-center min-h-[400px]">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto"></div>
          <p className="mt-4 text-gray-600">Loading displays...</p>
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
          <p className="text-red-600 mb-4">Failed to load displays</p>
          <Button onClick={() => queryClient.invalidateQueries({ queryKey: ['business-displays', selectedBusinessId] })}>
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
          <h2 className="text-2xl font-bold text-gray-900">Display Management</h2>
          <p className="text-gray-600">Manage your display devices and assignments</p>
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
          <Button variant="outline" onClick={() => setShowPairing(true)}>
            <QrCode className="h-4 w-4 mr-2" />
            Pair Display
          </Button>
          <Button onClick={() => setShowCreateForm(true)}>
            <Plus className="h-4 w-4 mr-2" />
            Add Display
          </Button>
        </div>
      </div>

      {!displays || displays.length === 0 ? (
        <Card>
          <CardContent className="text-center py-12">
            <div className="w-16 h-16 bg-gray-100 rounded-lg flex items-center justify-center mx-auto mb-4">
              <Monitor className="h-8 w-8 text-gray-400" />
            </div>
            <h3 className="text-lg font-medium text-gray-900 mb-2">No displays yet</h3>
            <p className="text-gray-500 mb-6">
              Add your first display device to start showing your menus
            </p>
            <div className="flex justify-center space-x-2">
              <Button variant="outline" onClick={() => setShowPairing(true)}>
                <QrCode className="h-4 w-4 mr-2" />
                Pair Existing Device
              </Button>
              <Button onClick={() => setShowCreateForm(true)}>
                <Plus className="h-4 w-4 mr-2" />
                Add New Display
              </Button>
            </div>
          </CardContent>
        </Card>
      ) : (
        <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
          {displays.map((display) => (
            <Card key={display.id} className="hover:shadow-md transition-shadow">
              <CardHeader>
                <div className="flex items-start justify-between">
                  <div className="flex items-center space-x-3">
                    <div className="w-10 h-10 bg-purple-100 rounded-lg flex items-center justify-center">
                      <Tv className="h-5 w-5 text-purple-600" />
                    </div>
                    <div>
                      <CardTitle className="text-lg">{display.name}</CardTitle>
                      <CardDescription className="capitalize">
                        {display.device_type}
                      </CardDescription>
                    </div>
                  </div>
                  <div className="flex space-x-1">
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={() => handleEdit(display)}
                      title="Edit display"
                    >
                      <Settings className="h-4 w-4" />
                    </Button>
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={() => handleDelete(display)}
                      disabled={deleteDisplayMutation.isPending}
                      title="Delete display"
                    >
                      <Trash2 className="h-4 w-4" />
                    </Button>
                  </div>
                </div>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="flex items-center text-sm">
                  <MapPin className="h-4 w-4 mr-2 text-gray-400" />
                  <span>{display.location}</span>
                </div>
                
                <div className="flex items-center justify-between text-sm">
                  <span className="text-gray-500">Status:</span>
                  <div className="flex items-center space-x-1">
                    {getStatusIcon(display)}
                    <span className={getStatusColor(display)}>{getStatusText(display)}</span>
                  </div>
                </div>

                <div className="flex items-center justify-between text-sm">
                  <span className="text-gray-500">Resolution:</span>
                  <span className="font-medium">{display.resolution}</span>
                </div>

                <div className="flex items-center justify-between text-sm">
                  <span className="text-gray-500">Orientation:</span>
                  <span className="font-medium capitalize">{display.orientation}</span>
                </div>

                {display.assigned_menu && (
                  <div className="flex items-center justify-between text-sm">
                    <span className="text-gray-500">Menu:</span>
                    <span className="font-medium text-green-600">Assigned</span>
                  </div>
                )}

                {display.last_heartbeat && (
                  <div className="flex items-center text-xs text-gray-500">
                    <Clock className="h-3 w-3 mr-1" />
                    Last seen: {new Date(display.last_heartbeat).toLocaleString()}
                  </div>
                )}

                <div className="flex space-x-2 pt-2">
                  <Button
                    size="sm"
                    variant="outline"
                    onClick={() => handleAssignMenu(display)}
                    className="flex-1"
                    disabled={!display.is_paired}
                  >
                    <Edit className="h-4 w-4 mr-1" />
                    {display.assigned_menu ? 'Change Menu' : 'Assign Menu'}
                  </Button>
                </div>

                <div className="pt-3 border-t">
                  <p className="text-xs text-gray-500">
                    Added {new Date(display.created_at).toLocaleDateString()}
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
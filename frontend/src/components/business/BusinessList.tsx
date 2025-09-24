import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { apiService, type Business } from '@/services/api';
import { BusinessForm } from './BusinessForm';
import { Plus, Building, MapPin, Phone, Mail, Edit, Trash2 } from 'lucide-react';
import { toast } from '@/lib/toast';
import { useMutation, useQueryClient } from '@tanstack/react-query';

export function BusinessList() {
  const queryClient = useQueryClient();
  const [showCreateForm, setShowCreateForm] = useState(false);
  const [editingBusiness, setEditingBusiness] = useState<Business | null>(null);

  const { data: businesses, isLoading, error } = useQuery({
    queryKey: ['businesses'],
    queryFn: () => apiService.getBusinesses(),
  });

  const deleteBusinessMutation = useMutation({
    mutationFn: (id: string) => apiService.deleteBusiness(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['businesses'] });
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

  const handleEdit = (business: Business) => {
    setEditingBusiness(business);
    setShowCreateForm(false);
  };

  const handleDelete = async (business: Business) => {
    if (window.confirm(`Are you sure you want to delete "${business.name}"? This action cannot be undone.`)) {
      deleteBusinessMutation.mutate(business.id);
    }
  };

  const handleFormSuccess = () => {
    setShowCreateForm(false);
    setEditingBusiness(null);
  };

  const handleFormCancel = () => {
    setShowCreateForm(false);
    setEditingBusiness(null);
  };

  if (showCreateForm || editingBusiness) {
    return (
      <BusinessForm
        business={editingBusiness || undefined}
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
          <p className="mt-4 text-gray-600">Loading businesses...</p>
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
          <p className="text-red-600 mb-4">Failed to load businesses</p>
          <Button onClick={() => queryClient.invalidateQueries({ queryKey: ['businesses'] })}>
            Try Again
          </Button>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <div>
          <h2 className="text-2xl font-bold text-gray-900">Your Businesses</h2>
          <p className="text-gray-600">Manage your business locations and settings</p>
        </div>
        <Button onClick={() => setShowCreateForm(true)}>
          <Plus className="h-4 w-4 mr-2" />
          Add Business
        </Button>
      </div>

      {!businesses || businesses.length === 0 ? (
        <Card>
          <CardContent className="text-center py-12">
            <div className="w-16 h-16 bg-gray-100 rounded-lg flex items-center justify-center mx-auto mb-4">
              <Building className="h-8 w-8 text-gray-400" />
            </div>
            <h3 className="text-lg font-medium text-gray-900 mb-2">No businesses yet</h3>
            <p className="text-gray-500 mb-6">
              Get started by creating your first business location
            </p>
            <Button onClick={() => setShowCreateForm(true)}>
              <Plus className="h-4 w-4 mr-2" />
              Create Your First Business
            </Button>
          </CardContent>
        </Card>
      ) : (
        <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
          {businesses.map((business) => (
            <Card key={business.id} className="hover:shadow-md transition-shadow">
              <CardHeader>
                <div className="flex items-start justify-between">
                  <div className="flex items-center space-x-3">
                    <div className="w-10 h-10 bg-blue-100 rounded-lg flex items-center justify-center">
                      <Building className="h-5 w-5 text-blue-600" />
                    </div>
                    <div>
                      <CardTitle className="text-lg">{business.name}</CardTitle>
                      <CardDescription className="capitalize">
                        {business.business_type.replace('_', ' ')}
                      </CardDescription>
                    </div>
                  </div>
                  <div className="flex space-x-1">
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={() => handleEdit(business)}
                    >
                      <Edit className="h-4 w-4" />
                    </Button>
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={() => handleDelete(business)}
                      disabled={deleteBusinessMutation.isPending}
                    >
                      <Trash2 className="h-4 w-4" />
                    </Button>
                  </div>
                </div>
              </CardHeader>
              <CardContent className="space-y-3">
                {business.description && (
                  <p className="text-sm text-gray-600">{business.description}</p>
                )}
                
                <div className="space-y-2 text-sm">
                  <div className="flex items-center text-gray-600">
                    <MapPin className="h-4 w-4 mr-2 flex-shrink-0" />
                    <span className="truncate">
                      {business.address_line_1}, {business.city}, {business.state_province}
                    </span>
                  </div>
                  <div className="flex items-center text-gray-600">
                    <Mail className="h-4 w-4 mr-2 flex-shrink-0" />
                    <span className="truncate">{business.email}</span>
                  </div>
                  <div className="flex items-center text-gray-600">
                    <Phone className="h-4 w-4 mr-2 flex-shrink-0" />
                    <span>{business.phone_number}</span>
                  </div>
                </div>

                <div className="pt-3 border-t">
                  <p className="text-xs text-gray-500">
                    Created {new Date(business.created_at).toLocaleDateString()}
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
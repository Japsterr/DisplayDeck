import { useState } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { apiService } from '@/services/api';
import { toast } from '@/lib/toast';
import { X } from 'lucide-react';

interface Business {
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
}

interface BusinessFormData {
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

interface BusinessFormProps {
  business?: Business;
  onSuccess?: () => void;
  onCancel?: () => void;
}

const BUSINESS_TYPES = [
  { value: 'restaurant', label: 'Restaurant' },
  { value: 'fast_food', label: 'Fast Food' },
  { value: 'cafe', label: 'Cafe' },
  { value: 'bar', label: 'Bar' },
  { value: 'hotel', label: 'Hotel' },
  { value: 'retail', label: 'Retail' },
  { value: 'other', label: 'Other' },
];

export function BusinessForm({ business, onSuccess, onCancel }: BusinessFormProps) {
  const queryClient = useQueryClient();
  const isEditing = !!business;

  const [formData, setFormData] = useState<BusinessFormData>({
    name: business?.name || '',
    business_type: business?.business_type || 'restaurant',
    description: business?.description || '',
    email: business?.email || '',
    phone_number: business?.phone_number || '',
    address_line_1: business?.address_line_1 || '',
    address_line_2: business?.address_line_2 || '',
    city: business?.city || '',
    state_province: business?.state_province || '',
    postal_code: business?.postal_code || '',
    country: business?.country || 'United States',
  });

  const [errors, setErrors] = useState<Record<string, string>>({});

  const createBusinessMutation = useMutation({
    mutationFn: (data: BusinessFormData) => apiService.createBusiness(data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['businesses'] });
      toast({
        title: 'Success',
        description: 'Business created successfully!',
      });
      onSuccess?.();
    },
    onError: (error) => {
      toast({
        title: 'Error',
        description: error instanceof Error ? error.message : 'Failed to create business',
        variant: 'destructive',
      });
    },
  });

  const updateBusinessMutation = useMutation({
    mutationFn: (data: BusinessFormData) => apiService.updateBusiness(business!.id, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['businesses'] });
      queryClient.invalidateQueries({ queryKey: ['business', business!.id] });
      toast({
        title: 'Success',
        description: 'Business updated successfully!',
      });
      onSuccess?.();
    },
    onError: (error) => {
      toast({
        title: 'Error',
        description: error instanceof Error ? error.message : 'Failed to update business',
        variant: 'destructive',
      });
    },
  });

  const validateForm = (): boolean => {
    const newErrors: Record<string, string> = {};

    if (!formData.name.trim()) {
      newErrors.name = 'Business name is required';
    }

    if (!formData.email.trim()) {
      newErrors.email = 'Email is required';
    } else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(formData.email)) {
      newErrors.email = 'Please enter a valid email address';
    }

    if (!formData.phone_number.trim()) {
      newErrors.phone_number = 'Phone number is required';
    }

    if (!formData.address_line_1.trim()) {
      newErrors.address_line_1 = 'Address is required';
    }

    if (!formData.city.trim()) {
      newErrors.city = 'City is required';
    }

    if (!formData.state_province.trim()) {
      newErrors.state_province = 'State/Province is required';
    }

    if (!formData.postal_code.trim()) {
      newErrors.postal_code = 'Postal code is required';
    }

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>) => {
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
      updateBusinessMutation.mutate(formData);
    } else {
      createBusinessMutation.mutate(formData);
    }
  };

  const isLoading = createBusinessMutation.isPending || updateBusinessMutation.isPending;

  return (
    <Card className="w-full max-w-2xl mx-auto">
      <CardHeader className="flex flex-row items-center justify-between">
        <div>
          <CardTitle>{isEditing ? 'Edit Business' : 'Create New Business'}</CardTitle>
          <CardDescription>
            {isEditing ? 'Update your business information' : 'Add a new business location to your account'}
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
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label htmlFor="name" className="block text-sm font-medium text-gray-700">
                Business Name *
              </label>
              <Input
                id="name"
                name="name"
                value={formData.name}
                onChange={handleInputChange}
                className={errors.name ? 'border-red-500' : ''}
                placeholder="My Restaurant"
              />
              {errors.name && (
                <p className="mt-1 text-sm text-red-600">{errors.name}</p>
              )}
            </div>

            <div>
              <label htmlFor="business_type" className="block text-sm font-medium text-gray-700">
                Business Type
              </label>
              <select
                id="business_type"
                name="business_type"
                value={formData.business_type}
                onChange={handleInputChange}
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              >
                {BUSINESS_TYPES.map(type => (
                  <option key={type.value} value={type.value}>
                    {type.label}
                  </option>
                ))}
              </select>
            </div>
          </div>

          <div>
            <label htmlFor="description" className="block text-sm font-medium text-gray-700">
              Description
            </label>
            <textarea
              id="description"
              name="description"
              value={formData.description}
              onChange={handleInputChange}
              rows={3}
              className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              placeholder="Brief description of your business..."
            />
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label htmlFor="email" className="block text-sm font-medium text-gray-700">
                Business Email *
              </label>
              <Input
                id="email"
                name="email"
                type="email"
                value={formData.email}
                onChange={handleInputChange}
                className={errors.email ? 'border-red-500' : ''}
                placeholder="business@example.com"
              />
              {errors.email && (
                <p className="mt-1 text-sm text-red-600">{errors.email}</p>
              )}
            </div>

            <div>
              <label htmlFor="phone_number" className="block text-sm font-medium text-gray-700">
                Phone Number *
              </label>
              <Input
                id="phone_number"
                name="phone_number"
                value={formData.phone_number}
                onChange={handleInputChange}
                className={errors.phone_number ? 'border-red-500' : ''}
                placeholder="+1 (555) 123-4567"
              />
              {errors.phone_number && (
                <p className="mt-1 text-sm text-red-600">{errors.phone_number}</p>
              )}
            </div>
          </div>

          <div>
            <label htmlFor="address_line_1" className="block text-sm font-medium text-gray-700">
              Address Line 1 *
            </label>
            <Input
              id="address_line_1"
              name="address_line_1"
              value={formData.address_line_1}
              onChange={handleInputChange}
              className={errors.address_line_1 ? 'border-red-500' : ''}
              placeholder="123 Main Street"
            />
            {errors.address_line_1 && (
              <p className="mt-1 text-sm text-red-600">{errors.address_line_1}</p>
            )}
          </div>

          <div>
            <label htmlFor="address_line_2" className="block text-sm font-medium text-gray-700">
              Address Line 2
            </label>
            <Input
              id="address_line_2"
              name="address_line_2"
              value={formData.address_line_2}
              onChange={handleInputChange}
              placeholder="Suite 100 (optional)"
            />
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div>
              <label htmlFor="city" className="block text-sm font-medium text-gray-700">
                City *
              </label>
              <Input
                id="city"
                name="city"
                value={formData.city}
                onChange={handleInputChange}
                className={errors.city ? 'border-red-500' : ''}
                placeholder="New York"
              />
              {errors.city && (
                <p className="mt-1 text-sm text-red-600">{errors.city}</p>
              )}
            </div>

            <div>
              <label htmlFor="state_province" className="block text-sm font-medium text-gray-700">
                State/Province *
              </label>
              <Input
                id="state_province"
                name="state_province"
                value={formData.state_province}
                onChange={handleInputChange}
                className={errors.state_province ? 'border-red-500' : ''}
                placeholder="NY"
              />
              {errors.state_province && (
                <p className="mt-1 text-sm text-red-600">{errors.state_province}</p>
              )}
            </div>

            <div>
              <label htmlFor="postal_code" className="block text-sm font-medium text-gray-700">
                Postal Code *
              </label>
              <Input
                id="postal_code"
                name="postal_code"
                value={formData.postal_code}
                onChange={handleInputChange}
                className={errors.postal_code ? 'border-red-500' : ''}
                placeholder="10001"
              />
              {errors.postal_code && (
                <p className="mt-1 text-sm text-red-600">{errors.postal_code}</p>
              )}
            </div>
          </div>

          <div>
            <label htmlFor="country" className="block text-sm font-medium text-gray-700">
              Country
            </label>
            <Input
              id="country"
              name="country"
              value={formData.country}
              onChange={handleInputChange}
              placeholder="United States"
            />
          </div>

          <div className="flex justify-end space-x-3 pt-4">
            {onCancel && (
              <Button type="button" variant="outline" onClick={onCancel}>
                Cancel
              </Button>
            )}
            <Button type="submit" disabled={isLoading}>
              {isLoading ? (isEditing ? 'Updating...' : 'Creating...') : (isEditing ? 'Update Business' : 'Create Business')}
            </Button>
          </div>
        </form>
      </CardContent>
    </Card>
  );
}
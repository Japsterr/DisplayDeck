import { useState } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { apiService, type Display, type DisplayCreateRequest } from '@/services/api';
import { toast } from '@/lib/toast';
import { X } from 'lucide-react';

interface DisplayFormData {
  business: string;
  name: string;
  location: string;
  device_type: string;
  orientation: 'landscape' | 'portrait';
  resolution: string;
}

interface DisplayFormProps {
  businessId: string;
  display?: Display;
  onSuccess?: () => void;
  onCancel?: () => void;
}

const DEVICE_TYPES = [
  { value: 'tablet', label: 'Tablet' },
  { value: 'tv', label: 'TV/Monitor' },
  { value: 'kiosk', label: 'Kiosk' },
  { value: 'smartphone', label: 'Smartphone' },
  { value: 'other', label: 'Other' },
];

const RESOLUTIONS = [
  { value: '1920x1080', label: '1920x1080 (Full HD)' },
  { value: '1366x768', label: '1366x768 (HD)' },
  { value: '1280x720', label: '1280x720 (HD)' },
  { value: '1024x768', label: '1024x768' },
  { value: '800x600', label: '800x600' },
  { value: 'custom', label: 'Custom' },
];

export function DisplayForm({ businessId, display, onSuccess, onCancel }: DisplayFormProps) {
  const queryClient = useQueryClient();
  const isEditing = !!display;

  const [formData, setFormData] = useState<DisplayFormData>({
    business: businessId,
    name: display?.name || '',
    location: display?.location || '',
    device_type: display?.device_type || 'tablet',
    orientation: display?.orientation || 'landscape',
    resolution: display?.resolution || '1920x1080',
  });

  const [customResolution, setCustomResolution] = useState('');
  const [errors, setErrors] = useState<Record<string, string>>({});

  const createDisplayMutation = useMutation({
    mutationFn: (data: DisplayCreateRequest) => apiService.createDisplay({
      ...data,
      business: businessId
    }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['business-displays', businessId] });
      queryClient.invalidateQueries({ queryKey: ['displays'] });
      toast({
        title: 'Success',
        description: 'Display created successfully!',
      });
      onSuccess?.();
    },
    onError: (error) => {
      toast({
        title: 'Error',
        description: error instanceof Error ? error.message : 'Failed to create display',
        variant: 'destructive',
      });
    },
  });

  const updateDisplayMutation = useMutation({
    mutationFn: (data: Partial<DisplayCreateRequest>) => apiService.updateDisplay(display!.id, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['business-displays', businessId] });
      queryClient.invalidateQueries({ queryKey: ['display', display!.id] });
      toast({
        title: 'Success',
        description: 'Display updated successfully!',
      });
      onSuccess?.();
    },
    onError: (error) => {
      toast({
        title: 'Error',
        description: error instanceof Error ? error.message : 'Failed to update display',
        variant: 'destructive',
      });
    },
  });

  const validateForm = (): boolean => {
    const newErrors: Record<string, string> = {};

    if (!formData.name.trim()) {
      newErrors.name = 'Display name is required';
    }

    if (!formData.location.trim()) {
      newErrors.location = 'Location is required';
    }

    if (formData.resolution === 'custom' && !customResolution.trim()) {
      newErrors.resolution = 'Custom resolution is required';
    }

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
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

    const submitData = {
      ...formData,
      resolution: formData.resolution === 'custom' ? customResolution : formData.resolution,
    };

    if (isEditing) {
      updateDisplayMutation.mutate(submitData);
    } else {
      createDisplayMutation.mutate(submitData);
    }
  };

  const isLoading = createDisplayMutation.isPending || updateDisplayMutation.isPending;

  return (
    <Card className="w-full max-w-lg mx-auto">
      <CardHeader className="flex flex-row items-center justify-between">
        <div>
          <CardTitle>{isEditing ? 'Edit Display' : 'Add New Display'}</CardTitle>
          <CardDescription>
            {isEditing ? 'Update your display settings' : 'Configure a new display device for your business'}
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
              Display Name *
            </label>
            <Input
              id="name"
              name="name"
              value={formData.name}
              onChange={handleInputChange}
              className={errors.name ? 'border-red-500' : ''}
              placeholder="Main Counter Display, Kitchen Board, etc."
            />
            {errors.name && (
              <p className="mt-1 text-sm text-red-600">{errors.name}</p>
            )}
          </div>

          <div>
            <label htmlFor="location" className="block text-sm font-medium text-gray-700">
              Location *
            </label>
            <Input
              id="location"
              name="location"
              value={formData.location}
              onChange={handleInputChange}
              className={errors.location ? 'border-red-500' : ''}
              placeholder="Front counter, Kitchen, Entrance, etc."
            />
            {errors.location && (
              <p className="mt-1 text-sm text-red-600">{errors.location}</p>
            )}
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label htmlFor="device_type" className="block text-sm font-medium text-gray-700">
                Device Type
              </label>
              <select
                id="device_type"
                name="device_type"
                value={formData.device_type}
                onChange={handleInputChange}
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              >
                {DEVICE_TYPES.map(type => (
                  <option key={type.value} value={type.value}>
                    {type.label}
                  </option>
                ))}
              </select>
            </div>

            <div>
              <label htmlFor="orientation" className="block text-sm font-medium text-gray-700">
                Orientation
              </label>
              <select
                id="orientation"
                name="orientation"
                value={formData.orientation}
                onChange={handleInputChange}
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              >
                <option value="landscape">Landscape</option>
                <option value="portrait">Portrait</option>
              </select>
            </div>
          </div>

          <div>
            <label htmlFor="resolution" className="block text-sm font-medium text-gray-700">
              Resolution
            </label>
            <select
              id="resolution"
              name="resolution"
              value={formData.resolution}
              onChange={handleInputChange}
              className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
              {RESOLUTIONS.map(res => (
                <option key={res.value} value={res.value}>
                  {res.label}
                </option>
              ))}
            </select>
            {formData.resolution === 'custom' && (
              <Input
                className="mt-2"
                placeholder="e.g., 1440x900"
                value={customResolution}
                onChange={(e) => setCustomResolution(e.target.value)}
              />
            )}
            {errors.resolution && (
              <p className="mt-1 text-sm text-red-600">{errors.resolution}</p>
            )}
          </div>

          <div className="flex justify-end space-x-3 pt-4">
            {onCancel && (
              <Button type="button" variant="outline" onClick={onCancel}>
                Cancel
              </Button>
            )}
            <Button type="submit" disabled={isLoading}>
              {isLoading ? (isEditing ? 'Updating...' : 'Creating...') : (isEditing ? 'Update Display' : 'Add Display')}
            </Button>
          </div>
        </form>
      </CardContent>
    </Card>
  );
}
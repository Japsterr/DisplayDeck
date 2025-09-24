import { useState } from 'react';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { MediaLibrary } from './MediaLibrary';
import { MediaUpload, type MediaFile } from './MediaUpload';
import { X, Upload, ImageIcon, Check } from 'lucide-react';

interface MediaSelectorProps {
  businessId: string;
  value?: MediaFile | null;
  onChange: (media: MediaFile | null) => void;
  onClose?: () => void;
  title?: string;
  description?: string;
  accept?: string;
}

export function MediaSelector({ 
  businessId, 
  value, 
  onChange, 
  onClose,
  title = 'Select Media',
  description = 'Choose from your media library or upload new files',
  accept = 'image/*,video/*'
}: MediaSelectorProps) {
  const [activeTab, setActiveTab] = useState<'library' | 'upload'>('library');

  const handleMediaSelect = (media: MediaFile) => {
    onChange(media);
  };

  const handleUploadSuccess = (files: MediaFile[]) => {
    if (files.length > 0) {
      onChange(files[0]); // Select the first uploaded file
    }
  };

  const handleClear = () => {
    onChange(null);
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
      <Card className="w-full max-w-6xl max-h-[90vh] overflow-hidden">
        <CardHeader className="flex flex-row items-center justify-between">
          <div>
            <CardTitle>{title}</CardTitle>
            <CardDescription>{description}</CardDescription>
          </div>
          <div className="flex items-center space-x-2">
            {value && (
              <Button
                variant="outline" 
                size="sm"
                onClick={handleClear}
              >
                Clear Selection
              </Button>
            )}
            {onClose && (
              <Button variant="ghost" size="sm" onClick={onClose}>
                <X className="h-4 w-4" />
              </Button>
            )}
          </div>
        </CardHeader>
        
        <CardContent className="p-0">
          {/* Current Selection */}
          {value && (
            <div className="p-6 border-b bg-green-50">
              <div className="flex items-center space-x-4">
                <div className="w-16 h-16 bg-white rounded-lg border-2 border-green-200 overflow-hidden">
                  {value.file_type.startsWith('image/') ? (
                    <img
                      src={value.url}
                      alt={value.name}
                      className="w-full h-full object-cover"
                    />
                  ) : (
                    <div className="w-full h-full flex items-center justify-center">
                      <ImageIcon className="h-8 w-8 text-gray-400" />
                    </div>
                  )}
                </div>
                <div className="flex-1">
                  <div className="flex items-center space-x-2">
                    <Check className="h-4 w-4 text-green-600" />
                    <span className="font-medium text-green-900">Selected:</span>
                  </div>
                  <p className="font-medium text-gray-900">{value.name}</p>
                  <p className="text-sm text-gray-600">
                    {(value.file_size / 1024 / 1024).toFixed(2)} MB
                  </p>
                </div>
                <Button
                  onClick={onClose}
                  disabled={!value}
                >
                  Use Selected
                </Button>
              </div>
            </div>
          )}

          {/* Tabs */}
          <div className="border-b border-gray-200">
            <div className="px-6">
              <nav className="-mb-px flex space-x-8">
                <button
                  onClick={() => setActiveTab('library')}
                  className={`py-4 px-1 border-b-2 font-medium text-sm ${
                    activeTab === 'library'
                      ? 'border-blue-500 text-blue-600'
                      : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                  }`}
                >
                  <ImageIcon className="h-4 w-4 inline mr-2" />
                  Media Library
                </button>
                <button
                  onClick={() => setActiveTab('upload')}
                  className={`py-4 px-1 border-b-2 font-medium text-sm ${
                    activeTab === 'upload'
                      ? 'border-blue-500 text-blue-600'
                      : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                  }`}
                >
                  <Upload className="h-4 w-4 inline mr-2" />
                  Upload New
                </button>
              </nav>
            </div>
          </div>

          {/* Tab Content */}
          <div className="overflow-y-auto max-h-[60vh]">
            {activeTab === 'library' ? (
              <div className="p-6">
                <MediaLibrary
                  businessId={businessId}
                  onSelectMedia={handleMediaSelect}
                  selectionMode
                />
              </div>
            ) : (
              <div className="p-6">
                <MediaUpload
                  businessId={businessId}
                  onSuccess={handleUploadSuccess}
                  accept={accept}
                />
              </div>
            )}
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
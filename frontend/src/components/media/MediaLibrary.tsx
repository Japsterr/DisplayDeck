import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { MediaUpload, type MediaFile } from './MediaUpload';
import { 
  Upload, 
  Search,
  Grid3X3,
  List,
  Image as ImageIcon, 
  Video,
  File,
  Trash2,
  Eye,
  Copy,
  Filter,
  FileText
} from 'lucide-react';
import { toast } from '@/lib/toast';

interface MediaLibraryProps {
  businessId: string;
  onSelectMedia?: (media: MediaFile) => void;
  selectionMode?: boolean;
}

export function MediaLibrary({ businessId, onSelectMedia, selectionMode = false }: MediaLibraryProps) {
  const queryClient = useQueryClient();
  const [showUpload, setShowUpload] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [viewMode, setViewMode] = useState<'grid' | 'list'>('grid');
  const [filterType, setFilterType] = useState<'all' | 'image' | 'video'>('all');

  // Mock media data - in real app, this would come from your API
  const mockMediaData: MediaFile[] = [
    {
      id: '1',
      name: 'restaurant-interior.jpg',
      url: '/placeholder-image.jpg',
      file_type: 'image/jpeg',
      file_size: 2048000,
      uploaded_at: '2024-01-15T10:30:00Z',
    },
    {
      id: '2',
      name: 'menu-item-burger.jpg',
      url: '/placeholder-image.jpg',
      file_type: 'image/jpeg',
      file_size: 1536000,
      uploaded_at: '2024-01-14T15:45:00Z',
    },
    {
      id: '3',
      name: 'cooking-video.mp4',
      url: '/placeholder-video.mp4',
      file_type: 'video/mp4',
      file_size: 15728640,
      uploaded_at: '2024-01-13T09:15:00Z',
    },
    {
      id: '4',
      name: 'logo.png',
      url: '/placeholder-logo.png',
      file_type: 'image/png',
      file_size: 512000,
      uploaded_at: '2024-01-12T14:20:00Z',
    },
  ];

  const { data: mediaFiles = mockMediaData, isLoading } = useQuery({
    queryKey: ['media', businessId],
    queryFn: async () => {
      // In real implementation: return apiService.getBusinessMedia(businessId);
      return mockMediaData;
    },
  });

  const deleteMediaMutation = useMutation({
    mutationFn: async (mediaId: string) => {
      // In real implementation: return apiService.deleteMedia(mediaId);
      console.log('Deleting media:', mediaId);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['media', businessId] });
      toast({
        title: 'Media Deleted',
        description: 'Media file has been successfully deleted.',
      });
    },
    onError: (error) => {
      toast({
        title: 'Delete Failed',
        description: error instanceof Error ? error.message : 'Failed to delete media file',
        variant: 'destructive',
      });
    },
  });

  const copyUrlMutation = useMutation({
    mutationFn: async (url: string) => {
      await navigator.clipboard.writeText(url);
    },
    onSuccess: () => {
      toast({
        title: 'URL Copied',
        description: 'Media URL has been copied to clipboard.',
      });
    },
  });

  const filteredMedia = mediaFiles.filter(media => {
    const matchesSearch = media.name.toLowerCase().includes(searchQuery.toLowerCase());
    const matchesFilter = 
      filterType === 'all' ||
      (filterType === 'image' && media.file_type.startsWith('image/')) ||
      (filterType === 'video' && media.file_type.startsWith('video/'));
    
    return matchesSearch && matchesFilter;
  });

  const formatFileSize = (bytes: number) => {
    if (bytes === 0) return '0 Bytes';
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
  };

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
    });
  };

  const getFileIcon = (fileType: string) => {
    if (fileType.startsWith('image/')) return <ImageIcon className="h-5 w-5" />;
    if (fileType.startsWith('video/')) return <Video className="h-5 w-5" />;
    return <File className="h-5 w-5" />;
  };

  const handleMediaClick = (media: MediaFile) => {
    if (selectionMode && onSelectMedia) {
      onSelectMedia(media);
    }
  };

  const handleUploadSuccess = () => {
    setShowUpload(false);
    // Refresh media library
    queryClient.invalidateQueries({ queryKey: ['media', businessId] });
  };

  if (showUpload) {
    return (
      <MediaUpload
        businessId={businessId}
        onSuccess={handleUploadSuccess}
        onCancel={() => setShowUpload(false)}
      />
    );
  }

  if (isLoading) {
    return (
      <div className="flex items-center justify-center min-h-[400px]">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto"></div>
          <p className="mt-4 text-gray-600">Loading media library...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h2 className="text-2xl font-bold text-gray-900">Media Library</h2>
          <p className="text-gray-600">Manage your images, videos, and other media files</p>
        </div>
        <Button onClick={() => setShowUpload(true)}>
          <Upload className="h-4 w-4 mr-2" />
          Upload Media
        </Button>
      </div>

      {/* Filters and Search */}
      <Card>
        <CardContent className="p-4">
          <div className="flex flex-col sm:flex-row sm:items-center gap-4">
            {/* Search */}
            <div className="flex-1 relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400" />
              <Input
                placeholder="Search media files..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="pl-10"
              />
            </div>

            {/* Filter */}
            <div className="flex items-center space-x-2">
              <Filter className="h-4 w-4 text-gray-400" />
              <select
                value={filterType}
                onChange={(e) => setFilterType(e.target.value as 'all' | 'image' | 'video')}
                className="px-3 py-2 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
              >
                <option value="all">All Files</option>
                <option value="image">Images</option>
                <option value="video">Videos</option>
              </select>
            </div>

            {/* View Mode */}
            <div className="flex border border-gray-300 rounded-md">
              <button
                onClick={() => setViewMode('grid')}
                className={`p-2 ${viewMode === 'grid' ? 'bg-blue-50 text-blue-600' : 'text-gray-400'}`}
              >
                <Grid3X3 className="h-4 w-4" />
              </button>
              <button
                onClick={() => setViewMode('list')}
                className={`p-2 border-l border-gray-300 ${viewMode === 'list' ? 'bg-blue-50 text-blue-600' : 'text-gray-400'}`}
              >
                <List className="h-4 w-4" />
              </button>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Media Grid/List */}
      {filteredMedia.length === 0 ? (
        <Card>
          <CardContent className="text-center py-12">
            <div className="w-16 h-16 bg-gray-100 rounded-lg flex items-center justify-center mx-auto mb-4">
              <ImageIcon className="h-8 w-8 text-gray-400" />
            </div>
            <h3 className="text-lg font-medium text-gray-900 mb-2">
              {searchQuery ? 'No media found' : 'No media files yet'}
            </h3>
            <p className="text-gray-500 mb-6">
              {searchQuery 
                ? `No media files match "${searchQuery}"` 
                : 'Upload your first media file to get started'
              }
            </p>
            {!searchQuery && (
              <Button onClick={() => setShowUpload(true)}>
                <Upload className="h-4 w-4 mr-2" />
                Upload Media
              </Button>
            )}
          </CardContent>
        </Card>
      ) : viewMode === 'grid' ? (
        <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
          {filteredMedia.map((media) => (
            <Card 
              key={media.id} 
              className={`group hover:shadow-md transition-shadow cursor-pointer ${
                selectionMode ? 'hover:bg-blue-50' : ''
              }`}
              onClick={() => handleMediaClick(media)}
            >
              <CardContent className="p-4">
                <div className="aspect-square bg-gray-100 rounded-lg mb-3 overflow-hidden">
                  {media.file_type.startsWith('image/') ? (
                    <img
                      src={media.url}
                      alt={media.name}
                      className="w-full h-full object-cover"
                      onError={(e) => {
                        // Fallback to placeholder if image fails to load
                        e.currentTarget.src = 'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMjAwIiBoZWlnaHQ9IjIwMCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48cmVjdCB3aWR0aD0iMTAwJSIgaGVpZ2h0PSIxMDAlIiBmaWxsPSIjZGRkIi8+PHRleHQgeD0iNTAlIiB5PSI1MCUiIGZvbnQtZmFtaWx5PSJBcmlhbCIgZm9udC1zaXplPSIxNiIgZmlsbD0iIzk5OSIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZHk9Ii4zZW0iPkltYWdlPC90ZXh0Pjwvc3ZnPg==';
                      }}
                    />
                  ) : media.file_type.startsWith('video/') ? (
                    <div className="w-full h-full flex items-center justify-center">
                      <Video className="h-12 w-12 text-gray-400" />
                    </div>
                  ) : (
                    <div className="w-full h-full flex items-center justify-center">
                      <File className="h-12 w-12 text-gray-400" />
                    </div>
                  )}
                </div>
                
                <div className="space-y-2">
                  <h4 className="font-medium text-gray-900 truncate text-sm">{media.name}</h4>
                  <p className="text-xs text-gray-500">
                    {formatFileSize(media.file_size)} • {formatDate(media.uploaded_at)}
                  </p>
                </div>

                {!selectionMode && (
                  <div className="flex items-center justify-between mt-3 opacity-0 group-hover:opacity-100 transition-opacity">
                    <div className="flex space-x-1">
                      <Button
                        variant="ghost"
                        size="sm"
                        onClick={(e) => {
                          e.stopPropagation();
                          window.open(media.url, '_blank');
                        }}
                        title="Preview"
                      >
                        <Eye className="h-3 w-3" />
                      </Button>
                      <Button
                        variant="ghost"
                        size="sm"
                        onClick={(e) => {
                          e.stopPropagation();
                          copyUrlMutation.mutate(media.url);
                        }}
                        title="Copy URL"
                      >
                        <Copy className="h-3 w-3" />
                      </Button>
                    </div>
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={(e) => {
                        e.stopPropagation();
                        if (confirm(`Delete ${media.name}?`)) {
                          deleteMediaMutation.mutate(media.id);
                        }
                      }}
                      title="Delete"
                    >
                      <Trash2 className="h-3 w-3" />
                    </Button>
                  </div>
                )}
              </CardContent>
            </Card>
          ))}
        </div>
      ) : (
        <Card>
          <CardContent className="p-0">
            <div className="divide-y divide-gray-200">
              {filteredMedia.map((media) => (
                <div 
                  key={media.id}
                  className={`p-4 hover:bg-gray-50 cursor-pointer ${
                    selectionMode ? 'hover:bg-blue-50' : ''
                  }`}
                  onClick={() => handleMediaClick(media)}
                >
                  <div className="flex items-center space-x-4">
                    <div className="flex-shrink-0 w-12 h-12 bg-gray-100 rounded-lg flex items-center justify-center">
                      {getFileIcon(media.file_type)}
                    </div>
                    <div className="flex-1 min-w-0">
                      <h4 className="font-medium text-gray-900 truncate">{media.name}</h4>
                      <p className="text-sm text-gray-500">
                        {formatFileSize(media.file_size)} • {formatDate(media.uploaded_at)}
                      </p>
                    </div>
                    {!selectionMode && (
                      <div className="flex items-center space-x-2">
                        <Button
                          variant="ghost"
                          size="sm"
                          onClick={(e) => {
                            e.stopPropagation();
                            window.open(media.url, '_blank');
                          }}
                        >
                          <Eye className="h-4 w-4" />
                        </Button>
                        <Button
                          variant="ghost"
                          size="sm"
                          onClick={(e) => {
                            e.stopPropagation();
                            copyUrlMutation.mutate(media.url);
                          }}
                        >
                          <Copy className="h-4 w-4" />
                        </Button>
                        <Button
                          variant="ghost"
                          size="sm"
                          onClick={(e) => {
                            e.stopPropagation();
                            if (confirm(`Delete ${media.name}?`)) {
                              deleteMediaMutation.mutate(media.id);
                            }
                          }}
                        >
                          <Trash2 className="h-4 w-4" />
                        </Button>
                      </div>
                    )}
                  </div>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
      )}

      {/* Stats */}
      <Card>
        <CardHeader>
          <CardTitle className="text-lg flex items-center">
            <FileText className="h-5 w-5 mr-2" />
            Library Stats
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="grid gap-4 md:grid-cols-3">
            <div className="text-center">
              <p className="text-2xl font-bold text-gray-900">{mediaFiles.length}</p>
              <p className="text-sm text-gray-500">Total Files</p>
            </div>
            <div className="text-center">
              <p className="text-2xl font-bold text-gray-900">
                {mediaFiles.filter(m => m.file_type.startsWith('image/')).length}
              </p>
              <p className="text-sm text-gray-500">Images</p>
            </div>
            <div className="text-center">
              <p className="text-2xl font-bold text-gray-900">
                {mediaFiles.filter(m => m.file_type.startsWith('video/')).length}
              </p>
              <p className="text-sm text-gray-500">Videos</p>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
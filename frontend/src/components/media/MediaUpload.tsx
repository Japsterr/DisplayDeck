import { useState, useRef } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { 
  Upload, 
  X, 
  Image as ImageIcon, 
  File, 
  Video,
  Loader2,
  Check,
  AlertCircle
} from 'lucide-react';
import { toast } from '@/lib/toast';

export interface MediaFile {
  id: string;
  name: string;
  url: string;
  file_type: string;
  file_size: number;
  uploaded_at: string;
}

interface MediaUploadProps {
  businessId: string;
  onSuccess?: (files: MediaFile[]) => void;
  onCancel?: () => void;
  accept?: string;
  maxFiles?: number;
  maxFileSize?: number; // in MB
}

export function MediaUpload({ 
  businessId, 
  onSuccess, 
  onCancel, 
  accept = 'image/*,video/*',
  maxFiles = 10,
  maxFileSize = 10 
}: MediaUploadProps) {
  const queryClient = useQueryClient();
  const fileInputRef = useRef<HTMLInputElement>(null);
  
  const [selectedFiles, setSelectedFiles] = useState<File[]>([]);
  const [dragOver, setDragOver] = useState(false);
  const [uploadProgress, setUploadProgress] = useState<Record<string, number>>({});

  const uploadMutation = useMutation({
    mutationFn: async (files: File[]) => {
      const uploadedFiles: MediaFile[] = [];
      
      for (const file of files) {
        const formData = new FormData();
        formData.append('file', file);
        formData.append('business', businessId);
        
        // Simulate upload progress
        setUploadProgress(prev => ({ ...prev, [file.name]: 0 }));
        
        try {
          // In a real implementation, you'd upload to your media API
          // For now, we'll simulate the upload
          const result = await simulateUpload(file, (progress) => {
            setUploadProgress(prev => ({ ...prev, [file.name]: progress }));
          });
          
          uploadedFiles.push(result);
          setUploadProgress(prev => ({ ...prev, [file.name]: 100 }));
        } catch (error) {
          console.error(`Failed to upload ${file.name}:`, error);
          throw error;
        }
      }
      
      return uploadedFiles;
    },
    onSuccess: (uploadedFiles) => {
      queryClient.invalidateQueries({ queryKey: ['media', businessId] });
      toast({
        title: 'Upload Successful',
        description: `${uploadedFiles.length} file(s) uploaded successfully!`,
      });
      onSuccess?.(uploadedFiles);
      setSelectedFiles([]);
      setUploadProgress({});
    },
    onError: (error) => {
      toast({
        title: 'Upload Failed',
        description: error instanceof Error ? error.message : 'Failed to upload files',
        variant: 'destructive',
      });
    },
  });

  // Simulate file upload with progress
  const simulateUpload = (file: File, onProgress: (progress: number) => void): Promise<MediaFile> => {
    return new Promise((resolve) => {
      let progress = 0;
      const interval = setInterval(() => {
        progress += Math.random() * 30;
        if (progress >= 100) {
          clearInterval(interval);
          onProgress(100);
          
          // Create a mock media file response
          resolve({
            id: Math.random().toString(36).substring(7),
            name: file.name,
            url: URL.createObjectURL(file),
            file_type: file.type,
            file_size: file.size,
            uploaded_at: new Date().toISOString(),
          });
        } else {
          onProgress(Math.min(progress, 95));
        }
      }, 100);
    });
  };

  const validateFiles = (files: File[]): { valid: File[]; errors: string[] } => {
    const valid: File[] = [];
    const errors: string[] = [];

    files.forEach(file => {
      // Check file size
      if (file.size > maxFileSize * 1024 * 1024) {
        errors.push(`${file.name}: File size exceeds ${maxFileSize}MB limit`);
        return;
      }

      // Check file type
      const allowedTypes = accept.split(',').map(type => type.trim());
      const isValidType = allowedTypes.some(allowedType => {
        if (allowedType === 'image/*') return file.type.startsWith('image/');
        if (allowedType === 'video/*') return file.type.startsWith('video/');
        return file.type === allowedType;
      });

      if (!isValidType) {
        errors.push(`${file.name}: File type not supported`);
        return;
      }

      valid.push(file);
    });

    // Check max files limit
    if (valid.length > maxFiles) {
      errors.push(`Maximum ${maxFiles} files allowed`);
      return { valid: valid.slice(0, maxFiles), errors };
    }

    return { valid, errors };
  };

  const handleFileSelect = (files: File[]) => {
    const { valid, errors } = validateFiles(files);
    
    if (errors.length > 0) {
      errors.forEach(error => {
        toast({
          title: 'File Validation Error',
          description: error,
          variant: 'destructive',
        });
      });
    }

    if (valid.length > 0) {
      setSelectedFiles(prev => [...prev, ...valid]);
    }
  };

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault();
    setDragOver(false);
    
    const files = Array.from(e.dataTransfer.files);
    handleFileSelect(files);
  };

  const handleFileInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files) {
      const files = Array.from(e.target.files);
      handleFileSelect(files);
    }
  };

  const removeFile = (index: number) => {
    setSelectedFiles(prev => prev.filter((_, i) => i !== index));
  };

  const getFileIcon = (file: File) => {
    if (file.type.startsWith('image/')) return <ImageIcon className="h-6 w-6" />;
    if (file.type.startsWith('video/')) return <Video className="h-6 w-6" />;
    return <File className="h-6 w-6" />;
  };

  const formatFileSize = (bytes: number) => {
    if (bytes === 0) return '0 Bytes';
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
  };

  return (
    <Card className="w-full max-w-2xl mx-auto">
      <CardHeader>
        <CardTitle>Upload Media</CardTitle>
        <CardDescription>
          Upload images, videos, or other media files for your business
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-6">
        {/* Upload Area */}
        <div
          className={`
            border-2 border-dashed rounded-lg p-8 text-center transition-colors cursor-pointer
            ${dragOver ? 'border-blue-500 bg-blue-50' : 'border-gray-300 hover:border-gray-400'}
          `}
          onDrop={handleDrop}
          onDragOver={(e) => {
            e.preventDefault();
            setDragOver(true);
          }}
          onDragLeave={() => setDragOver(false)}
          onClick={() => fileInputRef.current?.click()}
        >
          <Upload className="h-12 w-12 text-gray-400 mx-auto mb-4" />
          <h3 className="text-lg font-medium text-gray-900 mb-2">
            Drop files here or click to browse
          </h3>
          <p className="text-gray-600 mb-4">
            Supports images and videos up to {maxFileSize}MB each
          </p>
          <Button variant="outline">
            Choose Files
          </Button>
        </div>

        <input
          ref={fileInputRef}
          type="file"
          multiple
          accept={accept}
          onChange={handleFileInputChange}
          className="hidden"
        />

        {/* Selected Files */}
        {selectedFiles.length > 0 && (
          <div className="space-y-3">
            <h4 className="font-medium text-gray-900">Selected Files ({selectedFiles.length})</h4>
            <div className="space-y-2">
              {selectedFiles.map((file, index) => (
                <div key={`${file.name}-${index}`} className="flex items-center space-x-3 p-3 border border-gray-200 rounded-lg">
                  <div className="text-gray-400">
                    {getFileIcon(file)}
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-medium text-gray-900 truncate">
                      {file.name}
                    </p>
                    <p className="text-xs text-gray-500">
                      {formatFileSize(file.size)}
                    </p>
                  </div>
                  
                  {/* Upload Progress */}
                  {uploadProgress[file.name] !== undefined && (
                    <div className="flex items-center space-x-2">
                      {uploadProgress[file.name] === 100 ? (
                        <Check className="h-4 w-4 text-green-500" />
                      ) : (
                        <div className="flex items-center space-x-2">
                          <Loader2 className="h-4 w-4 animate-spin text-blue-500" />
                          <span className="text-xs text-gray-600">
                            {Math.round(uploadProgress[file.name])}%
                          </span>
                        </div>
                      )}
                    </div>
                  )}

                  {!uploadMutation.isPending && (
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={() => removeFile(index)}
                    >
                      <X className="h-4 w-4" />
                    </Button>
                  )}
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Upload Info */}
        <div className="bg-blue-50 rounded-lg p-4">
          <div className="flex items-start space-x-3">
            <AlertCircle className="h-5 w-5 text-blue-600 mt-0.5 flex-shrink-0" />
            <div className="text-sm">
              <p className="font-medium text-blue-900 mb-1">Upload Guidelines</p>
              <ul className="text-blue-800 space-y-1">
                <li>• Maximum file size: {maxFileSize}MB per file</li>
                <li>• Maximum files per upload: {maxFiles}</li>
                <li>• Supported formats: Images (JPG, PNG, GIF, WebP) and Videos (MP4, WebM)</li>
                <li>• Recommended image size: 1920x1080 pixels or higher</li>
              </ul>
            </div>
          </div>
        </div>

        {/* Actions */}
        <div className="flex justify-end space-x-3">
          {onCancel && (
            <Button variant="outline" onClick={onCancel}>
              Cancel
            </Button>
          )}
          <Button
            onClick={() => uploadMutation.mutate(selectedFiles)}
            disabled={selectedFiles.length === 0 || uploadMutation.isPending}
            className="min-w-[120px]"
          >
            {uploadMutation.isPending ? (
              <>
                <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                Uploading...
              </>
            ) : (
              <>
                <Upload className="h-4 w-4 mr-2" />
                Upload {selectedFiles.length} File{selectedFiles.length !== 1 ? 's' : ''}
              </>
            )}
          </Button>
        </div>
      </CardContent>
    </Card>
  );
}
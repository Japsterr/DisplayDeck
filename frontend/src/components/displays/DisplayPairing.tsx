import { useState, useRef, useEffect } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { apiService } from '@/services/api';
import { QrCode, Camera, MonitorX, CheckCircle, AlertCircle } from 'lucide-react';
import { toast } from '@/lib/toast';

interface DisplayPairingProps {
  businessId: string;
  onSuccess: () => void;
  onCancel: () => void;
}

export function DisplayPairing({ businessId, onSuccess, onCancel }: DisplayPairingProps) {
  const queryClient = useQueryClient();
  const [pairingCode, setPairingCode] = useState<string>('');
  const [isScanning, setIsScanning] = useState(false);
  const [manualEntry, setManualEntry] = useState(false);
  const videoRef = useRef<HTMLVideoElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const streamRef = useRef<MediaStream | null>(null);
  const scanIntervalRef = useRef<number | null>(null);

  const pairDisplayMutation = useMutation({
    mutationFn: (code: string) => apiService.pairDisplay({ 
      pairing_code: code,
      device_info: {
        device_type: 'tablet',
        resolution: `${screen.width}x${screen.height}`,
        user_agent: navigator.userAgent
      }
    }),
    onSuccess: (data) => {
      queryClient.invalidateQueries({ queryKey: ['business-displays', businessId] });
      toast({
        title: 'Success',
        description: `Display "${data.name}" paired successfully!`,
      });
      onSuccess();
    },
    onError: (error) => {
      toast({
        title: 'Pairing Failed',
        description: error instanceof Error ? error.message : 'Invalid pairing code or display already paired',
        variant: 'destructive',
      });
    },
  });

  // Start camera for QR code scanning
  const startCamera = async () => {
    try {
      setIsScanning(true);
      const stream = await navigator.mediaDevices.getUserMedia({ 
        video: { facingMode: 'environment' } 
      });
      streamRef.current = stream;
      
      if (videoRef.current) {
        videoRef.current.srcObject = stream;
        videoRef.current.play();
      }

      // Start scanning for QR codes
      scanIntervalRef.current = setInterval(scanForQRCode, 1000);
    } catch (err) {
      console.error('Error accessing camera:', err);
      setIsScanning(false);
      toast({
        title: 'Camera Error',
        description: 'Unable to access camera. Please enter the pairing code manually.',
        variant: 'destructive',
      });
      setManualEntry(true);
    }
  };

  // Stop camera
  const stopCamera = () => {
    setIsScanning(false);
    
    if (streamRef.current) {
      streamRef.current.getTracks().forEach(track => track.stop());
      streamRef.current = null;
    }

    if (videoRef.current) {
      videoRef.current.srcObject = null;
    }

    if (scanIntervalRef.current) {
      clearInterval(scanIntervalRef.current);
      scanIntervalRef.current = null;
    }
  };

  // Scan for QR code (simplified implementation)
  const scanForQRCode = () => {
    if (!videoRef.current || !canvasRef.current) return;

    const video = videoRef.current;
    const canvas = canvasRef.current;
    const ctx = canvas.getContext('2d');
    
    if (!ctx || video.videoWidth === 0) return;

    canvas.width = video.videoWidth;
    canvas.height = video.videoHeight;
    ctx.drawImage(video, 0, 0, canvas.width, canvas.height);

    // In a real implementation, you would use a QR code scanning library like jsQR
    // For now, we'll simulate detection and provide manual entry
    // This is a placeholder for actual QR code detection
  };

  // Handle manual pairing code submission
  const handleManualPairing = () => {
    if (!pairingCode.trim()) {
      toast({
        title: 'Invalid Code',
        description: 'Please enter a valid pairing code',
        variant: 'destructive',
      });
      return;
    }

    pairDisplayMutation.mutate(pairingCode.trim());
  };

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      stopCamera();
    };
  }, []);

  return (
    <div className="space-y-6">
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center space-x-2">
            <QrCode className="h-6 w-6" />
            <span>Pair Display Device</span>
          </CardTitle>
          <CardDescription>
            Scan the QR code on your display device or enter the pairing code manually
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          {!manualEntry && !isScanning && (
            <div className="text-center space-y-4">
              <div className="w-24 h-24 bg-blue-100 rounded-lg flex items-center justify-center mx-auto">
                <Camera className="h-12 w-12 text-blue-600" />
              </div>
              <div>
                <h3 className="text-lg font-medium mb-2">Ready to Scan</h3>
                <p className="text-gray-600 mb-4">
                  Position the QR code from your display device within the camera frame
                </p>
                <Button onClick={startCamera} className="mr-2">
                  <Camera className="h-4 w-4 mr-2" />
                  Start Camera
                </Button>
                <Button variant="outline" onClick={() => setManualEntry(true)}>
                  Enter Code Manually
                </Button>
              </div>
            </div>
          )}

          {isScanning && (
            <div className="space-y-4">
              <div className="relative bg-black rounded-lg overflow-hidden">
                <video
                  ref={videoRef}
                  className="w-full h-64 object-cover"
                  playsInline
                  muted
                />
                <canvas
                  ref={canvasRef}
                  className="hidden"
                />
                <div className="absolute inset-0 border-4 border-blue-500 rounded-lg">
                  <div className="absolute top-1/2 left-1/2 transform -translate-x-1/2 -translate-y-1/2">
                    <div className="w-48 h-48 border-2 border-white border-dashed rounded-lg"></div>
                  </div>
                </div>
              </div>
              <div className="text-center">
                <p className="text-sm text-gray-600 mb-4">
                  Position the QR code within the frame
                </p>
                <div className="flex justify-center space-x-2">
                  <Button variant="outline" onClick={stopCamera}>
                    <MonitorX className="h-4 w-4 mr-2" />
                    Stop Camera
                  </Button>
                  <Button variant="outline" onClick={() => setManualEntry(true)}>
                    Enter Code Instead
                  </Button>
                </div>
              </div>
            </div>
          )}

          {manualEntry && (
            <div className="space-y-4">
              <div className="text-center mb-4">
                <div className="w-16 h-16 bg-gray-100 rounded-lg flex items-center justify-center mx-auto mb-3">
                  <QrCode className="h-8 w-8 text-gray-400" />
                </div>
                <h3 className="text-lg font-medium mb-2">Enter Pairing Code</h3>
                <p className="text-gray-600">
                  Find the pairing code on your display device screen
                </p>
              </div>

              <div className="max-w-sm mx-auto">
                <label htmlFor="pairingCode" className="block text-sm font-medium text-gray-700 mb-2">
                  Pairing Code
                </label>
                <input
                  id="pairingCode"
                  type="text"
                  value={pairingCode}
                  onChange={(e) => setPairingCode(e.target.value.toUpperCase())}
                  placeholder="Enter 6-8 character code"
                  className="w-full px-3 py-2 border border-gray-300 rounded-md text-center font-mono text-lg tracking-widest uppercase focus:outline-none focus:ring-2 focus:ring-blue-500"
                  maxLength={8}
                />
                <p className="text-xs text-gray-500 mt-1 text-center">
                  Example: ABC123DE
                </p>
              </div>

              <div className="flex justify-center space-x-2">
                <Button
                  onClick={handleManualPairing}
                  disabled={pairDisplayMutation.isPending || !pairingCode.trim()}
                  className="min-w-[120px]"
                >
                  {pairDisplayMutation.isPending ? (
                    <>
                      <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-white mr-2"></div>
                      Pairing...
                    </>
                  ) : (
                    <>
                      <CheckCircle className="h-4 w-4 mr-2" />
                      Pair Device
                    </>
                  )}
                </Button>
                {!isScanning && (
                  <Button variant="outline" onClick={startCamera}>
                    <Camera className="h-4 w-4 mr-2" />
                    Use Camera
                  </Button>
                )}
              </div>
            </div>
          )}

          <div className="pt-4 border-t">
            <div className="flex items-start space-x-3 p-3 bg-blue-50 rounded-lg">
              <AlertCircle className="h-5 w-5 text-blue-600 mt-0.5 flex-shrink-0" />
              <div className="text-sm">
                <p className="font-medium text-blue-900 mb-1">Need help finding the pairing code?</p>
                <ul className="text-blue-800 space-y-1">
                  <li>• The code appears on your display device screen</li>
                  <li>• It's usually 6-8 characters long</li>
                  <li>• The code expires after 10 minutes</li>
                  <li>• Restart your display device to generate a new code</li>
                </ul>
              </div>
            </div>
          </div>

          <div className="flex justify-end space-x-2 pt-4">
            <Button variant="outline" onClick={onCancel}>
              Cancel
            </Button>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
"use client";

import { useEffect, useState, useRef } from "react";
import { Upload, Image as ImageIcon, MoreVertical, RefreshCw, Trash2, FileVideo } from "lucide-react";
import { formatDistanceToNow } from "date-fns";
import { useRouter } from "next/navigation";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Input } from "@/components/ui/input";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Label } from "@/components/ui/label";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";

interface MediaFile {
  Id: number;
  FileName: string;
  FileType: string;
  Orientation: string;
  StorageURL: string;
  CreatedAt: string;
}

export default function MediaPage() {
  const router = useRouter();
  const [mediaFiles, setMediaFiles] = useState<MediaFile[]>([]);
  const [loading, setLoading] = useState(true);
  const [isUploadDialogOpen, setIsUploadDialogOpen] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [orientation, setOrientation] = useState("Landscape");
  const fileInputRef = useRef<HTMLInputElement>(null);

  const fetchMedia = async () => {
    try {
      setLoading(true);
      const token = localStorage.getItem("token");
      const userStr = localStorage.getItem("user");

      if (!token || !userStr) {
        router.push("/login");
        return;
      }

      const user = JSON.parse(userStr);
      const orgId = user.OrganizationId;
      const apiUrl = process.env.NEXT_PUBLIC_API_URL || "https://api.displaydeck.co.za";

      const response = await fetch(`${apiUrl}/organizations/${orgId}/media-files`, {
        headers: {
          "X-Auth-Token": token || "",
        },
      });

      if (response.status === 401) {
        router.push("/login");
        return;
      }

      if (!response.ok) throw new Error("Failed to fetch media");

      const data = await response.json();
      setMediaFiles(data.value || []);
    } catch (error) {
      console.error(error);
      toast.error("Failed to load media library");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchMedia();
  }, []);

  const handleUpload = async (e: React.FormEvent) => {
    e.preventDefault();
    const file = fileInputRef.current?.files?.[0];
    if (!file) {
      toast.error("Please select a file");
      return;
    }

    try {
      setUploading(true);
      const token = localStorage.getItem("token");
      const userStr = localStorage.getItem("user");
      if (!token || !userStr) return;

      const user = JSON.parse(userStr);
      const orgId = user.OrganizationId;
      const apiUrl = process.env.NEXT_PUBLIC_API_URL || "https://api.displaydeck.co.za";

      // 1. Get Presigned URL
      const uploadUrlRes = await fetch(`${apiUrl}/media-files/upload-url`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-Auth-Token": token || "",
        },
        body: JSON.stringify({
          OrganizationId: orgId,
          FileName: file.name,
          FileType: file.type,
          ContentLength: file.size,
          Orientation: orientation,
        }),
      });

      if (!uploadUrlRes.ok) {
        const errorText = await uploadUrlRes.text();
        console.error("Upload URL Error:", errorText);
        throw new Error(`Failed to get upload URL: ${errorText}`);
      }
      const { UploadUrl } = await uploadUrlRes.json();

      // 2. Upload File to MinIO/S3
      const uploadRes = await fetch(UploadUrl, {
        method: "PUT",
        body: file,
        headers: {
          "Content-Type": file.type,
        },
      });

      if (!uploadRes.ok) {
        const errorText = await uploadRes.text();
        console.error("MinIO Upload Error:", errorText);
        throw new Error(`Failed to upload file content: ${uploadRes.status} ${uploadRes.statusText}`);
      }

      toast.success("File uploaded successfully");
      setIsUploadDialogOpen(false);
      setOrientation("Landscape");
      fetchMedia();
    } catch (error) {
      console.error(error);
      toast.error("Upload failed");
    } finally {
      setUploading(false);
    }
  };

  const handleDeleteMedia = async (id: number) => {
    if (!confirm("Are you sure you want to delete this file?")) return;

    try {
      const token = localStorage.getItem("token");
      const apiUrl = process.env.NEXT_PUBLIC_API_URL || "https://api.displaydeck.co.za";

      const response = await fetch(`${apiUrl}/media-files/${id}`, {
        method: "DELETE",
        headers: {
          "X-Auth-Token": token || "",
        },
      });

      if (!response.ok) throw new Error("Failed to delete file");

      toast.success("File deleted");
      setMediaFiles(mediaFiles.filter(m => m.Id !== id));
    } catch (error) {
      console.error(error);
      toast.error("Failed to delete file");
    }
  };

  return (
    <div className="flex flex-col gap-4 p-4 pt-0">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-3xl font-bold tracking-tight">Media Library</h2>
          <p className="text-muted-foreground">
            Upload and manage your images and videos.
          </p>
        </div>
        <div className="flex items-center gap-2">
          <Button variant="outline" size="icon" onClick={fetchMedia}>
            <RefreshCw className="h-4 w-4" />
          </Button>
          <Dialog open={isUploadDialogOpen} onOpenChange={setIsUploadDialogOpen}>
            <DialogTrigger asChild>
              <Button>
                <Upload className="mr-2 h-4 w-4" /> Upload Media
              </Button>
            </DialogTrigger>
            <DialogContent>
              <DialogHeader>
                <DialogTitle>Upload Media</DialogTitle>
                <DialogDescription>
                  Select an image or video file to upload. Supported formats: JPG, PNG, MP4.
                </DialogDescription>
              </DialogHeader>
              <form onSubmit={handleUpload}>
                <div className="grid gap-4 py-4">
                  <div className="grid w-full max-w-sm items-center gap-1.5">
                    <Label htmlFor="file">File</Label>
                    <Input id="file" type="file" ref={fileInputRef} accept="image/*,video/*" />
                  </div>
                  <div className="grid w-full max-w-sm items-center gap-1.5">
                    <Label htmlFor="orientation">Orientation</Label>
                    <Select value={orientation} onValueChange={setOrientation}>
                      <SelectTrigger>
                        <SelectValue placeholder="Select orientation" />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="Landscape">Landscape (16:9)</SelectItem>
                        <SelectItem value="Portrait">Portrait (9:16)</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
                </div>
                <DialogFooter>
                  <Button variant="outline" type="button" onClick={() => setIsUploadDialogOpen(false)}>Cancel</Button>
                  <Button type="submit" disabled={uploading}>
                    {uploading ? "Uploading..." : "Upload"}
                  </Button>
                </DialogFooter>
              </form>
            </DialogContent>
          </Dialog>
        </div>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Files</CardTitle>
          <CardDescription>
            {mediaFiles.length} files in your library.
          </CardDescription>
        </CardHeader>
        <CardContent>
          {loading ? (
            <div className="text-center py-8 text-muted-foreground">Loading media...</div>
          ) : mediaFiles.length === 0 ? (
            <div className="text-center py-12 border-2 border-dashed rounded-lg">
              <ImageIcon className="h-12 w-12 mx-auto text-muted-foreground opacity-50" />
              <h3 className="mt-4 text-lg font-semibold">No media files</h3>
              <p className="text-muted-foreground mb-4">Upload your first image or video.</p>
              <Button onClick={() => setIsUploadDialogOpen(true)}>Upload Media</Button>
            </div>
          ) : (
            <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-6 gap-4">
              {mediaFiles.map((file) => (
                <div key={file.Id} className="group relative border rounded-lg overflow-hidden bg-muted/40">
                  <div className="aspect-square flex items-center justify-center bg-black/5">
                    {file.FileType.startsWith("image/") ? (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img 
                        src={file.StorageURL} 
                        alt={file.FileName} 
                        className="w-full h-full object-cover"
                        onError={(e) => {
                          (e.target as HTMLImageElement).src = "https://placehold.co/400?text=Error";
                        }}
                      />
                    ) : (
                      <FileVideo className="h-12 w-12 text-muted-foreground" />
                    )}
                  </div>
                  <div className="p-2">
                    <p className="text-sm font-medium truncate" title={file.FileName}>{file.FileName}</p>
                    <p className="text-xs text-muted-foreground">
                      {formatDistanceToNow(new Date(file.CreatedAt), { addSuffix: true })}
                    </p>
                  </div>
                  <div className="absolute top-2 right-2 opacity-0 group-hover:opacity-100 transition-opacity">
                    <DropdownMenu>
                      <DropdownMenuTrigger asChild>
                        <Button variant="secondary" size="icon" className="h-8 w-8">
                          <MoreVertical className="h-4 w-4" />
                        </Button>
                      </DropdownMenuTrigger>
                      <DropdownMenuContent align="end">
                        <DropdownMenuItem onClick={() => window.open(file.StorageURL, '_blank')}>
                          View Original
                        </DropdownMenuItem>
                        <DropdownMenuSeparator />
                        <DropdownMenuItem className="text-red-600" onClick={() => handleDeleteMedia(file.Id)}>
                          <Trash2 className="mr-2 h-4 w-4" /> Delete
                        </DropdownMenuItem>
                      </DropdownMenuContent>
                    </DropdownMenu>
                  </div>
                </div>
              ))}
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}

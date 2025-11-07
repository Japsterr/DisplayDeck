unit MediaLibraryFrame;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants, 
  FMX.Types, FMX.Graphics, FMX.Controls, FMX.Forms, FMX.Dialogs, FMX.StdCtrls,
  FMX.Controls.Presentation, FMX.Objects, FMX.Layouts, FMX.ListView.Types,
  FMX.ListView.Appearances, FMX.ListView.Adapters.Base, FMX.ListView, FMX.Edit,
  uApiClient, System.JSON, System.Net.HttpClient;

type
  TFrame7 = class(TFrame)
    LayoutBackground: TLayout;
    RectBackground: TRectangle;
    LayoutMain: TLayout;
    LayoutHeader: TLayout;
    lblTitle: TLabel;
    btnUploadMedia: TButton;
    LayoutContent: TLayout;
    LayoutListView: TLayout;
    RectListCard: TRectangle;
    lvMediaFiles: TListView;
    LayoutDetail: TLayout;
    RectDetailCard: TRectangle;
    LayoutDetailContent: TLayout;
    lblDetailTitle: TLabel;
    ScrollBoxDetail: TVertScrollBox;
    LayoutForm: TLayout;
    lblFileName: TLabel;
    edtFileName: TEdit;
    lblFileType: TLabel;
    edtFileType: TEdit;
    lblFileSize: TLabel;
    edtFileSize: TEdit;
    lblDuration: TLabel;
    edtDuration: TEdit;
    lblTags: TLabel;
    edtTags: TEdit;
    LayoutPreview: TLayout;
    lblPreview: TLabel;
    imgPreview: TImage;
    LayoutButtons: TLayout;
    btnSaveMedia: TButton;
    btnDeleteMedia: TButton;
    btnClearMedia: TButton;
    procedure btnUploadMediaClick(Sender: TObject);
    procedure lvMediaFilesItemClick(const Sender: TObject; const AItem: TListViewItem);
    procedure btnSaveMediaClick(Sender: TObject);
    procedure btnDeleteMediaClick(Sender: TObject);
    procedure btnClearMediaClick(Sender: TObject);
  private
    FSelectedMediaId: Integer;
    FOrganizationId: Integer;
    procedure LoadMediaFiles;
    procedure ClearForm;
    procedure LoadMediaDetails(AMediaId: Integer);
  public
    procedure Initialize(AOrganizationId: Integer);
  end;

implementation

{$R *.fmx}

uses
  FMX.DialogService;

// API Base: http://localhost:2001/tms/xdata
// Endpoints:
//   GET  /organizations/{OrgId}/media-files - List all media files
//   POST /organizations/{OrgId}/media-files - Upload new media file
//   PUT  /media-files/{Id} - Update media file metadata
//   DELETE /media-files/{Id} - Delete media file

procedure TFrame7.Initialize(AOrganizationId: Integer);
begin
  FOrganizationId := AOrganizationId;
  FSelectedMediaId := -1;
  ClearForm;
  LoadMediaFiles;
end;

procedure TFrame7.LoadMediaFiles;
var
  Item: TListViewItem;
  ApiMediaFiles: TArray<uApiClient.TMediaFileData>;
  I: Integer;
begin
  lvMediaFiles.BeginUpdate;
  try
    lvMediaFiles.Items.Clear;
    
    try
      // Call API to get media files
      ApiMediaFiles := TApiClient.Instance.GetMediaFiles(FOrganizationId);
      
      for I := 0 to High(ApiMediaFiles) do
      begin
        Item := lvMediaFiles.Items.Add;
        Item.Text := ApiMediaFiles[I].FileName;
        Item.Detail := Format('%s • %.1f KB', [
          ApiMediaFiles[I].FileType, 
          ApiMediaFiles[I].FileSize / 1024
        ]);
        Item.Tag := ApiMediaFiles[I].Id;
      end;
    except
      on E: Exception do
        ShowMessage('Error loading media files: ' + E.Message);
    end;
  finally
    lvMediaFiles.EndUpdate;
  end;
end;

procedure TFrame7.lvMediaFilesItemClick(const Sender: TObject; const AItem: TListViewItem);
begin
  if Assigned(AItem) then
  begin
    FSelectedMediaId := AItem.Tag;
    LoadMediaDetails(FSelectedMediaId);
  end;
end;

procedure TFrame7.LoadMediaDetails(AMediaId: Integer);
begin
  // TODO: API call to GET /media-files/{AMediaId}
  // For now, populate with sample data
  case AMediaId of
    1: begin
      edtFileName.Text := 'promo_video.mp4';
      edtFileType.Text := 'video/mp4';
      edtFileSize.Text := '2.4 MB';
      edtDuration.Text := '30';
      edtTags.Text := 'promo, video, advertisement';
    end;
    2: begin
      edtFileName.Text := 'banner_ad.jpg';
      edtFileType.Text := 'image/jpeg';
      edtFileSize.Text := '512 KB';
      edtDuration.Text := '10';
      edtTags.Text := 'banner, image, static';
    end;
    3: begin
      edtFileName.Text := 'product_showcase.mp4';
      edtFileType.Text := 'video/mp4';
      edtFileSize.Text := '5.1 MB';
      edtDuration.Text := '60';
      edtTags.Text := 'product, showcase, video';
    end;
  end;
end;

procedure TFrame7.ClearForm;
begin
  FSelectedMediaId := -1;
  edtFileName.Text := '';
  edtFileType.Text := '';
  edtFileSize.Text := '';
  edtDuration.Text := '';
  edtTags.Text := '';
  imgPreview.Bitmap := nil;
end;

procedure TFrame7.btnUploadMediaClick(Sender: TObject);
var
  OpenDialog: TOpenDialog;
  UploadResult: uApiClient.TMediaUploadResponse;
  Success: Boolean;
  FileName: string;
begin
  OpenDialog := TOpenDialog.Create(nil);
  try
    OpenDialog.Filter := 'Media Files|*.jpg;*.jpeg;*.png;*.gif;*.mp4;*.avi;*.mov;*.wmv|All Files|*.*';
    OpenDialog.Options := [TOpenOption.ofFileMustExist];
    
    if OpenDialog.Execute then
    begin
      FileName := ExtractFileName(OpenDialog.FileName);
      
      try
        // Step 1: Request upload URL from API
        UploadResult := TApiClient.Instance.RequestMediaUpload;
        
        if not UploadResult.Success then
        begin
          ShowMessage('Failed to request upload URL: ' + UploadResult.Message);
          Exit;
        end;
        
        // Step 2: Upload file to the signed URL
        Success := TApiClient.Instance.UploadMediaFile(UploadResult.UploadUrl, OpenDialog.FileName);
        
        if Success then
        begin
          ShowMessage('File "' + FileName + '" uploaded successfully');
          LoadMediaFiles; // Refresh the list
        end
        else
          ShowMessage('Failed to upload file');
      except
        on E: Exception do
          ShowMessage('Error uploading file: ' + E.Message);
      end;
    end;
  finally
    OpenDialog.Free;
  end;
end;

procedure TFrame7.btnSaveMediaClick(Sender: TObject);
begin
  if FSelectedMediaId = -1 then
    Exit;
    
  // TODO: API call to PUT /media-files/{FSelectedMediaId}
  TDialogService.ShowMessage('Media file updated successfully');
  LoadMediaFiles;
end;

procedure TFrame7.btnDeleteMediaClick(Sender: TObject);
begin
  if FSelectedMediaId = -1 then
    Exit;
  
  if MessageDlg('Are you sure you want to delete this media file?', 
                TMsgDlgType.mtConfirmation, 
                [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], 0) = mrYes then
  begin
    // TODO: API call to DELETE /media-files/{FSelectedMediaId}
    ClearForm;
    LoadMediaFiles;
    ShowMessage('Media file deleted successfully');
  end;
end;

procedure TFrame7.btnClearMediaClick(Sender: TObject);
begin
  ClearForm;
end;

end.

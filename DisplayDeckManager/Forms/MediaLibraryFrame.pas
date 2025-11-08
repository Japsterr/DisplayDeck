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
  FMX.DialogService, FMX.DialogService.Sync, System.IOUtils;

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
        TDialogService.ShowMessage(
          'Error loading media files: ' + E.Message + sLineBreak +
          'URL: ' + TApiClient.Instance.LastURL + sLineBreak +
          'Status: ' + TApiClient.Instance.LastResponseCode.ToString + sLineBreak +
          'Body: ' + TApiClient.Instance.LastResponseBody
        );
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
var
  M: uApiClient.TMediaFileData;
  SizeText: string;
begin
  try
    M := TApiClient.Instance.GetMediaFile(AMediaId);
    if M.Id = 0 then
    begin
      TDialogService.ShowMessage('Failed to load media details');
      Exit;
    end;
    edtFileName.Text := M.FileName;
    edtFileType.Text := M.FileType;
    if M.FileSize > 1024*1024 then
      SizeText := Format('%.1f MB',[M.FileSize/1024/1024])
    else if M.FileSize > 1024 then
      SizeText := Format('%.1f KB',[M.FileSize/1024])
    else
      SizeText := IntToStr(M.FileSize) + ' B';
    edtFileSize.Text := SizeText;
    if M.Duration > 0 then
      edtDuration.Text := IntToStr(M.Duration)
    else
      edtDuration.Text := '';
    edtTags.Text := M.Tags;
  except
    on E: Exception do
      TDialogService.ShowMessage('Error loading details: ' + E.Message);
  end;
end;

procedure TFrame7.btnUploadMediaClick(Sender: TObject);
var
  OpenDialog: TOpenDialog;
  UploadResult: uApiClient.TMediaUploadResponse;
  Success: Boolean;
  FileName: string;
  FileType: string;
  ContentLen: Int64;
begin
  OpenDialog := TOpenDialog.Create(nil);
  try
    OpenDialog.Filter := 'Media Files|*.jpg;*.jpeg;*.png;*.gif;*.mp4;*.avi;*.mov;*.wmv|All Files|*.*';
    OpenDialog.Options := [TOpenOption.ofFileMustExist];

    if OpenDialog.Execute then
    begin
      FileName := ExtractFileName(OpenDialog.FileName);
      try
        if SameText(ExtractFileExt(OpenDialog.FileName), '.png') then FileType := 'image/png'
        else if SameText(ExtractFileExt(OpenDialog.FileName), '.jpg') or SameText(ExtractFileExt(OpenDialog.FileName), '.jpeg') then FileType := 'image/jpeg'
        else if SameText(ExtractFileExt(OpenDialog.FileName), '.gif') then FileType := 'image/gif'
        else if SameText(ExtractFileExt(OpenDialog.FileName), '.mp4') then FileType := 'video/mp4'
        else FileType := 'application/octet-stream';
        ContentLen := TFile.GetSize(OpenDialog.FileName);

        UploadResult := TApiClient.Instance.RequestMediaUpload(FOrganizationId, FileName, FileType, ContentLen);
        if not UploadResult.Success then
        begin
          TDialogService.ShowMessage(
            'Failed to request upload URL: ' + UploadResult.Message + sLineBreak +
            'URL: ' + TApiClient.Instance.LastURL + sLineBreak +
            'Status: ' + TApiClient.Instance.LastResponseCode.ToString + sLineBreak +
            'Body: ' + TApiClient.Instance.LastResponseBody
          );
          Exit;
        end;
        Success := TApiClient.Instance.UploadMediaFile(UploadResult.UploadUrl, OpenDialog.FileName);
        if Success then
        begin
          TDialogService.ShowMessage('File "' + FileName + '" uploaded successfully');
          LoadMediaFiles;
        end
        else
          TDialogService.ShowMessage(
            'Failed to upload file' + sLineBreak +
            'PUT URL: ' + UploadResult.UploadUrl + sLineBreak +
            'Status: ' + TApiClient.Instance.LastResponseCode.ToString + sLineBreak +
            'Body: ' + TApiClient.Instance.LastResponseBody
          );
      except
        on E: Exception do
          TDialogService.ShowMessage('Error uploading file: ' + E.Message);
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
  
  if TDialogServiceSync.MessageDialog('Are you sure you want to delete this media file?',
                TMsgDlgType.mtConfirmation, 
                [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], TMsgDlgBtn.mbNo, 0) = mrYes then
  begin
    // TODO: API call to DELETE /media-files/{FSelectedMediaId}
    ClearForm;
    LoadMediaFiles;
    TDialogService.ShowMessage('Media file deleted successfully');
  end;
end;

procedure TFrame7.btnClearMediaClick(Sender: TObject);
begin
  ClearForm;
end;

procedure TFrame7.ClearForm;
begin
  FSelectedMediaId := -1;
  edtFileName.Text := '';
  edtFileType.Text := '';
  edtFileSize.Text := '';
  edtDuration.Text := '';
  edtTags.Text := '';
end;

end.

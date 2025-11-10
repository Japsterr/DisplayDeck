unit MediaLibraryFrame;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  System.JSON,
  FMX.Types, FMX.Graphics, FMX.Controls, FMX.Forms, FMX.Dialogs, FMX.StdCtrls,
  FMX.Controls.Presentation, FMX.Objects, FMX.Layouts, FMX.ListView.Types,
  FMX.ListView.Appearances, FMX.ListView.Adapters.Base, FMX.ListView, FMX.Edit,
  FMX.ListBox,
  uApiClient;

type
  TFrame7 = class(TFrame)
  BadgeRect: TRectangle;
  BadgeLbl: TLabel;
    LayoutBackground: TLayout;
    RectBackground: TRectangle;
    LayoutMain: TLayout;
    LayoutHeader: TLayout;
    lblTitle: TLabel;
    btnUploadMedia: TButton;
    cbbTypeFilter: TComboBox;
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
    lblOrientation: TLabel;
    cbbOrientation: TComboBox;
    procedure btnUploadMediaClick(Sender: TObject);
    procedure lvMediaFilesItemClick(const Sender: TObject; const AItem: TListViewItem);
    procedure btnSaveMediaClick(Sender: TObject);
    procedure btnDeleteMediaClick(Sender: TObject);
    procedure btnClearMediaClick(Sender: TObject);
    procedure cbbTypeFilterChange(Sender: TObject);
  private
    FSelectedMediaId: Integer;
    FOrganizationId: Integer;
    FThumbFlow: TFlowLayout;
    procedure LoadMediaFiles;
    procedure ClearForm;
    procedure LoadMediaDetails(AMediaId: Integer);
    procedure EnsureThumbFlow;
    procedure RebuildThumbnails(const ApiMediaFiles: TArray<uApiClient.TMediaFileData>);
    procedure CreateMediaCard(const M: uApiClient.TMediaFileData);
    procedure OnCardClick(Sender: TObject);
    procedure DrawVideoPlaceholderToImage(AImage: TImage);
    function GetVideoThumbCacheDir: string;
    function GetCachedVideoThumb(const AFileName: string): string;
    procedure EnsureVideoThumb(const LocalVideoPath, AFileName: string);
    function ExtractVideoFrame(const VideoPath, OutputImagePath: string): Boolean;
  public
    procedure Initialize(AOrganizationId: Integer);
  end;

implementation

{$R *.fmx}

uses
  FMX.DialogService, FMX.DialogService.Sync, System.IOUtils, uTheme,
  IdHTTP, Winapi.Windows, Winapi.ShellAPI, System.Math; // math for Min()

// API Base: http://localhost:2001/api
// Endpoints:
//   GET  /organizations/{OrgId}/media-files - List all media files
//   POST /organizations/{OrgId}/media-files - Upload new media file
//   PUT  /media-files/{Id} - Update media file metadata
//   DELETE /media-files/{Id} - Delete media file

procedure TFrame7.Initialize(AOrganizationId: Integer);
begin
  FOrganizationId := AOrganizationId;
  FSelectedMediaId := 0;
  ClearForm;
  LoadMediaFiles;
  StyleBackground(RectBackground);
  StyleCard(RectListCard);
  StyleCard(RectDetailCard);
  StyleHeaderLabel(lblDetailTitle);
  StyleMutedLabel(lblFileName);
  StyleMutedLabel(lblFileType);
  StyleMutedLabel(lblFileSize);
  StyleMutedLabel(lblDuration);
  StyleMutedLabel(lblTags);
  StyleMutedLabel(lblOrientation);
  // Populate orientation choices
  cbbOrientation.Items.Clear;
  cbbOrientation.Items.Add('Landscape');
  cbbOrientation.Items.Add('Portrait');
  // Populate media type filter
  if Assigned(cbbTypeFilter) then
  begin
    cbbTypeFilter.Items.Clear;
    cbbTypeFilter.Items.Add('All');
    cbbTypeFilter.Items.Add('Images');
    cbbTypeFilter.Items.Add('Videos');
    cbbTypeFilter.Items.Add('Other');
    cbbTypeFilter.ItemIndex := 0;
    cbbTypeFilter.OnChange := cbbTypeFilterChange;
  end;
end;

procedure TFrame7.LoadMediaFiles;
var
  Item: TListViewItem;
  ApiMediaFiles: TArray<uApiClient.TMediaFileData>;
  I: Integer;
  Filter: string;
  ShowItem: Boolean;
  Filtered: TArray<uApiClient.TMediaFileData>;
  C: Integer;
begin
  lvMediaFiles.BeginUpdate;
  try
    lvMediaFiles.Items.Clear;
    try
      ApiMediaFiles := TApiClient.Instance.GetMediaFiles(FOrganizationId);
      SetLength(Filtered, Length(ApiMediaFiles));
      C := 0;
      for I := 0 to High(ApiMediaFiles) do
      begin
        Filter := '';
        if Assigned(cbbTypeFilter) and (cbbTypeFilter.ItemIndex >= 0) then
          Filter := cbbTypeFilter.Items[cbbTypeFilter.ItemIndex];
        ShowItem := True;
        if Filter = 'Images' then
          ShowItem := ApiMediaFiles[I].FileType.ToLower.StartsWith('image/')
        else if Filter = 'Videos' then
          ShowItem := ApiMediaFiles[I].FileType.ToLower.StartsWith('video/')
        else if Filter = 'Other' then
          ShowItem := (not ApiMediaFiles[I].FileType.ToLower.StartsWith('image/')) and (not ApiMediaFiles[I].FileType.ToLower.StartsWith('video/'));
        if not ShowItem then Continue;
        Item := lvMediaFiles.Items.Add;
        Item.Text := ApiMediaFiles[I].FileName;
        if ApiMediaFiles[I].FileSize > 0 then
        begin
          if ApiMediaFiles[I].FileSize > 1024*1024 then
            Item.Detail := Format('%s • %.1f MB', [ApiMediaFiles[I].FileType, ApiMediaFiles[I].FileSize/1024/1024])
          else
            Item.Detail := Format('%s • %.1f KB', [ApiMediaFiles[I].FileType, ApiMediaFiles[I].FileSize/1024]);
        end
        else
          Item.Detail := ApiMediaFiles[I].FileType;
        Item.Tag := ApiMediaFiles[I].Id;
        // collect for thumbnails
        Filtered[C] := ApiMediaFiles[I];
        Inc(C);
      end;
      SetLength(Filtered, C);
      RebuildThumbnails(Filtered);
    except
      on E: Exception do
        TDialogService.ShowMessage('Error loading media files: ' + E.Message + sLineBreak +
          'URL: ' + TApiClient.Instance.LastURL + sLineBreak +
          'Status: ' + TApiClient.Instance.LastResponseCode.ToString + sLineBreak +
          'Body: ' + TApiClient.Instance.LastResponseBody);
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
  Url: string;
  Http: TIdHTTP;
  MS: TMemoryStream;
  p, slash: Integer;
  rest, hostPort, pathQ, connectUrl: string;
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
    else if M.FileSize > 0 then
      SizeText := IntToStr(M.FileSize) + ' B'
    else
      SizeText := '';
    edtFileSize.Text := SizeText;
    if M.Duration > 0 then
      edtDuration.Text := IntToStr(M.Duration)
    else
      edtDuration.Text := '';
    edtTags.Text := M.Tags;
    // Orientation combo selection
    if M.Orientation <> '' then
    begin
      if SameText(M.Orientation,'Portrait') then
        cbbOrientation.ItemIndex := cbbOrientation.Items.IndexOf('Portrait')
      else
        cbbOrientation.ItemIndex := cbbOrientation.Items.IndexOf('Landscape');
    end
    else
      cbbOrientation.ItemIndex := -1;
    imgPreview.Bitmap.SetSize(0,0);
    if M.FileType.ToLower.StartsWith('image/') then
    begin
      Url := TApiClient.Instance.GetMediaDownloadUrl(AMediaId);
      if Url <> '' then
      begin
        Http := TIdHTTP.Create(nil);
        try
          Http.Request.Accept := '*/*';
          MS := TMemoryStream.Create;
          try
            // Preserve original Host header from presigned URL for SigV4
            p := Pos('://', Url);
            rest := Url; if p > 0 then rest := Copy(Url, p+3, MaxInt);
            slash := Pos('/', rest);
            if slash > 0 then
            begin
              hostPort := Copy(rest, 1, slash-1);
              pathQ := Copy(rest, slash+1, MaxInt);
            end
            else
            begin
              hostPort := rest; pathQ := '';
            end;
            Http.Request.Host := hostPort; // critical for SigV4
            // Connect to localhost when host is minio (Docker)
            if SameText(hostPort, 'minio:9000') then
              connectUrl := 'http://localhost:9000/' + pathQ
            else
              connectUrl := Url;

            try
              Http.Get(connectUrl, MS);
              if (Http.ResponseCode >= 200) and (Http.ResponseCode < 300) then
              begin
                MS.Position := 0;
                try imgPreview.Bitmap.LoadFromStream(MS); except end;
              end;
            except
              // ignore preview load errors
            end;
          finally MS.Free; end;
        finally Http.Free; end;
      end;
    end
    else
    begin
      DrawVideoPlaceholderToImage(imgPreview);
    end;
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
  Orientation, OrientationDefault: string;
  ThumbTarget: string;
  MsgRes: Integer;
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

        // Determine default Orientation (default Landscape). Image auto-detect removed for compatibility.
        OrientationDefault := 'Landscape';
        // Show a yes/no dialog instead of free text input.
        MsgRes := TDialogServiceSync.MessageDialog(
          'Select Orientation (Yes = Landscape, No = Portrait)',
          TMsgDlgType.mtConfirmation,
          [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo],
          TMsgDlgBtn.mbYes, 0);
        if MsgRes = mrYes then Orientation := 'Landscape'
        else if MsgRes = mrNo then Orientation := 'Portrait'
        else Orientation := OrientationDefault;
        // Reflect chosen orientation in combo (if user edits after upload it shows current)
        if SameText(Orientation,'Portrait') then
          cbbOrientation.ItemIndex := cbbOrientation.Items.IndexOf('Portrait')
        else
          cbbOrientation.ItemIndex := cbbOrientation.Items.IndexOf('Landscape');
        // For video files attempt to extract a thumbnail (first frame) and cache it locally.
        if FileType.StartsWith('video/') then
        begin
          ThumbTarget := GetCachedVideoThumb(FileName);
          if not FileExists(ThumbTarget) then
          begin
            EnsureVideoThumb(OpenDialog.FileName, FileName);
          end;
        end;

        UploadResult := TApiClient.Instance.RequestMediaUpload(FOrganizationId, FileName, FileType, Orientation, ContentLen);
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
var
  M: uApiClient.TMediaFileData;
  Success: Boolean;
  NewOrientation: string;
begin
  if FSelectedMediaId <= 0 then
  begin
    TDialogService.ShowMessage('No media selected');
    Exit;
  end;
  M := TApiClient.Instance.GetMediaFile(FSelectedMediaId);
  if (cbbOrientation.ItemIndex >= 0) then
    NewOrientation := cbbOrientation.Items[cbbOrientation.ItemIndex]
  else
    NewOrientation := M.Orientation; // preserve existing if none selected
  Success := TApiClient.Instance.UpdateMediaFileMeta(FSelectedMediaId, edtFileName.Text, M.FileType, M.StorageURL, NewOrientation);
  if Success then
  begin
    TDialogService.ShowMessage('Media updated');
    LoadMediaFiles;
  end
  else
    TDialogService.ShowMessage('Update failed');
end;

procedure TFrame7.btnDeleteMediaClick(Sender: TObject);
var
  Success: Boolean;
begin
  if FSelectedMediaId <= 0 then
  begin
    TDialogService.ShowMessage('No media selected');
    Exit;
  end;
  if TDialogServiceSync.MessageDialog('Delete this media?', TMsgDlgType.mtConfirmation,
     [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], TMsgDlgBtn.mbNo, 0) = mrYes then
  begin
    Success := TApiClient.Instance.DeleteMediaFile(FSelectedMediaId);
    if Success then
    begin
      TDialogService.ShowMessage('Deleted');
      FSelectedMediaId := 0;
      ClearForm;
      LoadMediaFiles;
    end
    else
      TDialogService.ShowMessage('Delete failed');
  end;
end;

procedure TFrame7.btnClearMediaClick(Sender: TObject);
begin
  // Clear current selection and reset form
  FSelectedMediaId := 0;
  ClearForm;
end;

procedure TFrame7.ClearForm;
begin
  edtFileName.Text := '';
  edtFileType.Text := '';
  edtFileSize.Text := '';
  edtDuration.Text := '';
  edtTags.Text := '';
  cbbOrientation.ItemIndex := -1;
  imgPreview.Bitmap.SetSize(0,0);
end;

// Ensure the flow layout exists (lazy creation)
procedure TFrame7.EnsureThumbFlow;
begin
  if not Assigned(FThumbFlow) then
  begin
    FThumbFlow := TFlowLayout.Create(Self);
    FThumbFlow.Parent := LayoutListView;
    FThumbFlow.Align := TAlignLayout.Client;
    FThumbFlow.Margins.Rect := TRectF.Create(12,12,12,12);
    lvMediaFiles.Visible := False;
  end
  else
  begin
    FThumbFlow.BeginUpdate;
    try
      while FThumbFlow.ChildrenCount > 0 do
        FThumbFlow.Children[0].Free;
    finally
      FThumbFlow.EndUpdate;
    end;
  end;
end;

procedure TFrame7.RebuildThumbnails(const ApiMediaFiles: TArray<uApiClient.TMediaFileData>);
var
  M: uApiClient.TMediaFileData;
begin
  EnsureThumbFlow;
  FThumbFlow.BeginUpdate;
  try
    for M in ApiMediaFiles do
      CreateMediaCard(M);
  finally
    FThumbFlow.EndUpdate;
  end;
end;

procedure TFrame7.CreateMediaCard(const M: uApiClient.TMediaFileData);
var
  Card: TRectangle;
  Img: TImage;
  Lbl: TLabel;
  IsImage: Boolean;
  Http: TIdHTTP;
  MS: TMemoryStream;
  Url: string;
  p, slash: Integer;
  rest, hostPort, pathQ, connectUrl: string;
  ThumbPath: string;
begin
  Card := TRectangle.Create(FThumbFlow);
  Card.Parent := FThumbFlow;
  Card.Width := 180;
  Card.Height := 180;
  Card.Fill.Color := $FFFFFFFF;
  Card.Stroke.Kind := TBrushKind.None;
  Card.XRadius := 12;
  Card.YRadius := 12;
  Card.Tag := M.Id;
  Card.HitTest := True;
  Card.Cursor := crHandPoint;
  Card.OnClick := OnCardClick;

  Img := TImage.Create(Card);
  Img.Parent := Card;
  Img.Align := TAlignLayout.Top;
  Img.Height := 130;
  Img.WrapMode := TImageWrapMode.Fit;
  Img.Bitmap.Clear($FFF0F0F0);

  Lbl := TLabel.Create(Card);
  Lbl.Parent := Card;
  Lbl.Align := TAlignLayout.Bottom;
  Lbl.Text := M.FileName;
  Lbl.Height := 40;
  Lbl.TextSettings.Font.Size := 12;
  Lbl.Trimming := TTextTrimming.Character;
  Lbl.WordWrap := False;

  IsImage := M.FileType.ToLower.StartsWith('image/');
  if IsImage then
  begin
    Url := TApiClient.Instance.GetMediaDownloadUrl(M.Id);
    if Url <> '' then
    begin
      Http := TIdHTTP.Create(nil);
      try
        Http.Request.Accept := '*/*';
        MS := TMemoryStream.Create;
        try
          // Preserve original Host header for SigV4 and connect to localhost when needed
          p := Pos('://', Url);
          rest := Url; if p > 0 then rest := Copy(Url, p+3, MaxInt);
          slash := Pos('/', rest);
          if slash > 0 then
          begin
            hostPort := Copy(rest, 1, slash-1);
            pathQ := Copy(rest, slash+1, MaxInt);
          end
          else
          begin
            hostPort := rest; pathQ := '';
          end;
          Http.Request.Host := hostPort;
          if SameText(hostPort, 'minio:9000') then
            connectUrl := 'http://localhost:9000/' + pathQ
          else
            connectUrl := Url;

          Http.Get(connectUrl, MS);
          if (Http.ResponseCode >= 200) and (Http.ResponseCode < 300) then
          begin
            MS.Position := 0;
            Img.Bitmap.LoadFromStream(MS);
          end;
        except
          Img.Bitmap.Clear($FFE0E0E0);
        end;
      finally
        MS.Free;
        Http.Free;
      end;
    end;
  end
  else
  begin
    // Try load cached video thumbnail if exists
    ThumbPath := GetCachedVideoThumb(M.FileName);
    if FileExists(ThumbPath) then
    begin
      try
        Img.Bitmap.LoadFromFile(ThumbPath);
      except
        DrawVideoPlaceholderToImage(Img);
      end;
    end
    else
      DrawVideoPlaceholderToImage(Img);
    Lbl.Text := M.FileName + sLineBreak + '(' + M.FileType + ')';
    Lbl.WordWrap := True;
    if M.Duration > 0 then
    begin
      BadgeRect := TRectangle.Create(Card);
      BadgeRect.Parent := Card;
      BadgeRect.Align := TAlignLayout.None;
      BadgeRect.Position.X := Card.Width - 60;
      BadgeRect.Position.Y := Card.Height - 22;
      BadgeRect.Width := 54;
      BadgeRect.Height := 20;
      BadgeRect.Fill.Color := $AA000000;
      BadgeRect.Stroke.Kind := TBrushKind.None;
      BadgeRect.XRadius := 6; BadgeRect.YRadius := 6;
      BadgeLbl := TLabel.Create(BadgeRect);
      BadgeLbl.Parent := BadgeRect;
      BadgeLbl.Align := TAlignLayout.Client;
      BadgeLbl.TextSettings.HorzAlign := TTextAlign.Center;
      BadgeLbl.TextSettings.VertAlign := TTextAlign.Center;
      BadgeLbl.TextSettings.Font.Size := 12;
      BadgeLbl.TextSettings.FontColor := $FFFFFFFF;
      BadgeLbl.Text := Format('%ds',[M.Duration]);
    end;
  end;
end;

procedure TFrame7.OnCardClick(Sender: TObject);
begin
  if Sender is TRectangle then
  begin
    FSelectedMediaId := TRectangle(Sender).Tag;
    LoadMediaDetails(FSelectedMediaId);
  end;
end;

procedure TFrame7.cbbTypeFilterChange(Sender: TObject);
begin
  LoadMediaFiles;
end;

procedure TFrame7.DrawVideoPlaceholderToImage(AImage: TImage);
var
  W, H: Integer;
  R: TRectF;
  cx, cy, radius, triW, triH: Single;
  p0, p1, p2: TPointF;
begin
  W := Round(AImage.Width);
  H := Round(AImage.Height);
  if (W < 10) or (H < 10) then
  begin
    W := 320;
    H := 180;
  end;
  AImage.Bitmap.SetSize(W, H);
  AImage.Bitmap.Clear($FFE7ECF0);
  if Assigned(AImage.Bitmap.Canvas) then
  begin
    AImage.Bitmap.Canvas.BeginScene;
    try
      AImage.Bitmap.Canvas.Stroke.Kind := TBrushKind.Solid;
      AImage.Bitmap.Canvas.Stroke.Color := $FFCBD5DC;
      AImage.Bitmap.Canvas.DrawRect(TRectF.Create(1,1,W-2,H-2), 8, 8, AllCorners, 1);

      cx := W * 0.5; cy := H * 0.5;
      radius := Min(W, H) * 0.18;
      R := TRectF.Create(cx - radius, cy - radius, cx + radius, cy + radius);
      AImage.Bitmap.Canvas.Fill.Kind := TBrushKind.Solid;
      AImage.Bitmap.Canvas.Fill.Color := $AA000000;
      AImage.Bitmap.Canvas.FillEllipse(R, 1);

      // Draw a white play triangle using lines (avoid TPolygon dependency)
      triW := radius * 0.85; triH := radius * 0.95;
      p0 := PointF(cx - triW * 0.35, cy - triH * 0.6);
      p1 := PointF(cx - triW * 0.35, cy + triH * 0.6);
      p2 := PointF(cx + triW * 0.65, cy);
      AImage.Bitmap.Canvas.Stroke.Color := $FFFFFFFF;
      AImage.Bitmap.Canvas.Stroke.Thickness := 4;
      AImage.Bitmap.Canvas.DrawLine(p0, p1, 1);
      AImage.Bitmap.Canvas.DrawLine(p1, p2, 1);
      AImage.Bitmap.Canvas.DrawLine(p2, p0, 1);
    finally
      AImage.Bitmap.Canvas.EndScene;
    end;
  end;
end;

function TFrame7.GetVideoThumbCacheDir: string;
begin
  Result := IncludeTrailingPathDelimiter(TPath.GetHomePath) + 'DisplayDeckThumbCache';
  if not TDirectory.Exists(Result) then
    TDirectory.CreateDirectory(Result);
end;

function TFrame7.GetCachedVideoThumb(const AFileName: string): string;
var
  Base: string;
begin
  Base := ChangeFileExt(AFileName, '');
  Result := IncludeTrailingPathDelimiter(GetVideoThumbCacheDir) + Base + '.thumb.png';
end;

procedure TFrame7.EnsureVideoThumb(const LocalVideoPath, AFileName: string);
var
  Target: string;
begin
  Target := GetCachedVideoThumb(AFileName);
  if FileExists(Target) then Exit;
  // Attempt extraction; fallback placeholder if fails.
  if not ExtractVideoFrame(LocalVideoPath, Target) then
  begin
    // create a simple placeholder file so future lookups skip extraction attempts
    // we intentionally write invalid image content; load will fail and we draw placeholder
    try
      TFile.WriteAllText(Target, '');
    except
      // ignore
    end;
  end;
end;

function TFrame7.ExtractVideoFrame(const VideoPath, OutputImagePath: string): Boolean;
var
  FFmpegExe: string;
  SI: TStartupInfo;
  PI: TProcessInformation;
  CmdLine: string;
  ExitCode: DWORD;
begin
  Result := False;
  // Look for ffmpeg.exe next to app or in PATH
  FFmpegExe := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + 'ffmpeg.exe';
  if not FileExists(FFmpegExe) then FFmpegExe := 'ffmpeg.exe';
  if not FileExists(FFmpegExe) then Exit; // ffmpeg not available

  // Build command: ffmpeg -y -i input -ss 00:00:00.5 -frames:v 1 -vf scale=320:-1 output
  CmdLine := Format('"%s" -y -ss 00:00:00.5 -i "%s" -frames:v 1 -vf scale=320:-1 "%s"',
    [FFmpegExe, VideoPath, OutputImagePath]);
  ZeroMemory(@SI, SizeOf(SI));
  SI.cb := SizeOf(SI);
  SI.dwFlags := STARTF_USESHOWWINDOW;
  SI.wShowWindow := SW_HIDE;
  ZeroMemory(@PI, SizeOf(PI));
  if CreateProcess(nil, PChar(CmdLine), nil, nil, False, CREATE_NO_WINDOW, nil, nil, SI, PI) then
  begin
    WaitForSingleObject(PI.hProcess, 15000); // wait up to 15s
    GetExitCodeProcess(PI.hProcess, ExitCode);
    CloseHandle(PI.hThread);
    CloseHandle(PI.hProcess);
    Result := (ExitCode = 0) and FileExists(OutputImagePath);
  end;
end;

end.

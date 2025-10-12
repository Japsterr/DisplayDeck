unit uMediaLibraryForm;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.Layouts,
  FMX.ListBox, FMX.StdCtrls, FMX.Controls.Presentation, FMX.ListView.Types,
  FMX.ListView.Appearances, FMX.ListView.Adapters.Base, FMX.ListView,
  FMX.MediaLibrary.Actions, FMX.StdActns, System.Actions, FMX.ActnList,
  uApiClient, uEntities;

type
  TMediaLibraryForm = class(TForm)
    Layout: TLayout;
    MediaListView: TListView;
    TopLayout: TLayout;
    RefreshButton: TButton;
    UploadButton: TButton;
    ActionList: TActionList;
    TakePhotoFromCameraAction: TTakePhotoFromCameraAction;
    TakePhotoFromLibraryAction: TTakePhotoFromLibraryAction;
    procedure FormCreate(Sender: TObject);
    procedure RefreshButtonClick(Sender: TObject);
    procedure UploadButtonClick(Sender: TObject);
    procedure TakePhotoFromCameraActionDidFinishTaking(Image: TBitmap);
    procedure TakePhotoFromLibraryActionDidFinishTaking(Image: TBitmap);
    procedure MediaListViewItemClick(const Sender: TObject;
      const AItem: TListViewItem);
  private
    FApiClient: TApiClient;
    procedure LoadMediaFiles;
    procedure HandleApiError(const ErrorMessage: string);
    procedure UploadMediaFile(Bitmap: TBitmap; const FileName: string);
  public
    { Public declarations }
  end;

var
  MediaLibraryForm: TMediaLibraryForm;

implementation

{$R *.fmx}

procedure TMediaLibraryForm.FormCreate(Sender: TObject);
begin
  FApiClient := TApiClient.Instance;
  LoadMediaFiles;
end;

procedure TMediaLibraryForm.RefreshButtonClick(Sender: TObject);
begin
  LoadMediaFiles;
end;

procedure TMediaLibraryForm.UploadButtonClick(Sender: TObject);
var
  ActionSheet: TActionSheet;
begin
  ActionSheet := TActionSheet.Create(Self);
  try
    ActionSheet.AddButton('Take Photo', TActionSheetButtonStyle.ActionSheetDefaultButtonStyle);
    ActionSheet.AddButton('Choose from Library', TActionSheetButtonStyle.ActionSheetDefaultButtonStyle);
    ActionSheet.AddButton('Cancel', TActionSheetButtonStyle.ActionSheetCancelButtonStyle);

    case ActionSheet.ShowModal of
      mrContinue: TakePhotoFromCameraAction.Execute;
      mrClose: TakePhotoFromLibraryAction.Execute;
    end;
  finally
    ActionSheet.Free;
  end;
end;

procedure TMediaLibraryForm.TakePhotoFromCameraActionDidFinishTaking(Image: TBitmap);
begin
  if Image <> nil then
  begin
    UploadMediaFile(Image, 'camera_' + FormatDateTime('yyyymmdd_hhnnss', Now) + '.jpg');
  end;
end;

procedure TMediaLibraryForm.TakePhotoFromLibraryActionDidFinishTaking(Image: TBitmap);
begin
  if Image <> nil then
  begin
    UploadMediaFile(Image, 'library_' + FormatDateTime('yyyymmdd_hhnnss', Now) + '.jpg');
  end;
end;

procedure TMediaLibraryForm.MediaListViewItemClick(const Sender: TObject;
  const AItem: TListViewItem);
begin
  // TODO: Show media preview or options
  ShowMessage('Media preview not yet implemented');
end;

procedure TMediaLibraryForm.LoadMediaFiles;
var
  Response: TMediaFileListResponse;
  MediaFile: TMediaFile;
  ListItem: TListViewItem;
begin
  MediaListView.ClearItems;

  try
    Response := FApiClient.GetMediaFiles;
    try
      if Response.Success then
      begin
        for MediaFile in Response.MediaFiles do
        begin
          ListItem := MediaListView.Items.Add;
          ListItem.Text := MediaFile.FileName;
          ListItem.Detail := Format('Size: %s | Uploaded: %s',
            [FormatByteSize(MediaFile.Size),
             FormatDateTime('yyyy-mm-dd hh:nn', MediaFile.UploadedAt)]);
          ListItem.TagString := MediaFile.Id; // Store media file ID
        end;
      end
      else
      begin
        HandleApiError('Failed to load media files: ' + Response.Message);
      end;
    finally
      Response.Free;
    end;
  except
    on E: Exception do
      HandleApiError('Error loading media files: ' + E.Message);
  end;
end;

procedure TMediaLibraryForm.UploadMediaFile(Bitmap: TBitmap; const FileName: string);
var
  Stream: TMemoryStream;
  Response: TMediaFileResponse;
begin
  Stream := TMemoryStream.Create;
  try
    Bitmap.SaveToStream(Stream);
    Stream.Position := 0;

    Response := FApiClient.UploadMediaFile(FileName, 'image/jpeg', Stream);
    try
      if Response.Success then
      begin
        ShowMessage('Media file uploaded successfully');
        LoadMediaFiles; // Refresh the list
      end
      else
      begin
        HandleApiError('Failed to upload media file: ' + Response.Message);
      end;
    finally
      Response.Free;
    end;
  finally
    Stream.Free;
  end;
end;

procedure TMediaLibraryForm.HandleApiError(const ErrorMessage: string);
begin
  ShowMessage(ErrorMessage);
end;

end.
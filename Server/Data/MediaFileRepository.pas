unit MediaFileRepository;

interface

uses uEntities, FireDAC.Comp.Client;

type
  TMediaFileRepository = class
  public
    class function CreateMedia(const OrgId: Integer; const FileName, FileType, Orientation, StorageURL: string): TMediaFile;
    class function GetById(const Id: Integer): TMediaFile;
  end;

implementation

uses System.SysUtils, FireDAC.Stan.Param, uServerContainer;

function NewConnection: TFDConnection;
begin
  Result := TFDConnection.Create(nil);
  try
    Result.Params.Assign(ServerContainer.FDConnection.Params);
    Result.LoginPrompt := False;
    Result.Connected := True;
  except
    Result.Free;
    raise;
  end;
end;

function MapMedia(const Q: TFDQuery): TMediaFile;
begin
  Result := TMediaFile.Create;
  Result.Id := Q.FieldByName('MediaFileID').AsInteger;
  Result.OrganizationId := Q.FieldByName('OrganizationID').AsInteger;
  Result.FileName := Q.FieldByName('FileName').AsString;
  Result.FileType := Q.FieldByName('FileType').AsString;
  Result.Orientation := Q.FieldByName('Orientation').AsString;
  if Q.FindField('ProcessingStatus') <> nil then
    Result.ProcessingStatus := Q.FieldByName('ProcessingStatus').AsString;
  if Q.FindField('ProcessingError') <> nil then
    Result.ProcessingError := Q.FieldByName('ProcessingError').AsString;
  Result.HasValidatedAt := (Q.FindField('ValidatedAt') <> nil) and (not Q.FieldByName('ValidatedAt').IsNull);
  if Result.HasValidatedAt then
    Result.ValidatedAt := Q.FieldByName('ValidatedAt').AsDateTime;
  Result.StorageURL := Q.FieldByName('StorageURL').AsString;
  Result.CreatedAt := Q.FieldByName('CreatedAt').AsDateTime;
  Result.UpdatedAt := Q.FieldByName('UpdatedAt').AsDateTime;
end;

class function TMediaFileRepository.CreateMedia(const OrgId: Integer; const FileName, FileType, Orientation, StorageURL: string): TMediaFile;
var C: TFDConnection; Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'insert into MediaFiles (OrganizationID, FileName, FileType, Orientation, StorageURL, ProcessingStatus) values (:Org,:Name,:Type,:Orient,:Url,''uploaded'') returning *';
      Q.ParamByName('Org').AsInteger := OrgId;
      Q.ParamByName('Name').AsString := FileName;
      Q.ParamByName('Type').AsString := FileType;
      Q.ParamByName('Orient').AsString := Orientation;
      Q.ParamByName('Url').AsString := StorageURL;
      Q.Open;
      Result := MapMedia(Q);
    finally Q.Free; end;
  finally C.Free; end;
end;

class function TMediaFileRepository.GetById(const Id: Integer): TMediaFile;
var C: TFDConnection; Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'select * from MediaFiles where MediaFileID=:Id';
      Q.ParamByName('Id').AsInteger := Id;
      Q.Open;
      if Q.Eof then Exit(nil);
      Result := MapMedia(Q);
    finally Q.Free; end;
  finally C.Free; end;
end;

end.

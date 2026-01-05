unit DisplayZoneRepository;

interface

uses
  System.Generics.Collections, uEntities;

type
  TDisplayZoneRepository = class
  public
    class function GetById(const Id: Integer): TDisplayZone;
    class function ListByDisplay(const DisplayId: Integer): TObjectList<TDisplayZone>;
    class function CreateZone(const Zone: TDisplayZone): TDisplayZone;
    class function UpdateZone(const Zone: TDisplayZone): TDisplayZone;
    class procedure DeleteZone(const Id: Integer);
    class procedure DeleteAllByDisplay(const DisplayId: Integer);
    class procedure AssignLayout(const DisplayId, TemplateId: Integer);
  end;

implementation

uses
  System.SysUtils,
  FireDAC.Comp.Client, FireDAC.Stan.Param,
  uServerContainer;

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

function MapZone(const Q: TFDQuery): TDisplayZone;
begin
  Result := TDisplayZone.Create;
  Result.Id := Q.FieldByName('ZoneID').AsInteger;
  Result.DisplayId := Q.FieldByName('DisplayID').AsInteger;
  Result.TemplateId := Q.FieldByName('TemplateID').AsInteger;
  Result.ZoneIdentifier := Q.FieldByName('ZoneIdentifier').AsString;
  Result.ContentType := Q.FieldByName('ContentType').AsString;
  if not Q.FieldByName('ContentID').IsNull then
    Result.ContentId := Q.FieldByName('ContentID').AsInteger;
  Result.Settings := Q.FieldByName('Settings').AsString;
  Result.CreatedAt := Q.FieldByName('CreatedAt').AsDateTime;
  Result.UpdatedAt := Q.FieldByName('UpdatedAt').AsDateTime;
end;

class function TDisplayZoneRepository.GetById(const Id: Integer): TDisplayZone;
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'SELECT * FROM DisplayZones WHERE ZoneID=:Id';
      Q.ParamByName('Id').AsInteger := Id;
      Q.Open;
      if Q.Eof then
        Exit(nil);
      Result := MapZone(Q);
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TDisplayZoneRepository.ListByDisplay(const DisplayId: Integer): TObjectList<TDisplayZone>;
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  Result := TObjectList<TDisplayZone>.Create(True);
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'SELECT * FROM DisplayZones WHERE DisplayID=:D ORDER BY ZoneIdentifier';
      Q.ParamByName('D').AsInteger := DisplayId;
      Q.Open;
      while not Q.Eof do
      begin
        Result.Add(MapZone(Q));
        Q.Next;
      end;
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TDisplayZoneRepository.CreateZone(const Zone: TDisplayZone): TDisplayZone;
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 
        'INSERT INTO DisplayZones (DisplayID, TemplateID, ZoneIdentifier, ContentType, ContentID, Settings) ' +
        'VALUES (:D, :T, :Z, :CT, :CID, :S::jsonb) RETURNING *';
      Q.ParamByName('D').AsInteger := Zone.DisplayId;
      Q.ParamByName('T').AsInteger := Zone.TemplateId;
      Q.ParamByName('Z').AsString := Zone.ZoneIdentifier;
      Q.ParamByName('CT').AsString := Zone.ContentType;
      if Zone.ContentId > 0 then
        Q.ParamByName('CID').AsInteger := Zone.ContentId
      else
        Q.ParamByName('CID').Clear;
      Q.ParamByName('S').AsString := Zone.Settings;
      Q.Open;
      Result := MapZone(Q);
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TDisplayZoneRepository.UpdateZone(const Zone: TDisplayZone): TDisplayZone;
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 
        'UPDATE DisplayZones SET ContentType=:CT, ContentID=:CID, Settings=:S::jsonb, UpdatedAt=NOW() ' +
        'WHERE ZoneID=:Id RETURNING *';
      Q.ParamByName('Id').AsInteger := Zone.Id;
      Q.ParamByName('CT').AsString := Zone.ContentType;
      if Zone.ContentId > 0 then
        Q.ParamByName('CID').AsInteger := Zone.ContentId
      else
        Q.ParamByName('CID').Clear;
      Q.ParamByName('S').AsString := Zone.Settings;
      Q.Open;
      if Q.Eof then
        Exit(nil);
      Result := MapZone(Q);
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class procedure TDisplayZoneRepository.DeleteZone(const Id: Integer);
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'DELETE FROM DisplayZones WHERE ZoneID=:Id';
      Q.ParamByName('Id').AsInteger := Id;
      Q.ExecSQL;
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class procedure TDisplayZoneRepository.DeleteAllByDisplay(const DisplayId: Integer);
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'DELETE FROM DisplayZones WHERE DisplayID=:D';
      Q.ParamByName('D').AsInteger := DisplayId;
      Q.ExecSQL;
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class procedure TDisplayZoneRepository.AssignLayout(const DisplayId, TemplateId: Integer);
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  C := NewConnection;
  try
    // First clear existing zones for this display
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'DELETE FROM DisplayZones WHERE DisplayID=:D';
      Q.ParamByName('D').AsInteger := DisplayId;
      Q.ExecSQL;
    finally
      Q.Free;
    end;
    
    // Then create zones based on the template's zone configuration
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 
        'INSERT INTO DisplayZones (DisplayID, TemplateID, ZoneIdentifier, ContentType, Settings) ' +
        'SELECT :D, :T, zone_key, ''none'', ''{}'' ' +
        'FROM LayoutTemplates, jsonb_object_keys(ZoneConfig) AS zone_key ' +
        'WHERE TemplateID=:T';
      Q.ParamByName('D').AsInteger := DisplayId;
      Q.ParamByName('T').AsInteger := TemplateId;
      Q.ExecSQL;
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

end.

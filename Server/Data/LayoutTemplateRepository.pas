unit LayoutTemplateRepository;

interface

uses
  System.Generics.Collections, uEntities;

type
  TLayoutTemplateRepository = class
  public
    class function GetById(const Id: Integer): TLayoutTemplate;
    class function ListAll: TObjectList<TLayoutTemplate>;
    class function ListByOrganization(const OrganizationId: Integer): TObjectList<TLayoutTemplate>;
    class function ListSystemTemplates: TObjectList<TLayoutTemplate>;
    class function CreateTemplate(const Template: TLayoutTemplate): TLayoutTemplate;
    class function UpdateTemplate(const Template: TLayoutTemplate): TLayoutTemplate;
    class procedure DeleteTemplate(const Id: Integer);
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

function MapTemplate(const Q: TFDQuery): TLayoutTemplate;
begin
  Result := TLayoutTemplate.Create;
  Result.Id := Q.FieldByName('LayoutTemplateID').AsInteger;
  if not Q.FieldByName('OrganizationID').IsNull then
    Result.OrganizationId := Q.FieldByName('OrganizationID').AsInteger;
  Result.Name := Q.FieldByName('Name').AsString;
  Result.Description := Q.FieldByName('Description').AsString;
  Result.IsSystemTemplate := Q.FieldByName('IsSystemTemplate').AsBoolean;
  Result.ZonesConfig := Q.FieldByName('ZonesConfig').AsString;
  Result.Orientation := Q.FieldByName('Orientation').AsString;
  Result.PreviewImageUrl := Q.FieldByName('PreviewImageUrl').AsString;
  Result.CreatedAt := Q.FieldByName('CreatedAt').AsDateTime;
  Result.UpdatedAt := Q.FieldByName('UpdatedAt').AsDateTime;
end;

class function TLayoutTemplateRepository.GetById(const Id: Integer): TLayoutTemplate;
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'SELECT * FROM LayoutTemplates WHERE LayoutTemplateID=:Id';
      Q.ParamByName('Id').AsInteger := Id;
      Q.Open;
      if Q.Eof then
        Exit(nil);
      Result := MapTemplate(Q);
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TLayoutTemplateRepository.ListAll: TObjectList<TLayoutTemplate>;
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  Result := TObjectList<TLayoutTemplate>.Create(True);
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'SELECT * FROM LayoutTemplates ORDER BY IsSystemTemplate DESC, Name ASC';
      Q.Open;
      while not Q.Eof do
      begin
        Result.Add(MapTemplate(Q));
        Q.Next;
      end;
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TLayoutTemplateRepository.ListByOrganization(const OrganizationId: Integer): TObjectList<TLayoutTemplate>;
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  Result := TObjectList<TLayoutTemplate>.Create(True);
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'SELECT * FROM LayoutTemplates WHERE OrganizationID=:O OR IsSystemTemplate=true ORDER BY IsSystemTemplate DESC, Name ASC';
      Q.ParamByName('O').AsInteger := OrganizationId;
      Q.Open;
      while not Q.Eof do
      begin
        Result.Add(MapTemplate(Q));
        Q.Next;
      end;
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TLayoutTemplateRepository.ListSystemTemplates: TObjectList<TLayoutTemplate>;
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  Result := TObjectList<TLayoutTemplate>.Create(True);
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'SELECT * FROM LayoutTemplates WHERE IsSystemTemplate=true ORDER BY Name ASC';
      Q.Open;
      while not Q.Eof do
      begin
        Result.Add(MapTemplate(Q));
        Q.Next;
      end;
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TLayoutTemplateRepository.CreateTemplate(const Template: TLayoutTemplate): TLayoutTemplate;
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
        'INSERT INTO LayoutTemplates (OrganizationID, Name, Description, IsSystemTemplate, ZonesConfig, Orientation, PreviewImageUrl) ' +
        'VALUES (:O, :N, :D, :S, :Z::jsonb, :OR, :P) RETURNING *';
      if Template.OrganizationId > 0 then
        Q.ParamByName('O').AsInteger := Template.OrganizationId
      else
        Q.ParamByName('O').Clear;
      Q.ParamByName('N').AsString := Template.Name;
      Q.ParamByName('D').AsString := Template.Description;
      Q.ParamByName('S').AsBoolean := Template.IsSystemTemplate;
      Q.ParamByName('Z').AsString := Template.ZonesConfig;
      Q.ParamByName('OR').AsString := Template.Orientation;
      Q.ParamByName('P').AsString := Template.PreviewImageUrl;
      Q.Open;
      Result := MapTemplate(Q);
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TLayoutTemplateRepository.UpdateTemplate(const Template: TLayoutTemplate): TLayoutTemplate;
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
        'UPDATE LayoutTemplates SET Name=:N, Description=:D, ZonesConfig=:Z::jsonb, Orientation=:OR, ' +
        'PreviewImageUrl=:P, UpdatedAt=NOW() WHERE LayoutTemplateID=:Id RETURNING *';
      Q.ParamByName('Id').AsInteger := Template.Id;
      Q.ParamByName('N').AsString := Template.Name;
      Q.ParamByName('D').AsString := Template.Description;
      Q.ParamByName('Z').AsString := Template.ZonesConfig;
      Q.ParamByName('OR').AsString := Template.Orientation;
      Q.ParamByName('P').AsString := Template.PreviewImageUrl;
      Q.Open;
      if Q.Eof then
        Exit(nil);
      Result := MapTemplate(Q);
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class procedure TLayoutTemplateRepository.DeleteTemplate(const Id: Integer);
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'DELETE FROM LayoutTemplates WHERE LayoutTemplateID=:Id AND IsSystemTemplate=false';
      Q.ParamByName('Id').AsInteger := Id;
      Q.ExecSQL;
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

end.

unit ContentTemplateRepository;

interface

uses
  System.Generics.Collections, uEntities;

type
  TContentTemplateRepository = class
  public
    class function GetById(const Id: Integer): TContentTemplate;
    class function ListPublic(const Category: string = ''; const TemplateType: string = ''): TObjectList<TContentTemplate>;
    class function ListByOrganization(const OrganizationId: Integer; const Category: string = ''; const TemplateType: string = ''): TObjectList<TContentTemplate>;
    class function ListByCategory(const Category: string): TObjectList<TContentTemplate>;
    class function CreateTemplate(const Template: TContentTemplate): TContentTemplate;
    class function UpdateTemplate(const Template: TContentTemplate): TContentTemplate;
    class procedure IncrementUsage(const Id: Integer);
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

function MapTemplate(const Q: TFDQuery): TContentTemplate;
begin
  Result := TContentTemplate.Create;
  Result.Id := Q.FieldByName('TemplateID').AsInteger;
  if not Q.FieldByName('OrganizationID').IsNull then
    Result.OrganizationId := Q.FieldByName('OrganizationID').AsInteger;
  Result.Name := Q.FieldByName('Name').AsString;
  Result.Description := Q.FieldByName('Description').AsString;
  Result.Category := Q.FieldByName('Category').AsString;
  Result.TemplateType := Q.FieldByName('TemplateType').AsString;
  Result.ThumbnailUrl := Q.FieldByName('ThumbnailUrl').AsString;
  Result.TemplateData := Q.FieldByName('TemplateData').AsString;
  Result.Tags := Q.FieldByName('Tags').AsString;
  Result.IsPublic := Q.FieldByName('IsPublic').AsBoolean;
  Result.IsSystemTemplate := Q.FieldByName('IsSystemTemplate').AsBoolean;
  Result.UsageCount := Q.FieldByName('UsageCount').AsInteger;
  if not Q.FieldByName('Rating').IsNull then
    Result.Rating := Q.FieldByName('Rating').AsFloat;
  Result.CreatedAt := Q.FieldByName('CreatedAt').AsDateTime;
  Result.UpdatedAt := Q.FieldByName('UpdatedAt').AsDateTime;
end;

class function TContentTemplateRepository.GetById(const Id: Integer): TContentTemplate;
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'SELECT * FROM ContentTemplates WHERE TemplateID=:Id';
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

class function TContentTemplateRepository.ListPublic(const Category: string; const TemplateType: string): TObjectList<TContentTemplate>;
var
  C: TFDConnection;
  Q: TFDQuery;
  SQL: string;
begin
  Result := TObjectList<TContentTemplate>.Create(True);
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      SQL := 'SELECT * FROM ContentTemplates WHERE (IsPublic=true OR IsSystemTemplate=true)';
      if Category <> '' then
        SQL := SQL + ' AND Category=:Cat';
      if TemplateType <> '' then
        SQL := SQL + ' AND TemplateType=:TT';
      SQL := SQL + ' ORDER BY IsSystemTemplate DESC, UsageCount DESC, Name ASC';
      Q.SQL.Text := SQL;
      if Category <> '' then
        Q.ParamByName('Cat').AsString := Category;
      if TemplateType <> '' then
        Q.ParamByName('TT').AsString := TemplateType;
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

class function TContentTemplateRepository.ListByOrganization(const OrganizationId: Integer; const Category: string = ''; const TemplateType: string = ''): TObjectList<TContentTemplate>;
var
  C: TFDConnection;
  Q: TFDQuery;
  SQL: string;
begin
  Result := TObjectList<TContentTemplate>.Create(True);
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      SQL := 'SELECT * FROM ContentTemplates WHERE (OrganizationID=:O OR IsPublic=true OR IsSystemTemplate=true)';
      if Category <> '' then
        SQL := SQL + ' AND Category=:C';
      if TemplateType <> '' then
        SQL := SQL + ' AND TemplateType=:T';
      SQL := SQL + ' ORDER BY Name ASC';
      Q.SQL.Text := SQL;
      Q.ParamByName('O').AsInteger := OrganizationId;
      if Category <> '' then
        Q.ParamByName('C').AsString := Category;
      if TemplateType <> '' then
        Q.ParamByName('T').AsString := TemplateType;
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

class function TContentTemplateRepository.ListByCategory(const Category: string): TObjectList<TContentTemplate>;
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  Result := TObjectList<TContentTemplate>.Create(True);
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'SELECT * FROM ContentTemplates WHERE Category=:C AND (IsPublic=true OR IsSystemTemplate=true) ORDER BY UsageCount DESC, Name ASC';
      Q.ParamByName('C').AsString := Category;
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

class function TContentTemplateRepository.CreateTemplate(const Template: TContentTemplate): TContentTemplate;
var
  C: TFDConnection;
  Q: TFDQuery;
  TagsJson: string;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 
        'INSERT INTO ContentTemplates (OrganizationID, Name, Description, Category, TemplateType, ' +
        'ThumbnailUrl, TemplateData, Tags, IsPublic, IsSystemTemplate) ' +
        'VALUES (:O, :N, :D, :C, :TT, :TH, :TD::jsonb, :TG::jsonb, :P, :S) RETURNING *';
      if Template.OrganizationId > 0 then
        Q.ParamByName('O').AsInteger := Template.OrganizationId
      else
        Q.ParamByName('O').Clear;
      Q.ParamByName('N').AsString := Template.Name;
      Q.ParamByName('D').AsString := Template.Description;
      Q.ParamByName('C').AsString := Template.Category;
      Q.ParamByName('TT').AsString := Template.TemplateType;
      Q.ParamByName('TH').AsString := Template.ThumbnailUrl;
      if (Template.TemplateData = '') then
        Q.ParamByName('TD').AsString := '{}'
      else
        Q.ParamByName('TD').AsString := Template.TemplateData;
      // Ensure Tags is valid JSON - empty string fails jsonb cast
      TagsJson := Trim(Template.Tags);
      if (TagsJson = '') then TagsJson := '[]';
      Q.ParamByName('TG').AsString := TagsJson;
      Q.ParamByName('P').AsBoolean := Template.IsPublic;
      Q.ParamByName('S').AsBoolean := Template.IsSystemTemplate;
      Q.Open;
      Result := MapTemplate(Q);
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TContentTemplateRepository.UpdateTemplate(const Template: TContentTemplate): TContentTemplate;
var
  C: TFDConnection;
  Q: TFDQuery;
  TagsJson, DataJson: string;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 
        'UPDATE ContentTemplates SET Name=:N, Description=:D, Category=:C, TemplateType=:TT, ' +
        'ThumbnailUrl=:TH, TemplateData=:TD::jsonb, Tags=:TG::jsonb, IsPublic=:P, UpdatedAt=NOW() ' +
        'WHERE TemplateID=:Id RETURNING *';
      Q.ParamByName('Id').AsInteger := Template.Id;
      Q.ParamByName('N').AsString := Template.Name;
      Q.ParamByName('D').AsString := Template.Description;
      Q.ParamByName('C').AsString := Template.Category;
      Q.ParamByName('TT').AsString := Template.TemplateType;
      Q.ParamByName('TH').AsString := Template.ThumbnailUrl;
      // Ensure TemplateData is valid JSON
      DataJson := Trim(Template.TemplateData);
      if DataJson = '' then DataJson := '{}';
      Q.ParamByName('TD').AsString := DataJson;
      // Ensure Tags is valid JSON
      TagsJson := Trim(Template.Tags);
      if TagsJson = '' then TagsJson := '[]';
      Q.ParamByName('TG').AsString := TagsJson;
      Q.ParamByName('P').AsBoolean := Template.IsPublic;
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

class procedure TContentTemplateRepository.IncrementUsage(const Id: Integer);
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'UPDATE ContentTemplates SET UsageCount=UsageCount+1 WHERE TemplateID=:Id';
      Q.ParamByName('Id').AsInteger := Id;
      Q.ExecSQL;
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class procedure TContentTemplateRepository.DeleteTemplate(const Id: Integer);
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'DELETE FROM ContentTemplates WHERE TemplateID=:Id AND IsSystemTemplate=false';
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

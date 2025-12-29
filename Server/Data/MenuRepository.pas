unit MenuRepository;

interface

uses System.Generics.Collections, uEntities;

type
  TMenu = class
  private
    FId: Integer;
    FOrganizationId: Integer;
    FName: string;
    FOrientation: string;
    FTemplateKey: string;
    FThemeConfigJson: string;
    FPublicToken: string;
    FCreatedAt: TDateTime;
    FUpdatedAt: TDateTime;
  public
    property Id: Integer read FId write FId;
    property OrganizationId: Integer read FOrganizationId write FOrganizationId;
    property Name: string read FName write FName;
    property Orientation: string read FOrientation write FOrientation;
    property TemplateKey: string read FTemplateKey write FTemplateKey;
    property ThemeConfigJson: string read FThemeConfigJson write FThemeConfigJson;
    property PublicToken: string read FPublicToken write FPublicToken;
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
    property UpdatedAt: TDateTime read FUpdatedAt write FUpdatedAt;
  end;

  TMenuRepository = class
  public
    class function GetById(const Id: Integer): TMenu;
    class function GetByPublicToken(const Token: string): TMenu;
    class function ListByOrganization(const OrgId: Integer): TObjectList<TMenu>;
    class function CreateMenu(const OrgId: Integer; const Name, Orientation, TemplateKey, ThemeConfigJson, PublicToken: string): TMenu;
    class function UpdateMenu(const Id: Integer; const Name, Orientation, TemplateKey, ThemeConfigJson: string): TMenu;
    class procedure DeleteMenu(const Id: Integer);
  end;

implementation

uses System.SysUtils, FireDAC.Comp.Client, FireDAC.Stan.Param, uServerContainer;

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

function MapMenu(const Q: TFDQuery): TMenu;
begin
  Result := TMenu.Create;
  Result.Id := Q.FieldByName('MenuID').AsInteger;
  Result.OrganizationId := Q.FieldByName('OrganizationID').AsInteger;
  Result.Name := Q.FieldByName('Name').AsString;
  Result.Orientation := Q.FieldByName('Orientation').AsString;
  Result.TemplateKey := Q.FieldByName('TemplateKey').AsString;
  Result.ThemeConfigJson := Q.FieldByName('ThemeConfig').AsString;
  Result.PublicToken := Q.FieldByName('PublicToken').AsString;
  Result.CreatedAt := Q.FieldByName('CreatedAt').AsDateTime;
  Result.UpdatedAt := Q.FieldByName('UpdatedAt').AsDateTime;
end;

class function TMenuRepository.GetById(const Id: Integer): TMenu;
var C: TFDConnection; Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'select * from Menus where MenuID=:Id';
      Q.ParamByName('Id').AsInteger := Id;
      Q.Open;
      if Q.Eof then Exit(nil);
      Result := MapMenu(Q);
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TMenuRepository.GetByPublicToken(const Token: string): TMenu;
var C: TFDConnection; Q: TFDQuery;
begin
  Result := nil;
  if Trim(Token) = '' then Exit(nil);

  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'select * from Menus where PublicToken=:T';
      Q.ParamByName('T').AsString := Token;
      Q.Open;
      if Q.Eof then Exit(nil);
      Result := MapMenu(Q);
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TMenuRepository.ListByOrganization(const OrgId: Integer): TObjectList<TMenu>;
var C: TFDConnection; Q: TFDQuery;
begin
  Result := TObjectList<TMenu>.Create(True);
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'select * from Menus where OrganizationID=:Org order by MenuID';
      Q.ParamByName('Org').AsInteger := OrgId;
      Q.Open;
      while not Q.Eof do
      begin
        Result.Add(MapMenu(Q));
        Q.Next;
      end;
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TMenuRepository.CreateMenu(const OrgId: Integer; const Name, Orientation, TemplateKey, ThemeConfigJson, PublicToken: string): TMenu;
var C: TFDConnection; Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'insert into Menus (OrganizationID, Name, Orientation, TemplateKey, ThemeConfig, PublicToken) '
                  + 'values (:Org,:Name,:Orient,:Tpl,:Theme::jsonb,:Tok) returning *';
      Q.ParamByName('Org').AsInteger := OrgId;
      Q.ParamByName('Name').AsString := Name;
      Q.ParamByName('Orient').AsString := Orientation;
      Q.ParamByName('Tpl').AsString := TemplateKey;
      if Trim(ThemeConfigJson) <> '' then
        Q.ParamByName('Theme').AsString := ThemeConfigJson
      else
        Q.ParamByName('Theme').AsString := '{}';
      Q.ParamByName('Tok').AsString := PublicToken;
      Q.Open;
      Result := MapMenu(Q);
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TMenuRepository.UpdateMenu(const Id: Integer; const Name, Orientation, TemplateKey, ThemeConfigJson: string): TMenu;
var C: TFDConnection; Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'update Menus set Name=:Name, Orientation=:Orient, TemplateKey=:Tpl, ThemeConfig=:Theme::jsonb, UpdatedAt=now() '
                  + 'where MenuID=:Id returning *';
      Q.ParamByName('Id').AsInteger := Id;
      Q.ParamByName('Name').AsString := Name;
      Q.ParamByName('Orient').AsString := Orientation;
      Q.ParamByName('Tpl').AsString := TemplateKey;
      if Trim(ThemeConfigJson) <> '' then
        Q.ParamByName('Theme').AsString := ThemeConfigJson
      else
        Q.ParamByName('Theme').AsString := '{}';
      Q.Open;
      if Q.Eof then Exit(nil);
      Result := MapMenu(Q);
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class procedure TMenuRepository.DeleteMenu(const Id: Integer);
var C: TFDConnection; Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'delete from Menus where MenuID=:Id';
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

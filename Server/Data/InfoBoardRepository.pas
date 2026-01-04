unit InfoBoardRepository;

interface

uses System.Generics.Collections, uEntities;

type
  TInfoBoard = class
  private
    FId: Integer;
    FOrganizationId: Integer;
    FName: string;
    FBoardType: string;
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
    property BoardType: string read FBoardType write FBoardType;
    property Orientation: string read FOrientation write FOrientation;
    property TemplateKey: string read FTemplateKey write FTemplateKey;
    property ThemeConfigJson: string read FThemeConfigJson write FThemeConfigJson;
    property PublicToken: string read FPublicToken write FPublicToken;
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
    property UpdatedAt: TDateTime read FUpdatedAt write FUpdatedAt;
  end;

  TInfoBoardRepository = class
  public
    class function GetById(const Id: Integer): TInfoBoard;
    class function GetByPublicToken(const Token: string): TInfoBoard;
    class function ListByOrganization(const OrgId: Integer): TObjectList<TInfoBoard>;
    class function CreateInfoBoard(const OrgId: Integer; const Name, BoardType, Orientation, TemplateKey, ThemeConfigJson, PublicToken: string): TInfoBoard;
    class function UpdateInfoBoard(const Id: Integer; const Name, BoardType, Orientation, TemplateKey, ThemeConfigJson: string): TInfoBoard;
    class procedure DeleteInfoBoard(const Id: Integer);
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

function MapInfoBoard(const Q: TFDQuery): TInfoBoard;
begin
  Result := TInfoBoard.Create;
  Result.Id := Q.FieldByName('InfoBoardID').AsInteger;
  Result.OrganizationId := Q.FieldByName('OrganizationID').AsInteger;
  Result.Name := Q.FieldByName('Name').AsString;
  Result.BoardType := Q.FieldByName('BoardType').AsString;
  Result.Orientation := Q.FieldByName('Orientation').AsString;
  Result.TemplateKey := Q.FieldByName('TemplateKey').AsString;
  Result.ThemeConfigJson := Q.FieldByName('ThemeConfig').AsString;
  Result.PublicToken := Q.FieldByName('PublicToken').AsString;
  Result.CreatedAt := Q.FieldByName('CreatedAt').AsDateTime;
  Result.UpdatedAt := Q.FieldByName('UpdatedAt').AsDateTime;
end;

class function TInfoBoardRepository.GetById(const Id: Integer): TInfoBoard;
var C: TFDConnection; Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'select * from InfoBoards where InfoBoardID=:Id';
      Q.ParamByName('Id').AsInteger := Id;
      Q.Open;
      if Q.Eof then Exit(nil);
      Result := MapInfoBoard(Q);
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TInfoBoardRepository.GetByPublicToken(const Token: string): TInfoBoard;
var C: TFDConnection; Q: TFDQuery;
begin
  Result := nil;
  if Trim(Token) = '' then Exit(nil);

  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'select * from InfoBoards where PublicToken=:T';
      Q.ParamByName('T').AsString := Token;
      Q.Open;
      if Q.Eof then Exit(nil);
      Result := MapInfoBoard(Q);
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TInfoBoardRepository.ListByOrganization(const OrgId: Integer): TObjectList<TInfoBoard>;
var C: TFDConnection; Q: TFDQuery;
begin
  Result := TObjectList<TInfoBoard>.Create(True);
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'select * from InfoBoards where OrganizationID=:Org order by InfoBoardID';
      Q.ParamByName('Org').AsInteger := OrgId;
      Q.Open;
      while not Q.Eof do
      begin
        Result.Add(MapInfoBoard(Q));
        Q.Next;
      end;
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TInfoBoardRepository.CreateInfoBoard(const OrgId: Integer; const Name, BoardType, Orientation, TemplateKey, ThemeConfigJson, PublicToken: string): TInfoBoard;
var C: TFDConnection; Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'insert into InfoBoards (OrganizationID, Name, BoardType, Orientation, TemplateKey, ThemeConfig, PublicToken) '
                  + 'values (:Org,:Name,:BType,:Orient,:Tpl,:Theme::jsonb,:Tok) returning *';
      Q.ParamByName('Org').AsInteger := OrgId;
      Q.ParamByName('Name').AsString := Name;
      Q.ParamByName('BType').AsString := BoardType;
      Q.ParamByName('Orient').AsString := Orientation;
      Q.ParamByName('Tpl').AsString := TemplateKey;
      if Trim(ThemeConfigJson) <> '' then
        Q.ParamByName('Theme').AsString := ThemeConfigJson
      else
        Q.ParamByName('Theme').AsString := '{}';
      Q.ParamByName('Tok').AsString := PublicToken;
      Q.Open;
      Result := MapInfoBoard(Q);
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TInfoBoardRepository.UpdateInfoBoard(const Id: Integer; const Name, BoardType, Orientation, TemplateKey, ThemeConfigJson: string): TInfoBoard;
var C: TFDConnection; Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'update InfoBoards set Name=:Name, BoardType=:BType, Orientation=:Orient, TemplateKey=:Tpl, ThemeConfig=:Theme::jsonb, UpdatedAt=now() '
                  + 'where InfoBoardID=:Id returning *';
      Q.ParamByName('Id').AsInteger := Id;
      Q.ParamByName('Name').AsString := Name;
      Q.ParamByName('BType').AsString := BoardType;
      Q.ParamByName('Orient').AsString := Orientation;
      Q.ParamByName('Tpl').AsString := TemplateKey;
      if Trim(ThemeConfigJson) <> '' then
        Q.ParamByName('Theme').AsString := ThemeConfigJson
      else
        Q.ParamByName('Theme').AsString := '{}';
      Q.Open;
      if Q.Eof then Exit(nil);
      Result := MapInfoBoard(Q);
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class procedure TInfoBoardRepository.DeleteInfoBoard(const Id: Integer);
var C: TFDConnection; Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'delete from InfoBoards where InfoBoardID=:Id';
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

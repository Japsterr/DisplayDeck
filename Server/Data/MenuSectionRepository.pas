unit MenuSectionRepository;

interface

uses System.Generics.Collections;

type
  TMenuSection = class
  private
    FId: Integer;
    FMenuId: Integer;
    FName: string;
    FDisplayOrder: Integer;
    FCreatedAt: TDateTime;
    FUpdatedAt: TDateTime;
  public
    property Id: Integer read FId write FId;
    property MenuId: Integer read FMenuId write FMenuId;
    property Name: string read FName write FName;
    property DisplayOrder: Integer read FDisplayOrder write FDisplayOrder;
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
    property UpdatedAt: TDateTime read FUpdatedAt write FUpdatedAt;
  end;

  TMenuSectionRepository = class
  public
    class function GetById(const Id: Integer): TMenuSection;
    class function ListByMenu(const MenuId: Integer): TObjectList<TMenuSection>;
    class function CreateSection(const MenuId: Integer; const Name: string; const DisplayOrder: Integer): TMenuSection;
    class function UpdateSection(const Id: Integer; const Name: string; const DisplayOrder: Integer): TMenuSection;
    class procedure DeleteSection(const Id: Integer);
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

function MapSection(const Q: TFDQuery): TMenuSection;
begin
  Result := TMenuSection.Create;
  Result.Id := Q.FieldByName('MenuSectionID').AsInteger;
  Result.MenuId := Q.FieldByName('MenuID').AsInteger;
  Result.Name := Q.FieldByName('Name').AsString;
  Result.DisplayOrder := Q.FieldByName('DisplayOrder').AsInteger;
  Result.CreatedAt := Q.FieldByName('CreatedAt').AsDateTime;
  Result.UpdatedAt := Q.FieldByName('UpdatedAt').AsDateTime;
end;

class function TMenuSectionRepository.GetById(const Id: Integer): TMenuSection;
var C: TFDConnection; Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'select * from MenuSections where MenuSectionID=:Id';
      Q.ParamByName('Id').AsInteger := Id;
      Q.Open;
      if Q.Eof then Exit(nil);
      Result := MapSection(Q);
    finally Q.Free; end;
  finally C.Free; end;
end;

class function TMenuSectionRepository.ListByMenu(const MenuId: Integer): TObjectList<TMenuSection>;
var C: TFDConnection; Q: TFDQuery;
begin
  Result := TObjectList<TMenuSection>.Create(True);
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'select * from MenuSections where MenuID=:Id order by DisplayOrder, MenuSectionID';
      Q.ParamByName('Id').AsInteger := MenuId;
      Q.Open;
      while not Q.Eof do
      begin
        Result.Add(MapSection(Q));
        Q.Next;
      end;
    finally Q.Free; end;
  finally C.Free; end;
end;

class function TMenuSectionRepository.CreateSection(const MenuId: Integer; const Name: string; const DisplayOrder: Integer): TMenuSection;
var C: TFDConnection; Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'insert into MenuSections (MenuID, Name, DisplayOrder) values (:M,:Name,:O) returning *';
      Q.ParamByName('M').AsInteger := MenuId;
      Q.ParamByName('Name').AsString := Name;
      Q.ParamByName('O').AsInteger := DisplayOrder;
      Q.Open;
      Result := MapSection(Q);
    finally Q.Free; end;
  finally C.Free; end;
end;

class function TMenuSectionRepository.UpdateSection(const Id: Integer; const Name: string; const DisplayOrder: Integer): TMenuSection;
var C: TFDConnection; Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'update MenuSections set Name=:Name, DisplayOrder=:O, UpdatedAt=now() where MenuSectionID=:Id returning *';
      Q.ParamByName('Id').AsInteger := Id;
      Q.ParamByName('Name').AsString := Name;
      Q.ParamByName('O').AsInteger := DisplayOrder;
      Q.Open;
      if Q.Eof then Exit(nil);
      Result := MapSection(Q);
    finally Q.Free; end;
  finally C.Free; end;
end;

class procedure TMenuSectionRepository.DeleteSection(const Id: Integer);
var C: TFDConnection; Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'delete from MenuSections where MenuSectionID=:Id';
      Q.ParamByName('Id').AsInteger := Id;
      Q.ExecSQL;
    finally Q.Free; end;
  finally C.Free; end;
end;

end.

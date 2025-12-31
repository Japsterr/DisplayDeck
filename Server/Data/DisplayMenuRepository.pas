unit DisplayMenuRepository;

interface

uses System.Generics.Collections, uEntities;

type
  TDisplayMenuRepository = class
  public
    class function ListByDisplay(const DisplayId: Integer): TObjectList<TDisplayMenu>;
    class function GetById(const Id: Integer): TDisplayMenu;
    class function CreateAssignment(const DisplayId, MenuId: Integer; const IsPrimary: Boolean): TDisplayMenu;
    class function UpdateAssignment(const Id: Integer; const IsPrimary: Boolean): TDisplayMenu;
    class procedure DeleteAssignment(const Id: Integer);
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

function MapDisplayMenu(const Q: TFDQuery): TDisplayMenu;
begin
  Result := TDisplayMenu.Create;
  Result.Id := Q.FieldByName('DisplayMenuID').AsInteger;
  Result.DisplayId := Q.FieldByName('DisplayID').AsInteger;
  Result.MenuId := Q.FieldByName('MenuID').AsInteger;
  Result.IsPrimary := Q.FieldByName('IsPrimary').AsBoolean;
end;

class function TDisplayMenuRepository.ListByDisplay(const DisplayId: Integer): TObjectList<TDisplayMenu>;
var C: TFDConnection; Q: TFDQuery;
begin
  Result := TObjectList<TDisplayMenu>.Create(True);
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'select * from DisplayMenus where DisplayID=:Id order by DisplayMenuID';
      Q.ParamByName('Id').AsInteger := DisplayId;
      Q.Open;
      while not Q.Eof do
      begin
        Result.Add(MapDisplayMenu(Q));
        Q.Next;
      end;
    finally Q.Free; end;
  finally C.Free; end;
end;

class function TDisplayMenuRepository.GetById(const Id: Integer): TDisplayMenu;
var C: TFDConnection; Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'select * from DisplayMenus where DisplayMenuID=:Id';
      Q.ParamByName('Id').AsInteger := Id;
      Q.Open;
      if Q.Eof then Exit(nil);
      Result := MapDisplayMenu(Q);
    finally Q.Free; end;
  finally C.Free; end;
end;

class function TDisplayMenuRepository.CreateAssignment(const DisplayId, MenuId: Integer; const IsPrimary: Boolean): TDisplayMenu;
var C: TFDConnection; Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'insert into DisplayMenus (DisplayID, MenuID, IsPrimary) values (:D,:M,:P) returning *';
      Q.ParamByName('D').AsInteger := DisplayId;
      Q.ParamByName('M').AsInteger := MenuId;
      Q.ParamByName('P').AsBoolean := IsPrimary;
      Q.Open;
      Result := MapDisplayMenu(Q);
    finally Q.Free; end;
  finally C.Free; end;
end;

class function TDisplayMenuRepository.UpdateAssignment(const Id: Integer; const IsPrimary: Boolean): TDisplayMenu;
var C: TFDConnection; Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'update DisplayMenus set IsPrimary=:P where DisplayMenuID=:Id returning *';
      Q.ParamByName('Id').AsInteger := Id;
      Q.ParamByName('P').AsBoolean := IsPrimary;
      Q.Open;
      if Q.Eof then Exit(nil);
      Result := MapDisplayMenu(Q);
    finally Q.Free; end;
  finally C.Free; end;
end;

class procedure TDisplayMenuRepository.DeleteAssignment(const Id: Integer);
var C: TFDConnection; Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'delete from DisplayMenus where DisplayMenuID=:Id';
      Q.ParamByName('Id').AsInteger := Id;
      Q.ExecSQL;
    finally Q.Free; end;
  finally C.Free; end;
end;

end.

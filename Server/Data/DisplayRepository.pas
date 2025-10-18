unit DisplayRepository;

interface

uses System.Generics.Collections, uEntities;

type
  TDisplayRepository = class
  public
    class function GetById(const Id: Integer): TDisplay;
    class function ListByOrganization(const OrgId: Integer): TObjectList<TDisplay>;
    class function CreateDisplay(const OrgId: Integer; const Name, Orientation: string): TDisplay;
    class function UpdateDisplay(const Id: Integer; const Name, Orientation: string): TDisplay;
    class procedure DeleteDisplay(const Id: Integer);
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

function MapDisplay(const Q: TFDQuery): TDisplay;
begin
  Result := TDisplay.Create;
  Result.Id := Q.FieldByName('DisplayID').AsInteger;
  Result.OrganizationId := Q.FieldByName('OrganizationID').AsInteger;
  Result.Name := Q.FieldByName('Name').AsString;
  Result.Orientation := Q.FieldByName('Orientation').AsString;
  Result.LastSeen := Q.FieldByName('LastSeen').AsDateTime;
  Result.CurrentStatus := Q.FieldByName('CurrentStatus').AsString;
  Result.ProvisioningToken := Q.FieldByName('ProvisioningToken').AsString;
  Result.CreatedAt := Q.FieldByName('CreatedAt').AsDateTime;
  Result.UpdatedAt := Q.FieldByName('UpdatedAt').AsDateTime;
end;

class function TDisplayRepository.GetById(const Id: Integer): TDisplay;
var C: TFDConnection; Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'select * from Displays where DisplayID=:Id';
      Q.ParamByName('Id').AsInteger := Id;
      Q.Open;
      if Q.Eof then Exit(nil);
      Result := MapDisplay(Q);
    finally Q.Free; end;
  finally C.Free; end;
end;

class function TDisplayRepository.ListByOrganization(const OrgId: Integer): TObjectList<TDisplay>;
var C: TFDConnection; Q: TFDQuery;
begin
  Result := TObjectList<TDisplay>.Create(True);
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'select * from Displays where OrganizationID=:Org order by DisplayID';
      Q.ParamByName('Org').AsInteger := OrgId;
      Q.Open;
      while not Q.Eof do
      begin
        Result.Add(MapDisplay(Q));
        Q.Next;
      end;
    finally Q.Free; end;
  finally C.Free; end;
end;

class function TDisplayRepository.CreateDisplay(const OrgId: Integer; const Name, Orientation: string): TDisplay;
var C: TFDConnection; Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'insert into Displays (OrganizationID, Name, Orientation) values (:Org,:Name,:Orient) returning *';
      Q.ParamByName('Org').AsInteger := OrgId;
      Q.ParamByName('Name').AsString := Name;
      Q.ParamByName('Orient').AsString := Orientation;
      Q.Open;
      Result := MapDisplay(Q);
    finally Q.Free; end;
  finally C.Free; end;
end;

class function TDisplayRepository.UpdateDisplay(const Id: Integer; const Name, Orientation: string): TDisplay;
var C: TFDConnection; Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'update Displays set Name=:Name, Orientation=:Orient, UpdatedAt=now() where DisplayID=:Id returning *';
      Q.ParamByName('Id').AsInteger := Id;
      Q.ParamByName('Name').AsString := Name;
      Q.ParamByName('Orient').AsString := Orientation;
      Q.Open;
      if Q.Eof then Exit(nil);
      Result := MapDisplay(Q);
    finally Q.Free; end;
  finally C.Free; end;
end;

class procedure TDisplayRepository.DeleteDisplay(const Id: Integer);
var C: TFDConnection; Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'delete from Displays where DisplayID=:Id';
      Q.ParamByName('Id').AsInteger := Id;
      Q.ExecSQL;
    finally Q.Free; end;
  finally C.Free; end;
end;

end.

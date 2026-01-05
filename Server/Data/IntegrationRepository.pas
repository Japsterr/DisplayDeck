unit IntegrationRepository;

interface

uses
  System.Generics.Collections, uEntities;

type
  TIntegrationRepository = class
  public
    class function GetById(const Id: Integer): TIntegrationConnection;
    class function ListByOrganization(const OrganizationId: Integer): TObjectList<TIntegrationConnection>;
    class function ListByType(const OrganizationId: Integer; const IntegrationType: string): TObjectList<TIntegrationConnection>;
    class function CreateConnection(const Conn: TIntegrationConnection): TIntegrationConnection;
    class function UpdateConnection(const Conn: TIntegrationConnection): TIntegrationConnection;
    class function UpdateSyncStatus(const Id: Integer; const Status: string; const Error: string): TIntegrationConnection;
    class procedure DeleteConnection(const Id: Integer);
    // Integration data cache
    class function GetCachedData(const ConnectionId: Integer; const DataKey: string): string;
    class procedure SetCachedData(const ConnectionId: Integer; const DataKey: string; const DataValue: string; const ExpiresAt: TDateTime);
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

function MapConnection(const Q: TFDQuery): TIntegrationConnection;
begin
  Result := TIntegrationConnection.Create;
  Result.Id := Q.FieldByName('ConnectionID').AsInteger;
  Result.OrganizationId := Q.FieldByName('OrganizationID').AsInteger;
  Result.IntegrationType := Q.FieldByName('IntegrationType').AsString;
  Result.Name := Q.FieldByName('Name').AsString;
  Result.Config := Q.FieldByName('Config').AsString;
  Result.IsActive := Q.FieldByName('IsActive').AsBoolean;
  Result.HasLastSyncAt := not Q.FieldByName('LastSyncAt').IsNull;
  if Result.HasLastSyncAt then
    Result.LastSyncAt := Q.FieldByName('LastSyncAt').AsDateTime;
  Result.LastSyncStatus := Q.FieldByName('LastSyncStatus').AsString;
  Result.LastSyncError := Q.FieldByName('LastSyncError').AsString;
  Result.CreatedAt := Q.FieldByName('CreatedAt').AsDateTime;
  Result.UpdatedAt := Q.FieldByName('UpdatedAt').AsDateTime;
end;

class function TIntegrationRepository.GetById(const Id: Integer): TIntegrationConnection;
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'SELECT * FROM IntegrationConnections WHERE ConnectionID=:Id';
      Q.ParamByName('Id').AsInteger := Id;
      Q.Open;
      if Q.Eof then
        Exit(nil);
      Result := MapConnection(Q);
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TIntegrationRepository.ListByOrganization(const OrganizationId: Integer): TObjectList<TIntegrationConnection>;
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  Result := TObjectList<TIntegrationConnection>.Create(True);
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'SELECT * FROM IntegrationConnections WHERE OrganizationID=:O ORDER BY IntegrationType, Name';
      Q.ParamByName('O').AsInteger := OrganizationId;
      Q.Open;
      while not Q.Eof do
      begin
        Result.Add(MapConnection(Q));
        Q.Next;
      end;
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TIntegrationRepository.ListByType(const OrganizationId: Integer; const IntegrationType: string): TObjectList<TIntegrationConnection>;
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  Result := TObjectList<TIntegrationConnection>.Create(True);
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'SELECT * FROM IntegrationConnections WHERE OrganizationID=:O AND IntegrationType=:T ORDER BY Name';
      Q.ParamByName('O').AsInteger := OrganizationId;
      Q.ParamByName('T').AsString := IntegrationType;
      Q.Open;
      while not Q.Eof do
      begin
        Result.Add(MapConnection(Q));
        Q.Next;
      end;
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TIntegrationRepository.CreateConnection(const Conn: TIntegrationConnection): TIntegrationConnection;
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
        'INSERT INTO IntegrationConnections (OrganizationID, IntegrationType, Name, Config, IsActive) ' +
        'VALUES (:O, :T, :N, :C::jsonb, :A) RETURNING *';
      Q.ParamByName('O').AsInteger := Conn.OrganizationId;
      Q.ParamByName('T').AsString := Conn.IntegrationType;
      Q.ParamByName('N').AsString := Conn.Name;
      Q.ParamByName('C').AsString := Conn.Config;
      Q.ParamByName('A').AsBoolean := Conn.IsActive;
      Q.Open;
      Result := MapConnection(Q);
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TIntegrationRepository.UpdateConnection(const Conn: TIntegrationConnection): TIntegrationConnection;
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
        'UPDATE IntegrationConnections SET Name=:N, Config=:C::jsonb, IsActive=:A, UpdatedAt=NOW() ' +
        'WHERE ConnectionID=:Id RETURNING *';
      Q.ParamByName('Id').AsInteger := Conn.Id;
      Q.ParamByName('N').AsString := Conn.Name;
      Q.ParamByName('C').AsString := Conn.Config;
      Q.ParamByName('A').AsBoolean := Conn.IsActive;
      Q.Open;
      if Q.Eof then
        Exit(nil);
      Result := MapConnection(Q);
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TIntegrationRepository.UpdateSyncStatus(const Id: Integer; const Status: string; const Error: string): TIntegrationConnection;
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
        'UPDATE IntegrationConnections SET LastSyncAt=NOW(), LastSyncStatus=:S, LastSyncError=:E, UpdatedAt=NOW() ' +
        'WHERE ConnectionID=:Id RETURNING *';
      Q.ParamByName('Id').AsInteger := Id;
      Q.ParamByName('S').AsString := Status;
      Q.ParamByName('E').AsString := Error;
      Q.Open;
      if Q.Eof then
        Exit(nil);
      Result := MapConnection(Q);
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class procedure TIntegrationRepository.DeleteConnection(const Id: Integer);
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'DELETE FROM IntegrationConnections WHERE ConnectionID=:Id';
      Q.ParamByName('Id').AsInteger := Id;
      Q.ExecSQL;
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TIntegrationRepository.GetCachedData(const ConnectionId: Integer; const DataKey: string): string;
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  Result := '';
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'SELECT DataValue FROM IntegrationData WHERE ConnectionID=:C AND DataKey=:K AND (ExpiresAt IS NULL OR ExpiresAt > NOW())';
      Q.ParamByName('C').AsInteger := ConnectionId;
      Q.ParamByName('K').AsString := DataKey;
      Q.Open;
      if not Q.Eof then
        Result := Q.FieldByName('DataValue').AsString;
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class procedure TIntegrationRepository.SetCachedData(const ConnectionId: Integer; const DataKey: string; const DataValue: string; const ExpiresAt: TDateTime);
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
        'INSERT INTO IntegrationData (ConnectionID, DataKey, DataValue, ExpiresAt) ' +
        'VALUES (:C, :K, :V::jsonb, :E) ' +
        'ON CONFLICT (ConnectionID, DataKey) DO UPDATE SET DataValue=:V::jsonb, ExpiresAt=:E, UpdatedAt=NOW()';
      Q.ParamByName('C').AsInteger := ConnectionId;
      Q.ParamByName('K').AsString := DataKey;
      Q.ParamByName('V').AsString := DataValue;
      if ExpiresAt > 0 then
        Q.ParamByName('E').AsDateTime := ExpiresAt
      else
        Q.ParamByName('E').Clear;
      Q.ExecSQL;
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

end.

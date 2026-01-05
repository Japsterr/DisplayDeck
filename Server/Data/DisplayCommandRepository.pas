unit DisplayCommandRepository;

interface

uses
  System.Generics.Collections, uEntities;

type
  TDisplayCommandRepository = class
  public
    class function GetById(const Id: Integer): TDisplayCommand;
    class function GetPendingForDisplay(const DisplayId: Integer): TObjectList<TDisplayCommand>;
    class function ListByDisplay(const DisplayId: Integer; const Limit: Integer = 50): TObjectList<TDisplayCommand>;
    class function CreateCommand(const Cmd: TDisplayCommand): TDisplayCommand;
    class function MarkAsSent(const Id: Integer): TDisplayCommand;
    class function MarkAsAcknowledged(const Id: Integer): TDisplayCommand;
    class function MarkAsCompleted(const Id: Integer; const ResultJson: string): TDisplayCommand;
    class function MarkAsFailed(const Id: Integer; const ErrorMessage: string): TDisplayCommand;
    class procedure DeleteExpired;
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

function MapCommand(const Q: TFDQuery): TDisplayCommand;
begin
  Result := TDisplayCommand.Create;
  Result.Id := Q.FieldByName('CommandID').AsInteger;
  Result.DisplayId := Q.FieldByName('DisplayID').AsInteger;
  Result.OrganizationId := Q.FieldByName('OrganizationID').AsInteger;
  Result.CommandType := Q.FieldByName('CommandType').AsString;
  Result.CommandData := Q.FieldByName('CommandData').AsString;
  Result.Status := Q.FieldByName('Status').AsString;
  Result.HasSentAt := not Q.FieldByName('SentAt').IsNull;
  if Result.HasSentAt then
    Result.SentAt := Q.FieldByName('SentAt').AsDateTime;
  Result.HasAcknowledgedAt := not Q.FieldByName('AcknowledgedAt').IsNull;
  if Result.HasAcknowledgedAt then
    Result.AcknowledgedAt := Q.FieldByName('AcknowledgedAt').AsDateTime;
  Result.HasCompletedAt := not Q.FieldByName('CompletedAt').IsNull;
  if Result.HasCompletedAt then
    Result.CompletedAt := Q.FieldByName('CompletedAt').AsDateTime;
  Result.Result := Q.FieldByName('Result').AsString;
  if not Q.FieldByName('CreatedByUserID').IsNull then
    Result.CreatedByUserId := Q.FieldByName('CreatedByUserID').AsInteger;
  Result.CreatedAt := Q.FieldByName('CreatedAt').AsDateTime;
  Result.ExpiresAt := Q.FieldByName('ExpiresAt').AsDateTime;
end;

class function TDisplayCommandRepository.GetById(const Id: Integer): TDisplayCommand;
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'SELECT * FROM DisplayCommands WHERE CommandID=:Id';
      Q.ParamByName('Id').AsInteger := Id;
      Q.Open;
      if Q.Eof then
        Exit(nil);
      Result := MapCommand(Q);
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TDisplayCommandRepository.GetPendingForDisplay(const DisplayId: Integer): TObjectList<TDisplayCommand>;
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  Result := TObjectList<TDisplayCommand>.Create(True);
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 
        'SELECT * FROM DisplayCommands WHERE DisplayID=:D AND Status=''pending'' ' +
        'AND ExpiresAt > NOW() ORDER BY CreatedAt ASC';
      Q.ParamByName('D').AsInteger := DisplayId;
      Q.Open;
      while not Q.Eof do
      begin
        Result.Add(MapCommand(Q));
        Q.Next;
      end;
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TDisplayCommandRepository.ListByDisplay(const DisplayId: Integer; const Limit: Integer): TObjectList<TDisplayCommand>;
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  Result := TObjectList<TDisplayCommand>.Create(True);
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'SELECT * FROM DisplayCommands WHERE DisplayID=:D ORDER BY CreatedAt DESC LIMIT :L';
      Q.ParamByName('D').AsInteger := DisplayId;
      Q.ParamByName('L').AsInteger := Limit;
      Q.Open;
      while not Q.Eof do
      begin
        Result.Add(MapCommand(Q));
        Q.Next;
      end;
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TDisplayCommandRepository.CreateCommand(const Cmd: TDisplayCommand): TDisplayCommand;
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
        'INSERT INTO DisplayCommands (DisplayID, OrganizationID, CommandType, CommandData, Status, CreatedByUserID) ' +
        'VALUES (:D, :O, :CT, :CD::jsonb, ''pending'', :U) RETURNING *';
      Q.ParamByName('D').AsInteger := Cmd.DisplayId;
      Q.ParamByName('O').AsInteger := Cmd.OrganizationId;
      Q.ParamByName('CT').AsString := Cmd.CommandType;
      Q.ParamByName('CD').AsString := Cmd.CommandData;
      if Cmd.CreatedByUserId > 0 then
        Q.ParamByName('U').AsInteger := Cmd.CreatedByUserId
      else
        Q.ParamByName('U').Clear;
      Q.Open;
      Result := MapCommand(Q);
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TDisplayCommandRepository.MarkAsSent(const Id: Integer): TDisplayCommand;
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'UPDATE DisplayCommands SET Status=''sent'', SentAt=NOW() WHERE CommandID=:Id RETURNING *';
      Q.ParamByName('Id').AsInteger := Id;
      Q.Open;
      if Q.Eof then
        Exit(nil);
      Result := MapCommand(Q);
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TDisplayCommandRepository.MarkAsAcknowledged(const Id: Integer): TDisplayCommand;
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'UPDATE DisplayCommands SET Status=''acknowledged'', AcknowledgedAt=NOW() WHERE CommandID=:Id RETURNING *';
      Q.ParamByName('Id').AsInteger := Id;
      Q.Open;
      if Q.Eof then
        Exit(nil);
      Result := MapCommand(Q);
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TDisplayCommandRepository.MarkAsCompleted(const Id: Integer; const ResultJson: string): TDisplayCommand;
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'UPDATE DisplayCommands SET Status=''completed'', CompletedAt=NOW(), Result=:R::jsonb WHERE CommandID=:Id RETURNING *';
      Q.ParamByName('Id').AsInteger := Id;
      Q.ParamByName('R').AsString := ResultJson;
      Q.Open;
      if Q.Eof then
        Exit(nil);
      Result := MapCommand(Q);
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TDisplayCommandRepository.MarkAsFailed(const Id: Integer; const ErrorMessage: string): TDisplayCommand;
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'UPDATE DisplayCommands SET Status=''failed'', CompletedAt=NOW(), Result=:R::jsonb WHERE CommandID=:Id RETURNING *';
      Q.ParamByName('Id').AsInteger := Id;
      Q.ParamByName('R').AsString := '{"error": "' + ErrorMessage + '"}';
      Q.Open;
      if Q.Eof then
        Exit(nil);
      Result := MapCommand(Q);
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class procedure TDisplayCommandRepository.DeleteExpired;
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'DELETE FROM DisplayCommands WHERE ExpiresAt < NOW()';
      Q.ExecSQL;
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

end.

unit WebhookRepository;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  FireDAC.Comp.Client;

type
  TWebhook = class
  public
    Id: Int64;
    OrganizationId: Integer;
    Url: string;
    Secret: string;
    Events: string;
    IsActive: Boolean;
  end;

  TWebhookRepository = class
  public
    class function ListByOrganization(const OrganizationId: Integer): TObjectList<TWebhook>;
    class function CreateWebhook(const OrganizationId: Integer; const Url, Secret, Events: string): TWebhook;
    class function GetById(const WebhookId: Int64): TWebhook;
    class function DeleteWebhook(const OrganizationId: Integer; const WebhookId: Int64): Boolean;
  end;

implementation

uses
  FireDAC.Stan.Param,
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

function MapWebhook(const Q: TFDQuery): TWebhook;
begin
  Result := TWebhook.Create;
  Result.Id := Q.FieldByName('WebhookID').AsLargeInt;
  Result.OrganizationId := Q.FieldByName('OrganizationID').AsInteger;
  Result.Url := Q.FieldByName('Url').AsString;
  if Q.FindField('Secret') <> nil then
    Result.Secret := Q.FieldByName('Secret').AsString;
  Result.Events := Q.FieldByName('Events').AsString;
  Result.IsActive := Q.FieldByName('IsActive').AsBoolean;
end;

class function TWebhookRepository.ListByOrganization(const OrganizationId: Integer): TObjectList<TWebhook>;
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  Result := TObjectList<TWebhook>.Create(True);
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'select * from Webhooks where OrganizationID=:Org order by WebhookID';
      Q.ParamByName('Org').AsInteger := OrganizationId;
      Q.Open;
      while not Q.Eof do
      begin
        Result.Add(MapWebhook(Q));
        Q.Next;
      end;
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TWebhookRepository.CreateWebhook(const OrganizationId: Integer; const Url, Secret, Events: string): TWebhook;
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'insert into Webhooks (OrganizationID, Url, Secret, Events, IsActive) values (:Org,:Url,:Secret,:Events,true) returning *';
      Q.ParamByName('Org').AsInteger := OrganizationId;
      Q.ParamByName('Url').AsString := Url;
      Q.ParamByName('Secret').AsString := Secret;
      Q.ParamByName('Events').AsString := Events;
      Q.Open;
      Result := MapWebhook(Q);
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TWebhookRepository.GetById(const WebhookId: Int64): TWebhook;
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  Result := nil;
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'select * from Webhooks where WebhookID=:Id';
      Q.ParamByName('Id').AsLargeInt := WebhookId;
      Q.Open;
      if Q.Eof then Exit(nil);
      Result := MapWebhook(Q);
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TWebhookRepository.DeleteWebhook(const OrganizationId: Integer; const WebhookId: Int64): Boolean;
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  Result := False;
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'delete from Webhooks where WebhookID=:Id and OrganizationID=:Org';
      Q.ParamByName('Id').AsLargeInt := WebhookId;
      Q.ParamByName('Org').AsInteger := OrganizationId;
      Q.ExecSQL;
      Result := Q.RowsAffected > 0;
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

end.

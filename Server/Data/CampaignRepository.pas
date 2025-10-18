unit CampaignRepository;

interface

uses System.Generics.Collections, uEntities;

type
  TCampaignRepository = class
  public
    class function GetById(const Id: Integer): TCampaign;
    class function ListByOrganization(const OrgId: Integer): TObjectList<TCampaign>;
    class function CreateCampaign(const OrgId: Integer; const Name, Orientation: string): TCampaign;
    class function UpdateCampaign(const Id: Integer; const Name, Orientation: string): TCampaign;
    class procedure DeleteCampaign(const Id: Integer);
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

function MapCampaign(const Q: TFDQuery): TCampaign;
begin
  Result := TCampaign.Create;
  Result.Id := Q.FieldByName('CampaignID').AsInteger;
  Result.OrganizationId := Q.FieldByName('OrganizationID').AsInteger;
  Result.Name := Q.FieldByName('Name').AsString;
  Result.Orientation := Q.FieldByName('Orientation').AsString;
  Result.CreatedAt := Q.FieldByName('CreatedAt').AsDateTime;
  Result.UpdatedAt := Q.FieldByName('UpdatedAt').AsDateTime;
end;

class function TCampaignRepository.GetById(const Id: Integer): TCampaign;
var C: TFDConnection; Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'select * from Campaigns where CampaignID=:Id';
      Q.ParamByName('Id').AsInteger := Id;
      Q.Open;
      if Q.Eof then Exit(nil);
      Result := MapCampaign(Q);
    finally Q.Free; end;
  finally C.Free; end;
end;

class function TCampaignRepository.ListByOrganization(const OrgId: Integer): TObjectList<TCampaign>;
var C: TFDConnection; Q: TFDQuery;
begin
  Result := TObjectList<TCampaign>.Create(True);
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'select * from Campaigns where OrganizationID=:Org order by CampaignID';
      Q.ParamByName('Org').AsInteger := OrgId;
      Q.Open;
      while not Q.Eof do
      begin
        Result.Add(MapCampaign(Q));
        Q.Next;
      end;
    finally Q.Free; end;
  finally C.Free; end;
end;

class function TCampaignRepository.CreateCampaign(const OrgId: Integer; const Name, Orientation: string): TCampaign;
var C: TFDConnection; Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'insert into Campaigns (OrganizationID, Name, Orientation) values (:Org,:Name,:Orient) returning *';
      Q.ParamByName('Org').AsInteger := OrgId;
      Q.ParamByName('Name').AsString := Name;
      Q.ParamByName('Orient').AsString := Orientation;
      Q.Open;
      Result := MapCampaign(Q);
    finally Q.Free; end;
  finally C.Free; end;
end;

class function TCampaignRepository.UpdateCampaign(const Id: Integer; const Name, Orientation: string): TCampaign;
var C: TFDConnection; Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'update Campaigns set Name=:Name, Orientation=:Orient, UpdatedAt=now() where CampaignID=:Id returning *';
      Q.ParamByName('Id').AsInteger := Id;
      Q.ParamByName('Name').AsString := Name;
      Q.ParamByName('Orient').AsString := Orientation;
      Q.Open;
      if Q.Eof then Exit(nil);
      Result := MapCampaign(Q);
    finally Q.Free; end;
  finally C.Free; end;
end;

class procedure TCampaignRepository.DeleteCampaign(const Id: Integer);
var C: TFDConnection; Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'delete from Campaigns where CampaignID=:Id';
      Q.ParamByName('Id').AsInteger := Id;
      Q.ExecSQL;
    finally Q.Free; end;
  finally C.Free; end;
end;

end.

unit OrganizationRepository;

interface

uses
  System.Generics.Collections,
  uEntities;

type
  TOrganizationRepository = class
  public
    class function GetOrganizations: TObjectList<TOrganization>;
    class function GetOrganization(const Id: Integer): TOrganization;
    class function CreateOrganization(const Organization: TOrganization): TOrganization;
  end;

implementation

uses
  System.SysUtils,
  FireDAC.Comp.Client,
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

function MapOrganization(const Query: TFDQuery): TOrganization;
begin
  Result := TOrganization.Create;
  Result.Id := Query.FieldByName('OrganizationID').AsInteger;
  Result.Name := Query.FieldByName('Name').AsString;
  Result.CreatedAt := Query.FieldByName('CreatedAt').AsDateTime;
  Result.UpdatedAt := Query.FieldByName('UpdatedAt').AsDateTime;
end;

class function TOrganizationRepository.GetOrganizations: TObjectList<TOrganization>;
var
  Conn: TFDConnection;
  Query: TFDQuery;
begin
  Result := TObjectList<TOrganization>.Create(True);
  Conn := NewConnection;
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := Conn;
      Query.SQL.Text :=
        'select OrganizationID, Name, CreatedAt, UpdatedAt from Organizations order by OrganizationID';
      Query.Open;
      while not Query.Eof do
      begin
        Result.Add(MapOrganization(Query));
        Query.Next;
      end;
    finally
      Query.Free;
    end;
  finally
    Conn.Free;
  end;
end;

class function TOrganizationRepository.GetOrganization(const Id: Integer): TOrganization;
var
  Conn: TFDConnection;
  Query: TFDQuery;
begin
  Conn := NewConnection;
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := Conn;
      Query.SQL.Text :=
        'select OrganizationID, Name, CreatedAt, UpdatedAt from Organizations where OrganizationID = :Id';
      Query.ParamByName('Id').AsInteger := Id;
      Query.Open;
      if Query.Eof then
        Exit(nil);
      Result := MapOrganization(Query);
    finally
      Query.Free;
    end;
  finally
    Conn.Free;
  end;
end;

class function TOrganizationRepository.CreateOrganization(const Organization: TOrganization): TOrganization;
var
  Conn: TFDConnection;
  Query: TFDQuery;
begin
  if Organization = nil then
    raise EArgumentNilException.Create('Organization parameter cannot be nil.');

  Conn := NewConnection;
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := Conn;
      Query.SQL.Text :=
        'insert into Organizations (Name) values (:Name) ' +
        'returning OrganizationID, Name, CreatedAt, UpdatedAt';
      Query.ParamByName('Name').AsString := Organization.Name;
      Query.Open;

      Organization.Id := Query.FieldByName('OrganizationID').AsInteger;
      Organization.Name := Query.FieldByName('Name').AsString;
      Organization.CreatedAt := Query.FieldByName('CreatedAt').AsDateTime;
      Organization.UpdatedAt := Query.FieldByName('UpdatedAt').AsDateTime;
      Result := Organization;
    finally
      Query.Free;
    end;
  finally
    Conn.Free;
  end;
end;

end.

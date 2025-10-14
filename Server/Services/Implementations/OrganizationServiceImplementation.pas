unit OrganizationServiceImplementation;

interface

uses
  XData.Server.Module,
  XData.Service.Common,
  OrganizationService,
  uEntities,
  System.Generics.Collections;

type
  [ServiceImplementation]
  TOrganizationService = class(TInterfacedObject, IOrganizationService)
  public
    function GetOrganizations: TList<TOrganization>;
    function GetOrganization(id: integer): TOrganization;
    function CreateOrganization(const organization: TOrganization): TOrganization;
  end;

implementation

uses
  uServerContainer,
  FireDAC.Comp.Client,
  FireDAC.Stan.Param,
  Data.DB,
  System.SysUtils,
  XData.Sys.Exceptions;

function TOrganizationService.GetOrganizations: TList<TOrganization>;
var
  Q: TFDQuery;
  Org: TOrganization;
begin
  Result := TList<TOrganization>.Create;
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := ServerContainer.FDConnection;
    Q.SQL.Text := 'SELECT OrganizationID, Name, CreatedAt, UpdatedAt FROM Organizations ORDER BY OrganizationID';
    Q.Open;
    while not Q.Eof do
    begin
      Org := TOrganization.Create;
      Org.Id := Q.FieldByName('OrganizationID').AsInteger;
      Org.Name := Q.FieldByName('Name').AsString;
      if not Q.FieldByName('CreatedAt').IsNull then
        Org.CreatedAt := Q.FieldByName('CreatedAt').AsDateTime;
      if not Q.FieldByName('UpdatedAt').IsNull then
        Org.UpdatedAt := Q.FieldByName('UpdatedAt').AsDateTime;
      Result.Add(Org);
      Q.Next;
    end;
  finally
    Q.Free;
  end;
end;

function TOrganizationService.GetOrganization(id: integer): TOrganization;
var
  Q: TFDQuery;
begin
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := ServerContainer.FDConnection;
    Q.SQL.Text := 'SELECT OrganizationID, Name, CreatedAt, UpdatedAt FROM Organizations WHERE OrganizationID = :Id';
    Q.ParamByName('Id').AsInteger := Id;
    Q.Open;
    if Q.IsEmpty then
      raise EXDataHttpException.Create(404, 'Organization not found');
    Result := TOrganization.Create;
    Result.Id := Q.FieldByName('OrganizationID').AsInteger;
    Result.Name := Q.FieldByName('Name').AsString;
    if not Q.FieldByName('CreatedAt').IsNull then
      Result.CreatedAt := Q.FieldByName('CreatedAt').AsDateTime;
    if not Q.FieldByName('UpdatedAt').IsNull then
      Result.UpdatedAt := Q.FieldByName('UpdatedAt').AsDateTime;
  finally
    Q.Free;
  end;
end;

function TOrganizationService.CreateOrganization(const organization: TOrganization): TOrganization;
var
  Q: TFDQuery;
begin
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := ServerContainer.FDConnection;
    // Insert and return the created row id
    Q.SQL.Text := 'INSERT INTO Organizations (Name, CreatedAt, UpdatedAt) ' +
                  'VALUES (:Name, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP) ' +
                  'RETURNING OrganizationID, CreatedAt, UpdatedAt';
    Q.ParamByName('Name').AsString := organization.Name;
    Q.Open;
    organization.Id := Q.FieldByName('OrganizationID').AsInteger;
    if not Q.FieldByName('CreatedAt').IsNull then
      organization.CreatedAt := Q.FieldByName('CreatedAt').AsDateTime;
    if not Q.FieldByName('UpdatedAt').IsNull then
      organization.UpdatedAt := Q.FieldByName('UpdatedAt').AsDateTime;
    Result := organization;
  finally
    Q.Free;
  end;
end;

initialization
  RegisterServiceType(TOrganizationService);

end.

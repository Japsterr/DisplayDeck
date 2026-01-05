unit TeamRepository;

interface

uses
  System.Generics.Collections, uEntities;

type
  TTeamRepository = class
  public
    // Roles
    class function GetRoleById(const Id: Integer): TRole;
    class function ListRoles(const OrganizationId: Integer): TObjectList<TRole>;
    class function ListSystemRoles: TObjectList<TRole>;
    class function CreateRole(const Role: TRole): TRole;
    class function UpdateRole(const Role: TRole): TRole;
    class procedure DeleteRole(const Id: Integer);
    // Invitations
    class function GetInvitationById(const Id: Integer): TTeamInvitation;
    class function GetInvitationByToken(const TokenHash: string): TTeamInvitation;
    class function ListInvitations(const OrganizationId: Integer): TObjectList<TTeamInvitation>;
    class function CreateInvitation(const Invite: TTeamInvitation): TTeamInvitation;
    class function AcceptInvitation(const Id: Integer): TTeamInvitation;
    class procedure DeleteInvitation(const Id: Integer);
    // Locations
    class function GetLocationById(const Id: Integer): TLocation;
    class function ListLocations(const OrganizationId: Integer): TObjectList<TLocation>;
    class function CreateLocation(const Loc: TLocation): TLocation;
    class function UpdateLocation(const Loc: TLocation): TLocation;
    class procedure DeleteLocation(const Id: Integer);
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

function MapRole(const Q: TFDQuery): TRole;
begin
  Result := TRole.Create;
  Result.Id := Q.FieldByName('RoleID').AsInteger;
  if not Q.FieldByName('OrganizationID').IsNull then
    Result.OrganizationId := Q.FieldByName('OrganizationID').AsInteger;
  Result.Name := Q.FieldByName('Name').AsString;
  Result.Description := Q.FieldByName('Description').AsString;
  Result.Permissions := Q.FieldByName('Permissions').AsString;
  Result.IsSystemRole := Q.FieldByName('IsSystemRole').AsBoolean;
  Result.CreatedAt := Q.FieldByName('CreatedAt').AsDateTime;
  Result.UpdatedAt := Q.FieldByName('UpdatedAt').AsDateTime;
end;

function MapInvitation(const Q: TFDQuery): TTeamInvitation;
begin
  Result := TTeamInvitation.Create;
  Result.Id := Q.FieldByName('InvitationID').AsInteger;
  Result.OrganizationId := Q.FieldByName('OrganizationID').AsInteger;
  Result.Email := Q.FieldByName('Email').AsString;
  Result.RoleId := Q.FieldByName('RoleID').AsInteger;
  Result.InvitedByUserId := Q.FieldByName('InvitedByUserID').AsInteger;
  Result.TokenHash := Q.FieldByName('TokenHash').AsString;
  Result.ExpiresAt := Q.FieldByName('ExpiresAt').AsDateTime;
  Result.HasAcceptedAt := not Q.FieldByName('AcceptedAt').IsNull;
  if Result.HasAcceptedAt then
    Result.AcceptedAt := Q.FieldByName('AcceptedAt').AsDateTime;
  Result.CreatedAt := Q.FieldByName('CreatedAt').AsDateTime;
end;

function MapLocation(const Q: TFDQuery): TLocation;
begin
  Result := TLocation.Create;
  Result.Id := Q.FieldByName('LocationID').AsInteger;
  Result.OrganizationId := Q.FieldByName('OrganizationID').AsInteger;
  Result.Name := Q.FieldByName('Name').AsString;
  Result.Address := Q.FieldByName('Address').AsString;
  Result.City := Q.FieldByName('City').AsString;
  Result.State := Q.FieldByName('State').AsString;
  Result.Country := Q.FieldByName('Country').AsString;
  Result.Timezone := Q.FieldByName('Timezone').AsString;
  if not Q.FieldByName('Latitude').IsNull then
    Result.Latitude := Q.FieldByName('Latitude').AsFloat;
  if not Q.FieldByName('Longitude').IsNull then
    Result.Longitude := Q.FieldByName('Longitude').AsFloat;
  Result.CreatedAt := Q.FieldByName('CreatedAt').AsDateTime;
  Result.UpdatedAt := Q.FieldByName('UpdatedAt').AsDateTime;
end;

// Roles

class function TTeamRepository.GetRoleById(const Id: Integer): TRole;
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'SELECT * FROM Roles WHERE RoleID=:Id';
      Q.ParamByName('Id').AsInteger := Id;
      Q.Open;
      if Q.Eof then
        Exit(nil);
      Result := MapRole(Q);
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TTeamRepository.ListRoles(const OrganizationId: Integer): TObjectList<TRole>;
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  Result := TObjectList<TRole>.Create(True);
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'SELECT * FROM Roles WHERE OrganizationID=:O OR IsSystemRole=true ORDER BY IsSystemRole DESC, Name ASC';
      Q.ParamByName('O').AsInteger := OrganizationId;
      Q.Open;
      while not Q.Eof do
      begin
        Result.Add(MapRole(Q));
        Q.Next;
      end;
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TTeamRepository.ListSystemRoles: TObjectList<TRole>;
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  Result := TObjectList<TRole>.Create(True);
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'SELECT * FROM Roles WHERE IsSystemRole=true ORDER BY Name ASC';
      Q.Open;
      while not Q.Eof do
      begin
        Result.Add(MapRole(Q));
        Q.Next;
      end;
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TTeamRepository.CreateRole(const Role: TRole): TRole;
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
        'INSERT INTO Roles (OrganizationID, Name, Description, Permissions, IsSystemRole) ' +
        'VALUES (:O, :N, :D, :P::jsonb, false) RETURNING *';
      if Role.OrganizationId > 0 then
        Q.ParamByName('O').AsInteger := Role.OrganizationId
      else
        Q.ParamByName('O').Clear;
      Q.ParamByName('N').AsString := Role.Name;
      Q.ParamByName('D').AsString := Role.Description;
      Q.ParamByName('P').AsString := Role.Permissions;
      Q.Open;
      Result := MapRole(Q);
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TTeamRepository.UpdateRole(const Role: TRole): TRole;
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
        'UPDATE Roles SET Name=:N, Description=:D, Permissions=:P::jsonb, UpdatedAt=NOW() ' +
        'WHERE RoleID=:Id AND IsSystemRole=false RETURNING *';
      Q.ParamByName('Id').AsInteger := Role.Id;
      Q.ParamByName('N').AsString := Role.Name;
      Q.ParamByName('D').AsString := Role.Description;
      Q.ParamByName('P').AsString := Role.Permissions;
      Q.Open;
      if Q.Eof then
        Exit(nil);
      Result := MapRole(Q);
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class procedure TTeamRepository.DeleteRole(const Id: Integer);
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'DELETE FROM Roles WHERE RoleID=:Id AND IsSystemRole=false';
      Q.ParamByName('Id').AsInteger := Id;
      Q.ExecSQL;
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

// Invitations

class function TTeamRepository.GetInvitationById(const Id: Integer): TTeamInvitation;
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'SELECT * FROM TeamInvitations WHERE InvitationID=:Id';
      Q.ParamByName('Id').AsInteger := Id;
      Q.Open;
      if Q.Eof then
        Exit(nil);
      Result := MapInvitation(Q);
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TTeamRepository.GetInvitationByToken(const TokenHash: string): TTeamInvitation;
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'SELECT * FROM TeamInvitations WHERE TokenHash=:T AND ExpiresAt > NOW() AND AcceptedAt IS NULL';
      Q.ParamByName('T').AsString := TokenHash;
      Q.Open;
      if Q.Eof then
        Exit(nil);
      Result := MapInvitation(Q);
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TTeamRepository.ListInvitations(const OrganizationId: Integer): TObjectList<TTeamInvitation>;
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  Result := TObjectList<TTeamInvitation>.Create(True);
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'SELECT * FROM TeamInvitations WHERE OrganizationID=:O ORDER BY CreatedAt DESC';
      Q.ParamByName('O').AsInteger := OrganizationId;
      Q.Open;
      while not Q.Eof do
      begin
        Result.Add(MapInvitation(Q));
        Q.Next;
      end;
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TTeamRepository.CreateInvitation(const Invite: TTeamInvitation): TTeamInvitation;
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
        'INSERT INTO TeamInvitations (OrganizationID, Email, RoleID, InvitedByUserID, TokenHash, ExpiresAt) ' +
        'VALUES (:O, :E, :R, :U, :T, :X) RETURNING *';
      Q.ParamByName('O').AsInteger := Invite.OrganizationId;
      Q.ParamByName('E').AsString := Invite.Email;
      Q.ParamByName('R').AsInteger := Invite.RoleId;
      Q.ParamByName('U').AsInteger := Invite.InvitedByUserId;
      Q.ParamByName('T').AsString := Invite.TokenHash;
      Q.ParamByName('X').AsDateTime := Invite.ExpiresAt;
      Q.Open;
      Result := MapInvitation(Q);
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TTeamRepository.AcceptInvitation(const Id: Integer): TTeamInvitation;
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'UPDATE TeamInvitations SET AcceptedAt=NOW() WHERE InvitationID=:Id RETURNING *';
      Q.ParamByName('Id').AsInteger := Id;
      Q.Open;
      if Q.Eof then
        Exit(nil);
      Result := MapInvitation(Q);
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class procedure TTeamRepository.DeleteInvitation(const Id: Integer);
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'DELETE FROM TeamInvitations WHERE InvitationID=:Id';
      Q.ParamByName('Id').AsInteger := Id;
      Q.ExecSQL;
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

// Locations

class function TTeamRepository.GetLocationById(const Id: Integer): TLocation;
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'SELECT * FROM Locations WHERE LocationID=:Id';
      Q.ParamByName('Id').AsInteger := Id;
      Q.Open;
      if Q.Eof then
        Exit(nil);
      Result := MapLocation(Q);
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TTeamRepository.ListLocations(const OrganizationId: Integer): TObjectList<TLocation>;
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  Result := TObjectList<TLocation>.Create(True);
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'SELECT * FROM Locations WHERE OrganizationID=:O ORDER BY Name ASC';
      Q.ParamByName('O').AsInteger := OrganizationId;
      Q.Open;
      while not Q.Eof do
      begin
        Result.Add(MapLocation(Q));
        Q.Next;
      end;
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TTeamRepository.CreateLocation(const Loc: TLocation): TLocation;
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
        'INSERT INTO Locations (OrganizationID, Name, Address, City, State, Country, Timezone, Latitude, Longitude) ' +
        'VALUES (:O, :N, :A, :C, :S, :CO, :TZ, :LAT, :LNG) RETURNING *';
      Q.ParamByName('O').AsInteger := Loc.OrganizationId;
      Q.ParamByName('N').AsString := Loc.Name;
      Q.ParamByName('A').AsString := Loc.Address;
      Q.ParamByName('C').AsString := Loc.City;
      Q.ParamByName('S').AsString := Loc.State;
      Q.ParamByName('CO').AsString := Loc.Country;
      Q.ParamByName('TZ').AsString := Loc.Timezone;
      if Loc.Latitude <> 0 then
        Q.ParamByName('LAT').AsFloat := Loc.Latitude
      else
        Q.ParamByName('LAT').Clear;
      if Loc.Longitude <> 0 then
        Q.ParamByName('LNG').AsFloat := Loc.Longitude
      else
        Q.ParamByName('LNG').Clear;
      Q.Open;
      Result := MapLocation(Q);
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TTeamRepository.UpdateLocation(const Loc: TLocation): TLocation;
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
        'UPDATE Locations SET Name=:N, Address=:A, City=:C, State=:S, Country=:CO, Timezone=:TZ, ' +
        'Latitude=:LAT, Longitude=:LNG, UpdatedAt=NOW() WHERE LocationID=:Id RETURNING *';
      Q.ParamByName('Id').AsInteger := Loc.Id;
      Q.ParamByName('N').AsString := Loc.Name;
      Q.ParamByName('A').AsString := Loc.Address;
      Q.ParamByName('C').AsString := Loc.City;
      Q.ParamByName('S').AsString := Loc.State;
      Q.ParamByName('CO').AsString := Loc.Country;
      Q.ParamByName('TZ').AsString := Loc.Timezone;
      if Loc.Latitude <> 0 then
        Q.ParamByName('LAT').AsFloat := Loc.Latitude
      else
        Q.ParamByName('LAT').Clear;
      if Loc.Longitude <> 0 then
        Q.ParamByName('LNG').AsFloat := Loc.Longitude
      else
        Q.ParamByName('LNG').Clear;
      Q.Open;
      if Q.Eof then
        Exit(nil);
      Result := MapLocation(Q);
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class procedure TTeamRepository.DeleteLocation(const Id: Integer);
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'DELETE FROM Locations WHERE LocationID=:Id';
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

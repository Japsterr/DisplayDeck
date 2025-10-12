unit DisplayServiceImplementation;

interface

uses
  System.SysUtils,
  XData.Server.Module,
  XData.Service.Common,
  FireDAC.Comp.Client,
  FireDAC.Stan.Param,
  Data.DB,
  uEntities,
  DisplayService;

type
  [ServiceImplementation]
  TDisplayService = class(TInterfacedObject, IDisplayService)
  private
    function GetConnection: TFDConnection;
  public
    function GetDisplays(OrganizationId: Integer): TArray<TDisplay>;
    function GetDisplay(Id: Integer): TDisplay;
    function CreateDisplay(OrganizationId: Integer; const Name, Orientation, CurrentStatus, ProvisioningToken: string): TDisplay;
    function UpdateDisplay(Id: Integer; const Name, Orientation, CurrentStatus: string): TDisplay;
    procedure DeleteDisplay(Id: Integer);
  end;

implementation

uses
  uServerContainer;

function TDisplayService.GetConnection: TFDConnection;
begin
  Result := ServerContainer.FDConnection;
end;

function TDisplayService.GetDisplays(OrganizationId: Integer): TArray<TDisplay>;
var
  Query: TFDQuery;
  List: TArray<TDisplay>;
  Item: TDisplay;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := GetConnection;
    Query.SQL.Text := 'SELECT DisplayID, OrganizationID, Name, Orientation, LastSeen, CurrentStatus, ProvisioningToken, CreatedAt, UpdatedAt ' +
                      'FROM Displays WHERE OrganizationID = :OrgId ORDER BY Name';
    Query.ParamByName('OrgId').AsInteger := OrganizationId;
    Query.Open;

    SetLength(List, 0);
    while not Query.Eof do
    begin
      Item := TDisplay.Create;
      Item.Id := Query.FieldByName('DisplayID').AsInteger;
      Item.OrganizationId := Query.FieldByName('OrganizationID').AsInteger;
      Item.Name := Query.FieldByName('Name').AsString;
      Item.Orientation := Query.FieldByName('Orientation').AsString;
      Item.LastSeen := Query.FieldByName('LastSeen').AsDateTime;
      Item.CurrentStatus := Query.FieldByName('CurrentStatus').AsString;
      Item.ProvisioningToken := Query.FieldByName('ProvisioningToken').AsString;
      Item.CreatedAt := Query.FieldByName('CreatedAt').AsDateTime;
      Item.UpdatedAt := Query.FieldByName('UpdatedAt').AsDateTime;

      SetLength(List, Length(List) + 1);
      List[High(List)] := Item;
      Query.Next;
    end;
    Result := List;
  finally
    Query.Free;
  end;
end;

function TDisplayService.GetDisplay(Id: Integer): TDisplay;
var
  Query: TFDQuery;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := GetConnection;
    Query.SQL.Text := 'SELECT DisplayID, OrganizationID, Name, Orientation, LastSeen, CurrentStatus, ProvisioningToken, CreatedAt, UpdatedAt ' +
                      'FROM Displays WHERE DisplayID = :Id';
    Query.ParamByName('Id').AsInteger := Id;
    Query.Open;

    if Query.IsEmpty then
      raise Exception.CreateFmt('Display with ID %d not found', [Id]);

    Result := TDisplay.Create;
    Result.Id := Query.FieldByName('DisplayID').AsInteger;
    Result.OrganizationId := Query.FieldByName('OrganizationID').AsInteger;
    Result.Name := Query.FieldByName('Name').AsString;
    Result.Orientation := Query.FieldByName('Orientation').AsString;
    Result.LastSeen := Query.FieldByName('LastSeen').AsDateTime;
    Result.CurrentStatus := Query.FieldByName('CurrentStatus').AsString;
    Result.ProvisioningToken := Query.FieldByName('ProvisioningToken').AsString;
    Result.CreatedAt := Query.FieldByName('CreatedAt').AsDateTime;
    Result.UpdatedAt := Query.FieldByName('UpdatedAt').AsDateTime;
  finally
    Query.Free;
  end;
end;

function TDisplayService.CreateDisplay(OrganizationId: Integer; const Name, Orientation, CurrentStatus, ProvisioningToken: string): TDisplay;
var
  Query: TFDQuery;
  NewId: Integer;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := GetConnection;
    Query.SQL.Text := 'INSERT INTO Displays (OrganizationID, Name, Orientation, CurrentStatus, ProvisioningToken, CreatedAt, UpdatedAt) ' +
                      'VALUES (:OrgId, :Name, :Orientation, :Status, :Token, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP) RETURNING DisplayID';
    Query.ParamByName('OrgId').AsInteger := OrganizationId;
    Query.ParamByName('Name').AsString := Name;
    Query.ParamByName('Orientation').AsString := Orientation;
    Query.ParamByName('Status').AsString := CurrentStatus;
    Query.ParamByName('Token').AsString := ProvisioningToken;
    Query.Open;
    NewId := Query.Fields[0].AsInteger;
    Result := GetDisplay(NewId);
  finally
    Query.Free;
  end;
end;

function TDisplayService.UpdateDisplay(Id: Integer; const Name, Orientation, CurrentStatus: string): TDisplay;
var
  Query: TFDQuery;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := GetConnection;
    Query.SQL.Text := 'UPDATE Displays SET Name = :Name, Orientation = :Orientation, CurrentStatus = :Status, UpdatedAt = CURRENT_TIMESTAMP WHERE DisplayID = :Id';
    Query.ParamByName('Id').AsInteger := Id;
    Query.ParamByName('Name').AsString := Name;
    Query.ParamByName('Orientation').AsString := Orientation;
    Query.ParamByName('Status').AsString := CurrentStatus;
    Query.ExecSQL;
    if Query.RowsAffected = 0 then
      raise Exception.CreateFmt('Display with ID %d not found', [Id]);
    Result := GetDisplay(Id);
  finally
    Query.Free;
  end;
end;

procedure TDisplayService.DeleteDisplay(Id: Integer);
var
  Query: TFDQuery;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := GetConnection;
    Query.SQL.Text := 'DELETE FROM Displays WHERE DisplayID = :Id';
    Query.ParamByName('Id').AsInteger := Id;
    Query.ExecSQL;
    if Query.RowsAffected = 0 then
      raise Exception.CreateFmt('Display with ID %d not found', [Id]);
  finally
    Query.Free;
  end;
end;
initialization
  RegisterServiceType(TDisplayService);

end.

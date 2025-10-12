unit CampaignServiceImplementation;

interface

uses
  System.SysUtils,
  XData.Server.Module,
  XData.Service.Common,
  FireDAC.Comp.Client,
  FireDAC.Stan.Param,
  Data.DB,
  uEntities,
  CampaignService;

type
  [ServiceImplementation]
  TCampaignService = class(TInterfacedObject, ICampaignService)
  private
    function GetConnection: TFDConnection;
  public
    function GetCampaigns(OrganizationId: Integer): TArray<TCampaign>;
    function GetCampaign(Id: Integer): TCampaign;
    function CreateCampaign(OrganizationId: Integer; const Name, Orientation: string): TCampaign;
    function UpdateCampaign(Id: Integer; const Name, Orientation: string): TCampaign;
    procedure DeleteCampaign(Id: Integer);
  end;

implementation

uses
  uServerContainer;

{ TCampaignService }

function TCampaignService.GetConnection: TFDConnection;
begin
  // Get the shared connection from the server container
  Result := ServerContainer.FDConnection;
end;

function TCampaignService.GetCampaigns(OrganizationId: Integer): TArray<TCampaign>;
var
  Query: TFDQuery;
  List: TArray<TCampaign>;
  Campaign: TCampaign;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := GetConnection;
    Query.SQL.Text := 'SELECT CampaignID, OrganizationID, Name, Orientation, CreatedAt, UpdatedAt ' +
                      'FROM Campaigns WHERE OrganizationID = :OrgId ORDER BY Name';
    Query.ParamByName('OrgId').AsInteger := OrganizationId;
    Query.Open;
    
    SetLength(List, 0);
    while not Query.Eof do
    begin
      Campaign := TCampaign.Create;
      Campaign.Id := Query.FieldByName('CampaignID').AsInteger;
      Campaign.OrganizationId := Query.FieldByName('OrganizationID').AsInteger;
      Campaign.Name := Query.FieldByName('Name').AsString;
      Campaign.Orientation := Query.FieldByName('Orientation').AsString;
      Campaign.CreatedAt := Query.FieldByName('CreatedAt').AsDateTime;
      Campaign.UpdatedAt := Query.FieldByName('UpdatedAt').AsDateTime;
      
      SetLength(List, Length(List) + 1);
      List[High(List)] := Campaign;
      Query.Next;
    end;
    
    Result := List;
  finally
    Query.Free;
  end;
end;

function TCampaignService.GetCampaign(Id: Integer): TCampaign;
var
  Query: TFDQuery;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := GetConnection;
    Query.SQL.Text := 'SELECT CampaignID, OrganizationID, Name, Orientation, CreatedAt, UpdatedAt ' +
                      'FROM Campaigns WHERE CampaignID = :Id';
    Query.ParamByName('Id').AsInteger := Id;
    Query.Open;
    
    if Query.IsEmpty then
      raise Exception.CreateFmt('Campaign with ID %d not found', [Id]);
    
    Result := TCampaign.Create;
    Result.Id := Query.FieldByName('CampaignID').AsInteger;
    Result.OrganizationId := Query.FieldByName('OrganizationID').AsInteger;
    Result.Name := Query.FieldByName('Name').AsString;
    Result.Orientation := Query.FieldByName('Orientation').AsString;
    Result.CreatedAt := Query.FieldByName('CreatedAt').AsDateTime;
    Result.UpdatedAt := Query.FieldByName('UpdatedAt').AsDateTime;
  finally
    Query.Free;
  end;
end;

function TCampaignService.CreateCampaign(OrganizationId: Integer; const Name, Orientation: string): TCampaign;
var
  Query: TFDQuery;
  NewId: Integer;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := GetConnection;
    Query.SQL.Text := 'INSERT INTO Campaigns (OrganizationID, Name, Orientation, CreatedAt, UpdatedAt) ' +
                      'VALUES (:OrgId, :Name, :Orientation, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP) ' +
                      'RETURNING CampaignID';
    Query.ParamByName('OrgId').AsInteger := OrganizationId;
    Query.ParamByName('Name').AsString := Name;
    Query.ParamByName('Orientation').AsString := Orientation;
    Query.Open;
    
    NewId := Query.Fields[0].AsInteger;
    Result := GetCampaign(NewId);
  finally
    Query.Free;
  end;
end;

function TCampaignService.UpdateCampaign(Id: Integer; const Name, Orientation: string): TCampaign;
var
  Query: TFDQuery;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := GetConnection;
    Query.SQL.Text := 'UPDATE Campaigns SET Name = :Name, Orientation = :Orientation, ' +
                      'UpdatedAt = CURRENT_TIMESTAMP WHERE CampaignID = :Id';
    Query.ParamByName('Id').AsInteger := Id;
    Query.ParamByName('Name').AsString := Name;
    Query.ParamByName('Orientation').AsString := Orientation;
    Query.ExecSQL;
    
    if Query.RowsAffected = 0 then
      raise Exception.CreateFmt('Campaign with ID %d not found', [Id]);
    
    Result := GetCampaign(Id);
  finally
    Query.Free;
  end;
end;

procedure TCampaignService.DeleteCampaign(Id: Integer);
var
  Query: TFDQuery;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := GetConnection;
    Query.SQL.Text := 'DELETE FROM Campaigns WHERE CampaignID = :Id';
    Query.ParamByName('Id').AsInteger := Id;
    Query.ExecSQL;
    
    if Query.RowsAffected = 0 then
      raise Exception.CreateFmt('Campaign with ID %d not found', [Id]);
  finally
    Query.Free;
  end;
end;

initialization
  RegisterServiceType(TCampaignService);

end.

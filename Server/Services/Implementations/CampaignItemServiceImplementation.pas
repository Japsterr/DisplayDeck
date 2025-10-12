unit CampaignItemServiceImplementation;

interface

uses
  XData.Server.Module,
  XData.Service.Common,
  FireDAC.Comp.Client,
  FireDAC.Stan.Param,
  Data.DB,
  uEntities,
  CampaignItemService;

type
  [ServiceImplementation]
  TCampaignItemService = class(TInterfacedObject, ICampaignItemService)
  private
    function GetConnection: TFDConnection;
  public
    function GetCampaignItems(CampaignId: Integer): TArray<TCampaignItem>;
    function GetCampaignItem(Id: Integer): TCampaignItem;
    function CreateCampaignItem(CampaignId, MediaFileId, DisplayOrder, Duration: Integer): TCampaignItem;
    function UpdateCampaignItem(Id, MediaFileId, DisplayOrder, Duration: Integer): TCampaignItem;
    procedure DeleteCampaignItem(Id: Integer);
  end;

implementation

uses
  System.SysUtils,
  uServerContainer;

function TCampaignItemService.GetConnection: TFDConnection;
begin
  Result := ServerContainer.FDConnection;
end;

function TCampaignItemService.GetCampaignItems(CampaignId: Integer): TArray<TCampaignItem>;
var
  Query: TFDQuery;
  List: TArray<TCampaignItem>;
  Item: TCampaignItem;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := GetConnection;
    Query.SQL.Text := 'SELECT CampaignItemID, CampaignID, MediaFileID, DisplayOrder, Duration FROM CampaignItems WHERE CampaignID = :Id ORDER BY DisplayOrder';
    Query.ParamByName('Id').AsInteger := CampaignId;
    Query.Open;
    SetLength(List, 0);
    while not Query.Eof do
    begin
      Item := TCampaignItem.Create;
      Item.Id := Query.FieldByName('CampaignItemID').AsInteger;
      Item.CampaignId := Query.FieldByName('CampaignID').AsInteger;
      Item.MediaFileId := Query.FieldByName('MediaFileID').AsInteger;
      Item.DisplayOrder := Query.FieldByName('DisplayOrder').AsInteger;
      Item.Duration := Query.FieldByName('Duration').AsInteger;
      SetLength(List, Length(List) + 1);
      List[High(List)] := Item;
      Query.Next;
    end;
    Result := List;
  finally
    Query.Free;
  end;
end;

function TCampaignItemService.GetCampaignItem(Id: Integer): TCampaignItem;
var
  Query: TFDQuery;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := GetConnection;
    Query.SQL.Text := 'SELECT CampaignItemID, CampaignID, MediaFileID, DisplayOrder, Duration FROM CampaignItems WHERE CampaignItemID = :Id';
    Query.ParamByName('Id').AsInteger := Id;
    Query.Open;
    if Query.IsEmpty then
      raise Exception.CreateFmt('Campaign item with ID %d not found', [Id]);
    Result := TCampaignItem.Create;
    Result.Id := Query.FieldByName('CampaignItemID').AsInteger;
    Result.CampaignId := Query.FieldByName('CampaignID').AsInteger;
    Result.MediaFileId := Query.FieldByName('MediaFileID').AsInteger;
    Result.DisplayOrder := Query.FieldByName('DisplayOrder').AsInteger;
    Result.Duration := Query.FieldByName('Duration').AsInteger;
  finally
    Query.Free;
  end;
end;

function TCampaignItemService.CreateCampaignItem(CampaignId, MediaFileId, DisplayOrder, Duration: Integer): TCampaignItem;
var
  Query: TFDQuery;
  NewId: Integer;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := GetConnection;
    Query.SQL.Text := 'INSERT INTO CampaignItems (CampaignID, MediaFileID, DisplayOrder, Duration) VALUES (:CampaignId, :MediaFileId, :DisplayOrder, :Duration) RETURNING CampaignItemID';
    Query.ParamByName('CampaignId').AsInteger := CampaignId;
    Query.ParamByName('MediaFileId').AsInteger := MediaFileId;
    Query.ParamByName('DisplayOrder').AsInteger := DisplayOrder;
    Query.ParamByName('Duration').AsInteger := Duration;
    Query.Open;
    NewId := Query.Fields[0].AsInteger;
    Result := GetCampaignItem(NewId);
  finally
    Query.Free;
  end;
end;

function TCampaignItemService.UpdateCampaignItem(Id, MediaFileId, DisplayOrder, Duration: Integer): TCampaignItem;
var
  Query: TFDQuery;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := GetConnection;
    Query.SQL.Text := 'UPDATE CampaignItems SET MediaFileID = :MediaFileId, DisplayOrder = :DisplayOrder, Duration = :Duration WHERE CampaignItemID = :Id';
    Query.ParamByName('Id').AsInteger := Id;
    Query.ParamByName('MediaFileId').AsInteger := MediaFileId;
    Query.ParamByName('DisplayOrder').AsInteger := DisplayOrder;
    Query.ParamByName('Duration').AsInteger := Duration;
    Query.ExecSQL;
    if Query.RowsAffected = 0 then
      raise Exception.CreateFmt('Campaign item with ID %d not found', [Id]);
    Result := GetCampaignItem(Id);
  finally
    Query.Free;
  end;
end;

procedure TCampaignItemService.DeleteCampaignItem(Id: Integer);
var
  Query: TFDQuery;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := GetConnection;
    Query.SQL.Text := 'DELETE FROM CampaignItems WHERE CampaignItemID = :Id';
    Query.ParamByName('Id').AsInteger := Id;
    Query.ExecSQL;
    if Query.RowsAffected = 0 then
      raise Exception.CreateFmt('Campaign item with ID %d not found', [Id]);
  finally
    Query.Free;
  end;
end;
initialization
  RegisterServiceType(TCampaignItemService);

end.

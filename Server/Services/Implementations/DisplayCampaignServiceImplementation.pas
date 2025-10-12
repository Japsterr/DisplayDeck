unit DisplayCampaignServiceImplementation;

interface

uses
  XData.Server.Module,
  XData.Service.Common,
  FireDAC.Comp.Client,
  FireDAC.Stan.Param,
  Data.DB,
  uEntities,
  DisplayCampaignService;

type
  [ServiceImplementation]
  TDisplayCampaignService = class(TInterfacedObject, IDisplayCampaignService)
  private
    function GetConnection: TFDConnection;
  public
    function GetDisplayCampaigns(DisplayId: Integer): TArray<TDisplayCampaign>;
    function GetDisplayCampaign(Id: Integer): TDisplayCampaign;
    function CreateDisplayCampaign(DisplayId, CampaignId: Integer; IsPrimary: Boolean): TDisplayCampaign;
    function UpdateDisplayCampaign(Id: Integer; IsPrimary: Boolean): TDisplayCampaign;
    procedure DeleteDisplayCampaign(Id: Integer);
  end;

implementation

uses
  System.SysUtils,
  uServerContainer;

function TDisplayCampaignService.GetConnection: TFDConnection;
begin
  Result := ServerContainer.FDConnection;
end;

function TDisplayCampaignService.GetDisplayCampaigns(DisplayId: Integer): TArray<TDisplayCampaign>;
var
  Query: TFDQuery;
  List: TArray<TDisplayCampaign>;
  Item: TDisplayCampaign;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := GetConnection;
    Query.SQL.Text := 'SELECT DisplayCampaignID, DisplayID, CampaignID, IsPrimary FROM DisplayCampaigns WHERE DisplayID = :Id ORDER BY DisplayCampaignID';
    Query.ParamByName('Id').AsInteger := DisplayId;
    Query.Open;
    SetLength(List, 0);
    while not Query.Eof do
    begin
      Item := TDisplayCampaign.Create;
      Item.Id := Query.FieldByName('DisplayCampaignID').AsInteger;
      Item.DisplayId := Query.FieldByName('DisplayID').AsInteger;
      Item.CampaignId := Query.FieldByName('CampaignID').AsInteger;
      Item.IsPrimary := Query.FieldByName('IsPrimary').AsBoolean;
      SetLength(List, Length(List) + 1);
      List[High(List)] := Item;
      Query.Next;
    end;
    Result := List;
  finally
    Query.Free;
  end;
end;

function TDisplayCampaignService.GetDisplayCampaign(Id: Integer): TDisplayCampaign;
var
  Query: TFDQuery;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := GetConnection;
    Query.SQL.Text := 'SELECT DisplayCampaignID, DisplayID, CampaignID, IsPrimary FROM DisplayCampaigns WHERE DisplayCampaignID = :Id';
    Query.ParamByName('Id').AsInteger := Id;
    Query.Open;
    if Query.IsEmpty then
      raise Exception.CreateFmt('DisplayCampaign with ID %d not found', [Id]);
    Result := TDisplayCampaign.Create;
    Result.Id := Query.FieldByName('DisplayCampaignID').AsInteger;
    Result.DisplayId := Query.FieldByName('DisplayID').AsInteger;
    Result.CampaignId := Query.FieldByName('CampaignID').AsInteger;
    Result.IsPrimary := Query.FieldByName('IsPrimary').AsBoolean;
  finally
    Query.Free;
  end;
end;

function TDisplayCampaignService.CreateDisplayCampaign(DisplayId, CampaignId: Integer; IsPrimary: Boolean): TDisplayCampaign;
var
  Query: TFDQuery;
  NewId: Integer;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := GetConnection;
    Query.SQL.Text := 'INSERT INTO DisplayCampaigns (DisplayID, CampaignID, IsPrimary) VALUES (:DisplayId, :CampaignId, :IsPrimary) RETURNING DisplayCampaignID';
    Query.ParamByName('DisplayId').AsInteger := DisplayId;
    Query.ParamByName('CampaignId').AsInteger := CampaignId;
    Query.ParamByName('IsPrimary').AsBoolean := IsPrimary;
    Query.Open;
    NewId := Query.Fields[0].AsInteger;
    Result := GetDisplayCampaign(NewId);
  finally
    Query.Free;
  end;
end;

function TDisplayCampaignService.UpdateDisplayCampaign(Id: Integer; IsPrimary: Boolean): TDisplayCampaign;
var
  Query: TFDQuery;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := GetConnection;
    Query.SQL.Text := 'UPDATE DisplayCampaigns SET IsPrimary = :IsPrimary WHERE DisplayCampaignID = :Id';
    Query.ParamByName('Id').AsInteger := Id;
    Query.ParamByName('IsPrimary').AsBoolean := IsPrimary;
    Query.ExecSQL;
    if Query.RowsAffected = 0 then
      raise Exception.CreateFmt('DisplayCampaign with ID %d not found', [Id]);
    Result := GetDisplayCampaign(Id);
  finally
    Query.Free;
  end;
end;

procedure TDisplayCampaignService.DeleteDisplayCampaign(Id: Integer);
var
  Query: TFDQuery;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := GetConnection;
    Query.SQL.Text := 'DELETE FROM DisplayCampaigns WHERE DisplayCampaignID = :Id';
    Query.ParamByName('Id').AsInteger := Id;
    Query.ExecSQL;
    if Query.RowsAffected = 0 then
      raise Exception.CreateFmt('DisplayCampaign with ID %d not found', [Id]);
  finally
    Query.Free;
  end;
end;
initialization
  RegisterServiceType(TDisplayCampaignService);

end.

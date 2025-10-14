unit PlanServiceImplementation;

interface

uses
  System.SysUtils,
  XData.Server.Module,
  XData.Service.Common,
  FireDAC.Comp.Client,
  FireDAC.Stan.Param,
  Data.DB,
  uEntities,
  PlanService;

type
  [ServiceImplementation]
  TPlanService = class(TInterfacedObject, IPlanService)
  private
    function GetConnection: TFDConnection;
  public
    function GetPlans: TArray<TPlan>;
  end;

implementation


uses
  uServerContainer;

{ TPlanService }

function TPlanService.GetConnection: TFDConnection;
begin
  Result := ServerContainer.FDConnection;
end;

function TPlanService.GetPlans: TArray<TPlan>;
var
  Query: TFDQuery;
  List: TArray<TPlan>;
  P: TPlan;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := GetConnection;
    Query.SQL.Text := 'SELECT PlanID, Name, Price, MaxDisplays, MaxCampaigns, MaxMediaStorageGB, IsActive FROM Plans WHERE IsActive = TRUE ORDER BY Price';
    Query.Open;
    SetLength(List, 0);
    while not Query.Eof do
    begin
      P := TPlan.Create;
      P.Id := Query.FieldByName('PlanID').AsInteger;
      P.Name := Query.FieldByName('Name').AsString;
      P.Price := Query.FieldByName('Price').AsFloat;
      P.MaxDisplays := Query.FieldByName('MaxDisplays').AsInteger;
      P.MaxCampaigns := Query.FieldByName('MaxCampaigns').AsInteger;
      P.MaxMediaStorageGB := Query.FieldByName('MaxMediaStorageGB').AsInteger;
      P.IsActive := Query.FieldByName('IsActive').AsBoolean;
      SetLength(List, Length(List)+1);
      List[High(List)] := P;
      Query.Next;
    end;
    Result := List;
  finally
    Query.Free;
  end;
end;

initialization
  RegisterServiceType(TPlanService);

end.

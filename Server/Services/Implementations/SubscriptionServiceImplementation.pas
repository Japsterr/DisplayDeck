unit SubscriptionServiceImplementation;

interface

uses
  System.SysUtils,
  XData.Server.Module,
  XData.Service.Common,
  FireDAC.Comp.Client,
  FireDAC.Stan.Param,
  Data.DB,
  uEntities,
  SubscriptionService;

type
  [ServiceImplementation]
  TSubscriptionService = class(TInterfacedObject, ISubscriptionService)
  private
    function GetConnection: TFDConnection;
  public
    function GetSubscription(OrganizationId: Integer): TSubscription;
  end;

implementation


uses
  uServerContainer;

{ TSubscriptionService }

function TSubscriptionService.GetConnection: TFDConnection;
begin
  Result := ServerContainer.FDConnection;
end;

function TSubscriptionService.GetSubscription(OrganizationId: Integer): TSubscription;
var
  Query: TFDQuery;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := GetConnection;
    Query.SQL.Text := 'SELECT SubscriptionID, OrganizationID, PlanID, Status, CurrentPeriodEnd, TrialEndDate, CreatedAt, UpdatedAt ' +
                      'FROM Subscriptions WHERE OrganizationID = :OrgId';
    Query.ParamByName('OrgId').AsInteger := OrganizationId;
    Query.Open;
    if Query.IsEmpty then
      Exit(nil);
    Result := TSubscription.Create;
    Result.Id := Query.FieldByName('SubscriptionID').AsInteger;
    Result.OrganizationId := Query.FieldByName('OrganizationID').AsInteger;
    Result.PlanId := Query.FieldByName('PlanID').AsInteger;
    Result.Status := Query.FieldByName('Status').AsString;
    if not Query.FieldByName('CurrentPeriodEnd').IsNull then
      Result.CurrentPeriodEnd := Query.FieldByName('CurrentPeriodEnd').AsDateTime;
    if not Query.FieldByName('TrialEndDate').IsNull then
      Result.TrialEndDate := Query.FieldByName('TrialEndDate').AsDateTime;
    Result.CreatedAt := Query.FieldByName('CreatedAt').AsDateTime;
    Result.UpdatedAt := Query.FieldByName('UpdatedAt').AsDateTime;
  finally
    Query.Free;
  end;
end;

initialization
  RegisterServiceType(TSubscriptionService);

end.

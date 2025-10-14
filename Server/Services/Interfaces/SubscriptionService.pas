unit SubscriptionService;

interface

uses
  XData.Service.Common,
  uEntities;

type
  [ServiceContract]
  [Route('')]
  ISubscriptionService = interface(IInvokable)
    ['{958FC163-8304-4DFA-A8BA-C8FB353C5325}']
    [HttpGet]
    [Route('organizations/{OrganizationId}/subscription')]
    function GetSubscription(OrganizationId: Integer): TSubscription;
  end;

implementation

end.


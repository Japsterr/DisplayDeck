unit PlanService;

interface

uses
  XData.Service.Common,
  uEntities;

type
  [ServiceContract]
  [Route('')]
  IPlanService = interface(IInvokable)
    ['{7B6C5B24-40D2-4B8F-BC74-7BD71110F6C6}']
    [HttpGet]
    [Route('plans')]
    function GetPlans: TArray<TPlan>;
  end;

implementation

end.


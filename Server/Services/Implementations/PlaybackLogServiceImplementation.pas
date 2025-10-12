unit PlaybackLogServiceImplementation;

interface

uses
  XData.Server.Module,
  XData.Service.Common,
  PlaybackLogService;

type
  [ServiceImplementation]
  TPlaybackLogService = class(TInterfacedObject, IPlaybackLogService)
  end;

implementation


initialization
  RegisterServiceType(TPlaybackLogService);

end.

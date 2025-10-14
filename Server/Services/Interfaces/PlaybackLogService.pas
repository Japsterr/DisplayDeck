unit PlaybackLogService;

interface

uses
  XData.Service.Common,
  System.SysUtils;

type
  [ServiceContract]
  [Route('')]
  IPlaybackLogService = interface(IInvokable)
    ['{00CDB187-F65F-4AEB-9B3A-AF6AD672911C}']
    [HttpPost]
    [Route('playback-logs')]
    procedure LogPlayback(DisplayId, MediaFileId, CampaignId: Integer; const PlaybackTimestamp: TDateTime);
  end;

implementation

end.


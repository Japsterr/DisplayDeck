unit PlaybackLogServiceImplementation;

interface

uses
  System.SysUtils,
  XData.Server.Module,
  XData.Service.Common,
  FireDAC.Comp.Client,
  FireDAC.Stan.Param,
  Data.DB,
  PlaybackLogService;

type
  [ServiceImplementation]
  TPlaybackLogService = class(TInterfacedObject, IPlaybackLogService)
  private
    function GetConnection: TFDConnection;
  public
    procedure LogPlayback(DisplayId, MediaFileId, CampaignId: Integer; const PlaybackTimestamp: TDateTime);
  end;

implementation


uses
  uServerContainer;

{ TPlaybackLogService }

function TPlaybackLogService.GetConnection: TFDConnection;
begin
  Result := ServerContainer.FDConnection;
end;

procedure TPlaybackLogService.LogPlayback(DisplayId, MediaFileId, CampaignId: Integer; const PlaybackTimestamp: TDateTime);
var
  Query: TFDQuery;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := GetConnection;
    Query.SQL.Text := 'INSERT INTO PlaybackLogs (DisplayID, MediaFileID, CampaignID, PlaybackTimestamp) ' +
                      'VALUES (:DisplayId, :MediaFileId, :CampaignId, :PlaybackTimestamp)';
    Query.ParamByName('DisplayId').AsInteger := DisplayId;
    Query.ParamByName('MediaFileId').AsInteger := MediaFileId;
    Query.ParamByName('CampaignId').AsInteger := CampaignId;
    Query.ParamByName('PlaybackTimestamp').AsDateTime := PlaybackTimestamp;
    Query.ExecSQL;
  finally
    Query.Free;
  end;
end;

initialization
  RegisterServiceType(TPlaybackLogService);

end.

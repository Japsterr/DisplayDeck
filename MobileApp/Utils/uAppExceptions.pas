unit uAppExceptions;

interface

procedure InitAppExceptions;

implementation

uses
  System.SysUtils, FMX.Forms
{$IFDEF ANDROID}
  , Androidapi.Log
{$ENDIF}
  ;

type
  TAppExceptions = class
    class procedure HandleAppException(Sender: TObject; E: Exception);
  end;

class procedure TAppExceptions.HandleAppException(Sender: TObject; E: Exception);
begin
  // Intentionally no modal UI here to avoid lifecycle issues on Android.
  // Optionally log via platform-specific means if needed.
  {$IFDEF ANDROID}
  try
    __android_log_write(android_LogPriority.ANDROID_LOG_ERROR, 'DisplayDeck', PAnsiChar(AnsiString('Unhandled exception: ' + E.ClassName + ' - ' + E.Message)));
  except
    // swallow any logging errors
  end;
  {$ENDIF}
end;

procedure InitAppExceptions;
begin
  Application.OnException := TAppExceptions.HandleAppException;
end;

end.

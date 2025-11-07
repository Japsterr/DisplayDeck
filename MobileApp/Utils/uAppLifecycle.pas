unit uAppLifecycle;

interface

uses
  System.SysUtils, System.Classes, FMX.Forms, FMX.Types, FMX.Platform,
  FMX.DialogService;

procedure InitializeAppLifecycle;
function AppIsActive: Boolean;

implementation

uses
{$IFDEF ANDROID}
  Androidapi.Helpers, Androidapi.JNI.App, Androidapi.JNI.GraphicsContentViewText, FMX.Helpers.Android,
{$ENDIF}
  System.UITypes;

type
  TAppExceptionFilter = class(TObject)
  public
    procedure HandleAppException(Sender: TObject; E: Exception);
  end;

var
  GIsActive: Boolean = False;
  GFilter: TAppExceptionFilter = nil;

function AppIsActive: Boolean;
begin
  Result := GIsActive;
end;

procedure ShowSafeInfo(const Msg: string);
begin
{$IFDEF ANDROID}
  // Prefer Toast to avoid FragmentManager dialogs during sensitive states
  TThread.Queue(nil,
    procedure
    var Toast: JToast;
    begin
      Toast := TJToast.JavaClass.makeText(TAndroidHelper.Context, StringToJString(Msg), TJToast.JavaClass.LENGTH_SHORT);
      Toast.show;
    end);
{$ELSE}
  // On non-Android platforms, defer to platform dialog on UI thread
  TThread.Queue(nil,
    procedure
    begin
      TDialogService.PreferredMode := TDialogService.TPreferredMode.Platform;
      TDialogService.MessageDialog(Msg, TMsgDlgType.mtInformation, [TMsgDlgBtn.mbOK], TMsgDlgBtn.mbOK, 0,
        procedure(const AResult: TModalResult) begin end);
    end);
{$ENDIF}
end;

procedure TAppExceptionFilter.HandleAppException(Sender: TObject; E: Exception);
begin
  // Avoid FMX default modal dialog which can crash during lifecycle changes
  ShowSafeInfo(E.Message);
end;

procedure InitializeAppLifecycle;
var AppEvents: IFMXApplicationEventService;
begin
  // Track active state for future gating if needed
  if TPlatformServices.Current.SupportsPlatformService(IFMXApplicationEventService, IInterface(AppEvents)) then
  begin
    AppEvents.SetApplicationEventHandler(
      function(AEvent: TApplicationEvent; AContext: TObject): Boolean
      begin
        case AEvent of
          TApplicationEvent.BecameActive: GIsActive := True;
          TApplicationEvent.WillBecomeInactive,
          TApplicationEvent.EnteredBackground: GIsActive := False;
        end;
        Result := False;
      end);
  end;
  // Prevent FMX from showing blocking dialogs for unhandled exceptions
  if GFilter = nil then
    GFilter := TAppExceptionFilter.Create;
  Application.OnException := GFilter.HandleAppException;
end;

end.

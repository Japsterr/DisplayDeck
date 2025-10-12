unit uServerContainer;

interface

uses
  System.SysUtils, System.Classes, System.IOUtils, System.Variants, Winapi.Windows, Sparkle.HttpServer.Module,
  Sparkle.HttpServer.Context, Sparkle.Comp.Server,
  Sparkle.Comp.HttpSysDispatcher, XData.Server.Module,
  XData.Comp.Server, XData.Comp.ConnectionPool, FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error,
  FireDAC.UI.Intf, FireDAC.Phys.Intf, FireDAC.Stan.Def, FireDAC.Stan.Pool,
  FireDAC.Stan.Async, FireDAC.Phys, FireDAC.VCLUI.Wait, Data.DB,
  FireDAC.Comp.Client, FireDAC.Phys.PG, FireDAC.Phys.PGDef, FireDAC.DApt,
  ServiceRegistration,
  // Service implementations - ensure they are loaded and registered
  AuthServiceImplementation,
  DeviceServiceImplementation,
  CampaignItemServiceImplementation,
  CampaignServiceImplementation,
  DisplayCampaignServiceImplementation,
  DisplayServiceImplementation,
  MediaFileServiceImplementation,
  OrganizationServiceImplementation,
  PlanServiceImplementation,
  PlaybackLogServiceImplementation,
  RoleServiceImplementation,
  SubscriptionServiceImplementation,
  UserServiceImplementation;

type
  TServerContainer = class(TDataModule)
    SparkleHttpSysDispatcher: TSparkleHttpSysDispatcher;
    XDataServer: TXDataServer;
    FDConnection: TFDConnection;
    XDataConnectionPool: TXDataConnectionPool;
    procedure DataModuleCreate(Sender: TObject);
  private
      FPgDriverLink: TFDPhysPgDriverLink;
  public
    { Public declarations }
  end;

var
  ServerContainer: TServerContainer;

implementation

{%CLASSGROUP 'Vcl.Controls.TControl'}

{$R *.dfm}

procedure TServerContainer.DataModuleCreate(Sender: TObject);
var
  ArchFolder: string;
  i: Integer;
  LogMsg: string;
begin
  if SizeOf(Pointer) = 8 then
    ArchFolder := 'Win64'
  else
    ArchFolder := 'Win32';

  FPgDriverLink := TFDPhysPgDriverLink.Create(Self);
  FPgDriverLink.VendorHome := TPath.GetFullPath(
    TPath.Combine(ExtractFilePath(ParamStr(0)), '..\..\Vendor\PostgreSQL\' + ArchFolder));
  
  OutputDebugString(PChar('VendorHome: ' + FPgDriverLink.VendorHome));
  
  if not TFile.Exists(TPath.Combine(FPgDriverLink.VendorHome, 'lib\libpq.dll')) then
    raise Exception.CreateFmt(
      'PostgreSQL vendor library (libpq.dll) not found for %s in %s',[ArchFolder, TPath.Combine(FPgDriverLink.VendorHome, 'lib')]);

  // Configure FireDAC connection for PostgreSQL
  FDConnection.DriverName := 'PG';
  FDConnection.Params.Clear;
  FDConnection.Params.Add('DriverID=PG');
  FDConnection.Params.Add('Server=127.0.0.1');
  FDConnection.Params.Add('Port=5432');
  FDConnection.Params.Add('Database=displaydeck');
  FDConnection.Params.Add('User_Name=displaydeck_user');
  FDConnection.Params.Add('Password=verysecretpassword');
  FDConnection.Params.Add('CharacterSet=UTF8');
  FDConnection.LoginPrompt := False;
  
  // Log all connection parameters
  OutputDebugString(PChar('=== FireDAC Connection Parameters ==='));
  for i := 0 to FDConnection.Params.Count - 1 do
  begin
    LogMsg := FDConnection.Params[i];
    // Mask password in log
    if Pos('Password=', LogMsg) > 0 then
      LogMsg := 'Password=***MASKED***';
    OutputDebugString(PChar(LogMsg));
  end;
  OutputDebugString(PChar('=== Attempting Connection ==='));
  // Optional sanity check during startup; we don't keep the connection open
  // so repositories can establish their own per-request connections.
  {
  try
    OutputDebugString(PChar('Connecting to PostgreSQL...'));
    FDConnection.Connected := True;
    OutputDebugString(PChar('Connection successful! ServerVersion: ' + VarToStr(FDConnection.ExecSQLScalar('SELECT version()'))));
    FDConnection.Connected := False;
    OutputDebugString(PChar('Connection closed.'));
  except
    on E: Exception do
    begin
      OutputDebugString(PChar('Connection failed: ' + E.Message));
      raise Exception.CreateFmt('Database connection failed: %s', [E.Message]);
    end;
  end;
  }
  OutputDebugString(PChar('Skipping connection test - will connect on first request'));

  // Register all services AFTER XData server and database are configured
  RegisterAllServices(XDataServer, FDConnection);
  
  // Now activate the HTTP dispatcher to start listening
  SparkleHttpSysDispatcher.Active := True;
end;

end.

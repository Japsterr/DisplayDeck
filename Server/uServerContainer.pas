unit uServerContainer;

interface

uses
  System.SysUtils, System.Classes, System.IOUtils, System.Variants, Winapi.Windows, Sparkle.HttpServer.Module,
  Sparkle.HttpServer.Context, Sparkle.Comp.Server,
  Sparkle.Comp.HttpSysDispatcher, XData.Server.Module,
  XData.Comp.Server, XData.Comp.ConnectionPool, XData.Service.Common, FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error,
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
  UserServiceImplementation,
  HealthServiceImplementation;

type
  TServerContainer = class(TDataModule)
    SparkleHttpSysDispatcher: TSparkleHttpSysDispatcher;
    XDataServer: TXDataServer;
    FDConnection: TFDConnection;
    XDataConnectionPool: TXDataConnectionPool;
    procedure DataModuleCreate(Sender: TObject);
  private
    FPgDriverLink: TFDPhysPgDriverLink;
    procedure LogToFile(const FileName, Msg: string);
    procedure ConfigureXDataServer;
  public
    { Public declarations }
  end;

var
  ServerContainer: TServerContainer;

implementation

{%CLASSGROUP 'Vcl.Controls.TControl'}

{$R *.dfm}

procedure TServerContainer.ConfigureXDataServer;
begin
  // Attribute-based registration is handled via [ServiceImplementation] and unit initialization.
  // TXDataServer visual component doesn't expose Options; keep defaults here.
end;

procedure TServerContainer.DataModuleCreate(Sender: TObject);
var
  ArchFolder: string;
  i: Integer;
  LogMsg: string;
  VendorLibPath: string;
begin
  ConfigureXDataServer;

  if SizeOf(Pointer) = 8 then
    ArchFolder := 'Win64'
  else
    ArchFolder := 'Win32';

  FPgDriverLink := TFDPhysPgDriverLink.Create(Self);
  FPgDriverLink.VendorHome := TPath.GetFullPath(
    TPath.Combine(ExtractFilePath(ParamStr(0)), '..\..\Vendor\PostgreSQL\' + ArchFolder));
    VendorLibPath := TPath.Combine(FPgDriverLink.VendorHome, 'lib\libpq.dll');
    // FireDAC builds path as VendorHome + "\\lib\\" + VendorLib; keep VendorLib as file name only
    FPgDriverLink.VendorLib := 'libpq.dll';
  
  OutputDebugString(PChar('VendorHome: ' + FPgDriverLink.VendorHome));
    OutputDebugString(PChar('VendorLib: ' + FPgDriverLink.VendorLib));
  
  if not TFile.Exists(VendorLibPath) then
    raise Exception.CreateFmt(
      'PostgreSQL vendor library (libpq.dll) not found for %s in %s',[ArchFolder, TPath.Combine(FPgDriverLink.VendorHome, 'lib')]);

  // Configure FireDAC connection for PostgreSQL
  FDConnection.DriverName := 'PG';
  FDConnection.Params.Clear;
  FDConnection.Params.Add('DriverID=PG');
  // Use docker host mapping; 127.0.0.1 is fine but pg_hba is trust; provide password as fallback
  FDConnection.Params.Add('Server=127.0.0.1');
  FDConnection.Params.Add('Port=5433');
  FDConnection.Params.Add('Database=displaydeck');
  FDConnection.Params.Add('User_Name=api_user');
  FDConnection.Params.Add('Password=api123');
  FDConnection.Params.Add('CharacterSet=UTF8');
  FDConnection.Params.Add('SSLMode=disable');
  FDConnection.Params.Add('LoginTimeout=5');
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
  OutputDebugString(PChar('=== Performing database connection self-test ==='));
  try
    FDConnection.Connected := True;
    FDConnection.Connected := False;
    OutputDebugString(PChar('DB self-test: SUCCESS'));
    LogToFile('server_output.log', FormatDateTime('yyyy-mm-dd hh:nn:ss', Now) + ' DB self-test: SUCCESS');
  except
    on E: Exception do
    begin
      OutputDebugString(PChar('DB self-test: FAILED - ' + E.Message));
      LogToFile('server_error.log', FormatDateTime('yyyy-mm-dd hh:nn:ss', Now) + ' DB self-test FAILED: ' + E.Message);
    end;
  end;

  // Actually test the database connection and log to file
  try
    FDConnection.Connected := True;
    OutputDebugString(PChar('=== Database connection successful ==='));
    TFile.AppendAllText(TPath.Combine(ExtractFilePath(ParamStr(0)), 'database_test.log'), 
      FormatDateTime('yyyy-mm-dd hh:nn:ss', Now) + ': Database connection successful' + sLineBreak);
  except
    on E: Exception do
    begin
      OutputDebugString(PChar('=== Database connection failed: ' + E.Message + ' ==='));
      TFile.AppendAllText(TPath.Combine(ExtractFilePath(ParamStr(0)), 'database_test.log'), 
        FormatDateTime('yyyy-mm-dd hh:nn:ss', Now) + ': Database connection failed: ' + E.Message + sLineBreak);
      // Don't raise exception, continue with service registration
    end;
  end;
  // RegisterAllServices is no longer needed as services are registered
  // in the initialization section of their respective implementation units.

  // Now activate the HTTP dispatcher to start listening
  SparkleHttpSysDispatcher.Active := True;
end;

procedure TServerContainer.LogToFile(const FileName, Msg: string);
var
  FullPath: string;
begin
  try
    FullPath := TPath.Combine(ExtractFilePath(ParamStr(0)), FileName);
    TFile.AppendAllText(FullPath, Msg + sLineBreak, TEncoding.UTF8);
  except
    // ignore
  end;
end;

end.

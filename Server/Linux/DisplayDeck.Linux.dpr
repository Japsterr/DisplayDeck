program DisplayDeckLinux;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.StrUtils,
  Sparkle.HttpServer.Server,
  Sparkle.HttpServer.Module,
  XData.Server.Module,
  XData.Comp.ConnectionPool,
  FireDAC.Comp.Client,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error,
  FireDAC.Phys.Intf, FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Stan.Async,
  FireDAC.Phys, FireDAC.Phys.PG, FireDAC.Phys.PGDef, FireDAC.DApt,
  // Bring service implementations so they self-register
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
  HealthServiceImplementation,
  uServerContainer;

function GetEnv(const Name, Default: string): string;
begin
  Result := GetEnvironmentVariable(Name);
  if Result = '' then Result := Default;
end;

var
  HttpServer: TSparkleHttpServer;
  XDataModule: TXDataServerModule;
  Pool: TXDataConnectionPool;
  Conn: TFDConnection;
  BaseUrl: string;
begin
  try
    // FireDAC connection (Linux: rely on system libpq.so.5, no VendorLib set)
    Conn := TFDConnection.Create(nil);
    Conn.DriverName := 'PG';
    Conn.Params.Add('DriverID=PG');
    Conn.Params.Add('Server=' + GetEnv('DB_HOST', 'postgres'));
    Conn.Params.Add('Port=' + GetEnv('DB_PORT', '5432'));
    Conn.Params.Add('Database=' + GetEnv('DB_NAME', 'displaydeck'));
    Conn.Params.Add('User_Name=' + GetEnv('DB_USER', 'displaydeck_user'));
    Conn.Params.Add('Password=' + GetEnv('DB_PASSWORD', 'verysecretpassword'));
    Conn.Params.Add('CharacterSet=UTF8');
    Conn.Params.Add('SSLMode=disable');
    Conn.LoginPrompt := False;

    // Global container for services to access FDConnection
    ServerContainer := TServerContainer.Create;
    ServerContainer.FDConnection := Conn;

    // XData connection pool
    Pool := TXDataConnectionPool.Create(nil);
    Pool.Connection := Conn;

    // XData module (base URL)
    BaseUrl := 'http://+:2001/tms/xdata';
    XDataModule := TXDataServerModule.Create('xdata', BaseUrl);
    XDataModule.Model.Connection := Conn;
    XDataModule.Model.ConnectionPool := Pool;

    // Sparkle HTTP server (cross-platform)
    HttpServer := TSparkleHttpServer.Create;
    HttpServer.AddModule(XDataModule);
    HttpServer.Active := True;

    Writeln('DisplayDeck Linux server started at ' + BaseUrl);
    Writeln('Press Ctrl+C to stop.');
    while True do
      TThread.Sleep(1000);
  except
    on E: Exception do
    begin
      Writeln('Fatal error: ' + E.ClassName + ': ' + E.Message);
      Halt(1);
    end;
  end;
end.

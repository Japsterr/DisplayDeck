program DisplayDeck;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Types,
  System.JSON,
  Web.HTTPApp,
  Web.ReqMulti,
  Web.WebReq,
  Web.WebBroker,
  IdHTTPWebBrokerBridge,
  FireDAC.Comp.Client,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error,
  FireDAC.Phys.Intf, FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Stan.Async,
  FireDAC.Phys, FireDAC.Phys.PG, FireDAC.Phys.PGDef, FireDAC.DApt,
  FireDAC.ConsoleUI.Wait,
  uServerContainer,
  WebModuleMain in 'WebModuleMain.pas';

function GetEnv(const Name, Default: string): string;
begin
  Result := GetEnvironmentVariable(Name);
  if Result = '' then Result := Default;
end;

var
  Server: TIdHTTPWebBrokerBridge;
  Conn: TFDConnection;
  PgLink: TFDPhysPgDriverLink;
  Port: Integer;
  StartTs: Cardinal;
  Connected: Boolean;
begin
  try
    // Initialize shared FireDAC connection
    Conn := TFDConnection.Create(nil);
    Conn.DriverName := 'PG';
    Conn.Params.Clear;
    Conn.Params.Add('DriverID=PG');
    Conn.Params.Add('Server=' + GetEnv('DB_HOST', 'postgres'));
    Conn.Params.Add('Port=' + GetEnv('DB_PORT', '5432'));
    Conn.Params.Add('Database=' + GetEnv('DB_NAME', 'displaydeck'));
    Conn.Params.Add('User_Name=' + GetEnv('DB_USER', 'displaydeck_user'));
    Conn.Params.Add('Password=' + GetEnv('DB_PASSWORD', 'verysecretpassword'));
    Conn.Params.Add('CharacterSet=UTF8');
    Conn.Params.Add('SSLMode=disable');
    Conn.LoginPrompt := False;

    // Ensure FireDAC PG driver loads the correct vendor library on Debian
    PgLink := TFDPhysPgDriverLink.Create(nil);
    // libpq5 package provides libpq.so.5 in Debian bookworm
    PgLink.VendorLib := 'libpq.so.5';

    // Retry loop awaiting Postgres readiness
    Writeln('Connecting to Postgres at ' + Conn.Params.Values['Server'] + ':' + Conn.Params.Values['Port'] + ' db=' + Conn.Params.Values['Database'] + ' ...');
    Connected := False;
    StartTs := TThread.GetTickCount;
    while not Connected do
    begin
      try
        Conn.Connected := True;
        Connected := True;
      except
        on E: Exception do
        begin
          if (TThread.GetTickCount - StartTs) > 60000 then
            raise;
          Writeln('Waiting for Postgres: ' + E.Message);
          TThread.Sleep(1000);
        end;
      end;
    end;
    Writeln('Connected to Postgres successfully.');

    // Ensure provisioning tokens table exists for device pairing workflow
    var Q := TFDQuery.Create(nil);
    try
      Q.Connection := Conn;
      Q.SQL.Text :=
        'CREATE TABLE IF NOT EXISTS ProvisioningTokens ('+
        '  Token VARCHAR(255) PRIMARY KEY,'+
        '  HardwareId VARCHAR(255),'+
        '  CreatedAt TIMESTAMPTZ NOT NULL DEFAULT NOW(),'+
        '  ExpiresAt TIMESTAMPTZ NOT NULL,'+
        '  Claimed BOOLEAN NOT NULL DEFAULT FALSE,'+
        '  DisplayID INT NULL REFERENCES Displays(DisplayID) ON DELETE SET NULL,'+
        '  OrganizationID INT NULL REFERENCES Organizations(OrganizationID) ON DELETE SET NULL'+
        ');'+
        'CREATE INDEX IF NOT EXISTS idx_provtokens_expires ON ProvisioningTokens(ExpiresAt);';
      Q.ExecSQL;
    finally
      Q.Free;
    end;

    // Publish globally so repositories can clone params
    ServerContainer := TServerContainer.Create;
    ServerContainer.FDConnection := Conn;

    // Start WebBroker/Indy server
    Port := StrToIntDef(GetEnv('PORT', '2001'), 2001);
    if WebRequestHandler <> nil then
      WebRequestHandler.WebModuleClass := WebModuleClass;
    Server := TIdHTTPWebBrokerBridge.Create(nil);
    try
      Server.DefaultPort := Port;
      Server.Active := True;
      Writeln(Format('DisplayDeck WebBroker server listening on http://0.0.0.0:%d', [Port]));
      Writeln('Endpoints: /health, /organizations, /organizations/{id}');
      while True do
        TThread.Sleep(1000);
    finally
      Server.Active := False;
      Server.Free;
    end;
  except
    on E: Exception do
    begin
      Writeln('Fatal: ' + E.ClassName + ' - ' + E.Message);
      Halt(1);
    end;
  end;
end.

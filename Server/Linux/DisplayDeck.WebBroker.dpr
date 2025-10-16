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
  IdHTTPWebBrokerBridge,
  FireDAC.Comp.Client,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error,
  FireDAC.Phys.Intf, FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Stan.Async,
  FireDAC.Phys, FireDAC.Phys.PG, FireDAC.Phys.PGDef, FireDAC.DApt,
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
  Port: Integer;
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
    Conn.Connected := True;

    // Publish globally so repositories can clone params
    ServerContainer := TServerContainer.Create;
    ServerContainer.FDConnection := Conn;

    // Start WebBroker/Indy server
    Port := StrToIntDef(GetEnv('PORT', '2001'), 2001);
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

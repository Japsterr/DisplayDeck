unit uServerContainer;

interface

uses
  System.SysUtils, System.Classes, Sparkle.HttpServer.Module,
  Sparkle.HttpServer.Context, Sparkle.Comp.Server,
  Sparkle.Comp.HttpSysDispatcher, Aurelius.Drivers.Interfaces,
  Aurelius.Comp.Connection, XData.Comp.ConnectionPool, XData.Server.Module,
  XData.Comp.Server, FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error,
  FireDAC.UI.Intf, FireDAC.Phys.Intf, FireDAC.Stan.Def, FireDAC.Stan.Pool,
  FireDAC.Stan.Async, FireDAC.Phys, FireDAC.VCLUI.Wait, Data.DB,
  FireDAC.Comp.Client, FireDAC.Phys.PG, FireDAC.Phys.PGDef;

type
  TServerContainer = class(TDataModule)
    SparkleHttpSysDispatcher: TSparkleHttpSysDispatcher;
    XDataServer: TXDataServer;
    XDataConnectionPool: TXDataConnectionPool;
    AureliusConnection: TAureliusConnection;
    FDConnection: TFDConnection;
    procedure DataModuleCreate(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  ServerContainer: TServerContainer;

implementation

{%CLASSGROUP 'Vcl.Controls.TControl'}

{$R *.dfm}

procedure TServerContainer.DataModuleCreate(Sender: TObject);
begin
  // Configure FireDAC connection for PostgreSQL
  FDConnection.DriverName := 'PG';
  FDConnection.Params.Values['Server'] := 'localhost';
  FDConnection.Params.Values['Port'] := '5432';
  FDConnection.Params.Values['Database'] := 'displaydeck';
  FDConnection.Params.Values['User_Name'] := 'postgres';
  FDConnection.Params.Values['Password'] := 'admin';
  FDConnection.LoginPrompt := False;

  // Configure Aurelius to use the FireDAC connection
  AureliusConnection.AdapterName := 'FireDAC';
  AureliusConnection.SQLDialect := 'PostgreSQL';
  AureliusConnection.AdaptedConnection := FDConnection;

  // The XDataConnectionPool will use the AureliusConnection
  // No need to test connection here, the pool will handle it.
end;

end.

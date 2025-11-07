unit uApiClient;

interface

uses System.SysUtils, System.Classes, System.Net.HttpClient, System.Net.URLClient,
     System.JSON, uAppConfig;

type
  TApiClient = class
  private
    FClient: THTTPClient;
    FToken: string;
  public
    constructor Create;
    destructor Destroy; override;
    procedure SetToken(const AToken: string);
    function Get(const Path: string): string;
    function PostJson(const Path: string; const Body: TJSONObject): string;
  end;

function ApiClient: TApiClient;

implementation

var GClient: TApiClient;

constructor TApiClient.Create;
begin
  FClient := THTTPClient.Create;
end;

destructor TApiClient.Destroy;
begin
  FClient.Free;
  inherited;
end;

procedure TApiClient.SetToken(const AToken: string);
begin
  FToken := AToken;
end;

function TApiClient.Get(const Path: string): string;
var Resp: IHTTPResponse;
    Url: string;
begin
  Url := TAppConfig.BaseUrl + Path;
  if FToken <> '' then
    FClient.CustomHeaders['Authorization'] := 'Bearer ' + FToken
  else
    FClient.CustomHeaders['Authorization'] := '';
  Resp := FClient.Get(Url);
  Result := Resp.ContentAsString(TEncoding.UTF8);
end;

function TApiClient.PostJson(const Path: string; const Body: TJSONObject): string;
var Resp: IHTTPResponse;
    Url: string;
    Stream: TStringStream;
begin
  Url := TAppConfig.BaseUrl + Path;
  if FToken <> '' then
    FClient.CustomHeaders['Authorization'] := 'Bearer ' + FToken
  else
    FClient.CustomHeaders['Authorization'] := '';
  Stream := TStringStream.Create(Body.ToJSON, TEncoding.UTF8);
  try
    Resp := FClient.Post(Url, Stream, nil, [TNetHeader.Create('Content-Type','application/json')]);
    Result := Resp.ContentAsString(TEncoding.UTF8);
  finally
    Stream.Free;
  end;
end;

function ApiClient: TApiClient;
begin
  if GClient = nil then GClient := TApiClient.Create;
  Result := GClient;
end;

end.

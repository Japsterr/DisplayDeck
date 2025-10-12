unit uApiClient;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  System.Net.URLClient, System.Net.HttpClient, System.Net.HttpClientComponent,
  System.JSON, REST.Types, REST.Client, REST.Authenticator.OAuth,
  uEntities;

type
  TApiClient = class
  private
    FHttpClient: TNetHTTPClient;
    FBaseUrl: string;
    FAuthToken: string;
    class var FInstance: TApiClient;
    constructor Create;
  public
    destructor Destroy; override;
    class function Instance: TApiClient;

    property AuthToken: string read FAuthToken write FAuthToken;
    property BaseUrl: string read FBaseUrl write FBaseUrl;

    // Authentication
    function Register(Request: TRegisterRequest): TAuthResponse;
    function Login(Request: TLoginRequest): TAuthResponse;

    // Campaigns
    function GetCampaigns: TCampaignListResponse;
    function CreateCampaign(Request: TCreateCampaignRequest): TCampaignResponse;
    function UpdateCampaign(CampaignId: Integer; Request: TUpdateCampaignRequest): TCampaignResponse;
    function DeleteCampaign(CampaignId: Integer): TApiResponse;

    // Media Files
    function GetMediaFiles: TMediaFileListResponse;
    function UploadMediaFile(FileName, ContentType: string; FileStream: TStream): TMediaFileResponse;
    function DeleteMediaFile(FileId: string): TApiResponse;

    // Displays
    function GetDisplays: TDisplayListResponse;
    function RegisterDisplay(Request: TRegisterDisplayRequest): TDisplayResponse;
    function UpdateDisplay(DisplayId: Integer; Request: TUpdateDisplayRequest): TDisplayResponse;
    function DeleteDisplay(DisplayId: Integer): TApiResponse;

    // Display Campaigns (assignments)
    function GetDisplayCampaigns(DisplayId: Integer): TDisplayCampaignListResponse;
    function AssignCampaign(Request: TAssignCampaignRequest): TDisplayCampaignResponse;
    function UnassignCampaign(AssignmentId: Integer): TApiResponse;

  private
    function MakeRequest(Method, Endpoint: string; RequestBody: TJSONObject = nil): TJSONObject;
    function ParseAuthResponse(JSON: TJSONObject): TAuthResponse;
    function ParseApiResponse(JSON: TJSONObject): TApiResponse;
    function CreateAuthHeaders: TNetHeaders;
  end;

implementation

{ TApiClient }

constructor TApiClient.Create;
begin
  inherited;
  FHttpClient := TNetHTTPClient.Create(nil);
  FBaseUrl := 'http://localhost:2001/tms/xdata'; // Default for development
end;

destructor TApiClient.Destroy;
begin
  FHttpClient.Free;
  inherited;
end;

class function TApiClient.Instance: TApiClient;
begin
  if FInstance = nil then
    FInstance := TApiClient.Create;
  Result := FInstance;
end;

function TApiClient.MakeRequest(Method, Endpoint: string; RequestBody: TJSONObject = nil): TJSONObject;
var
  Url: string;
  RequestStream: TStringStream;
  ResponseStream: TStringStream;
  Headers: TNetHeaders;
begin
  Result := nil;
  Url := FBaseUrl + Endpoint;

  Headers := CreateAuthHeaders;

  RequestStream := nil;
  ResponseStream := TStringStream.Create;

  try
    if RequestBody <> nil then
    begin
      RequestStream := TStringStream.Create(RequestBody.ToString);
      Headers := Headers + [TNetHeader.Create('Content-Type', 'application/json')];
    end;

    case Method of
      'GET': FHttpClient.Get(Url, ResponseStream, Headers);
      'POST': FHttpClient.Post(Url, RequestStream, ResponseStream, Headers);
      'PUT': FHttpClient.Put(Url, RequestStream, ResponseStream, Headers);
      'DELETE': FHttpClient.Delete(Url, ResponseStream, Headers);
    end;

    if ResponseStream.Size > 0 then
    begin
      Result := TJSONObject.ParseJSONValue(ResponseStream.DataString) as TJSONObject;
    end;

  finally
    RequestStream.Free;
    ResponseStream.Free;
  end;
end;

function TApiClient.CreateAuthHeaders: TNetHeaders;
begin
  if FAuthToken.IsEmpty then
    Result := []
  else
    Result := [TNetHeader.Create('Authorization', 'Bearer ' + FAuthToken)];
end;

function TApiClient.Register(Request: TRegisterRequest): TAuthResponse;
var
  JSON: TJSONObject;
  Response: TJSONObject;
begin
  JSON := TJSONObject.Create;
  try
    JSON.AddPair('Email', Request.Email);
    JSON.AddPair('Password', Request.Password);
    JSON.AddPair('OrganizationName', Request.OrganizationName);

    Response := MakeRequest('POST', '/AuthService/Register', JSON);
    try
      Result := ParseAuthResponse(Response);
    finally
      Response.Free;
    end;
  finally
    JSON.Free;
  end;
end;

function TApiClient.Login(Request: TLoginRequest): TAuthResponse;
var
  JSON: TJSONObject;
  Response: TJSONObject;
begin
  JSON := TJSONObject.Create;
  try
    JSON.AddPair('Email', Request.Email);
    JSON.AddPair('Password', Request.Password);

    Response := MakeRequest('POST', '/AuthService/Login', JSON);
    try
      Result := ParseAuthResponse(Response);
    finally
      Response.Free;
    end;
  finally
    JSON.Free;
  end;
end;

function TApiClient.GetCampaigns: TCampaignListResponse;
var
  Response: TJSONObject;
begin
  Response := MakeRequest('GET', '/CampaignService/GetCampaigns');
  try
    Result := TCampaignListResponse.Create;
    // Parse response - implementation would depend on actual API response format
    // For now, return empty list
  finally
    Response.Free;
  end;
end;

function TApiClient.CreateCampaign(Request: TCreateCampaignRequest): TCampaignResponse;
var
  JSON: TJSONObject;
  Response: TJSONObject;
begin
  JSON := TJSONObject.Create;
  try
    JSON.AddPair('Name', Request.Name);
    JSON.AddPair('Description', Request.Description);
    // Add items array

    Response := MakeRequest('POST', '/CampaignService/CreateCampaign', JSON);
    try
      Result := TCampaignResponse.Create;
      // Parse response
    finally
      Response.Free;
    end;
  finally
    JSON.Free;
  end;
end;

function TApiClient.UpdateCampaign(CampaignId: Integer; Request: TUpdateCampaignRequest): TCampaignResponse;
begin
  // Implementation for updating campaign
  Result := nil;
end;

function TApiClient.DeleteCampaign(CampaignId: Integer): TApiResponse;
begin
  // Implementation for deleting campaign
  Result := nil;
end;

function TApiClient.GetMediaFiles: TMediaFileListResponse;
begin
  // Implementation for getting media files
  Result := nil;
end;

function TApiClient.UploadMediaFile(FileName, ContentType: string; FileStream: TStream): TMediaFileResponse;
begin
  // Implementation for uploading media file
  Result := nil;
end;

function TApiClient.DeleteMediaFile(FileId: string): TApiResponse;
begin
  // Implementation for deleting media file
  Result := nil;
end;

function TApiClient.GetDisplays: TDisplayListResponse;
begin
  // Implementation for getting displays
  Result := nil;
end;

function TApiClient.RegisterDisplay(Request: TRegisterDisplayRequest): TDisplayResponse;
begin
  // Implementation for registering display
  Result := nil;
end;

function TApiClient.UpdateDisplay(DisplayId: Integer; Request: TUpdateDisplayRequest): TDisplayResponse;
begin
  // Implementation for updating display
  Result := nil;
end;

function TApiClient.DeleteDisplay(DisplayId: Integer): TApiResponse;
begin
  // Implementation for deleting display
  Result := nil;
end;

function TApiClient.GetDisplayCampaigns(DisplayId: Integer): TDisplayCampaignListResponse;
begin
  // Implementation for getting display campaigns
  Result := nil;
end;

function TApiClient.AssignCampaign(Request: TAssignCampaignRequest): TDisplayCampaignResponse;
begin
  // Implementation for assigning campaign to display
  Result := nil;
end;

function TApiClient.UnassignCampaign(AssignmentId: Integer): TApiResponse;
begin
  // Implementation for unassigning campaign from display
  Result := nil;
end;

function TApiClient.ParseAuthResponse(JSON: TJSONObject): TAuthResponse;
begin
  Result := TAuthResponse.Create;
  if JSON <> nil then
  begin
    Result.Success := JSON.GetValue<Boolean>('Success', False);
    Result.Message := JSON.GetValue<string>('Message', '');
    Result.Token := JSON.GetValue<string>('Token', '');

    if JSON.GetValue('User') is TJSONObject then
    begin
      Result.User := TUser.Create;
      // Parse user object
    end;
  end;
end;

function TApiClient.ParseApiResponse(JSON: TJSONObject): TApiResponse;
begin
  Result := TApiResponse.Create;
  if JSON <> nil then
  begin
    Result.Success := JSON.GetValue<Boolean>('Success', False);
    Result.Message := JSON.GetValue<string>('Message', '');
  end;
end;

initialization

finalization
  if Assigned(FInstance) then
    FInstance.Free;

end.
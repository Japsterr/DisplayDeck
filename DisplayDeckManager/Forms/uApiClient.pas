unit uApiClient;

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.Net.HttpClient,
  System.Net.URLClient, FMX.Dialogs;

type
  // Response wrapper types
  TApiResponse = record
    Success: Boolean;
    Data: TJSONValue;
    ErrorMessage: string;
    StatusCode: Integer;
  end;

  // Auth responses
  TLoginResponse = record
    Success: Boolean;
    Token: string;
    UserId: Integer;
    UserEmail: string;
    UserName: string;
    OrganizationId: Integer;
    OrganizationName: string;
    Message: string;
  end;

  TRegisterResponse = record
    Success: Boolean;
    Token: string;
    UserId: Integer;
    OrganizationId: Integer;
    Message: string;
  end;

  // Entity types
  TDisplayData = record
    Id: Integer;
    OrganizationId: Integer;
    Name: string;
    Orientation: string;
    LastSeen: string;
    CurrentStatus: string;
    ProvisioningToken: string;
    CreatedAt: string;
    UpdatedAt: string;
  end;

  TCampaignData = record
    Id: Integer;
    OrganizationId: Integer;
    Name: string;
    Orientation: string;
    CreatedAt: string;
    UpdatedAt: string;
  end;

  TMediaFileData = record
    Id: Integer;
    OrganizationId: Integer;
    FileName: string;
    FileType: string;
    FileSize: Int64;
    Duration: Integer;
    StorageURL: string;
    Tags: string;
    CreatedAt: string;
    UpdatedAt: string;
  end;

  TMediaUploadResponse = record
    Success: Boolean;
    MediaFileId: Integer;
    UploadUrl: string;
    StorageKey: string;
    Message: string;
  end;

  // Singleton API Client
  TApiClient = class
  private
    FHttpClient: THTTPClient;
    FBaseURL: string;
    FAuthToken: string;
    FLastURL: string;
    FLastResponseCode: Integer;
    FLastResponseBody: string;
    class var FInstance: TApiClient;
    constructor Create;
    function DoRequest(const AMethod, APath: string; ABody: TJSONObject = nil): TApiResponse;
    function ParseError(const AResponse: IHTTPResponse): string;
  public
    destructor Destroy; override;
    class function Instance: TApiClient;
    class procedure ReleaseInstance;

    // Configuration
    procedure SetBaseURL(const AURL: string);
    procedure SetAuthToken(const AToken: string);
    function GetAuthToken: string;
    
    // Debug properties
    property LastURL: string read FLastURL;
    property LastResponseCode: Integer read FLastResponseCode;
    property LastResponseBody: string read FLastResponseBody;

    // Auth endpoints
    function Login(const AEmail, APassword: string): TLoginResponse;
    function Register(const AEmail, APassword, AOrgName: string): TRegisterResponse;

    // Display endpoints
    function GetDisplays(AOrganizationId: Integer): TArray<TDisplayData>;
    function GetDisplay(ADisplayId: Integer): TDisplayData;
    function CreateDisplay(AOrganizationId: Integer; const AName, AOrientation: string): TDisplayData;
    function UpdateDisplay(const ADisplay: TDisplayData): TDisplayData;
    function DeleteDisplay(ADisplayId: Integer): Boolean;

    // Campaign endpoints
    function GetCampaigns(AOrganizationId: Integer): TArray<TCampaignData>;
    function GetCampaign(ACampaignId: Integer): TCampaignData;
    function CreateCampaign(AOrganizationId: Integer; const AName, AOrientation: string): TCampaignData;
    function UpdateCampaign(const ACampaign: TCampaignData): TCampaignData;
    function DeleteCampaign(ACampaignId: Integer): Boolean;

    // Media endpoints
    function GetMediaFiles(AOrganizationId: Integer): TArray<TMediaFileData>;
    function RequestMediaUpload: TMediaUploadResponse;
    function UploadMediaFile(const AUploadUrl, AFilePath: string): Boolean;
    function GetMediaDownloadUrl(AMediaFileId: Integer): string;
  end;

implementation

uses
  System.NetEncoding;

{ TApiClient }

constructor TApiClient.Create;
begin
  inherited;
  FHttpClient := THTTPClient.Create;
  FBaseURL := 'http://localhost:2001';
  FAuthToken := '';
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

class procedure TApiClient.ReleaseInstance;
begin
  if FInstance <> nil then
  begin
    FInstance.Free;
    FInstance := nil;
  end;
end;

procedure TApiClient.SetBaseURL(const AURL: string);
begin
  FBaseURL := AURL;
end;

procedure TApiClient.SetAuthToken(const AToken: string);
begin
  FAuthToken := AToken;
end;

function TApiClient.GetAuthToken: string;
begin
  Result := FAuthToken;
end;

function TApiClient.ParseError(const AResponse: IHTTPResponse): string;
var
  JsonObj: TJSONObject;
  ErrorObj: TJSONObject;
begin
  Result := 'Unknown error';
  try
    JsonObj := TJSONObject.ParseJSONValue(AResponse.ContentAsString) as TJSONObject;
    if Assigned(JsonObj) then
    try
      if JsonObj.TryGetValue<TJSONObject>('error', ErrorObj) then
        Result := ErrorObj.GetValue<string>('message', 'Unknown error')
      else
        Result := AResponse.ContentAsString;
    finally
      JsonObj.Free;
    end;
  except
    Result := AResponse.ContentAsString;
  end;
end;

function TApiClient.DoRequest(const AMethod, APath: string; ABody: TJSONObject = nil): TApiResponse;
var
  Response: IHTTPResponse;
  URL: string;
  RequestStream: TStringStream;
  OwnsBody: Boolean;
begin
  Result.Success := False;
  Result.Data := nil;
  Result.ErrorMessage := '';
  Result.StatusCode := 0;
  
  URL := FBaseURL + APath;
  
  // Add token as query parameter if present (fallback for THTTPClient CustomHeaders issues)
  if FAuthToken <> '' then
  begin
    // Don't URL encode - JWT tokens are already URL-safe (base64url encoding)
    if Pos('?', URL) > 0 then
      URL := URL + '&access_token=' + FAuthToken
    else
      URL := URL + '?access_token=' + FAuthToken;
  end;
  
  FLastURL := URL;
  RequestStream := nil;
  OwnsBody := False;
  
  try
    // Set content type first
    FHttpClient.ContentType := 'application/json';
    
    // Also try setting headers (may not work in all cases)
    if FAuthToken <> '' then
    begin
      FHttpClient.CustomHeaders['X-Auth-Token'] := FAuthToken;
      FHttpClient.CustomHeaders['Authorization'] := 'Bearer ' + FAuthToken;
    end;
    
    // Prepare request body
    if Assigned(ABody) then
    begin
      RequestStream := TStringStream.Create(ABody.ToJSON, TEncoding.UTF8);
    end;
    
    // Execute request
    if AMethod = 'GET' then
      Response := FHttpClient.Get(URL)
    else if AMethod = 'POST' then
      Response := FHttpClient.Post(URL, RequestStream)
    else if AMethod = 'PUT' then
      Response := FHttpClient.Put(URL, RequestStream)
    else if AMethod = 'DELETE' then
      Response := FHttpClient.Delete(URL)
    else
      raise Exception.Create('Unsupported HTTP method: ' + AMethod);
    
    Result.StatusCode := Response.StatusCode;
    FLastResponseCode := Response.StatusCode;
    FLastResponseBody := Response.ContentAsString;
    
    // Handle response
    if (Response.StatusCode >= 200) and (Response.StatusCode < 300) then
    begin
      Result.Success := True;
      if Response.ContentAsString <> '' then
      begin
        try
          Result.Data := TJSONObject.ParseJSONValue(Response.ContentAsString);
        except
          on E: Exception do
          begin
            Result.Success := False;
            Result.ErrorMessage := 'JSON parse error: ' + E.Message;
          end;
        end;
      end;
    end
    else
    begin
      Result.Success := False;
      Result.ErrorMessage := ParseError(Response);
    end;
    
  except
    on E: Exception do
    begin
      Result.Success := False;
      Result.ErrorMessage := E.Message;
      // DEBUG: Show exception that's being swallowed
      ShowMessage('HTTP Request Exception: ' + E.Message + #13#10 + 
        'Class: ' + E.ClassName + #13#10 +
        'URL: ' + URL);
    end;
  end;
  
  if Assigned(RequestStream) then
    RequestStream.Free;
end;

function TApiClient.Login(const AEmail, APassword: string): TLoginResponse;
var
  RequestBody: TJSONObject;
  Response: TApiResponse;
  UserObj: TJSONObject;
  OrgObj: TJSONObject;
begin
  Result.Success := False;
  Result.Token := '';
  Result.Message := '';
  Result.UserId := 0;
  Result.OrganizationId := 0;
  Result.UserEmail := '';
  Result.UserName := '';
  Result.OrganizationName := '';
  
  RequestBody := TJSONObject.Create;
  try
    RequestBody.AddPair('Email', AEmail);
    RequestBody.AddPair('Password', APassword);
    
    Response := DoRequest('POST', '/auth/login', RequestBody);
    
    if Response.Success and Assigned(Response.Data) then
    begin
      try
        Result.Success := (Response.Data as TJSONObject).GetValue<Boolean>('Success');
        if Result.Success then
        begin
          Result.Token := (Response.Data as TJSONObject).GetValue<string>('Token');
          
          if (Response.Data as TJSONObject).TryGetValue<TJSONObject>('User', UserObj) then
          begin
            Result.UserId := UserObj.GetValue<Integer>('Id');
            Result.OrganizationId := UserObj.GetValue<Integer>('OrganizationId', 0);
            Result.UserEmail := UserObj.GetValue<string>('Email');
            Result.UserName := UserObj.GetValue<string>('Name', '');
            // Note: OrganizationName is not in the User object from login response
            Result.OrganizationName := '';
          end;
          
          FAuthToken := Result.Token;
        end
        else
          Result.Message := (Response.Data as TJSONObject).GetValue<string>('Message', 'Login failed');
      finally
        Response.Data.Free;
      end;
    end
    else
    begin
      Result.Message := Response.ErrorMessage;
    end;
  finally
    RequestBody.Free;
  end;
end;

function TApiClient.Register(const AEmail, APassword, AOrgName: string): TRegisterResponse;
var
  RequestBody: TJSONObject;
  Response: TApiResponse;
begin
  Result.Success := False;
  Result.Token := '';
  Result.Message := '';
  Result.UserId := 0;
  Result.OrganizationId := 0;
  
  RequestBody := TJSONObject.Create;
  try
    RequestBody.AddPair('Email', AEmail);
    RequestBody.AddPair('Password', APassword);
    RequestBody.AddPair('OrganizationName', AOrgName);
    
    Response := DoRequest('POST', '/auth/register', RequestBody);
    
    if Response.Success and Assigned(Response.Data) then
    begin
      try
        Result.Success := (Response.Data as TJSONObject).GetValue<Boolean>('Success');
        if Result.Success then
        begin
          Result.Token := (Response.Data as TJSONObject).GetValue<string>('Token');
          Result.Message := (Response.Data as TJSONObject).GetValue<string>('Message', 'Registration successful');
          
          // Extract UserId from User object
          var UserObj: TJSONObject;
          if (Response.Data as TJSONObject).TryGetValue<TJSONObject>('User', UserObj) then
          begin
            Result.UserId := UserObj.GetValue<Integer>('Id', 0);
            Result.OrganizationId := UserObj.GetValue<Integer>('OrganizationId', 0);
          end;
          
          FAuthToken := Result.Token;
        end
        else
          Result.Message := (Response.Data as TJSONObject).GetValue<string>('Message', 'Registration failed');
      finally
        Response.Data.Free;
      end;
    end
    else
    begin
      Result.Message := Response.ErrorMessage;
    end;
  finally
    RequestBody.Free;
  end;
end;

function TApiClient.GetDisplays(AOrganizationId: Integer): TArray<TDisplayData>;
var
  Response: TApiResponse;
  JsonArray: TJSONArray;
  JsonObj: TJSONObject;
  I: Integer;
begin
  SetLength(Result, 0);
  
  Response := DoRequest('GET', Format('/organizations/%d/displays', [AOrganizationId]));
  
  if Response.Success and Assigned(Response.Data) then
  begin
    try
      if (Response.Data as TJSONObject).TryGetValue<TJSONArray>('value', JsonArray) then
      begin
        SetLength(Result, JsonArray.Count);
        for I := 0 to JsonArray.Count - 1 do
        begin
          JsonObj := JsonArray.Items[I] as TJSONObject;
          Result[I].Id := JsonObj.GetValue<Integer>('Id');
          Result[I].OrganizationId := JsonObj.GetValue<Integer>('OrganizationId');
          Result[I].Name := JsonObj.GetValue<string>('Name');
          Result[I].Orientation := JsonObj.GetValue<string>('Orientation');
          Result[I].LastSeen := JsonObj.GetValue<string>('LastSeen', '');
          Result[I].CurrentStatus := JsonObj.GetValue<string>('CurrentStatus');
          Result[I].ProvisioningToken := JsonObj.GetValue<string>('ProvisioningToken', '');
          Result[I].CreatedAt := JsonObj.GetValue<string>('CreatedAt', '');
          Result[I].UpdatedAt := JsonObj.GetValue<string>('UpdatedAt', '');
        end;
      end;
    finally
      Response.Data.Free;
    end;
  end;
end;

function TApiClient.GetDisplay(ADisplayId: Integer): TDisplayData;
var
  Response: TApiResponse;
  JsonObj: TJSONObject;
begin
  FillChar(Result, SizeOf(Result), 0);
  
  Response := DoRequest('GET', Format('/displays/%d', [ADisplayId]));
  
  if Response.Success and Assigned(Response.Data) then
  begin
    try
      JsonObj := Response.Data as TJSONObject;
      Result.Id := JsonObj.GetValue<Integer>('Id');
      Result.OrganizationId := JsonObj.GetValue<Integer>('OrganizationId');
      Result.Name := JsonObj.GetValue<string>('Name');
      Result.Orientation := JsonObj.GetValue<string>('Orientation');
      Result.LastSeen := JsonObj.GetValue<string>('LastSeen', '');
      Result.CurrentStatus := JsonObj.GetValue<string>('CurrentStatus');
      Result.ProvisioningToken := JsonObj.GetValue<string>('ProvisioningToken', '');
      Result.CreatedAt := JsonObj.GetValue<string>('CreatedAt', '');
      Result.UpdatedAt := JsonObj.GetValue<string>('UpdatedAt', '');
    finally
      Response.Data.Free;
    end;
  end;
end;

function TApiClient.CreateDisplay(AOrganizationId: Integer; const AName, AOrientation: string): TDisplayData;
var
  RequestBody: TJSONObject;
  Response: TApiResponse;
  JsonObj: TJSONObject;
  ProvToken: string;
begin
  FillChar(Result, SizeOf(Result), 0);
  
  // Generate provisioning token
  ProvToken := 'PROV-' + FormatDateTime('yyyymmddhhnnss', Now) + '-' + IntToStr(Random(9999));
  
  RequestBody := TJSONObject.Create;
  try
    RequestBody.AddPair('OrganizationId', TJSONNumber.Create(AOrganizationId));
    RequestBody.AddPair('Name', AName);
    RequestBody.AddPair('Orientation', AOrientation);
    RequestBody.AddPair('CurrentStatus', 'offline');
    RequestBody.AddPair('ProvisioningToken', ProvToken);
    
    Response := DoRequest('POST', Format('/organizations/%d/displays', [AOrganizationId]), RequestBody);
    
    if Response.Success and Assigned(Response.Data) then
    begin
      try
        JsonObj := Response.Data as TJSONObject;
        Result.Id := JsonObj.GetValue<Integer>('Id');
        Result.OrganizationId := JsonObj.GetValue<Integer>('OrganizationId');
        Result.Name := JsonObj.GetValue<string>('Name');
        Result.Orientation := JsonObj.GetValue<string>('Orientation');
        Result.LastSeen := JsonObj.GetValue<string>('LastSeen', '');
        Result.CurrentStatus := JsonObj.GetValue<string>('CurrentStatus');
        Result.ProvisioningToken := JsonObj.GetValue<string>('ProvisioningToken', '');
        Result.CreatedAt := JsonObj.GetValue<string>('CreatedAt', '');
        Result.UpdatedAt := JsonObj.GetValue<string>('UpdatedAt', '');
      finally
        Response.Data.Free;
      end;
    end;
  finally
    RequestBody.Free;
  end;
end;

function TApiClient.UpdateDisplay(const ADisplay: TDisplayData): TDisplayData;
var
  RequestBody: TJSONObject;
  Response: TApiResponse;
  JsonObj: TJSONObject;
begin
  FillChar(Result, SizeOf(Result), 0);
  
  RequestBody := TJSONObject.Create;
  try
    RequestBody.AddPair('Id', TJSONNumber.Create(ADisplay.Id));
    RequestBody.AddPair('Name', ADisplay.Name);
    RequestBody.AddPair('Orientation', ADisplay.Orientation);
    RequestBody.AddPair('CurrentStatus', ADisplay.CurrentStatus);
    
    Response := DoRequest('PUT', Format('/displays/%d', [ADisplay.Id]), RequestBody);
    
    if Response.Success and Assigned(Response.Data) then
    begin
      try
        JsonObj := Response.Data as TJSONObject;
        Result.Id := JsonObj.GetValue<Integer>('Id');
        Result.OrganizationId := JsonObj.GetValue<Integer>('OrganizationId');
        Result.Name := JsonObj.GetValue<string>('Name');
        Result.Orientation := JsonObj.GetValue<string>('Orientation');
        Result.LastSeen := JsonObj.GetValue<string>('LastSeen', '');
        Result.CurrentStatus := JsonObj.GetValue<string>('CurrentStatus');
        Result.ProvisioningToken := JsonObj.GetValue<string>('ProvisioningToken', '');
        Result.CreatedAt := JsonObj.GetValue<string>('CreatedAt', '');
        Result.UpdatedAt := JsonObj.GetValue<string>('UpdatedAt', '');
      finally
        Response.Data.Free;
      end;
    end;
  finally
    RequestBody.Free;
  end;
end;

function TApiClient.DeleteDisplay(ADisplayId: Integer): Boolean;
var
  Response: TApiResponse;
begin
  Response := DoRequest('DELETE', Format('/displays/%d', [ADisplayId]));
  Result := Response.Success;
  if Assigned(Response.Data) then
    Response.Data.Free;
end;

function TApiClient.GetCampaigns(AOrganizationId: Integer): TArray<TCampaignData>;
var
  Response: TApiResponse;
  JsonArray: TJSONArray;
  JsonObj: TJSONObject;
  I: Integer;
begin
  SetLength(Result, 0);
  
  Response := DoRequest('GET', Format('/organizations/%d/campaigns', [AOrganizationId]));
  
  if Response.Success and Assigned(Response.Data) then
  begin
    try
      if (Response.Data as TJSONObject).TryGetValue<TJSONArray>('value', JsonArray) then
      begin
        SetLength(Result, JsonArray.Count);
        for I := 0 to JsonArray.Count - 1 do
        begin
          JsonObj := JsonArray.Items[I] as TJSONObject;
          Result[I].Id := JsonObj.GetValue<Integer>('Id');
          Result[I].OrganizationId := JsonObj.GetValue<Integer>('OrganizationId');
          Result[I].Name := JsonObj.GetValue<string>('Name');
          Result[I].Orientation := JsonObj.GetValue<string>('Orientation');
          Result[I].CreatedAt := JsonObj.GetValue<string>('CreatedAt', '');
          Result[I].UpdatedAt := JsonObj.GetValue<string>('UpdatedAt', '');
        end;
      end;
    finally
      Response.Data.Free;
    end;
  end;
end;

function TApiClient.GetCampaign(ACampaignId: Integer): TCampaignData;
var
  Response: TApiResponse;
  JsonObj: TJSONObject;
begin
  FillChar(Result, SizeOf(Result), 0);
  
  Response := DoRequest('GET', Format('/campaigns/%d', [ACampaignId]));
  
  if Response.Success and Assigned(Response.Data) then
  begin
    try
      JsonObj := Response.Data as TJSONObject;
      Result.Id := JsonObj.GetValue<Integer>('Id');
      Result.OrganizationId := JsonObj.GetValue<Integer>('OrganizationId');
      Result.Name := JsonObj.GetValue<string>('Name');
      Result.Orientation := JsonObj.GetValue<string>('Orientation');
      Result.CreatedAt := JsonObj.GetValue<string>('CreatedAt', '');
      Result.UpdatedAt := JsonObj.GetValue<string>('UpdatedAt', '');
    finally
      Response.Data.Free;
    end;
  end;
end;

function TApiClient.CreateCampaign(AOrganizationId: Integer; const AName, AOrientation: string): TCampaignData;
var
  RequestBody: TJSONObject;
  Response: TApiResponse;
  JsonObj: TJSONObject;
begin
  FillChar(Result, SizeOf(Result), 0);
  
  RequestBody := TJSONObject.Create;
  try
    RequestBody.AddPair('OrganizationId', TJSONNumber.Create(AOrganizationId));
    RequestBody.AddPair('Name', AName);
    RequestBody.AddPair('Orientation', AOrientation);
    
    Response := DoRequest('POST', Format('/organizations/%d/campaigns', [AOrganizationId]), RequestBody);
    
    if Response.Success and Assigned(Response.Data) then
    begin
      try
        JsonObj := Response.Data as TJSONObject;
        Result.Id := JsonObj.GetValue<Integer>('Id');
        Result.OrganizationId := JsonObj.GetValue<Integer>('OrganizationId');
        Result.Name := JsonObj.GetValue<string>('Name');
        Result.Orientation := JsonObj.GetValue<string>('Orientation');
        Result.CreatedAt := JsonObj.GetValue<string>('CreatedAt', '');
        Result.UpdatedAt := JsonObj.GetValue<string>('UpdatedAt', '');
      finally
        Response.Data.Free;
      end;
    end;
  finally
    RequestBody.Free;
  end;
end;

function TApiClient.UpdateCampaign(const ACampaign: TCampaignData): TCampaignData;
var
  RequestBody: TJSONObject;
  Response: TApiResponse;
  JsonObj: TJSONObject;
begin
  FillChar(Result, SizeOf(Result), 0);
  
  RequestBody := TJSONObject.Create;
  try
    RequestBody.AddPair('Id', TJSONNumber.Create(ACampaign.Id));
    RequestBody.AddPair('Name', ACampaign.Name);
    RequestBody.AddPair('Orientation', ACampaign.Orientation);
    
    Response := DoRequest('PUT', Format('/campaigns/%d', [ACampaign.Id]), RequestBody);
    
    if Response.Success and Assigned(Response.Data) then
    begin
      try
        JsonObj := Response.Data as TJSONObject;
        Result.Id := JsonObj.GetValue<Integer>('Id');
        Result.OrganizationId := JsonObj.GetValue<Integer>('OrganizationId');
        Result.Name := JsonObj.GetValue<string>('Name');
        Result.Orientation := JsonObj.GetValue<string>('Orientation');
        Result.CreatedAt := JsonObj.GetValue<string>('CreatedAt', '');
        Result.UpdatedAt := JsonObj.GetValue<string>('UpdatedAt', '');
      finally
        Response.Data.Free;
      end;
    end;
  finally
    RequestBody.Free;
  end;
end;

function TApiClient.DeleteCampaign(ACampaignId: Integer): Boolean;
var
  Response: TApiResponse;
begin
  Response := DoRequest('DELETE', Format('/campaigns/%d', [ACampaignId]));
  Result := Response.Success;
  if Assigned(Response.Data) then
    Response.Data.Free;
end;

function TApiClient.GetMediaFiles(AOrganizationId: Integer): TArray<TMediaFileData>;
var
  Response: TApiResponse;
  JsonArray: TJSONArray;
  JsonObj: TJSONObject;
  I: Integer;
begin
  SetLength(Result, 0);
  
  Response := DoRequest('GET', Format('/organizations/%d/media-files', [AOrganizationId]));
  
  if Response.Success and Assigned(Response.Data) then
  begin
    try
      if (Response.Data as TJSONObject).TryGetValue<TJSONArray>('value', JsonArray) then
      begin
        SetLength(Result, JsonArray.Count);
        for I := 0 to JsonArray.Count - 1 do
        begin
          JsonObj := JsonArray.Items[I] as TJSONObject;
          Result[I].Id := JsonObj.GetValue<Integer>('MediaFileID');
          Result[I].OrganizationId := JsonObj.GetValue<Integer>('OrganizationID');
          Result[I].FileName := JsonObj.GetValue<string>('FileName');
          Result[I].FileType := JsonObj.GetValue<string>('FileType');
          Result[I].FileSize := JsonObj.GetValue<Int64>('FileSize', 0);
          Result[I].Duration := JsonObj.GetValue<Integer>('Duration', 0);
          Result[I].StorageURL := JsonObj.GetValue<string>('StorageURL', '');
          Result[I].Tags := JsonObj.GetValue<string>('Tags', '');
          Result[I].CreatedAt := JsonObj.GetValue<string>('CreatedAt', '');
          Result[I].UpdatedAt := JsonObj.GetValue<string>('UpdatedAt', '');
        end;
      end;
    finally
      Response.Data.Free;
    end;
  end;
end;

function TApiClient.RequestMediaUpload: TMediaUploadResponse;
var
  Response: TApiResponse;
  JsonObj: TJSONObject;
begin
  Result.Success := False;
  Result.MediaFileId := 0;
  Result.UploadUrl := '';
  Result.StorageKey := '';
  Result.Message := '';
  
  Response := DoRequest('POST', '/media-files/upload-url');
  
  if Response.Success and Assigned(Response.Data) then
  begin
    try
      JsonObj := Response.Data as TJSONObject;
      Result.Success := JsonObj.GetValue<Boolean>('Success');
      Result.MediaFileId := JsonObj.GetValue<Integer>('MediaFileId');
      Result.UploadUrl := JsonObj.GetValue<string>('UploadUrl');
      Result.StorageKey := JsonObj.GetValue<string>('StorageKey');
      Result.Message := JsonObj.GetValue<string>('Message', '');
    finally
      Response.Data.Free;
    end;
  end
  else
  begin
    Result.Message := Response.ErrorMessage;
  end;
end;

function TApiClient.UploadMediaFile(const AUploadUrl, AFilePath: string): Boolean;
var
  FileStream: TFileStream;
  Response: IHTTPResponse;
begin
  Result := False;
  
  if not FileExists(AFilePath) then
    Exit;
  
  FileStream := TFileStream.Create(AFilePath, fmOpenRead or fmShareDenyWrite);
  try
    try
      Response := FHttpClient.Put(AUploadUrl, FileStream);
      Result := (Response.StatusCode >= 200) and (Response.StatusCode < 300);
    except
      Result := False;
    end;
  finally
    FileStream.Free;
  end;
end;

function TApiClient.GetMediaDownloadUrl(AMediaFileId: Integer): string;
var
  Response: TApiResponse;
  JsonObj: TJSONObject;
begin
  Result := '';
  
  Response := DoRequest('GET', Format('/media-files/%d/download-url', [AMediaFileId]));
  
  if Response.Success and Assigned(Response.Data) then
  begin
    try
      JsonObj := Response.Data as TJSONObject;
      if JsonObj.GetValue<Boolean>('Success') then
        Result := JsonObj.GetValue<string>('DownloadUrl');
    finally
      Response.Data.Free;
    end;
  end;
end;

initialization

finalization
  TApiClient.ReleaseInstance;

end.

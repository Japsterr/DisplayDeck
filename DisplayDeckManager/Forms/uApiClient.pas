unit uApiClient;

interface

uses
  System.SysUtils, System.Classes, System.JSON, FMX.Dialogs, System.IOUtils,
  IdHTTP, IdSSLOpenSSL, IdGlobal, System.Generics.Collections; // added for inline expansions

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

  // Display insight/control
  TCurrentPlaying = record
    DisplayId: Integer;
    CampaignId: Integer;
    MediaFileId: Integer;
    MediaFileName: string;
    StartedAt: string;
  end;

  // Singleton API Client
  TApiClient = class
  private
    FHttpClient: TIdHTTP;
    FBaseURL: string;
    FAuthToken: string;
    FLastURL: string;
    FLastResponseCode: Integer;
    FLastResponseBody: string;
    FConfigPath: string;
    class var FInstance: TApiClient;
    constructor Create;
    function DoRequest(const AMethod, APath: string; ABody: TJSONObject = nil): TApiResponse;
    // Case-insensitive JSON value fetch helper
    function GetJsonValueCI(AObj: TJSONObject; const AName: string): TJSONValue;
    function RewriteMinioHost(const AUrl: string): string;
    function ParseCurrentPlaying(AObj: TJSONObject): TCurrentPlaying;
    procedure LoadConfig;
    procedure SaveConfig;
  public
    destructor Destroy; override;
    class function Instance: TApiClient;
    class procedure ReleaseInstance;

    // Configuration
    procedure SetBaseURL(const AURL: string);
    procedure SetAuthToken(const AToken: string);
    function GetAuthToken: string;
    procedure ClearAuthToken; // clears and persists removal
    procedure UpdateBaseURL(const AURL: string); // updates base URL and persists
    procedure SaveState; // explicit persist of current config
    
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
    // Display pairing (claim a device using provisioning token)
    function ClaimDisplay(AOrganizationId: Integer; const AProvisioningToken, AName, AOrientation: string): TDisplayData;
    // Display insight/control
    function GetDisplayCurrentPlaying(ADisplayId: Integer): TCurrentPlaying;
    function SetDisplayPrimary(ADisplayId, ACampaignId: Integer): Boolean;

    // Campaign endpoints
    function GetCampaigns(AOrganizationId: Integer): TArray<TCampaignData>;
    function GetCampaign(ACampaignId: Integer): TCampaignData;
    function CreateCampaign(AOrganizationId: Integer; const AName, AOrientation: string): TCampaignData;
    function UpdateCampaign(const ACampaign: TCampaignData): TCampaignData;
    function DeleteCampaign(ACampaignId: Integer): Boolean;

    // Media endpoints
    function GetMediaFiles(AOrganizationId: Integer): TArray<TMediaFileData>;
    function GetMediaFile(AMediaFileId: Integer): TMediaFileData;
    function RequestMediaUpload(AOrganizationId: Integer; const AFileName, AFileType: string; AContentLength: Int64): TMediaUploadResponse;
    function UploadMediaFile(const AUploadUrl, AFilePath: string): Boolean;
    function GetMediaDownloadUrl(AMediaFileId: Integer): string;
    function GuessMimeType(const AFilePath: string): string;
  end;

implementation

uses
  System.NetEncoding;

{ TApiClient }

constructor TApiClient.Create;
begin
  inherited;
  FHttpClient := TIdHTTP.Create(nil);
  FHttpClient.Request.ContentType := 'application/json';
  FHttpClient.Request.Accept := 'application/json';
  // All API endpoints are now rooted at /api
  FBaseURL := 'http://localhost:2001/api';
  FAuthToken := '';
  // Avoid header folding issues for long JWT values
  FHttpClient.Request.CustomHeaders.FoldLines := False;
  FConfigPath := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + 'displaydeck-config.json';
  LoadConfig; // attempt to restore persisted token/base url
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

procedure TApiClient.ClearAuthToken;
begin
  FAuthToken := '';
  SaveConfig;
end;

procedure TApiClient.UpdateBaseURL(const AURL: string);
begin
  if AURL.Trim <> '' then
  begin
    FBaseURL := AURL.Trim;
    SaveConfig;
  end;
end;

procedure TApiClient.SaveState;
begin
  SaveConfig;
end;

function TApiClient.DoRequest(const AMethod, APath: string; ABody: TJSONObject = nil): TApiResponse;
var
  URL: string;
  RequestStream: TStringStream;
  ResponseStream: TStringStream;
  ResponseStr: string;
begin
  Result.Success := False;
  Result.Data := nil;
  Result.ErrorMessage := '';
  Result.StatusCode := 0;
  
  URL := FBaseURL + APath;
  
  // Token handling (header + query) as per server behavior
  if FAuthToken <> '' then
  begin
    FHttpClient.Request.CustomHeaders.Values['X-Auth-Token'] := FAuthToken.Trim;
    if Pos('?', URL) > 0 then
      URL := URL + '&access_token=' + FAuthToken.Trim
    else
      URL := URL + '?access_token=' + FAuthToken.Trim;
  end;
  
  FLastURL := URL;
  RequestStream := nil;
  ResponseStream := nil;
  
  try
    // Prepare request body
    if Assigned(ABody) then
      RequestStream := TStringStream.Create(ABody.ToJSON, TEncoding.UTF8);
    
    ResponseStream := TStringStream.Create('', TEncoding.UTF8);
    
    // Execute request with TIdHTTP
    try
      if AMethod = 'GET' then
        ResponseStr := FHttpClient.Get(URL)
      else if AMethod = 'POST' then
        ResponseStr := FHttpClient.Post(URL, RequestStream)
      else if AMethod = 'PUT' then
        ResponseStr := FHttpClient.Put(URL, RequestStream)
      else if AMethod = 'DELETE' then
      begin
        FHttpClient.Delete(URL);
        ResponseStr := '';
      end
      else
        raise Exception.Create('Unsupported HTTP method: ' + AMethod);
      
      Result.StatusCode := FHttpClient.ResponseCode;
      FLastResponseCode := FHttpClient.ResponseCode;
      FLastResponseBody := ResponseStr;
      
      // Handle response
      if (FHttpClient.ResponseCode >= 200) and (FHttpClient.ResponseCode < 300) then
      begin
        Result.Success := True;
        if ResponseStr <> '' then
        begin
          try
            Result.Data := TJSONObject.ParseJSONValue(ResponseStr);
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
        Result.ErrorMessage := Format('HTTP %d: %s', [FHttpClient.ResponseCode, FHttpClient.ResponseText]);
      end;
      
    except
      on E: EIdHTTPProtocolException do
      begin
        Result.StatusCode := E.ErrorCode;
        FLastResponseCode := E.ErrorCode;
        FLastResponseBody := E.ErrorMessage;
        Result.Success := False;
        Result.ErrorMessage := Format('HTTP %d: %s', [E.ErrorCode, E.Message]);
      end;
    end;
    
  except
    on E: Exception do
    begin
      Result.Success := False;
      Result.ErrorMessage := E.Message;
    end;
  end;
  
  if Assigned(RequestStream) then
    RequestStream.Free;
  if Assigned(ResponseStream) then
    ResponseStream.Free;
end;

function TApiClient.GetJsonValueCI(AObj: TJSONObject; const AName: string): TJSONValue;
var
  Pair: TJSONPair;
begin
  Result := nil;
  if AObj = nil then Exit;
  for Pair in AObj do
    if SameText(Pair.JsonString.Value, AName) then
      Exit(Pair.JsonValue);
end;

function TApiClient.RewriteMinioHost(const AUrl: string): string;
begin
  Result := AUrl;
  // When running Docker, server presigns with host 'minio' which isn't resolvable from Windows.
  // Rewrite to localhost so the client can reach the exposed port 9000.
  Result := StringReplace(Result, 'http://minio:9000', 'http://localhost:9000', [rfIgnoreCase, rfReplaceAll]);
end;

function TApiClient.ParseCurrentPlaying(AObj: TJSONObject): TCurrentPlaying;
var
  V: TJSONValue;
begin
  Result.DisplayId := 0;
  Result.CampaignId := 0;
  Result.MediaFileId := 0;
  Result.MediaFileName := '';
  Result.StartedAt := '';
  if AObj = nil then Exit;
  V := GetJsonValueCI(AObj,'DisplayId'); if Assigned(V) then Result.DisplayId := StrToIntDef(V.Value,0);
  V := GetJsonValueCI(AObj,'CampaignId'); if Assigned(V) then Result.CampaignId := StrToIntDef(V.Value,0);
  V := GetJsonValueCI(AObj,'MediaFileId'); if not Assigned(V) then V := GetJsonValueCI(AObj,'MediaFileID'); if Assigned(V) then Result.MediaFileId := StrToIntDef(V.Value,0);
  V := GetJsonValueCI(AObj,'MediaFileName'); if Assigned(V) then Result.MediaFileName := V.Value;
  V := GetJsonValueCI(AObj,'StartedAt'); if Assigned(V) then Result.StartedAt := V.Value;
end;

function TApiClient.Login(const AEmail, APassword: string): TLoginResponse;
var
  RequestBody: TJSONObject;
  Response: TApiResponse;
  UserObj: TJSONObject;
  SV, TV, OrgVal, MV: TJSONValue;
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
        // Case-insensitive fetch of Success flag
        SV := GetJsonValueCI(Response.Data as TJSONObject, 'Success');
        if Assigned(SV) then
          Result.Success := SameText(SV.Value, 'true') or (SV is TJSONBool) and TJSONBool(SV).AsBoolean
        else
          Result.Success := (Response.Data as TJSONObject).GetValue<Boolean>('Success', False);
        if Result.Success then
        begin
          TV := GetJsonValueCI(Response.Data as TJSONObject, 'Token');
          if Assigned(TV) then
            Result.Token := TV.Value.Replace(#13,'').Replace(#10,'').Trim
          else
            Result.Token := (Response.Data as TJSONObject).GetValue<string>('Token','').Replace(#13,'').Replace(#10,'').Trim;
          
          if (Response.Data as TJSONObject).TryGetValue<TJSONObject>('User', UserObj) then
          begin
            Result.UserId := UserObj.GetValue<Integer>('Id');
            // Accept either OrganizationId or OrganizationID casing
            OrgVal := GetJsonValueCI(UserObj,'OrganizationId');
            if not Assigned(OrgVal) then OrgVal := GetJsonValueCI(UserObj,'OrganizationID');
            if Assigned(OrgVal) then
              Result.OrganizationId := StrToIntDef(OrgVal.Value,0)
            else
              Result.OrganizationId := UserObj.GetValue<Integer>('OrganizationId',0);
            Result.UserEmail := UserObj.GetValue<string>('Email');
            Result.UserName := UserObj.GetValue<string>('Name', '');
            // Note: OrganizationName is not in the User object from login response
            Result.OrganizationName := '';
          end;
          
          FAuthToken := Result.Token; // store trimmed token
          SaveConfig; // persist after successful login
        end
        else
        begin
          MV := GetJsonValueCI(Response.Data as TJSONObject,'Message');
          if Assigned(MV) then
            Result.Message := MV.Value
          else
            Result.Message := (Response.Data as TJSONObject).GetValue<string>('Message','Login failed');
        end;
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
          SaveConfig; // persist after successful registration
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
          // Case-insensitive extraction to avoid JSON casing issues
          var V: TJSONValue;
          V := GetJsonValueCI(JsonObj,'Id'); if Assigned(V) then Result[I].Id := StrToIntDef(V.Value,0) else Result[I].Id := JsonObj.GetValue<Integer>('Id',0);
          V := GetJsonValueCI(JsonObj,'OrganizationId'); if not Assigned(V) then V := GetJsonValueCI(JsonObj,'OrganizationID');
          if Assigned(V) then Result[I].OrganizationId := StrToIntDef(V.Value,0) else Result[I].OrganizationId := JsonObj.GetValue<Integer>('OrganizationId',0);
          V := GetJsonValueCI(JsonObj,'Name'); if Assigned(V) then Result[I].Name := V.Value else Result[I].Name := JsonObj.GetValue<string>('Name','');
          V := GetJsonValueCI(JsonObj,'Orientation'); if Assigned(V) then Result[I].Orientation := V.Value else Result[I].Orientation := JsonObj.GetValue<string>('Orientation','');
          V := GetJsonValueCI(JsonObj,'LastSeen'); if Assigned(V) then Result[I].LastSeen := V.Value else Result[I].LastSeen := JsonObj.GetValue<string>('LastSeen','');
          V := GetJsonValueCI(JsonObj,'CurrentStatus'); if Assigned(V) then Result[I].CurrentStatus := V.Value else Result[I].CurrentStatus := JsonObj.GetValue<string>('CurrentStatus','');
          V := GetJsonValueCI(JsonObj,'ProvisioningToken'); if Assigned(V) then Result[I].ProvisioningToken := V.Value else Result[I].ProvisioningToken := JsonObj.GetValue<string>('ProvisioningToken','');
          V := GetJsonValueCI(JsonObj,'CreatedAt'); if Assigned(V) then Result[I].CreatedAt := V.Value else Result[I].CreatedAt := JsonObj.GetValue<string>('CreatedAt','');
          V := GetJsonValueCI(JsonObj,'UpdatedAt'); if Assigned(V) then Result[I].UpdatedAt := V.Value else Result[I].UpdatedAt := JsonObj.GetValue<string>('UpdatedAt','');
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
      // Handle missing CurrentStatus gracefully
      Result.CurrentStatus := JsonObj.GetValue<string>('CurrentStatus', '');
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
    // Accept server variations: OrganizationID vs OrganizationId. We send OrganizationId as spec.
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
        var V: TJSONValue;
        V := GetJsonValueCI(JsonObj,'OrganizationId'); if not Assigned(V) then V := GetJsonValueCI(JsonObj,'OrganizationID');
        if Assigned(V) then Result.OrganizationId := StrToIntDef(V.Value,0) else Result.OrganizationId := JsonObj.GetValue<Integer>('OrganizationId',0);
        Result.Name := JsonObj.GetValue<string>('Name');
        Result.Orientation := JsonObj.GetValue<string>('Orientation');
        Result.LastSeen := JsonObj.GetValue<string>('LastSeen', '');
        Result.CurrentStatus := JsonObj.GetValue<string>('CurrentStatus', '');
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
        var V: TJSONValue;
        V := GetJsonValueCI(JsonObj,'OrganizationId'); if not Assigned(V) then V := GetJsonValueCI(JsonObj,'OrganizationID');
        if Assigned(V) then Result.OrganizationId := StrToIntDef(V.Value,0) else Result.OrganizationId := JsonObj.GetValue<Integer>('OrganizationId',0);
        Result.Name := JsonObj.GetValue<string>('Name');
        Result.Orientation := JsonObj.GetValue<string>('Orientation');
        Result.LastSeen := JsonObj.GetValue<string>('LastSeen', '');
        Result.CurrentStatus := JsonObj.GetValue<string>('CurrentStatus', '');
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

function TApiClient.ClaimDisplay(AOrganizationId: Integer; const AProvisioningToken, AName, AOrientation: string): TDisplayData;
var
  RequestBody: TJSONObject;
  Response: TApiResponse;
  JsonObj: TJSONObject;
begin
  FillChar(Result, SizeOf(Result), 0);
  RequestBody := TJSONObject.Create;
  try
    RequestBody.AddPair('ProvisioningToken', AProvisioningToken);
    if AName <> '' then RequestBody.AddPair('Name', AName);
    if AOrientation <> '' then RequestBody.AddPair('Orientation', AOrientation);
    Response := DoRequest('POST', Format('/organizations/%d/displays/claim', [AOrganizationId]), RequestBody);
  finally
    RequestBody.Free;
  end;

  if Response.Success and Assigned(Response.Data) then
  begin
    try
      JsonObj := Response.Data as TJSONObject;
      var V: TJSONValue;
      V := GetJsonValueCI(JsonObj,'Id'); if Assigned(V) then Result.Id := StrToIntDef(V.Value,0) else Result.Id := JsonObj.GetValue<Integer>('Id',0);
      V := GetJsonValueCI(JsonObj,'OrganizationId'); if not Assigned(V) then V := GetJsonValueCI(JsonObj,'OrganizationID');
      if Assigned(V) then Result.OrganizationId := StrToIntDef(V.Value,0) else Result.OrganizationId := JsonObj.GetValue<Integer>('OrganizationId',0);
      V := GetJsonValueCI(JsonObj,'Name'); if Assigned(V) then Result.Name := V.Value else Result.Name := JsonObj.GetValue<string>('Name','');
      V := GetJsonValueCI(JsonObj,'Orientation'); if Assigned(V) then Result.Orientation := V.Value else Result.Orientation := JsonObj.GetValue<string>('Orientation','');
      V := GetJsonValueCI(JsonObj,'LastSeen'); if Assigned(V) then Result.LastSeen := V.Value else Result.LastSeen := JsonObj.GetValue<string>('LastSeen','');
      V := GetJsonValueCI(JsonObj,'CurrentStatus'); if Assigned(V) then Result.CurrentStatus := V.Value else Result.CurrentStatus := JsonObj.GetValue<string>('CurrentStatus','');
      V := GetJsonValueCI(JsonObj,'ProvisioningToken'); if Assigned(V) then Result.ProvisioningToken := V.Value else Result.ProvisioningToken := JsonObj.GetValue<string>('ProvisioningToken','');
      V := GetJsonValueCI(JsonObj,'CreatedAt'); if Assigned(V) then Result.CreatedAt := V.Value else Result.CreatedAt := JsonObj.GetValue<string>('CreatedAt','');
      V := GetJsonValueCI(JsonObj,'UpdatedAt'); if Assigned(V) then Result.UpdatedAt := V.Value else Result.UpdatedAt := JsonObj.GetValue<string>('UpdatedAt','');
    finally
      Response.Data.Free;
    end;
  end
  else if Assigned(Response.Data) then
    Response.Data.Free;
end;

function TApiClient.GetDisplayCurrentPlaying(ADisplayId: Integer): TCurrentPlaying;
var
  Response: TApiResponse;
  Obj: TJSONObject;
begin
  Result.DisplayId := 0; Result.CampaignId := 0; Result.MediaFileId := 0; Result.MediaFileName := ''; Result.StartedAt := '';
  Response := DoRequest('GET', Format('/displays/%d/current-playing', [ADisplayId]));
  if Response.Success and Assigned(Response.Data) then
  begin
    try
      Obj := Response.Data as TJSONObject;
      Result := ParseCurrentPlaying(Obj);
    finally
      Response.Data.Free;
    end;
  end;
end;

function TApiClient.SetDisplayPrimary(ADisplayId, ACampaignId: Integer): Boolean;
var
  Body: TJSONObject;
  Response: TApiResponse;
begin
  Body := TJSONObject.Create;
  try
    Body.AddPair('CampaignId', TJSONNumber.Create(ACampaignId));
    Response := DoRequest('POST', Format('/displays/%d/set-primary', [ADisplayId]), Body);
  finally
    Body.Free;
  end;
  Result := Response.Success;
  if Assigned(Response.Data) then Response.Data.Free;
end;

procedure TApiClient.LoadConfig;
var
  LText: string;
  LJSON: TJSONObject;
  TokVal, UrlVal: TJSONValue;
begin
  if not FileExists(FConfigPath) then Exit;
  try
    LText := TFile.ReadAllText(FConfigPath, TEncoding.UTF8);
    LJSON := TJSONObject.ParseJSONValue(LText) as TJSONObject;
    try
      if Assigned(LJSON) then
      begin
        TokVal := GetJsonValueCI(LJSON, 'AuthToken');
        if Assigned(TokVal) then FAuthToken := TokVal.Value.Trim;
        UrlVal := GetJsonValueCI(LJSON, 'BaseURL');
        if Assigned(UrlVal) and (UrlVal.Value.Trim <> '') then FBaseURL := UrlVal.Value.Trim;
      end;
    finally
      LJSON.Free;
    end;
  except
    // swallow errors to avoid startup disruption
  end;
end;

procedure TApiClient.SaveConfig;
var
  LJSON: TJSONObject;
  LText: string;
begin
  LJSON := TJSONObject.Create;
  try
    LJSON.AddPair('BaseURL', FBaseURL);
    LJSON.AddPair('AuthToken', FAuthToken);
    LText := LJSON.ToJSON;
    try
      TFile.WriteAllText(FConfigPath, LText, TEncoding.UTF8);
    except
      // ignore write errors
    end;
  finally
    LJSON.Free;
  end;
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
          var V: TJSONValue;
          V := GetJsonValueCI(JsonObj,'Id'); if Assigned(V) then Result[I].Id := StrToIntDef(V.Value,0) else Result[I].Id := JsonObj.GetValue<Integer>('Id',0);
          V := GetJsonValueCI(JsonObj,'OrganizationId'); if not Assigned(V) then V := GetJsonValueCI(JsonObj,'OrganizationID');
          if Assigned(V) then Result[I].OrganizationId := StrToIntDef(V.Value,0) else Result[I].OrganizationId := JsonObj.GetValue<Integer>('OrganizationId',0);
          V := GetJsonValueCI(JsonObj,'Name'); if Assigned(V) then Result[I].Name := V.Value else Result[I].Name := JsonObj.GetValue<string>('Name','');
          V := GetJsonValueCI(JsonObj,'Orientation'); if Assigned(V) then Result[I].Orientation := V.Value else Result[I].Orientation := JsonObj.GetValue<string>('Orientation','');
          V := GetJsonValueCI(JsonObj,'CreatedAt'); if Assigned(V) then Result[I].CreatedAt := V.Value else Result[I].CreatedAt := JsonObj.GetValue<string>('CreatedAt','');
          V := GetJsonValueCI(JsonObj,'UpdatedAt'); if Assigned(V) then Result[I].UpdatedAt := V.Value else Result[I].UpdatedAt := JsonObj.GetValue<string>('UpdatedAt','');
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
  PreflightInfo: string;
  DebugURL: string;
begin
  FillChar(Result, SizeOf(Result), 0);
  
  RequestBody := TJSONObject.Create;
  try
    RequestBody.AddPair('OrganizationId', TJSONNumber.Create(AOrganizationId));
    RequestBody.AddPair('Name', AName);
    RequestBody.AddPair('Orientation', AOrientation);
    
    // Preflight: ask server what headers/query token it sees
    PreflightInfo := '';
    if FAuthToken <> '' then
    begin
      // Prepare header
      FHttpClient.Request.CustomHeaders.FoldLines := False;
      FHttpClient.Request.CustomHeaders.Clear;
      FHttpClient.Request.CustomHeaders.Add('X-Auth-Token: ' + FAuthToken.Trim);
      // Call /debug/headers with access_token query as well
      DebugURL := FBaseURL + '/debug/headers?access_token=' + FAuthToken.Trim;
      try
        PreflightInfo := FHttpClient.Get(DebugURL);
      except
        on E: Exception do
          PreflightInfo := 'Preflight failed: ' + E.Message;
      end;
    end;

    Response := DoRequest('POST', Format('/organizations/%d/campaigns', [AOrganizationId]), RequestBody);
    if (not Response.Success) and (Response.StatusCode=401) then
    begin
      // Append debug details so UI can show them
      FLastResponseBody := '[401 DEBUG] Token prefix=' + Copy(FAuthToken,1,30)+'...' +
        '\n[Preflight] ' + PreflightInfo;
    end;
    
    if Response.Success and Assigned(Response.Data) then
    begin
      try
        JsonObj := Response.Data as TJSONObject;
        Result.Id := JsonObj.GetValue<Integer>('Id');
        var V: TJSONValue;
        V := GetJsonValueCI(JsonObj,'OrganizationId'); if not Assigned(V) then V := GetJsonValueCI(JsonObj,'OrganizationID');
        if Assigned(V) then Result.OrganizationId := StrToIntDef(V.Value,0) else Result.OrganizationId := JsonObj.GetValue<Integer>('OrganizationId',0);
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
        var V: TJSONValue;
        V := GetJsonValueCI(JsonObj,'OrganizationId'); if not Assigned(V) then V := GetJsonValueCI(JsonObj,'OrganizationID');
        if Assigned(V) then Result.OrganizationId := StrToIntDef(V.Value,0) else Result.OrganizationId := JsonObj.GetValue<Integer>('OrganizationId',0);
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
          // Use case-insensitive lookup for field names
          var V: TJSONValue;
          V := GetJsonValueCI(JsonObj,'MediaFileId'); if Assigned(V) then Result[I].Id := StrToIntDef(V.Value,0) else Result[I].Id := JsonObj.GetValue<Integer>('MediaFileID',0);
          V := GetJsonValueCI(JsonObj,'OrganizationId'); if Assigned(V) then Result[I].OrganizationId := StrToIntDef(V.Value,0) else Result[I].OrganizationId := JsonObj.GetValue<Integer>('OrganizationID',0);
          V := GetJsonValueCI(JsonObj,'FileName'); if Assigned(V) then Result[I].FileName := V.Value else Result[I].FileName := JsonObj.GetValue<string>('FileName','');
          V := GetJsonValueCI(JsonObj,'FileType'); if Assigned(V) then Result[I].FileType := V.Value else Result[I].FileType := JsonObj.GetValue<string>('FileType','');
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

function TApiClient.GetMediaFile(AMediaFileId: Integer): TMediaFileData;
var
  Response: TApiResponse;
  JsonObj: TJSONObject;
  V: TJSONValue;
begin
  FillChar(Result, SizeOf(Result), 0);
  Response := DoRequest('GET', Format('/media-files/%d', [AMediaFileId]));
  if Response.Success and Assigned(Response.Data) then
  begin
    try
      JsonObj := Response.Data as TJSONObject;
      V := GetJsonValueCI(JsonObj,'MediaFileId'); if Assigned(V) then Result.Id := StrToIntDef(V.Value,0) else Result.Id := JsonObj.GetValue<Integer>('Id',0);
      V := GetJsonValueCI(JsonObj,'OrganizationId'); if not Assigned(V) then V := GetJsonValueCI(JsonObj,'OrganizationID'); if Assigned(V) then Result.OrganizationId := StrToIntDef(V.Value,0);
      V := GetJsonValueCI(JsonObj,'FileName'); if Assigned(V) then Result.FileName := V.Value;
      V := GetJsonValueCI(JsonObj,'FileType'); if Assigned(V) then Result.FileType := V.Value;
      V := GetJsonValueCI(JsonObj,'FileSize'); if Assigned(V) then Result.FileSize := StrToInt64Def(V.Value,0);
      V := GetJsonValueCI(JsonObj,'Duration'); if Assigned(V) then Result.Duration := StrToIntDef(V.Value,0);
      V := GetJsonValueCI(JsonObj,'StorageURL'); if Assigned(V) then Result.StorageURL := V.Value;
      V := GetJsonValueCI(JsonObj,'Tags'); if Assigned(V) then Result.Tags := V.Value;
      V := GetJsonValueCI(JsonObj,'CreatedAt'); if Assigned(V) then Result.CreatedAt := V.Value;
      V := GetJsonValueCI(JsonObj,'UpdatedAt'); if Assigned(V) then Result.UpdatedAt := V.Value;
    finally
      Response.Data.Free;
    end;
  end;
end;

function TApiClient.RequestMediaUpload(AOrganizationId: Integer; const AFileName, AFileType: string; AContentLength: Int64): TMediaUploadResponse;
var
  Response: TApiResponse;
  JsonObj: TJSONObject;
  Req: TJSONObject;
begin
  Result.Success := False;
  Result.MediaFileId := 0;
  Result.UploadUrl := '';
  Result.StorageKey := '';
  Result.Message := '';
  // Build required request body per API schema
  Req := TJSONObject.Create;
  try
    Req.AddPair('OrganizationId', TJSONNumber.Create(AOrganizationId));
    Req.AddPair('FileName', AFileName);
    Req.AddPair('FileType', AFileType);
    Req.AddPair('ContentLength', TJSONNumber.Create(AContentLength));
    Response := DoRequest('POST', '/media-files/upload-url', Req);
  finally
    Req.Free;
  end;
  
  if Response.Success and Assigned(Response.Data) then
  begin
    try
      JsonObj := Response.Data as TJSONObject;
      Result.Success := JsonObj.GetValue<Boolean>('Success');
      Result.MediaFileId := JsonObj.GetValue<Integer>('MediaFileId');
      Result.UploadUrl := RewriteMinioHost(JsonObj.GetValue<string>('UploadUrl'));
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
  PrevContentType, PrevAccept: string;
  Mime: string;
begin
  Result := False;
  
  if not FileExists(AFilePath) then
    Exit;
  
  FileStream := TFileStream.Create(AFilePath, fmOpenRead or fmShareDenyWrite);
  try
    try
      // Preserve previous request headers so we can restore after raw upload
      PrevContentType := FHttpClient.Request.ContentType;
      PrevAccept := FHttpClient.Request.Accept;
      // Determine mime type from extension
      Mime := GuessMimeType(AFilePath);
      FHttpClient.Request.ContentType := Mime;
      FHttpClient.Request.Accept := '*/*';
      // Clear custom JSON headers for S3/MinIO PUT (avoid confusing server)
      FHttpClient.Request.CustomHeaders.Clear;
      // Execute binary PUT
      FHttpClient.Put(AUploadUrl, FileStream);
      // Restore headers
      FHttpClient.Request.ContentType := PrevContentType;
      FHttpClient.Request.Accept := PrevAccept;
      Result := (FHttpClient.ResponseCode >= 200) and (FHttpClient.ResponseCode < 300);
    except
      Result := False;
      FLastResponseCode := FHttpClient.ResponseCode;
      FLastResponseBody := 'Upload failed; HTTP ' + IntToStr(FHttpClient.ResponseCode) + ' Body=' + FHttpClient.ResponseText;
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
      var V: TJSONValue;
      V := GetJsonValueCI(JsonObj,'Success');
      if Assigned(V) and (SameText(V.Value,'true') or (V is TJSONBool) and TJSONBool(V).AsBoolean) then
      begin
        var DU := GetJsonValueCI(JsonObj,'DownloadUrl');
        if Assigned(DU) then
          Result := RewriteMinioHost(DU.Value)
        else
          Result := RewriteMinioHost(JsonObj.GetValue<string>('DownloadUrl',''));
      end;
    finally
      Response.Data.Free;
    end;
  end;
end;

function TApiClient.GuessMimeType(const AFilePath: string): string;
var
  Ext: string;
begin
  Ext := LowerCase(ExtractFileExt(AFilePath));
  if Ext = '.png' then Result := 'image/png'
  else if (Ext = '.jpg') or (Ext = '.jpeg') then Result := 'image/jpeg'
  else if Ext = '.gif' then Result := 'image/gif'
  else if Ext = '.mp4' then Result := 'video/mp4'
  else if Ext = '.webm' then Result := 'video/webm'
  else if (Ext = '.mov') or (Ext = '.qt') then Result := 'video/quicktime'
  else if Ext = '.pdf' then Result := 'application/pdf'
  else if Ext = '.json' then Result := 'application/json'
  else Result := 'application/octet-stream';
end;

initialization

finalization
  TApiClient.ReleaseInstance;

end.

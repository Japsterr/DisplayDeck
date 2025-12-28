unit WebModuleMain;

interface

uses
  System.SysUtils, System.Classes, System.JSON, Web.HTTPApp,
  OrganizationRepository, uEntities;

type
  TWebModule1 = class(TWebModule)
    procedure DefaultHandlerAction(Sender: TObject; Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
  private
    procedure HandleHealth(Response: TWebResponse);
    procedure HandleOrganizations(Request: TWebRequest; Response: TWebResponse);
    procedure HandleOrganizationById(Request: TWebRequest; Response: TWebResponse);
  public
    constructor Create(AOwner: TComponent); override;
  end;

var
  WebModuleClass: TComponentClass = TWebModule1;

implementation

{$R *.dfm}

uses
  System.Generics.Collections, System.StrUtils, System.Net.URLClient, Web.WebReq,
  System.DateUtils,
  FireDAC.Comp.Client, FireDAC.Stan.Param,
  // Repositories & utils
  DisplayRepository,
  CampaignRepository,
  CampaignItemRepository,
  DisplayCampaignRepository,
  ScheduleRepository,
  MediaFileRepository,
  UserRepository,
  RefreshTokenRepository,
  ApiKeyRepository,
  IdempotencyRepository,
  AuditLogRepository,
  WebhookRepository,
  PasswordUtils,
  JWTUtils,
  AWSSigV4,
  ProvisioningTokenRepository,
  uServerContainer,
  System.Hash,
  System.Threading,
  IdHTTP,
  IdSSLOpenSSL; // optional for https webhooks

constructor TWebModule1.Create(AOwner: TComponent);
var
  Action: TWebActionItem;
begin
  inherited Create(AOwner);
  // Create a default action that delegates to our handler
  Action := Actions.Add;
  Action.Name := 'Default';
  Action.Default := True;
  Action.OnAction := DefaultHandlerAction;
end;



procedure TWebModule1.DefaultHandlerAction(Sender: TObject; Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
var
  RequestId: string;
  ClientIp: string;
  UserAgent: string;
  IdempotencyKey: string;
  AuthApiKeyId: Int64;
  AuthKind: string;
  // Local helper to reply 501 for yet-to-be-implemented endpoints
  procedure SetHeaderSafe(const Name, Value: string);
  begin
    try
      Response.SetCustomHeader(Name, Value);
    except
      // ignore
    end;
  end;
  function EnsureRequestId: string;
  var
    G: TGUID;
  begin
    Result := Request.GetFieldByName('X-Request-Id');
    if Result = '' then Result := Request.GetFieldByName('x-request-id');
    Result := Trim(Result);
    if Result = '' then
    begin
      CreateGUID(G);
      Result := GUIDToString(G);
      Result := Result.Replace('{','').Replace('}','');
    end;
    SetHeaderSafe('X-Request-Id', Result);
  end;
  procedure SendJson(const Status: Integer; const JsonText: string);
  begin
    Response.StatusCode := Status;
    Response.ContentType := 'application/json';
    Response.Content := JsonText;
    Response.SendResponse;
  end;
  function JSONError(Code: Integer; const Msg: string; const ErrCode: string = ''): Boolean;
  var
    CodeText: string;
  begin
    if ErrCode.Trim <> '' then CodeText := ErrCode.Trim else CodeText := 'error';
    SendJson(Code,
      '{"code":"' + StringReplace(CodeText, '"', '\"', [rfReplaceAll]) +
      '","message":"' + StringReplace(Msg, '"', '\"', [rfReplaceAll]) +
      '","requestId":"' + StringReplace(RequestId, '"', '\"', [rfReplaceAll]) + '"}');
    Result := True;
  end;
  procedure NotImpl(const Feature: string);
  begin
    JSONError(501, 'Not Implemented: ' + Feature, 'not_implemented');
  end;
  function GetEnv(const Name, DefaultVal: string): string;
  begin
    Result := GetEnvironmentVariable(Name);
    if Result = '' then Result := DefaultVal;
  end;
  function DebugEnabled: Boolean;
  begin
    Result := SameText(GetEnv('SERVER_DEBUG','false'), 'true');
  end;
  function NewConnection: TFDConnection;
  begin
    Result := TFDConnection.Create(nil);
    try
      Result.Params.Assign(ServerContainer.FDConnection.Params);
      Result.LoginPrompt := False;
      Result.Connected := True;
    except
      Result.Free;
      raise;
    end;
  end;
  function GetClientIp: string;
  begin
    Result := Request.GetFieldByName('X-Forwarded-For');
    if Result = '' then Result := Request.RemoteAddr;
    Result := Trim(Result);
  end;
  function HashSha256Hex(const S: string): string;
  begin
    Result := THashSHA2.GetHashString(S, THashSHA2.TSHA2Version.SHA256);
  end;
  function GenerateOpaqueToken: string;
  var
    G: TGUID;
    Seed: string;
    Bytes: TBytes;
  begin
    CreateGUID(G);
    Seed := GUIDToString(G) + '|' + IntToStr(DateTimeToUnix(Now, False)) + '|' + IntToStr(Random(MaxInt));
    Bytes := THashSHA2.GetHashBytes(Seed, THashSHA2.TSHA2Version.SHA256);
    Result := JWTUtils.Base64UrlEncode(Bytes);
  end;
  function NormalizeScopes(const S: string): string;
  begin
    Result := ' ' + LowerCase(StringReplace(S, ',', ' ', [rfReplaceAll])) + ' ';
    while Pos('  ', Result) > 0 do Result := StringReplace(Result, '  ', ' ', [rfReplaceAll]);
  end;
  function ApiKeyHasScopes(const ApiKeyScopes: string; const RequiredScopes: array of string): Boolean;
  var
    Hay: string;
    R: string;
  begin
    Hay := NormalizeScopes(ApiKeyScopes);
    for R in RequiredScopes do
    begin
      if Trim(R) = '' then Continue;
      if Pos(' ' + LowerCase(Trim(R)) + ' ', Hay) = 0 then Exit(False);
    end;
    Result := True;
  end;

  function TryJWT(out OrgId: Integer; out UserId: Integer; out Role: string): Boolean; forward;
  function RequireJWT(out OrgId: Integer; out UserId: Integer; out Role: string): Boolean; forward;

  function TryApiKeyAuth(const RequiredScopes: array of string; out OrgId: Integer; out UserId: Integer; out Role: string): Boolean;
  var
    ApiKey: string;
    Info: TApiKeyInfo;
    Hash: string;
  begin
    Result := False;
    OrgId := 0; UserId := 0; Role := '';

    ApiKey := Trim(Request.GetFieldByName('X-Api-Key'));
    if ApiKey = '' then ApiKey := Trim(Request.GetFieldByName('x-api-key'));
    if ApiKey = '' then Exit(False);

    Hash := HashSha256Hex(ApiKey);
    if not TApiKeyRepository.FindByHash(Hash, Info) then
      Exit(False);
    if Info.Revoked then Exit(False);
    if Info.HasExpiresAt and (Info.ExpiresAt < Now) then Exit(False);
    if not ApiKeyHasScopes(Info.Scopes, RequiredScopes) then Exit(False);

    TApiKeyRepository.TouchLastUsed(Info.ApiKeyId);
    AuthApiKeyId := Info.ApiKeyId;
    AuthKind := 'apiKey';

    OrgId := Info.OrganizationId;
    UserId := 0;
    Role := 'ApiKey';
    Result := True;
  end;
  function RequireAuth(const RequiredScopes: array of string; out OrgId: Integer; out UserId: Integer; out Role: string): Boolean;
  begin
    // Prefer JWT, but allow scoped API keys as fallback.
    Result := TryJWT(OrgId, UserId, Role);
    if Result then begin AuthKind := 'jwt'; Exit; end;
    Result := TryApiKeyAuth(RequiredScopes, OrgId, UserId, Role);
    if not Result then
      JSONError(401, 'Unauthorized', 'unauthorized');
  end;
  function CleanToken(const S: string): string;
  var i: Integer; ch: Char;
  begin
    Result := '';
    for i := 1 to Length(S) do
    begin
      ch := S[i];
      if (ch in ['A'..'Z','a'..'z','0'..'9','-','_','.']) then
        Result := Result + ch;
    end;
  end;
  function TryJWT(out OrgId: Integer; out UserId: Integer; out Role: string): Boolean;
  var
    H, RawToken, QueryToken, TryToken: string;
    Parts: TArray<string>;
    Payload: TJSONObject;
    Secret: string;
    NowSec: Int64;
  begin
    Result := False;
    OrgId := 0; UserId := 0; Role := '';

    H := Request.GetFieldByName('Authorization');
    if (H <> '') and H.StartsWith('Bearer ') then
      RawToken := H.Substring(7)
    else
    begin
      // Fallback to X-Auth-Token for clients that cannot set Authorization header (e.g., PS 5.1)
      RawToken := Request.GetFieldByName('X-Auth-Token');
      if RawToken='' then RawToken := Request.GetFieldByName('x-auth-token');
      if RawToken='' then RawToken := Request.GetFieldByName('X_AUTH_TOKEN');
      if RawToken.StartsWith('Bearer ') then RawToken := RawToken.Substring(7);
    end;

    if DebugEnabled then
      Writeln(Format('TryJWT Authorization="%s" X-Auth-Token="%s" RawToken="%s"',
        [H, Request.GetFieldByName('X-Auth-Token'), RawToken]));

    QueryToken := Request.QueryFields.Values['access_token'];
    RawToken := CleanToken(RawToken);
    QueryToken := CleanToken(QueryToken);
    if RawToken = '' then RawToken := QueryToken;
    if RawToken = '' then Exit(False);

    Parts := RawToken.Split([' ']);
    Secret := GetEnv('JWT_SECRET','changeme');
    TryToken := Parts[0];

    Payload := nil;
    if not VerifyJWT(TryToken, Secret, Payload) then
    begin
      if (QueryToken<>'') then
      begin
        if not VerifyJWT(QueryToken, Secret, Payload) then Exit(False);
      end
      else
        Exit(False);
    end;

    try
      OrgId := Payload.GetValue<Integer>('org',0);
      UserId := Payload.GetValue<Integer>('sub',0);
      Role := Payload.GetValue<string>('role','');
      NowSec := DateTimeToUnix(Now, False);
      if Payload.GetValue<Int64>('exp', NowSec) < NowSec then Exit(False);
    finally
      Payload.Free;
    end;
    Result := True;
  end;

  function RequireJWT(out OrgId: Integer; out UserId: Integer; out Role: string): Boolean;
  begin
    Result := TryJWT(OrgId, UserId, Role);
    if not Result then
      JSONError(401, 'Unauthorized', 'unauthorized');
  end;

  function TryReplayIdempotency(const OrganizationId: Integer): Boolean;
  var
    Hit: TIdempotencyHit;
  begin
    Result := False;
    if Trim(IdempotencyKey) = '' then Exit(False);
    Hit := TIdempotencyRepository.TryGet(Trim(IdempotencyKey), Request.Method, Request.PathInfo, OrganizationId);
    if not Hit.Hit then Exit(False);
    Response.StatusCode := Hit.StatusCode;
    Response.ContentType := 'application/json';
    Response.Content := Hit.ResponseBody;
    Response.SendResponse;
    Result := True;
  end;

  procedure StoreIdempotency(const OrganizationId: Integer; const StatusCode: Integer; const Body: string);
  begin
    if Trim(IdempotencyKey) = '' then Exit;
    TIdempotencyRepository.Store(Trim(IdempotencyKey), Request.Method, Request.PathInfo, OrganizationId, StatusCode, Body, Now + 1);
  end;
  function CheckPlanAllowsDisplay(const OrganizationId: Integer): Boolean;
  var C: TFDConnection; Q: TFDQuery; Limit, Count: Integer;
  begin
    Result := True;
    C := NewConnection; try
      Q := TFDQuery.Create(nil); try
        Q.Connection := C;
        Q.SQL.Text := 'select p.MaxDisplays as Limit, (select count(*) from Displays d where d.OrganizationID=:Org) as Cnt '
                    + 'from Subscriptions s join Plans p on p.PlanID=s.PlanID where s.OrganizationID=:Org and s.Status in (''Active'',''Trialing'')';
        Q.ParamByName('Org').AsInteger := OrganizationId; Q.Open;
        if not Q.Eof then begin Limit := Q.FieldByName('Limit').AsInteger; Count := Q.FieldByName('Cnt').AsInteger; Result := (Count < Limit); end;
      finally Q.Free; end;
    finally C.Free; end;
  end;

  function TryParseHm(const S: string; out Minutes: Integer): Boolean;
  begin
    Result := False;
    Minutes := 0;
    var P := Pos(':', S);
    if P <= 0 then Exit;
    var HH := StrToIntDef(Copy(S, 1, P-1), -1);
    var MM := StrToIntDef(Copy(S, P+1, 2), -1);
    if (HH < 0) or (HH > 23) or (MM < 0) or (MM > 59) then Exit;
    Minutes := HH * 60 + MM;
    Result := True;
  end;

  function MatchesRecurring(const Pattern: string; const NowUtc: TDateTime): Boolean;
  begin
    // If no pattern, no additional restriction.
    Result := True;
    if Pattern.Trim = '' then Exit;

    // Only implement JSON recurrence for now; unknown formats are treated as non-restrictive.
    var J := TJSONObject.ParseJSONValue(Pattern) as TJSONObject;
    if J = nil then Exit(True);
    try
      // Days-of-week filter: 0=Sun..6=Sat
      var DaysOk := True;
      var DaysVal := J.GetValue('daysOfWeek');
      if (DaysVal <> nil) and (DaysVal is TJSONArray) then
      begin
        DaysOk := False;
        var Dow := DayOfWeek(NowUtc); // 1=Sun..7=Sat
        var Dow0 := Dow - 1; // 0..6
        for var V in TJSONArray(DaysVal) do
          if StrToIntDef(V.Value, -1) = Dow0 then
          begin
            DaysOk := True;
            Break;
          end;
      end;
      if not DaysOk then Exit(False);

      // Time-of-day window filter
      var StartLocal := '';
      var EndLocal := '';
      var SV := J.GetValue('startLocal');
      if (SV <> nil) and (not (SV is TJSONNull)) then StartLocal := SV.Value;
      var EV := J.GetValue('endLocal');
      if (EV <> nil) and (not (EV is TJSONNull)) then EndLocal := EV.Value;

      if (StartLocal.Trim = '') and (EndLocal.Trim = '') then Exit(True);

      var StartMin: Integer;
      var EndMin: Integer;
      if (StartLocal.Trim <> '') and (not TryParseHm(StartLocal.Trim, StartMin)) then Exit(True);
      if (EndLocal.Trim <> '') and (not TryParseHm(EndLocal.Trim, EndMin)) then Exit(True);

      var NowMin := HourOf(NowUtc) * 60 + MinuteOf(NowUtc);

      // If only one bound provided, treat as open-ended.
      if (StartLocal.Trim <> '') and (EndLocal.Trim = '') then
        Exit(NowMin >= StartMin);
      if (StartLocal.Trim = '') and (EndLocal.Trim <> '') then
        Exit(NowMin <= EndMin);

      // Both bounds provided.
      if EndMin >= StartMin then
        Result := (NowMin >= StartMin) and (NowMin <= EndMin)
      else
        // window spans midnight
        Result := (NowMin >= StartMin) or (NowMin <= EndMin);
    finally
      J.Free;
    end;
  end;

  function IsScheduleActive(const S: TSchedule; const NowUtc: TDateTime): Boolean;
  begin
    Result := True;
    if (S.StartTime <> 0) and (NowUtc < S.StartTime) then Exit(False);
    if (S.EndTime <> 0) and (NowUtc > S.EndTime) then Exit(False);
    if not MatchesRecurring(S.RecurringPattern, NowUtc) then Exit(False);
  end;

begin
  RequestId := '';
  ClientIp := '';
  UserAgent := '';
  IdempotencyKey := '';
  AuthApiKeyId := 0;
  AuthKind := '';

  Handled := True;
  Randomize;
  RequestId := EnsureRequestId;
  ClientIp := GetClientIp;
  UserAgent := Request.GetFieldByName('User-Agent');
  IdempotencyKey := Trim(Request.GetFieldByName('Idempotency-Key'));
  // Normalize optional /api prefix once for all routing decisions
  var NormalizedPath := Request.PathInfo;
  if Copy(NormalizedPath,1,4)='/api' then
    NormalizedPath := Copy(NormalizedPath,5,MaxInt);
  try
    if SameText(NormalizedPath, '/health') and SameText(Request.Method, 'GET') then
    begin
      HandleHealth(Response);
      Response.SendResponse;
      Exit;
    end;

    if DebugEnabled and SameText(NormalizedPath, '/debug/headers') and SameText(Request.Method,'GET') then
    begin
      var Obj := TJSONObject.Create;
      try
        Obj.AddPair('Authorization', Request.GetFieldByName('Authorization'));
        Obj.AddPair('X-Auth-Token', Request.GetFieldByName('X-Auth-Token'));
        Obj.AddPair('QueryAccessToken', Request.QueryFields.Values['access_token']);
        Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := Obj.ToJSON; Response.SendResponse;
      finally Obj.Free; end;
      Exit;
    end;

    if (NormalizedPath = '/organizations') then
    begin
      if SameText(Request.Method, 'GET') then
      begin
        HandleOrganizations(Request, Response);
        Exit;
      end;
      if SameText(Request.Method, 'POST') then
      begin
        // Create organization from JSON body { "Name": "..." }
        var LJSONObj: TJSONObject;
        var NameStr: string;
        var Org: TOrganization;
        var Obj: TJSONObject;
        LJSONObj := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject;
        try
          if (LJSONObj = nil) or (not LJSONObj.TryGetValue<string>('Name', NameStr)) then
          begin
            Response.StatusCode := 400;
            Response.ContentType := 'application/json';
            Response.Content := '{"message":"Invalid payload"}';
            Exit;
          end;
          Org := TOrganization.Create;
          try
            Org.Name := NameStr;
            Org := TOrganizationRepository.CreateOrganization(Org);
            Obj := TJSONObject.Create;
            try
              Obj.AddPair('Id', TJSONNumber.Create(Org.Id));
              Obj.AddPair('Name', Org.Name);
              Response.StatusCode := 200;
              Response.ContentType := 'application/json';
              Response.Content := Obj.ToJSON;
              Response.SendResponse;
            finally
              Obj.Free;
            end;
          finally
            Org.Free;
          end;
        finally
          LJSONObj.Free;
        end;
        Exit;
      end;
    end;

    // Only match /organizations/{id} (no further segments)
    if (Copy(NormalizedPath, 1, 15) = '/organizations/') and SameText(Request.Method, 'GET') and
       (Pos('/', Copy(NormalizedPath, 16, MaxInt)) = 0) then
    begin
      HandleOrganizationById(Request, Response);
      Exit;
    end;

    // ----- Auth -----
    if SameText(NormalizedPath, '/auth/register') and SameText(Request.Method, 'POST') then
    begin
      // Spec: AuthRegisterRequest { Email, Password, OrganizationName }
      // Create organization, then user (Role='Owner'), and return AuthResponse with Token & User
      var Body := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject;
      try
        if (Body = nil) then begin JSONError(400, 'Invalid JSON'); Exit; end;
        var OrgName := Body.GetValue<string>('OrganizationName', '');
        var Email := Body.GetValue<string>('Email', '');
        var Password := Body.GetValue<string>('Password', '');
        if (OrgName='') or (Email='') or (Password='') then begin JSONError(400,'Missing fields'); Exit; end;
        // Create organization
        var Org := TOrganization.Create;
        try
          Org.Name := OrgName;
          Org := TOrganizationRepository.CreateOrganization(Org);
          // Create user
          var User := TUserRepository.CreateUser(Org.Id, Email, Password, 'Owner');
          try
            // Token
            var Header := TJSONObject.Create; Header.AddPair('alg','HS256'); Header.AddPair('typ','JWT');
            var Payload := TJSONObject.Create;
            var NowSec := DateTimeToUnix(Now, False);
            Payload.AddPair('sub', TJSONNumber.Create(User.Id));
            Payload.AddPair('org', TJSONNumber.Create(User.OrganizationId));
            Payload.AddPair('role', User.Role);
            Payload.AddPair('iat', TJSONNumber.Create(NowSec));
            Payload.AddPair('exp', TJSONNumber.Create(NowSec + 86400));
            var Secret := GetEnv('JWT_SECRET','changeme');
            var Token := CreateJWT(Header, Payload, Secret);
            Header.Free; Payload.Free;

            var RefreshToken := GenerateOpaqueToken;
            TRefreshTokenRepository.StoreToken(User.OrganizationId, User.Id, HashSha256Hex(RefreshToken), Now + 30);
            // Build AuthResponse
            var UserObj := TJSONObject.Create;
            UserObj.AddPair('Id', TJSONNumber.Create(User.Id));
            UserObj.AddPair('OrganizationId', TJSONNumber.Create(User.OrganizationId));
            UserObj.AddPair('Email', User.Email);
            UserObj.AddPair('PasswordHash', User.PasswordHash);
            UserObj.AddPair('Role', User.Role);
            var Obj := TJSONObject.Create;
            try
              Obj.AddPair('Token', Token);
              Obj.AddPair('RefreshToken', RefreshToken);
              Obj.AddPair('User', UserObj);
              Obj.AddPair('Success', TJSONBool.Create(True));
              Obj.AddPair('Message', '');
              Response.StatusCode := 200;
              Response.ContentType := 'application/json';
              Response.Content := Obj.ToJSON;
              Response.SendResponse;
            finally Obj.Free; end;
          finally User.Free; end;
        finally Org.Free; end;
      finally Body.Free; end;
      Exit;
    end;
    if SameText(NormalizedPath, '/auth/login') and SameText(Request.Method, 'POST') then
    begin
      var Body := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject;
      try
        if (Body=nil) then begin JSONError(400,'Invalid JSON'); Exit; end;
        var Email := Body.GetValue<string>('Email','');
        var Password := Body.GetValue<string>('Password','');
        if (Email='') or (Password='') then begin JSONError(400,'Missing credentials'); Exit; end;
        var U := TUserRepository.FindByEmail(Email);
        if U=nil then begin JSONError(401,'Invalid email or password'); Exit; end;
        try
          var Parts := U.PasswordHash.Split(['$']);
          if Length(Parts)<>2 then begin JSONError(500,'Stored password format invalid'); Exit; end;
          if not VerifyPassword(Password, Parts[0], Parts[1]) then begin JSONError(401,'Invalid email or password'); Exit; end;
          var Header := TJSONObject.Create; Header.AddPair('alg','HS256'); Header.AddPair('typ','JWT');
          var Payload := TJSONObject.Create; 
          Payload.AddPair('sub', TJSONNumber.Create(U.Id));
          Payload.AddPair('org', TJSONNumber.Create(U.OrganizationId));
          Payload.AddPair('role', U.Role);
          var NowSec := DateTimeToUnix(Now, False);
          Payload.AddPair('iat', TJSONNumber.Create(NowSec));
          Payload.AddPair('exp', TJSONNumber.Create(NowSec + 86400));
          var Secret := GetEnv('JWT_SECRET','changeme');
          var Token := CreateJWT(Header, Payload, Secret);
          Header.Free; Payload.Free;

          var RefreshToken := GenerateOpaqueToken;
          TRefreshTokenRepository.StoreToken(U.OrganizationId, U.Id, HashSha256Hex(RefreshToken), Now + 30);
          // Build AuthResponse as per spec
          var UserObj := TJSONObject.Create;
          UserObj.AddPair('Id', TJSONNumber.Create(U.Id));
          UserObj.AddPair('OrganizationId', TJSONNumber.Create(U.OrganizationId));
          UserObj.AddPair('Email', U.Email);
          UserObj.AddPair('PasswordHash', U.PasswordHash);
          UserObj.AddPair('Role', U.Role);
          var Obj := TJSONObject.Create;
          try
            Obj.AddPair('Token', Token);
            Obj.AddPair('RefreshToken', RefreshToken);
            Obj.AddPair('User', UserObj);
            Obj.AddPair('Success', TJSONBool.Create(True));
            Obj.AddPair('Message', '');
            Response.StatusCode := 200; Response.ContentType := 'application/json';
            Response.Content := Obj.ToJSON; Response.SendResponse;
          finally Obj.Free; end;
        finally U.Free; end;
      finally Body.Free; end;
      Exit;
    end;

    if SameText(NormalizedPath, '/auth/refresh') and SameText(Request.Method, 'POST') then
    begin
      var Body := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject;
      try
        if Body=nil then begin JSONError(400,'Invalid JSON'); Exit; end;
        var RefreshToken := Body.GetValue<string>('RefreshToken','');
        if RefreshToken='' then begin JSONError(400,'Missing RefreshToken'); Exit; end;

        var OrgId: Integer;
        var UserId: Integer;
        var Hash := HashSha256Hex(RefreshToken);
        if not TRefreshTokenRepository.ValidateToken(Hash, OrgId, UserId) then
        begin
          JSONError(401, 'Invalid refresh token', 'invalid_refresh_token');
          Exit;
        end;

        // Rotate refresh token
        TRefreshTokenRepository.RevokeToken(Hash);
        var NewRefreshToken := GenerateOpaqueToken;
        TRefreshTokenRepository.StoreToken(OrgId, UserId, HashSha256Hex(NewRefreshToken), Now + 30);

        var U := TUserRepository.FindById(UserId);
        if U=nil then begin JSONError(401, 'Unauthorized', 'unauthorized'); Exit; end;
        try
          var Header := TJSONObject.Create; Header.AddPair('alg','HS256'); Header.AddPair('typ','JWT');
          var Payload := TJSONObject.Create;
          var NowSec := DateTimeToUnix(Now, False);
          Payload.AddPair('sub', TJSONNumber.Create(U.Id));
          Payload.AddPair('org', TJSONNumber.Create(U.OrganizationId));
          Payload.AddPair('role', U.Role);
          Payload.AddPair('iat', TJSONNumber.Create(NowSec));
          Payload.AddPair('exp', TJSONNumber.Create(NowSec + 86400));
          var Secret := GetEnv('JWT_SECRET','changeme');
          var Token := CreateJWT(Header, Payload, Secret);
          Header.Free; Payload.Free;

          var UserObj := TJSONObject.Create;
          UserObj.AddPair('Id', TJSONNumber.Create(U.Id));
          UserObj.AddPair('OrganizationId', TJSONNumber.Create(U.OrganizationId));
          UserObj.AddPair('Email', U.Email);
          UserObj.AddPair('PasswordHash', U.PasswordHash);
          UserObj.AddPair('Role', U.Role);

          var Obj := TJSONObject.Create;
          try
            Obj.AddPair('Token', Token);
            Obj.AddPair('RefreshToken', NewRefreshToken);
            Obj.AddPair('User', UserObj);
            Obj.AddPair('Success', TJSONBool.Create(True));
            Obj.AddPair('Message', '');
            Response.StatusCode := 200;
            Response.ContentType := 'application/json';
            Response.Content := Obj.ToJSON;
            Response.SendResponse;
          finally
            Obj.Free;
          end;
        finally
          U.Free;
        end;
      finally
        Body.Free;
      end;
      Exit;
    end;

    if SameText(NormalizedPath, '/auth/logout') and SameText(Request.Method, 'POST') then
    begin
      var Body := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject;
      try
        if Body=nil then begin JSONError(400,'Invalid JSON'); Exit; end;
        var RefreshToken := Body.GetValue<string>('RefreshToken','');
        if RefreshToken='' then begin JSONError(400,'Missing RefreshToken'); Exit; end;
        TRefreshTokenRepository.RevokeToken(HashSha256Hex(RefreshToken));
        Response.StatusCode := 204;
        Response.ContentType := 'application/json';
        Response.Content := '';
        Response.SendResponse;
      finally
        Body.Free;
      end;
      Exit;
    end;
    if DebugEnabled and SameText(NormalizedPath, '/auth/debug-verify') and SameText(Request.Method, 'POST') then
    begin
      var Body := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject;
      try
        if Body=nil then begin JSONError(400,'Invalid JSON'); Exit; end;
        var Token := Body.GetValue<string>('Token','');
        if Token='' then begin JSONError(400,'Missing Token'); Exit; end;
        var Parts := Token.Split(['.']); if Length(Parts)<>3 then begin JSONError(400,'Malformed token'); Exit; end;
        var SigningInput := Parts[0] + '.' + Parts[1];
        var Secret := GetEnv('JWT_SECRET','changeme');
        var ExpectedSig := THashSHA2.GetHMACAsBytes(
          TEncoding.UTF8.GetBytes(SigningInput),
          TEncoding.UTF8.GetBytes(Secret),
          THashSHA2.TSHA2Version.SHA256
        );
        var ExpectedB64 := JWTUtils.Base64UrlEncode(ExpectedSig);
        var ActualB64 := Parts[2];
        var Obj := TJSONObject.Create;
        try
          Obj.AddPair('SecretLen', TJSONNumber.Create(Length(Secret)));
          Obj.AddPair('SigningInputLen', TJSONNumber.Create(Length(SigningInput)));
          Obj.AddPair('ExpectedSigLen', TJSONNumber.Create(Length(ExpectedSig)));
          Obj.AddPair('ExpectedSigB64', ExpectedB64);
          Obj.AddPair('ActualSigB64', ActualB64);
          Obj.AddPair('Match', TJSONBool.Create(SameText(ExpectedB64, ActualB64)));
          Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := Obj.ToJSON; Response.SendResponse;
        finally Obj.Free; end;
      finally Body.Free; end;
      Exit;
    end;

    // ----- API Keys -----
    if (Copy(NormalizedPath, 1, 15) = '/organizations/') then
    begin
      var Rest := Copy(NormalizedPath, 16, MaxInt);
      var p := Pos('/', Rest);
      if p > 0 then
      begin
        var OrgIdStr := Copy(Rest, 1, p-1);
        var Tail := Copy(Rest, p+1, MaxInt);
        var PathOrgId := StrToIntDef(OrgIdStr, 0);

        if (PathOrgId > 0) and SameText(Tail, 'api-keys') and SameText(Request.Method, 'GET') then
        begin
          var AuthOrgId, AuthUserId: Integer; var AuthRole: string;
          if not RequireAuth(['api_keys:read'], AuthOrgId, AuthUserId, AuthRole) then Exit;
          if AuthOrgId <> PathOrgId then begin JSONError(403,'Forbidden'); Exit; end;

          var C := NewConnection;
          try
            var Q := TFDQuery.Create(nil);
            try
              Q.Connection := C;
              Q.SQL.Text := 'select ApiKeyID, Name, Scopes, CreatedAt, LastUsedAt, ExpiresAt, RevokedAt from ApiKeys where OrganizationID=:Org order by ApiKeyID';
              Q.ParamByName('Org').AsInteger := PathOrgId;
              Q.Open;
              var Arr := TJSONArray.Create;
              try
                while not Q.Eof do
                begin
                  var Obj := TJSONObject.Create;
                  Obj.AddPair('ApiKeyId', TJSONNumber.Create(Q.FieldByName('ApiKeyID').AsLargeInt));
                  Obj.AddPair('Name', Q.FieldByName('Name').AsString);
                  Obj.AddPair('Scopes', Q.FieldByName('Scopes').AsString);
                  Obj.AddPair('CreatedAt', DateToISO8601(Q.FieldByName('CreatedAt').AsDateTime, True));
                  if not Q.FieldByName('LastUsedAt').IsNull then
                    Obj.AddPair('LastUsedAt', DateToISO8601(Q.FieldByName('LastUsedAt').AsDateTime, True))
                  else
                    Obj.AddPair('LastUsedAt', TJSONNull.Create);
                  if not Q.FieldByName('ExpiresAt').IsNull then
                    Obj.AddPair('ExpiresAt', DateToISO8601(Q.FieldByName('ExpiresAt').AsDateTime, True))
                  else
                    Obj.AddPair('ExpiresAt', TJSONNull.Create);
                  if not Q.FieldByName('RevokedAt').IsNull then
                    Obj.AddPair('RevokedAt', DateToISO8601(Q.FieldByName('RevokedAt').AsDateTime, True))
                  else
                    Obj.AddPair('RevokedAt', TJSONNull.Create);
                  Arr.AddElement(Obj);
                  Q.Next;
                end;
                Response.StatusCode := 200;
                Response.ContentType := 'application/json';
                Response.Content := Arr.ToJSON;
                Response.SendResponse;
              finally
                Arr.Free;
              end;
            finally
              Q.Free;
            end;
          finally
            C.Free;
          end;
          Exit;
        end;

        if (PathOrgId > 0) and SameText(Tail, 'api-keys') and SameText(Request.Method, 'POST') then
        begin
          var AuthOrgId, AuthUserId: Integer; var AuthRole: string;
          if not RequireAuth(['api_keys:write'], AuthOrgId, AuthUserId, AuthRole) then Exit;
          if AuthOrgId <> PathOrgId then begin JSONError(403,'Forbidden'); Exit; end;

          var Body := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject;
          try
            if Body=nil then begin JSONError(400,'Invalid JSON'); Exit; end;
            var Name := Body.GetValue<string>('Name','');
            var Scopes := Body.GetValue<string>('Scopes','');
            var ExpiresAtStr := Body.GetValue<string>('ExpiresAt','');
            if Name='' then begin JSONError(400,'Missing Name'); Exit; end;
            if Scopes='' then begin JSONError(400,'Missing Scopes'); Exit; end;

            var HasExp := False;
            var ExpAt: TDateTime := 0;
            if ExpiresAtStr <> '' then
            begin
              HasExp := TryISO8601ToDate(ExpiresAtStr, ExpAt, True);
              if not HasExp then begin JSONError(400,'Invalid ExpiresAt'); Exit; end;
            end;

            var RawKey := 'ddk_' + GenerateOpaqueToken;
            var KeyHash := HashSha256Hex(RawKey);
            var ApiKeyId := TApiKeyRepository.CreateKey(PathOrgId, AuthUserId, Name, Scopes, KeyHash, ExpAt, HasExp);

            TAuditLogRepository.WriteEvent(PathOrgId, AuthUserId, 'api_key.create', 'api_key', IntToStr(ApiKeyId), nil, RequestId, ClientIp, UserAgent);

            var Obj := TJSONObject.Create;
            try
              Obj.AddPair('ApiKeyId', TJSONNumber.Create(ApiKeyId));
              Obj.AddPair('ApiKey', RawKey);
              Obj.AddPair('Name', Name);
              Obj.AddPair('Scopes', Scopes);
              if HasExp then Obj.AddPair('ExpiresAt', DateToISO8601(ExpAt, True)) else Obj.AddPair('ExpiresAt', TJSONNull.Create);
              Response.StatusCode := 201;
              Response.ContentType := 'application/json';
              Response.Content := Obj.ToJSON;
              Response.SendResponse;
            finally
              Obj.Free;
            end;
          finally
            Body.Free;
          end;
          Exit;
        end;

        if (PathOrgId > 0) and (Copy(Tail, 1, 9) = 'api-keys/') and SameText(Request.Method, 'DELETE') then
        begin
          var AuthOrgId, AuthUserId: Integer; var AuthRole: string;
          if not RequireAuth(['api_keys:write'], AuthOrgId, AuthUserId, AuthRole) then Exit;
          if AuthOrgId <> PathOrgId then begin JSONError(403,'Forbidden'); Exit; end;

          var ApiKeyId := StrToInt64Def(Copy(Tail, 10, MaxInt), 0);
          if ApiKeyId <= 0 then begin JSONError(400,'Invalid api key id'); Exit; end;
          if not TApiKeyRepository.RevokeKey(PathOrgId, ApiKeyId) then begin JSONError(404,'Not found'); Exit; end;

          TAuditLogRepository.WriteEvent(PathOrgId, AuthUserId, 'api_key.revoke', 'api_key', IntToStr(ApiKeyId), nil, RequestId, ClientIp, UserAgent);
          Response.StatusCode := 204;
          Response.ContentType := 'application/json';
          Response.Content := '';
          Response.SendResponse;
          Exit;
        end;

        // Webhooks
        if (PathOrgId > 0) and SameText(Tail, 'webhooks') and SameText(Request.Method, 'GET') then
        begin
          var AuthOrgId, AuthUserId: Integer; var AuthRole: string;
          if not RequireAuth(['webhooks:read'], AuthOrgId, AuthUserId, AuthRole) then Exit;
          if AuthOrgId <> PathOrgId then begin JSONError(403,'Forbidden'); Exit; end;

          var Hooks := TWebhookRepository.ListByOrganization(PathOrgId);
          try
            var Arr := TJSONArray.Create;
            try
              for var Hk in Hooks do
              begin
                var Obj := TJSONObject.Create;
                Obj.AddPair('WebhookId', TJSONNumber.Create(Hk.Id));
                Obj.AddPair('Url', Hk.Url);
                Obj.AddPair('Events', Hk.Events);
                Obj.AddPair('IsActive', TJSONBool.Create(Hk.IsActive));
                Arr.AddElement(Obj);
              end;
              Response.StatusCode := 200;
              Response.ContentType := 'application/json';
              Response.Content := Arr.ToJSON;
              Response.SendResponse;
            finally
              Arr.Free;
            end;
          finally
            Hooks.Free;
          end;
          Exit;
        end;

        if (PathOrgId > 0) and SameText(Tail, 'webhooks') and SameText(Request.Method, 'POST') then
        begin
          var AuthOrgId, AuthUserId: Integer; var AuthRole: string;
          if not RequireAuth(['webhooks:write'], AuthOrgId, AuthUserId, AuthRole) then Exit;
          if AuthOrgId <> PathOrgId then begin JSONError(403,'Forbidden'); Exit; end;

          var Body := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject;
          try
            if Body=nil then begin JSONError(400,'Invalid JSON'); Exit; end;
            var Url := Body.GetValue<string>('Url','');
            var Events := Body.GetValue<string>('Events','');
            var Secret := Body.GetValue<string>('Secret','');
            if Url='' then begin JSONError(400,'Missing Url'); Exit; end;
            if Events='' then begin JSONError(400,'Missing Events'); Exit; end;
            if Secret='' then Secret := GenerateOpaqueToken;

            var Hook := TWebhookRepository.CreateWebhook(PathOrgId, Url, Secret, Events);
            try
              TAuditLogRepository.WriteEvent(PathOrgId, AuthUserId, 'webhook.create', 'webhook', IntToStr(Hook.Id), nil, RequestId, ClientIp, UserAgent);

              var Obj := TJSONObject.Create;
              try
                Obj.AddPair('WebhookId', TJSONNumber.Create(Hook.Id));
                Obj.AddPair('Url', Hook.Url);
                Obj.AddPair('Events', Hook.Events);
                Obj.AddPair('IsActive', TJSONBool.Create(Hook.IsActive));
                Obj.AddPair('Secret', Hook.Secret);
                Response.StatusCode := 201;
                Response.ContentType := 'application/json';
                Response.Content := Obj.ToJSON;
                Response.SendResponse;
              finally
                Obj.Free;
              end;
            finally
              Hook.Free;
            end;
          finally
            Body.Free;
          end;
          Exit;
        end;

        if (PathOrgId > 0) and (Copy(Tail, 1, 9) = 'webhooks/') and SameText(Request.Method, 'GET') then
        begin
          var AuthOrgId, AuthUserId: Integer; var AuthRole: string;
          if not RequireAuth(['webhooks:read'], AuthOrgId, AuthUserId, AuthRole) then Exit;
          if AuthOrgId <> PathOrgId then begin JSONError(403,'Forbidden'); Exit; end;

          var WebhookId := StrToInt64Def(Copy(Tail, 10, MaxInt), 0);
          if WebhookId <= 0 then begin JSONError(400,'Invalid webhook id'); Exit; end;
          var Hook := TWebhookRepository.GetById(WebhookId);
          if (Hook=nil) or (Hook.OrganizationId <> PathOrgId) then begin if Hook<>nil then Hook.Free; JSONError(404,'Not found'); Exit; end;
          try
            var Obj := TJSONObject.Create;
            try
              Obj.AddPair('WebhookId', TJSONNumber.Create(Hook.Id));
              Obj.AddPair('Url', Hook.Url);
              Obj.AddPair('Events', Hook.Events);
              Obj.AddPair('IsActive', TJSONBool.Create(Hook.IsActive));
              Response.StatusCode := 200;
              Response.ContentType := 'application/json';
              Response.Content := Obj.ToJSON;
              Response.SendResponse;
            finally
              Obj.Free;
            end;
          finally
            Hook.Free;
          end;
          Exit;
        end;

        if (PathOrgId > 0) and (Copy(Tail, 1, 9) = 'webhooks/') and SameText(Request.Method, 'DELETE') then
        begin
          var AuthOrgId, AuthUserId: Integer; var AuthRole: string;
          if not RequireAuth(['webhooks:write'], AuthOrgId, AuthUserId, AuthRole) then Exit;
          if AuthOrgId <> PathOrgId then begin JSONError(403,'Forbidden'); Exit; end;

          var WebhookId := StrToInt64Def(Copy(Tail, 10, MaxInt), 0);
          if WebhookId <= 0 then begin JSONError(400,'Invalid webhook id'); Exit; end;
          if not TWebhookRepository.DeleteWebhook(PathOrgId, WebhookId) then begin JSONError(404,'Not found'); Exit; end;
          TAuditLogRepository.WriteEvent(PathOrgId, AuthUserId, 'webhook.delete', 'webhook', IntToStr(WebhookId), nil, RequestId, ClientIp, UserAgent);
          Response.StatusCode := 204;
          Response.ContentType := 'application/json';
          Response.Content := '';
          Response.SendResponse;
          Exit;
        end;

        // Audit log
        if (PathOrgId > 0) and SameText(Tail, 'audit-log') and SameText(Request.Method, 'GET') then
        begin
          var AuthOrgId, AuthUserId: Integer; var AuthRole: string;
          if not RequireAuth(['audit:read'], AuthOrgId, AuthUserId, AuthRole) then Exit;
          if AuthOrgId <> PathOrgId then begin JSONError(403,'Forbidden'); Exit; end;

          var Limit := StrToIntDef(Request.QueryFields.Values['limit'], 100);
          if Limit <= 0 then Limit := 100;
          if Limit > 200 then Limit := 200;
          var BeforeId := StrToInt64Def(Request.QueryFields.Values['beforeId'], 0);

          var C := NewConnection;
          try
            var Q := TFDQuery.Create(nil);
            try
              Q.Connection := C;
              Q.SQL.Text := 'select AuditLogID, CreatedAt, UserID, Action, ObjectType, ObjectId, Details, RequestId, IpAddress, UserAgent '
                          + 'from AuditLogs where OrganizationID=:Org '
                          + 'and (:BeforeId=0 or AuditLogID < :BeforeId) '
                          + 'order by AuditLogID desc limit ' + IntToStr(Limit + 1);
              Q.ParamByName('Org').AsInteger := PathOrgId;
              Q.ParamByName('BeforeId').AsLargeInt := BeforeId;
              Q.Open;

              var Arr := TJSONArray.Create;
              var NextBeforeId: Int64 := 0;
              try
                var Count := 0;
                while (not Q.Eof) and (Count < Limit) do
                begin
                  var Obj := TJSONObject.Create;
                  Obj.AddPair('AuditLogId', TJSONNumber.Create(Q.FieldByName('AuditLogID').AsLargeInt));
                  Obj.AddPair('CreatedAt', DateToISO8601(Q.FieldByName('CreatedAt').AsDateTime, True));
                  if not Q.FieldByName('UserID').IsNull then
                    Obj.AddPair('UserId', TJSONNumber.Create(Q.FieldByName('UserID').AsInteger))
                  else
                    Obj.AddPair('UserId', TJSONNull.Create);
                  Obj.AddPair('Action', Q.FieldByName('Action').AsString);
                  Obj.AddPair('ObjectType', Q.FieldByName('ObjectType').AsString);
                  Obj.AddPair('ObjectId', Q.FieldByName('ObjectId').AsString);
                  Obj.AddPair('Details', Q.FieldByName('Details').AsString);
                  Obj.AddPair('RequestId', Q.FieldByName('RequestId').AsString);
                  Obj.AddPair('IpAddress', Q.FieldByName('IpAddress').AsString);
                  Obj.AddPair('UserAgent', Q.FieldByName('UserAgent').AsString);
                  Arr.AddElement(Obj);
                  Inc(Count);
                  Q.Next;
                end;

                if not Q.Eof then
                  NextBeforeId := Q.FieldByName('AuditLogID').AsLargeInt;

                var OutObj := TJSONObject.Create;
                try
                  OutObj.AddPair('Items', Arr);
                  if NextBeforeId > 0 then
                    OutObj.AddPair('NextBeforeId', TJSONNumber.Create(NextBeforeId))
                  else
                    OutObj.AddPair('NextBeforeId', TJSONNull.Create);
                  Response.StatusCode := 200;
                  Response.ContentType := 'application/json';
                  Response.Content := OutObj.ToJSON;
                  Response.SendResponse;
                finally
                  OutObj.Free;
                end;

              except
                Arr.Free;
                raise;
              end;
            finally
              Q.Free;
            end;
          finally
            C.Free;
          end;
          Exit;
        end;
      end;
    end;

    // Plans and Roles
    if SameText(NormalizedPath, '/plans') and SameText(Request.Method, 'GET') then
    begin
      // Return all active plans
      var C := NewConnection; try
        var Q := TFDQuery.Create(nil); try
          Q.Connection := C; Q.SQL.Text := 'select * from Plans where IsActive=true order by PlanID'; Q.Open;
          var Arr := TJSONArray.Create; try
            while not Q.Eof do begin
              var P := TJSONObject.Create;
              P.AddPair('PlanID', TJSONNumber.Create(Q.FieldByName('PlanID').AsInteger));
              P.AddPair('Name', Q.FieldByName('Name').AsString);
              P.AddPair('Price', TJSONNumber.Create(Q.FieldByName('Price').AsFloat));
              P.AddPair('MaxDisplays', TJSONNumber.Create(Q.FieldByName('MaxDisplays').AsInteger));
              P.AddPair('MaxCampaigns', TJSONNumber.Create(Q.FieldByName('MaxCampaigns').AsInteger));
              P.AddPair('MaxMediaStorageGB', TJSONNumber.Create(Q.FieldByName('MaxMediaStorageGB').AsInteger));
              P.AddPair('IsActive', TJSONBool.Create(Q.FieldByName('IsActive').AsBoolean));
              Arr.AddElement(P);
              Q.Next;
            end;
            Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := Arr.ToJSON; Response.SendResponse;
          finally Arr.Free; end;
        finally Q.Free; end;
      finally C.Free; end;
      Exit;
    end;
    if SameText(NormalizedPath, '/roles') and SameText(Request.Method, 'GET') then
    begin
      var Arr := TJSONArray.Create; try
        Arr.Add('Owner'); Arr.Add('ContentManager'); Arr.Add('Viewer');
        Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := Arr.ToJSON; Response.SendResponse;
      finally Arr.Free; end;
      Exit;
    end;

    // Organization sub-resources
     if (Copy(NormalizedPath, 1, 15) = '/organizations/') and SameText(Request.Method, 'GET') and
       (Pos('/subscription', NormalizedPath) > 0) then
    begin
      // /organizations/{OrganizationId}/subscription
      var OrgIdStr := Copy(NormalizedPath, 16, MaxInt);
      var Slash := Pos('/', OrgIdStr);
      if Slash>0 then OrgIdStr := Copy(OrgIdStr, 1, Slash-1);
      var OrgId := StrToIntDef(OrgIdStr,0);
      if OrgId=0 then begin JSONError(400,'Invalid organization id'); Exit; end;
      var C := NewConnection; try
        var Q := TFDQuery.Create(nil); try
          Q.Connection := C; Q.SQL.Text := 'select * from Subscriptions where OrganizationID=:Org'; Q.ParamByName('Org').AsInteger := OrgId; Q.Open;
          if Q.Eof then begin JSONError(404,'Not found'); Exit; end;
          var O := TJSONObject.Create; try
            O.AddPair('SubscriptionID', TJSONNumber.Create(Q.FieldByName('SubscriptionID').AsInteger));
            O.AddPair('OrganizationID', TJSONNumber.Create(Q.FieldByName('OrganizationID').AsInteger));
            O.AddPair('PlanID', TJSONNumber.Create(Q.FieldByName('PlanID').AsInteger));
            O.AddPair('Status', Q.FieldByName('Status').AsString);
            O.AddPair('CurrentPeriodEnd', Q.FieldByName('CurrentPeriodEnd').AsString);
            Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := O.ToJSON; Response.SendResponse;
          finally O.Free; end;
        finally Q.Free; end;
      finally C.Free; end;
      Exit;
    end;
    if (Copy(NormalizedPath, 1, 15) = '/organizations/') and (Pos('/displays', NormalizedPath) > 0) then
    begin
      // /organizations/{orgId}/displays
      var OrgIdStr := Copy(NormalizedPath, 16, MaxInt);
      var Slash := Pos('/', OrgIdStr);
      if Slash>0 then OrgIdStr := Copy(OrgIdStr, 1, Slash-1);
      var OrgId := StrToIntDef(OrgIdStr,0);
      if OrgId=0 then begin JSONError(400,'Invalid organization id'); Exit; end;
      // Enforce auth for org-scoped writes
      if SameText(Request.Method,'GET') then
      begin
        var TokOrg, TokUser: Integer; var TokRole: string;
        if not RequireAuth(['displays:read'], TokOrg, TokUser, TokRole) then Exit;
        if TokOrg<>OrgId then begin JSONError(403,'Forbidden'); Exit; end;
        var List := TDisplayRepository.ListByOrganization(OrgId);
        try
          var Arr := TJSONArray.Create;
          try
            for var D in List do
            begin
              var It := TJSONObject.Create;
              It.AddPair('Id', TJSONNumber.Create(D.Id));
              It.AddPair('Name', D.Name);
              It.AddPair('Orientation', D.Orientation);
              Arr.AddElement(It);
            end;
            var Wrapper := TJSONObject.Create; try
              Wrapper.AddPair('value', Arr);
              Response.StatusCode := 200; Response.ContentType := 'application/json';
              Response.Content := Wrapper.ToJSON; Response.SendResponse;
            finally Wrapper.Free; end;
          finally Arr.Free; end;
        finally List.Free; end;
        Exit;
      end
      else if SameText(Request.Method,'POST') then
      begin
        var TokOrg, TokUser: Integer; var TokRole: string;
        if not RequireAuth(['displays:write'], TokOrg, TokUser, TokRole) then Exit;
        if TokOrg<>OrgId then begin JSONError(403,'Forbidden'); Exit; end;
        if not CheckPlanAllowsDisplay(OrgId) then begin JSONError(402,'Display limit reached for plan'); Exit; end;
        if TryReplayIdempotency(OrgId) then Exit;
        var Body := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject;
        try
          if Body=nil then begin JSONError(400,'Invalid JSON'); Exit; end;
          var Name := Body.GetValue<string>('Name','');
          var Orientation := Body.GetValue<string>('Orientation','');
          if (Name='') or (Orientation='') then begin JSONError(400,'Missing fields'); Exit; end;
          var D := TDisplayRepository.CreateDisplay(OrgId, Name, Orientation);
          try
            var Obj := TJSONObject.Create; Obj.AddPair('Id', TJSONNumber.Create(D.Id)); Obj.AddPair('Name', D.Name); Obj.AddPair('Orientation', D.Orientation);
            var OutBody := Obj.ToJSON;
            Obj.Free;
            StoreIdempotency(OrgId, 201, OutBody);
            Response.StatusCode := 201; Response.ContentType := 'application/json'; Response.Content := OutBody; Response.SendResponse;
          finally D.Free; end;
        finally Body.Free; end;
        Exit;
      end;
    end;

    // Device pairing: device asks for ephemeral provisioning token
    if (SameText(Request.PathInfo, '/device/provisioning/token') or SameText(Request.PathInfo, '/api/device/provisioning/token')) and SameText(Request.Method,'POST') then
    begin
      var Body := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject; try
        if Body=nil then begin JSONError(400,'Invalid JSON'); Exit; end;
        var HardwareId := Body.GetValue<string>('HardwareId',''); if HardwareId='' then begin JSONError(400,'Missing HardwareId'); Exit; end;
        var Info := TProvisioningTokenRepository.CreateToken(600);
        // Optionally store hardware id
        var C := NewConnection; try
          var Q := TFDQuery.Create(nil); try
            Q.Connection := C; Q.SQL.Text := 'update ProvisioningTokens set HardwareId=:H where Token=:T';
            Q.ParamByName('H').AsString := HardwareId; Q.ParamByName('T').AsString := Info.Token; Q.ExecSQL;
          finally Q.Free; end;
        finally C.Free; end;
        var Obj := TJSONObject.Create; 
        Obj.AddPair('ProvisioningToken', Info.Token); 
        Obj.AddPair('ExpiresInSeconds', TJSONNumber.Create(600));
        Obj.AddPair('QrCodeData', 'displaydeck://claim/' + Info.Token);
        Obj.AddPair('Instructions', 'Scan this QR code with the DisplayDeck mobile app to pair this display.');
        Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := Obj.ToJSON; Response.SendResponse; Obj.Free;
      finally Body.Free; end;
      Exit;
    end;

    // Account-side claiming: link a device provisioning token to an organization (via JWT org)
    if (Copy(NormalizedPath,1,15) = '/organizations/') and (Pos('/displays/claim', NormalizedPath)>0) and SameText(Request.Method,'POST') then
    begin
      var OrgIdStr := Copy(NormalizedPath, 16, MaxInt); var Slash := Pos('/', OrgIdStr); if Slash>0 then OrgIdStr := Copy(OrgIdStr,1,Slash-1);
      var OrgId := StrToIntDef(OrgIdStr,0); if OrgId=0 then begin JSONError(400,'Invalid organization id'); Exit; end;
      var TokOrg, TokUser: Integer; var TokRole: string;
      if not RequireAuth(['displays:write'], TokOrg, TokUser, TokRole) then Exit;
      if TokOrg<>OrgId then begin JSONError(403,'Forbidden'); Exit; end;
      if not CheckPlanAllowsDisplay(OrgId) then begin JSONError(402,'Display limit reached for plan'); Exit; end;
      if TryReplayIdempotency(OrgId) then Exit;
      var Body := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject; try
        if Body=nil then begin JSONError(400,'Invalid JSON'); Exit; end;
        var ProvisioningToken := Body.GetValue<string>('ProvisioningToken',''); if ProvisioningToken='' then begin JSONError(400,'Missing ProvisioningToken'); Exit; end;
        var Name := Body.GetValue<string>('Name','New Display'); var Orientation := Body.GetValue<string>('Orientation','Landscape');
        if not TProvisioningTokenRepository.ExistsValid(ProvisioningToken) then begin JSONError(400,'Invalid or expired token'); Exit; end;
        var C := NewConnection; try
          // create display now that token is valid
          var D := TDisplayRepository.CreateDisplay(OrgId, Name, Orientation);
          try
            if not TProvisioningTokenRepository.ValidateAndClaim(ProvisioningToken) then begin JSONError(400,'Token already claimed'); Exit; end;
            var U := TFDQuery.Create(nil); try
              U.Connection := C; U.SQL.Text := 'update ProvisioningTokens set DisplayID=:D, OrganizationID=:O where Token=:T';
              U.ParamByName('D').AsInteger := D.Id; U.ParamByName('O').AsInteger := OrgId; U.ParamByName('T').AsString := ProvisioningToken; U.ExecSQL;
            finally U.Free; end;
            var Obj := TJSONObject.Create; Obj.AddPair('Id', TJSONNumber.Create(D.Id)); Obj.AddPair('Name', D.Name); Obj.AddPair('Orientation', D.Orientation);
            var OutBody := Obj.ToJSON;
            Obj.Free;
            StoreIdempotency(OrgId, 200, OutBody);
            Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := OutBody; Response.SendResponse;
          finally D.Free; end;
        finally C.Free; end;
      finally Body.Free; end;
      Exit;
    end;

    // Organization campaigns: /organizations/{OrganizationId}/campaigns
     if (Copy(NormalizedPath, 1, 15) = '/organizations/') and
       (Pos('/campaigns', NormalizedPath) > 0) then
    begin
      var OrgIdStr := Copy(NormalizedPath, 16, MaxInt);
      var Slash := Pos('/', OrgIdStr); if Slash>0 then OrgIdStr := Copy(OrgIdStr, 1, Slash-1);
      var OrgId := StrToIntDef(OrgIdStr,0); if OrgId=0 then begin JSONError(400,'Invalid organization id'); Exit; end;
      if SameText(Request.Method,'GET') then
      begin
        var TokOrg, TokUser: Integer; var TokRole: string;
        if not RequireAuth(['campaigns:read'], TokOrg, TokUser, TokRole) then Exit;
        if TokOrg<>OrgId then begin JSONError(403,'Forbidden'); Exit; end;
        var L := TCampaignRepository.ListByOrganization(OrgId);
        try
          var Arr := TJSONArray.Create; try
            for var Cmp in L do
            begin
              var O := TJSONObject.Create;
              O.AddPair('Id', TJSONNumber.Create(Cmp.Id));
              O.AddPair('OrganizationId', TJSONNumber.Create(Cmp.OrganizationId));
              O.AddPair('Name', Cmp.Name);
              O.AddPair('Orientation', Cmp.Orientation);
              Arr.AddElement(O);
            end;
            var Wrapper := TJSONObject.Create; try
              Wrapper.AddPair('value', Arr);
              Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := Wrapper.ToJSON; Response.SendResponse;
            finally Wrapper.Free; end;
          finally Arr.Free; end;
        finally L.Free; end; Exit;
      end
      else if SameText(Request.Method,'POST') then
      begin
        var TokOrg, TokUser: Integer; var TokRole: string;
        if not RequireAuth(['campaigns:write'], TokOrg, TokUser, TokRole) then Exit;
        if TokOrg<>OrgId then begin JSONError(403,'Forbidden'); Exit; end;
        if TryReplayIdempotency(OrgId) then Exit;
        var Body := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject; try
          if Body=nil then begin JSONError(400,'Invalid JSON'); Exit; end;
          var Name := Body.GetValue<string>('Name',''); var Orientation := Body.GetValue<string>('Orientation','');
          if Name='' then begin JSONError(400,'Missing Name'); Exit; end;
          var Cmp := TCampaignRepository.CreateCampaign(OrgId, Name, Orientation);
          try
            var O := TJSONObject.Create; O.AddPair('Id', TJSONNumber.Create(Cmp.Id)); O.AddPair('OrganizationId', TJSONNumber.Create(Cmp.OrganizationId)); O.AddPair('Name', Cmp.Name); O.AddPair('Orientation', Cmp.Orientation);
            var OutBody := O.ToJSON;
            O.Free;
            StoreIdempotency(OrgId, 201, OutBody);
            Response.StatusCode := 201; Response.ContentType := 'application/json'; Response.Content := OutBody; Response.SendResponse;
          finally Cmp.Free; end;
        finally Body.Free; end; Exit;
      end;
    end;

    // Displays
    if (Copy(NormalizedPath, 1, 10) = '/displays/') then
    begin
      var Tail := Copy(NormalizedPath, 11, MaxInt);
      var NextSlash := Pos('/', Tail);
      var IdStr := Tail; if NextSlash>0 then IdStr := Copy(Tail,1,NextSlash-1);
      var Id := StrToIntDef(IdStr,0);
      if (Id=0) then begin JSONError(400,'Invalid display id'); Exit; end;
      if Pos('/campaign-assignments', NormalizedPath) > 0 then
      begin
        var Disp := TDisplayRepository.GetById(Id);
        if Disp=nil then begin JSONError(404,'Not found'); Exit; end;
        try
          var TokOrg, TokUser: Integer; var TokRole: string;
          if SameText(Request.Method,'GET') then
          begin
            if not RequireAuth(['assignments:read'], TokOrg, TokUser, TokRole) then Exit;
          end
          else
          begin
            if not RequireAuth(['assignments:write'], TokOrg, TokUser, TokRole) then Exit;
          end;
          if TokOrg<>Disp.OrganizationId then begin JSONError(403,'Forbidden'); Exit; end;

        if SameText(Request.Method,'GET') then
        begin
          var L := TDisplayCampaignRepository.ListByDisplay(Id);
          try
            var Arr := TJSONArray.Create;
            try
              for var A in L do
              begin
                var It := TJSONObject.Create;
                It.AddPair('Id', TJSONNumber.Create(A.Id));
                It.AddPair('CampaignId', TJSONNumber.Create(A.CampaignId));
                It.AddPair('IsPrimary', TJSONBool.Create(A.IsPrimary));
                Arr.AddElement(It);
              end;
              var Wrapper := TJSONObject.Create; try
                Wrapper.AddPair('value', Arr);
                Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := Wrapper.ToJSON; Response.SendResponse;
              finally Wrapper.Free; end;
            finally Arr.Free; end;
          finally L.Free; end;
          Exit;
        end
        else if SameText(Request.Method,'POST') then
        begin
          if TryReplayIdempotency(Disp.OrganizationId) then Exit;
          var Body := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject;
          try
            if Body=nil then begin JSONError(400,'Invalid JSON'); Exit; end;
            var CampaignId := Body.GetValue<Integer>('CampaignId',0);
            var IsPrimary := Body.GetValue<Boolean>('IsPrimary',True);
            if CampaignId=0 then begin JSONError(400,'Missing CampaignId'); Exit; end;

            // Enforce orientation match (displays have no gyro; campaigns must fit)
            var Cmp := TCampaignRepository.GetById(CampaignId);
            if Cmp=nil then begin JSONError(404,'Campaign not found'); Exit; end;
            try
              if (Cmp.Orientation<>'') and (Disp.Orientation<>'') and (not SameText(Cmp.Orientation, Disp.Orientation)) then
              begin
                JSONError(400, 'Campaign orientation does not match display orientation');
                Exit;
              end;
            finally
              Cmp.Free;
            end;

            var A := TDisplayCampaignRepository.CreateAssignment(Id, CampaignId, IsPrimary);
            try
              var Obj := TJSONObject.Create; Obj.AddPair('Id', TJSONNumber.Create(A.Id)); Obj.AddPair('CampaignId', TJSONNumber.Create(A.CampaignId)); Obj.AddPair('IsPrimary', TJSONBool.Create(A.IsPrimary));
              var OutBody := Obj.ToJSON;
              Obj.Free;
              StoreIdempotency(Disp.OrganizationId, 201, OutBody);
              Response.StatusCode := 201; Response.ContentType := 'application/json'; Response.Content := OutBody; Response.SendResponse;
            finally A.Free; end;
          finally Body.Free; end;
          Exit;
        end;

        finally
          Disp.Free;
        end;
      end
      else
      begin
        if SameText(Request.Method,'GET') then
        begin
          var D := TDisplayRepository.GetById(Id);
          if D=nil then begin JSONError(404,'Not found'); Exit; end;
          try
            var TokOrg, TokUser: Integer; var TokRole: string;
            if not RequireAuth(['displays:read'], TokOrg, TokUser, TokRole) then Exit;
            if TokOrg<>D.OrganizationId then begin JSONError(403,'Forbidden'); Exit; end;
            var Obj := TJSONObject.Create; Obj.AddPair('Id', TJSONNumber.Create(D.Id)); Obj.AddPair('Name', D.Name); Obj.AddPair('Orientation', D.Orientation);
            Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := Obj.ToJSON; Response.SendResponse; Obj.Free;
          finally D.Free; end;
          Exit;
        end
        else if SameText(Request.Method,'PUT') then
        begin
          var DExisting := TDisplayRepository.GetById(Id);
          if DExisting=nil then begin JSONError(404,'Not found'); Exit; end;
          try
            var TokOrg, TokUser: Integer; var TokRole: string;
            if not RequireAuth(['displays:write'], TokOrg, TokUser, TokRole) then Exit;
            if TokOrg<>DExisting.OrganizationId then begin JSONError(403,'Forbidden'); Exit; end;

            var Body := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject;
            try
              if Body=nil then begin JSONError(400,'Invalid JSON'); Exit; end;
              var Name := Body.GetValue<string>('Name','');
              var Orientation := Body.GetValue<string>('Orientation','');
              if (Name='') or (Orientation='') then begin JSONError(400,'Missing fields'); Exit; end;

              var DUpdated := TDisplayRepository.UpdateDisplay(Id, Name, Orientation);
              if DUpdated=nil then begin JSONError(404,'Not found'); Exit; end;
              try
                var Obj := TJSONObject.Create;
                Obj.AddPair('Id', TJSONNumber.Create(DUpdated.Id));
                Obj.AddPair('Name', DUpdated.Name);
                Obj.AddPair('Orientation', DUpdated.Orientation);
                Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := Obj.ToJSON; Response.SendResponse; Obj.Free;
              finally DUpdated.Free; end;
            finally Body.Free; end;

          finally
            DExisting.Free;
          end;
          Exit;
        end
        else if SameText(Request.Method,'DELETE') then
        begin
          var D := TDisplayRepository.GetById(Id);
          if D=nil then begin JSONError(404,'Not found'); Exit; end;
          try
            var TokOrg, TokUser: Integer; var TokRole: string;
            if not RequireAuth(['displays:write'], TokOrg, TokUser, TokRole) then Exit;
            if TokOrg<>D.OrganizationId then begin JSONError(403,'Forbidden'); Exit; end;
          finally D.Free; end;
          TDisplayRepository.DeleteDisplay(Id);
          Response.StatusCode := 204; Response.ContentType := 'application/json'; Response.Content := ''; Response.SendResponse; Exit;
        end;
      end;
    end;

    // Campaigns and items
    if (Copy(NormalizedPath, 1, 11) = '/campaigns/') then
    begin
      if Pos('/schedules', NormalizedPath) > 0 then
      begin
        // /campaigns/{CampaignId}/schedules
        var IdStr := Copy(NormalizedPath, 12, MaxInt);
        var Slash := Pos('/', IdStr); if Slash>0 then IdStr := Copy(IdStr,1,Slash-1);
        var CampId := StrToIntDef(IdStr,0); if CampId=0 then begin JSONError(400,'Invalid campaign id'); Exit; end;

        var Camp := TCampaignRepository.GetById(CampId);
        if Camp=nil then begin JSONError(404,'Not found'); Exit; end;
        try
          var TokOrg, TokUser: Integer; var TokRole: string;
          if SameText(Request.Method,'GET') then
          begin
            if not RequireAuth(['campaigns:read'], TokOrg, TokUser, TokRole) then Exit;
          end
          else
          begin
            if not RequireAuth(['campaigns:write'], TokOrg, TokUser, TokRole) then Exit;
          end;
          if TokOrg<>Camp.OrganizationId then begin JSONError(403,'Forbidden'); Exit; end;

          if SameText(Request.Method,'GET') then
          begin
            var L := TScheduleRepository.ListByCampaign(CampId);
            try
              var Arr := TJSONArray.Create;
              try
                for var S in L do
                begin
                  var O := TJSONObject.Create;
                  O.AddPair('Id', TJSONNumber.Create(S.Id));
                  O.AddPair('CampaignId', TJSONNumber.Create(S.CampaignId));
                  if S.StartTime <> 0 then O.AddPair('StartTime', DateToISO8601(S.StartTime, True)) else O.AddPair('StartTime', TJSONNull.Create);
                  if S.EndTime <> 0 then O.AddPair('EndTime', DateToISO8601(S.EndTime, True)) else O.AddPair('EndTime', TJSONNull.Create);
                  if S.RecurringPattern <> '' then O.AddPair('RecurringPattern', S.RecurringPattern) else O.AddPair('RecurringPattern', TJSONNull.Create);
                  Arr.AddElement(O);
                end;
                var Wrapper := TJSONObject.Create;
                try
                  Wrapper.AddPair('value', Arr);
                  Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := Wrapper.ToJSON; Response.SendResponse;
                finally Wrapper.Free; end;
              finally Arr.Free; end;
            finally L.Free; end;
            Exit;
          end
          else if SameText(Request.Method,'POST') then
          begin
            if TryReplayIdempotency(Camp.OrganizationId) then Exit;
            var Body := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject;
            try
              if Body=nil then begin JSONError(400,'Invalid JSON'); Exit; end;
              var StartStrVal := Body.GetValue('StartTime');
              var EndStrVal := Body.GetValue('EndTime');
              var RecVal := Body.GetValue('RecurringPattern');

              var HasStart := False;
              var HasEnd := False;
              var StartAt: TDateTime := 0;
              var EndAt: TDateTime := 0;

              if (StartStrVal<>nil) and (not (StartStrVal is TJSONNull)) then
              begin
                HasStart := TryISO8601ToDate(StartStrVal.Value, StartAt, True);
                if not HasStart then begin JSONError(400,'Invalid StartTime'); Exit; end;
              end;
              if (EndStrVal<>nil) and (not (EndStrVal is TJSONNull)) then
              begin
                HasEnd := TryISO8601ToDate(EndStrVal.Value, EndAt, True);
                if not HasEnd then begin JSONError(400,'Invalid EndTime'); Exit; end;
              end;
              if HasStart and HasEnd and (EndAt < StartAt) then begin JSONError(400,'EndTime must be >= StartTime'); Exit; end;

              var Rec := '';
              if (RecVal<>nil) and (not (RecVal is TJSONNull)) then
                Rec := RecVal.Value;

              var S := TScheduleRepository.CreateSchedule(CampId, StartAt, EndAt, HasStart, HasEnd, Rec);
              try
                var O := TJSONObject.Create;
                O.AddPair('Id', TJSONNumber.Create(S.Id));
                O.AddPair('CampaignId', TJSONNumber.Create(S.CampaignId));
                if HasStart then O.AddPair('StartTime', DateToISO8601(S.StartTime, True)) else O.AddPair('StartTime', TJSONNull.Create);
                if HasEnd then O.AddPair('EndTime', DateToISO8601(S.EndTime, True)) else O.AddPair('EndTime', TJSONNull.Create);
                if S.RecurringPattern <> '' then O.AddPair('RecurringPattern', S.RecurringPattern) else O.AddPair('RecurringPattern', TJSONNull.Create);
                var OutBody := O.ToJSON;
                O.Free;
                StoreIdempotency(Camp.OrganizationId, 201, OutBody);
                Response.StatusCode := 201; Response.ContentType := 'application/json'; Response.Content := OutBody; Response.SendResponse;
              finally S.Free; end;
            finally Body.Free; end;
            Exit;
          end;
        finally Camp.Free; end;
      end
      else if Pos('/items', NormalizedPath) > 0 then
      begin
        var IdStr := Copy(NormalizedPath, 12, MaxInt);
        var Slash := Pos('/', IdStr); if Slash>0 then IdStr := Copy(IdStr,1,Slash-1);
        var CampId := StrToIntDef(IdStr,0); if CampId=0 then begin JSONError(400,'Invalid campaign id'); Exit; end;

        var Camp := TCampaignRepository.GetById(CampId);
        if Camp=nil then begin JSONError(404,'Not found'); Exit; end;
        try
          var TokOrg, TokUser: Integer; var TokRole: string;
          if SameText(Request.Method,'GET') then
          begin
            if not RequireAuth(['campaigns:read'], TokOrg, TokUser, TokRole) then Exit;
          end
          else
          begin
            if not RequireAuth(['campaigns:write'], TokOrg, TokUser, TokRole) then Exit;
          end;
          if TokOrg<>Camp.OrganizationId then begin JSONError(403,'Forbidden'); Exit; end;

        if SameText(Request.Method,'GET') then
        begin
          var L := TCampaignItemRepository.ListByCampaign(CampId);
          try
            var Arr := TJSONArray.Create; try
              for var Itm in L do
              begin
                var O := TJSONObject.Create; O.AddPair('Id', TJSONNumber.Create(Itm.Id)); O.AddPair('MediaFileId', TJSONNumber.Create(Itm.MediaFileId)); O.AddPair('DisplayOrder', TJSONNumber.Create(Itm.DisplayOrder)); O.AddPair('Duration', TJSONNumber.Create(Itm.Duration)); Arr.AddElement(O);
              end;
              var Wrapper := TJSONObject.Create; try
                Wrapper.AddPair('value', Arr);
                Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := Wrapper.ToJSON; Response.SendResponse;
              finally Wrapper.Free; end;
            finally Arr.Free; end;
          finally L.Free; end; Exit;
        end
        else if SameText(Request.Method,'POST') then
        begin
          if TryReplayIdempotency(Camp.OrganizationId) then Exit;
          var Body := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject; try
            if Body=nil then begin JSONError(400,'Invalid JSON'); Exit; end;
            var MediaFileId := Body.GetValue<Integer>('MediaFileId',0);
            var DisplayOrder := Body.GetValue<Integer>('DisplayOrder',0);
            var Duration := Body.GetValue<Integer>('Duration',0);
            if MediaFileId=0 then begin JSONError(400,'Missing MediaFileId'); Exit; end;
            var Itm := TCampaignItemRepository.CreateItem(CampId, MediaFileId, DisplayOrder, Duration);
            try
              var O := TJSONObject.Create; O.AddPair('Id', TJSONNumber.Create(Itm.Id)); O.AddPair('MediaFileId', TJSONNumber.Create(Itm.MediaFileId)); O.AddPair('DisplayOrder', TJSONNumber.Create(Itm.DisplayOrder)); O.AddPair('Duration', TJSONNumber.Create(Itm.Duration));
              var OutBody := O.ToJSON;
              O.Free;
              StoreIdempotency(Camp.OrganizationId, 201, OutBody);
              Response.StatusCode := 201; Response.ContentType := 'application/json'; Response.Content := OutBody; Response.SendResponse;
            finally Itm.Free; end;
          finally Body.Free; end; Exit;
        end;

        finally
          Camp.Free;
        end;
      end
      else if (SameText(Request.Method, 'GET') or SameText(Request.Method, 'PUT') or SameText(Request.Method, 'DELETE')) then
      begin
        var IdStr := Copy(NormalizedPath, 12, MaxInt);
        var Id := StrToIntDef(IdStr,0); if Id=0 then begin JSONError(400,'Invalid campaign id'); Exit; end;
        var Cmp0 := TCampaignRepository.GetById(Id);
        if Cmp0=nil then begin JSONError(404,'Not found'); Exit; end;
        try
          var TokOrg, TokUser: Integer; var TokRole: string;
          if SameText(Request.Method,'GET') then
          begin
            if not RequireAuth(['campaigns:read'], TokOrg, TokUser, TokRole) then Exit;
          end
          else
          begin
            if not RequireAuth(['campaigns:write'], TokOrg, TokUser, TokRole) then Exit;
          end;
          if TokOrg<>Cmp0.OrganizationId then begin JSONError(403,'Forbidden'); Exit; end;

        if SameText(Request.Method,'GET') then
        begin
          var Cmp := Cmp0;
          var O := TJSONObject.Create; O.AddPair('Id', TJSONNumber.Create(Cmp.Id)); O.AddPair('Name', Cmp.Name); O.AddPair('Orientation', Cmp.Orientation);
            Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := O.ToJSON; Response.SendResponse; O.Free;
          Exit;
        end
        else if SameText(Request.Method,'PUT') then
        begin
          var Body := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject; try
            if Body=nil then begin JSONError(400,'Invalid JSON'); Exit; end;
            var Name := Body.GetValue<string>('Name',''); var Orientation := Body.GetValue<string>('Orientation','');
            if (Name='') or (Orientation='') then begin JSONError(400,'Missing fields'); Exit; end;
            var Cmp := TCampaignRepository.UpdateCampaign(Id, Name, Orientation); if Cmp=nil then begin JSONError(404,'Not found'); Exit; end;
            try var O := TJSONObject.Create; O.AddPair('Id', TJSONNumber.Create(Cmp.Id)); O.AddPair('Name', Cmp.Name); O.AddPair('Orientation', Cmp.Orientation);
              Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := O.ToJSON; Response.SendResponse; O.Free;
            finally Cmp.Free; end; Exit;
          finally Body.Free; end;
        end
        else if SameText(Request.Method,'DELETE') then
        begin
          TCampaignRepository.DeleteCampaign(Id);
          Response.StatusCode := 204; Response.ContentType := 'application/json'; Response.Content := ''; Response.SendResponse; Exit;
        end;

        finally
          Cmp0.Free;
        end;
      end;
    end;

    // Schedules CRUD
    if (Copy(NormalizedPath, 1, 11) = '/schedules/') then
    begin
      var IdStr := Copy(NormalizedPath, 12, MaxInt);
      var Id := StrToIntDef(IdStr,0); if Id=0 then begin JSONError(400,'Invalid schedule id'); Exit; end;
      var S0 := TScheduleRepository.GetById(Id);
      if S0=nil then begin JSONError(404,'Not found'); Exit; end;
      var Camp0 := TCampaignRepository.GetById(S0.CampaignId);
      if Camp0=nil then begin S0.Free; JSONError(404,'Not found'); Exit; end;
      try
        var TokOrg, TokUser: Integer; var TokRole: string;
        if SameText(Request.Method,'GET') then
        begin
          if not RequireAuth(['campaigns:read'], TokOrg, TokUser, TokRole) then Exit;
        end
        else
        begin
          if not RequireAuth(['campaigns:write'], TokOrg, TokUser, TokRole) then Exit;
        end;
        if TokOrg<>Camp0.OrganizationId then begin JSONError(403,'Forbidden'); Exit; end;

        if SameText(Request.Method,'GET') then
        begin
          var O := TJSONObject.Create;
          O.AddPair('Id', TJSONNumber.Create(S0.Id));
          O.AddPair('CampaignId', TJSONNumber.Create(S0.CampaignId));
          if S0.StartTime <> 0 then O.AddPair('StartTime', DateToISO8601(S0.StartTime, True)) else O.AddPair('StartTime', TJSONNull.Create);
          if S0.EndTime <> 0 then O.AddPair('EndTime', DateToISO8601(S0.EndTime, True)) else O.AddPair('EndTime', TJSONNull.Create);
          if S0.RecurringPattern <> '' then O.AddPair('RecurringPattern', S0.RecurringPattern) else O.AddPair('RecurringPattern', TJSONNull.Create);
          Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := O.ToJSON; Response.SendResponse; O.Free;
          Exit;
        end
        else if SameText(Request.Method,'PUT') then
        begin
          var Body := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject;
          try
            if Body=nil then begin JSONError(400,'Invalid JSON'); Exit; end;
            var StartStrVal := Body.GetValue('StartTime');
            var EndStrVal := Body.GetValue('EndTime');
            var RecVal := Body.GetValue('RecurringPattern');

            var HasStart := False;
            var HasEnd := False;
            var StartAt: TDateTime := 0;
            var EndAt: TDateTime := 0;

            if (StartStrVal<>nil) and (not (StartStrVal is TJSONNull)) then
            begin
              HasStart := TryISO8601ToDate(StartStrVal.Value, StartAt, True);
              if not HasStart then begin JSONError(400,'Invalid StartTime'); Exit; end;
            end;
            if (EndStrVal<>nil) and (not (EndStrVal is TJSONNull)) then
            begin
              HasEnd := TryISO8601ToDate(EndStrVal.Value, EndAt, True);
              if not HasEnd then begin JSONError(400,'Invalid EndTime'); Exit; end;
            end;
            if HasStart and HasEnd and (EndAt < StartAt) then begin JSONError(400,'EndTime must be >= StartTime'); Exit; end;

            var Rec := '';
            if (RecVal<>nil) and (not (RecVal is TJSONNull)) then
              Rec := RecVal.Value;

            var S := TScheduleRepository.UpdateSchedule(Id, StartAt, EndAt, HasStart, HasEnd, Rec);
            if S=nil then begin JSONError(404,'Not found'); Exit; end;
            try
              var O := TJSONObject.Create;
              O.AddPair('Id', TJSONNumber.Create(S.Id));
              O.AddPair('CampaignId', TJSONNumber.Create(S.CampaignId));
              if HasStart then O.AddPair('StartTime', DateToISO8601(S.StartTime, True)) else O.AddPair('StartTime', TJSONNull.Create);
              if HasEnd then O.AddPair('EndTime', DateToISO8601(S.EndTime, True)) else O.AddPair('EndTime', TJSONNull.Create);
              if S.RecurringPattern <> '' then O.AddPair('RecurringPattern', S.RecurringPattern) else O.AddPair('RecurringPattern', TJSONNull.Create);
              Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := O.ToJSON; Response.SendResponse; O.Free;
            finally S.Free; end;
          finally Body.Free; end;
          Exit;
        end
        else if SameText(Request.Method,'DELETE') then
        begin
          TScheduleRepository.DeleteSchedule(Id);
          Response.StatusCode := 204; Response.ContentType := 'application/json'; Response.Content := ''; Response.SendResponse;
          Exit;
        end;

      finally
        Camp0.Free;
        S0.Free;
      end;
    end;

    if (Copy(NormalizedPath, 1, 16) = '/campaign-items/') then
    begin
      var IdStr := Copy(NormalizedPath, 17, MaxInt);
      var Id := StrToIntDef(IdStr,0); if Id=0 then begin JSONError(400,'Invalid campaign item id'); Exit; end;
      var Itm0 := TCampaignItemRepository.GetById(Id);
      if Itm0=nil then begin JSONError(404,'Not found'); Exit; end;
      var Camp0 := TCampaignRepository.GetById(Itm0.CampaignId);
      if Camp0=nil then begin Itm0.Free; JSONError(404,'Not found'); Exit; end;
      try
        var TokOrg, TokUser: Integer; var TokRole: string;
        if SameText(Request.Method,'GET') then
        begin
          if not RequireAuth(['campaigns:read'], TokOrg, TokUser, TokRole) then Exit;
        end
        else
        begin
          if not RequireAuth(['campaigns:write'], TokOrg, TokUser, TokRole) then Exit;
        end;
        if TokOrg<>Camp0.OrganizationId then begin JSONError(403,'Forbidden'); Exit; end;

      if SameText(Request.Method,'GET') then
      begin
        var Itm := Itm0;
        var O := TJSONObject.Create; O.AddPair('Id', TJSONNumber.Create(Itm.Id)); O.AddPair('MediaFileId', TJSONNumber.Create(Itm.MediaFileId)); O.AddPair('DisplayOrder', TJSONNumber.Create(Itm.DisplayOrder)); O.AddPair('Duration', TJSONNumber.Create(Itm.Duration));
          Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := O.ToJSON; Response.SendResponse; O.Free;
        Exit;
      end
      else if SameText(Request.Method,'PUT') then
      begin
        var Body := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject; try
          if Body=nil then begin JSONError(400,'Invalid JSON'); Exit; end;
          var MediaFileId := Body.GetValue<Integer>('MediaFileId',0);
          var DisplayOrder := Body.GetValue<Integer>('DisplayOrder',0);
          var Duration := Body.GetValue<Integer>('Duration',0);
          var Itm := TCampaignItemRepository.UpdateItem(Id, MediaFileId, DisplayOrder, Duration); if Itm=nil then begin JSONError(404,'Not found'); Exit; end;
          try var O := TJSONObject.Create; O.AddPair('Id', TJSONNumber.Create(Itm.Id)); O.AddPair('MediaFileId', TJSONNumber.Create(Itm.MediaFileId)); O.AddPair('DisplayOrder', TJSONNumber.Create(Itm.DisplayOrder)); O.AddPair('Duration', TJSONNumber.Create(Itm.Duration));
            Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := O.ToJSON; Response.SendResponse; O.Free;
          finally Itm.Free; end; Exit;
        finally Body.Free; end;
      end
      else if SameText(Request.Method,'DELETE') then
      begin
        TFDQuery.Create(nil).Free; // no-op to ensure FireDAC referenced
        var C := NewConnection; try
          var Q := TFDQuery.Create(nil); try
            Q.Connection := C; Q.SQL.Text := 'delete from CampaignItems where CampaignItemID=:Id'; Q.ParamByName('Id').AsInteger := Id; Q.ExecSQL;
          finally Q.Free; end;
        finally C.Free; end;
        Response.StatusCode := 204; Response.SendResponse; Exit;
      end;

      finally
        Camp0.Free;
        Itm0.Free;
      end;
    end;

    if (Copy(NormalizedPath, 1, 22) = '/campaign-assignments/') then
    begin
      var IdStr := Copy(NormalizedPath, 23, MaxInt);
      var Id := StrToIntDef(IdStr,0); if Id=0 then begin JSONError(400,'Invalid assignment id'); Exit; end;
      var A0 := TDisplayCampaignRepository.GetById(Id);
      if A0=nil then begin JSONError(404,'Not found'); Exit; end;
      var D0 := TDisplayRepository.GetById(A0.DisplayId);
      if D0=nil then begin A0.Free; JSONError(404,'Not found'); Exit; end;
      try
        var TokOrg, TokUser: Integer; var TokRole: string;
        if not RequireAuth(['assignments:write'], TokOrg, TokUser, TokRole) then Exit;
        if TokOrg<>D0.OrganizationId then begin JSONError(403,'Forbidden'); Exit; end;

      if SameText(Request.Method,'PUT') then
      begin
        var Body := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject; try
          if Body=nil then begin JSONError(400,'Invalid JSON'); Exit; end;
          var IsPrimary := Body.GetValue<Boolean>('IsPrimary', True);
          var A := TDisplayCampaignRepository.UpdateAssignment(Id, IsPrimary); if A=nil then begin JSONError(404,'Not found'); Exit; end;
          try
            var O := TJSONObject.Create; O.AddPair('Id', TJSONNumber.Create(A.Id)); O.AddPair('DisplayId', TJSONNumber.Create(A.DisplayId)); O.AddPair('CampaignId', TJSONNumber.Create(A.CampaignId)); O.AddPair('IsPrimary', TJSONBool.Create(A.IsPrimary));
            Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := O.ToJSON; Response.SendResponse; O.Free;
          finally A.Free; end;
        finally Body.Free; end; Exit;
      end
      else if SameText(Request.Method,'DELETE') then
      begin
        TDisplayCampaignRepository.DeleteAssignment(Id);
        Response.StatusCode := 204; Response.ContentType := 'application/json'; Response.Content := ''; Response.SendResponse; Exit;
      end;

      finally
        D0.Free;
        A0.Free;
      end;
    end;

    // Media files presigned URLs
    // Prefix normalization: allow optional /api prefix
    var PathInfo := Request.PathInfo;
    if Copy(PathInfo,1,4)='/api' then
      PathInfo := Copy(PathInfo,5,MaxInt); // strip /api

    // ===== Media Files CRUD & Analytics =====
    // List media files for organization
    if (Pos('/organizations/', PathInfo)=1) and (Pos('/media-files', PathInfo)>0) and SameText(Request.Method,'GET') then
    begin
      // Expect /organizations/{OrgId}/media-files
      var Tail := Copy(PathInfo, Length('/organizations/')+1, MaxInt); // {OrgId}/media-files
      var OrgIdStr := Copy(Tail,1, Pos('/',Tail)-1);
      var OrgId := StrToIntDef(OrgIdStr,0); if OrgId=0 then begin JSONError(400,'Invalid organization id'); Exit; end;
      var TokOrg, TokUser: Integer; var TokRole: string;
      if not RequireAuth(['media:read'], TokOrg, TokUser, TokRole) then Exit;
      if TokOrg<>OrgId then begin JSONError(403,'Forbidden'); Exit; end;
      var C := NewConnection; try
        var Q := TFDQuery.Create(nil); try
          Q.Connection := C;
          Q.SQL.Text := 'select * from MediaFiles where OrganizationID=:Org order by CreatedAt desc';
          Q.ParamByName('Org').AsInteger := OrgId;
          Q.Open;
          var Arr := TJSONArray.Create; try
            while not Q.Eof do
            begin
              var O := TJSONObject.Create;
              O.AddPair('Id', TJSONNumber.Create(Q.FieldByName('MediaFileID').AsInteger));
              O.AddPair('OrganizationId', TJSONNumber.Create(Q.FieldByName('OrganizationID').AsInteger));
              O.AddPair('FileName', Q.FieldByName('FileName').AsString);
              O.AddPair('FileType', Q.FieldByName('FileType').AsString);
              if Q.FindField('Orientation') <> nil then
                O.AddPair('Orientation', Q.FieldByName('Orientation').AsString);
              O.AddPair('StorageURL', Q.FieldByName('StorageURL').AsString);
              O.AddPair('CreatedAt', Q.FieldByName('CreatedAt').AsString);
              O.AddPair('UpdatedAt', Q.FieldByName('UpdatedAt').AsString);
              Arr.AddElement(O);
              Q.Next;
            end;
            var Root := TJSONObject.Create; try
              Root.AddPair('value', Arr.Clone as TJSONArray); // envelope pattern
              Root.AddPair('Success', TJSONBool.Create(True));
              Root.AddPair('Message', '');
              Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := Root.ToJSON; Response.SendResponse;
            finally Root.Free; end;
          finally Arr.Free; end;
        finally Q.Free; end;
      finally C.Free; end;
      Exit;
    end;

    // Get single media file
    if (Copy(PathInfo,1,13)='/media-files/') and (Pos('/download-url', PathInfo)=0) and SameText(Request.Method,'GET') then
    begin
      var IdStr := Copy(PathInfo,14,MaxInt); // after '/media-files/'
      var Id := StrToIntDef(IdStr,0); if Id=0 then begin JSONError(400,'Invalid media id'); Exit; end;
      var TokOrg, TokUser: Integer; var TokRole: string;
      if not RequireAuth(['media:read'], TokOrg, TokUser, TokRole) then Exit;
      var MF := TMediaFileRepository.GetById(Id); if MF=nil then begin JSONError(404,'Not found'); Exit; end;
      try
        if TokOrg<>MF.OrganizationId then begin JSONError(403,'Forbidden'); Exit; end;
        var O := TJSONObject.Create; try
          O.AddPair('Id', TJSONNumber.Create(MF.Id));
          O.AddPair('OrganizationId', TJSONNumber.Create(MF.OrganizationId));
          O.AddPair('FileName', MF.FileName);
          O.AddPair('FileType', MF.FileType);
          O.AddPair('Orientation', MF.Orientation);
          O.AddPair('StorageURL', MF.StorageURL);
          O.AddPair('CreatedAt', DateTimeToStr(MF.CreatedAt));
          O.AddPair('UpdatedAt', DateTimeToStr(MF.UpdatedAt));
          O.AddPair('Success', TJSONBool.Create(True));
          O.AddPair('Message', '');
          Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := O.ToJSON; Response.SendResponse;
        finally O.Free; end;
      finally MF.Free; end;
      Exit;
    end;

    // Create media file directly (metadata only - alternative to upload-url flow)
    if (Pos('/organizations/', PathInfo)=1) and (Pos('/media-files', PathInfo)>0) and SameText(Request.Method,'POST') then
    begin
      // Distinguish from upload-url: path will be /organizations/{OrgId}/media-files
      var Tail := Copy(PathInfo, Length('/organizations/')+1, MaxInt);
      var OrgIdStr := Copy(Tail,1, Pos('/',Tail)-1);
      var OrgId := StrToIntDef(OrgIdStr,0); if OrgId=0 then begin JSONError(400,'Invalid organization id'); Exit; end;
      var TokOrg, TokUser: Integer; var TokRole: string;
      if not RequireAuth(['media:write'], TokOrg, TokUser, TokRole) then Exit;
      if TokOrg<>OrgId then begin JSONError(403,'Forbidden'); Exit; end;
      var Body := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject; try
        if Body=nil then begin JSONError(400,'Invalid JSON'); Exit; end;
        var FileName := Body.GetValue<string>('FileName','');
        var FileType := Body.GetValue<string>('FileType','application/octet-stream');
        var Orientation := Body.GetValue<string>('Orientation','Landscape');
        var StorageURL := Body.GetValue<string>('StorageURL','');
        if (FileName='') or (StorageURL='') then begin JSONError(400,'Missing FileName or StorageURL'); Exit; end;
        var MF := TMediaFileRepository.CreateMedia(OrgId, FileName, FileType, Orientation, StorageURL);
        try
          var O := TJSONObject.Create; try
            O.AddPair('Id', TJSONNumber.Create(MF.Id));
            O.AddPair('OrganizationId', TJSONNumber.Create(MF.OrganizationId));
            O.AddPair('FileName', MF.FileName);
            O.AddPair('FileType', MF.FileType);
            O.AddPair('Orientation', MF.Orientation);
            O.AddPair('StorageURL', MF.StorageURL);
            O.AddPair('CreatedAt', DateTimeToStr(MF.CreatedAt));
            O.AddPair('UpdatedAt', DateTimeToStr(MF.UpdatedAt));
            O.AddPair('Success', TJSONBool.Create(True));
            O.AddPair('Message', '');
            Response.StatusCode := 201; Response.ContentType := 'application/json'; Response.Content := O.ToJSON; Response.SendResponse;
          finally O.Free; end;
        finally MF.Free; end;
      finally Body.Free; end;
      Exit;
    end;

    // Update media file
    if (Copy(PathInfo,1,13)='/media-files/') and SameText(Request.Method,'PUT') then
    begin
      var IdStr := Copy(PathInfo,14,MaxInt);
      var Id := StrToIntDef(IdStr,0); if Id=0 then begin JSONError(400,'Invalid media id'); Exit; end;
      var TokOrg, TokUser: Integer; var TokRole: string;
      if not RequireAuth(['media:write'], TokOrg, TokUser, TokRole) then Exit;
      var Body := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject; try
        if Body=nil then begin JSONError(400,'Invalid JSON'); Exit; end;
        var FileName := Body.GetValue<string>('FileName','');
        var FileType := Body.GetValue<string>('FileType','');
        var StorageURL := Body.GetValue<string>('StorageURL','');
        var Orientation := Body.GetValue<string>('Orientation','');
        // Require Orientation if column is present (>=0.1.7) to allow explicit update
        if (FileName='') or (Orientation='') then begin JSONError(400,'Missing FileName or Orientation'); Exit; end;
        // Simple update using SQL
        var C := NewConnection; try
          var Q := TFDQuery.Create(nil); try
            Q.Connection := C;
            // Include Orientation in update (compatible with new schema); if legacy DB without column, this will error until migrated.
            Q.SQL.Text := 'update MediaFiles set FileName=:Name, FileType=:Type, StorageURL=:Url, Orientation=:Orientation, UpdatedAt=NOW() where MediaFileID=:Id and OrganizationID=:Org returning *';
            Q.ParamByName('Name').AsString := FileName;
            Q.ParamByName('Type').AsString := FileType;
            Q.ParamByName('Url').AsString := StorageURL;
            Q.ParamByName('Orientation').AsString := Orientation;
            Q.ParamByName('Id').AsInteger := Id;
            Q.ParamByName('Org').AsInteger := TokOrg;
            Q.Open;
            if Q.Eof then begin JSONError(404,'Not found'); Exit; end;
            var O := TJSONObject.Create; try
              O.AddPair('Id', TJSONNumber.Create(Q.FieldByName('MediaFileID').AsInteger));
              O.AddPair('OrganizationId', TJSONNumber.Create(Q.FieldByName('OrganizationID').AsInteger));
              O.AddPair('FileName', Q.FieldByName('FileName').AsString);
              O.AddPair('FileType', Q.FieldByName('FileType').AsString);
              if Q.FindField('Orientation') <> nil then
                O.AddPair('Orientation', Q.FieldByName('Orientation').AsString);
              O.AddPair('StorageURL', Q.FieldByName('StorageURL').AsString);
              O.AddPair('CreatedAt', Q.FieldByName('CreatedAt').AsString);
              O.AddPair('UpdatedAt', Q.FieldByName('UpdatedAt').AsString);
              O.AddPair('Success', TJSONBool.Create(True));
              O.AddPair('Message', '');
              Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := O.ToJSON; Response.SendResponse;
            finally O.Free; end;
          finally Q.Free; end;
        finally C.Free; end;
      finally Body.Free; end;
      Exit;
    end;

    // Delete media file
    if (Copy(PathInfo,1,13)='/media-files/') and SameText(Request.Method,'DELETE') then
    begin
      var IdStr := Copy(PathInfo,14,MaxInt);
      var Id := StrToIntDef(IdStr,0); if Id=0 then begin JSONError(400,'Invalid media id'); Exit; end;
      var TokOrg, TokUser: Integer; var TokRole: string;
      if not RequireAuth(['media:write'], TokOrg, TokUser, TokRole) then Exit;
      var C := NewConnection; try
        var Q := TFDQuery.Create(nil); try
          Q.Connection := C;
          Q.SQL.Text := 'delete from MediaFiles where MediaFileID=:Id and OrganizationID=:Org';
          Q.ParamByName('Id').AsInteger := Id;
          Q.ParamByName('Org').AsInteger := TokOrg;
          Q.ExecSQL;
          if Q.RowsAffected=0 then begin JSONError(404,'Not found'); Exit; end;
          Response.StatusCode := 204; Response.ContentType := 'application/json'; Response.Content := ''; Response.SendResponse;
        finally Q.Free; end;
      finally C.Free; end;
      Exit;
    end;

    // Upload URL (presign)
    if SameText(PathInfo, '/media-files/upload-url') and SameText(Request.Method, 'POST') then
    begin
      var TokOrg, TokUser: Integer; var TokRole: string;
      if not RequireAuth(['media:write'], TokOrg, TokUser, TokRole) then Exit;
      var Body := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject; try
        if Body=nil then begin JSONError(400,'Invalid JSON'); Exit; end;
        var OrgId := Body.GetValue<Integer>('OrganizationId',0);
        var FileName := Body.GetValue<string>('FileName','');
        var FileType := Body.GetValue<string>('FileType','application/octet-stream');
        var Orientation := Body.GetValue<string>('Orientation','Landscape');
        if (OrgId=0) or (FileName='') then begin JSONError(400,'Missing fields'); Exit; end;
        if TokOrg<>OrgId then begin JSONError(403,'Forbidden'); Exit; end;
        // Use the same default bucket name created by docker compose (minio-setup)
        var Bucket := GetEnv('MINIO_BUCKET','displaydeck-media');
        var InternalEndpoint := GetEnv('MINIO_ENDPOINT','http://minio:9000');
        var PublicEndpoint := GetEnv('MINIO_PUBLIC_ENDPOINT', InternalEndpoint);
        var Access := GetEnv('MINIO_ACCESS_KEY','minioadmin');
        var Secret := GetEnv('MINIO_SECRET_KEY','minioadmin');
        var Region := GetEnv('MINIO_REGION','us-east-1');
        var Key := Format('org/%d/%s/%s',[OrgId, FormatDateTime('yyyymmddhhnnsszz', Now), FileName]);
        var Params: TS3PresignParams; Params.Endpoint:=PublicEndpoint; Params.Region:=Region; Params.Bucket:=Bucket; Params.ObjectKey:=Key; Params.AccessKey:=Access; Params.SecretKey:=Secret; Params.Method:='PUT'; Params.ExpiresSeconds:=900;
        var Url: string; if not BuildS3PresignedUrl(Params, Url) then begin JSONError(500,'Failed to generate URL'); Exit; end;
        var StorageURL := PublicEndpoint.TrimRight(['/']) + '/' + Bucket + '/' + Key;
        var MF := TMediaFileRepository.CreateMedia(OrgId, FileName, FileType, Orientation, StorageURL);
        try
          var Obj := TJSONObject.Create;
          Obj.AddPair('MediaFileId', TJSONNumber.Create(MF.Id));
          Obj.AddPair('UploadUrl', Url);
          Obj.AddPair('StorageKey', Key);
          Obj.AddPair('Orientation', MF.Orientation);
          Obj.AddPair('Success', TJSONBool.Create(True));
          Obj.AddPair('Message', '');
          Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := Obj.ToJSON; Response.SendResponse; Obj.Free;
        finally MF.Free; end;
      finally Body.Free; end;
      Exit;
    end;
    if (Copy(PathInfo, 1, 13) = '/media-files/') and (Pos('/download-url', PathInfo) > 0) and
       SameText(Request.Method, 'GET') then
    begin
      // /media-files/{id}/download-url
      // Use normalized PathInfo (without optional /api prefix) for parsing
      var Tail := Copy(PathInfo, 14, MaxInt);
      var IdStr := Copy(Tail, 1, Pos('/', Tail)-1);
      var Id := StrToIntDef(IdStr,0); if Id=0 then begin JSONError(400,'Invalid media id'); Exit; end;
      var TokOrg, TokUser: Integer; var TokRole: string;
      if not RequireAuth(['media:read'], TokOrg, TokUser, TokRole) then Exit;
      var MF := TMediaFileRepository.GetById(Id); if MF=nil then begin JSONError(404,'Not found'); Exit; end;
      try
        if TokOrg<>MF.OrganizationId then begin JSONError(403,'Forbidden'); Exit; end;
        var InternalEndpoint := GetEnv('MINIO_ENDPOINT','http://minio:9000');
        var PublicEndpoint := GetEnv('MINIO_PUBLIC_ENDPOINT', InternalEndpoint);
        var Access := GetEnv('MINIO_ACCESS_KEY','minioadmin');
        var Secret := GetEnv('MINIO_SECRET_KEY','minioadmin');
        var Region := GetEnv('MINIO_REGION','us-east-1');
        // Robust parsing: StorageURL may have been saved with either internal or public endpoint.
        // Strip either endpoint prefix if present, then extract bucket and key.
        var Path := Trim(MF.StorageURL);
        if Path='' then begin JSONError(400,'Missing storage path'); Exit; end;
        if Path.StartsWith(PublicEndpoint) then
          Path := Copy(Path, Length(PublicEndpoint)+1, MaxInt)
        else if Path.StartsWith(InternalEndpoint) then
          Path := Copy(Path, Length(InternalEndpoint)+1, MaxInt);
        if (Length(Path)>0) and (Path[1]='/') then Path := Copy(Path,2,MaxInt);
        // Fallback: if still contains scheme://host because endpoints changed, strip host portion.
        var SchemePos := Pos('://', Path);
        if SchemePos>0 then
        begin
          // find next slash after scheme://
          var HostEndIdx := SchemePos + 3; // position where host starts
          var SlashAfterHost := 0;
          var i := HostEndIdx;
          while i <= Length(Path) do begin if Path[i]='/' then begin SlashAfterHost := i; Break; end; Inc(i); end;
          if SlashAfterHost>0 then
            Path := Copy(Path, SlashAfterHost+1, MaxInt);
        end;
        var p := Pos('/', Path);
        if p=0 then begin JSONError(400,'Invalid storage path'); Exit; end;
        var Bucket := Copy(Path,1,p-1);
        var Key := Copy(Path,p+1, MaxInt);
        if (Bucket='') or (Key='') then begin JSONError(400,'Invalid storage path'); Exit; end;
        var Params: TS3PresignParams; Params.Endpoint:=PublicEndpoint; Params.Region:=Region; Params.Bucket:=Bucket; Params.ObjectKey:=Key; Params.AccessKey:=Access; Params.SecretKey:=Secret; Params.Method:='GET'; Params.ExpiresSeconds:=900;
        var Url: string; if not BuildS3PresignedUrl(Params, Url) then begin JSONError(500,'Failed to generate URL'); Exit; end;
        var Obj := TJSONObject.Create; Obj.AddPair('DownloadUrl', Url); Obj.AddPair('Success', TJSONBool.Create(True)); Obj.AddPair('Message', '');
        Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := Obj.ToJSON; Response.SendResponse; Obj.Free;
      finally MF.Free; end;
      Exit;
    end;

    // Current playing on a display (analytics)
    if (Copy(PathInfo,1,10)='/displays/') and (Pos('/current-playing', PathInfo)>0) and SameText(Request.Method,'GET') then
    begin
      var IdStr := Copy(PathInfo, 11, MaxInt);
      var Slash := Pos('/', IdStr); if Slash>0 then IdStr := Copy(IdStr,1,Slash-1);
      var DisplayId := StrToIntDef(IdStr,0); if DisplayId=0 then begin JSONError(400,'Invalid display id'); Exit; end;
      var TokOrg, TokUser: Integer; var TokRole: string;
      if not RequireAuth(['displays:read'], TokOrg, TokUser, TokRole) then Exit;
      var C := NewConnection; try
        // Ensure display belongs to authenticated org
        var QOrg := TFDQuery.Create(nil); try
          QOrg.Connection := C;
          QOrg.SQL.Text := 'select OrganizationID from Displays where DisplayID=:D';
          QOrg.ParamByName('D').AsInteger := DisplayId;
          QOrg.Open;
          if QOrg.Eof then begin JSONError(404,'Display not found'); Exit; end;
          if TokOrg<>QOrg.FieldByName('OrganizationID').AsInteger then begin JSONError(403,'Forbidden'); Exit; end;
        finally QOrg.Free; end;
        var Q := TFDQuery.Create(nil); try
          Q.Connection := C;
          Q.SQL.Text := 'select pl.*, mf.FileName, mf.FileType, c.Name as CampaignName ' +
                        'from PlaybackLogs pl ' +
                        'left join MediaFiles mf on mf.MediaFileID=pl.MediaFileID ' +
                        'left join Campaigns c on c.CampaignID=pl.CampaignID ' +
                        'where pl.DisplayID=:D order by pl.PlaybackTimestamp desc limit 1';
          Q.ParamByName('D').AsInteger := DisplayId; Q.Open;
          if Q.Eof then begin JSONError(404,'No playback yet'); Exit; end;
          var O := TJSONObject.Create; try
            O.AddPair('DisplayId', TJSONNumber.Create(Q.FieldByName('DisplayID').AsInteger));
            O.AddPair('MediaFileId', TJSONNumber.Create(Q.FieldByName('MediaFileID').AsInteger));
            O.AddPair('CampaignId', TJSONNumber.Create(Q.FieldByName('CampaignID').AsInteger));
            // Provide both PlaybackTimestamp (original) and StartedAt (client expectation)
            var TS := Q.FieldByName('PlaybackTimestamp').AsString;
            O.AddPair('PlaybackTimestamp', TS);
            O.AddPair('StartedAt', TS);
            O.AddPair('MediaFileName', Q.FieldByName('FileName').AsString);
            O.AddPair('MediaFileType', Q.FieldByName('FileType').AsString);
            O.AddPair('CampaignName', Q.FieldByName('CampaignName').AsString);
            Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := O.ToJSON; Response.SendResponse;
          finally O.Free; end;
        finally Q.Free; end;
      finally C.Free; end;
      Exit;
    end;

    // Set primary campaign for a display (control)
    if (Copy(PathInfo,1,10)='/displays/') and (Pos('/set-primary', PathInfo)>0) and SameText(Request.Method,'POST') then
    begin
      var IdStr := Copy(PathInfo, 11, MaxInt);
      var Slash := Pos('/', IdStr); if Slash>0 then IdStr := Copy(IdStr,1,Slash-1);
      var DisplayId := StrToIntDef(IdStr,0); if DisplayId=0 then begin JSONError(400,'Invalid display id'); Exit; end;
      var TokOrg, TokUser: Integer; var TokRole: string;
      if not RequireAuth(['displays:write'], TokOrg, TokUser, TokRole) then Exit;
      var Body := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject; try
        if Body=nil then begin JSONError(400,'Invalid JSON'); Exit; end;
        var CampaignId := Body.GetValue<Integer>('CampaignId',0); if CampaignId=0 then begin JSONError(400,'Missing CampaignId'); Exit; end;
        // Set only this assignment as primary
        var C := NewConnection; try
          // Ensure display belongs to org
          var QOrg := TFDQuery.Create(nil); try
            QOrg.Connection := C;
            QOrg.SQL.Text := 'select OrganizationID from Displays where DisplayID=:D';
            QOrg.ParamByName('D').AsInteger := DisplayId;
            QOrg.Open;
            if QOrg.Eof then begin JSONError(404,'Display not found'); Exit; end;
            if TokOrg<>QOrg.FieldByName('OrganizationID').AsInteger then begin JSONError(403,'Forbidden'); Exit; end;
          finally QOrg.Free; end;
          var Q := TFDQuery.Create(nil); try
            Q.Connection := C;
            Q.SQL.Text := 'update DisplayCampaigns set IsPrimary=false where DisplayID=:D'; Q.ParamByName('D').AsInteger := DisplayId; Q.ExecSQL;
            Q.SQL.Text := 'update DisplayCampaigns set IsPrimary=true where DisplayID=:D and CampaignID=:C'; Q.ParamByName('C').AsInteger := CampaignId; Q.ExecSQL;
          finally Q.Free; end;
        finally C.Free; end;
        Response.StatusCode := 204; Response.ContentType := 'application/json'; Response.Content := ''; Response.SendResponse;
      finally Body.Free; end;
      Exit;
    end;

    // Analytics: list plays with filters
    if SameText(PathInfo, '/analytics/plays') and SameText(Request.Method,'GET') then
    begin
      var TokOrg, TokUser: Integer; var TokRole: string;
      if not RequireAuth(['analytics:read'], TokOrg, TokUser, TokRole) then Exit;
      var OrgId := StrToIntDef(Request.QueryFields.Values['organizationId'], 0);
      if OrgId=0 then OrgId := TokOrg else if OrgId<>TokOrg then begin JSONError(403,'Forbidden'); Exit; end;
      var DisplayId := StrToIntDef(Request.QueryFields.Values['displayId'], 0);
      var CampaignId := StrToIntDef(Request.QueryFields.Values['campaignId'], 0);
      var MediaFileId := StrToIntDef(Request.QueryFields.Values['mediaFileId'], 0);
      var FromTs := Request.QueryFields.Values['from'];
      var ToTs := Request.QueryFields.Values['to'];
      var C := NewConnection; try
        var Q := TFDQuery.Create(nil); try
          Q.Connection := C;
          var SQL := 'select pl.*, d.Name as DisplayName, c.Name as CampaignName, mf.FileName as MediaFileName ' +
                     'from PlaybackLogs pl ' +
                     'left join Displays d on d.DisplayID=pl.DisplayID ' +
                     'left join Campaigns c on c.CampaignID=pl.CampaignID ' +
                     'left join MediaFiles mf on mf.MediaFileID=pl.MediaFileID where 1=1';
          if OrgId>0 then SQL := SQL + ' and d.OrganizationID=:OrgId';
          if DisplayId>0 then SQL := SQL + ' and pl.DisplayID=:DisplayId';
          if CampaignId>0 then SQL := SQL + ' and pl.CampaignID=:CampaignId';
          if MediaFileId>0 then SQL := SQL + ' and pl.MediaFileID=:MediaFileId';
          if FromTs<>'' then SQL := SQL + ' and pl.PlaybackTimestamp >= :FromTs';
          if ToTs<>'' then SQL := SQL + ' and pl.PlaybackTimestamp <= :ToTs';
          SQL := SQL + ' order by pl.PlaybackTimestamp desc limit 1000';
          Q.SQL.Text := SQL;
          if OrgId>0 then Q.ParamByName('OrgId').AsInteger := OrgId;
          if DisplayId>0 then Q.ParamByName('DisplayId').AsInteger := DisplayId;
          if CampaignId>0 then Q.ParamByName('CampaignId').AsInteger := CampaignId;
          if MediaFileId>0 then Q.ParamByName('MediaFileId').AsInteger := MediaFileId;
          if FromTs<>'' then Q.ParamByName('FromTs').AsString := FromTs;
          if ToTs<>'' then Q.ParamByName('ToTs').AsString := ToTs;
          Q.Open;
          var Arr := TJSONArray.Create; try
            while not Q.Eof do
            begin
              var O := TJSONObject.Create;
              O.AddPair('DisplayId', TJSONNumber.Create(Q.FieldByName('DisplayID').AsInteger));
              O.AddPair('CampaignId', TJSONNumber.Create(Q.FieldByName('CampaignID').AsInteger));
              O.AddPair('MediaFileId', TJSONNumber.Create(Q.FieldByName('MediaFileID').AsInteger));
              O.AddPair('PlaybackTimestamp', Q.FieldByName('PlaybackTimestamp').AsString);
              O.AddPair('DisplayName', Q.FieldByName('DisplayName').AsString);
              O.AddPair('CampaignName', Q.FieldByName('CampaignName').AsString);
              O.AddPair('MediaFileName', Q.FieldByName('MediaFileName').AsString);
              Arr.AddElement(O);
              Q.Next;
            end;
            var Root := TJSONObject.Create; try
              Root.AddPair('value', Arr.Clone as TJSONArray);
              Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := Root.ToJSON; Response.SendResponse;
            finally Root.Free; end;
          finally Arr.Free; end;
        finally Q.Free; end;
      finally C.Free; end;
      Exit;
    end;

    // Analytics: summary by media
    if SameText(PathInfo, '/analytics/summary/media') and SameText(Request.Method,'GET') then
    begin
      var TokOrg, TokUser: Integer; var TokRole: string;
      if not RequireAuth(['analytics:read'], TokOrg, TokUser, TokRole) then Exit;
      var OrgId := StrToIntDef(Request.QueryFields.Values['organizationId'], 0);
      if OrgId=0 then OrgId := TokOrg else if OrgId<>TokOrg then begin JSONError(403,'Forbidden'); Exit; end;
      var FromTs := Request.QueryFields.Values['from'];
      var ToTs := Request.QueryFields.Values['to'];
      var C := NewConnection; try
        var Q := TFDQuery.Create(nil); try
          Q.Connection := C;
          var SQL := 'select pl.MediaFileID, mf.FileName, count(*) as Plays ' +
                     'from PlaybackLogs pl left join MediaFiles mf on mf.MediaFileID=pl.MediaFileID ' +
                     'left join Displays d on d.DisplayID=pl.DisplayID where 1=1';
          if OrgId>0 then SQL := SQL + ' and d.OrganizationID=:OrgId';
          if FromTs<>'' then SQL := SQL + ' and pl.PlaybackTimestamp >= :FromTs';
          if ToTs<>'' then SQL := SQL + ' and pl.PlaybackTimestamp <= :ToTs';
          SQL := SQL + ' group by pl.MediaFileID, mf.FileName order by Plays desc';
          Q.SQL.Text := SQL;
          if OrgId>0 then Q.ParamByName('OrgId').AsInteger := OrgId;
          if FromTs<>'' then Q.ParamByName('FromTs').AsString := FromTs;
          if ToTs<>'' then Q.ParamByName('ToTs').AsString := ToTs;
          Q.Open;
          var Arr := TJSONArray.Create; try
            while not Q.Eof do
            begin
              var O := TJSONObject.Create; O.AddPair('MediaFileId', TJSONNumber.Create(Q.FieldByName('MediaFileID').AsInteger)); O.AddPair('MediaFileName', Q.FieldByName('FileName').AsString); O.AddPair('Plays', TJSONNumber.Create(Q.FieldByName('Plays').AsInteger));
              Arr.AddElement(O); Q.Next;
            end;
            var Root := TJSONObject.Create; try Root.AddPair('value', Arr.Clone as TJSONArray); Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := Root.ToJSON; Response.SendResponse; finally Root.Free; end;
          finally Arr.Free; end;
        finally Q.Free; end;
      finally C.Free; end; Exit;
    end;

    // Analytics: summary by campaign
    if SameText(PathInfo, '/analytics/summary/campaigns') and SameText(Request.Method,'GET') then
    begin
      var TokOrg, TokUser: Integer; var TokRole: string;
      if not RequireAuth(['analytics:read'], TokOrg, TokUser, TokRole) then Exit;
      var OrgId := StrToIntDef(Request.QueryFields.Values['organizationId'], 0);
      if OrgId=0 then OrgId := TokOrg else if OrgId<>TokOrg then begin JSONError(403,'Forbidden'); Exit; end;
      var FromTs := Request.QueryFields.Values['from'];
      var ToTs := Request.QueryFields.Values['to'];
      var C := NewConnection; try
        var Q := TFDQuery.Create(nil); try
          Q.Connection := C;
          var SQL := 'select pl.CampaignID, c.Name, count(*) as Plays ' +
                     'from PlaybackLogs pl left join Campaigns c on c.CampaignID=pl.CampaignID ' +
                     'left join Displays d on d.DisplayID=pl.DisplayID where 1=1';
          if OrgId>0 then SQL := SQL + ' and d.OrganizationID=:OrgId';
          if FromTs<>'' then SQL := SQL + ' and pl.PlaybackTimestamp >= :FromTs';
          if ToTs<>'' then SQL := SQL + ' and pl.PlaybackTimestamp <= :ToTs';
          SQL := SQL + ' group by pl.CampaignID, c.Name order by Plays desc';
          Q.SQL.Text := SQL;
          if OrgId>0 then Q.ParamByName('OrgId').AsInteger := OrgId;
          if FromTs<>'' then Q.ParamByName('FromTs').AsString := FromTs;
          if ToTs<>'' then Q.ParamByName('ToTs').AsString := ToTs;
          Q.Open;
          var Arr := TJSONArray.Create; try
            while not Q.Eof do
            begin
              var O := TJSONObject.Create; O.AddPair('CampaignId', TJSONNumber.Create(Q.FieldByName('CampaignID').AsInteger)); O.AddPair('CampaignName', Q.FieldByName('Name').AsString); O.AddPair('Plays', TJSONNumber.Create(Q.FieldByName('Plays').AsInteger));
              Arr.AddElement(O); Q.Next;
            end;
            var Root := TJSONObject.Create; try Root.AddPair('value', Arr.Clone as TJSONArray); Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := Root.ToJSON; Response.SendResponse; finally Root.Free; end;
          finally Arr.Free; end;
        finally Q.Free; end;
      finally C.Free; end; Exit;
    end;

    // Device
    if SameText(PathInfo, '/device/config') and SameText(Request.Method, 'POST') then
    begin
      var Body := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject; try
        if Body=nil then begin JSONError(400,'Invalid JSON'); Exit; end;
        var ProvisioningToken := Body.GetValue<string>('ProvisioningToken',''); if ProvisioningToken='' then begin JSONError(400,'Missing ProvisioningToken'); Exit; end;



        // Lookup display by ProvisioningToken
        var C := NewConnection; try
          var Q := TFDQuery.Create(nil); try
            Q.Connection := C; Q.SQL.Text := 'select * from Displays where ProvisioningToken=:T'; Q.ParamByName('T').AsString := ProvisioningToken; Q.Open;
            if Q.Eof then begin JSONError(404,'Display not found'); Exit; end;
            var DisplayId := Q.FieldByName('DisplayID').AsInteger;
            // Build DeviceConfigResponse: Device + Campaigns (no items per spec)
            var Dev := TJSONObject.Create; Dev.AddPair('Id', TJSONNumber.Create(DisplayId));
            Dev.AddPair('OrganizationId', TJSONNumber.Create(Q.FieldByName('OrganizationID').AsInteger));
            Dev.AddPair('Name', Q.FieldByName('Name').AsString);
            Dev.AddPair('Orientation', Q.FieldByName('Orientation').AsString);
            Dev.AddPair('LastSeen', Q.FieldByName('LastSeen').AsString);
            Dev.AddPair('CurrentStatus', Q.FieldByName('CurrentStatus').AsString);
            Dev.AddPair('ProvisioningToken', Q.FieldByName('ProvisioningToken').AsString);
            Dev.AddPair('CreatedAt', Q.FieldByName('CreatedAt').AsString);
            Dev.AddPair('UpdatedAt', Q.FieldByName('UpdatedAt').AsString);
            var Assigns := TDisplayCampaignRepository.ListByDisplay(DisplayId);
            try
              var ArrC := TJSONArray.Create; try
                var NowUtc := TTimeZone.Local.ToUniversalTime(Now);
                var Seen := TDictionary<Integer, Boolean>.Create;
                try
                for var A in Assigns do
                begin
                  // De-dupe by campaign id
                  if Seen.ContainsKey(A.CampaignId) then
                    Continue;
                  Seen.Add(A.CampaignId, True);

                  var Camp := TCampaignRepository.GetById(A.CampaignId);
                  if Camp<>nil then
                  try
                    // Enforce orientation match at config time as well (safety)
                    var DispOrient := Q.FieldByName('Orientation').AsString;
                    if (Camp.Orientation <> '') and (DispOrient <> '') and (not SameText(Camp.Orientation, DispOrient)) then
                      Continue;

                    // Enforce schedules: if no schedules exist, treat as always-active.
                    var Schedules := TScheduleRepository.ListByCampaign(Camp.Id);
                    try
                      var Active := True;
                      if (Schedules <> nil) and (Schedules.Count > 0) then
                      begin
                        Active := False;
                        for var S in Schedules do
                          if IsScheduleActive(S, NowUtc) then
                          begin
                            Active := True;
                            Break;
                          end;
                      end;
                      if not Active then
                        Continue;
                    finally
                      Schedules.Free;
                    end;

                    var OC := TJSONObject.Create;
                    OC.AddPair('Id', TJSONNumber.Create(Camp.Id));
                    OC.AddPair('OrganizationId', TJSONNumber.Create(Camp.OrganizationId));
                    OC.AddPair('Name', Camp.Name);
                    OC.AddPair('Orientation', Camp.Orientation);
                    ArrC.AddElement(OC);
                  finally Camp.Free; end;
                end;
                finally
                  Seen.Free;
                end;
                var Root := TJSONObject.Create; Root.AddPair('Device', Dev); Root.AddPair('Campaigns', ArrC); Root.AddPair('Success', TJSONBool.Create(True)); Root.AddPair('Message', '');
                Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := Root.ToJSON; Response.SendResponse; Root.Free;
              finally ArrC.Free; end;
            finally Assigns.Free; end;
          finally Q.Free; end;
        finally C.Free; end;
      finally Body.Free; end;
      Exit;
    end;
    if SameText(PathInfo, '/device/logs') and SameText(Request.Method, 'POST') then
    begin
      // Accept and ack; production would persist device logs in a dedicated table
      var Obj := TJSONObject.Create; Obj.AddPair('Success', TJSONBool.Create(True)); Obj.AddPair('Message','accepted');
      Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := Obj.ToJSON; Response.SendResponse; Obj.Free; Exit;
    end;

    // Playback logs
    if SameText(PathInfo, '/playback-logs') and SameText(Request.Method, 'POST') then
    begin
      var Body := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject; try
        if Body=nil then begin JSONError(400,'Invalid JSON'); Exit; end;
        var DisplayId := Body.GetValue<Integer>('DisplayId',0);
        var MediaFileId := Body.GetValue<Integer>('MediaFileId',0);
        var CampaignId := Body.GetValue<Integer>('CampaignId',0);
        var Ts := Body.GetValue<string>('PlaybackTimestamp','');
        if (DisplayId=0) or (MediaFileId=0) or (CampaignId=0) or (Ts='') then begin JSONError(400,'Missing fields'); Exit; end;
        var C := NewConnection; try
          var Q := TFDQuery.Create(nil); try
            Q.Connection := C;
            Q.SQL.Text := 'insert into PlaybackLogs (DisplayID, MediaFileID, CampaignID, PlaybackTimestamp) values (:D,:M,:C,:T)';
            Q.ParamByName('D').AsInteger := DisplayId;
            Q.ParamByName('M').AsInteger := MediaFileId;
            Q.ParamByName('C').AsInteger := CampaignId;
            Q.ParamByName('T').AsDateTime := ISO8601ToDate(Ts, False);
            Q.ExecSQL;
          finally Q.Free; end;
        finally C.Free; end;
        Response.StatusCode := 204; Response.ContentType := 'application/json'; Response.Content := ''; Response.SendResponse;
      finally Body.Free; end;
      Exit;
    end;

    Response.StatusCode := 404;
    Response.ContentType := 'application/json';
    Response.Content := '{"message":"Not Found"}';
    Response.SendResponse;
  except
    on E: Exception do
    begin
      Response.StatusCode := 500;
      Response.ContentType := 'application/json';
      Response.Content := '{"message":"' + StringReplace(E.Message, '"', '\"', [rfReplaceAll]) + '"}';
      Response.SendResponse;
    end;
  end;
end;

procedure TWebModule1.HandleHealth(Response: TWebResponse);
begin
  Response.StatusCode := 200;
  Response.ContentType := 'application/json';
  Response.Content := '{"value":"OK"}';
  Response.SendResponse;
end;

procedure TWebModule1.HandleOrganizations(Request: TWebRequest; Response: TWebResponse);
var
  List: TObjectList<TOrganization>;
  Arr: TJSONArray;
  Item: TJSONObject;
  Org: TOrganization;
begin
  List := TOrganizationRepository.GetOrganizations;
  try
    Arr := TJSONArray.Create;
    try
      for Org in List do
      begin
        Item := TJSONObject.Create;
        Item.AddPair('Id', TJSONNumber.Create(Org.Id));
        Item.AddPair('Name', Org.Name);
        Arr.AddElement(Item);
      end;
  var Wrapper := TJSONObject.Create; try
    Wrapper.AddPair('value', Arr);
    Response.StatusCode := 200;
    Response.ContentType := 'application/json';
    Response.Content := Wrapper.ToJSON;
    Response.SendResponse;
  finally Wrapper.Free; end;
    finally
      Arr.Free;
    end;
  finally
    List.Free;
  end;
end;

procedure TWebModule1.HandleOrganizationById(Request: TWebRequest; Response: TWebResponse);
var
  IdStr: string;
  Id: Integer;
  Org: TOrganization;
  Obj: TJSONObject;
begin
  // Support optional /api prefix by stripping it before extracting the id
  var P := Request.PathInfo;
  if Copy(P,1,4)='/api' then P := Copy(P,5,MaxInt);
  IdStr := Copy(P, 16, MaxInt);
  Id := StrToIntDef(IdStr, 0);
  if Id = 0 then
  begin
    Response.StatusCode := 400;
    Response.ContentType := 'application/json';
    Response.Content := '{"message":"Invalid organization id"}';
    Response.SendResponse;
    Exit;
  end;

  Org := TOrganizationRepository.GetOrganization(Id);
  if Org = nil then
  begin
    Response.StatusCode := 404;
    Response.ContentType := 'application/json';
    Response.Content := '{"message":"Not found"}';
    Response.SendResponse;
    Exit;
  end;

  Obj := TJSONObject.Create;
  try
    Obj.AddPair('Id', TJSONNumber.Create(Org.Id));
    Obj.AddPair('Name', Org.Name);
    Response.StatusCode := 200;
    Response.ContentType := 'application/json';
    Response.Content := Obj.ToJSON;
  Response.SendResponse;
  finally
    Obj.Free;
    Org.Free;
  end;
end;

end.

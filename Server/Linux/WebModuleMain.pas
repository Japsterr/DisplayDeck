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
  MenuRepository,
  MenuSectionRepository,
  MenuItemRepository,
  DisplayCampaignRepository,
  DisplayMenuRepository,
  ScheduleRepository,
  MediaFileRepository,
  InfoBoardRepository,
  InfoBoardSectionRepository,
  InfoBoardItemRepository,
  UserRepository,
  RefreshTokenRepository,
  EmailVerificationTokenRepository,
  PasswordResetTokenRepository,
  ApiKeyRepository,
  IdempotencyRepository,
  AuditLogRepository,
  WebhookRepository,
  PasswordUtils,
  JWTUtils,
  EmailSender,
  AWSSigV4,
  ProvisioningTokenRepository,
  ProvisioningTokenEventRepository,
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
  function TryPresignS3GetUrlFromStorageUrl(
    const StorageUrl, PublicEndpoint, InternalEndpoint, Access, Secret, Region: string;
    out OutUrl: string
  ): Boolean;
  begin
    Result := False;
    OutUrl := '';

    var Path := Trim(StorageUrl);
    if Path='' then Exit;

    if (PublicEndpoint<>'') and Path.StartsWith(PublicEndpoint) then
      Path := Copy(Path, Length(PublicEndpoint)+1, MaxInt)
    else if (InternalEndpoint<>'') and Path.StartsWith(InternalEndpoint) then
      Path := Copy(Path, Length(InternalEndpoint)+1, MaxInt);

    if (Length(Path)>0) and (Path[1]='/') then Path := Copy(Path,2,MaxInt);

    // Backward-compat: StorageURL may include a reverse-proxy prefix (e.g. https://api.../minio/{bucket}/{key}).
    if (Length(Path) >= 6) and SameText(Copy(Path, 1, 6), 'minio/') then
      Path := Copy(Path, 7, MaxInt);

    // Strip scheme/host if present.
    var SchemePos := Pos('://', Path);
    if SchemePos>0 then
    begin
      var HostEndIdx := SchemePos + 3;
      var SlashAfterHost := 0;
      var i := HostEndIdx;
      while i <= Length(Path) do begin if Path[i]='/' then begin SlashAfterHost := i; Break; end; Inc(i); end;
      if SlashAfterHost>0 then Path := Copy(Path, SlashAfterHost+1, MaxInt);
    end;

    if (Length(Path) >= 6) and SameText(Copy(Path, 1, 6), 'minio/') then
      Path := Copy(Path, 7, MaxInt);

    var p := Pos('/', Path);
    if p=0 then Exit;
    var Bucket := Copy(Path,1,p-1);
    var Key := Copy(Path,p+1, MaxInt);
    if (Bucket='') or (Key='') then Exit;

    var Params: TS3PresignParams;
    Params.Endpoint := PublicEndpoint;
    if Params.Endpoint = '' then Params.Endpoint := InternalEndpoint;
    Params.Region := Region;
    Params.Bucket := Bucket;
    Params.ObjectKey := Key;
    Params.AccessKey := Access;
    Params.SecretKey := Secret;
    Params.Method := 'GET';
    Params.ExpiresSeconds := 900;
    Result := BuildS3PresignedUrl(Params, OutUrl);
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
            // Send verification email (optional; enforced only if AUTH_REQUIRE_EMAIL_VERIFICATION=true)
            try
              var PublicWebUrl := GetEnv('PUBLIC_WEB_URL', 'http://localhost:3000');
              if (PublicWebUrl <> '') and PublicWebUrl.EndsWith('/') then
                PublicWebUrl := PublicWebUrl.Substring(0, Length(PublicWebUrl)-1);
              var VerifyToken := GenerateOpaqueToken;
              TEmailVerificationTokenRepository.InvalidateOutstandingForUser(User.Id);
              TEmailVerificationTokenRepository.StoreToken(User.Id, HashSha256Hex(VerifyToken), Now + 2);
              var VerifyLink := PublicWebUrl + '/verify-email?token=' + VerifyToken;
              TEmailSender.SendPlainText(User.Email, 'Verify your DisplayDeck account',
                'Welcome to DisplayDeck.' + sLineBreak + sLineBreak +
                'Verify your email address by clicking this link:' + sLineBreak +
                VerifyLink + sLineBreak + sLineBreak +
                'If you did not create this account, you can ignore this email.');
            except
              on E: Exception do
                Writeln('Auth register: failed to send verification email: ' + E.Message);
            end;

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
            UserObj.AddPair('Role', User.Role);
            if User.HasEmailVerifiedAt then
              UserObj.AddPair('EmailVerifiedAt', DateToISO8601(User.EmailVerifiedAt, True))
            else
              UserObj.AddPair('EmailVerifiedAt', TJSONNull.Create);
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

          // Optional: block login until email verified
          if SameText(GetEnv('AUTH_REQUIRE_EMAIL_VERIFICATION','false'), 'true') then
          begin
            if not U.HasEmailVerifiedAt then
            begin
              JSONError(403, 'Email not verified', 'email_not_verified');
              Exit;
            end;
          end;

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
          UserObj.AddPair('Role', U.Role);
          if U.HasEmailVerifiedAt then
            UserObj.AddPair('EmailVerifiedAt', DateToISO8601(U.EmailVerifiedAt, True))
          else
            UserObj.AddPair('EmailVerifiedAt', TJSONNull.Create);
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

    if SameText(NormalizedPath, '/auth/resend-verification') and SameText(Request.Method, 'POST') then
    begin
      var Body := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject;
      try
        if (Body=nil) then begin JSONError(400,'Invalid JSON'); Exit; end;
        var Email := Body.GetValue<string>('Email','');
        if Email='' then begin JSONError(400,'Missing Email'); Exit; end;

        // Always return 200 to avoid account enumeration.
        var U := TUserRepository.FindByEmail(Email);
        if (U<>nil) then
        try
          if not U.HasEmailVerifiedAt then
          begin
            var PublicWebUrl := GetEnv('PUBLIC_WEB_URL', 'http://localhost:3000');
            if (PublicWebUrl <> '') and PublicWebUrl.EndsWith('/') then
              PublicWebUrl := PublicWebUrl.Substring(0, Length(PublicWebUrl)-1);
            var VerifyToken := GenerateOpaqueToken;
            TEmailVerificationTokenRepository.InvalidateOutstandingForUser(U.Id);
            TEmailVerificationTokenRepository.StoreToken(U.Id, HashSha256Hex(VerifyToken), Now + 2);
            var VerifyLink := PublicWebUrl + '/verify-email?token=' + VerifyToken;
            TEmailSender.SendPlainText(U.Email, 'Verify your DisplayDeck account',
              'Verify your email address by clicking this link:' + sLineBreak +
              VerifyLink + sLineBreak);
          end;
        finally
          U.Free;
        end;

        var Obj := TJSONObject.Create;
        try
          Obj.AddPair('Success', TJSONBool.Create(True));
          Obj.AddPair('Message', 'If the account exists, a verification email has been sent.');
          if GetEnvironmentVariable('SMTP_HOST') = '' then
            Obj.AddPair('EmailMode', 'log')
          else
            Obj.AddPair('EmailMode', 'smtp');
          Response.StatusCode := 200;
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

    if SameText(NormalizedPath, '/auth/verify-email') and SameText(Request.Method, 'POST') then
    begin
      var Body := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject;
      try
        if (Body=nil) then begin JSONError(400,'Invalid JSON'); Exit; end;
        var Token := Body.GetValue<string>('Token','');
        if Token='' then begin JSONError(400,'Missing Token'); Exit; end;

        var UserId: Integer;
        if not TEmailVerificationTokenRepository.ConsumeToken(HashSha256Hex(Token), UserId) then
        begin
          JSONError(400, 'Invalid or expired token', 'invalid_token');
          Exit;
        end;

        TUserRepository.MarkEmailVerified(UserId);

        var Obj := TJSONObject.Create;
        try
          Obj.AddPair('Success', TJSONBool.Create(True));
          Obj.AddPair('Message', 'Email verified.');
          Response.StatusCode := 200;
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

    if SameText(NormalizedPath, '/auth/forgot-password') and SameText(Request.Method, 'POST') then
    begin
      var Body := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject;
      try
        if (Body=nil) then begin JSONError(400,'Invalid JSON'); Exit; end;
        var Email := Body.GetValue<string>('Email','');
        if Email='' then begin JSONError(400,'Missing Email'); Exit; end;

        // Always return 200 to avoid account enumeration.
        var U := TUserRepository.FindByEmail(Email);
        if (U<>nil) then
        try
          var PublicWebUrl := GetEnv('PUBLIC_WEB_URL', 'http://localhost:3000');
          if (PublicWebUrl <> '') and PublicWebUrl.EndsWith('/') then
            PublicWebUrl := PublicWebUrl.Substring(0, Length(PublicWebUrl)-1);
          var ResetToken := GenerateOpaqueToken;
          TPasswordResetTokenRepository.InvalidateOutstandingForUser(U.Id);
          TPasswordResetTokenRepository.StoreToken(U.Id, HashSha256Hex(ResetToken), Now + (1/24)); // 1 hour
          var ResetLink := PublicWebUrl + '/reset-password?token=' + ResetToken;
          TEmailSender.SendPlainText(U.Email, 'Reset your DisplayDeck password',
            'Click this link to reset your password:' + sLineBreak +
            ResetLink + sLineBreak + sLineBreak +
            'This link expires in 1 hour.');
        finally
          U.Free;
        end;

        var Obj := TJSONObject.Create;
        try
          Obj.AddPair('Success', TJSONBool.Create(True));
          Obj.AddPair('Message', 'If the account exists, a reset email has been sent.');
          if GetEnvironmentVariable('SMTP_HOST') = '' then
            Obj.AddPair('EmailMode', 'log')
          else
            Obj.AddPair('EmailMode', 'smtp');
          Response.StatusCode := 200;
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

    if SameText(NormalizedPath, '/auth/reset-password') and SameText(Request.Method, 'POST') then
    begin
      var Body := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject;
      try
        if (Body=nil) then begin JSONError(400,'Invalid JSON'); Exit; end;
        var Token := Body.GetValue<string>('Token','');
        var NewPassword := Body.GetValue<string>('Password','');
        if Token='' then begin JSONError(400,'Missing Token'); Exit; end;
        if NewPassword='' then begin JSONError(400,'Missing Password'); Exit; end;

        var UserId: Integer;
        if not TPasswordResetTokenRepository.ConsumeToken(HashSha256Hex(Token), UserId) then
        begin
          JSONError(400, 'Invalid or expired token', 'invalid_token');
          Exit;
        end;

        TUserRepository.SetPassword(UserId, NewPassword);

        // Revoke all refresh tokens for this user
        var U := TUserRepository.FindById(UserId);
        if U<>nil then
        try
          TRefreshTokenRepository.RevokeAllForUser(U.OrganizationId, U.Id);
        finally
          U.Free;
        end;

        var Obj := TJSONObject.Create;
        try
          Obj.AddPair('Success', TJSONBool.Create(True));
          Obj.AddPair('Message', 'Password updated.');
          Response.StatusCode := 200;
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

        // ----- Organization Users -----
        if (PathOrgId > 0) and SameText(Tail, 'users') and SameText(Request.Method, 'GET') then
        begin
          var AuthOrgId, AuthUserId: Integer; var AuthRole: string;
          if not RequireAuth([], AuthOrgId, AuthUserId, AuthRole) then Exit;
          if AuthOrgId <> PathOrgId then begin JSONError(403,'Forbidden'); Exit; end;
          if not SameText(AuthRole, 'Owner') then begin JSONError(403,'Forbidden'); Exit; end;

          var C := NewConnection;
          try
            var Q := TFDQuery.Create(nil);
            try
              Q.Connection := C;
              Q.SQL.Text := 'select UserID, Email, Role, CreatedAt, EmailVerifiedAt from Users where OrganizationID=:Org order by UserID';
              Q.ParamByName('Org').AsInteger := PathOrgId;
              Q.Open;
              var Arr := TJSONArray.Create;
              try
                while not Q.Eof do
                begin
                  var Obj := TJSONObject.Create;
                  Obj.AddPair('Id', TJSONNumber.Create(Q.FieldByName('UserID').AsLargeInt));
                  Obj.AddPair('OrganizationId', TJSONNumber.Create(PathOrgId));
                  Obj.AddPair('Email', Q.FieldByName('Email').AsString);
                  Obj.AddPair('Role', Q.FieldByName('Role').AsString);
                  Obj.AddPair('CreatedAt', DateToISO8601(Q.FieldByName('CreatedAt').AsDateTime, True));
                  if not Q.FieldByName('EmailVerifiedAt').IsNull then
                    Obj.AddPair('EmailVerifiedAt', DateToISO8601(Q.FieldByName('EmailVerifiedAt').AsDateTime, True))
                  else
                    Obj.AddPair('EmailVerifiedAt', TJSONNull.Create);
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

        if (PathOrgId > 0) and SameText(Tail, 'users') and SameText(Request.Method, 'POST') then
        begin
          var AuthOrgId, AuthUserId: Integer; var AuthRole: string;
          if not RequireAuth([], AuthOrgId, AuthUserId, AuthRole) then Exit;
          if AuthOrgId <> PathOrgId then begin JSONError(403,'Forbidden'); Exit; end;
          if not SameText(AuthRole, 'Owner') then begin JSONError(403,'Forbidden'); Exit; end;

          var Body := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject;
          try
            if Body=nil then begin JSONError(400,'Invalid JSON'); Exit; end;
            var Email := Body.GetValue<string>('Email','');
            var Role := Body.GetValue<string>('Role','ContentManager');
            if Email='' then begin JSONError(400,'Missing Email'); Exit; end;
            if Role='' then Role := 'ContentManager';

            // Create user with a random temp password, then email a reset link.
            var TempPassword := 'Temp-' + Copy(GenerateOpaqueToken, 1, 12);
            var NewUser: TUser := nil;
            try
              NewUser := TUserRepository.CreateUser(PathOrgId, Email, TempPassword, Role);

              var PublicWebUrl := GetEnv('PUBLIC_WEB_URL', 'http://localhost:3000');
              if (PublicWebUrl <> '') and PublicWebUrl.EndsWith('/') then
                PublicWebUrl := PublicWebUrl.Substring(0, Length(PublicWebUrl)-1);

              var ResetToken := GenerateOpaqueToken;
              TPasswordResetTokenRepository.InvalidateOutstandingForUser(NewUser.Id);
              TPasswordResetTokenRepository.StoreToken(NewUser.Id, HashSha256Hex(ResetToken), Now + (1/24));
              var ResetLink := PublicWebUrl + '/reset-password?token=' + ResetToken;

              var VerifyToken := GenerateOpaqueToken;
              TEmailVerificationTokenRepository.InvalidateOutstandingForUser(NewUser.Id);
              TEmailVerificationTokenRepository.StoreToken(NewUser.Id, HashSha256Hex(VerifyToken), Now + 2);
              var VerifyLink := PublicWebUrl + '/verify-email?token=' + VerifyToken;

              TEmailSender.SendPlainText(NewUser.Email, 'You have been invited to DisplayDeck',
                'An account has been created for you.' + sLineBreak + sLineBreak +
                '1) Set your password:' + sLineBreak + ResetLink + sLineBreak + sLineBreak +
                '2) Verify your email:' + sLineBreak + VerifyLink + sLineBreak);

              TAuditLogRepository.WriteEvent(PathOrgId, AuthUserId, 'user.create', 'user', IntToStr(NewUser.Id), nil, RequestId, ClientIp, UserAgent);

              var UserObj := TJSONObject.Create;
              try
                UserObj.AddPair('Id', TJSONNumber.Create(NewUser.Id));
                UserObj.AddPair('OrganizationId', TJSONNumber.Create(NewUser.OrganizationId));
                UserObj.AddPair('Email', NewUser.Email);
                UserObj.AddPair('Role', NewUser.Role);
                UserObj.AddPair('EmailVerifiedAt', TJSONNull.Create);

                Response.StatusCode := 201;
                Response.ContentType := 'application/json';
                Response.Content := UserObj.ToJSON;
                Response.SendResponse;
              finally
                UserObj.Free;
              end;
            finally
              NewUser.Free;
            end;
          finally
            Body.Free;
          end;
          Exit;
        end;

        if (PathOrgId > 0) and (Copy(Tail, 1, 6) = 'users/') and SameText(Request.Method, 'PATCH') then
        begin
          var AuthOrgId, AuthUserId: Integer; var AuthRole: string;
          if not RequireAuth([], AuthOrgId, AuthUserId, AuthRole) then Exit;
          if AuthOrgId <> PathOrgId then begin JSONError(403,'Forbidden'); Exit; end;
          if not SameText(AuthRole, 'Owner') then begin JSONError(403,'Forbidden'); Exit; end;

          var UserIdToUpdate := StrToIntDef(Copy(Tail, 7, MaxInt), 0);
          if UserIdToUpdate <= 0 then begin JSONError(400,'Invalid user id'); Exit; end;

          if UserIdToUpdate = AuthUserId then
          begin
            JSONError(400,'Cannot change your own role','cannot_change_own_role');
            Exit;
          end;

          var Body := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject;
          try
            if Body=nil then begin JSONError(400,'Invalid JSON'); Exit; end;
            var NewRole := Body.GetValue<string>('Role','');
            if NewRole='' then begin JSONError(400,'Missing Role'); Exit; end;
            if (not SameText(NewRole,'Owner')) and (not SameText(NewRole,'ContentManager')) then
            begin
              JSONError(400,'Invalid Role','invalid_role');
              Exit;
            end;

            var C := NewConnection;
            try
              // Fetch current role
              var CurRole := '';
              var Qr := TFDQuery.Create(nil);
              try
                Qr.Connection := C;
                Qr.SQL.Text := 'select Role from Users where OrganizationID=:Org and UserID=:UserId';
                Qr.ParamByName('Org').AsInteger := PathOrgId;
                Qr.ParamByName('UserId').AsInteger := UserIdToUpdate;
                Qr.Open;
                if Qr.Eof then begin JSONError(404,'Not found'); Exit; end;
                CurRole := Qr.FieldByName('Role').AsString;
              finally
                Qr.Free;
              end;

              // Guard: cannot remove the last Owner
              if SameText(CurRole,'Owner') and (not SameText(NewRole,'Owner')) then
              begin
                var Qc := TFDQuery.Create(nil);
                try
                  Qc.Connection := C;
                  Qc.SQL.Text := 'select count(*) as Cnt from Users where OrganizationID=:Org and Role=''Owner''';
                  Qc.ParamByName('Org').AsInteger := PathOrgId;
                  Qc.Open;
                  if Qc.FieldByName('Cnt').AsInteger <= 1 then
                  begin
                    JSONError(400,'Cannot remove the last Owner','cannot_remove_last_owner');
                    Exit;
                  end;
                finally
                  Qc.Free;
                end;
              end;

              // Update role
              var Qu := TFDQuery.Create(nil);
              try
                Qu.Connection := C;
                Qu.SQL.Text := 'update Users set Role=:Role where OrganizationID=:Org and UserID=:UserId';
                Qu.ParamByName('Role').AsString := NewRole;
                Qu.ParamByName('Org').AsInteger := PathOrgId;
                Qu.ParamByName('UserId').AsInteger := UserIdToUpdate;
                Qu.ExecSQL;
              finally
                Qu.Free;
              end;

              TAuditLogRepository.WriteEvent(PathOrgId, AuthUserId, 'user.role_update', 'user', IntToStr(UserIdToUpdate), nil, RequestId, ClientIp, UserAgent);

              // Return updated user (minimal fields)
              var Qo := TFDQuery.Create(nil);
              try
                Qo.Connection := C;
                Qo.SQL.Text := 'select UserID, Email, Role, CreatedAt, EmailVerifiedAt from Users where OrganizationID=:Org and UserID=:UserId';
                Qo.ParamByName('Org').AsInteger := PathOrgId;
                Qo.ParamByName('UserId').AsInteger := UserIdToUpdate;
                Qo.Open;
                if Qo.Eof then begin JSONError(404,'Not found'); Exit; end;

                var Obj := TJSONObject.Create;
                try
                  Obj.AddPair('Id', TJSONNumber.Create(Qo.FieldByName('UserID').AsLargeInt));
                  Obj.AddPair('OrganizationId', TJSONNumber.Create(PathOrgId));
                  Obj.AddPair('Email', Qo.FieldByName('Email').AsString);
                  Obj.AddPair('Role', Qo.FieldByName('Role').AsString);
                  Obj.AddPair('CreatedAt', DateToISO8601(Qo.FieldByName('CreatedAt').AsDateTime, True));
                  if not Qo.FieldByName('EmailVerifiedAt').IsNull then
                    Obj.AddPair('EmailVerifiedAt', DateToISO8601(Qo.FieldByName('EmailVerifiedAt').AsDateTime, True))
                  else
                    Obj.AddPair('EmailVerifiedAt', TJSONNull.Create);

                  Response.StatusCode := 200;
                  Response.ContentType := 'application/json';
                  Response.Content := Obj.ToJSON;
                  Response.SendResponse;
                finally
                  Obj.Free;
                end;
              finally
                Qo.Free;
              end;
            finally
              C.Free;
            end;
          finally
            Body.Free;
          end;
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

        // Provisioning token lifecycle events (org-scoped by token)
        // GET /organizations/{orgId}/provisioning-token-events?token=ABC123&limit=100&beforeId=0
        if (PathOrgId > 0) and SameText(Tail, 'provisioning-token-events') and SameText(Request.Method, 'GET') then
        begin
          var AuthOrgId, AuthUserId: Integer; var AuthRole: string;
          if not RequireAuth(['audit:read'], AuthOrgId, AuthUserId, AuthRole) then Exit;
          if AuthOrgId <> PathOrgId then begin JSONError(403,'Forbidden'); Exit; end;

          var Tok := Trim(Request.QueryFields.Values['token']);
          if Tok = '' then begin JSONError(400,'Missing token'); Exit; end;
          Tok := UpperCase(Tok);

          var Limit := StrToIntDef(Request.QueryFields.Values['limit'], 100);
          if Limit <= 0 then Limit := 100;
          if Limit > 200 then Limit := 200;
          var BeforeId := StrToInt64Def(Request.QueryFields.Values['beforeId'], 0);

          var C := NewConnection;
          try
            // Ensure token belongs (or belonged) to this org (prevents leaking device-side events).
            // Note: tokens can be unpaired, clearing OrganizationID from ProvisioningTokens.
            var QCheck := TFDQuery.Create(nil);
            try
              QCheck.Connection := C;
              QCheck.SQL.Text :=
                'select 1 where exists (select 1 from ProvisioningTokens where Token=:T and OrganizationID=:Org) '
                + 'or exists (select 1 from ProvisioningTokenEvents where Token=:T and OrganizationID=:Org)';
              QCheck.ParamByName('T').AsString := Tok;
              QCheck.ParamByName('Org').AsInteger := PathOrgId;
              QCheck.Open;
              if QCheck.Eof then begin JSONError(404,'Not found'); Exit; end;
            finally
              QCheck.Free;
            end;

            var Q := TFDQuery.Create(nil);
            try
              Q.Connection := C;
              Q.SQL.Text := 'select EventID, CreatedAt, EventType, HardwareId, DisplayID, OrganizationID, UserID, Details, RequestId, IpAddress, UserAgent '
                          + 'from ProvisioningTokenEvents where Token=:T '
                          + 'and (:BeforeId=0 or EventID < :BeforeId) '
                          + 'order by EventID desc limit ' + IntToStr(Limit + 1);
              Q.ParamByName('T').AsString := Tok;
              Q.ParamByName('BeforeId').AsLargeInt := BeforeId;
              Q.Open;

              var Arr := TJSONArray.Create;
              var NextBeforeId: Int64 := 0;
              try
                var Count := 0;
                while (not Q.Eof) and (Count < Limit) do
                begin
                  var Obj := TJSONObject.Create;
                  Obj.AddPair('EventId', TJSONNumber.Create(Q.FieldByName('EventID').AsLargeInt));
                  Obj.AddPair('CreatedAt', DateToISO8601(Q.FieldByName('CreatedAt').AsDateTime, True));
                  Obj.AddPair('EventType', Q.FieldByName('EventType').AsString);
                  if not Q.FieldByName('HardwareId').IsNull then Obj.AddPair('HardwareId', Q.FieldByName('HardwareId').AsString) else Obj.AddPair('HardwareId', TJSONNull.Create);
                  if not Q.FieldByName('DisplayID').IsNull then Obj.AddPair('DisplayId', TJSONNumber.Create(Q.FieldByName('DisplayID').AsInteger)) else Obj.AddPair('DisplayId', TJSONNull.Create);
                  if not Q.FieldByName('OrganizationID').IsNull then Obj.AddPair('OrganizationId', TJSONNumber.Create(Q.FieldByName('OrganizationID').AsInteger)) else Obj.AddPair('OrganizationId', TJSONNull.Create);
                  if not Q.FieldByName('UserID').IsNull then Obj.AddPair('UserId', TJSONNumber.Create(Q.FieldByName('UserID').AsInteger)) else Obj.AddPair('UserId', TJSONNull.Create);
                  Obj.AddPair('Details', Q.FieldByName('Details').AsString);
                  Obj.AddPair('RequestId', Q.FieldByName('RequestId').AsString);
                  Obj.AddPair('IpAddress', Q.FieldByName('IpAddress').AsString);
                  Obj.AddPair('UserAgent', Q.FieldByName('UserAgent').AsString);
                  Arr.AddElement(Obj);
                  Inc(Count);
                  Q.Next;
                end;

                if not Q.Eof then
                  NextBeforeId := Q.FieldByName('EventID').AsLargeInt;

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

        // Provisioning device lifecycle events (org-scoped by hardware id)
        // GET /organizations/{orgId}/provisioning-device-events?hardwareId=HW123&limit=100&beforeId=0
        if (PathOrgId > 0) and SameText(Tail, 'provisioning-device-events') and SameText(Request.Method, 'GET') then
        begin
          var TokOrg, TokUser: Integer; var TokRole: string;
          if not RequireAuth(['audit:read'], TokOrg, TokUser, TokRole) then Exit;
          if TokOrg <> PathOrgId then begin JSONError(403,'Forbidden'); Exit; end;

          var Hw := Trim(Request.QueryFields.Values['hardwareId']);
          if Hw = '' then begin JSONError(400,'Missing hardwareId'); Exit; end;

          var Limit := StrToIntDef(Request.QueryFields.Values['limit'], 100);
          if (Limit <= 0) then Limit := 100;
          if (Limit > 500) then Limit := 500;
          var BeforeId := StrToIntDef(Request.QueryFields.Values['beforeId'], 0);

          var C := NewConnection;
          try
            // Ensure device has events in this org
            var QCheck := TFDQuery.Create(nil);
            try
              QCheck.Connection := C;
              QCheck.SQL.Text := 'select 1 from ProvisioningTokenEvents where OrganizationID=:Org and HardwareId=:H limit 1';
              QCheck.ParamByName('Org').AsInteger := PathOrgId;
              QCheck.ParamByName('H').AsString := Hw;
              QCheck.Open;
              if QCheck.Eof then begin JSONError(404,'Not found'); Exit; end;
            finally
              QCheck.Free;
            end;

            var Q := TFDQuery.Create(nil);
            try
              Q.Connection := C;
              Q.SQL.Text :=
                'select Id, CreatedAt, Token, EventType, HardwareId, DisplayID, OrganizationID, UserID, Details '
                + 'from ProvisioningTokenEvents '
                + 'where OrganizationID=:Org and HardwareId=:H '
                + 'and (:BeforeId=0 or Id<:BeforeId) '
                + 'order by Id desc limit :L';
              Q.ParamByName('Org').AsInteger := PathOrgId;
              Q.ParamByName('H').AsString := Hw;
              Q.ParamByName('BeforeId').AsInteger := BeforeId;
              Q.ParamByName('L').AsInteger := Limit;
              Q.Open;

              var Arr := TJSONArray.Create;
              try
                while not Q.Eof do
                begin
                  var It := TJSONObject.Create;
                  It.AddPair('Id', TJSONNumber.Create(Q.FieldByName('Id').AsInteger));
                  It.AddPair('CreatedAt', DateToISO8601(Q.FieldByName('CreatedAt').AsDateTime, True));
                  It.AddPair('Token', Q.FieldByName('Token').AsString);
                  It.AddPair('EventType', Q.FieldByName('EventType').AsString);
                  if Trim(Q.FieldByName('HardwareId').AsString) <> '' then It.AddPair('HardwareId', Trim(Q.FieldByName('HardwareId').AsString)) else It.AddPair('HardwareId', TJSONNull.Create);
                  if not Q.FieldByName('DisplayID').IsNull then It.AddPair('DisplayId', TJSONNumber.Create(Q.FieldByName('DisplayID').AsInteger)) else It.AddPair('DisplayId', TJSONNull.Create);
                  if not Q.FieldByName('OrganizationID').IsNull then It.AddPair('OrganizationId', TJSONNumber.Create(Q.FieldByName('OrganizationID').AsInteger)) else It.AddPair('OrganizationId', TJSONNull.Create);
                  if not Q.FieldByName('UserID').IsNull then It.AddPair('UserId', TJSONNumber.Create(Q.FieldByName('UserID').AsInteger)) else It.AddPair('UserId', TJSONNull.Create);
                  var Dv := Q.FieldByName('Details').AsString;
                  if Trim(Dv) <> '' then
                  begin
                    var Parsed := TJSONObject.ParseJSONValue(Dv);
                    if Assigned(Parsed) then It.AddPair('Details', Parsed) else It.AddPair('Details', TJSONNull.Create);
                  end
                  else
                    It.AddPair('Details', TJSONNull.Create);
                  Arr.AddElement(It);
                  Q.Next;
                end;
                var OutBody := Arr.ToJSON;
                Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := OutBody; Response.SendResponse;
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

        // Provisioning devices list (org-scoped by hardware id)
        // GET /organizations/{orgId}/provisioning-devices?afterHardwareId=...&limit=200
        if (PathOrgId > 0) and SameText(Tail, 'provisioning-devices') and SameText(Request.Method, 'GET') then
        begin
          var TokOrg, TokUser: Integer; var TokRole: string;
          if not RequireAuth(['audit:read'], TokOrg, TokUser, TokRole) then Exit;
          if TokOrg <> PathOrgId then begin JSONError(403,'Forbidden'); Exit; end;

          var AfterHw := Trim(Request.QueryFields.Values['afterHardwareId']);
          var Limit := StrToIntDef(Request.QueryFields.Values['limit'], 200);
          if (Limit <= 0) then Limit := 200;
          if (Limit > 1000) then Limit := 1000;

          var C := NewConnection;
          try
            var Q := TFDQuery.Create(nil);
            try
              Q.Connection := C;
              Q.SQL.Text :=
                'select HardwareId, '
                + 'max(CreatedAt) as LastSeenAt, '
                + 'max(Id) as LastEventId, '
                + 'count(1) as EventsCount, '
                + 'count(distinct Token) as TokensCount, '
                + 'count(distinct DisplayID) as DisplaysCount '
                + 'from ProvisioningTokenEvents '
                + 'where OrganizationID=:Org '
                + 'and HardwareId is not null and HardwareId<>'''' '
                + 'and (:AfterHw='''' or HardwareId>:AfterHw) '
                + 'group by HardwareId '
                + 'order by HardwareId asc '
                + 'limit :L';
              Q.ParamByName('Org').AsInteger := PathOrgId;
              Q.ParamByName('AfterHw').AsString := AfterHw;
              Q.ParamByName('L').AsInteger := Limit;
              Q.Open;

              var Arr := TJSONArray.Create;
              try
                while not Q.Eof do
                begin
                  var It := TJSONObject.Create;
                  It.AddPair('HardwareId', Q.FieldByName('HardwareId').AsString);
                  It.AddPair('LastSeenAt', DateToISO8601(Q.FieldByName('LastSeenAt').AsDateTime, True));
                  It.AddPair('LastEventId', TJSONNumber.Create(Q.FieldByName('LastEventId').AsInteger));
                  It.AddPair('EventsCount', TJSONNumber.Create(Q.FieldByName('EventsCount').AsInteger));
                  It.AddPair('TokensCount', TJSONNumber.Create(Q.FieldByName('TokensCount').AsInteger));
                  It.AddPair('DisplaysCount', TJSONNumber.Create(Q.FieldByName('DisplaysCount').AsInteger));
                  Arr.AddElement(It);
                  Q.Next;
                end;
                Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := Arr.ToJSON; Response.SendResponse;
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

        // Audit stats (lightweight rollups)
        if (PathOrgId > 0) and SameText(Tail, 'stats/display-lifecycle') and SameText(Request.Method, 'GET') then
        begin
          var AuthOrgId, AuthUserId: Integer; var AuthRole: string;
          if not RequireAuth(['audit:read'], AuthOrgId, AuthUserId, AuthRole) then Exit;
          if AuthOrgId <> PathOrgId then begin JSONError(403,'Forbidden'); Exit; end;

          var Days := StrToIntDef(Request.QueryFields.Values['days'], 30);
          if Days <= 0 then Days := 30;
          if Days > 365 then Days := 365;

          var FromAt := Now - Days;
          var ToAt := Now;

          var PairedCount := 0;
          var RemovedCount := 0;

          var C := NewConnection;
          try
            var Q := TFDQuery.Create(nil);
            try
              Q.Connection := C;
              Q.SQL.Text :=
                'select Action, count(*) as Cnt ' +
                'from AuditLogs ' +
                'where OrganizationID=:Org ' +
                'and CreatedAt >= :FromAt ' +
                'and Action in (''display.pair'',''display.delete'') ' +
                'group by Action';
              Q.ParamByName('Org').AsInteger := PathOrgId;
              Q.ParamByName('FromAt').AsDateTime := FromAt;
              Q.Open;
              while not Q.Eof do
              begin
                var Act := Q.FieldByName('Action').AsString;
                var Cnt := Q.FieldByName('Cnt').AsInteger;
                if SameText(Act, 'display.pair') then PairedCount := Cnt;
                if SameText(Act, 'display.delete') then RemovedCount := Cnt;
                Q.Next;
              end;
            finally
              Q.Free;
            end;
          finally
            C.Free;
          end;

          var OutObj := TJSONObject.Create;
          try
            OutObj.AddPair('Days', TJSONNumber.Create(Days));
            OutObj.AddPair('From', DateToISO8601(FromAt, True));
            OutObj.AddPair('To', DateToISO8601(ToAt, True));
            var Counts := TJSONObject.Create;
            Counts.AddPair('Paired', TJSONNumber.Create(PairedCount));
            Counts.AddPair('Removed', TJSONNumber.Create(RemovedCount));
            OutObj.AddPair('Counts', Counts);
            Response.StatusCode := 200;
            Response.ContentType := 'application/json';
            Response.Content := OutObj.ToJSON;
            Response.SendResponse;
          finally
            OutObj.Free;
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
    // Important: match only the collection route (/organizations/{orgId}/displays),
    // otherwise sub-routes like /organizations/{orgId}/displays/claim will be incorrectly handled here.
    if (Copy(NormalizedPath, 1, 15) = '/organizations/') and (NormalizedPath.EndsWith('/displays') or NormalizedPath.EndsWith('/displays/')) then
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
              // Compute online/offline from heartbeat. Avoid trusting stale CurrentStatus.
              var OnlineSeconds := StrToIntDef(GetEnv('HEARTBEAT_ONLINE_SECONDS','90'), 90);
              var Status := 'Offline';
              if (D.LastHeartbeatAt > 0) and (SecondsBetween(Now, D.LastHeartbeatAt) <= OnlineSeconds) then
                Status := 'Online';

              var It := TJSONObject.Create;
              It.AddPair('Id', TJSONNumber.Create(D.Id));
              It.AddPair('Name', D.Name);
              It.AddPair('Orientation', D.Orientation);
              It.AddPair('CurrentStatus', Status);
              if (D.LastSeen > 0) then It.AddPair('LastSeen', DateToISO8601(D.LastSeen, True)) else It.AddPair('LastSeen', TJSONNull.Create);
              if (D.ProvisioningToken <> '') then It.AddPair('ProvisioningToken', D.ProvisioningToken) else It.AddPair('ProvisioningToken', TJSONNull.Create);
              if (D.LastHeartbeatAt > 0) then It.AddPair('LastHeartbeatAt', DateToISO8601(D.LastHeartbeatAt, True)) else It.AddPair('LastHeartbeatAt', TJSONNull.Create);
              if (D.AppVersion <> '') then It.AddPair('AppVersion', D.AppVersion) else It.AddPair('AppVersion', TJSONNull.Create);
              if (D.LastIp <> '') then It.AddPair('LastIp', D.LastIp) else It.AddPair('LastIp', TJSONNull.Create);
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

    // Organization display actions: /organizations/{orgId}/displays/{displayId}/unpair
    if (Copy(NormalizedPath, 1, 15) = '/organizations/') and (Pos('/displays/', NormalizedPath) > 0) and (Pos('/unpair', NormalizedPath) > 0) and SameText(Request.Method, 'POST') then
    begin
      var OrgIdStr := Copy(NormalizedPath, 16, MaxInt);
      var Slash := Pos('/', OrgIdStr);
      if Slash > 0 then OrgIdStr := Copy(OrgIdStr, 1, Slash-1);
      var OrgId := StrToIntDef(OrgIdStr, 0);
      if OrgId = 0 then begin JSONError(400, 'Invalid organization id'); Exit; end;

      // Extract display id between /displays/ and /unpair
      var Tail := Copy(NormalizedPath, Pos('/displays/', NormalizedPath) + Length('/displays/'), MaxInt);
      var UnpairPos := Pos('/unpair', Tail);
      if UnpairPos <= 1 then begin JSONError(400, 'Invalid display id'); Exit; end;
      var DisplayIdStr := Copy(Tail, 1, UnpairPos-1);
      var DisplayId := StrToIntDef(DisplayIdStr, 0);
      if DisplayId <= 0 then begin JSONError(400, 'Invalid display id'); Exit; end;

      var TokOrg, TokUser: Integer; var TokRole: string;
      if not RequireAuth(['displays:write'], TokOrg, TokUser, TokRole) then Exit;
      if TokOrg <> OrgId then begin JSONError(403, 'Forbidden'); Exit; end;
      if TryReplayIdempotency(OrgId) then Exit;

      var C := NewConnection;
      try
        C.StartTransaction;
        try
          // Load existing token + hardware id (and confirm org ownership)
          var ExistingToken := '';
          var ExistingHw := '';
          var QGet := TFDQuery.Create(nil);
          try
            QGet.Connection := C;
            QGet.SQL.Text :=
              'select d.ProvisioningToken, pt.HardwareId '
              + 'from Displays d '
              + 'left join ProvisioningTokens pt on pt.Token = d.ProvisioningToken '
              + 'where d.DisplayID=:D and d.OrganizationID=:Org for update';
            QGet.ParamByName('D').AsInteger := DisplayId;
            QGet.ParamByName('Org').AsInteger := OrgId;
            QGet.Open;
            if QGet.Eof then begin C.Rollback; JSONError(404, 'Not found'); Exit; end;
            ExistingToken := Trim(QGet.FieldByName('ProvisioningToken').AsString);
            ExistingHw := Trim(QGet.FieldByName('HardwareId').AsString);
          finally
            QGet.Free;
          end;

          // If token is known but HardwareId isn't available from ProvisioningTokens, resolve from historical events
          if (ExistingToken <> '') and (ExistingHw = '') then
          begin
            var QHw := TFDQuery.Create(nil);
            try
              QHw.Connection := C;
              QHw.SQL.Text := 'select HardwareId from ProvisioningTokenEvents where Token=:T and HardwareId<>'''' order by Id desc limit 1';
              QHw.ParamByName('T').AsString := ExistingToken;
              QHw.Open;
              if (not QHw.Eof) then ExistingHw := Trim(QHw.FieldByName('HardwareId').AsString);
            finally
              QHw.Free;
            end;
          end;

          // Always clear display token (idempotent)
          var QClr := TFDQuery.Create(nil);
          try
            QClr.Connection := C;
            QClr.SQL.Text := 'update Displays set ProvisioningToken=null, UpdatedAt=now() where DisplayID=:D and OrganizationID=:Org';
            QClr.ParamByName('D').AsInteger := DisplayId;
            QClr.ParamByName('Org').AsInteger := OrgId;
            QClr.ExecSQL;
          finally
            QClr.Free;
          end;

          // If there was a token, detach it so device heartbeats fail (Not linked)
          if ExistingToken <> '' then
          begin
            var QTok := TFDQuery.Create(nil);
            try
              QTok.Connection := C;
              QTok.SQL.Text := 'update ProvisioningTokens set DisplayID=null, OrganizationID=null where Token=:T';
              QTok.ParamByName('T').AsString := ExistingToken;
              QTok.ExecSQL;
            finally
              QTok.Free;
            end;
          end;

          C.Commit;

          // Log token lifecycle event (account-side)
          if ExistingToken <> '' then
          begin
            var Ev := TJSONObject.Create;
            try
              Ev.AddPair('Reason', 'manual_unpair');

              // Snapshot assignment counts + related content counts
              var C2 := NewConnection;
              try
                var QCnt := TFDQuery.Create(nil);
                try
                  QCnt.Connection := C2;
                  QCnt.SQL.Text :=
                    'select '
                    + '  (select count(1) from DisplayCampaigns where DisplayID=:D) as CampaignAssignments, '
                    + '  (select count(1) from DisplayMenus where DisplayID=:D) as MenuAssignments, '
                    + '  (select count(distinct ci.MediaFileID) '
                    + '     from DisplayCampaigns dc '
                    + '     join CampaignItems ci on ci.CampaignID=dc.CampaignID '
                    + '     where dc.DisplayID=:D and ci.ItemType=''media'' and ci.MediaFileID is not null) as MediaFilesDistinct, '
                    + '  (select count(distinct ci.MenuID) '
                    + '     from DisplayCampaigns dc '
                    + '     join CampaignItems ci on ci.CampaignID=dc.CampaignID '
                    + '     where dc.DisplayID=:D and ci.ItemType=''menu'' and ci.MenuID is not null) as MenusInCampaignsDistinct';
                  QCnt.ParamByName('D').AsInteger := DisplayId;
                  QCnt.Open;
                  Ev.AddPair('CampaignAssignments', TJSONNumber.Create(QCnt.FieldByName('CampaignAssignments').AsInteger));
                  Ev.AddPair('MenuAssignments', TJSONNumber.Create(QCnt.FieldByName('MenuAssignments').AsInteger));
                  Ev.AddPair('MediaFilesDistinct', TJSONNumber.Create(QCnt.FieldByName('MediaFilesDistinct').AsInteger));
                  Ev.AddPair('MenusInCampaignsDistinct', TJSONNumber.Create(QCnt.FieldByName('MenusInCampaignsDistinct').AsInteger));
                finally
                  QCnt.Free;
                end;
              finally
                C2.Free;
              end;

              TProvisioningTokenEventRepository.WriteEvent(ExistingToken, 'unpaired', ExistingHw, DisplayId, OrgId, TokUser, Ev, RequestId, ClientIp, UserAgent);
            finally
              Ev.Free;
            end;
          end;

          var Obj := TJSONObject.Create;
          try
            Obj.AddPair('Success', TJSONBool.Create(True));
            Obj.AddPair('DisplayId', TJSONNumber.Create(DisplayId));
            if ExistingToken <> '' then Obj.AddPair('ProvisioningToken', ExistingToken) else Obj.AddPair('ProvisioningToken', TJSONNull.Create);
            var OutBody := Obj.ToJSON;
            StoreIdempotency(OrgId, 200, OutBody);
            Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := OutBody; Response.SendResponse;
          finally
            Obj.Free;
          end;
        except
          on E: Exception do
          begin
            try C.Rollback; except end;
            JSONError(500, 'Unpair failed: ' + E.Message, 'unpair_failed');
          end;
        end;
      finally
        C.Free;
      end;
      Exit;
    end;

    // Device pairing: device asks for a short pairing code (shown on screen)
    if (SameText(Request.PathInfo, '/device/provisioning/token') or SameText(Request.PathInfo, '/api/device/provisioning/token')) and SameText(Request.Method,'POST') then
    begin
      var Body := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject; try
        if Body=nil then begin JSONError(400,'Invalid JSON'); Exit; end;
        var HardwareId := Body.GetValue<string>('HardwareId',''); if HardwareId='' then begin JSONError(400,'Missing HardwareId'); Exit; end;
        // 6-char code for manual pairing on the website. TTL is long enough to avoid frustration during onboarding.
        var Info := TProvisioningTokenRepository.CreatePairingCode(3600, 6);
        // Optionally store hardware id, and clean up old unclaimed tokens for this device
        var C := NewConnection; try
          // Delete any old unclaimed tokens for this HardwareId (prevents stale pairing codes)
          var QDel := TFDQuery.Create(nil); try
            QDel.Connection := C;
            QDel.SQL.Text := 'delete from ProvisioningTokens where HardwareId=:H and Claimed=false';
            QDel.ParamByName('H').AsString := HardwareId;
            QDel.ExecSQL;
          finally QDel.Free; end;
          var Q := TFDQuery.Create(nil); try
            Q.Connection := C; Q.SQL.Text := 'update ProvisioningTokens set HardwareId=:H where Token=:T';
            Q.ParamByName('H').AsString := HardwareId; Q.ParamByName('T').AsString := Info.Token; Q.ExecSQL;
          finally Q.Free; end;
        finally C.Free; end;

        // Token lifecycle event (device-side)
        var Ev := TJSONObject.Create;
        try
          Ev.AddPair('TtlSeconds', TJSONNumber.Create(3600));
          Ev.AddPair('CodeLength', TJSONNumber.Create(6));
          TProvisioningTokenEventRepository.WriteEvent(Info.Token, 'issued', HardwareId, 0, 0, 0, Ev, RequestId, ClientIp, UserAgent);
        finally
          Ev.Free;
        end;

        var Obj := TJSONObject.Create; 
        Obj.AddPair('ProvisioningToken', Info.Token);
        Obj.AddPair('PairingCode', Info.Token);
        Obj.AddPair('ExpiresInSeconds', TJSONNumber.Create(3600));
        Obj.AddPair('Instructions', 'Enter this code on the DisplayDeck website to add/pair this display.');
        Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := Obj.ToJSON; Response.SendResponse; Obj.Free;
      finally Body.Free; end;
      Exit;
    end;

    // Device pairing: device polls for claim status (no user input on device)
    if (SameText(Request.PathInfo, '/device/provisioning/status') or SameText(Request.PathInfo, '/api/device/provisioning/status')) and SameText(Request.Method,'POST') then
    begin
      var Body := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject; try
        if Body=nil then begin JSONError(400,'Invalid JSON'); Exit; end;
        var HardwareId := Body.GetValue<string>('HardwareId',''); if HardwareId='' then begin JSONError(400,'Missing HardwareId'); Exit; end;
        var ProvisioningToken := Body.GetValue<string>('ProvisioningToken',''); if ProvisioningToken='' then begin JSONError(400,'Missing ProvisioningToken'); Exit; end;

        var C := NewConnection; try
          var Q := TFDQuery.Create(nil); try
            Q.Connection := C;
            Q.SQL.Text :=
              'select pt.Claimed, pt.ExpiresAt, pt.DisplayID, d.Name as DisplayName, d.Orientation as DisplayOrientation, d.OrganizationID ' +
              'from ProvisioningTokens pt ' +
              'left join Displays d on d.DisplayID = pt.DisplayID ' +
              'where pt.Token=:T and pt.HardwareId=:H';
            Q.ParamByName('T').AsString := ProvisioningToken;
            Q.ParamByName('H').AsString := HardwareId;
            Q.Open;
            if Q.Eof then begin JSONError(404,'Not found'); Exit; end;

            // Expired tokens are treated as gone.
            if Q.FieldByName('ExpiresAt').AsDateTime <= Now then begin JSONError(410,'Expired'); Exit; end;

            var Claimed := Q.FieldByName('Claimed').AsBoolean;
            var Obj := TJSONObject.Create;
            try
              if Claimed then
                Obj.AddPair('Status', 'Claimed')
              else
                Obj.AddPair('Status', 'Pending');
              Obj.AddPair('Claimed', TJSONBool.Create(Claimed));

              if Claimed and (not Q.FieldByName('DisplayID').IsNull) then
              begin
                var DObj := TJSONObject.Create;
                DObj.AddPair('Id', TJSONNumber.Create(Q.FieldByName('DisplayID').AsInteger));
                DObj.AddPair('OrganizationId', TJSONNumber.Create(Q.FieldByName('OrganizationID').AsInteger));
                DObj.AddPair('Name', Q.FieldByName('DisplayName').AsString);
                DObj.AddPair('Orientation', Q.FieldByName('DisplayOrientation').AsString);
                Obj.AddPair('Display', DObj);
              end;

              Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := Obj.ToJSON; Response.SendResponse;
            finally
              Obj.Free;
            end;
          finally Q.Free; end;
        finally C.Free; end;
      finally Body.Free; end;
      Exit;
    end;

    // Device heartbeat + config: device reports liveness and receives what to display
    if (SameText(Request.PathInfo, '/device/heartbeat') or SameText(Request.PathInfo, '/api/device/heartbeat')) and SameText(Request.Method,'POST') then
    begin
      var Body := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject;
      try
        if Body=nil then begin JSONError(400,'Invalid JSON'); Exit; end;
        var HardwareId := Body.GetValue<string>('HardwareId',''); if HardwareId='' then begin JSONError(400,'Missing HardwareId'); Exit; end;
        var ProvisioningToken := Body.GetValue<string>('ProvisioningToken',''); if ProvisioningToken='' then begin JSONError(400,'Missing ProvisioningToken'); Exit; end;
        var AppVersion := Body.GetValue<string>('AppVersion','');
        var DeviceInfoVal := Body.GetValue('DeviceInfo');
        var DeviceInfoJson := '';
        if (DeviceInfoVal<>nil) and (not (DeviceInfoVal is TJSONNull)) then DeviceInfoJson := DeviceInfoVal.ToJSON;

        var C := NewConnection;
        try
          // Validate token belongs to this hardware and is claimed.
          var QTok := TFDQuery.Create(nil);
          try
            QTok.Connection := C;
            QTok.SQL.Text := 'select Claimed, ExpiresAt, DisplayID from ProvisioningTokens where Token=:T and HardwareId=:H';
            QTok.ParamByName('T').AsString := ProvisioningToken;
            QTok.ParamByName('H').AsString := HardwareId;
            QTok.Open;
            if QTok.Eof then
            begin
              var Ev := TJSONObject.Create;
              try
                Ev.AddPair('Reason', 'not_found');
                TProvisioningTokenEventRepository.WriteEvent(ProvisioningToken, 'heartbeat_rejected', HardwareId, 0, 0, 0, Ev, RequestId, ClientIp, UserAgent);
              finally
                Ev.Free;
              end;
              JSONError(404,'Not found');
              Exit;
            end;
            var ClaimedTok := QTok.FieldByName('Claimed').AsBoolean;
            // Provisioning tokens are short-lived during pairing, but once claimed we treat them
            // as a long-lived device credential to keep the device zero-input.
            if (not ClaimedTok) and (QTok.FieldByName('ExpiresAt').AsDateTime <= Now) then
            begin
              var Ev := TJSONObject.Create;
              try
                Ev.AddPair('Reason', 'expired');
                TProvisioningTokenEventRepository.WriteEvent(ProvisioningToken, 'heartbeat_rejected', HardwareId, 0, 0, 0, Ev, RequestId, ClientIp, UserAgent);
              finally
                Ev.Free;
              end;
              JSONError(410,'Expired');
              Exit;
            end;
            if not ClaimedTok then
            begin
              var Ev := TJSONObject.Create;
              try
                Ev.AddPair('Reason', 'not_claimed');
                TProvisioningTokenEventRepository.WriteEvent(ProvisioningToken, 'heartbeat_rejected', HardwareId, 0, 0, 0, Ev, RequestId, ClientIp, UserAgent);
              finally
                Ev.Free;
              end;
              JSONError(409,'Not claimed');
              Exit;
            end;
            if QTok.FieldByName('DisplayID').IsNull then
            begin
              var Ev := TJSONObject.Create;
              try
                Ev.AddPair('Reason', 'not_linked');
                TProvisioningTokenEventRepository.WriteEvent(ProvisioningToken, 'heartbeat_rejected', HardwareId, 0, 0, 0, Ev, RequestId, ClientIp, UserAgent);
              finally
                Ev.Free;
              end;
              JSONError(409,'Not linked');
              Exit;
            end;

            var DisplayId := QTok.FieldByName('DisplayID').AsInteger;

            // Detect first successful heartbeat
            var OrgIdForEvent := 0;
            var IsFirstHeartbeat := False;
            var QState := TFDQuery.Create(nil);
            try
              QState.Connection := C;
              QState.SQL.Text := 'select OrganizationID, LastHeartbeatAt from Displays where DisplayID=:D';
              QState.ParamByName('D').AsInteger := DisplayId;
              QState.Open;
              if not QState.Eof then
              begin
                OrgIdForEvent := QState.FieldByName('OrganizationID').AsInteger;
                IsFirstHeartbeat := QState.FieldByName('LastHeartbeatAt').IsNull;
              end;
            finally
              QState.Free;
            end;

            // Update heartbeat/status fields
            var Qu := TFDQuery.Create(nil);
            try
              Qu.Connection := C;
              Qu.SQL.Text := 'update Displays set LastSeen=now(), CurrentStatus=''Online'', LastHeartbeatAt=now(), AppVersion=:V, DeviceInfo=:DI::jsonb, LastIp=:IP, UpdatedAt=now() where DisplayID=:D';
              Qu.ParamByName('V').AsString := AppVersion;
              if Trim(DeviceInfoJson)='' then
                Qu.ParamByName('DI').AsString := '{}'
              else
                Qu.ParamByName('DI').AsString := DeviceInfoJson;
              Qu.ParamByName('IP').AsString := ClientIp;
              Qu.ParamByName('D').AsInteger := DisplayId;
              Qu.ExecSQL;
            finally
              Qu.Free;
            end;

            // Determine current assignment: prefer primary campaign; else primary menu; else primary infoboard.
            var AssignType := 'none';
            var MenuToken := '';
            var CampaignId := 0;
            var InfoBoardToken := '';

            var Qc := TFDQuery.Create(nil);
            try
              Qc.Connection := C;
              Qc.SQL.Text := 'select CampaignID from DisplayCampaigns where DisplayID=:D and IsPrimary=true order by DisplayCampaignID desc limit 1';
              Qc.ParamByName('D').AsInteger := DisplayId;
              Qc.Open;
              if not Qc.Eof then
              begin
                AssignType := 'campaign';
                CampaignId := Qc.FieldByName('CampaignID').AsInteger;
              end;
            finally
              Qc.Free;
            end;

            if AssignType='none' then
            begin
              var Qm := TFDQuery.Create(nil);
              try
                Qm.Connection := C;
                Qm.SQL.Text := 'select m.PublicToken from DisplayMenus dm join Menus m on m.MenuID=dm.MenuID where dm.DisplayID=:D and dm.IsPrimary=true order by dm.DisplayMenuID desc limit 1';
                Qm.ParamByName('D').AsInteger := DisplayId;
                Qm.Open;
                if not Qm.Eof then
                begin
                  AssignType := 'menu';
                  MenuToken := Qm.FieldByName('PublicToken').AsString;
                end;
              finally
                Qm.Free;
              end;
            end;

            if AssignType='none' then
            begin
              var Qib := TFDQuery.Create(nil);
              try
                Qib.Connection := C;
                Qib.SQL.Text := 'select ib.PublicToken from DisplayInfoBoards dib join InfoBoards ib on ib.InfoBoardID=dib.InfoBoardID where dib.DisplayID=:D and dib.IsPrimary=true order by dib.DisplayInfoBoardID desc limit 1';
                Qib.ParamByName('D').AsInteger := DisplayId;
                Qib.Open;
                if not Qib.Eof then
                begin
                  AssignType := 'infoboard';
                  InfoBoardToken := Qib.FieldByName('PublicToken').AsString;
                end;
              finally
                Qib.Free;
              end;
            end;

            if IsFirstHeartbeat then
            begin
              // Snapshot assignment counts + related content counts
              var Ev := TJSONObject.Create;
              try
                Ev.AddPair('AssignmentType', AssignType);
                if CampaignId > 0 then Ev.AddPair('PrimaryCampaignId', TJSONNumber.Create(CampaignId)) else Ev.AddPair('PrimaryCampaignId', TJSONNull.Create);
                if MenuToken <> '' then Ev.AddPair('PrimaryMenuPublicToken', MenuToken) else Ev.AddPair('PrimaryMenuPublicToken', TJSONNull.Create);

                var QCnt := TFDQuery.Create(nil);
                try
                  QCnt.Connection := C;
                  QCnt.SQL.Text :=
                    'select '
                    + '  (select count(1) from DisplayCampaigns where DisplayID=:D) as CampaignAssignments, '
                    + '  (select count(1) from DisplayMenus where DisplayID=:D) as MenuAssignments, '
                    + '  (select count(distinct ci.MediaFileID) '
                    + '     from DisplayCampaigns dc '
                    + '     join CampaignItems ci on ci.CampaignID=dc.CampaignID '
                    + '     where dc.DisplayID=:D and ci.ItemType=''media'' and ci.MediaFileID is not null) as MediaFilesDistinct, '
                    + '  (select count(distinct ci.MenuID) '
                    + '     from DisplayCampaigns dc '
                    + '     join CampaignItems ci on ci.CampaignID=dc.CampaignID '
                    + '     where dc.DisplayID=:D and ci.ItemType=''menu'' and ci.MenuID is not null) as MenusInCampaignsDistinct';
                  QCnt.ParamByName('D').AsInteger := DisplayId;
                  QCnt.Open;
                  Ev.AddPair('CampaignAssignments', TJSONNumber.Create(QCnt.FieldByName('CampaignAssignments').AsInteger));
                  Ev.AddPair('MenuAssignments', TJSONNumber.Create(QCnt.FieldByName('MenuAssignments').AsInteger));
                  Ev.AddPair('MediaFilesDistinct', TJSONNumber.Create(QCnt.FieldByName('MediaFilesDistinct').AsInteger));
                  Ev.AddPair('MenusInCampaignsDistinct', TJSONNumber.Create(QCnt.FieldByName('MenusInCampaignsDistinct').AsInteger));
                finally
                  QCnt.Free;
                end;

                TProvisioningTokenEventRepository.WriteEvent(ProvisioningToken, 'first_heartbeat_ok', HardwareId, DisplayId, OrgIdForEvent, 0, Ev, RequestId, ClientIp, UserAgent);
              finally
                Ev.Free;
              end;
            end;

            var Qd := TFDQuery.Create(nil);
            try
              Qd.Connection := C;
              Qd.SQL.Text := 'select DisplayID, OrganizationID, Name, Orientation, ProvisioningToken from Displays where DisplayID=:D';
              Qd.ParamByName('D').AsInteger := DisplayId;
              Qd.Open;
              if Qd.Eof then begin JSONError(404,'Display not found'); Exit; end;

              var OutObj := TJSONObject.Create;
              try
                var DObj := TJSONObject.Create;
                DObj.AddPair('Id', TJSONNumber.Create(Qd.FieldByName('DisplayID').AsInteger));
                DObj.AddPair('OrganizationId', TJSONNumber.Create(Qd.FieldByName('OrganizationID').AsInteger));
                DObj.AddPair('Name', Qd.FieldByName('Name').AsString);
                DObj.AddPair('Orientation', Qd.FieldByName('Orientation').AsString);
                DObj.AddPair('ProvisioningToken', Qd.FieldByName('ProvisioningToken').AsString);
                OutObj.AddPair('Display', DObj);

                var AObj := TJSONObject.Create;
                AObj.AddPair('Type', AssignType);
                if (AssignType='menu') and (MenuToken<>'') then
                  AObj.AddPair('MenuPublicToken', MenuToken)
                else
                  AObj.AddPair('MenuPublicToken', TJSONNull.Create);
                if (AssignType='campaign') and (CampaignId>0) then
                  AObj.AddPair('CampaignId', TJSONNumber.Create(CampaignId))
                else
                  AObj.AddPair('CampaignId', TJSONNull.Create);
                if (AssignType='infoboard') and (InfoBoardToken<>'') then
                  AObj.AddPair('InfoBoardPublicToken', InfoBoardToken)
                else
                  AObj.AddPair('InfoBoardPublicToken', TJSONNull.Create);
                OutObj.AddPair('Assignment', AObj);

                Response.StatusCode := 200; Response.ContentType := 'application/json';
                Response.Content := OutObj.ToJSON; Response.SendResponse;
              finally
                OutObj.Free;
              end;
            finally
              Qd.Free;
            end;
          finally
            QTok.Free;
          end;
        finally
          C.Free;
        end;
      finally
        Body.Free;
      end;
      Exit;
    end;

    // Device: fetch a campaign manifest for playback on-device.
    // POST /device/campaign/manifest
    // Body: { HardwareId, ProvisioningToken, CampaignId }
    if (SameText(Request.PathInfo, '/device/campaign/manifest') or SameText(Request.PathInfo, '/api/device/campaign/manifest')) and SameText(Request.Method,'POST') then
    begin
      var Body := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject;
      try
        if Body=nil then begin JSONError(400,'Invalid JSON'); Exit; end;
        var HardwareId := Body.GetValue<string>('HardwareId',''); if HardwareId='' then begin JSONError(400,'Missing HardwareId'); Exit; end;
        var ProvisioningToken := Body.GetValue<string>('ProvisioningToken',''); if ProvisioningToken='' then begin JSONError(400,'Missing ProvisioningToken'); Exit; end;
        var CampaignId := Body.GetValue<Integer>('CampaignId',0); if CampaignId<=0 then begin JSONError(400,'Missing CampaignId'); Exit; end;

        var C := NewConnection;
        try
          // Validate token belongs to this hardware and is claimed.
          var DisplayId := 0;
          var QTok := TFDQuery.Create(nil);
          try
            QTok.Connection := C;
            QTok.SQL.Text := 'select Claimed, ExpiresAt, DisplayID from ProvisioningTokens where Token=:T and HardwareId=:H';
            QTok.ParamByName('T').AsString := ProvisioningToken;
            QTok.ParamByName('H').AsString := HardwareId;
            QTok.Open;
            if QTok.Eof then begin JSONError(404,'Not found'); Exit; end;
            var ClaimedTok := QTok.FieldByName('Claimed').AsBoolean;
            if (not ClaimedTok) and (QTok.FieldByName('ExpiresAt').AsDateTime <= Now) then begin JSONError(410,'Expired'); Exit; end;
            if not ClaimedTok then begin JSONError(409,'Not claimed'); Exit; end;
            if QTok.FieldByName('DisplayID').IsNull then begin JSONError(409,'Not linked'); Exit; end;
            DisplayId := QTok.FieldByName('DisplayID').AsInteger;
          finally
            QTok.Free;
          end;

          // Ensure this campaign is actually assigned to this display (primary).
          var QAsn := TFDQuery.Create(nil);
          try
            QAsn.Connection := C;
            QAsn.SQL.Text := 'select 1 from DisplayCampaigns where DisplayID=:D and CampaignID=:C and IsPrimary=true limit 1';
            QAsn.ParamByName('D').AsInteger := DisplayId;
            QAsn.ParamByName('C').AsInteger := CampaignId;
            QAsn.Open;
            if QAsn.Eof then begin JSONError(404,'Not assigned'); Exit; end;
          finally
            QAsn.Free;
          end;

          // Presign helper (GET) for media items.
          var InternalEndpoint := GetEnv('MINIO_ENDPOINT','http://minio:9000');
          var PublicEndpoint := GetEnv('MINIO_PUBLIC_ENDPOINT','');
          if PublicEndpoint = '' then
          begin
            var ReqProto := Request.GetFieldByName('X-Forwarded-Proto');
            if ReqProto = '' then ReqProto := 'http';
            var ReqHost := Request.GetFieldByName('X-Forwarded-Host');
            if ReqHost = '' then ReqHost := Request.GetFieldByName('Host');
            if ReqHost <> '' then PublicEndpoint := ReqProto + '://' + ReqHost + '/minio';
          end;
          if PublicEndpoint = '' then PublicEndpoint := InternalEndpoint;

          var Access := GetEnv('MINIO_ACCESS_KEY','minioadmin');
          var Secret := GetEnv('MINIO_SECRET_KEY','minioadmin');
          var Region := GetEnv('MINIO_REGION','us-east-1');

          var Q := TFDQuery.Create(nil);
          try
            Q.Connection := C;
            Q.SQL.Text :=
              'select ci.ItemType, ci.DisplayOrder, ci.Duration, ci.MediaFileID, ci.MenuID, ' +
              'mf.StorageURL as MediaStorageURL, mf.FileType as MediaFileType, ' +
              'm.PublicToken as MenuPublicToken ' +
              'from CampaignItems ci ' +
              'left join MediaFiles mf on mf.MediaFileID=ci.MediaFileID ' +
              'left join Menus m on m.MenuID=ci.MenuID ' +
              'where ci.CampaignID=:C ' +
              'order by ci.DisplayOrder, ci.CampaignItemID';
            Q.ParamByName('C').AsInteger := CampaignId;
            Q.Open;

            var OutObj := TJSONObject.Create;
            try
              OutObj.AddPair('CampaignId', TJSONNumber.Create(CampaignId));
              var ItemsArr := TJSONArray.Create;
              OutObj.AddPair('Items', ItemsArr);

              while not Q.Eof do
              begin
                var ItObj := TJSONObject.Create;
                var ItemType := Trim(Q.FieldByName('ItemType').AsString);
                if ItemType='' then ItemType := 'media';
                ItObj.AddPair('Type', LowerCase(ItemType));
                ItObj.AddPair('DisplayOrder', TJSONNumber.Create(Q.FieldByName('DisplayOrder').AsInteger));
                ItObj.AddPair('Duration', TJSONNumber.Create(Q.FieldByName('Duration').AsInteger));

                if SameText(ItemType,'menu') then
                begin
                  var Tok := Q.FieldByName('MenuPublicToken').AsString;
                  if Tok<>'' then ItObj.AddPair('MenuPublicToken', Tok) else ItObj.AddPair('MenuPublicToken', TJSONNull.Create);
                end
                else
                begin
                  if not Q.FieldByName('MediaFileID').IsNull then
                    ItObj.AddPair('MediaFileId', TJSONNumber.Create(Q.FieldByName('MediaFileID').AsInteger))
                  else
                    ItObj.AddPair('MediaFileId', TJSONNull.Create);
                  var Ft := Q.FieldByName('MediaFileType').AsString;
                  if Ft<>'' then ItObj.AddPair('FileType', Ft) else ItObj.AddPair('FileType', TJSONNull.Create);
                  var Dl := '';
                  if TryPresignS3GetUrlFromStorageUrl(Q.FieldByName('MediaStorageURL').AsString, PublicEndpoint, InternalEndpoint, Access, Secret, Region, Dl) and (Dl<>'') then
                    ItObj.AddPair('DownloadUrl', Dl)
                  else
                    ItObj.AddPair('DownloadUrl', TJSONNull.Create);
                end;

                ItemsArr.AddElement(ItObj);
                Q.Next;
              end;

              Response.StatusCode := 200;
              Response.ContentType := 'application/json';
              Response.Content := OutObj.ToJSON;
              Response.SendResponse;
            finally
              OutObj.Free;
            end;
          finally
            Q.Free;
          end;
        finally
          C.Free;
        end;
      finally
        Body.Free;
      end;
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
        var ProvisioningToken := Trim(Body.GetValue<string>('ProvisioningToken',''));
        if ProvisioningToken='' then begin JSONError(400,'Missing ProvisioningToken'); Exit; end;
        // Defensive normalization: codes are uppercase A-Z/2-9; strip whitespace.
        ProvisioningToken := UpperCase(ProvisioningToken);

        var Name := Body.GetValue<string>('Name','New Display');
        var Orientation := Body.GetValue<string>('Orientation','Landscape');

        var C := NewConnection;
        try
          C.StartTransaction;
          try
            var ClaimHardwareId := '';
            // Lock the token row so claim + create display is consistent.
            var QTok := TFDQuery.Create(nil);
            try
              QTok.Connection := C;
              QTok.SQL.Text := 'select Claimed, ExpiresAt, HardwareId from ProvisioningTokens where Token=:T for update';
              QTok.ParamByName('T').AsString := ProvisioningToken;
              QTok.Open;
              if QTok.Eof then begin C.Rollback; JSONError(404,'Token not found','token_not_found'); Exit; end;

              // If the token is unclaimed but expired, treat it as gone.
              if (not QTok.FieldByName('Claimed').AsBoolean) and (QTok.FieldByName('ExpiresAt').AsDateTime <= Now) then
              begin
                C.Rollback;
                JSONError(410,'Token expired','token_expired');
                Exit;
              end;

              if QTok.FieldByName('Claimed').AsBoolean then
              begin
                C.Rollback;
                JSONError(409,'Token already claimed','token_claimed');
                Exit;
              end;

              // Require that the token was actually issued to a device (via /device/provisioning/token).
              var Hw := Trim(QTok.FieldByName('HardwareId').AsString);
              if Hw = '' then
              begin
                C.Rollback;
                JSONError(400,'Token not issued to a device','token_not_issued');
                Exit;
              end;
              ClaimHardwareId := Hw;
            finally
              QTok.Free;
            end;

            // Claim token
            var QClaim := TFDQuery.Create(nil);
            try
              QClaim.Connection := C;
              QClaim.SQL.Text := 'update ProvisioningTokens set Claimed=true where Token=:T and Claimed=false and ExpiresAt > now()';
              QClaim.ParamByName('T').AsString := ProvisioningToken;
              QClaim.ExecSQL;
              if QClaim.RowsAffected = 0 then
              begin
                C.Rollback;
                JSONError(409,'Token already claimed','token_claimed');
                Exit;
              end;
            finally
              QClaim.Free;
            end;

            // Create display (same DB transaction)
            var QIns := TFDQuery.Create(nil);
            var DisplayId: Integer;
            try
              QIns.Connection := C;
              QIns.SQL.Text := 'insert into Displays (OrganizationID, Name, Orientation) values (:Org,:Name,:Orient) returning DisplayID, Name, Orientation';
              QIns.ParamByName('Org').AsInteger := OrgId;
              QIns.ParamByName('Name').AsString := Name;
              QIns.ParamByName('Orient').AsString := Orientation;
              QIns.Open;
              if QIns.Eof then
              begin
                C.Rollback;
                JSONError(500,'Failed to create display','display_create_failed');
                Exit;
              end;
              DisplayId := QIns.FieldByName('DisplayID').AsInteger;
            finally
              QIns.Free;
            end;

            // Link token -> display/org
            var U := TFDQuery.Create(nil);
            try
              U.Connection := C;
              U.SQL.Text := 'update ProvisioningTokens set DisplayID=:D, OrganizationID=:O where Token=:T';
              U.ParamByName('D').AsInteger := DisplayId;
              U.ParamByName('O').AsInteger := OrgId;
              U.ParamByName('T').AsString := ProvisioningToken;
              U.ExecSQL;
            finally
              U.Free;
            end;

            // Store token against the display as a convenience for device heartbeat lookup
            var U2 := TFDQuery.Create(nil);
            try
              U2.Connection := C;
              U2.SQL.Text := 'update Displays set ProvisioningToken=:T, UpdatedAt=now() where DisplayID=:D';
              U2.ParamByName('T').AsString := ProvisioningToken;
              U2.ParamByName('D').AsInteger := DisplayId;
              U2.ExecSQL;
            finally
              U2.Free;
            end;

            C.Commit;

            // Audit: pairing/claiming a display token
            var Details := TJSONObject.Create;
            try
              Details.AddPair('ProvisioningToken', ProvisioningToken);
              if ClaimHardwareId <> '' then Details.AddPair('HardwareId', ClaimHardwareId) else Details.AddPair('HardwareId', TJSONNull.Create);
              Details.AddPair('Name', Name);
              Details.AddPair('Orientation', Orientation);
              TAuditLogRepository.WriteEvent(OrgId, TokUser, 'display.pair', 'display', IntToStr(DisplayId), Details, RequestId, ClientIp, UserAgent);
            finally
              Details.Free;
            end;

            // Token lifecycle event (account-side)
            var Ev := TJSONObject.Create;
            try
              Ev.AddPair('Name', Name);
              Ev.AddPair('Orientation', Orientation);
              TProvisioningTokenEventRepository.WriteEvent(ProvisioningToken, 'claimed', ClaimHardwareId, DisplayId, OrgId, TokUser, Ev, RequestId, ClientIp, UserAgent);
            finally
              Ev.Free;
            end;

            var Obj := TJSONObject.Create;
            Obj.AddPair('Id', TJSONNumber.Create(DisplayId));
            Obj.AddPair('Name', Name);
            Obj.AddPair('Orientation', Orientation);
            var OutBody := Obj.ToJSON;
            Obj.Free;
            StoreIdempotency(OrgId, 200, OutBody);
            Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := OutBody; Response.SendResponse;
          except
            on E: Exception do
            begin
              try C.Rollback; except end;
              JSONError(500, 'Pairing failed: ' + E.Message, 'pairing_failed');
            end;
          end;
        finally
          C.Free;
        end;
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

    // Organization menus: /organizations/{OrganizationId}/menus
    if (Copy(NormalizedPath, 1, 15) = '/organizations/') and
       (Pos('/menus', NormalizedPath) > 0) then
    begin
      var OrgIdStr := Copy(NormalizedPath, 16, MaxInt);
      var Slash := Pos('/', OrgIdStr); if Slash>0 then OrgIdStr := Copy(OrgIdStr, 1, Slash-1);
      var OrgId := StrToIntDef(OrgIdStr,0); if OrgId=0 then begin JSONError(400,'Invalid organization id'); Exit; end;

      if SameText(Request.Method,'GET') then
      begin
        var TokOrg, TokUser: Integer; var TokRole: string;
        if not RequireAuth(['campaigns:read'], TokOrg, TokUser, TokRole) then Exit;
        if TokOrg<>OrgId then begin JSONError(403,'Forbidden'); Exit; end;
        var L := TMenuRepository.ListByOrganization(OrgId);
        try
          var Arr := TJSONArray.Create; try
            for var M in L do
            begin
              var O := TJSONObject.Create;
              O.AddPair('Id', TJSONNumber.Create(M.Id));
              O.AddPair('OrganizationId', TJSONNumber.Create(M.OrganizationId));
              O.AddPair('Name', M.Name);
              O.AddPair('Orientation', M.Orientation);
              O.AddPair('TemplateKey', M.TemplateKey);
              O.AddPair('PublicToken', M.PublicToken);
              var Theme := TJSONObject.ParseJSONValue(M.ThemeConfigJson);
              if Theme=nil then Theme := TJSONObject.Create;
              O.AddPair('ThemeConfig', Theme);
              Arr.AddElement(O);
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
        var TokOrg, TokUser: Integer; var TokRole: string;
        if not RequireAuth(['campaigns:write'], TokOrg, TokUser, TokRole) then Exit;
        if TokOrg<>OrgId then begin JSONError(403,'Forbidden'); Exit; end;
        if TryReplayIdempotency(OrgId) then Exit;
        var Body := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject;
        try
          if Body=nil then begin JSONError(400,'Invalid JSON'); Exit; end;
          var Name := Body.GetValue<string>('Name','');
          var Orientation := Body.GetValue<string>('Orientation','');
          var TemplateKey := Body.GetValue<string>('TemplateKey','');
          var ThemeVal := Body.GetValue('ThemeConfig');
          var ThemeJson := '{}';
          if (ThemeVal<>nil) and (not (ThemeVal is TJSONNull)) then ThemeJson := ThemeVal.ToJSON;
          if Name='' then begin JSONError(400,'Missing Name'); Exit; end;
          if Orientation='' then Orientation := 'Landscape';
          if TemplateKey='' then TemplateKey := 'classic';
          var PublicToken := TGUID.NewGuid.ToString.Replace('{','').Replace('}','').Replace('-','');
          var M := TMenuRepository.CreateMenu(OrgId, Name, Orientation, TemplateKey, ThemeJson, PublicToken);
          try
            var O := TJSONObject.Create;
            O.AddPair('Id', TJSONNumber.Create(M.Id));
            O.AddPair('OrganizationId', TJSONNumber.Create(M.OrganizationId));
            O.AddPair('Name', M.Name);
            O.AddPair('Orientation', M.Orientation);
            O.AddPair('TemplateKey', M.TemplateKey);
            O.AddPair('PublicToken', M.PublicToken);
            var Theme := TJSONObject.ParseJSONValue(M.ThemeConfigJson);
            if Theme=nil then Theme := TJSONObject.Create;
            O.AddPair('ThemeConfig', Theme);
            var OutBody := O.ToJSON;
            O.Free;
            StoreIdempotency(OrgId, 201, OutBody);
            Response.StatusCode := 201; Response.ContentType := 'application/json'; Response.Content := OutBody; Response.SendResponse;
          finally M.Free; end;
        finally Body.Free; end;
        Exit;
      end;
    end;

    // Public menu JSON: /public/menus/{token}
    // NOTE: exclude nested routes like /public/menus/{token}/media-files/{id}/download-url
    if (Copy(NormalizedPath, 1, 14) = '/public/menus/') and (Pos('/media-files/', NormalizedPath) = 0) and SameText(Request.Method,'GET') then
    begin
      var Token := Copy(NormalizedPath, 15, MaxInt);
      if Token='' then begin JSONError(400,'Missing token'); Exit; end;
      var M := TMenuRepository.GetByPublicToken(Token);
      if M=nil then begin JSONError(404,'Not found'); Exit; end;
      try
        var Root := TJSONObject.Create;
        Root.AddPair('Id', TJSONNumber.Create(M.Id));
        Root.AddPair('Name', M.Name);
        Root.AddPair('Orientation', M.Orientation);
        Root.AddPair('TemplateKey', M.TemplateKey);
        var Theme := TJSONObject.ParseJSONValue(M.ThemeConfigJson);
        if Theme=nil then Theme := TJSONObject.Create;
        Root.AddPair('ThemeConfig', Theme);

        var SectionsArr := TJSONArray.Create;
        var Secs := TMenuSectionRepository.ListByMenu(M.Id);
        try
          for var S in Secs do
          begin
            var SO := TJSONObject.Create;
            SO.AddPair('Id', TJSONNumber.Create(S.Id));
            SO.AddPair('Name', S.Name);
            SO.AddPair('DisplayOrder', TJSONNumber.Create(S.DisplayOrder));

            var ItemsArr := TJSONArray.Create;
            var Items := TMenuItemRepository.ListBySection(S.Id);
            try
              for var It in Items do
              begin
                var IO := TJSONObject.Create;
                IO.AddPair('Id', TJSONNumber.Create(It.Id));
                IO.AddPair('Name', It.Name);
                if Trim(It.Sku)<>'' then IO.AddPair('Sku', It.Sku) else IO.AddPair('Sku', TJSONNull.Create);
                if Trim(It.Description)<>'' then IO.AddPair('Description', It.Description) else IO.AddPair('Description', TJSONNull.Create);
                if Trim(It.ImageUrl)<>'' then IO.AddPair('ImageUrl', It.ImageUrl) else IO.AddPair('ImageUrl', TJSONNull.Create);
                if It.HasPriceCents then IO.AddPair('PriceCents', TJSONNumber.Create(It.PriceCents)) else IO.AddPair('PriceCents', TJSONNull.Create);
                IO.AddPair('IsAvailable', TJSONBool.Create(It.IsAvailable));
                IO.AddPair('DisplayOrder', TJSONNumber.Create(It.DisplayOrder));
                ItemsArr.AddElement(IO);
              end;
            finally Items.Free; end;
            SO.AddPair('Items', ItemsArr);
            SectionsArr.AddElement(SO);
          end;
        finally Secs.Free; end;

        Root.AddPair('Sections', SectionsArr);
        Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := Root.ToJSON; Response.SendResponse;
        Root.Free;
        Exit;
      finally M.Free; end;
    end;

    // Menus CRUD: /menus/{id}
    // NOTE: exclude /menus/{id}/display-assignments so the bulk assignment handler can process it.
    if (Copy(NormalizedPath, 1, 7) = '/menus/') and (Pos('/display-assignments', NormalizedPath) = 0) then
    begin
      var Tail := Copy(NormalizedPath, 8, MaxInt);
      var Slash := Pos('/', Tail);
      var IdStr := Tail; if Slash>0 then IdStr := Copy(Tail,1,Slash-1);
      var MenuId := StrToIntDef(IdStr,0); if MenuId=0 then begin JSONError(400,'Invalid menu id'); Exit; end;

      // /menus/{id}/duplicate
      if Pos('/duplicate', NormalizedPath) > 0 then
      begin
        var M0 := TMenuRepository.GetById(MenuId);
        if M0=nil then begin JSONError(404,'Not found'); Exit; end;
        try
          var TokOrg, TokUser: Integer; var TokRole: string;
          if not RequireAuth(['campaigns:write'], TokOrg, TokUser, TokRole) then Exit;
          if TokOrg<>M0.OrganizationId then begin JSONError(403,'Forbidden'); Exit; end;
          if not SameText(Request.Method,'POST') then begin JSONError(405,'Method not allowed'); Exit; end;
          if TryReplayIdempotency(M0.OrganizationId) then Exit;

          var NewName := M0.Name + ' (Copy)';
          var Body: TJSONObject := nil;
          if Trim(Request.Content)<>'' then
            Body := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject;
          try
            if Body<>nil then
            begin
              var NameFromBody := Body.GetValue<string>('Name','');
              if Trim(NameFromBody)<>'' then NewName := NameFromBody;
            end;
          finally
            if Body<>nil then Body.Free;
          end;

          var PublicToken := TGUID.NewGuid.ToString.Replace('{','').Replace('}','').Replace('-','');
          var NewMenu := TMenuRepository.CreateMenu(M0.OrganizationId, NewName, M0.Orientation, M0.TemplateKey, M0.ThemeConfigJson, PublicToken);
          try
            var Secs := TMenuSectionRepository.ListByMenu(M0.Id);
            try
              for var S in Secs do
              begin
                var NewSec := TMenuSectionRepository.CreateSection(NewMenu.Id, S.Name, S.DisplayOrder);
                try
                  var Items := TMenuItemRepository.ListBySection(S.Id);
                  try
                    for var It in Items do
                    begin
                      var NewItem := TMenuItemRepository.CreateItem(NewSec.Id, It.Name, It.Sku, It.Description, It.ImageUrl, It.PriceCents, It.HasPriceCents, It.IsAvailable, It.DisplayOrder);
                      NewItem.Free;
                    end;
                  finally Items.Free; end;
                finally NewSec.Free; end;
              end;
            finally Secs.Free; end;

            var O := TJSONObject.Create;
            O.AddPair('Id', TJSONNumber.Create(NewMenu.Id));
            O.AddPair('OrganizationId', TJSONNumber.Create(NewMenu.OrganizationId));
            O.AddPair('Name', NewMenu.Name);
            O.AddPair('Orientation', NewMenu.Orientation);
            O.AddPair('TemplateKey', NewMenu.TemplateKey);
            O.AddPair('PublicToken', NewMenu.PublicToken);
            var Theme := TJSONObject.ParseJSONValue(NewMenu.ThemeConfigJson);
            if Theme=nil then Theme := TJSONObject.Create;
            O.AddPair('ThemeConfig', Theme);
            var OutBody := O.ToJSON;
            O.Free;
            StoreIdempotency(M0.OrganizationId, 201, OutBody);
            Response.StatusCode := 201; Response.ContentType := 'application/json'; Response.Content := OutBody; Response.SendResponse;
            Exit;
          finally NewMenu.Free; end;
        finally M0.Free; end;
      end;

      // /menus/{id}/sections
      if Pos('/sections', NormalizedPath) > 0 then
      begin
        var M0 := TMenuRepository.GetById(MenuId);
        if M0=nil then begin JSONError(404,'Not found'); Exit; end;
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
          if TokOrg<>M0.OrganizationId then begin JSONError(403,'Forbidden'); Exit; end;

          if SameText(Request.Method,'GET') then
          begin
            var L := TMenuSectionRepository.ListByMenu(MenuId);
            try
              var Arr := TJSONArray.Create; try
                for var S in L do
                begin
                  var O := TJSONObject.Create;
                  O.AddPair('Id', TJSONNumber.Create(S.Id));
                  O.AddPair('MenuId', TJSONNumber.Create(S.MenuId));
                  O.AddPair('Name', S.Name);
                  O.AddPair('DisplayOrder', TJSONNumber.Create(S.DisplayOrder));
                  Arr.AddElement(O);
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
            if TryReplayIdempotency(M0.OrganizationId) then Exit;
            var Body := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject;
            try
              if Body=nil then begin JSONError(400,'Invalid JSON'); Exit; end;
              var Name := Body.GetValue<string>('Name','');
              var DisplayOrder := Body.GetValue<Integer>('DisplayOrder',0);
              if Name='' then begin JSONError(400,'Missing Name'); Exit; end;
              var S := TMenuSectionRepository.CreateSection(MenuId, Name, DisplayOrder);
              try
                var O := TJSONObject.Create;
                O.AddPair('Id', TJSONNumber.Create(S.Id));
                O.AddPair('MenuId', TJSONNumber.Create(S.MenuId));
                O.AddPair('Name', S.Name);
                O.AddPair('DisplayOrder', TJSONNumber.Create(S.DisplayOrder));
                var OutBody := O.ToJSON;
                O.Free;
                StoreIdempotency(M0.OrganizationId, 201, OutBody);
                Response.StatusCode := 201; Response.ContentType := 'application/json'; Response.Content := OutBody; Response.SendResponse;
              finally S.Free; end;
            finally Body.Free; end;
            Exit;
          end;

        finally M0.Free; end;
      end
      else
      begin
        var M0 := TMenuRepository.GetById(MenuId);
        if M0=nil then begin JSONError(404,'Not found'); Exit; end;
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
          if TokOrg<>M0.OrganizationId then begin JSONError(403,'Forbidden'); Exit; end;

          if SameText(Request.Method,'GET') then
          begin
            var O := TJSONObject.Create;
            O.AddPair('Id', TJSONNumber.Create(M0.Id));
            O.AddPair('OrganizationId', TJSONNumber.Create(M0.OrganizationId));
            O.AddPair('Name', M0.Name);
            O.AddPair('Orientation', M0.Orientation);
            O.AddPair('TemplateKey', M0.TemplateKey);
            O.AddPair('PublicToken', M0.PublicToken);
            var Theme := TJSONObject.ParseJSONValue(M0.ThemeConfigJson);
            if Theme=nil then Theme := TJSONObject.Create;
            O.AddPair('ThemeConfig', Theme);
            Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := O.ToJSON; Response.SendResponse; O.Free;
            Exit;
          end
          else if SameText(Request.Method,'PUT') then
          begin
            var Body := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject;
            try
              if Body=nil then begin JSONError(400,'Invalid JSON'); Exit; end;
              var Name := Body.GetValue<string>('Name','');
              var Orientation := Body.GetValue<string>('Orientation','');
              var TemplateKey := Body.GetValue<string>('TemplateKey','');
              var ThemeVal := Body.GetValue('ThemeConfig');
              var ThemeJson := '{}';
              if (ThemeVal<>nil) and (not (ThemeVal is TJSONNull)) then ThemeJson := ThemeVal.ToJSON;
              if Name='' then begin JSONError(400,'Missing Name'); Exit; end;
              if Orientation='' then Orientation := M0.Orientation;
              if TemplateKey='' then TemplateKey := M0.TemplateKey;
              var M := TMenuRepository.UpdateMenu(MenuId, Name, Orientation, TemplateKey, ThemeJson);
              if M=nil then begin JSONError(404,'Not found'); Exit; end;
              try
                var O := TJSONObject.Create;
                O.AddPair('Id', TJSONNumber.Create(M.Id));
                O.AddPair('OrganizationId', TJSONNumber.Create(M.OrganizationId));
                O.AddPair('Name', M.Name);
                O.AddPair('Orientation', M.Orientation);
                O.AddPair('TemplateKey', M.TemplateKey);
                O.AddPair('PublicToken', M.PublicToken);
                var Theme := TJSONObject.ParseJSONValue(M.ThemeConfigJson);
                if Theme=nil then Theme := TJSONObject.Create;
                O.AddPair('ThemeConfig', Theme);
                Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := O.ToJSON; Response.SendResponse; O.Free;
              finally M.Free; end;
            finally Body.Free; end;
            Exit;
          end
          else if SameText(Request.Method,'DELETE') then
          begin
            TMenuRepository.DeleteMenu(MenuId);
            Response.StatusCode := 204; Response.ContentType := 'application/json'; Response.Content := ''; Response.SendResponse;
            Exit;
          end;

        finally M0.Free; end;
      end;
    end;

    // Menu sections: /menu-sections/{id}
    if (Copy(NormalizedPath, 1, 15) = '/menu-sections/') then
    begin
      var Tail := Copy(NormalizedPath, 16, MaxInt);
      var Slash := Pos('/', Tail);
      var IdStr := Tail; if Slash>0 then IdStr := Copy(Tail,1,Slash-1);
      var SecId := StrToIntDef(IdStr,0); if SecId=0 then begin JSONError(400,'Invalid menu section id'); Exit; end;

      // /menu-sections/{id}/items
      if Pos('/items', NormalizedPath) > 0 then
      begin
        var S0 := TMenuSectionRepository.GetById(SecId);
        if S0=nil then begin JSONError(404,'Not found'); Exit; end;
        var M0 := TMenuRepository.GetById(S0.MenuId);
        if M0=nil then begin S0.Free; JSONError(404,'Not found'); Exit; end;
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
          if TokOrg<>M0.OrganizationId then begin JSONError(403,'Forbidden'); Exit; end;

          if SameText(Request.Method,'GET') then
          begin
            var L := TMenuItemRepository.ListBySection(SecId);
            try
              var Arr := TJSONArray.Create; try
                for var It in L do
                begin
                  var O := TJSONObject.Create;
                  O.AddPair('Id', TJSONNumber.Create(It.Id));
                  O.AddPair('MenuSectionId', TJSONNumber.Create(It.MenuSectionId));
                  O.AddPair('Name', It.Name);
                  if Trim(It.Sku)<>'' then O.AddPair('Sku', It.Sku) else O.AddPair('Sku', TJSONNull.Create);
                  if Trim(It.Description)<>'' then O.AddPair('Description', It.Description) else O.AddPair('Description', TJSONNull.Create);
                  if Trim(It.ImageUrl)<>'' then O.AddPair('ImageUrl', It.ImageUrl) else O.AddPair('ImageUrl', TJSONNull.Create);
                  if It.HasPriceCents then O.AddPair('PriceCents', TJSONNumber.Create(It.PriceCents)) else O.AddPair('PriceCents', TJSONNull.Create);
                  O.AddPair('IsAvailable', TJSONBool.Create(It.IsAvailable));
                  O.AddPair('DisplayOrder', TJSONNumber.Create(It.DisplayOrder));
                  Arr.AddElement(O);
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
            if TryReplayIdempotency(M0.OrganizationId) then Exit;
            var Body := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject;
            try
              if Body=nil then begin JSONError(400,'Invalid JSON'); Exit; end;
              var Name := Body.GetValue<string>('Name','');

              var SkuVal := Body.GetValue('Sku');
              var Sku := '';
              if (SkuVal<>nil) and (not (SkuVal is TJSONNull)) then
                Sku := SkuVal.Value;

              var Desc := '';
              var DescVal := Body.GetValue('Description');
              if (DescVal<>nil) and (not (DescVal is TJSONNull)) then
                Desc := DescVal.Value;

              var ImgVal := Body.GetValue('ImageUrl');
              var Img := '';
              if (ImgVal<>nil) and (not (ImgVal is TJSONNull)) then
                Img := ImgVal.Value;

              var PriceVal := Body.GetValue('PriceCents');
              var HasPrice := (PriceVal<>nil) and (not (PriceVal is TJSONNull));
              var PriceCents := 0;
              if HasPrice then PriceCents := StrToIntDef(PriceVal.Value,0);
              var IsAvailable := Body.GetValue<Boolean>('IsAvailable', True);
              var DisplayOrder := Body.GetValue<Integer>('DisplayOrder',0);
              if Name='' then begin JSONError(400,'Missing Name'); Exit; end;
              var It := TMenuItemRepository.CreateItem(SecId, Name, Sku, Desc, Img, PriceCents, HasPrice, IsAvailable, DisplayOrder);
              try
                var O := TJSONObject.Create;
                O.AddPair('Id', TJSONNumber.Create(It.Id));
                O.AddPair('MenuSectionId', TJSONNumber.Create(It.MenuSectionId));
                O.AddPair('Name', It.Name);
                if Trim(It.Sku)<>'' then O.AddPair('Sku', It.Sku) else O.AddPair('Sku', TJSONNull.Create);
                if Trim(It.Description)<>'' then O.AddPair('Description', It.Description) else O.AddPair('Description', TJSONNull.Create);
                if Trim(It.ImageUrl)<>'' then O.AddPair('ImageUrl', It.ImageUrl) else O.AddPair('ImageUrl', TJSONNull.Create);
                if It.HasPriceCents then O.AddPair('PriceCents', TJSONNumber.Create(It.PriceCents)) else O.AddPair('PriceCents', TJSONNull.Create);
                O.AddPair('IsAvailable', TJSONBool.Create(It.IsAvailable));
                O.AddPair('DisplayOrder', TJSONNumber.Create(It.DisplayOrder));
                var OutBody := O.ToJSON;
                O.Free;
                StoreIdempotency(M0.OrganizationId, 201, OutBody);
                Response.StatusCode := 201; Response.ContentType := 'application/json'; Response.Content := OutBody; Response.SendResponse;
              finally It.Free; end;
            finally Body.Free; end;
            Exit;
          end;

        finally
          M0.Free;
          S0.Free;
        end;
      end
      else
      begin
        var S0 := TMenuSectionRepository.GetById(SecId);
        if S0=nil then begin JSONError(404,'Not found'); Exit; end;
        var M0 := TMenuRepository.GetById(S0.MenuId);
        if M0=nil then begin S0.Free; JSONError(404,'Not found'); Exit; end;
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
          if TokOrg<>M0.OrganizationId then begin JSONError(403,'Forbidden'); Exit; end;

          if SameText(Request.Method,'GET') then
          begin
            var O := TJSONObject.Create;
            O.AddPair('Id', TJSONNumber.Create(S0.Id));
            O.AddPair('MenuId', TJSONNumber.Create(S0.MenuId));
            O.AddPair('Name', S0.Name);
            O.AddPair('DisplayOrder', TJSONNumber.Create(S0.DisplayOrder));
            Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := O.ToJSON; Response.SendResponse; O.Free;
            Exit;
          end
          else if SameText(Request.Method,'PUT') then
          begin
            var Body := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject;
            try
              if Body=nil then begin JSONError(400,'Invalid JSON'); Exit; end;
              var Name := Body.GetValue<string>('Name','');
              var DisplayOrder := Body.GetValue<Integer>('DisplayOrder',0);
              if Name='' then begin JSONError(400,'Missing Name'); Exit; end;
              var S := TMenuSectionRepository.UpdateSection(SecId, Name, DisplayOrder);
              if S=nil then begin JSONError(404,'Not found'); Exit; end;
              try
                var O := TJSONObject.Create;
                O.AddPair('Id', TJSONNumber.Create(S.Id));
                O.AddPair('MenuId', TJSONNumber.Create(S.MenuId));
                O.AddPair('Name', S.Name);
                O.AddPair('DisplayOrder', TJSONNumber.Create(S.DisplayOrder));
                Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := O.ToJSON; Response.SendResponse; O.Free;
              finally S.Free; end;
            finally Body.Free; end;
            Exit;
          end
          else if SameText(Request.Method,'DELETE') then
          begin
            TMenuSectionRepository.DeleteSection(SecId);
            Response.StatusCode := 204; Response.ContentType := 'application/json'; Response.Content := ''; Response.SendResponse;
            Exit;
          end;

        finally
          M0.Free;
          S0.Free;
        end;
      end;
    end;

    // Menu items: /menu-items/{id}
    if (Copy(NormalizedPath, 1, 12) = '/menu-items/') then
    begin
      var IdStr := Copy(NormalizedPath, 13, MaxInt);
      var Id := StrToIntDef(IdStr,0); if Id=0 then begin JSONError(400,'Invalid menu item id'); Exit; end;
      var It0 := TMenuItemRepository.GetById(Id);
      if It0=nil then begin JSONError(404,'Not found'); Exit; end;
      var S0 := TMenuSectionRepository.GetById(It0.MenuSectionId);
      if S0=nil then begin It0.Free; JSONError(404,'Not found'); Exit; end;
      var M0 := TMenuRepository.GetById(S0.MenuId);
      if M0=nil then begin It0.Free; S0.Free; JSONError(404,'Not found'); Exit; end;
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
        if TokOrg<>M0.OrganizationId then begin JSONError(403,'Forbidden'); Exit; end;

        if SameText(Request.Method,'GET') then
        begin
          var O := TJSONObject.Create;
          O.AddPair('Id', TJSONNumber.Create(It0.Id));
          O.AddPair('MenuSectionId', TJSONNumber.Create(It0.MenuSectionId));
          O.AddPair('Name', It0.Name);
          if Trim(It0.Sku)<>'' then O.AddPair('Sku', It0.Sku) else O.AddPair('Sku', TJSONNull.Create);
          if Trim(It0.Description)<>'' then O.AddPair('Description', It0.Description) else O.AddPair('Description', TJSONNull.Create);
          if Trim(It0.ImageUrl)<>'' then O.AddPair('ImageUrl', It0.ImageUrl) else O.AddPair('ImageUrl', TJSONNull.Create);
          if It0.HasPriceCents then O.AddPair('PriceCents', TJSONNumber.Create(It0.PriceCents)) else O.AddPair('PriceCents', TJSONNull.Create);
          O.AddPair('IsAvailable', TJSONBool.Create(It0.IsAvailable));
          O.AddPair('DisplayOrder', TJSONNumber.Create(It0.DisplayOrder));
          Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := O.ToJSON; Response.SendResponse; O.Free;
          Exit;
        end
        else if SameText(Request.Method,'PUT') then
        begin
          var Body := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject;
          try
            if Body=nil then begin JSONError(400,'Invalid JSON'); Exit; end;
            var Name := Body.GetValue<string>('Name','');

            var SkuVal := Body.GetValue('Sku');
            var Sku := '';
            if (SkuVal<>nil) and (not (SkuVal is TJSONNull)) then
              Sku := SkuVal.Value;

            var Desc := '';
            var DescVal := Body.GetValue('Description');
            if (DescVal<>nil) and (not (DescVal is TJSONNull)) then
              Desc := DescVal.Value;

            var ImgVal := Body.GetValue('ImageUrl');
            var Img := '';
            if (ImgVal<>nil) and (not (ImgVal is TJSONNull)) then
              Img := ImgVal.Value;

            var PriceVal := Body.GetValue('PriceCents');
            var HasPrice := (PriceVal<>nil) and (not (PriceVal is TJSONNull));
            var PriceCents := 0;
            if HasPrice then PriceCents := StrToIntDef(PriceVal.Value,0);
            var IsAvailable := Body.GetValue<Boolean>('IsAvailable', True);
            var DisplayOrder := Body.GetValue<Integer>('DisplayOrder',0);
            if Name='' then begin JSONError(400,'Missing Name'); Exit; end;
            var It := TMenuItemRepository.UpdateItem(Id, Name, Sku, Desc, Img, PriceCents, HasPrice, IsAvailable, DisplayOrder);
            if It=nil then begin JSONError(404,'Not found'); Exit; end;
            try
              var O := TJSONObject.Create;
              O.AddPair('Id', TJSONNumber.Create(It.Id));
              O.AddPair('MenuSectionId', TJSONNumber.Create(It.MenuSectionId));
              O.AddPair('Name', It.Name);
              if Trim(It.Sku)<>'' then O.AddPair('Sku', It.Sku) else O.AddPair('Sku', TJSONNull.Create);
              if Trim(It.Description)<>'' then O.AddPair('Description', It.Description) else O.AddPair('Description', TJSONNull.Create);
              if Trim(It.ImageUrl)<>'' then O.AddPair('ImageUrl', It.ImageUrl) else O.AddPair('ImageUrl', TJSONNull.Create);
              if It.HasPriceCents then O.AddPair('PriceCents', TJSONNumber.Create(It.PriceCents)) else O.AddPair('PriceCents', TJSONNull.Create);
              O.AddPair('IsAvailable', TJSONBool.Create(It.IsAvailable));
              O.AddPair('DisplayOrder', TJSONNumber.Create(It.DisplayOrder));
              Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := O.ToJSON; Response.SendResponse; O.Free;
            finally It.Free; end;
          finally Body.Free; end;
          Exit;
        end
        else if SameText(Request.Method,'DELETE') then
        begin
          TMenuItemRepository.DeleteItem(Id);
          Response.StatusCode := 204; Response.ContentType := 'application/json'; Response.Content := ''; Response.SendResponse;
          Exit;
        end;

      finally
        M0.Free;
        S0.Free;
        It0.Free;
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
      else if Pos('/menu-assignments', NormalizedPath) > 0 then
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
            var L := TDisplayMenuRepository.ListByDisplay(Id);
            try
              var Arr := TJSONArray.Create;
              try
                for var A in L do
                begin
                  var It := TJSONObject.Create;
                  It.AddPair('Id', TJSONNumber.Create(A.Id));
                  It.AddPair('MenuId', TJSONNumber.Create(A.MenuId));
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
              var MenuId := Body.GetValue<Integer>('MenuId',0);
              var IsPrimary := Body.GetValue<Boolean>('IsPrimary',True);
              if MenuId=0 then begin JSONError(400,'Missing MenuId'); Exit; end;

              // Enforce orientation match
              var M := TMenuRepository.GetById(MenuId);
              if M=nil then begin JSONError(404,'Menu not found'); Exit; end;
              try
                if (M.Orientation<>'') and (Disp.Orientation<>'') and (not SameText(M.Orientation, Disp.Orientation)) then
                begin
                  JSONError(400, 'Menu orientation does not match display orientation');
                  Exit;
                end;
              finally
                M.Free;
              end;

              var A := TDisplayMenuRepository.CreateAssignment(Id, MenuId, IsPrimary);
              try
                var Obj := TJSONObject.Create;
                Obj.AddPair('Id', TJSONNumber.Create(A.Id));
                Obj.AddPair('MenuId', TJSONNumber.Create(A.MenuId));
                Obj.AddPair('IsPrimary', TJSONBool.Create(A.IsPrimary));
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
          var TokOrg, TokUser: Integer; var TokRole: string;
          try
            if not RequireAuth(['displays:write'], TokOrg, TokUser, TokRole) then Exit;
            if TokOrg<>D.OrganizationId then begin JSONError(403,'Forbidden'); Exit; end;
            // Capture details before delete (for audit trail)
            var C := NewConnection;
            try
              var Details := TJSONObject.Create;
              try
                if D.ProvisioningToken <> '' then Details.AddPair('ProvisioningToken', D.ProvisioningToken) else Details.AddPair('ProvisioningToken', TJSONNull.Create);
                if D.AppVersion <> '' then Details.AddPair('AppVersion', D.AppVersion) else Details.AddPair('AppVersion', TJSONNull.Create);
                if D.LastHeartbeatAt > 0 then Details.AddPair('LastHeartbeatAt', DateToISO8601(D.LastHeartbeatAt, True)) else Details.AddPair('LastHeartbeatAt', TJSONNull.Create);
                if D.DeviceInfoJson <> '' then
                begin
                  var Parsed := TJSONObject.ParseJSONValue(D.DeviceInfoJson);
                  if Assigned(Parsed) then
                    Details.AddPair('DeviceInfo', Parsed)
                  else
                    Details.AddPair('DeviceInfo', TJSONNull.Create);
                end
                else
                  Details.AddPair('DeviceInfo', TJSONNull.Create);

                // Try resolve HardwareId from ProvisioningTokens
                var HwForEvent := '';
                if D.ProvisioningToken <> '' then
                begin
                  var QHw := TFDQuery.Create(nil);
                  try
                    QHw.Connection := C;
                    QHw.SQL.Text := 'select HardwareId from ProvisioningTokens where Token=:T';
                    QHw.ParamByName('T').AsString := D.ProvisioningToken;
                    QHw.Open;
                    if (not QHw.Eof) and (Trim(QHw.FieldByName('HardwareId').AsString) <> '') then
                    begin
                      HwForEvent := Trim(QHw.FieldByName('HardwareId').AsString);
                      Details.AddPair('HardwareId', HwForEvent);
                    end
                    else
                      Details.AddPair('HardwareId', TJSONNull.Create);
                  finally
                    QHw.Free;
                  end;

                  // Fallback to historical events if not currently in ProvisioningTokens
                  if (HwForEvent = '') then
                  begin
                    var QHw2 := TFDQuery.Create(nil);
                    try
                      QHw2.Connection := C;
                      QHw2.SQL.Text := 'select HardwareId from ProvisioningTokenEvents where Token=:T and HardwareId<>'''' order by Id desc limit 1';
                      QHw2.ParamByName('T').AsString := D.ProvisioningToken;
                      QHw2.Open;
                      if (not QHw2.Eof) and (Trim(QHw2.FieldByName('HardwareId').AsString) <> '') then
                      begin
                        HwForEvent := Trim(QHw2.FieldByName('HardwareId').AsString);
                        Details.RemovePair('HardwareId');
                        Details.AddPair('HardwareId', HwForEvent);
                      end;
                    finally
                      QHw2.Free;
                    end;
                  end;
                end
                else
                  Details.AddPair('HardwareId', TJSONNull.Create);

                // Snapshot assignment counts (helps explain impact)
                var QCnt := TFDQuery.Create(nil);
                try
                  QCnt.Connection := C;
                  QCnt.SQL.Text :=
                    'select '
                    + '  (select count(1) from DisplayCampaigns where DisplayID=:D) as CampaignAssignments, '
                    + '  (select count(1) from DisplayMenus where DisplayID=:D) as MenuAssignments';
                  QCnt.ParamByName('D').AsInteger := D.Id;
                  QCnt.Open;
                  Details.AddPair('CampaignAssignments', TJSONNumber.Create(QCnt.FieldByName('CampaignAssignments').AsInteger));
                  Details.AddPair('MenuAssignments', TJSONNumber.Create(QCnt.FieldByName('MenuAssignments').AsInteger));
                finally
                  QCnt.Free;
                end;

                TAuditLogRepository.WriteEvent(D.OrganizationId, TokUser, 'display.delete', 'display', IntToStr(D.Id), Details, RequestId, ClientIp, UserAgent);

                // Token lifecycle event (account-side)
                if D.ProvisioningToken <> '' then
                  TProvisioningTokenEventRepository.WriteEvent(D.ProvisioningToken, 'display_deleted', HwForEvent, D.Id, D.OrganizationId, TokUser, Details, RequestId, ClientIp, UserAgent);

                // Also emit a generic unpair event (so dashboards can filter only unpairs)
                if D.ProvisioningToken <> '' then
                begin
                  var Ev2 := TJSONObject.Create;
                  try
                    Ev2.AddPair('Reason', 'display_deleted');
                    TProvisioningTokenEventRepository.WriteEvent(D.ProvisioningToken, 'unpaired', HwForEvent, D.Id, D.OrganizationId, TokUser, Ev2, RequestId, ClientIp, UserAgent);
                  finally
                    Ev2.Free;
                  end;
                end;
              finally
                Details.Free;
              end;
            finally
              C.Free;
            end;
          finally
            D.Free;
          end;
          TDisplayRepository.DeleteDisplay(Id);
          Response.StatusCode := 204; Response.ContentType := 'application/json'; Response.Content := ''; Response.SendResponse; Exit;
        end;
      end;
    end;

    // Menu assignment CRUD (by assignment id): /menu-assignments/{id}
    if (Copy(NormalizedPath, 1, 18) = '/menu-assignments/') then
    begin
      var IdStr := Copy(NormalizedPath, 19, MaxInt);
      var Id := StrToIntDef(IdStr,0); if Id=0 then begin JSONError(400,'Invalid assignment id'); Exit; end;
      var A0 := TDisplayMenuRepository.GetById(Id);
      if A0=nil then begin JSONError(404,'Not found'); Exit; end;
      var D0 := TDisplayRepository.GetById(A0.DisplayId);
      if D0=nil then begin A0.Free; JSONError(404,'Not found'); Exit; end;
      try
        var TokOrg, TokUser: Integer; var TokRole: string;
        if not RequireAuth(['assignments:write'], TokOrg, TokUser, TokRole) then Exit;
        if TokOrg<>D0.OrganizationId then begin JSONError(403,'Forbidden'); Exit; end;

        if SameText(Request.Method,'PUT') then
        begin
          var Body := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject;
          try
            if Body=nil then begin JSONError(400,'Invalid JSON'); Exit; end;
            var IsPrimary := Body.GetValue<Boolean>('IsPrimary', True);
            var A := TDisplayMenuRepository.UpdateAssignment(Id, IsPrimary); if A=nil then begin JSONError(404,'Not found'); Exit; end;
            try
              var O := TJSONObject.Create;
              O.AddPair('Id', TJSONNumber.Create(A.Id));
              O.AddPair('DisplayId', TJSONNumber.Create(A.DisplayId));
              O.AddPair('MenuId', TJSONNumber.Create(A.MenuId));
              O.AddPair('IsPrimary', TJSONBool.Create(A.IsPrimary));
              Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := O.ToJSON; Response.SendResponse; O.Free;
            finally A.Free; end;
          finally Body.Free; end;
          Exit;
        end
        else if SameText(Request.Method,'DELETE') then
        begin
          TDisplayMenuRepository.DeleteAssignment(Id);
          Response.StatusCode := 204; Response.ContentType := 'application/json'; Response.Content := ''; Response.SendResponse; Exit;
        end;
      finally
        D0.Free;
        A0.Free;
      end;
    end;

    // Bulk: list/replace campaign assignments for a campaign: /campaigns/{id}/display-assignments
    if (Copy(NormalizedPath, 1, 11) = '/campaigns/') and (Pos('/display-assignments', NormalizedPath) > 0) then
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
          if not RequireAuth(['assignments:read'], TokOrg, TokUser, TokRole) then Exit;
        end
        else
        begin
          if not RequireAuth(['assignments:write'], TokOrg, TokUser, TokRole) then Exit;
        end;
        if TokOrg<>Camp.OrganizationId then begin JSONError(403,'Forbidden'); Exit; end;

        var C := NewConnection;
        try
          if SameText(Request.Method,'GET') then
          begin
            var Q := TFDQuery.Create(nil);
            try
              Q.Connection := C;
              Q.SQL.Text := 'select DisplayCampaignID, DisplayID, IsPrimary from DisplayCampaigns where CampaignID=:C order by DisplayCampaignID';
              Q.ParamByName('C').AsInteger := CampId;
              Q.Open;
              var Arr := TJSONArray.Create;
              try
                while not Q.Eof do
                begin
                  var O := TJSONObject.Create;
                  O.AddPair('Id', TJSONNumber.Create(Q.FieldByName('DisplayCampaignID').AsInteger));
                  O.AddPair('DisplayId', TJSONNumber.Create(Q.FieldByName('DisplayID').AsInteger));
                  O.AddPair('IsPrimary', TJSONBool.Create(Q.FieldByName('IsPrimary').AsBoolean));
                  Arr.AddElement(O);
                  Q.Next;
                end;
                var Root := TJSONObject.Create; try
                  Root.AddPair('value', Arr);
                  Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := Root.ToJSON; Response.SendResponse;
                finally Root.Free; end;
              finally Arr.Free; end;
            finally Q.Free; end;
            Exit;
          end
          else if SameText(Request.Method,'PUT') then
          begin
            if TryReplayIdempotency(Camp.OrganizationId) then Exit;
            var Body := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject;
            try
              if Body=nil then begin JSONError(400,'Invalid JSON'); Exit; end;
              var DisplayIdsVal := Body.GetValue('DisplayIds');
              if (DisplayIdsVal=nil) or (not (DisplayIdsVal is TJSONArray)) then begin JSONError(400,'Missing DisplayIds'); Exit; end;
              var SetPrimary := Body.GetValue<Boolean>('SetPrimary', True);

              // Remove assignments for displays not in the new set
              var Csv := '';
              for var v in (DisplayIdsVal as TJSONArray) do
              begin
                var did := StrToIntDef(v.Value,0);
                if did>0 then
                begin
                  if Csv<>'' then Csv := Csv + ',';
                  Csv := Csv + IntToStr(did);
                end;
              end;

              var QDel := TFDQuery.Create(nil);
              try
                QDel.Connection := C;
                // Replace full set for this campaign (avoids relying on UNIQUE/ON CONFLICT constraints)
                QDel.SQL.Text := 'delete from DisplayCampaigns where CampaignID=:C';
                QDel.ParamByName('C').AsInteger := CampId;
                QDel.ExecSQL;
              finally QDel.Free; end;

              // Upsert assignments for the new set
              if Csv<>'' then
              begin
                var QIns := TFDQuery.Create(nil);
                try
                  QIns.Connection := C;
                  QIns.SQL.Text :=
                    'insert into DisplayCampaigns (DisplayID, CampaignID, IsPrimary) ' +
                    'select distinct d.DisplayID, :C as CampaignID, :P as IsPrimary ' +
                    'from Displays d ' +
                    'join unnest(string_to_array(:Ids,'','')) as x on d.DisplayID = x::int ' +
                    'where d.OrganizationID = :Org';
                  QIns.ParamByName('C').AsInteger := CampId;
                  QIns.ParamByName('P').AsBoolean := SetPrimary;
                  QIns.ParamByName('Ids').AsString := Csv;
                  QIns.ParamByName('Org').AsInteger := Camp.OrganizationId;
                  QIns.ExecSQL;
                finally QIns.Free; end;

                // Enforce: a display can have either campaigns OR menus assigned.
                // When assigning a campaign, remove any menu assignments for those displays.
                var QClearMenus := TFDQuery.Create(nil);
                try
                  QClearMenus.Connection := C;
                  QClearMenus.SQL.Text :=
                    'delete from DisplayMenus dm using Displays d ' +
                    'where dm.DisplayID = d.DisplayID ' +
                    'and d.OrganizationID = :Org ' +
                    'and dm.DisplayID = any(string_to_array(:Ids,'','')::int[])';
                  QClearMenus.ParamByName('Org').AsInteger := Camp.OrganizationId;
                  QClearMenus.ParamByName('Ids').AsString := Csv;
                  QClearMenus.ExecSQL;
                finally QClearMenus.Free; end;

                if SetPrimary then
                begin
                  // Clear other primaries on those displays and set this campaign primary.
                  var Qp := TFDQuery.Create(nil);
                  try
                    Qp.Connection := C;
                    Qp.SQL.Text :=
                      'update DisplayCampaigns dc set IsPrimary=false ' +
                      'from Displays d ' +
                      'where dc.DisplayID = d.DisplayID ' +
                      'and d.OrganizationID = :Org ' +
                      'and dc.DisplayID = any(string_to_array(:Ids,'','')::int[]) ' +
                      'and dc.CampaignID<>:C';
                    Qp.ParamByName('Ids').AsString := Csv;
                    Qp.ParamByName('C').AsInteger := CampId;
                    Qp.ParamByName('Org').AsInteger := Camp.OrganizationId;
                    Qp.ExecSQL;
                    Qp.SQL.Text :=
                      'update DisplayCampaigns dc set IsPrimary=true ' +
                      'from Displays d ' +
                      'where dc.DisplayID = d.DisplayID ' +
                      'and d.OrganizationID = :Org ' +
                      'and dc.DisplayID = any(string_to_array(:Ids,'','')::int[]) ' +
                      'and dc.CampaignID=:C';
                    Qp.ExecSQL;
                  finally Qp.Free; end;
                end;
              end;

              Response.StatusCode := 204; Response.ContentType := 'application/json'; Response.Content := ''; Response.SendResponse;
            finally Body.Free; end;
            Exit;
          end;
        finally C.Free; end;
      finally Camp.Free; end;
    end;

    // Bulk: list/replace menu assignments for a menu: /menus/{id}/display-assignments
    if (Copy(NormalizedPath, 1, 7) = '/menus/') and (Pos('/display-assignments', NormalizedPath) > 0) then
    begin
      var Tail := Copy(NormalizedPath, 8, MaxInt);
      var Slash := Pos('/', Tail);
      var IdStr := Tail; if Slash>0 then IdStr := Copy(Tail,1,Slash-1);
      var MenuId := StrToIntDef(IdStr,0); if MenuId=0 then begin JSONError(400,'Invalid menu id'); Exit; end;
      var M0 := TMenuRepository.GetById(MenuId);
      if M0=nil then begin JSONError(404,'Not found'); Exit; end;
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
        if TokOrg<>M0.OrganizationId then begin JSONError(403,'Forbidden'); Exit; end;

        var C := NewConnection;
        try
          if SameText(Request.Method,'GET') then
          begin
            var Q := TFDQuery.Create(nil);
            try
              Q.Connection := C;
              Q.SQL.Text := 'select DisplayMenuID, DisplayID, IsPrimary from DisplayMenus where MenuID=:M order by DisplayMenuID';
              Q.ParamByName('M').AsInteger := MenuId;
              Q.Open;
              var Arr := TJSONArray.Create;
              try
                while not Q.Eof do
                begin
                  var O := TJSONObject.Create;
                  O.AddPair('Id', TJSONNumber.Create(Q.FieldByName('DisplayMenuID').AsInteger));
                  O.AddPair('DisplayId', TJSONNumber.Create(Q.FieldByName('DisplayID').AsInteger));
                  O.AddPair('IsPrimary', TJSONBool.Create(Q.FieldByName('IsPrimary').AsBoolean));
                  Arr.AddElement(O);
                  Q.Next;
                end;
                var Root := TJSONObject.Create; try
                  Root.AddPair('value', Arr);
                  Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := Root.ToJSON; Response.SendResponse;
                finally Root.Free; end;
              finally Arr.Free; end;
            finally Q.Free; end;
            Exit;
          end
          else if SameText(Request.Method,'PUT') then
          begin
            if TryReplayIdempotency(M0.OrganizationId) then Exit;
            var Body := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject;
            try
              if Body=nil then begin JSONError(400,'Invalid JSON'); Exit; end;
              var DisplayIdsVal := Body.GetValue('DisplayIds');
              if (DisplayIdsVal=nil) or (not (DisplayIdsVal is TJSONArray)) then begin JSONError(400,'Missing DisplayIds'); Exit; end;
              var SetPrimary := Body.GetValue<Boolean>('SetPrimary', True);

              var Csv := '';
              for var v in (DisplayIdsVal as TJSONArray) do
              begin
                var did := StrToIntDef(v.Value,0);
                if did>0 then
                begin
                  if Csv<>'' then Csv := Csv + ',';
                  Csv := Csv + IntToStr(did);
                end;
              end;

              var QDel := TFDQuery.Create(nil);
              try
                QDel.Connection := C;
                // Replace full set for this menu (avoids relying on UNIQUE/ON CONFLICT constraints)
                QDel.SQL.Text := 'delete from DisplayMenus where MenuID=:M';
                QDel.ParamByName('M').AsInteger := MenuId;
                QDel.ExecSQL;
              finally QDel.Free; end;

              if Csv<>'' then
              begin
                // Ensure a display only has one menu at a time: clear any existing menu assignments on these displays
                // before inserting the new menu assignments (avoids UNIQUE(DisplayID) conflicts).
                var QClearOtherMenus := TFDQuery.Create(nil);
                try
                  QClearOtherMenus.Connection := C;
                  QClearOtherMenus.SQL.Text :=
                    'delete from DisplayMenus dm using Displays d ' +
                    'where dm.DisplayID = d.DisplayID ' +
                    'and d.OrganizationID = :Org ' +
                    'and dm.DisplayID = any(string_to_array(:Ids,'','')::int[])';
                  QClearOtherMenus.ParamByName('Org').AsInteger := M0.OrganizationId;
                  QClearOtherMenus.ParamByName('Ids').AsString := Csv;
                  QClearOtherMenus.ExecSQL;
                finally QClearOtherMenus.Free; end;

                var QIns := TFDQuery.Create(nil);
                try
                  QIns.Connection := C;
                  QIns.SQL.Text :=
                    'insert into DisplayMenus (DisplayID, MenuID, IsPrimary) ' +
                    'select distinct d.DisplayID, :M as MenuID, :P as IsPrimary ' +
                    'from Displays d ' +
                    'join unnest(string_to_array(:Ids,'','')) as x on d.DisplayID = x::int ' +
                    'where d.OrganizationID = :Org';
                  QIns.ParamByName('M').AsInteger := MenuId;
                  QIns.ParamByName('P').AsBoolean := SetPrimary;
                  QIns.ParamByName('Ids').AsString := Csv;
                  QIns.ParamByName('Org').AsInteger := M0.OrganizationId;
                  QIns.ExecSQL;
                finally QIns.Free; end;

                // Enforce: a display can have either menus OR campaigns assigned.
                // When assigning a menu, remove any campaign assignments for those displays.
                var QClearCampaigns := TFDQuery.Create(nil);
                try
                  QClearCampaigns.Connection := C;
                  QClearCampaigns.SQL.Text :=
                    'delete from DisplayCampaigns dc using Displays d ' +
                    'where dc.DisplayID = d.DisplayID ' +
                    'and d.OrganizationID = :Org ' +
                    'and dc.DisplayID = any(string_to_array(:Ids,'','')::int[])';
                  QClearCampaigns.ParamByName('Org').AsInteger := M0.OrganizationId;
                  QClearCampaigns.ParamByName('Ids').AsString := Csv;
                  QClearCampaigns.ExecSQL;
                finally QClearCampaigns.Free; end;

                if SetPrimary then
                begin
                  // Clear other primaries (menus) on those displays and set this menu primary.
                  var Qp := TFDQuery.Create(nil);
                  try
                    Qp.Connection := C;
                    Qp.SQL.Text :=
                      'update DisplayMenus dm set IsPrimary=false ' +
                      'from Displays d ' +
                      'where dm.DisplayID = d.DisplayID ' +
                      'and d.OrganizationID = :Org ' +
                      'and dm.DisplayID = any(string_to_array(:Ids,'','')::int[]) ' +
                      'and dm.MenuID<>:M';
                    Qp.ParamByName('Ids').AsString := Csv;
                    Qp.ParamByName('M').AsInteger := MenuId;
                    Qp.ParamByName('Org').AsInteger := M0.OrganizationId;
                    Qp.ExecSQL;
                    Qp.SQL.Text :=
                      'update DisplayMenus dm set IsPrimary=true ' +
                      'from Displays d ' +
                      'where dm.DisplayID = d.DisplayID ' +
                      'and d.OrganizationID = :Org ' +
                      'and dm.DisplayID = any(string_to_array(:Ids,'','')::int[]) ' +
                      'and dm.MenuID=:M';
                    Qp.ExecSQL;
                  finally Qp.Free; end;
                end;
              end;

              Response.StatusCode := 204; Response.ContentType := 'application/json'; Response.Content := ''; Response.SendResponse;
            finally Body.Free; end;
            Exit;
          end;
        finally C.Free; end;
      finally M0.Free; end;
    end;

    // Organization info boards: /organizations/{OrganizationId}/infoboards
    if (Copy(NormalizedPath, 1, 15) = '/organizations/') and
       (Pos('/infoboards', NormalizedPath) > 0) and
       (Pos('/sections', NormalizedPath) = 0) and (Pos('/items', NormalizedPath) = 0) then
    begin
      var OrgIdStr := Copy(NormalizedPath, 16, MaxInt);
      var Slash := Pos('/', OrgIdStr); if Slash>0 then OrgIdStr := Copy(OrgIdStr, 1, Slash-1);
      var OrgId := StrToIntDef(OrgIdStr,0); if OrgId=0 then begin JSONError(400,'Invalid organization id'); Exit; end;

      if SameText(Request.Method,'GET') then
      begin
        var TokOrg, TokUser: Integer; var TokRole: string;
        if not RequireAuth(['campaigns:read'], TokOrg, TokUser, TokRole) then Exit;
        if TokOrg<>OrgId then begin JSONError(403,'Forbidden'); Exit; end;
        var L := TInfoBoardRepository.ListByOrganization(OrgId);
        try
          var Arr := TJSONArray.Create; try
            for var B in L do
            begin
              var O := TJSONObject.Create;
              O.AddPair('Id', TJSONNumber.Create(B.Id));
              O.AddPair('OrganizationId', TJSONNumber.Create(B.OrganizationId));
              O.AddPair('Name', B.Name);
              O.AddPair('BoardType', B.BoardType);
              O.AddPair('Orientation', B.Orientation);
              O.AddPair('TemplateKey', B.TemplateKey);
              O.AddPair('PublicToken', B.PublicToken);
              var Theme := TJSONObject.ParseJSONValue(B.ThemeConfigJson);
              if Theme=nil then Theme := TJSONObject.Create;
              O.AddPair('ThemeConfig', Theme);
              Arr.AddElement(O);
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
        var TokOrg, TokUser: Integer; var TokRole: string;
        if not RequireAuth(['campaigns:write'], TokOrg, TokUser, TokRole) then Exit;
        if TokOrg<>OrgId then begin JSONError(403,'Forbidden'); Exit; end;
        if TryReplayIdempotency(OrgId) then Exit;
        var Body := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject;
        try
          if Body=nil then begin JSONError(400,'Invalid JSON'); Exit; end;
          var Name := Body.GetValue<string>('Name','');
          var BoardType := Body.GetValue<string>('BoardType','');
          var Orientation := Body.GetValue<string>('Orientation','');
          var TemplateKey := Body.GetValue<string>('TemplateKey','');
          var ThemeVal := Body.GetValue('ThemeConfig');
          var ThemeJson := '{}';
          if (ThemeVal<>nil) and (not (ThemeVal is TJSONNull)) then ThemeJson := ThemeVal.ToJSON;
          if Name='' then begin JSONError(400,'Missing Name'); Exit; end;
          if BoardType='' then BoardType := 'directory';
          if Orientation='' then Orientation := 'Landscape';
          if TemplateKey='' then TemplateKey := 'standard';
          var PublicToken := TGUID.NewGuid.ToString.Replace('{','').Replace('}','').Replace('-','');
          var B := TInfoBoardRepository.CreateInfoBoard(OrgId, Name, BoardType, Orientation, TemplateKey, ThemeJson, PublicToken);
          try
            var O := TJSONObject.Create;
            O.AddPair('Id', TJSONNumber.Create(B.Id));
            O.AddPair('OrganizationId', TJSONNumber.Create(B.OrganizationId));
            O.AddPair('Name', B.Name);
            O.AddPair('BoardType', B.BoardType);
            O.AddPair('Orientation', B.Orientation);
            O.AddPair('TemplateKey', B.TemplateKey);
            O.AddPair('PublicToken', B.PublicToken);
            var Theme := TJSONObject.ParseJSONValue(B.ThemeConfigJson);
            if Theme=nil then Theme := TJSONObject.Create;
            O.AddPair('ThemeConfig', Theme);
            var OutBody := O.ToJSON;
            O.Free;
            StoreIdempotency(OrgId, 201, OutBody);
            Response.StatusCode := 201; Response.ContentType := 'application/json'; Response.Content := OutBody; Response.SendResponse;
          finally B.Free; end;
        finally Body.Free; end;
        Exit;
      end;
    end;

    // Info Board CRUD: /infoboards/{id}
    if (Copy(NormalizedPath, 1, 12) = '/infoboards/') and
       (Pos('/display-assignments', NormalizedPath) = 0) and
       (Pos('/sections', NormalizedPath) = 0) and
       (Pos('/duplicate', NormalizedPath) = 0) then
    begin
      var Tail := Copy(NormalizedPath, 13, MaxInt);
      var Slash := Pos('/', Tail);
      var IdStr := Tail; if Slash>0 then IdStr := Copy(Tail,1,Slash-1);
      var BoardId := StrToIntDef(IdStr,0); if BoardId=0 then begin JSONError(400,'Invalid info board id'); Exit; end;

      var B := TInfoBoardRepository.GetById(BoardId);
      if B=nil then begin JSONError(404,'Not found'); Exit; end;
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
        if TokOrg<>B.OrganizationId then begin JSONError(403,'Forbidden'); Exit; end;

        if SameText(Request.Method,'GET') then
        begin
          var O := TJSONObject.Create;
          O.AddPair('Id', TJSONNumber.Create(B.Id));
          O.AddPair('OrganizationId', TJSONNumber.Create(B.OrganizationId));
          O.AddPair('Name', B.Name);
          O.AddPair('BoardType', B.BoardType);
          O.AddPair('Orientation', B.Orientation);
          O.AddPair('TemplateKey', B.TemplateKey);
          O.AddPair('PublicToken', B.PublicToken);
          var Theme := TJSONObject.ParseJSONValue(B.ThemeConfigJson);
          if Theme=nil then Theme := TJSONObject.Create;
          O.AddPair('ThemeConfig', Theme);
          Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := O.ToJSON; Response.SendResponse;
          O.Free;
          Exit;
        end
        else if SameText(Request.Method,'PUT') or SameText(Request.Method,'PATCH') then
        begin
          var Body := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject;
          try
            if Body=nil then begin JSONError(400,'Invalid JSON'); Exit; end;
            var NewName := Body.GetValue<string>('Name','');
            var NewBoardType := Body.GetValue<string>('BoardType','');
            var NewOrientation := Body.GetValue<string>('Orientation','');
            var NewTemplateKey := Body.GetValue<string>('TemplateKey','');
            var ThemeVal := Body.GetValue('ThemeConfig');
            var NewThemeJson := '';
            if (ThemeVal<>nil) and (not (ThemeVal is TJSONNull)) then NewThemeJson := ThemeVal.ToJSON;
            if NewName='' then NewName := B.Name;
            if NewBoardType='' then NewBoardType := B.BoardType;
            if NewOrientation='' then NewOrientation := B.Orientation;
            if NewTemplateKey='' then NewTemplateKey := B.TemplateKey;
            if NewThemeJson='' then NewThemeJson := B.ThemeConfigJson;
            var Updated := TInfoBoardRepository.UpdateInfoBoard(BoardId, NewName, NewBoardType, NewOrientation, NewTemplateKey, NewThemeJson);
            try
              var O := TJSONObject.Create;
              O.AddPair('Id', TJSONNumber.Create(Updated.Id));
              O.AddPair('OrganizationId', TJSONNumber.Create(Updated.OrganizationId));
              O.AddPair('Name', Updated.Name);
              O.AddPair('BoardType', Updated.BoardType);
              O.AddPair('Orientation', Updated.Orientation);
              O.AddPair('TemplateKey', Updated.TemplateKey);
              O.AddPair('PublicToken', Updated.PublicToken);
              var Theme := TJSONObject.ParseJSONValue(Updated.ThemeConfigJson);
              if Theme=nil then Theme := TJSONObject.Create;
              O.AddPair('ThemeConfig', Theme);
              Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := O.ToJSON; Response.SendResponse;
              O.Free;
            finally Updated.Free; end;
          finally Body.Free; end;
          Exit;
        end
        else if SameText(Request.Method,'DELETE') then
        begin
          TInfoBoardRepository.DeleteInfoBoard(BoardId);
          Response.StatusCode := 204; Response.ContentType := 'application/json'; Response.Content := ''; Response.SendResponse;
          Exit;
        end;
      finally B.Free; end;
    end;

    // Info Board duplicate: /infoboards/{id}/duplicate
    if (Copy(NormalizedPath, 1, 12) = '/infoboards/') and (Pos('/duplicate', NormalizedPath) > 0) and SameText(Request.Method,'POST') then
    begin
      var Tail := Copy(NormalizedPath, 13, MaxInt);
      var Slash := Pos('/', Tail);
      var IdStr := Tail; if Slash>0 then IdStr := Copy(Tail,1,Slash-1);
      var BoardId := StrToIntDef(IdStr,0); if BoardId=0 then begin JSONError(400,'Invalid info board id'); Exit; end;
      var B := TInfoBoardRepository.GetById(BoardId);
      if B=nil then begin JSONError(404,'Not found'); Exit; end;
      try
        var TokOrg, TokUser: Integer; var TokRole: string;
        if not RequireAuth(['campaigns:write'], TokOrg, TokUser, TokRole) then Exit;
        if TokOrg<>B.OrganizationId then begin JSONError(403,'Forbidden'); Exit; end;
        var NewPublicToken := TGUID.NewGuid.ToString.Replace('{','').Replace('}','').Replace('-','');
        var NewB := TInfoBoardRepository.CreateInfoBoard(B.OrganizationId, B.Name + ' (Copy)', B.BoardType, B.Orientation, B.TemplateKey, B.ThemeConfigJson, NewPublicToken);
        try
          // Copy sections and items
          var Secs := TInfoBoardSectionRepository.ListByInfoBoard(B.Id);
          try
            for var Sec in Secs do
            begin
              var NewSec := TInfoBoardSectionRepository.CreateSection(NewB.Id, Sec.Name, Sec.Subtitle, Sec.IconEmoji, Sec.IconUrl, Sec.BackgroundColor, Sec.TitleColor, Sec.LayoutStyle, Sec.DisplayOrder);
              try
                var Items := TInfoBoardItemRepository.ListBySection(Sec.Id);
                try
                  for var Item in Items do
                  begin
                    TInfoBoardItemRepository.CreateItem(NewSec.Id, Item.ItemType, Item.Title, Item.Subtitle, Item.Description, Item.ImageUrl, Item.IconEmoji, Item.Location, Item.ContactInfo, Item.QrCodeUrl, Item.MapPositionJson, Item.TagsJson, Item.HighlightColor, Item.DisplayOrder, Item.IsVisible);
                  end;
                finally Items.Free; end;
              finally NewSec.Free; end;
            end;
          finally Secs.Free; end;
          var O := TJSONObject.Create;
          O.AddPair('Id', TJSONNumber.Create(NewB.Id));
          O.AddPair('OrganizationId', TJSONNumber.Create(NewB.OrganizationId));
          O.AddPair('Name', NewB.Name);
          O.AddPair('BoardType', NewB.BoardType);
          O.AddPair('Orientation', NewB.Orientation);
          O.AddPair('TemplateKey', NewB.TemplateKey);
          O.AddPair('PublicToken', NewB.PublicToken);
          Response.StatusCode := 201; Response.ContentType := 'application/json'; Response.Content := O.ToJSON; Response.SendResponse;
          O.Free;
        finally NewB.Free; end;
      finally B.Free; end;
      Exit;
    end;

    // Info Board display assignments: /infoboards/{id}/display-assignments
    if (Copy(NormalizedPath, 1, 12) = '/infoboards/') and (Pos('/display-assignments', NormalizedPath) > 0) then
    begin
      var Tail := Copy(NormalizedPath, 13, MaxInt);
      var Slash := Pos('/', Tail);
      var IdStr := Tail; if Slash>0 then IdStr := Copy(Tail,1,Slash-1);
      var BoardId := StrToIntDef(IdStr,0); if BoardId=0 then begin JSONError(400,'Invalid info board id'); Exit; end;
      var B := TInfoBoardRepository.GetById(BoardId);
      if B=nil then begin JSONError(404,'Not found'); Exit; end;
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
        if TokOrg<>B.OrganizationId then begin JSONError(403,'Forbidden'); Exit; end;

        var C := NewConnection;
        try
          if SameText(Request.Method,'GET') then
          begin
            var Q := TFDQuery.Create(nil);
            try
              Q.Connection := C;
              Q.SQL.Text := 'select DisplayInfoBoardID, DisplayID, IsPrimary from DisplayInfoBoards where InfoBoardID=:B';
              Q.ParamByName('B').AsInteger := BoardId;
              Q.Open;
              var Arr := TJSONArray.Create;
              while not Q.Eof do
              begin
                var O := TJSONObject.Create;
                O.AddPair('DisplayInfoBoardId', TJSONNumber.Create(Q.FieldByName('DisplayInfoBoardID').AsInteger));
                O.AddPair('DisplayId', TJSONNumber.Create(Q.FieldByName('DisplayID').AsInteger));
                O.AddPair('IsPrimary', TJSONBool.Create(Q.FieldByName('IsPrimary').AsBoolean));
                Arr.AddElement(O);
                Q.Next;
              end;
              var Wrapper := TJSONObject.Create;
              Wrapper.AddPair('value', Arr);
              Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := Wrapper.ToJSON; Response.SendResponse;
              Wrapper.Free;
            finally Q.Free; end;
            Exit;
          end
          else if SameText(Request.Method,'PUT') then
          begin
            var Body := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject;
            try
              if Body=nil then begin JSONError(400,'Invalid JSON'); Exit; end;
              var SetPrimary := Body.GetValue<Boolean>('SetPrimary', False);
              var IdsArr := Body.GetValue<TJSONArray>('DisplayIds');
              var Csv := '';
              if IdsArr<>nil then
              begin
                for var i := 0 to IdsArr.Count-1 do
                begin
                  var v := IdsArr.Items[i];
                  var idVal := 0;
                  if v is TJSONNumber then idVal := (v as TJSONNumber).AsInt
                  else if v is TJSONString then idVal := StrToIntDef((v as TJSONString).Value, 0);
                  if idVal>0 then
                  begin
                    if Csv<>'' then Csv := Csv + ',';
                    Csv := Csv + IntToStr(idVal);
                  end;
                end;
              end;

              // Delete existing assignments for this info board
              var QDel := TFDQuery.Create(nil);
              try
                QDel.Connection := C;
                QDel.SQL.Text := 'delete from DisplayInfoBoards where InfoBoardID=:B';
                QDel.ParamByName('B').AsInteger := BoardId;
                QDel.ExecSQL;
              finally QDel.Free; end;

              if Csv<>'' then
              begin
                // Clear other content assignments when assigning info board
                var QClearMenus := TFDQuery.Create(nil);
                try
                  QClearMenus.Connection := C;
                  QClearMenus.SQL.Text :=
                    'delete from DisplayMenus dm using Displays d ' +
                    'where dm.DisplayID = d.DisplayID ' +
                    'and d.OrganizationID = :Org ' +
                    'and dm.DisplayID = any(string_to_array(:Ids,'','')::int[])';
                  QClearMenus.ParamByName('Org').AsInteger := B.OrganizationId;
                  QClearMenus.ParamByName('Ids').AsString := Csv;
                  QClearMenus.ExecSQL;
                finally QClearMenus.Free; end;

                var QClearCampaigns := TFDQuery.Create(nil);
                try
                  QClearCampaigns.Connection := C;
                  QClearCampaigns.SQL.Text :=
                    'delete from DisplayCampaigns dc using Displays d ' +
                    'where dc.DisplayID = d.DisplayID ' +
                    'and d.OrganizationID = :Org ' +
                    'and dc.DisplayID = any(string_to_array(:Ids,'','')::int[])';
                  QClearCampaigns.ParamByName('Org').AsInteger := B.OrganizationId;
                  QClearCampaigns.ParamByName('Ids').AsString := Csv;
                  QClearCampaigns.ExecSQL;
                finally QClearCampaigns.Free; end;

                // Insert new assignments
                var QIns := TFDQuery.Create(nil);
                try
                  QIns.Connection := C;
                  QIns.SQL.Text :=
                    'insert into DisplayInfoBoards (DisplayID, InfoBoardID, IsPrimary) ' +
                    'select distinct d.DisplayID, :B as InfoBoardID, :P as IsPrimary ' +
                    'from Displays d ' +
                    'join unnest(string_to_array(:Ids,'','')) as x on d.DisplayID = x::int ' +
                    'where d.OrganizationID = :Org';
                  QIns.ParamByName('B').AsInteger := BoardId;
                  QIns.ParamByName('P').AsBoolean := SetPrimary;
                  QIns.ParamByName('Ids').AsString := Csv;
                  QIns.ParamByName('Org').AsInteger := B.OrganizationId;
                  QIns.ExecSQL;
                finally QIns.Free; end;
              end;

              Response.StatusCode := 204; Response.ContentType := 'application/json'; Response.Content := ''; Response.SendResponse;
            finally Body.Free; end;
            Exit;
          end;
        finally C.Free; end;
      finally B.Free; end;
    end;

    // Public info board JSON: /public/infoboards/{token}
    if (Copy(NormalizedPath, 1, 19) = '/public/infoboards/') and SameText(Request.Method,'GET') then
    begin
      var Token := Copy(NormalizedPath, 20, MaxInt);
      if Token='' then begin JSONError(400,'Missing token'); Exit; end;
      var B := TInfoBoardRepository.GetByPublicToken(Token);
      if B=nil then begin JSONError(404,'Not found'); Exit; end;
      try
        var Root := TJSONObject.Create;
        Root.AddPair('Id', TJSONNumber.Create(B.Id));
        Root.AddPair('Name', B.Name);
        Root.AddPair('BoardType', B.BoardType);
        Root.AddPair('Orientation', B.Orientation);
        Root.AddPair('TemplateKey', B.TemplateKey);
        var Theme := TJSONObject.ParseJSONValue(B.ThemeConfigJson);
        if Theme=nil then Theme := TJSONObject.Create;
        Root.AddPair('ThemeConfig', Theme);

        var SectionsArr := TJSONArray.Create;
        var Secs := TInfoBoardSectionRepository.ListByInfoBoard(B.Id);
        try
          for var S in Secs do
          begin
            var SO := TJSONObject.Create;
            SO.AddPair('Id', TJSONNumber.Create(S.Id));
            SO.AddPair('Name', S.Name);
            if Trim(S.Subtitle)<>'' then SO.AddPair('Subtitle', S.Subtitle) else SO.AddPair('Subtitle', TJSONNull.Create);
            if Trim(S.IconEmoji)<>'' then SO.AddPair('IconEmoji', S.IconEmoji) else SO.AddPair('IconEmoji', TJSONNull.Create);
            if Trim(S.IconUrl)<>'' then SO.AddPair('IconUrl', S.IconUrl) else SO.AddPair('IconUrl', TJSONNull.Create);
            if Trim(S.BackgroundColor)<>'' then SO.AddPair('BackgroundColor', S.BackgroundColor) else SO.AddPair('BackgroundColor', TJSONNull.Create);
            if Trim(S.TitleColor)<>'' then SO.AddPair('TitleColor', S.TitleColor) else SO.AddPair('TitleColor', TJSONNull.Create);
            SO.AddPair('LayoutStyle', S.LayoutStyle);
            SO.AddPair('DisplayOrder', TJSONNumber.Create(S.DisplayOrder));

            var ItemsArr := TJSONArray.Create;
            var Items := TInfoBoardItemRepository.ListBySection(S.Id);
            try
              for var It in Items do
              begin
                if not It.IsVisible then Continue;
                var IO := TJSONObject.Create;
                IO.AddPair('Id', TJSONNumber.Create(It.Id));
                IO.AddPair('ItemType', It.ItemType);
                IO.AddPair('Title', It.Title);
                if Trim(It.Subtitle)<>'' then IO.AddPair('Subtitle', It.Subtitle) else IO.AddPair('Subtitle', TJSONNull.Create);
                if Trim(It.Description)<>'' then IO.AddPair('Description', It.Description) else IO.AddPair('Description', TJSONNull.Create);
                if Trim(It.ImageUrl)<>'' then IO.AddPair('ImageUrl', It.ImageUrl) else IO.AddPair('ImageUrl', TJSONNull.Create);
                if Trim(It.IconEmoji)<>'' then IO.AddPair('IconEmoji', It.IconEmoji) else IO.AddPair('IconEmoji', TJSONNull.Create);
                if Trim(It.Location)<>'' then IO.AddPair('Location', It.Location) else IO.AddPair('Location', TJSONNull.Create);
                if Trim(It.ContactInfo)<>'' then IO.AddPair('ContactInfo', It.ContactInfo) else IO.AddPair('ContactInfo', TJSONNull.Create);
                if Trim(It.QrCodeUrl)<>'' then IO.AddPair('QrCodeUrl', It.QrCodeUrl) else IO.AddPair('QrCodeUrl', TJSONNull.Create);
                if Trim(It.HighlightColor)<>'' then IO.AddPair('HighlightColor', It.HighlightColor) else IO.AddPair('HighlightColor', TJSONNull.Create);
                IO.AddPair('DisplayOrder', TJSONNumber.Create(It.DisplayOrder));
                ItemsArr.AddElement(IO);
              end;
            finally Items.Free; end;
            SO.AddPair('Items', ItemsArr);
            SectionsArr.AddElement(SO);
          end;
        finally Secs.Free; end;

        Root.AddPair('Sections', SectionsArr);
        Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := Root.ToJSON; Response.SendResponse;
        Root.Free;
        Exit;
      finally B.Free; end;
    end;

    // InfoBoard Sections: /infoboards/{id}/sections
    if (Copy(NormalizedPath, 1, 12) = '/infoboards/') and (Pos('/sections', NormalizedPath) > 0) and (Pos('/items', NormalizedPath) = 0) then
    begin
      var IdStr := Copy(NormalizedPath, 13, MaxInt);
      var Slash := Pos('/', IdStr); if Slash>0 then IdStr := Copy(IdStr,1,Slash-1);
      var BoardId := StrToIntDef(IdStr,0); if BoardId=0 then begin JSONError(400,'Invalid board id'); Exit; end;

      var B := TInfoBoardRepository.GetById(BoardId);
      if B=nil then begin JSONError(404,'Not found'); Exit; end;
      try
        var TokOrg, TokUser: Integer; var TokRole: string;
        if SameText(Request.Method,'GET') then
        begin
          if not RequireAuth(['infoboards:read'], TokOrg, TokUser, TokRole) then Exit;
        end
        else
        begin
          if not RequireAuth(['infoboards:write'], TokOrg, TokUser, TokRole) then Exit;
        end;
        if TokOrg<>B.OrganizationId then begin JSONError(403,'Forbidden'); Exit; end;

        if SameText(Request.Method,'GET') then
        begin
          var L := TInfoBoardSectionRepository.ListByInfoBoard(BoardId);
          try
            var Arr := TJSONArray.Create;
            for var S in L do
            begin
              var O := TJSONObject.Create;
              O.AddPair('Id', TJSONNumber.Create(S.Id));
              O.AddPair('InfoBoardId', TJSONNumber.Create(S.InfoBoardId));
              O.AddPair('Title', S.Name);
              O.AddPair('DisplayOrder', TJSONNumber.Create(S.DisplayOrder));
              O.AddPair('LayoutType', S.LayoutStyle);
              if Trim(S.BackgroundColor)<>'' then O.AddPair('BackgroundColor', S.BackgroundColor) else O.AddPair('BackgroundColor', TJSONNull.Create);
              if Trim(S.TitleColor)<>'' then O.AddPair('TextColor', S.TitleColor) else O.AddPair('TextColor', TJSONNull.Create);
              Arr.AddElement(O);
            end;
            var Wrapper := TJSONObject.Create;
            try
              Wrapper.AddPair('value', Arr);
              Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := Wrapper.ToJSON; Response.SendResponse;
            finally Wrapper.Free; end;
          finally L.Free; end;
          Exit;
        end
        else if SameText(Request.Method,'POST') then
        begin
          if TryReplayIdempotency(B.OrganizationId) then Exit;
          var Body := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject;
          try
            if Body=nil then begin JSONError(400,'Invalid JSON'); Exit; end;
            var TitleVal := Body.GetValue('Title');
            if (TitleVal=nil) or (TitleVal is TJSONNull) or (Trim(TitleVal.Value)='') then begin JSONError(400,'Title required'); Exit; end;

            var LayoutVal := Body.GetValue('LayoutType');
            var Layout := 'grid';
            if (LayoutVal<>nil) and (not (LayoutVal is TJSONNull)) then Layout := LayoutVal.Value;

            var OrderVal := Body.GetValue('DisplayOrder');
            var Order := 1;
            if (OrderVal<>nil) and (not (OrderVal is TJSONNull)) then
            begin
              if OrderVal is TJSONNumber then Order := TJSONNumber(OrderVal).AsInt else Order := StrToIntDef(OrderVal.Value, 1);
            end;

            var BgVal := Body.GetValue('BackgroundColor');
            var Bg := '';
            if (BgVal<>nil) and (not (BgVal is TJSONNull)) then Bg := BgVal.Value;

            var TxVal := Body.GetValue('TextColor');
            var Tx := '';
            if (TxVal<>nil) and (not (TxVal is TJSONNull)) then Tx := TxVal.Value;

            var S := TInfoBoardSectionRepository.CreateSection(BoardId, TitleVal.Value, '', '', '', Bg, Tx, Layout, Order);
            try
              var O := TJSONObject.Create;
              O.AddPair('Id', TJSONNumber.Create(S.Id));
              O.AddPair('InfoBoardId', TJSONNumber.Create(S.InfoBoardId));
              O.AddPair('Title', S.Name);
              O.AddPair('DisplayOrder', TJSONNumber.Create(S.DisplayOrder));
              O.AddPair('LayoutType', S.LayoutStyle);
              if Trim(S.BackgroundColor)<>'' then O.AddPair('BackgroundColor', S.BackgroundColor) else O.AddPair('BackgroundColor', TJSONNull.Create);
              if Trim(S.TitleColor)<>'' then O.AddPair('TextColor', S.TitleColor) else O.AddPair('TextColor', TJSONNull.Create);
              var OutBody := O.ToJSON;
              O.Free;
              StoreIdempotency(B.OrganizationId, 201, OutBody);
              Response.StatusCode := 201; Response.ContentType := 'application/json'; Response.Content := OutBody; Response.SendResponse;
            finally S.Free; end;
          finally Body.Free; end;
          Exit;
        end;
      finally B.Free; end;
    end;

    // InfoBoard Section CRUD: /infoboard-sections/{id}
    if (Copy(NormalizedPath, 1, 20) = '/infoboard-sections/') and (Pos('/items', NormalizedPath) = 0) then
    begin
      var IdStr := Copy(NormalizedPath, 21, MaxInt);
      if Pos('/', IdStr) > 0 then IdStr := Copy(IdStr, 1, Pos('/', IdStr)-1);
      var SectionId := StrToIntDef(IdStr,0); if SectionId=0 then begin JSONError(400,'Invalid section id'); Exit; end;

      var S := TInfoBoardSectionRepository.GetById(SectionId);
      if S=nil then begin JSONError(404,'Not found'); Exit; end;
      try
        var B := TInfoBoardRepository.GetById(S.InfoBoardId);
        if B=nil then begin JSONError(404,'Board not found'); S.Free; Exit; end;
        try
          var TokOrg, TokUser: Integer; var TokRole: string;
          if SameText(Request.Method,'GET') then
          begin
            if not RequireAuth(['infoboards:read'], TokOrg, TokUser, TokRole) then Exit;
          end
          else
          begin
            if not RequireAuth(['infoboards:write'], TokOrg, TokUser, TokRole) then Exit;
          end;
          if TokOrg<>B.OrganizationId then begin JSONError(403,'Forbidden'); Exit; end;

          if SameText(Request.Method,'GET') then
          begin
            var O := TJSONObject.Create;
            O.AddPair('Id', TJSONNumber.Create(S.Id));
            O.AddPair('InfoBoardId', TJSONNumber.Create(S.InfoBoardId));
            O.AddPair('Title', S.Name);
            O.AddPair('DisplayOrder', TJSONNumber.Create(S.DisplayOrder));
            O.AddPair('LayoutType', S.LayoutStyle);
            if Trim(S.BackgroundColor)<>'' then O.AddPair('BackgroundColor', S.BackgroundColor) else O.AddPair('BackgroundColor', TJSONNull.Create);
            if Trim(S.TitleColor)<>'' then O.AddPair('TextColor', S.TitleColor) else O.AddPair('TextColor', TJSONNull.Create);
            Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := O.ToJSON; Response.SendResponse;
            O.Free;
            Exit;
          end
          else if SameText(Request.Method,'PUT') then
          begin
            var Body := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject;
            try
              if Body=nil then begin JSONError(400,'Invalid JSON'); Exit; end;
              var TitleVal := Body.GetValue('Title');
              if (TitleVal<>nil) and (not (TitleVal is TJSONNull)) then S.Name := TitleVal.Value;

              var LayoutVal := Body.GetValue('LayoutType');
              if (LayoutVal<>nil) and (not (LayoutVal is TJSONNull)) then S.LayoutStyle := LayoutVal.Value;

              var OrderVal := Body.GetValue('DisplayOrder');
              if (OrderVal<>nil) and (not (OrderVal is TJSONNull)) then
              begin
                if OrderVal is TJSONNumber then S.DisplayOrder := TJSONNumber(OrderVal).AsInt else S.DisplayOrder := StrToIntDef(OrderVal.Value, S.DisplayOrder);
              end;

              var BgVal := Body.GetValue('BackgroundColor');
              if (BgVal<>nil) and (not (BgVal is TJSONNull)) then S.BackgroundColor := BgVal.Value;

              var TxVal := Body.GetValue('TextColor');
              if (TxVal<>nil) and (not (TxVal is TJSONNull)) then S.TitleColor := TxVal.Value;

              var UpdS := TInfoBoardSectionRepository.UpdateSection(S.Id, S.Name, S.Subtitle, S.IconEmoji, S.IconUrl, S.BackgroundColor, S.TitleColor, S.LayoutStyle, S.DisplayOrder);
              try
                var O := TJSONObject.Create;
                O.AddPair('Id', TJSONNumber.Create(UpdS.Id));
                O.AddPair('InfoBoardId', TJSONNumber.Create(UpdS.InfoBoardId));
                O.AddPair('Title', UpdS.Name);
                O.AddPair('DisplayOrder', TJSONNumber.Create(UpdS.DisplayOrder));
                O.AddPair('LayoutType', UpdS.LayoutStyle);
                if Trim(UpdS.BackgroundColor)<>'' then O.AddPair('BackgroundColor', UpdS.BackgroundColor) else O.AddPair('BackgroundColor', TJSONNull.Create);
                if Trim(UpdS.TitleColor)<>'' then O.AddPair('TextColor', UpdS.TitleColor) else O.AddPair('TextColor', TJSONNull.Create);
                Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := O.ToJSON; Response.SendResponse;
                O.Free;
              finally UpdS.Free; end;
            finally Body.Free; end;
            Exit;
          end
          else if SameText(Request.Method,'DELETE') then
          begin
            TInfoBoardSectionRepository.DeleteSection(SectionId);
            Response.StatusCode := 204; Response.ContentType := 'application/json'; Response.Content := ''; Response.SendResponse;
            Exit;
          end;
        finally B.Free; end;
      finally S.Free; end;
    end;

    // InfoBoard Section Items: /infoboard-sections/{id}/items
    if (Copy(NormalizedPath, 1, 20) = '/infoboard-sections/') and (Pos('/items', NormalizedPath) > 0) then
    begin
      var IdStr := Copy(NormalizedPath, 21, MaxInt);
      var Slash := Pos('/', IdStr); if Slash>0 then IdStr := Copy(IdStr,1,Slash-1);
      var SectionId := StrToIntDef(IdStr,0); if SectionId=0 then begin JSONError(400,'Invalid section id'); Exit; end;

      var S := TInfoBoardSectionRepository.GetById(SectionId);
      if S=nil then begin JSONError(404,'Section not found'); Exit; end;
      try
        var B := TInfoBoardRepository.GetById(S.InfoBoardId);
        if B=nil then begin JSONError(404,'Board not found'); S.Free; Exit; end;
        try
          var TokOrg, TokUser: Integer; var TokRole: string;
          if SameText(Request.Method,'GET') then
          begin
            if not RequireAuth(['infoboards:read'], TokOrg, TokUser, TokRole) then Exit;
          end
          else
          begin
            if not RequireAuth(['infoboards:write'], TokOrg, TokUser, TokRole) then Exit;
          end;
          if TokOrg<>B.OrganizationId then begin JSONError(403,'Forbidden'); Exit; end;

          if SameText(Request.Method,'GET') then
          begin
            var L := TInfoBoardItemRepository.ListBySection(SectionId);
            try
              var Arr := TJSONArray.Create;
              for var It in L do
              begin
                var O := TJSONObject.Create;
                O.AddPair('Id', TJSONNumber.Create(It.Id));
                O.AddPair('SectionId', TJSONNumber.Create(It.SectionId));
                O.AddPair('ItemType', It.ItemType);
                O.AddPair('Title', It.Title);
                if Trim(It.Subtitle)<>'' then O.AddPair('Subtitle', It.Subtitle) else O.AddPair('Subtitle', TJSONNull.Create);
                if Trim(It.Description)<>'' then O.AddPair('Description', It.Description) else O.AddPair('Description', TJSONNull.Create);
                if Trim(It.ImageUrl)<>'' then O.AddPair('ImageUrl', It.ImageUrl) else O.AddPair('ImageUrl', TJSONNull.Create);
                if Trim(It.Location)<>'' then O.AddPair('LinkUrl', It.Location) else O.AddPair('LinkUrl', TJSONNull.Create);
                O.AddPair('DisplayOrder', TJSONNumber.Create(It.DisplayOrder));
                Arr.AddElement(O);
              end;
              var Wrapper := TJSONObject.Create;
              try
                Wrapper.AddPair('value', Arr);
                Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := Wrapper.ToJSON; Response.SendResponse;
              finally Wrapper.Free; end;
            finally L.Free; end;
            Exit;
          end
          else if SameText(Request.Method,'POST') then
          begin
            if TryReplayIdempotency(B.OrganizationId) then Exit;
            var Body := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject;
            try
              if Body=nil then begin JSONError(400,'Invalid JSON'); Exit; end;
              var TitleVal := Body.GetValue('Title');
              if (TitleVal=nil) or (TitleVal is TJSONNull) or (Trim(TitleVal.Value)='') then begin JSONError(400,'Title required'); Exit; end;

              var ItemTypeVal := Body.GetValue('ItemType');
              var ItemType := 'text';
              if (ItemTypeVal<>nil) and (not (ItemTypeVal is TJSONNull)) then ItemType := ItemTypeVal.Value;

              var SubtitleVal := Body.GetValue('Subtitle');
              var Subtitle := '';
              if (SubtitleVal<>nil) and (not (SubtitleVal is TJSONNull)) then Subtitle := SubtitleVal.Value;

              var DescVal := Body.GetValue('Description');
              var Desc := '';
              if (DescVal<>nil) and (not (DescVal is TJSONNull)) then Desc := DescVal.Value;

              var ImgVal := Body.GetValue('ImageUrl');
              var ImgUrl := '';
              if (ImgVal<>nil) and (not (ImgVal is TJSONNull)) then ImgUrl := ImgVal.Value;

              var LinkVal := Body.GetValue('LinkUrl');
              var LinkUrl := '';
              if (LinkVal<>nil) and (not (LinkVal is TJSONNull)) then LinkUrl := LinkVal.Value;

              var OrderVal := Body.GetValue('DisplayOrder');
              var Order := 1;
              if (OrderVal<>nil) and (not (OrderVal is TJSONNull)) then
              begin
                if OrderVal is TJSONNumber then
                  Order := TJSONNumber(OrderVal).AsInt
                else
                  Order := StrToIntDef(OrderVal.Value, 1);
              end;

              var It := TInfoBoardItemRepository.CreateItem(SectionId, ItemType, TitleVal.Value, Subtitle, Desc, ImgUrl, '', LinkUrl, '', '', '', '', '', Order, True);
              try
                var O := TJSONObject.Create;
                O.AddPair('Id', TJSONNumber.Create(It.Id));
                O.AddPair('SectionId', TJSONNumber.Create(It.SectionId));
                O.AddPair('ItemType', It.ItemType);
                O.AddPair('Title', It.Title);
                if Trim(It.Subtitle)<>'' then O.AddPair('Subtitle', It.Subtitle) else O.AddPair('Subtitle', TJSONNull.Create);
                if Trim(It.Description)<>'' then O.AddPair('Description', It.Description) else O.AddPair('Description', TJSONNull.Create);
                if Trim(It.ImageUrl)<>'' then O.AddPair('ImageUrl', It.ImageUrl) else O.AddPair('ImageUrl', TJSONNull.Create);
                if Trim(It.Location)<>'' then O.AddPair('LinkUrl', It.Location) else O.AddPair('LinkUrl', TJSONNull.Create);
                O.AddPair('DisplayOrder', TJSONNumber.Create(It.DisplayOrder));
                var OutBody := O.ToJSON;
                O.Free;
                StoreIdempotency(B.OrganizationId, 201, OutBody);
                Response.StatusCode := 201; Response.ContentType := 'application/json'; Response.Content := OutBody; Response.SendResponse;
              finally It.Free; end;
            finally Body.Free; end;
            Exit;
          end;
        finally B.Free; end;
      finally S.Free; end;
    end;

    // InfoBoard Item CRUD: /infoboard-items/{id}
    if (Copy(NormalizedPath, 1, 17) = '/infoboard-items/') then
    begin
      var IdStr := Copy(NormalizedPath, 18, MaxInt);
      if Pos('/', IdStr) > 0 then IdStr := Copy(IdStr, 1, Pos('/', IdStr)-1);
      var ItemId := StrToIntDef(IdStr,0); if ItemId=0 then begin JSONError(400,'Invalid item id'); Exit; end;

      var It := TInfoBoardItemRepository.GetById(ItemId);
      if It=nil then begin JSONError(404,'Not found'); Exit; end;
      try
        var S := TInfoBoardSectionRepository.GetById(It.SectionId);
        if S=nil then begin JSONError(404,'Section not found'); It.Free; Exit; end;
        try
          var B := TInfoBoardRepository.GetById(S.InfoBoardId);
          if B=nil then begin JSONError(404,'Board not found'); S.Free; It.Free; Exit; end;
          try
            var TokOrg, TokUser: Integer; var TokRole: string;
            if SameText(Request.Method,'GET') then
            begin
              if not RequireAuth(['infoboards:read'], TokOrg, TokUser, TokRole) then Exit;
            end
            else
            begin
              if not RequireAuth(['infoboards:write'], TokOrg, TokUser, TokRole) then Exit;
            end;
            if TokOrg<>B.OrganizationId then begin JSONError(403,'Forbidden'); Exit; end;

            if SameText(Request.Method,'GET') then
            begin
              var O := TJSONObject.Create;
              O.AddPair('Id', TJSONNumber.Create(It.Id));
              O.AddPair('SectionId', TJSONNumber.Create(It.SectionId));
              O.AddPair('ItemType', It.ItemType);
              O.AddPair('Title', It.Title);
              if Trim(It.Subtitle)<>'' then O.AddPair('Subtitle', It.Subtitle) else O.AddPair('Subtitle', TJSONNull.Create);
              if Trim(It.Description)<>'' then O.AddPair('Description', It.Description) else O.AddPair('Description', TJSONNull.Create);
              if Trim(It.ImageUrl)<>'' then O.AddPair('ImageUrl', It.ImageUrl) else O.AddPair('ImageUrl', TJSONNull.Create);
              if Trim(It.Location)<>'' then O.AddPair('LinkUrl', It.Location) else O.AddPair('LinkUrl', TJSONNull.Create);
              O.AddPair('DisplayOrder', TJSONNumber.Create(It.DisplayOrder));
              Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := O.ToJSON; Response.SendResponse;
              O.Free;
              Exit;
            end
            else if SameText(Request.Method,'PUT') then
            begin
              var Body := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject;
              try
                if Body=nil then begin JSONError(400,'Invalid JSON'); Exit; end;
                var TitleVal := Body.GetValue('Title');
                if (TitleVal<>nil) and (not (TitleVal is TJSONNull)) then It.Title := TitleVal.Value;

                var ItemTypeVal := Body.GetValue('ItemType');
                if (ItemTypeVal<>nil) and (not (ItemTypeVal is TJSONNull)) then It.ItemType := ItemTypeVal.Value;

                var SubtitleVal := Body.GetValue('Subtitle');
                if (SubtitleVal<>nil) and (not (SubtitleVal is TJSONNull)) then It.Subtitle := SubtitleVal.Value;

                var DescVal := Body.GetValue('Description');
                if (DescVal<>nil) and (not (DescVal is TJSONNull)) then It.Description := DescVal.Value;

                var ImgVal := Body.GetValue('ImageUrl');
                if (ImgVal<>nil) and (not (ImgVal is TJSONNull)) then It.ImageUrl := ImgVal.Value;

                var LinkVal := Body.GetValue('LinkUrl');
                if (LinkVal<>nil) and (not (LinkVal is TJSONNull)) then It.Location := LinkVal.Value;

                var OrderVal := Body.GetValue('DisplayOrder');
                if (OrderVal<>nil) and (not (OrderVal is TJSONNull)) then
                begin
                  if OrderVal is TJSONNumber then It.DisplayOrder := TJSONNumber(OrderVal).AsInt else It.DisplayOrder := StrToIntDef(OrderVal.Value, It.DisplayOrder);
                end;

                var UpdIt := TInfoBoardItemRepository.UpdateItem(It.Id, It.ItemType, It.Title, It.Subtitle, It.Description, It.ImageUrl, It.IconEmoji, It.Location, It.ContactInfo, It.QrCodeUrl, It.MapPositionJson, It.TagsJson, It.HighlightColor, It.DisplayOrder, It.IsVisible);
                try
                  var O := TJSONObject.Create;
                  O.AddPair('Id', TJSONNumber.Create(UpdIt.Id));
                  O.AddPair('SectionId', TJSONNumber.Create(UpdIt.SectionId));
                  O.AddPair('ItemType', UpdIt.ItemType);
                  O.AddPair('Title', UpdIt.Title);
                  if Trim(UpdIt.Subtitle)<>'' then O.AddPair('Subtitle', UpdIt.Subtitle) else O.AddPair('Subtitle', TJSONNull.Create);
                  if Trim(UpdIt.Description)<>'' then O.AddPair('Description', UpdIt.Description) else O.AddPair('Description', TJSONNull.Create);
                  if Trim(UpdIt.ImageUrl)<>'' then O.AddPair('ImageUrl', UpdIt.ImageUrl) else O.AddPair('ImageUrl', TJSONNull.Create);
                  if Trim(UpdIt.Location)<>'' then O.AddPair('LinkUrl', UpdIt.Location) else O.AddPair('LinkUrl', TJSONNull.Create);
                  O.AddPair('DisplayOrder', TJSONNumber.Create(UpdIt.DisplayOrder));
                  Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := O.ToJSON; Response.SendResponse;
                  O.Free;
                finally UpdIt.Free; end;
              finally Body.Free; end;
              Exit;
            end
            else if SameText(Request.Method,'DELETE') then
            begin
              TInfoBoardItemRepository.DeleteItem(ItemId);
              Response.StatusCode := 204; Response.ContentType := 'application/json'; Response.Content := ''; Response.SendResponse;
              Exit;
            end;
          finally B.Free; end;
        finally S.Free; end;
      finally It.Free; end;
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
                var O := TJSONObject.Create;
                O.AddPair('Id', TJSONNumber.Create(Itm.Id));
                O.AddPair('ItemType', Itm.ItemType);
                if Itm.MediaFileId>0 then O.AddPair('MediaFileId', TJSONNumber.Create(Itm.MediaFileId)) else O.AddPair('MediaFileId', TJSONNull.Create);
                if Itm.MenuId>0 then O.AddPair('MenuId', TJSONNumber.Create(Itm.MenuId)) else O.AddPair('MenuId', TJSONNull.Create);
                O.AddPair('DisplayOrder', TJSONNumber.Create(Itm.DisplayOrder));
                O.AddPair('Duration', TJSONNumber.Create(Itm.Duration));
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
          if TryReplayIdempotency(Camp.OrganizationId) then Exit;
          var Body := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject; try
            if Body=nil then begin JSONError(400,'Invalid JSON'); Exit; end;
            var ItemType := Body.GetValue<string>('ItemType','media');
            var MediaFileId := Body.GetValue<Integer>('MediaFileId',0);
            var MenuId := Body.GetValue<Integer>('MenuId',0);
            var DisplayOrder := Body.GetValue<Integer>('DisplayOrder',0);
            var Duration := Body.GetValue<Integer>('Duration',0);
            if SameText(ItemType,'menu') then
            begin
              if MenuId=0 then begin JSONError(400,'Missing MenuId'); Exit; end;
              MediaFileId := 0;
            end
            else
            begin
              ItemType := 'media';
              if MediaFileId=0 then begin JSONError(400,'Missing MediaFileId'); Exit; end;
              MenuId := 0;
            end;

            var Itm := TCampaignItemRepository.CreateItem(CampId, ItemType, MediaFileId, MenuId, DisplayOrder, Duration);
            try
              var O := TJSONObject.Create;
              O.AddPair('Id', TJSONNumber.Create(Itm.Id));
              O.AddPair('ItemType', Itm.ItemType);
              if Itm.MediaFileId>0 then O.AddPair('MediaFileId', TJSONNumber.Create(Itm.MediaFileId)) else O.AddPair('MediaFileId', TJSONNull.Create);
              if Itm.MenuId>0 then O.AddPair('MenuId', TJSONNumber.Create(Itm.MenuId)) else O.AddPair('MenuId', TJSONNull.Create);
              O.AddPair('DisplayOrder', TJSONNumber.Create(Itm.DisplayOrder));
              O.AddPair('Duration', TJSONNumber.Create(Itm.Duration));
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
        var O := TJSONObject.Create;
        O.AddPair('Id', TJSONNumber.Create(Itm.Id));
        O.AddPair('ItemType', Itm.ItemType);
        if Itm.MediaFileId>0 then O.AddPair('MediaFileId', TJSONNumber.Create(Itm.MediaFileId)) else O.AddPair('MediaFileId', TJSONNull.Create);
        if Itm.MenuId>0 then O.AddPair('MenuId', TJSONNumber.Create(Itm.MenuId)) else O.AddPair('MenuId', TJSONNull.Create);
        O.AddPair('DisplayOrder', TJSONNumber.Create(Itm.DisplayOrder));
        O.AddPair('Duration', TJSONNumber.Create(Itm.Duration));
          Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := O.ToJSON; Response.SendResponse; O.Free;
        Exit;
      end
      else if SameText(Request.Method,'PUT') then
      begin
        var Body := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject; try
          if Body=nil then begin JSONError(400,'Invalid JSON'); Exit; end;
          var ItemType := Body.GetValue<string>('ItemType', Itm0.ItemType);
          if ItemType='' then ItemType := 'media';
          var MediaFileId := Body.GetValue<Integer>('MediaFileId',0);
          var MenuId := Body.GetValue<Integer>('MenuId',0);
          var DisplayOrder := Body.GetValue<Integer>('DisplayOrder',0);
          var Duration := Body.GetValue<Integer>('Duration',0);
          if SameText(ItemType,'menu') then
          begin
            if MenuId=0 then begin JSONError(400,'Missing MenuId'); Exit; end;
            MediaFileId := 0;
          end
          else if SameText(ItemType,'media') then
          begin
            if MediaFileId=0 then begin JSONError(400,'Missing MediaFileId'); Exit; end;
            MenuId := 0;
          end
          else
          begin
            JSONError(400,'Invalid ItemType');
            Exit;
          end;

          var Itm := TCampaignItemRepository.UpdateItem(Id, ItemType, MediaFileId, MenuId, DisplayOrder, Duration);
          if Itm=nil then begin JSONError(404,'Not found'); Exit; end;
          try
            var O := TJSONObject.Create;
            O.AddPair('Id', TJSONNumber.Create(Itm.Id));
            O.AddPair('ItemType', Itm.ItemType);
            if Itm.MediaFileId>0 then O.AddPair('MediaFileId', TJSONNumber.Create(Itm.MediaFileId)) else O.AddPair('MediaFileId', TJSONNull.Create);
            if Itm.MenuId>0 then O.AddPair('MenuId', TJSONNumber.Create(Itm.MenuId)) else O.AddPair('MenuId', TJSONNull.Create);
            O.AddPair('DisplayOrder', TJSONNumber.Create(Itm.DisplayOrder));
            O.AddPair('Duration', TJSONNumber.Create(Itm.Duration));
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

    // Public: resolve a media file to a signed download URL scoped by a menu public token.
    // This allows menu boards to reference private media without making the entire bucket public.
    // GET /public/menus/{token}/media-files/{id}/download-url
    if (Copy(PathInfo, 1, 14) = '/public/menus/') and (Pos('/media-files/', PathInfo) > 0) and (Pos('/download-url', PathInfo) > 0) and
       SameText(Request.Method, 'GET') then
    begin
      var Tail := Copy(PathInfo, 15, MaxInt); // {token}/media-files/{id}/download-url
      var Slash := Pos('/', Tail);
      if Slash = 0 then begin JSONError(400,'Invalid token'); Exit; end;
      var PublicToken := Copy(Tail, 1, Slash-1);
      var Rest := Copy(Tail, Slash+1, MaxInt);
      if Copy(Rest, 1, 12) <> 'media-files/' then begin JSONError(400,'Invalid path'); Exit; end;
      Rest := Copy(Rest, 13, MaxInt); // {id}/download-url
      Slash := Pos('/', Rest);
      if Slash = 0 then begin JSONError(400,'Invalid media id'); Exit; end;
      var IdStr := Copy(Rest, 1, Slash-1);
      var MediaId := StrToIntDef(IdStr, 0);
      if MediaId = 0 then begin JSONError(400,'Invalid media id'); Exit; end;

      var M := TMenuRepository.GetByPublicToken(PublicToken);
      if M = nil then begin JSONError(404,'Not found'); Exit; end;
      try
        var MF := TMediaFileRepository.GetById(MediaId);
        if MF = nil then begin JSONError(404,'Not found'); Exit; end;
        try
          if MF.OrganizationId <> M.OrganizationId then begin JSONError(403,'Forbidden'); Exit; end;

          var InternalEndpoint := GetEnv('MINIO_ENDPOINT','http://minio:9000');
          var PublicEndpoint := GetEnv('MINIO_PUBLIC_ENDPOINT','');
          // If not configured, infer from the incoming request (supports multiple domains and local dev).
          if PublicEndpoint = '' then
          begin
            var ReqProto := Request.GetFieldByName('X-Forwarded-Proto');
            if ReqProto = '' then ReqProto := 'http';
            var ReqHost := Request.GetFieldByName('X-Forwarded-Host');
            if ReqHost = '' then ReqHost := Request.GetFieldByName('Host');
            if ReqHost <> '' then PublicEndpoint := ReqProto + '://' + ReqHost + '/minio';
          end;
          if PublicEndpoint = '' then PublicEndpoint := InternalEndpoint;

          var Access := GetEnv('MINIO_ACCESS_KEY','minioadmin');
          var Secret := GetEnv('MINIO_SECRET_KEY','minioadmin');
          var Region := GetEnv('MINIO_REGION','us-east-1');

          // Parse bucket/key from StorageURL (supports both internal and public endpoints)
          var Path := Trim(MF.StorageURL);
          if Path='' then begin JSONError(400,'Missing storage path'); Exit; end;
          if Path.StartsWith(PublicEndpoint) then
            Path := Copy(Path, Length(PublicEndpoint)+1, MaxInt)
          else if Path.StartsWith(InternalEndpoint) then
            Path := Copy(Path, Length(InternalEndpoint)+1, MaxInt);
          if (Length(Path)>0) and (Path[1]='/') then Path := Copy(Path,2,MaxInt);

          // Backward-compat: StorageURL may include a reverse-proxy prefix (e.g. https://api.../minio/{bucket}/{key}).
          // If endpoint stripping didn't remove it, strip a leading "minio/" segment before bucket/key parsing.
          if (Length(Path) >= 6) and SameText(Copy(Path, 1, 6), 'minio/') then
            Path := Copy(Path, 7, MaxInt);
          var SchemePos := Pos('://', Path);
          if SchemePos>0 then
          begin
            var HostEndIdx := SchemePos + 3;
            var SlashAfterHost := 0;
            var i := HostEndIdx;
            while i <= Length(Path) do begin if Path[i]='/' then begin SlashAfterHost := i; Break; end; Inc(i); end;
            if SlashAfterHost>0 then Path := Copy(Path, SlashAfterHost+1, MaxInt);
          end;

          if (Length(Path) >= 6) and SameText(Copy(Path, 1, 6), 'minio/') then
            Path := Copy(Path, 7, MaxInt);
          var p := Pos('/', Path);
          if p=0 then begin JSONError(400,'Invalid storage path'); Exit; end;
          var Bucket := Copy(Path,1,p-1);
          var Key := Copy(Path,p+1, MaxInt);
          if (Bucket='') or (Key='') then begin JSONError(400,'Invalid storage path'); Exit; end;

          var Params: TS3PresignParams;
          Params.Endpoint:=PublicEndpoint;
          Params.Region:=Region;
          Params.Bucket:=Bucket;
          Params.ObjectKey:=Key;
          Params.AccessKey:=Access;
          Params.SecretKey:=Secret;
          Params.Method:='GET';
          Params.ExpiresSeconds:=900;
          var Url: string;
          if not BuildS3PresignedUrl(Params, Url) then begin JSONError(500,'Failed to generate URL'); Exit; end;

          var Obj := TJSONObject.Create;
          Obj.AddPair('DownloadUrl', Url);
          Obj.AddPair('Success', TJSONBool.Create(True));
          Obj.AddPair('Message', '');
          Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := Obj.ToJSON; Response.SendResponse; Obj.Free;
        finally MF.Free; end;
      finally M.Free; end;
      Exit;
    end;

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
        var PublicEndpoint := GetEnv('MINIO_PUBLIC_ENDPOINT','');
        // If not configured, infer from the incoming request (supports multiple domains and local dev).
        if PublicEndpoint = '' then
        begin
          var ReqProto := Request.GetFieldByName('X-Forwarded-Proto');
          if ReqProto = '' then ReqProto := 'http';
          var ReqHost := Request.GetFieldByName('X-Forwarded-Host');
          if ReqHost = '' then ReqHost := Request.GetFieldByName('Host');
          if ReqHost <> '' then PublicEndpoint := ReqProto + '://' + ReqHost + '/minio';
        end;
        // Prefer inferred endpoint when running under localhost but a fixed prod URL is configured.
        var HostHdr := Request.GetFieldByName('Host');
        if (HostHdr <> '') and (Pos('localhost', LowerCase(HostHdr)) > 0) and (Pos(HostHdr, PublicEndpoint) = 0) then
        begin
          var ReqProto := Request.GetFieldByName('X-Forwarded-Proto');
          if ReqProto = '' then ReqProto := 'http';
          PublicEndpoint := ReqProto + '://' + HostHdr + '/minio';
        end;
        if PublicEndpoint = '' then PublicEndpoint := InternalEndpoint;
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
        var PublicEndpoint := GetEnv('MINIO_PUBLIC_ENDPOINT','');
        if PublicEndpoint = '' then
        begin
          var ReqProto := Request.GetFieldByName('X-Forwarded-Proto');
          if ReqProto = '' then ReqProto := 'http';
          var ReqHost := Request.GetFieldByName('X-Forwarded-Host');
          if ReqHost = '' then ReqHost := Request.GetFieldByName('Host');
          if ReqHost <> '' then PublicEndpoint := ReqProto + '://' + ReqHost + '/minio';
        end;
        var HostHdr := Request.GetFieldByName('Host');
        if (HostHdr <> '') and (Pos('localhost', LowerCase(HostHdr)) > 0) and (Pos(HostHdr, PublicEndpoint) = 0) then
        begin
          var ReqProto := Request.GetFieldByName('X-Forwarded-Proto');
          if ReqProto = '' then ReqProto := 'http';
          PublicEndpoint := ReqProto + '://' + HostHdr + '/minio';
        end;
        if PublicEndpoint = '' then PublicEndpoint := InternalEndpoint;
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

        // Backward-compat: StorageURL may include a reverse-proxy prefix (e.g. https://api.../minio/{bucket}/{key}).
        if (Length(Path) >= 6) and SameText(Copy(Path, 1, 6), 'minio/') then
          Path := Copy(Path, 7, MaxInt);
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

        if (Length(Path) >= 6) and SameText(Copy(Path, 1, 6), 'minio/') then
          Path := Copy(Path, 7, MaxInt);
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

          // If we have playback logs, return the actual last played item.
          if not Q.Eof then
          begin
            var O := TJSONObject.Create; try
              O.AddPair('ItemType', 'media');
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
            Exit;
          end;
        finally Q.Free; end;

        // Fallback: no proof-of-play yet. Return assigned menu/campaign so the dashboard can still show intent.
        // Try menu first (menus and campaigns are mutually exclusive by enforcement).
        var Qm := TFDQuery.Create(nil);
        try
          Qm.Connection := C;
          Qm.SQL.Text := 'select m.MenuID, m.Name, m.PublicToken from DisplayMenus dm join Menus m on m.MenuID=dm.MenuID ' +
                        'where dm.DisplayID=:D and dm.IsPrimary=true order by dm.DisplayMenuID desc limit 1';
          Qm.ParamByName('D').AsInteger := DisplayId;
          Qm.Open;
          if not Qm.Eof then
          begin
            var O := TJSONObject.Create;
            try
              O.AddPair('ItemType', 'menu');
              O.AddPair('DisplayId', TJSONNumber.Create(DisplayId));
              O.AddPair('MenuId', TJSONNumber.Create(Qm.FieldByName('MenuID').AsInteger));
              O.AddPair('MenuName', Qm.FieldByName('Name').AsString);
              O.AddPair('MenuPublicToken', Qm.FieldByName('PublicToken').AsString);
              O.AddPair('CampaignId', TJSONNull.Create);
              O.AddPair('CampaignName', TJSONNull.Create);
              O.AddPair('MediaFileId', TJSONNull.Create);
              O.AddPair('MediaFileName', TJSONNull.Create);
              O.AddPair('MediaFileType', TJSONNull.Create);
              O.AddPair('PlaybackTimestamp', TJSONNull.Create);
              O.AddPair('StartedAt', TJSONNull.Create);
              Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := O.ToJSON; Response.SendResponse;
            finally
              O.Free;
            end;
            Exit;
          end;
        finally
          Qm.Free;
        end;

        // Try primary campaign + first media item
        var Qc := TFDQuery.Create(nil);
        try
          Qc.Connection := C;
          Qc.SQL.Text := 'select dc.CampaignID, c.Name as CampaignName ' +
                        'from DisplayCampaigns dc join Campaigns c on c.CampaignID=dc.CampaignID ' +
                        'where dc.DisplayID=:D and dc.IsPrimary=true order by dc.DisplayCampaignID desc limit 1';
          Qc.ParamByName('D').AsInteger := DisplayId;
          Qc.Open;
          if Qc.Eof then begin JSONError(404,'No playback yet'); Exit; end;
          var CampId := Qc.FieldByName('CampaignID').AsInteger;
          var CampName := Qc.FieldByName('CampaignName').AsString;

          var Qi := TFDQuery.Create(nil);
          try
            Qi.Connection := C;
            Qi.SQL.Text := 'select ci.MediaFileID, mf.FileName, mf.FileType ' +
                          'from CampaignItems ci left join MediaFiles mf on mf.MediaFileID=ci.MediaFileID ' +
                          'where ci.CampaignID=:C and (ci.ItemType=''media'' or ci.ItemType='''' ) and ci.MediaFileID is not null ' +
                          'order by ci.DisplayOrder asc limit 1';
            Qi.ParamByName('C').AsInteger := CampId;
            Qi.Open;
            if Qi.Eof then begin JSONError(404,'No playback yet'); Exit; end;
            var O := TJSONObject.Create;
            try
              O.AddPair('ItemType', 'media');
              O.AddPair('DisplayId', TJSONNumber.Create(DisplayId));
              O.AddPair('CampaignId', TJSONNumber.Create(CampId));
              O.AddPair('CampaignName', CampName);
              O.AddPair('MediaFileId', TJSONNumber.Create(Qi.FieldByName('MediaFileID').AsInteger));
              O.AddPair('MediaFileName', Qi.FieldByName('FileName').AsString);
              O.AddPair('MediaFileType', Qi.FieldByName('FileType').AsString);
              O.AddPair('PlaybackTimestamp', TJSONNull.Create);
              O.AddPair('StartedAt', TJSONNull.Create);
              Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := O.ToJSON; Response.SendResponse;
            finally
              O.Free;
            end;
            Exit;
          finally
            Qi.Free;
          end;
        finally
          Qc.Free;
        end;
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
  var Obj := TJSONObject.Create;
  try
    Obj.AddPair('value', 'OK');
    Obj.AddPair('EmailConfigured', TJSONBool.Create(GetEnvironmentVariable('SMTP_HOST') <> ''));
    Obj.AddPair('PublicWebUrlConfigured', TJSONBool.Create(GetEnvironmentVariable('PUBLIC_WEB_URL') <> ''));
    Response.Content := Obj.ToJSON;
  finally
    Obj.Free;
  end;
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

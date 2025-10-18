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

// No DFM used; we configure routes manually in DefaultHandlerAction

uses
  System.Generics.Collections, System.StrUtils, System.Net.URLClient, Web.WebReq,
  System.DateUtils,
  FireDAC.Comp.Client, FireDAC.Stan.Param,
  // Repositories & utils
  DisplayRepository,
  CampaignRepository,
  CampaignItemRepository,
  DisplayCampaignRepository,
  MediaFileRepository,
  UserRepository,
  PasswordUtils,
  JWTUtils,
  AWSSigV4,
  ProvisioningTokenRepository,
  uServerContainer,
  System.Hash; // for THashSHA2

constructor TWebModule1.Create(AOwner: TComponent);
var
  Action: TWebActionItem;
begin
  inherited Create(AOwner);
  // Since no DFM is used, create a default action that delegates to our handler
  Action := Actions.Add;
  Action.Name := 'Default';
  Action.Default := True;
  Action.OnAction := DefaultHandlerAction;
end;

procedure TWebModule1.DefaultHandlerAction(Sender: TObject; Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
  // Local helper to reply 501 for yet-to-be-implemented endpoints
  procedure NotImpl(const Feature: string);
  begin
    Response.StatusCode := 501; // Not Implemented
    Response.ContentType := 'application/json';
    Response.Content := '{"message":"Not Implemented: ' + StringReplace(Feature, '"', '\"', [rfReplaceAll]) + '"}';
    Response.SendResponse;
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
  function JSONError(Code: Integer; const Msg: string): Boolean;
  begin
    Response.StatusCode := Code;
    Response.ContentType := 'application/json';
    Response.Content := '{"message":"' + StringReplace(Msg, '"', '\"', [rfReplaceAll]) + '"}';
    Response.SendResponse;
    Result := True;
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
  function RequireJWT(out OrgId: Integer; out UserId: Integer; out Role: string): Boolean;
  var H, RawToken, QueryToken, TryToken: string; Parts: TArray<string>; Payload: TJSONObject; Secret: string;
  begin
    Result := False; OrgId := 0; UserId := 0; Role := '';
    H := Request.GetFieldByName('Authorization');
      if (H<>'') and H.StartsWith('Bearer ') then
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
        Writeln(Format('RequireJWT Authorization="%s" X-Auth-Token="%s" RawToken="%s"',
          [H, Request.GetFieldByName('X-Auth-Token'), RawToken]));
    QueryToken := Request.QueryFields.Values['access_token'];
    // sanitize
    RawToken := CleanToken(RawToken);
    QueryToken := CleanToken(QueryToken);
    if RawToken='' then RawToken := QueryToken;
    if RawToken='' then begin JSONError(401,'Unauthorized'); Exit; end;
    Parts := RawToken.Split([' ']);
    Secret := GetEnv('JWT_SECRET','changeme');
    TryToken := Parts[0];
    if not VerifyJWT(TryToken, Secret, Payload) then
    begin
      // Try the query token fallback in case header was mangled by client
      if (QueryToken<>'') then
      begin
        if not VerifyJWT(QueryToken, Secret, Payload) then begin JSONError(401,'Invalid token'); Exit; end;
      end
      else begin JSONError(401,'Invalid token'); Exit; end;
    end;
    try
      OrgId := Payload.GetValue<Integer>('org',0);
      UserId := Payload.GetValue<Integer>('sub',0);
      Role := Payload.GetValue<string>('role','');
      var NowSec := DateTimeToUnix(Now, False);
      if Payload.GetValue<Integer>('exp', NowSec) < NowSec then begin JSONError(401,'Token expired'); Exit; end;
    finally
      Payload.Free;
    end;
    Result := True;
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
begin

  Handled := True;
  try
    if SameText(Request.PathInfo, '/health') and SameText(Request.Method, 'GET') then
    begin
      HandleHealth(Response);
      Response.SendResponse;
      Exit;
    end;

    if DebugEnabled and SameText(Request.PathInfo, '/debug/headers') and SameText(Request.Method,'GET') then
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

    if (Request.PathInfo = '/organizations') then
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
    if (Copy(Request.PathInfo, 1, 15) = '/organizations/') and SameText(Request.Method, 'GET') and
       (Pos('/', Copy(Request.PathInfo, 16, MaxInt)) = 0) then
    begin
      HandleOrganizationById(Request, Response);
      Exit;
    end;

    // ----- Auth -----
    if SameText(Request.PathInfo, '/auth/register') and SameText(Request.Method, 'POST') then
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
    if SameText(Request.PathInfo, '/auth/login') and SameText(Request.Method, 'POST') then
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
    if DebugEnabled and SameText(Request.PathInfo, '/auth/debug-verify') and SameText(Request.Method, 'POST') then
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

    // Plans and Roles
    if SameText(Request.PathInfo, '/plans') and SameText(Request.Method, 'GET') then
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
    if SameText(Request.PathInfo, '/roles') and SameText(Request.Method, 'GET') then
    begin
      var Arr := TJSONArray.Create; try
        Arr.Add('Owner'); Arr.Add('ContentManager'); Arr.Add('Viewer');
        Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := Arr.ToJSON; Response.SendResponse;
      finally Arr.Free; end;
      Exit;
    end;

    // Organization sub-resources
    if (Copy(Request.PathInfo, 1, 15) = '/organizations/') and SameText(Request.Method, 'GET') and
       (Pos('/subscription', Request.PathInfo) > 0) then
    begin
      // /organizations/{OrganizationId}/subscription
      var OrgIdStr := Copy(Request.PathInfo, 16, MaxInt);
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
    if (Copy(Request.PathInfo, 1, 15) = '/organizations/') and
       (Pos('/displays', Request.PathInfo) > 0) then
    begin
      // /organizations/{orgId}/displays
      var OrgIdStr := Copy(Request.PathInfo, 16, MaxInt);
      var Slash := Pos('/', OrgIdStr);
      if Slash>0 then OrgIdStr := Copy(OrgIdStr, 1, Slash-1);
      var OrgId := StrToIntDef(OrgIdStr,0);
      if OrgId=0 then begin JSONError(400,'Invalid organization id'); Exit; end;
      // Enforce auth for org-scoped writes
      if SameText(Request.Method,'GET') then
      begin
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
        if not RequireJWT(TokOrg, TokUser, TokRole) then Exit;
        if TokOrg<>OrgId then begin JSONError(403,'Forbidden'); Exit; end;
        if not CheckPlanAllowsDisplay(OrgId) then begin JSONError(402,'Display limit reached for plan'); Exit; end;
        var Body := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject;
        try
          if Body=nil then begin JSONError(400,'Invalid JSON'); Exit; end;
          var Name := Body.GetValue<string>('Name','');
          var Orientation := Body.GetValue<string>('Orientation','');
          if (Name='') or (Orientation='') then begin JSONError(400,'Missing fields'); Exit; end;
          var D := TDisplayRepository.CreateDisplay(OrgId, Name, Orientation);
          try
            var Obj := TJSONObject.Create; Obj.AddPair('Id', TJSONNumber.Create(D.Id)); Obj.AddPair('Name', D.Name); Obj.AddPair('Orientation', D.Orientation);
            Response.StatusCode := 201; Response.ContentType := 'application/json'; Response.Content := Obj.ToJSON; Response.SendResponse; Obj.Free;
          finally D.Free; end;
        finally Body.Free; end;
        Exit;
      end;
    end;

    // Device pairing: device asks for ephemeral provisioning token
    if SameText(Request.PathInfo, '/device/provisioning/token') and SameText(Request.Method,'POST') then
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
        var Obj := TJSONObject.Create; Obj.AddPair('ProvisioningToken', Info.Token); Obj.AddPair('ExpiresInSeconds', TJSONNumber.Create(600));
        Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := Obj.ToJSON; Response.SendResponse; Obj.Free;
      finally Body.Free; end;
      Exit;
    end;

    // Account-side claiming: link a device provisioning token to an organization (via JWT org)
    if (Copy(Request.PathInfo,1,15) = '/organizations/') and (Pos('/displays/claim', Request.PathInfo)>0) and SameText(Request.Method,'POST') then
    begin
      var OrgIdStr := Copy(Request.PathInfo, 16, MaxInt); var Slash := Pos('/', OrgIdStr); if Slash>0 then OrgIdStr := Copy(OrgIdStr,1,Slash-1);
      var OrgId := StrToIntDef(OrgIdStr,0); if OrgId=0 then begin JSONError(400,'Invalid organization id'); Exit; end;
      var TokOrg, TokUser: Integer; var TokRole: string;
      if not RequireJWT(TokOrg, TokUser, TokRole) then Exit;
      if TokOrg<>OrgId then begin JSONError(403,'Forbidden'); Exit; end;
      if not CheckPlanAllowsDisplay(OrgId) then begin JSONError(402,'Display limit reached for plan'); Exit; end;
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
            Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := Obj.ToJSON; Response.SendResponse; Obj.Free;
          finally D.Free; end;
        finally C.Free; end;
      finally Body.Free; end;
      Exit;
    end;

    // Organization campaigns: /organizations/{OrganizationId}/campaigns
    if (Copy(Request.PathInfo, 1, 15) = '/organizations/') and
       (Pos('/campaigns', Request.PathInfo) > 0) then
    begin
      var OrgIdStr := Copy(Request.PathInfo, 16, MaxInt);
      var Slash := Pos('/', OrgIdStr); if Slash>0 then OrgIdStr := Copy(OrgIdStr, 1, Slash-1);
      var OrgId := StrToIntDef(OrgIdStr,0); if OrgId=0 then begin JSONError(400,'Invalid organization id'); Exit; end;
      if SameText(Request.Method,'GET') then
      begin
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
        var Body := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject; try
          if Body=nil then begin JSONError(400,'Invalid JSON'); Exit; end;
          var Name := Body.GetValue<string>('Name',''); var Orientation := Body.GetValue<string>('Orientation','');
          if Name='' then begin JSONError(400,'Missing Name'); Exit; end;
          var Cmp := TCampaignRepository.CreateCampaign(OrgId, Name, Orientation);
          try
            var O := TJSONObject.Create; O.AddPair('Id', TJSONNumber.Create(Cmp.Id)); O.AddPair('OrganizationId', TJSONNumber.Create(Cmp.OrganizationId)); O.AddPair('Name', Cmp.Name); O.AddPair('Orientation', Cmp.Orientation);
            Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := O.ToJSON; Response.SendResponse; O.Free;
          finally Cmp.Free; end;
        finally Body.Free; end; Exit;
      end;
    end;

    // Displays
    if (Copy(Request.PathInfo, 1, 10) = '/displays/') then
    begin
      var Tail := Copy(Request.PathInfo, 11, MaxInt);
      var NextSlash := Pos('/', Tail);
      var IdStr := Tail; if NextSlash>0 then IdStr := Copy(Tail,1,NextSlash-1);
      var Id := StrToIntDef(IdStr,0);
      if (Id=0) then begin JSONError(400,'Invalid display id'); Exit; end;
      if Pos('/campaign-assignments', Request.PathInfo) > 0 then
      begin
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
          var Body := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject;
          try
            if Body=nil then begin JSONError(400,'Invalid JSON'); Exit; end;
            var CampaignId := Body.GetValue<Integer>('CampaignId',0);
            var IsPrimary := Body.GetValue<Boolean>('IsPrimary',True);
            if CampaignId=0 then begin JSONError(400,'Missing CampaignId'); Exit; end;
            var A := TDisplayCampaignRepository.CreateAssignment(Id, CampaignId, IsPrimary);
            try
              var Obj := TJSONObject.Create; Obj.AddPair('Id', TJSONNumber.Create(A.Id)); Obj.AddPair('CampaignId', TJSONNumber.Create(A.CampaignId)); Obj.AddPair('IsPrimary', TJSONBool.Create(A.IsPrimary));
              Response.StatusCode := 201; Response.ContentType := 'application/json'; Response.Content := Obj.ToJSON; Response.SendResponse; Obj.Free;
            finally A.Free; end;
          finally Body.Free; end;
          Exit;
        end;
      end
      else
      begin
        if SameText(Request.Method,'GET') then
        begin
          var D := TDisplayRepository.GetById(Id);
          if D=nil then begin JSONError(404,'Not found'); Exit; end;
          try
            var Obj := TJSONObject.Create; Obj.AddPair('Id', TJSONNumber.Create(D.Id)); Obj.AddPair('Name', D.Name); Obj.AddPair('Orientation', D.Orientation);
            Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := Obj.ToJSON; Response.SendResponse; Obj.Free;
          finally D.Free; end;
          Exit;
        end
        else if SameText(Request.Method,'PUT') then
        begin
          var Body := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject; try
            if Body=nil then begin JSONError(400,'Invalid JSON'); Exit; end;
            var Name := Body.GetValue<string>('Name',''); var Orientation := Body.GetValue<string>('Orientation','');
            if (Name='') or (Orientation='') then begin JSONError(400,'Missing fields'); Exit; end;
            var D := TDisplayRepository.UpdateDisplay(Id, Name, Orientation);
            if D=nil then begin JSONError(404,'Not found'); Exit; end;
            try
              var Obj := TJSONObject.Create; Obj.AddPair('Id', TJSONNumber.Create(D.Id)); Obj.AddPair('Name', D.Name); Obj.AddPair('Orientation', D.Orientation);
              Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := Obj.ToJSON; Response.SendResponse; Obj.Free;
            finally D.Free; end;
          finally Body.Free; end;
          Exit;
        end
        else if SameText(Request.Method,'DELETE') then
        begin
          TDisplayRepository.DeleteDisplay(Id);
          Response.StatusCode := 204; Response.ContentType := 'application/json'; Response.Content := ''; Response.SendResponse; Exit;
        end;
      end;
    end;

    // Campaigns and items
    if (Copy(Request.PathInfo, 1, 11) = '/campaigns/') then
    begin
      if Pos('/items', Request.PathInfo) > 0 then
      begin
        var IdStr := Copy(Request.PathInfo, 12, MaxInt);
        var Slash := Pos('/', IdStr); if Slash>0 then IdStr := Copy(IdStr,1,Slash-1);
        var CampId := StrToIntDef(IdStr,0); if CampId=0 then begin JSONError(400,'Invalid campaign id'); Exit; end;
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
          var Body := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject; try
            if Body=nil then begin JSONError(400,'Invalid JSON'); Exit; end;
            var MediaFileId := Body.GetValue<Integer>('MediaFileId',0);
            var DisplayOrder := Body.GetValue<Integer>('DisplayOrder',0);
            var Duration := Body.GetValue<Integer>('Duration',0);
            if MediaFileId=0 then begin JSONError(400,'Missing MediaFileId'); Exit; end;
            var Itm := TCampaignItemRepository.CreateItem(CampId, MediaFileId, DisplayOrder, Duration);
            try
              var O := TJSONObject.Create; O.AddPair('Id', TJSONNumber.Create(Itm.Id)); O.AddPair('MediaFileId', TJSONNumber.Create(Itm.MediaFileId)); O.AddPair('DisplayOrder', TJSONNumber.Create(Itm.DisplayOrder)); O.AddPair('Duration', TJSONNumber.Create(Itm.Duration));
              Response.StatusCode := 201; Response.ContentType := 'application/json'; Response.Content := O.ToJSON; Response.SendResponse; O.Free;
            finally Itm.Free; end;
          finally Body.Free; end; Exit;
        end;
      end
      else if (SameText(Request.Method, 'GET') or SameText(Request.Method, 'PUT') or SameText(Request.Method, 'DELETE')) then
      begin
        var IdStr := Copy(Request.PathInfo, 12, MaxInt);
        var Id := StrToIntDef(IdStr,0); if Id=0 then begin JSONError(400,'Invalid campaign id'); Exit; end;
        if SameText(Request.Method,'GET') then
        begin
          var Cmp := TCampaignRepository.GetById(Id); if Cmp=nil then begin JSONError(404,'Not found'); Exit; end;
          try var O := TJSONObject.Create; O.AddPair('Id', TJSONNumber.Create(Cmp.Id)); O.AddPair('Name', Cmp.Name); O.AddPair('Orientation', Cmp.Orientation);
            Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := O.ToJSON; Response.SendResponse; O.Free;
          finally Cmp.Free; end; Exit;
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
      end;
    end;

    if (Copy(Request.PathInfo, 1, 16) = '/campaign-items/') then
    begin
      var IdStr := Copy(Request.PathInfo, 17, MaxInt);
      var Id := StrToIntDef(IdStr,0); if Id=0 then begin JSONError(400,'Invalid campaign item id'); Exit; end;
      if SameText(Request.Method,'GET') then
      begin
        var Itm := TCampaignItemRepository.GetById(Id); if Itm=nil then begin JSONError(404,'Not found'); Exit; end;
        try var O := TJSONObject.Create; O.AddPair('Id', TJSONNumber.Create(Itm.Id)); O.AddPair('MediaFileId', TJSONNumber.Create(Itm.MediaFileId)); O.AddPair('DisplayOrder', TJSONNumber.Create(Itm.DisplayOrder)); O.AddPair('Duration', TJSONNumber.Create(Itm.Duration));
          Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := O.ToJSON; Response.SendResponse; O.Free;
        finally Itm.Free; end; Exit;
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
    end;

    if (Copy(Request.PathInfo, 1, 22) = '/campaign-assignments/') then
    begin
      var IdStr := Copy(Request.PathInfo, 23, MaxInt);
      var Id := StrToIntDef(IdStr,0); if Id=0 then begin JSONError(400,'Invalid assignment id'); Exit; end;
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
    end;

    // Media files presigned URLs
    if SameText(Request.PathInfo, '/media-files/upload-url') and SameText(Request.Method, 'POST') then
    begin
      var Body := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject; try
        if Body=nil then begin JSONError(400,'Invalid JSON'); Exit; end;
        var OrgId := Body.GetValue<Integer>('OrganizationId',0);
        var FileName := Body.GetValue<string>('FileName','');
        var FileType := Body.GetValue<string>('FileType','application/octet-stream');
        if (OrgId=0) or (FileName='') then begin JSONError(400,'Missing fields'); Exit; end;
        var Bucket := GetEnv('MINIO_BUCKET','displaydeck');
        var Endpoint := GetEnv('MINIO_ENDPOINT','http://minio:9000');
        var Access := GetEnv('MINIO_ACCESS_KEY','minioadmin');
        var Secret := GetEnv('MINIO_SECRET_KEY','minioadmin');
        var Region := GetEnv('MINIO_REGION','us-east-1');
        var Key := Format('org/%d/%s/%s',[OrgId, FormatDateTime('yyyymmddhhnnsszz', Now), FileName]);
        var Params: TS3PresignParams; Params.Endpoint:=Endpoint; Params.Region:=Region; Params.Bucket:=Bucket; Params.ObjectKey:=Key; Params.AccessKey:=Access; Params.SecretKey:=Secret; Params.Method:='PUT'; Params.ExpiresSeconds:=900;
        var Url: string; if not BuildS3PresignedUrl(Params, Url) then begin JSONError(500,'Failed to generate URL'); Exit; end;
        var StorageURL := Endpoint.TrimRight(['/']) + '/' + Bucket + '/' + Key;
        var MF := TMediaFileRepository.CreateMedia(OrgId, FileName, FileType, StorageURL);
        try
          var Obj := TJSONObject.Create;
          Obj.AddPair('MediaFileId', TJSONNumber.Create(MF.Id));
          Obj.AddPair('UploadUrl', Url);
          Obj.AddPair('StorageKey', Key);
          Obj.AddPair('Success', TJSONBool.Create(True));
          Obj.AddPair('Message', '');
          Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := Obj.ToJSON; Response.SendResponse; Obj.Free;
        finally MF.Free; end;
      finally Body.Free; end;
      Exit;
    end;
    if (Copy(Request.PathInfo, 1, 13) = '/media-files/') and (Pos('/download-url', Request.PathInfo) > 0) and
       SameText(Request.Method, 'GET') then
    begin
      // /media-files/{id}/download-url
      var Tail := Copy(Request.PathInfo, 14, MaxInt);
      var IdStr := Copy(Tail, 1, Pos('/', Tail)-1);
      var Id := StrToIntDef(IdStr,0); if Id=0 then begin JSONError(400,'Invalid media id'); Exit; end;
      var MF := TMediaFileRepository.GetById(Id); if MF=nil then begin JSONError(404,'Not found'); Exit; end;
      try
        var Endpoint := GetEnv('MINIO_ENDPOINT','http://minio:9000');
        var Access := GetEnv('MINIO_ACCESS_KEY','minioadmin');
        var Secret := GetEnv('MINIO_SECRET_KEY','minioadmin');
        var Region := GetEnv('MINIO_REGION','us-east-1');
        // Parse bucket/key from StorageURL of form endpoint/bucket/key
        var Path := MF.StorageURL;
        if Path.StartsWith(Endpoint) then Path := Copy(Path, Length(Endpoint)+1, MaxInt);
        if (Length(Path)>0) and (Path[1]='/') then Path := Copy(Path,2,MaxInt);
        var p := Pos('/', Path); var Bucket := Copy(Path,1,p-1); var Key := Copy(Path,p+1, MaxInt);
        var Params: TS3PresignParams; Params.Endpoint:=Endpoint; Params.Region:=Region; Params.Bucket:=Bucket; Params.ObjectKey:=Key; Params.AccessKey:=Access; Params.SecretKey:=Secret; Params.Method:='GET'; Params.ExpiresSeconds:=900;
        var Url: string; if not BuildS3PresignedUrl(Params, Url) then begin JSONError(500,'Failed to generate URL'); Exit; end;
        var Obj := TJSONObject.Create; Obj.AddPair('DownloadUrl', Url); Obj.AddPair('Success', TJSONBool.Create(True)); Obj.AddPair('Message', '');
        Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := Obj.ToJSON; Response.SendResponse; Obj.Free;
      finally MF.Free; end;
      Exit;
    end;

    // Device
    if SameText(Request.PathInfo, '/device/config') and SameText(Request.Method, 'POST') then
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
                for var A in Assigns do
                begin
                  var Camp := TCampaignRepository.GetById(A.CampaignId);
                  if Camp<>nil then
                  try
                    var OC := TJSONObject.Create; OC.AddPair('Id', TJSONNumber.Create(Camp.Id)); OC.AddPair('OrganizationId', TJSONNumber.Create(Camp.OrganizationId)); OC.AddPair('Name', Camp.Name); OC.AddPair('Orientation', Camp.Orientation);
                    ArrC.AddElement(OC);
                  finally Camp.Free; end;
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
    if SameText(Request.PathInfo, '/device/logs') and SameText(Request.Method, 'POST') then
    begin
      // Accept and ack; production would persist device logs in a dedicated table
      var Obj := TJSONObject.Create; Obj.AddPair('Success', TJSONBool.Create(True)); Obj.AddPair('Message','accepted');
      Response.StatusCode := 200; Response.ContentType := 'application/json'; Response.Content := Obj.ToJSON; Response.SendResponse; Obj.Free; Exit;
    end;

    // Playback logs
    if SameText(Request.PathInfo, '/playback-logs') and SameText(Request.Method, 'POST') then
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
  IdStr := Copy(Request.PathInfo, 16, MaxInt);
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

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
  end;

var
  WebModuleClass: TComponentClass = TWebModule1;

implementation

// No DFM used; we configure routes manually in DefaultHandlerAction

uses
  System.Generics.Collections;

procedure TWebModule1.DefaultHandlerAction(Sender: TObject; Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
begin
  Handled := True;
  try
    if SameText(Request.PathInfo, '/health') and SameText(Request.Method, 'GET') then
    begin
      HandleHealth(Response);
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

    if (Copy(Request.PathInfo, 1, 15) = '/organizations/') and SameText(Request.Method, 'GET') then
    begin
      HandleOrganizationById(Request, Response);
      Exit;
    end;

    Response.StatusCode := 404;
    Response.ContentType := 'application/json';
    Response.Content := '{"message":"Not Found"}';
  except
    on E: Exception do
    begin
      Response.StatusCode := 500;
      Response.ContentType := 'application/json';
      Response.Content := '{"message":"' + StringReplace(E.Message, '"', '\"', [rfReplaceAll]) + '"}';
    end;
  end;
end;

procedure TWebModule1.HandleHealth(Response: TWebResponse);
begin
  Response.StatusCode := 200;
  Response.ContentType := 'application/json';
  Response.Content := '{"value":"OK"}';
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
      Response.StatusCode := 200;
      Response.ContentType := 'application/json';
      Response.Content := Arr.ToJSON;
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
    Exit;
  end;

  Org := TOrganizationRepository.GetOrganization(Id);
  if Org = nil then
  begin
    Response.StatusCode := 404;
    Response.ContentType := 'application/json';
    Response.Content := '{"message":"Not found"}';
    Exit;
  end;

  Obj := TJSONObject.Create;
  try
    Obj.AddPair('Id', TJSONNumber.Create(Org.Id));
    Obj.AddPair('Name', Org.Name);
    Response.StatusCode := 200;
    Response.ContentType := 'application/json';
    Response.Content := Obj.ToJSON;
  finally
    Obj.Free;
    Org.Free;
  end;
end;

end.

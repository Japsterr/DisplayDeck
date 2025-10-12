unit AuthServiceTestCases;

interface

uses
  DUnitX.TestFramework,
  AuthService,
  AuthServiceImplementation,
  uEntities,
  FireDAC.Comp.Client,
  System.SysUtils,
  System.Classes;

type

  [TestFixture]
  TAuthServiceTestCases = class(TObject)
  private
    FAuthService: TAuthService;
    FConnection: TFDConnection;
    procedure SetupDatabase;
    procedure CleanupDatabase;
    function GetTestUser: TUser;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure TestRegister_ValidData_ReturnsSuccess;
    [Test]
    procedure TestRegister_DuplicateEmail_ReturnsError;
    [Test]
    procedure TestLogin_ValidCredentials_ReturnsToken;
    [Test]
    procedure TestLogin_InvalidEmail_ReturnsError;
    [Test]
    procedure TestLogin_InvalidPassword_ReturnsError;
    [Test]
    procedure TestPasswordHashing_IsSecure;
  end;

implementation

uses
  uServerContainer;

{ TAuthServiceTestCases }

procedure TAuthServiceTestCases.Setup;
begin
  // Create a test database connection
  FConnection := TFDConnection.Create(nil);
  FConnection.DriverName := 'PG';
  FConnection.Params.Clear;
  FConnection.Params.Add('DriverID=PG');
  FConnection.Params.Add('Server=127.0.0.1');
  FConnection.Params.Add('Port=5432');
  FConnection.Params.Add('Database=displaydeck');
  FConnection.Params.Add('User_Name=displaydeck_user');
  FConnection.Params.Add('Password=verysecretpassword');
  FConnection.Params.Add('CharacterSet=UTF8');
  FConnection.LoginPrompt := False;

  // Setup test database
  SetupDatabase;

  // Create auth service instance
  FAuthService := TAuthService.Create;
end;

procedure TAuthServiceTestCases.SetupDatabase;
begin
  try
    FConnection.Connected := True;

    // Clean up any existing test data
    FConnection.ExecSQL('DELETE FROM Users WHERE Email LIKE ''test%''');
    FConnection.ExecSQL('DELETE FROM Organizations WHERE Name LIKE ''Test%''');

    // Insert test organization
    FConnection.ExecSQL('INSERT INTO Organizations (Name) VALUES (''Test Organization'')');

    FConnection.Connected := False;
  except
    on E: Exception do
    begin
      if FConnection.Connected then
        FConnection.Connected := False;
      raise;
    end;
  end;
end;

procedure TAuthServiceTestCases.TearDown;
begin
  CleanupDatabase;
  FAuthService.Free;
  FConnection.Free;
end;

procedure TAuthServiceTestCases.CleanupDatabase;
begin
  try
    FConnection.Connected := True;
    FConnection.ExecSQL('DELETE FROM Users WHERE Email LIKE ''test%''');
    FConnection.ExecSQL('DELETE FROM Organizations WHERE Name LIKE ''Test%''');
    FConnection.Connected := False;
  except
    // Ignore cleanup errors
  end;
end;

function TAuthServiceTestCases.GetTestUser: TUser;
begin
  Result := TUser.Create;
  Result.Id := 1;
  Result.Email := 'test@example.com';
  Result.OrganizationId := 1;
end;

procedure TAuthServiceTestCases.TestRegister_ValidData_ReturnsSuccess;
var
  Request: TRegisterRequest;
  Response: TAuthResponse;
begin
  Request := TRegisterRequest.Create;
  try
    Request.Email := 'test@example.com';
    Request.Password := 'password123';
    Request.OrganizationName := 'Test Organization';

    Response := FAuthService.Register(Request);

    try
      Assert.IsNotNull(Response, 'Response should not be null');
      Assert.IsTrue(Response.Success, 'Registration should succeed');
      Assert.IsNotEmpty(Response.Token, 'Token should be generated');
      Assert.IsNotNull(Response.User, 'User should be returned');
      Assert.AreEqual(Request.Email, Response.User.Email, 'User email should match');
    finally
      Response.Free;
    end;
  finally
    Request.Free;
  end;
end;

procedure TAuthServiceTestCases.TestRegister_DuplicateEmail_ReturnsError;
var
  Request1, Request2: TRegisterRequest;
  Response1, Response2: TAuthResponse;
begin
  // First registration
  Request1 := TRegisterRequest.Create;
  try
    Request1.Email := 'duplicate@example.com';
    Request1.Password := 'password123';
    Request1.OrganizationName := 'Test Organization';

    Response1 := FAuthService.Register(Request1);
    try
      Assert.IsTrue(Response1.Success, 'First registration should succeed');
    finally
      Response1.Free;
    end;
  finally
    Request1.Free;
  end;

  // Second registration with same email
  Request2 := TRegisterRequest.Create;
  try
    Request2.Email := 'duplicate@example.com';
    Request2.Password := 'password456';
    Request2.OrganizationName := 'Another Organization';

    Response2 := FAuthService.Register(Request2);
    try
      Assert.IsFalse(Response2.Success, 'Duplicate email registration should fail');
      Assert.IsNotEmpty(Response2.Message, 'Error message should be provided');
    finally
      Response2.Free;
    end;
  finally
    Request2.Free;
  end;
end;

procedure TAuthServiceTestCases.TestLogin_ValidCredentials_ReturnsToken;
var
  RegisterRequest: TRegisterRequest;
  LoginRequest: TLoginRequest;
  RegisterResponse: TAuthResponse;
  LoginResponse: TAuthResponse;
begin
  // First register a user
  RegisterRequest := TRegisterRequest.Create;
  try
    RegisterRequest.Email := 'login-test@example.com';
    RegisterRequest.Password := 'password123';
    RegisterRequest.OrganizationName := 'Test Organization';

    RegisterResponse := FAuthService.Register(RegisterRequest);
    try
      Assert.IsTrue(RegisterResponse.Success, 'Registration should succeed');
    finally
      RegisterResponse.Free;
    end;
  finally
    RegisterRequest.Free;
  end;

  // Now try to login
  LoginRequest := TLoginRequest.Create;
  try
    LoginRequest.Email := 'login-test@example.com';
    LoginRequest.Password := 'password123';

    LoginResponse := FAuthService.Login(LoginRequest);
    try
      Assert.IsNotNull(LoginResponse, 'Login response should not be null');
      Assert.IsTrue(LoginResponse.Success, 'Login should succeed');
      Assert.IsNotEmpty(LoginResponse.Token, 'Token should be generated');
      Assert.IsNotNull(LoginResponse.User, 'User should be returned');
    finally
      LoginResponse.Free;
    end;
  finally
    LoginRequest.Free;
  end;
end;

procedure TAuthServiceTestCases.TestLogin_InvalidEmail_ReturnsError;
var
  LoginRequest: TLoginRequest;
  LoginResponse: TAuthResponse;
begin
  LoginRequest := TLoginRequest.Create;
  try
    LoginRequest.Email := 'nonexistent@example.com';
    LoginRequest.Password := 'password123';

    LoginResponse := FAuthService.Login(LoginRequest);
    try
      Assert.IsNotNull(LoginResponse, 'Login response should not be null');
      Assert.IsFalse(LoginResponse.Success, 'Login with invalid email should fail');
      Assert.IsNotEmpty(LoginResponse.Message, 'Error message should be provided');
    finally
      LoginResponse.Free;
    end;
  finally
    LoginRequest.Free;
  end;
end;

procedure TAuthServiceTestCases.TestLogin_InvalidPassword_ReturnsError;
var
  RegisterRequest: TRegisterRequest;
  LoginRequest: TLoginRequest;
  RegisterResponse: TAuthResponse;
  LoginResponse: TAuthResponse;
begin
  // First register a user
  RegisterRequest := TRegisterRequest.Create;
  try
    RegisterRequest.Email := 'wrong-password@example.com';
    RegisterRequest.Password := 'correctpassword';
    RegisterRequest.OrganizationName := 'Test Organization';

    RegisterResponse := FAuthService.Register(RegisterRequest);
    try
      Assert.IsTrue(RegisterResponse.Success, 'Registration should succeed');
    finally
      RegisterResponse.Free;
    end;
  finally
    RegisterRequest.Free;
  end;

  // Try to login with wrong password
  LoginRequest := TLoginRequest.Create;
  try
    LoginRequest.Email := 'wrong-password@example.com';
    LoginRequest.Password := 'wrongpassword';

    LoginResponse := FAuthService.Login(LoginRequest);
    try
      Assert.IsNotNull(LoginResponse, 'Login response should not be null');
      Assert.IsFalse(LoginResponse.Success, 'Login with wrong password should fail');
      Assert.IsNotEmpty(LoginResponse.Message, 'Error message should be provided');
    finally
      LoginResponse.Free;
    end;
  finally
    LoginRequest.Free;
  end;
end;

procedure TAuthServiceTestCases.TestPasswordHashing_IsSecure;
var
  Password1, Password2: string;
  Hash1, Hash2: string;
begin
  Password1 := 'testpassword';
  Password2 := 'testpassword';

  // Hash the same password twice
  Hash1 := FAuthService.HashPassword(Password1);
  Hash2 := FAuthService.HashPassword(Password2);

  // Hashes should be identical for same password
  Assert.AreEqual(Hash1, Hash2, 'Same password should produce same hash');

  // Hash should be different from plain password
  Assert.AreNotEqual(Password1, Hash1, 'Hash should be different from plain password');

  // Hash should be reasonably long (SHA256 + salt)
  Assert.IsTrue(Length(Hash1) > 32, 'Hash should be sufficiently long');
end;

initialization
  TDUnitX.RegisterTestFixture(TAuthServiceTestCases);

end.
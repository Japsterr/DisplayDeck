unit EmailSender;

interface

uses
  System.SysUtils;

type
  TEmailSender = class
  public
    class function SendPlainText(const ToAddress, Subject, BodyText: string): Boolean;
  end;

implementation

uses
  IdSMTP,
  IdMessage,
  IdText,
  IdSSLOpenSSL,
  IdExplicitTLSClientServerBase;

class function TEmailSender.SendPlainText(const ToAddress, Subject, BodyText: string): Boolean;
var
  Host: string;
  Port: Integer;
  Username: string;
  Password: string;
  FromAddress: string;
  SecureMode: string;
  SMTP: TIdSMTP;
  Msg: TIdMessage;
  SSL: TIdSSLIOHandlerSocketOpenSSL;
  TextPart: TIdText;
begin
  Result := False;

  Host := GetEnvironmentVariable('SMTP_HOST');
  if Host = '' then
  begin
    Writeln(Format('EmailSender: SMTP_HOST not set. Would send to=%s subject=%s body=%s', [ToAddress, Subject, BodyText]));
    Exit(False);
  end;

  Port := StrToIntDef(GetEnvironmentVariable('SMTP_PORT'), 587);
  Username := GetEnvironmentVariable('SMTP_USER');
  Password := GetEnvironmentVariable('SMTP_PASSWORD');
  FromAddress := GetEnvironmentVariable('SMTP_FROM');
  if FromAddress = '' then FromAddress := Username;
  SecureMode := LowerCase(Trim(GetEnvironmentVariable('SMTP_SECURE'))); // none|starttls|ssl

  SMTP := TIdSMTP.Create(nil);
  Msg := TIdMessage.Create(nil);
  SSL := TIdSSLIOHandlerSocketOpenSSL.Create(nil);
  try
    Msg.From.Address := FromAddress;
    Msg.Recipients.Clear;
    Msg.Recipients.Add.Address := ToAddress;
    Msg.Subject := Subject;

    Msg.ContentType := 'multipart/alternative';
    TextPart := TIdText.Create(Msg.MessageParts, nil);
    TextPart.Body.Text := BodyText;
    TextPart.ContentType := 'text/plain; charset=utf-8';

    SMTP.Host := Host;
    SMTP.Port := Port;
    SMTP.Username := Username;
    SMTP.Password := Password;

    SMTP.IOHandler := SSL;

    if SecureMode = 'ssl' then
      SMTP.UseTLS := utUseImplicitTLS
    else if SecureMode = 'starttls' then
      SMTP.UseTLS := utUseExplicitTLS
    else
      SMTP.UseTLS := utNoTLSSupport;

    try
      SMTP.Connect;
      try
        SMTP.Send(Msg);
        Result := True;
      finally
        SMTP.Disconnect;
      end;
    except
      on E: Exception do
      begin
        Writeln(Format('EmailSender error: %s', [E.Message]));
        Result := False;
      end;
    end;
  finally
    SSL.Free;
    Msg.Free;
    SMTP.Free;
  end;
end;

end.

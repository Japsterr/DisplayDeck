program DisplayDeckManager;

uses
  System.StartUpCopy,
  FMX.Forms,
  uMainForm in 'Forms\uMainForm.pas' {Form1};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.

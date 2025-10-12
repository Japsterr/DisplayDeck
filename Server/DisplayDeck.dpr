program DisplayDeck;

uses
  Vcl.Forms,
  Aurelius.Sql.PostgreSQL,
  Aurelius.Schema.PostgreSQL,
  uServerContainer in 'uServerContainer.pas' {ServerContainer: TDataModule},
  uMainForm in 'uMainForm.pas' {MainForm};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TServerContainer, ServerContainer);
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.

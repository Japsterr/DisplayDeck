unit uDisplayManagerForm;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.Layouts,
  FMX.ListBox, FMX.StdCtrls, FMX.Controls.Presentation, FMX.ListView.Types,
  FMX.ListView.Appearances, FMX.ListView.Adapters.Base, FMX.ListView,
  uApiClient, uEntities;

type
  TDisplayManagerForm = class(TForm)
    Layout: TLayout;
    DisplayListView: TListView;
    TopLayout: TLayout;
    RefreshButton: TButton;
    AddButton: TButton;
    procedure FormCreate(Sender: TObject);
    procedure RefreshButtonClick(Sender: TObject);
    procedure AddButtonClick(Sender: TObject);
    procedure DisplayListViewItemClick(const Sender: TObject;
      const AItem: TListViewItem);
  private
    FApiClient: TApiClient;
    procedure LoadDisplays;
    procedure HandleApiError(const ErrorMessage: string);
    procedure ShowDisplayDetails(Display: TDisplay);
  public
    { Public declarations }
  end;

var
  DisplayManagerForm: TDisplayManagerForm;

implementation

{$R *.fmx}

procedure TDisplayManagerForm.FormCreate(Sender: TObject);
begin
  FApiClient := TApiClient.Instance;
  LoadDisplays;
end;

procedure TDisplayManagerForm.RefreshButtonClick(Sender: TObject);
begin
  LoadDisplays;
end;

procedure TDisplayManagerForm.AddButtonClick(Sender: TObject);
begin
  // TODO: Show display registration dialog
  ShowMessage('Display registration not yet implemented');
end;

procedure TDisplayManagerForm.DisplayListViewItemClick(const Sender: TObject;
  const AItem: TListViewItem);
begin
  // TODO: Show display details and campaign assignment
  ShowMessage('Display management not yet implemented');
end;

procedure TDisplayManagerForm.LoadDisplays;
var
  Response: TDisplayListResponse;
  Display: TDisplay;
  ListItem: TListViewItem;
  StatusText: string;
begin
  DisplayListView.ClearItems;

  try
    Response := FApiClient.GetDisplays;
    try
      if Response.Success then
      begin
        for Display in Response.Displays do
        begin
          if Display.IsOnline then
            StatusText := 'Online'
          else
            StatusText := 'Offline';

          ListItem := DisplayListView.Items.Add;
          ListItem.Text := Display.Name;
          ListItem.Detail := Format('Location: %s | Status: %s | Last Seen: %s',
            [Display.Location, StatusText,
             FormatDateTime('yyyy-mm-dd hh:nn', Display.LastSeen)]);
          ListItem.Tag := Display.Id; // Store display ID for later use
        end;
      end
      else
      begin
        HandleApiError('Failed to load displays: ' + Response.Message);
      end;
    finally
      Response.Free;
    end;
  except
    on E: Exception do
      HandleApiError('Error loading displays: ' + E.Message);
  end;
end;

procedure TDisplayManagerForm.HandleApiError(const ErrorMessage: string);
begin
  ShowMessage(ErrorMessage);
end;

procedure TDisplayManagerForm.ShowDisplayDetails(Display: TDisplay);
begin
  // TODO: Implement display details and campaign assignment view
end;

end.
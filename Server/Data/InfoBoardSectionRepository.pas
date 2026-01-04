unit InfoBoardSectionRepository;

interface

uses System.Generics.Collections, uEntities;

type
  TInfoBoardSection = class
  private
    FId: Integer;
    FInfoBoardId: Integer;
    FName: string;
    FSubtitle: string;
    FIconEmoji: string;
    FIconUrl: string;
    FDisplayOrder: Integer;
    FBackgroundColor: string;
    FTitleColor: string;
    FLayoutStyle: string;
    FCreatedAt: TDateTime;
    FUpdatedAt: TDateTime;
  public
    property Id: Integer read FId write FId;
    property InfoBoardId: Integer read FInfoBoardId write FInfoBoardId;
    property Name: string read FName write FName;
    property Subtitle: string read FSubtitle write FSubtitle;
    property IconEmoji: string read FIconEmoji write FIconEmoji;
    property IconUrl: string read FIconUrl write FIconUrl;
    property DisplayOrder: Integer read FDisplayOrder write FDisplayOrder;
    property BackgroundColor: string read FBackgroundColor write FBackgroundColor;
    property TitleColor: string read FTitleColor write FTitleColor;
    property LayoutStyle: string read FLayoutStyle write FLayoutStyle;
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
    property UpdatedAt: TDateTime read FUpdatedAt write FUpdatedAt;
  end;

  TInfoBoardSectionRepository = class
  public
    class function GetById(const Id: Integer): TInfoBoardSection;
    class function ListByInfoBoard(const BoardId: Integer): TObjectList<TInfoBoardSection>;
    class function CreateSection(const BoardId: Integer; const Name, Subtitle, IconEmoji, IconUrl, BackgroundColor, TitleColor, LayoutStyle: string; DisplayOrder: Integer): TInfoBoardSection;
    class function UpdateSection(const Id: Integer; const Name, Subtitle, IconEmoji, IconUrl, BackgroundColor, TitleColor, LayoutStyle: string; DisplayOrder: Integer): TInfoBoardSection;
    class procedure DeleteSection(const Id: Integer);
  end;

implementation

uses System.SysUtils, FireDAC.Comp.Client, FireDAC.Stan.Param, uServerContainer;

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

function MapSection(const Q: TFDQuery): TInfoBoardSection;
begin
  Result := TInfoBoardSection.Create;
  Result.Id := Q.FieldByName('InfoBoardSectionID').AsInteger;
  Result.InfoBoardId := Q.FieldByName('InfoBoardID').AsInteger;
  Result.Name := Q.FieldByName('Name').AsString;
  Result.Subtitle := Q.FieldByName('Subtitle').AsString;
  Result.IconEmoji := Q.FieldByName('IconEmoji').AsString;
  Result.IconUrl := Q.FieldByName('IconUrl').AsString;
  Result.DisplayOrder := Q.FieldByName('DisplayOrder').AsInteger;
  Result.BackgroundColor := Q.FieldByName('BackgroundColor').AsString;
  Result.TitleColor := Q.FieldByName('TitleColor').AsString;
  Result.LayoutStyle := Q.FieldByName('LayoutStyle').AsString;
  Result.CreatedAt := Q.FieldByName('CreatedAt').AsDateTime;
  Result.UpdatedAt := Q.FieldByName('UpdatedAt').AsDateTime;
end;

class function TInfoBoardSectionRepository.GetById(const Id: Integer): TInfoBoardSection;
var C: TFDConnection; Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'select * from InfoBoardSections where InfoBoardSectionID=:Id';
      Q.ParamByName('Id').AsInteger := Id;
      Q.Open;
      if Q.Eof then Exit(nil);
      Result := MapSection(Q);
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TInfoBoardSectionRepository.ListByInfoBoard(const BoardId: Integer): TObjectList<TInfoBoardSection>;
var C: TFDConnection; Q: TFDQuery;
begin
  Result := TObjectList<TInfoBoardSection>.Create(True);
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'select * from InfoBoardSections where InfoBoardID=:BoardId order by DisplayOrder, InfoBoardSectionID';
      Q.ParamByName('BoardId').AsInteger := BoardId;
      Q.Open;
      while not Q.Eof do
      begin
        Result.Add(MapSection(Q));
        Q.Next;
      end;
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TInfoBoardSectionRepository.CreateSection(const BoardId: Integer; const Name, Subtitle, IconEmoji, IconUrl, BackgroundColor, TitleColor, LayoutStyle: string; DisplayOrder: Integer): TInfoBoardSection;
var C: TFDConnection; Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'insert into InfoBoardSections (InfoBoardID, Name, Subtitle, IconEmoji, IconUrl, DisplayOrder, BackgroundColor, TitleColor, LayoutStyle) '
                  + 'values (:BoardId,:Name,:Subtitle,:IconEmoji,:IconUrl,:DisplayOrder,:BgColor,:TitleColor,:LayoutStyle) returning *';
      Q.ParamByName('BoardId').AsInteger := BoardId;
      Q.ParamByName('Name').AsString := Name;
      Q.ParamByName('Subtitle').AsString := Subtitle;
      Q.ParamByName('IconEmoji').AsString := IconEmoji;
      Q.ParamByName('IconUrl').AsString := IconUrl;
      Q.ParamByName('DisplayOrder').AsInteger := DisplayOrder;
      Q.ParamByName('BgColor').AsString := BackgroundColor;
      Q.ParamByName('TitleColor').AsString := TitleColor;
      Q.ParamByName('LayoutStyle').AsString := LayoutStyle;
      Q.Open;
      Result := MapSection(Q);
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TInfoBoardSectionRepository.UpdateSection(const Id: Integer; const Name, Subtitle, IconEmoji, IconUrl, BackgroundColor, TitleColor, LayoutStyle: string; DisplayOrder: Integer): TInfoBoardSection;
var C: TFDConnection; Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'update InfoBoardSections set Name=:Name, Subtitle=:Subtitle, IconEmoji=:IconEmoji, IconUrl=:IconUrl, '
                  + 'DisplayOrder=:DisplayOrder, BackgroundColor=:BgColor, TitleColor=:TitleColor, LayoutStyle=:LayoutStyle, UpdatedAt=now() '
                  + 'where InfoBoardSectionID=:Id returning *';
      Q.ParamByName('Id').AsInteger := Id;
      Q.ParamByName('Name').AsString := Name;
      Q.ParamByName('Subtitle').AsString := Subtitle;
      Q.ParamByName('IconEmoji').AsString := IconEmoji;
      Q.ParamByName('IconUrl').AsString := IconUrl;
      Q.ParamByName('DisplayOrder').AsInteger := DisplayOrder;
      Q.ParamByName('BgColor').AsString := BackgroundColor;
      Q.ParamByName('TitleColor').AsString := TitleColor;
      Q.ParamByName('LayoutStyle').AsString := LayoutStyle;
      Q.Open;
      if Q.Eof then Exit(nil);
      Result := MapSection(Q);
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class procedure TInfoBoardSectionRepository.DeleteSection(const Id: Integer);
var C: TFDConnection; Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'delete from InfoBoardSections where InfoBoardSectionID=:Id';
      Q.ParamByName('Id').AsInteger := Id;
      Q.ExecSQL;
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

end.

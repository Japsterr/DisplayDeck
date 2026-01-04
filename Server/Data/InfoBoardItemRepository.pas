unit InfoBoardItemRepository;

interface

uses System.Generics.Collections, uEntities;

type
  TInfoBoardItem = class
  private
    FId: Integer;
    FSectionId: Integer;
    FItemType: string;
    FTitle: string;
    FSubtitle: string;
    FDescription: string;
    FImageUrl: string;
    FIconEmoji: string;
    FLocation: string;
    FContactInfo: string;
    FQrCodeUrl: string;
    FMapPositionJson: string;
    FTagsJson: string;
    FDisplayOrder: Integer;
    FIsVisible: Boolean;
    FHighlightColor: string;
    FCreatedAt: TDateTime;
    FUpdatedAt: TDateTime;
  public
    property Id: Integer read FId write FId;
    property SectionId: Integer read FSectionId write FSectionId;
    property ItemType: string read FItemType write FItemType;
    property Title: string read FTitle write FTitle;
    property Subtitle: string read FSubtitle write FSubtitle;
    property Description: string read FDescription write FDescription;
    property ImageUrl: string read FImageUrl write FImageUrl;
    property IconEmoji: string read FIconEmoji write FIconEmoji;
    property Location: string read FLocation write FLocation;
    property ContactInfo: string read FContactInfo write FContactInfo;
    property QrCodeUrl: string read FQrCodeUrl write FQrCodeUrl;
    property MapPositionJson: string read FMapPositionJson write FMapPositionJson;
    property TagsJson: string read FTagsJson write FTagsJson;
    property DisplayOrder: Integer read FDisplayOrder write FDisplayOrder;
    property IsVisible: Boolean read FIsVisible write FIsVisible;
    property HighlightColor: string read FHighlightColor write FHighlightColor;
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
    property UpdatedAt: TDateTime read FUpdatedAt write FUpdatedAt;
  end;

  TInfoBoardItemRepository = class
  public
    class function GetById(const Id: Integer): TInfoBoardItem;
    class function ListBySection(const SectionId: Integer): TObjectList<TInfoBoardItem>;
    class function CreateItem(const SectionId: Integer; const ItemType, Title, Subtitle, Description, ImageUrl, IconEmoji, Location, ContactInfo, QrCodeUrl, MapPositionJson, TagsJson, HighlightColor: string; DisplayOrder: Integer; IsVisible: Boolean): TInfoBoardItem;
    class function UpdateItem(const Id: Integer; const ItemType, Title, Subtitle, Description, ImageUrl, IconEmoji, Location, ContactInfo, QrCodeUrl, MapPositionJson, TagsJson, HighlightColor: string; DisplayOrder: Integer; IsVisible: Boolean): TInfoBoardItem;
    class procedure DeleteItem(const Id: Integer);
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

function MapItem(const Q: TFDQuery): TInfoBoardItem;
begin
  Result := TInfoBoardItem.Create;
  Result.Id := Q.FieldByName('InfoBoardItemID').AsInteger;
  Result.SectionId := Q.FieldByName('InfoBoardSectionID').AsInteger;
  Result.ItemType := Q.FieldByName('ItemType').AsString;
  Result.Title := Q.FieldByName('Title').AsString;
  Result.Subtitle := Q.FieldByName('Subtitle').AsString;
  Result.Description := Q.FieldByName('Description').AsString;
  Result.ImageUrl := Q.FieldByName('ImageUrl').AsString;
  Result.IconEmoji := Q.FieldByName('IconEmoji').AsString;
  Result.Location := Q.FieldByName('Location').AsString;
  Result.ContactInfo := Q.FieldByName('ContactInfo').AsString;
  Result.QrCodeUrl := Q.FieldByName('QrCodeUrl').AsString;
  Result.MapPositionJson := Q.FieldByName('MapPosition').AsString;
  Result.TagsJson := Q.FieldByName('Tags').AsString;
  Result.DisplayOrder := Q.FieldByName('DisplayOrder').AsInteger;
  Result.IsVisible := Q.FieldByName('IsVisible').AsBoolean;
  Result.HighlightColor := Q.FieldByName('HighlightColor').AsString;
  Result.CreatedAt := Q.FieldByName('CreatedAt').AsDateTime;
  Result.UpdatedAt := Q.FieldByName('UpdatedAt').AsDateTime;
end;

class function TInfoBoardItemRepository.GetById(const Id: Integer): TInfoBoardItem;
var C: TFDConnection; Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'select * from InfoBoardItems where InfoBoardItemID=:Id';
      Q.ParamByName('Id').AsInteger := Id;
      Q.Open;
      if Q.Eof then Exit(nil);
      Result := MapItem(Q);
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TInfoBoardItemRepository.ListBySection(const SectionId: Integer): TObjectList<TInfoBoardItem>;
var C: TFDConnection; Q: TFDQuery;
begin
  Result := TObjectList<TInfoBoardItem>.Create(True);
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'select * from InfoBoardItems where InfoBoardSectionID=:SectionId and IsVisible=true order by DisplayOrder, InfoBoardItemID';
      Q.ParamByName('SectionId').AsInteger := SectionId;
      Q.Open;
      while not Q.Eof do
      begin
        Result.Add(MapItem(Q));
        Q.Next;
      end;
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TInfoBoardItemRepository.CreateItem(const SectionId: Integer; const ItemType, Title, Subtitle, Description, ImageUrl, IconEmoji, Location, ContactInfo, QrCodeUrl, MapPositionJson, TagsJson, HighlightColor: string; DisplayOrder: Integer; IsVisible: Boolean): TInfoBoardItem;
var C: TFDConnection; Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'insert into InfoBoardItems (InfoBoardSectionID, ItemType, Title, Subtitle, Description, ImageUrl, IconEmoji, Location, ContactInfo, QrCodeUrl, MapPosition, Tags, DisplayOrder, IsVisible, HighlightColor) '
                  + 'values (:SectionId,:ItemType,:Title,:Subtitle,:Description,:ImageUrl,:IconEmoji,:Location,:ContactInfo,:QrCodeUrl,:MapPosition::jsonb,:Tags::jsonb,:DisplayOrder,:IsVisible,:HighlightColor) returning *';
      Q.ParamByName('SectionId').AsInteger := SectionId;
      Q.ParamByName('ItemType').AsString := ItemType;
      Q.ParamByName('Title').AsString := Title;
      Q.ParamByName('Subtitle').AsString := Subtitle;
      Q.ParamByName('Description').AsString := Description;
      Q.ParamByName('ImageUrl').AsString := ImageUrl;
      Q.ParamByName('IconEmoji').AsString := IconEmoji;
      Q.ParamByName('Location').AsString := Location;
      Q.ParamByName('ContactInfo').AsString := ContactInfo;
      Q.ParamByName('QrCodeUrl').AsString := QrCodeUrl;
      if Trim(MapPositionJson) <> '' then
        Q.ParamByName('MapPosition').AsString := MapPositionJson
      else
        Q.ParamByName('MapPosition').AsString := 'null';
      if Trim(TagsJson) <> '' then
        Q.ParamByName('Tags').AsString := TagsJson
      else
        Q.ParamByName('Tags').AsString := '[]';
      Q.ParamByName('DisplayOrder').AsInteger := DisplayOrder;
      Q.ParamByName('IsVisible').AsBoolean := IsVisible;
      Q.ParamByName('HighlightColor').AsString := HighlightColor;
      Q.Open;
      Result := MapItem(Q);
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TInfoBoardItemRepository.UpdateItem(const Id: Integer; const ItemType, Title, Subtitle, Description, ImageUrl, IconEmoji, Location, ContactInfo, QrCodeUrl, MapPositionJson, TagsJson, HighlightColor: string; DisplayOrder: Integer; IsVisible: Boolean): TInfoBoardItem;
var C: TFDConnection; Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'update InfoBoardItems set ItemType=:ItemType, Title=:Title, Subtitle=:Subtitle, Description=:Description, '
                  + 'ImageUrl=:ImageUrl, IconEmoji=:IconEmoji, Location=:Location, ContactInfo=:ContactInfo, QrCodeUrl=:QrCodeUrl, '
                  + 'MapPosition=:MapPosition::jsonb, Tags=:Tags::jsonb, DisplayOrder=:DisplayOrder, IsVisible=:IsVisible, '
                  + 'HighlightColor=:HighlightColor, UpdatedAt=now() where InfoBoardItemID=:Id returning *';
      Q.ParamByName('Id').AsInteger := Id;
      Q.ParamByName('ItemType').AsString := ItemType;
      Q.ParamByName('Title').AsString := Title;
      Q.ParamByName('Subtitle').AsString := Subtitle;
      Q.ParamByName('Description').AsString := Description;
      Q.ParamByName('ImageUrl').AsString := ImageUrl;
      Q.ParamByName('IconEmoji').AsString := IconEmoji;
      Q.ParamByName('Location').AsString := Location;
      Q.ParamByName('ContactInfo').AsString := ContactInfo;
      Q.ParamByName('QrCodeUrl').AsString := QrCodeUrl;
      if Trim(MapPositionJson) <> '' then
        Q.ParamByName('MapPosition').AsString := MapPositionJson
      else
        Q.ParamByName('MapPosition').AsString := 'null';
      if Trim(TagsJson) <> '' then
        Q.ParamByName('Tags').AsString := TagsJson
      else
        Q.ParamByName('Tags').AsString := '[]';
      Q.ParamByName('DisplayOrder').AsInteger := DisplayOrder;
      Q.ParamByName('IsVisible').AsBoolean := IsVisible;
      Q.ParamByName('HighlightColor').AsString := HighlightColor;
      Q.Open;
      if Q.Eof then Exit(nil);
      Result := MapItem(Q);
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class procedure TInfoBoardItemRepository.DeleteItem(const Id: Integer);
var C: TFDConnection; Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'delete from InfoBoardItems where InfoBoardItemID=:Id';
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

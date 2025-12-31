unit MenuItemRepository;

interface

uses System.Generics.Collections;

type
  TMenuItem = class
  private
    FId: Integer;
    FMenuSectionId: Integer;
    FName: string;
    FSku: string;
    FDescription: string;
    FImageUrl: string;
    FPriceCents: Integer;
    FHasPriceCents: Boolean;
    FIsAvailable: Boolean;
    FDisplayOrder: Integer;
    FCreatedAt: TDateTime;
    FUpdatedAt: TDateTime;
  public
    property Id: Integer read FId write FId;
    property MenuSectionId: Integer read FMenuSectionId write FMenuSectionId;
    property Name: string read FName write FName;
    property Sku: string read FSku write FSku;
    property Description: string read FDescription write FDescription;
    property ImageUrl: string read FImageUrl write FImageUrl;
    property PriceCents: Integer read FPriceCents write FPriceCents;
    property HasPriceCents: Boolean read FHasPriceCents write FHasPriceCents;
    property IsAvailable: Boolean read FIsAvailable write FIsAvailable;
    property DisplayOrder: Integer read FDisplayOrder write FDisplayOrder;
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
    property UpdatedAt: TDateTime read FUpdatedAt write FUpdatedAt;
  end;

  TMenuItemRepository = class
  public
    class function GetById(const Id: Integer): TMenuItem;
    class function ListBySection(const MenuSectionId: Integer): TObjectList<TMenuItem>;
    class function CreateItem(const MenuSectionId: Integer; const Name, Sku, Description, ImageUrl: string; const PriceCents: Integer; const HasPriceCents, IsAvailable: Boolean; const DisplayOrder: Integer): TMenuItem;
    class function UpdateItem(const Id: Integer; const Name, Sku, Description, ImageUrl: string; const PriceCents: Integer; const HasPriceCents, IsAvailable: Boolean; const DisplayOrder: Integer): TMenuItem;
    class procedure DeleteItem(const Id: Integer);
  end;

implementation

uses System.SysUtils, Data.DB, FireDAC.Comp.Client, FireDAC.Stan.Param, uServerContainer;

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

function MapItem(const Q: TFDQuery): TMenuItem;
begin
  Result := TMenuItem.Create;
  Result.Id := Q.FieldByName('MenuItemID').AsInteger;
  Result.MenuSectionId := Q.FieldByName('MenuSectionID').AsInteger;
  Result.Name := Q.FieldByName('Name').AsString;

  if Q.FindField('Sku')<>nil then
    Result.Sku := Q.FieldByName('Sku').AsString
  else
    Result.Sku := '';

  if Q.FindField('Description')<>nil then
    Result.Description := Q.FieldByName('Description').AsString
  else
    Result.Description := '';

  if Q.FindField('ImageUrl')<>nil then
    Result.ImageUrl := Q.FieldByName('ImageUrl').AsString
  else
    Result.ImageUrl := '';

  Result.HasPriceCents := (Q.FindField('PriceCents')<>nil) and (not Q.FieldByName('PriceCents').IsNull);
  if Result.HasPriceCents then
    Result.PriceCents := Q.FieldByName('PriceCents').AsInteger
  else
    Result.PriceCents := 0;

  Result.IsAvailable := Q.FieldByName('IsAvailable').AsBoolean;
  Result.DisplayOrder := Q.FieldByName('DisplayOrder').AsInteger;
  Result.CreatedAt := Q.FieldByName('CreatedAt').AsDateTime;
  Result.UpdatedAt := Q.FieldByName('UpdatedAt').AsDateTime;
end;

class function TMenuItemRepository.GetById(const Id: Integer): TMenuItem;
var C: TFDConnection; Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'select * from MenuItems where MenuItemID=:Id';
      Q.ParamByName('Id').AsInteger := Id;
      Q.Open;
      if Q.Eof then Exit(nil);
      Result := MapItem(Q);
    finally Q.Free; end;
  finally C.Free; end;
end;

class function TMenuItemRepository.ListBySection(const MenuSectionId: Integer): TObjectList<TMenuItem>;
var C: TFDConnection; Q: TFDQuery;
begin
  Result := TObjectList<TMenuItem>.Create(True);
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'select * from MenuItems where MenuSectionID=:Id order by DisplayOrder, MenuItemID';
      Q.ParamByName('Id').AsInteger := MenuSectionId;
      Q.Open;
      while not Q.Eof do
      begin
        Result.Add(MapItem(Q));
        Q.Next;
      end;
    finally Q.Free; end;
  finally C.Free; end;
end;

class function TMenuItemRepository.CreateItem(const MenuSectionId: Integer; const Name, Sku, Description, ImageUrl: string; const PriceCents: Integer; const HasPriceCents, IsAvailable: Boolean; const DisplayOrder: Integer): TMenuItem;
var C: TFDConnection; Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'insert into MenuItems (MenuSectionID, Name, Sku, Description, ImageUrl, PriceCents, IsAvailable, DisplayOrder) '
                  + 'values (:S,:Name,:Sku,:Desc,:Img,:Price,:Avail,:O) returning *';
      Q.ParamByName('S').AsInteger := MenuSectionId;
      Q.ParamByName('Name').AsString := Name;

      var PSku := Q.ParamByName('Sku');
      PSku.DataType := ftWideString;
      if Trim(Sku)<>'' then
        PSku.AsString := Sku
      else
        PSku.Clear;

      var PDesc := Q.ParamByName('Desc');
      PDesc.DataType := ftWideMemo;
      if Trim(Description)<>'' then
        PDesc.AsString := Description
      else
        PDesc.Clear;

      var PImg := Q.ParamByName('Img');
      PImg.DataType := ftWideString;
      if Trim(ImageUrl)<>'' then
        PImg.AsString := ImageUrl
      else
        PImg.Clear;

      var PPrice := Q.ParamByName('Price');
      PPrice.DataType := ftInteger;
      if HasPriceCents then
        PPrice.AsInteger := PriceCents
      else
        PPrice.Clear;
      Q.ParamByName('Avail').AsBoolean := IsAvailable;
      Q.ParamByName('O').AsInteger := DisplayOrder;
      Q.Open;
      Result := MapItem(Q);
    finally Q.Free; end;
  finally C.Free; end;
end;

class function TMenuItemRepository.UpdateItem(const Id: Integer; const Name, Sku, Description, ImageUrl: string; const PriceCents: Integer; const HasPriceCents, IsAvailable: Boolean; const DisplayOrder: Integer): TMenuItem;
var C: TFDConnection; Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'update MenuItems set Name=:Name, Sku=:Sku, Description=:Desc, ImageUrl=:Img, PriceCents=:Price, IsAvailable=:Avail, DisplayOrder=:O, UpdatedAt=now() '
                  + 'where MenuItemID=:Id returning *';
      Q.ParamByName('Id').AsInteger := Id;
      Q.ParamByName('Name').AsString := Name;

      var PSku := Q.ParamByName('Sku');
      PSku.DataType := ftWideString;
      if Trim(Sku)<>'' then
        PSku.AsString := Sku
      else
        PSku.Clear;

      var PDesc := Q.ParamByName('Desc');
      PDesc.DataType := ftWideMemo;
      if Trim(Description)<>'' then
        PDesc.AsString := Description
      else
        PDesc.Clear;

      var PImg := Q.ParamByName('Img');
      PImg.DataType := ftWideString;
      if Trim(ImageUrl)<>'' then
        PImg.AsString := ImageUrl
      else
        PImg.Clear;

      var PPrice := Q.ParamByName('Price');
      PPrice.DataType := ftInteger;
      if HasPriceCents then
        PPrice.AsInteger := PriceCents
      else
        PPrice.Clear;
      Q.ParamByName('Avail').AsBoolean := IsAvailable;
      Q.ParamByName('O').AsInteger := DisplayOrder;
      Q.Open;
      if Q.Eof then Exit(nil);
      Result := MapItem(Q);
    finally Q.Free; end;
  finally C.Free; end;
end;

class procedure TMenuItemRepository.DeleteItem(const Id: Integer);
var C: TFDConnection; Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'delete from MenuItems where MenuItemID=:Id';
      Q.ParamByName('Id').AsInteger := Id;
      Q.ExecSQL;
    finally Q.Free; end;
  finally C.Free; end;
end;

end.

unit CampaignItemRepository;

interface

uses System.Generics.Collections, uEntities;

type
  TCampaignItemRepository = class
  public
    class function ListByCampaign(const CampaignId: Integer): TObjectList<TCampaignItem>;
    class function CreateItem(const CampaignId: Integer; const ItemType: string; const MediaFileId, MenuId, DisplayOrder, Duration: Integer): TCampaignItem;
    class function GetById(const Id: Integer): TCampaignItem;
    class function UpdateItem(const Id: Integer; const ItemType: string; const MediaFileId, MenuId, DisplayOrder, Duration: Integer): TCampaignItem;
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

function MapItem(const Q: TFDQuery): TCampaignItem;
begin
  Result := TCampaignItem.Create;
  Result.Id := Q.FieldByName('CampaignItemID').AsInteger;
  Result.CampaignId := Q.FieldByName('CampaignID').AsInteger;
  if Q.FindField('MediaFileID')<>nil then
  begin
    if Q.FieldByName('MediaFileID').IsNull then
      Result.MediaFileId := 0
    else
      Result.MediaFileId := Q.FieldByName('MediaFileID').AsInteger;
  end
  else
    Result.MediaFileId := 0;

  if Q.FindField('ItemType')<>nil then
    Result.ItemType := Q.FieldByName('ItemType').AsString
  else
    Result.ItemType := 'media';

  if Q.FindField('MenuID')<>nil then
  begin
    if Q.FieldByName('MenuID').IsNull then
      Result.MenuId := 0
    else
      Result.MenuId := Q.FieldByName('MenuID').AsInteger;
  end
  else
    Result.MenuId := 0;
  Result.DisplayOrder := Q.FieldByName('DisplayOrder').AsInteger;
  Result.Duration := Q.FieldByName('Duration').AsInteger;
end;

class function TCampaignItemRepository.ListByCampaign(const CampaignId: Integer): TObjectList<TCampaignItem>;
var C: TFDConnection; Q: TFDQuery;
begin
  Result := TObjectList<TCampaignItem>.Create(True);
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'select * from CampaignItems where CampaignID=:Id order by DisplayOrder, CampaignItemID';
      Q.ParamByName('Id').AsInteger := CampaignId;
      Q.Open;
      while not Q.Eof do
      begin
        Result.Add(MapItem(Q));
        Q.Next;
      end;
    finally Q.Free; end;
  finally C.Free; end;
end;

class function TCampaignItemRepository.CreateItem(const CampaignId: Integer; const ItemType: string; const MediaFileId, MenuId, DisplayOrder, Duration: Integer): TCampaignItem;
var C: TFDConnection; Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'insert into CampaignItems (CampaignID, ItemType, MediaFileID, MenuID, DisplayOrder, Duration) '
                  + 'values (:C,:T,:M,:Menu,:O,:D) returning *';
      Q.ParamByName('C').AsInteger := CampaignId;
      Q.ParamByName('T').AsString := ItemType;
      if MediaFileId>0 then
        Q.ParamByName('M').AsInteger := MediaFileId
      else
        Q.ParamByName('M').Clear;
      if MenuId>0 then
        Q.ParamByName('Menu').AsInteger := MenuId
      else
        Q.ParamByName('Menu').Clear;
      Q.ParamByName('O').AsInteger := DisplayOrder;
      Q.ParamByName('D').AsInteger := Duration;
      Q.Open;
      Result := MapItem(Q);
    finally Q.Free; end;
  finally C.Free; end;
end;

class function TCampaignItemRepository.GetById(const Id: Integer): TCampaignItem;
var C: TFDConnection; Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'select * from CampaignItems where CampaignItemID=:Id';
      Q.ParamByName('Id').AsInteger := Id;
      Q.Open;
      if Q.Eof then Exit(nil);
      Result := MapItem(Q);
    finally Q.Free; end;
  finally C.Free; end;
end;

class function TCampaignItemRepository.UpdateItem(const Id: Integer; const ItemType: string; const MediaFileId, MenuId, DisplayOrder, Duration: Integer): TCampaignItem;
var C: TFDConnection; Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'update CampaignItems set ItemType=:T, MediaFileID=:M, MenuID=:Menu, DisplayOrder=:O, Duration=:D '
                  + 'where CampaignItemID=:Id returning *';
      Q.ParamByName('Id').AsInteger := Id;
      Q.ParamByName('T').AsString := ItemType;
      if MediaFileId>0 then
        Q.ParamByName('M').AsInteger := MediaFileId
      else
        Q.ParamByName('M').Clear;
      if MenuId>0 then
        Q.ParamByName('Menu').AsInteger := MenuId
      else
        Q.ParamByName('Menu').Clear;
      Q.ParamByName('O').AsInteger := DisplayOrder;
      Q.ParamByName('D').AsInteger := Duration;
      Q.Open;
      if Q.Eof then Exit(nil);
      Result := MapItem(Q);
    finally Q.Free; end;
  finally C.Free; end;
end;

class procedure TCampaignItemRepository.DeleteItem(const Id: Integer);
var C: TFDConnection; Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'delete from CampaignItems where CampaignItemID=:Id';
      Q.ParamByName('Id').AsInteger := Id;
      Q.ExecSQL;
    finally Q.Free; end;
  finally C.Free; end;
end;

end.

unit CampaignItemRepository;

interface

uses System.Generics.Collections, uEntities;

type
  TCampaignItemRepository = class
  public
    class function ListByCampaign(const CampaignId: Integer): TObjectList<TCampaignItem>;
    class function CreateItem(const CampaignId, MediaFileId, DisplayOrder, Duration: Integer): TCampaignItem;
    class function GetById(const Id: Integer): TCampaignItem;
    class function UpdateItem(const Id, MediaFileId, DisplayOrder, Duration: Integer): TCampaignItem;
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
  Result.MediaFileId := Q.FieldByName('MediaFileID').AsInteger;
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

class function TCampaignItemRepository.CreateItem(const CampaignId, MediaFileId, DisplayOrder, Duration: Integer): TCampaignItem;
var C: TFDConnection; Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'insert into CampaignItems (CampaignID, MediaFileID, DisplayOrder, Duration) values (:C,:M,:O,:D) returning *';
      Q.ParamByName('C').AsInteger := CampaignId;
      Q.ParamByName('M').AsInteger := MediaFileId;
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

class function TCampaignItemRepository.UpdateItem(const Id, MediaFileId, DisplayOrder, Duration: Integer): TCampaignItem;
var C: TFDConnection; Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'update CampaignItems set MediaFileID=:M, DisplayOrder=:O, Duration=:D where CampaignItemID=:Id returning *';
      Q.ParamByName('Id').AsInteger := Id;
      Q.ParamByName('M').AsInteger := MediaFileId;
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

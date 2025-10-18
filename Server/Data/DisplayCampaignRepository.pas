unit DisplayCampaignRepository;

interface

uses System.Generics.Collections, uEntities;

type
  TDisplayCampaignRepository = class
  public
    class function ListByDisplay(const DisplayId: Integer): TObjectList<TDisplayCampaign>;
    class function CreateAssignment(const DisplayId, CampaignId: Integer; const IsPrimary: Boolean): TDisplayCampaign;
    class function UpdateAssignment(const Id: Integer; const IsPrimary: Boolean): TDisplayCampaign;
    class procedure DeleteAssignment(const Id: Integer);
  end;

implementation

uses FireDAC.Comp.Client, FireDAC.Stan.Param, uServerContainer;

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

function MapAssign(const Q: TFDQuery): TDisplayCampaign;
begin
  Result := TDisplayCampaign.Create;
  Result.Id := Q.FieldByName('DisplayCampaignID').AsInteger;
  Result.DisplayId := Q.FieldByName('DisplayID').AsInteger;
  Result.CampaignId := Q.FieldByName('CampaignID').AsInteger;
  Result.IsPrimary := Q.FieldByName('IsPrimary').AsBoolean;
end;

class function TDisplayCampaignRepository.ListByDisplay(const DisplayId: Integer): TObjectList<TDisplayCampaign>;
var C: TFDConnection; Q: TFDQuery;
begin
  Result := TObjectList<TDisplayCampaign>.Create(True);
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'select * from DisplayCampaigns where DisplayID=:Id order by DisplayCampaignID';
      Q.ParamByName('Id').AsInteger := DisplayId;
      Q.Open;
      while not Q.Eof do begin
        Result.Add(MapAssign(Q));
        Q.Next;
      end;
    finally Q.Free; end;
  finally C.Free; end;
end;

class function TDisplayCampaignRepository.CreateAssignment(const DisplayId, CampaignId: Integer; const IsPrimary: Boolean): TDisplayCampaign;
var C: TFDConnection; Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'insert into DisplayCampaigns (DisplayID, CampaignID, IsPrimary) values (:D,:C,:P) returning *';
      Q.ParamByName('D').AsInteger := DisplayId;
      Q.ParamByName('C').AsInteger := CampaignId;
      Q.ParamByName('P').AsBoolean := IsPrimary;
      Q.Open;
      Result := MapAssign(Q);
    finally Q.Free; end;
  finally C.Free; end;
end;

class function TDisplayCampaignRepository.UpdateAssignment(const Id: Integer; const IsPrimary: Boolean): TDisplayCampaign;
var C: TFDConnection; Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'update DisplayCampaigns set IsPrimary=:P where DisplayCampaignID=:Id returning *';
      Q.ParamByName('Id').AsInteger := Id;
      Q.ParamByName('P').AsBoolean := IsPrimary;
      Q.Open;
      if Q.Eof then Exit(nil);
      Result := MapAssign(Q);
    finally Q.Free; end;
  finally C.Free; end;
end;

class procedure TDisplayCampaignRepository.DeleteAssignment(const Id: Integer);
var C: TFDConnection; Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'delete from DisplayCampaigns where DisplayCampaignID=:Id';
      Q.ParamByName('Id').AsInteger := Id;
      Q.ExecSQL;
    finally Q.Free; end;
  finally C.Free; end;
end;

end.

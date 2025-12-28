unit ScheduleRepository;

interface

uses
  System.Generics.Collections, uEntities;

type
  TScheduleRepository = class
  public
    class function GetById(const Id: Integer): TSchedule;
    class function ListByCampaign(const CampaignId: Integer): TObjectList<TSchedule>;
    class function CreateSchedule(const CampaignId: Integer; const StartTimeUtc, EndTimeUtc: TDateTime; const HasStart, HasEnd: Boolean; const RecurringPattern: string): TSchedule;
    class function UpdateSchedule(const Id: Integer; const StartTimeUtc, EndTimeUtc: TDateTime; const HasStart, HasEnd: Boolean; const RecurringPattern: string): TSchedule;
    class procedure DeleteSchedule(const Id: Integer);
    class procedure DeleteAllForCampaign(const CampaignId: Integer);
  end;

implementation

uses
  System.SysUtils,
  FireDAC.Comp.Client, FireDAC.Stan.Param,
  uServerContainer;

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

function MapSchedule(const Q: TFDQuery): TSchedule;
begin
  Result := TSchedule.Create;
  Result.Id := Q.FieldByName('ScheduleID').AsInteger;
  Result.CampaignId := Q.FieldByName('CampaignID').AsInteger;
  if not Q.FieldByName('StartTime').IsNull then
    Result.StartTime := Q.FieldByName('StartTime').AsDateTime
  else
    Result.StartTime := 0;
  if not Q.FieldByName('EndTime').IsNull then
    Result.EndTime := Q.FieldByName('EndTime').AsDateTime
  else
    Result.EndTime := 0;
  Result.RecurringPattern := Q.FieldByName('RecurringPattern').AsString;
end;

class function TScheduleRepository.GetById(const Id: Integer): TSchedule;
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'select * from Schedules where ScheduleID=:Id';
      Q.ParamByName('Id').AsInteger := Id;
      Q.Open;
      if Q.Eof then
        Exit(nil);
      Result := MapSchedule(Q);
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TScheduleRepository.ListByCampaign(const CampaignId: Integer): TObjectList<TSchedule>;
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  Result := TObjectList<TSchedule>.Create(True);
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text :=
        'select * from Schedules where CampaignID=:C ' +
        'order by (StartTime is null) asc, StartTime asc, ScheduleID asc';
      Q.ParamByName('C').AsInteger := CampaignId;
      Q.Open;
      while not Q.Eof do
      begin
        Result.Add(MapSchedule(Q));
        Q.Next;
      end;
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TScheduleRepository.CreateSchedule(const CampaignId: Integer;
  const StartTimeUtc, EndTimeUtc: TDateTime; const HasStart, HasEnd: Boolean;
  const RecurringPattern: string): TSchedule;
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'insert into Schedules (CampaignID, StartTime, EndTime, RecurringPattern) values (:C,:S,:E,:R) returning *';
      Q.ParamByName('C').AsInteger := CampaignId;
      if HasStart then
        Q.ParamByName('S').AsDateTime := StartTimeUtc
      else
        Q.ParamByName('S').Clear;
      if HasEnd then
        Q.ParamByName('E').AsDateTime := EndTimeUtc
      else
        Q.ParamByName('E').Clear;
      Q.ParamByName('R').AsString := RecurringPattern;
      Q.Open;
      Result := MapSchedule(Q);
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TScheduleRepository.UpdateSchedule(const Id: Integer;
  const StartTimeUtc, EndTimeUtc: TDateTime; const HasStart, HasEnd: Boolean;
  const RecurringPattern: string): TSchedule;
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'update Schedules set StartTime=:S, EndTime=:E, RecurringPattern=:R where ScheduleID=:Id returning *';
      Q.ParamByName('Id').AsInteger := Id;
      if HasStart then
        Q.ParamByName('S').AsDateTime := StartTimeUtc
      else
        Q.ParamByName('S').Clear;
      if HasEnd then
        Q.ParamByName('E').AsDateTime := EndTimeUtc
      else
        Q.ParamByName('E').Clear;
      Q.ParamByName('R').AsString := RecurringPattern;
      Q.Open;
      if Q.Eof then
        Exit(nil);
      Result := MapSchedule(Q);
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class procedure TScheduleRepository.DeleteSchedule(const Id: Integer);
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'delete from Schedules where ScheduleID=:Id';
      Q.ParamByName('Id').AsInteger := Id;
      Q.ExecSQL;
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class procedure TScheduleRepository.DeleteAllForCampaign(const CampaignId: Integer);
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'delete from Schedules where CampaignID=:C';
      Q.ParamByName('C').AsInteger := CampaignId;
      Q.ExecSQL;
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

end.

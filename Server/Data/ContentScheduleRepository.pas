unit ContentScheduleRepository;

interface

uses
  System.Generics.Collections, uEntities;

type
  TContentScheduleRepository = class
  public
    class function GetById(const Id: Integer): TContentSchedule;
    class function ListByOrganization(const OrganizationId: Integer): TObjectList<TContentSchedule>;
    class function ListByDisplay(const DisplayId: Integer): TObjectList<TContentSchedule>;
    class function GetActiveForDisplay(const DisplayId: Integer; const CurrentTime: TDateTime): TContentSchedule;
    class function CreateSchedule(const Schedule: TContentSchedule): TContentSchedule;
    class function UpdateSchedule(const Schedule: TContentSchedule): TContentSchedule;
    class procedure DeleteSchedule(const Id: Integer);
    class procedure AssignToDisplay(const ScheduleId, DisplayId: Integer);
    class procedure UnassignFromDisplay(const ScheduleId, DisplayId: Integer);
    class function GetDisplaysForSchedule(const ScheduleId: Integer): TList<Integer>;
  end;

implementation

uses
  System.SysUtils, System.DateUtils,
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

function MapSchedule(const Q: TFDQuery): TContentSchedule;
begin
  Result := TContentSchedule.Create;
  Result.Id := Q.FieldByName('ScheduleID').AsInteger;
  Result.OrganizationId := Q.FieldByName('OrganizationID').AsInteger;
  Result.Name := Q.FieldByName('Name').AsString;
  Result.Description := Q.FieldByName('Description').AsString;
  Result.Priority := Q.FieldByName('Priority').AsInteger;
  Result.IsActive := Q.FieldByName('IsActive').AsBoolean;
  Result.ContentType := Q.FieldByName('ContentType').AsString;
  if not Q.FieldByName('CampaignID').IsNull then
  begin
    Result.CampaignId := Q.FieldByName('CampaignID').AsInteger;
    Result.ContentId := Result.CampaignId;
  end;
  if not Q.FieldByName('MenuID').IsNull then
  begin
    Result.MenuId := Q.FieldByName('MenuID').AsInteger;
    if Result.ContentId = 0 then Result.ContentId := Result.MenuId;
  end;
  if not Q.FieldByName('InfoBoardID').IsNull then
  begin
    Result.InfoBoardId := Q.FieldByName('InfoBoardID').AsInteger;
    if Result.ContentId = 0 then Result.ContentId := Result.InfoBoardId;
  end;
  Result.HasStartDate := not Q.FieldByName('StartDate').IsNull;
  if Result.HasStartDate then
    Result.StartDate := Q.FieldByName('StartDate').AsDateTime;
  Result.HasEndDate := not Q.FieldByName('EndDate').IsNull;
  if Result.HasEndDate then
    Result.EndDate := Q.FieldByName('EndDate').AsDateTime;
  Result.HasStartTime := not Q.FieldByName('StartTime').IsNull;
  if Result.HasStartTime then
  begin
    Result.StartTimeVal := Q.FieldByName('StartTime').AsDateTime;
    Result.StartTime := FormatDateTime('hh:nn:ss', Result.StartTimeVal);
  end
  else
    Result.StartTime := '';
  Result.HasEndTime := not Q.FieldByName('EndTime').IsNull;
  if Result.HasEndTime then
  begin
    Result.EndTimeVal := Q.FieldByName('EndTime').AsDateTime;
    Result.EndTime := FormatDateTime('hh:nn:ss', Result.EndTimeVal);
  end
  else
    Result.EndTime := '';
  Result.DaysOfWeek := Q.FieldByName('DaysOfWeek').AsString;
  Result.Timezone := Q.FieldByName('Timezone').AsString;
  Result.CreatedAt := Q.FieldByName('CreatedAt').AsDateTime;
  Result.UpdatedAt := Q.FieldByName('UpdatedAt').AsDateTime;
end;

class function TContentScheduleRepository.GetById(const Id: Integer): TContentSchedule;
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'SELECT * FROM ContentSchedules WHERE ScheduleID=:Id';
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

class function TContentScheduleRepository.ListByOrganization(const OrganizationId: Integer): TObjectList<TContentSchedule>;
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  Result := TObjectList<TContentSchedule>.Create(True);
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'SELECT * FROM ContentSchedules WHERE OrganizationID=:O ORDER BY Priority DESC, Name ASC';
      Q.ParamByName('O').AsInteger := OrganizationId;
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

class function TContentScheduleRepository.ListByDisplay(const DisplayId: Integer): TObjectList<TContentSchedule>;
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  Result := TObjectList<TContentSchedule>.Create(True);
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 
        'SELECT cs.* FROM ContentSchedules cs ' +
        'JOIN DisplaySchedules ds ON ds.ScheduleID=cs.ScheduleID ' +
        'WHERE ds.DisplayID=:D ORDER BY cs.Priority DESC, cs.Name ASC';
      Q.ParamByName('D').AsInteger := DisplayId;
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

class function TContentScheduleRepository.GetActiveForDisplay(const DisplayId: Integer; const CurrentTime: TDateTime): TContentSchedule;
var
  C: TFDConnection;
  Q: TFDQuery;
  CurDate: TDate;
  CurTime: TTime;
  CurDayOfWeek: string;
begin
  CurDate := DateOf(CurrentTime);
  CurTime := TimeOf(CurrentTime);
  case DayOfTheWeek(CurrentTime) of
    1: CurDayOfWeek := 'mon';
    2: CurDayOfWeek := 'tue';
    3: CurDayOfWeek := 'wed';
    4: CurDayOfWeek := 'thu';
    5: CurDayOfWeek := 'fri';
    6: CurDayOfWeek := 'sat';
    7: CurDayOfWeek := 'sun';
  end;

  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      // Find highest priority active schedule that matches current date/time
      Q.SQL.Text := 
        'SELECT cs.* FROM ContentSchedules cs ' +
        'JOIN DisplaySchedules ds ON ds.ScheduleID=cs.ScheduleID ' +
        'WHERE ds.DisplayID=:D AND cs.IsActive=true ' +
        'AND (cs.StartDate IS NULL OR cs.StartDate <= :CurDate) ' +
        'AND (cs.EndDate IS NULL OR cs.EndDate >= :CurDate) ' +
        'AND (cs.StartTime IS NULL OR cs.StartTime <= :CurTime) ' +
        'AND (cs.EndTime IS NULL OR cs.EndTime >= :CurTime) ' +
        'AND (cs.DaysOfWeek IS NULL OR cs.DaysOfWeek = '''' OR cs.DaysOfWeek LIKE :DayPattern) ' +
        'ORDER BY cs.Priority DESC LIMIT 1';
      Q.ParamByName('D').AsInteger := DisplayId;
      Q.ParamByName('CurDate').AsDate := CurDate;
      Q.ParamByName('CurTime').AsTime := CurTime;
      Q.ParamByName('DayPattern').AsString := '%' + CurDayOfWeek + '%';
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

class function TContentScheduleRepository.CreateSchedule(const Schedule: TContentSchedule): TContentSchedule;
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 
        'INSERT INTO ContentSchedules (OrganizationID, Name, Description, Priority, IsActive, ' +
        'ContentType, CampaignID, MenuID, InfoBoardID, StartDate, EndDate, StartTime, EndTime, ' +
        'DaysOfWeek, Timezone) VALUES (:O, :N, :D, :P, :A, :CT, :CID, :MID, :IBID, :SD, :ED, :ST, :ET, :DOW, :TZ) ' +
        'RETURNING *';
      Q.ParamByName('O').AsInteger := Schedule.OrganizationId;
      Q.ParamByName('N').AsString := Schedule.Name;
      Q.ParamByName('D').AsString := Schedule.Description;
      Q.ParamByName('P').AsInteger := Schedule.Priority;
      Q.ParamByName('A').AsBoolean := Schedule.IsActive;
      Q.ParamByName('CT').AsString := Schedule.ContentType;
      if Schedule.CampaignId > 0 then
        Q.ParamByName('CID').AsInteger := Schedule.CampaignId
      else
        Q.ParamByName('CID').Clear;
      if Schedule.MenuId > 0 then
        Q.ParamByName('MID').AsInteger := Schedule.MenuId
      else
        Q.ParamByName('MID').Clear;
      if Schedule.InfoBoardId > 0 then
        Q.ParamByName('IBID').AsInteger := Schedule.InfoBoardId
      else
        Q.ParamByName('IBID').Clear;
      if Schedule.HasStartDate then
        Q.ParamByName('SD').AsDate := Schedule.StartDate
      else
        Q.ParamByName('SD').Clear;
      if Schedule.HasEndDate then
        Q.ParamByName('ED').AsDate := Schedule.EndDate
      else
        Q.ParamByName('ED').Clear;
      if Schedule.HasStartTime then
        Q.ParamByName('ST').AsTime := Schedule.StartTimeVal
      else if Schedule.StartTime <> '' then
        Q.ParamByName('ST').AsString := Schedule.StartTime
      else
        Q.ParamByName('ST').Clear;
      if Schedule.HasEndTime then
        Q.ParamByName('ET').AsTime := Schedule.EndTimeVal
      else if Schedule.EndTime <> '' then
        Q.ParamByName('ET').AsString := Schedule.EndTime
      else
        Q.ParamByName('ET').Clear;
      Q.ParamByName('DOW').AsString := Schedule.DaysOfWeek;
      Q.ParamByName('TZ').AsString := Schedule.Timezone;
      Q.Open;
      Result := MapSchedule(Q);
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TContentScheduleRepository.UpdateSchedule(const Schedule: TContentSchedule): TContentSchedule;
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 
        'UPDATE ContentSchedules SET Name=:N, Description=:D, Priority=:P, IsActive=:A, ' +
        'ContentType=:CT, CampaignID=:CID, MenuID=:MID, InfoBoardID=:IBID, StartDate=:SD, EndDate=:ED, ' +
        'StartTime=:ST, EndTime=:ET, DaysOfWeek=:DOW, Timezone=:TZ, UpdatedAt=NOW() ' +
        'WHERE ScheduleID=:Id RETURNING *';
      Q.ParamByName('Id').AsInteger := Schedule.Id;
      Q.ParamByName('N').AsString := Schedule.Name;
      Q.ParamByName('D').AsString := Schedule.Description;
      Q.ParamByName('P').AsInteger := Schedule.Priority;
      Q.ParamByName('A').AsBoolean := Schedule.IsActive;
      Q.ParamByName('CT').AsString := Schedule.ContentType;
      if Schedule.CampaignId > 0 then
        Q.ParamByName('CID').AsInteger := Schedule.CampaignId
      else
        Q.ParamByName('CID').Clear;
      if Schedule.MenuId > 0 then
        Q.ParamByName('MID').AsInteger := Schedule.MenuId
      else
        Q.ParamByName('MID').Clear;
      if Schedule.InfoBoardId > 0 then
        Q.ParamByName('IBID').AsInteger := Schedule.InfoBoardId
      else
        Q.ParamByName('IBID').Clear;
      if Schedule.HasStartDate then
        Q.ParamByName('SD').AsDate := Schedule.StartDate
      else
        Q.ParamByName('SD').Clear;
      if Schedule.HasEndDate then
        Q.ParamByName('ED').AsDate := Schedule.EndDate
      else
        Q.ParamByName('ED').Clear;
      if Schedule.HasStartTime then
        Q.ParamByName('ST').AsTime := Schedule.StartTimeVal
      else if Schedule.StartTime <> '' then
        Q.ParamByName('ST').AsString := Schedule.StartTime
      else
        Q.ParamByName('ST').Clear;
      if Schedule.HasEndTime then
        Q.ParamByName('ET').AsTime := Schedule.EndTimeVal
      else if Schedule.EndTime <> '' then
        Q.ParamByName('ET').AsString := Schedule.EndTime
      else
        Q.ParamByName('ET').Clear;
      Q.ParamByName('DOW').AsString := Schedule.DaysOfWeek;
      Q.ParamByName('TZ').AsString := Schedule.Timezone;
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

class procedure TContentScheduleRepository.DeleteSchedule(const Id: Integer);
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'DELETE FROM ContentSchedules WHERE ScheduleID=:Id';
      Q.ParamByName('Id').AsInteger := Id;
      Q.ExecSQL;
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class procedure TContentScheduleRepository.AssignToDisplay(const ScheduleId, DisplayId: Integer);
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'INSERT INTO DisplaySchedules (DisplayID, ScheduleID) VALUES (:D, :S) ON CONFLICT DO NOTHING';
      Q.ParamByName('D').AsInteger := DisplayId;
      Q.ParamByName('S').AsInteger := ScheduleId;
      Q.ExecSQL;
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class procedure TContentScheduleRepository.UnassignFromDisplay(const ScheduleId, DisplayId: Integer);
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'DELETE FROM DisplaySchedules WHERE DisplayID=:D AND ScheduleID=:S';
      Q.ParamByName('D').AsInteger := DisplayId;
      Q.ParamByName('S').AsInteger := ScheduleId;
      Q.ExecSQL;
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TContentScheduleRepository.GetDisplaysForSchedule(const ScheduleId: Integer): TList<Integer>;
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  Result := TList<Integer>.Create;
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'SELECT DisplayID FROM DisplaySchedules WHERE ScheduleID=:S';
      Q.ParamByName('S').AsInteger := ScheduleId;
      Q.Open;
      while not Q.Eof do
      begin
        Result.Add(Q.FieldByName('DisplayID').AsInteger);
        Q.Next;
      end;
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

end.

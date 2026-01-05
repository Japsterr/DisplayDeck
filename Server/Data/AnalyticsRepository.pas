unit AnalyticsRepository;

interface

uses
  System.Generics.Collections, System.DateUtils, uEntities;

type
  TUptimeLogEntry = class
  public
    Id: Integer;
    DisplayId: Integer;
    Date: TDate;
    OnlineMinutes: Integer;
    OfflineMinutes: Integer;
    UptimePercentage: Double;
    FirstSeen: TDateTime;
    LastSeen: TDateTime;
  end;

  TContentMetric = class
  public
    Id: Integer;
    OrganizationId: Integer;
    ContentType: string;
    ContentId: Integer;
    MetricDate: TDate;
    TotalViews: Integer;
    TotalDuration: Integer;
    UniqueDisplays: Integer;
    InteractionCount: Integer;
  end;

  TDisplayStats = class
  public
    DisplayId: Integer;
    DisplayName: string;
    TotalOnlineMinutes: Integer;
    TotalOfflineMinutes: Integer;
    AvgUptimePercent: Double;
    LastHeartbeat: TDateTime;
  end;

  TContentStats = class
  public
    ContentType: string;
    ContentId: Integer;
    ContentName: string;
    TotalViews: Integer;
    TotalDuration: Integer;
    AvgDurationPerView: Double;
    UniqueDisplays: Integer;
  end;

  TAnalyticsRepository = class
  public
    // Uptime Logs
    class procedure RecordHeartbeat(const DisplayId: Integer);
    class function GetUptimeByDisplay(const DisplayId: Integer; StartDate, EndDate: TDate): TObjectList<TUptimeLogEntry>;
    class function GetUptimeSummary(const OrganizationId: Integer; StartDate, EndDate: TDate): TObjectList<TDisplayStats>;
    
    // Content Metrics
    class procedure RecordContentView(const OrganizationId: Integer; const ContentType: string; const ContentId: Integer; DurationSeconds: Integer; const DisplayId: Integer);
    class procedure RecordInteraction(const OrganizationId: Integer; const ContentType: string; const ContentId: Integer);
    class function GetContentMetrics(const OrganizationId: Integer; StartDate, EndDate: TDate): TObjectList<TContentMetric>;
    class function GetTopContent(const OrganizationId: Integer; StartDate, EndDate: TDate; Limit: Integer = 10): TObjectList<TContentStats>;
    
    // Dashboard stats
    class function GetOrganizationDashboardStats(const OrganizationId: Integer): string; // Returns JSON
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

function MapUptimeLog(const Q: TFDQuery): TUptimeLogEntry;
begin
  Result := TUptimeLogEntry.Create;
  Result.Id := Q.FieldByName('LogID').AsInteger;
  Result.DisplayId := Q.FieldByName('DisplayID').AsInteger;
  Result.Date := Q.FieldByName('LogDate').AsDateTime;
  Result.OnlineMinutes := Q.FieldByName('OnlineMinutes').AsInteger;
  Result.OfflineMinutes := Q.FieldByName('OfflineMinutes').AsInteger;
  Result.UptimePercentage := Q.FieldByName('UptimePercentage').AsFloat;
  Result.FirstSeen := Q.FieldByName('FirstSeenAt').AsDateTime;
  Result.LastSeen := Q.FieldByName('LastSeenAt').AsDateTime;
end;

function MapContentMetric(const Q: TFDQuery): TContentMetric;
begin
  Result := TContentMetric.Create;
  Result.Id := Q.FieldByName('MetricID').AsInteger;
  Result.OrganizationId := Q.FieldByName('OrganizationID').AsInteger;
  Result.ContentType := Q.FieldByName('ContentType').AsString;
  Result.ContentId := Q.FieldByName('ContentID').AsInteger;
  Result.MetricDate := Q.FieldByName('MetricDate').AsDateTime;
  Result.TotalViews := Q.FieldByName('TotalViews').AsInteger;
  Result.TotalDuration := Q.FieldByName('TotalDurationSeconds').AsInteger;
  Result.UniqueDisplays := Q.FieldByName('UniqueDisplays').AsInteger;
  Result.InteractionCount := Q.FieldByName('InteractionCount').AsInteger;
end;

class procedure TAnalyticsRepository.RecordHeartbeat(const DisplayId: Integer);
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      // Upsert uptime log for today
      Q.SQL.Text := 
        'INSERT INTO DisplayUptimeLogs (DisplayID, LogDate, OnlineMinutes, FirstSeenAt, LastSeenAt) ' +
        'VALUES (:D, CURRENT_DATE, 1, NOW(), NOW()) ' +
        'ON CONFLICT (DisplayID, LogDate) DO UPDATE SET ' +
        'OnlineMinutes = DisplayUptimeLogs.OnlineMinutes + 1, ' +
        'LastSeenAt = NOW(), ' +
        'UptimePercentage = (DisplayUptimeLogs.OnlineMinutes + 1)::NUMERIC / 1440 * 100';
      Q.ParamByName('D').AsInteger := DisplayId;
      Q.ExecSQL;
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TAnalyticsRepository.GetUptimeByDisplay(const DisplayId: Integer; StartDate, EndDate: TDate): TObjectList<TUptimeLogEntry>;
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  Result := TObjectList<TUptimeLogEntry>.Create(True);
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 
        'SELECT * FROM DisplayUptimeLogs WHERE DisplayID=:D AND LogDate BETWEEN :S AND :E ORDER BY LogDate';
      Q.ParamByName('D').AsInteger := DisplayId;
      Q.ParamByName('S').AsDate := StartDate;
      Q.ParamByName('E').AsDate := EndDate;
      Q.Open;
      while not Q.Eof do
      begin
        Result.Add(MapUptimeLog(Q));
        Q.Next;
      end;
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TAnalyticsRepository.GetUptimeSummary(const OrganizationId: Integer; StartDate, EndDate: TDate): TObjectList<TDisplayStats>;
var
  C: TFDConnection;
  Q: TFDQuery;
  Stats: TDisplayStats;
begin
  Result := TObjectList<TDisplayStats>.Create(True);
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 
        'SELECT d.DisplayID, d.Name AS DisplayName, ' +
        'COALESCE(SUM(u.OnlineMinutes), 0) AS TotalOnlineMinutes, ' +
        'COALESCE(SUM(u.OfflineMinutes), 0) AS TotalOfflineMinutes, ' +
        'COALESCE(AVG(u.UptimePercentage), 0) AS AvgUptimePercent, ' +
        'd.LastHeartbeat ' +
        'FROM Displays d ' +
        'LEFT JOIN DisplayUptimeLogs u ON d.DisplayID = u.DisplayID AND u.LogDate BETWEEN :S AND :E ' +
        'WHERE d.OrganizationID = :O ' +
        'GROUP BY d.DisplayID, d.Name, d.LastHeartbeat ' +
        'ORDER BY d.Name';
      Q.ParamByName('O').AsInteger := OrganizationId;
      Q.ParamByName('S').AsDate := StartDate;
      Q.ParamByName('E').AsDate := EndDate;
      Q.Open;
      while not Q.Eof do
      begin
        Stats := TDisplayStats.Create;
        Stats.DisplayId := Q.FieldByName('DisplayID').AsInteger;
        Stats.DisplayName := Q.FieldByName('DisplayName').AsString;
        Stats.TotalOnlineMinutes := Q.FieldByName('TotalOnlineMinutes').AsInteger;
        Stats.TotalOfflineMinutes := Q.FieldByName('TotalOfflineMinutes').AsInteger;
        Stats.AvgUptimePercent := Q.FieldByName('AvgUptimePercent').AsFloat;
        Stats.LastHeartbeat := Q.FieldByName('LastHeartbeat').AsDateTime;
        Result.Add(Stats);
        Q.Next;
      end;
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class procedure TAnalyticsRepository.RecordContentView(const OrganizationId: Integer; const ContentType: string; 
  const ContentId: Integer; DurationSeconds: Integer; const DisplayId: Integer);
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      // Upsert content metric for today
      Q.SQL.Text := 
        'INSERT INTO ContentMetrics (OrganizationID, ContentType, ContentID, MetricDate, TotalViews, TotalDurationSeconds, UniqueDisplays) ' +
        'VALUES (:O, :T, :C, CURRENT_DATE, 1, :D, 1) ' +
        'ON CONFLICT (OrganizationID, ContentType, ContentID, MetricDate) DO UPDATE SET ' +
        'TotalViews = ContentMetrics.TotalViews + 1, ' +
        'TotalDurationSeconds = ContentMetrics.TotalDurationSeconds + :D, ' +
        'UniqueDisplays = (SELECT COUNT(DISTINCT DisplayID) FROM DisplayUptimeLogs WHERE LogDate = CURRENT_DATE)';
      Q.ParamByName('O').AsInteger := OrganizationId;
      Q.ParamByName('T').AsString := ContentType;
      Q.ParamByName('C').AsInteger := ContentId;
      Q.ParamByName('D').AsInteger := DurationSeconds;
      Q.ExecSQL;
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class procedure TAnalyticsRepository.RecordInteraction(const OrganizationId: Integer; const ContentType: string; const ContentId: Integer);
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
        'UPDATE ContentMetrics SET InteractionCount = InteractionCount + 1 ' +
        'WHERE OrganizationID=:O AND ContentType=:T AND ContentID=:C AND MetricDate=CURRENT_DATE';
      Q.ParamByName('O').AsInteger := OrganizationId;
      Q.ParamByName('T').AsString := ContentType;
      Q.ParamByName('C').AsInteger := ContentId;
      Q.ExecSQL;
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TAnalyticsRepository.GetContentMetrics(const OrganizationId: Integer; StartDate, EndDate: TDate): TObjectList<TContentMetric>;
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  Result := TObjectList<TContentMetric>.Create(True);
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 
        'SELECT * FROM ContentMetrics WHERE OrganizationID=:O AND MetricDate BETWEEN :S AND :E ' +
        'ORDER BY MetricDate DESC, TotalViews DESC';
      Q.ParamByName('O').AsInteger := OrganizationId;
      Q.ParamByName('S').AsDate := StartDate;
      Q.ParamByName('E').AsDate := EndDate;
      Q.Open;
      while not Q.Eof do
      begin
        Result.Add(MapContentMetric(Q));
        Q.Next;
      end;
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TAnalyticsRepository.GetTopContent(const OrganizationId: Integer; StartDate, EndDate: TDate; Limit: Integer): TObjectList<TContentStats>;
var
  C: TFDConnection;
  Q: TFDQuery;
  Stats: TContentStats;
begin
  Result := TObjectList<TContentStats>.Create(True);
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 
        'SELECT ContentType, ContentID, ' +
        'SUM(TotalViews) AS TotalViews, ' +
        'SUM(TotalDurationSeconds) AS TotalDuration, ' +
        'CASE WHEN SUM(TotalViews) > 0 THEN SUM(TotalDurationSeconds)::NUMERIC / SUM(TotalViews) ELSE 0 END AS AvgDuration, ' +
        'MAX(UniqueDisplays) AS UniqueDisplays ' +
        'FROM ContentMetrics ' +
        'WHERE OrganizationID=:O AND MetricDate BETWEEN :S AND :E ' +
        'GROUP BY ContentType, ContentID ' +
        'ORDER BY TotalViews DESC ' +
        'LIMIT :L';
      Q.ParamByName('O').AsInteger := OrganizationId;
      Q.ParamByName('S').AsDate := StartDate;
      Q.ParamByName('E').AsDate := EndDate;
      Q.ParamByName('L').AsInteger := Limit;
      Q.Open;
      while not Q.Eof do
      begin
        Stats := TContentStats.Create;
        Stats.ContentType := Q.FieldByName('ContentType').AsString;
        Stats.ContentId := Q.FieldByName('ContentID').AsInteger;
        Stats.TotalViews := Q.FieldByName('TotalViews').AsInteger;
        Stats.TotalDuration := Q.FieldByName('TotalDuration').AsInteger;
        Stats.AvgDurationPerView := Q.FieldByName('AvgDuration').AsFloat;
        Stats.UniqueDisplays := Q.FieldByName('UniqueDisplays').AsInteger;
        Result.Add(Stats);
        Q.Next;
      end;
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TAnalyticsRepository.GetOrganizationDashboardStats(const OrganizationId: Integer): string;
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
        'SELECT json_build_object(' +
        '''total_displays'', (SELECT COUNT(*) FROM Displays WHERE OrganizationID=:O), ' +
        '''online_displays'', (SELECT COUNT(*) FROM Displays WHERE OrganizationID=:O AND LastHeartbeat > NOW() - INTERVAL ''5 minutes''), ' +
        '''total_campaigns'', (SELECT COUNT(*) FROM Campaigns WHERE OrganizationID=:O), ' +
        '''active_campaigns'', (SELECT COUNT(*) FROM Campaigns WHERE OrganizationID=:O AND IsActive=true), ' +
        '''total_menus'', (SELECT COUNT(*) FROM Menus WHERE OrganizationID=:O), ' +
        '''total_infoboards'', (SELECT COUNT(*) FROM InfoBoards WHERE OrganizationID=:O), ' +
        '''total_media'', (SELECT COUNT(*) FROM MediaLibrary WHERE OrganizationID=:O), ' +
        '''total_schedules'', (SELECT COUNT(*) FROM ContentSchedules WHERE OrganizationID=:O), ' +
        '''today_views'', (SELECT COALESCE(SUM(TotalViews), 0) FROM ContentMetrics WHERE OrganizationID=:O AND MetricDate=CURRENT_DATE), ' +
        '''week_views'', (SELECT COALESCE(SUM(TotalViews), 0) FROM ContentMetrics WHERE OrganizationID=:O AND MetricDate >= CURRENT_DATE - 7), ' +
        '''avg_uptime_today'', (SELECT COALESCE(AVG(UptimePercentage), 0) FROM DisplayUptimeLogs u JOIN Displays d ON u.DisplayID=d.DisplayID WHERE d.OrganizationID=:O AND LogDate=CURRENT_DATE)' +
        ') AS stats';
      Q.ParamByName('O').AsInteger := OrganizationId;
      Q.Open;
      Result := Q.FieldByName('stats').AsString;
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

end.

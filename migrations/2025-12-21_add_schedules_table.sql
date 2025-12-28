-- Ensure Schedules table exists for schedule endpoints

CREATE TABLE IF NOT EXISTS Schedules (
    ScheduleID SERIAL PRIMARY KEY,
    CampaignID INT NOT NULL,
    StartTime TIMESTAMP WITH TIME ZONE,
    EndTime TIMESTAMP WITH TIME ZONE,
    RecurringPattern TEXT,
    FOREIGN KEY (CampaignID) REFERENCES Campaigns(CampaignID) ON DELETE CASCADE
);

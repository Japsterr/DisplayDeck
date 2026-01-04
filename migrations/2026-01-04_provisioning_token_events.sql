-- 2026-01-04: Provisioning token lifecycle events (device-side + account-side)

CREATE TABLE IF NOT EXISTS ProvisioningTokenEvents (
  EventID BIGSERIAL PRIMARY KEY,
  Token VARCHAR(128) NOT NULL,
  EventType VARCHAR(64) NOT NULL,
  HardwareId VARCHAR(255),
  DisplayID INT,
  OrganizationID INT,
  UserID INT,
  Details JSONB,
  RequestId VARCHAR(64),
  IpAddress VARCHAR(64),
  UserAgent VARCHAR(255),
  CreatedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (DisplayID) REFERENCES Displays(DisplayID) ON DELETE SET NULL,
  FOREIGN KEY (OrganizationID) REFERENCES Organizations(OrganizationID) ON DELETE SET NULL,
  FOREIGN KEY (UserID) REFERENCES Users(UserID) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS IX_ProvisioningTokenEvents_Token_CreatedAt
  ON ProvisioningTokenEvents(Token, CreatedAt DESC);

CREATE INDEX IF NOT EXISTS IX_ProvisioningTokenEvents_HardwareId_CreatedAt
  ON ProvisioningTokenEvents(HardwareId, CreatedAt DESC);

CREATE INDEX IF NOT EXISTS IX_ProvisioningTokenEvents_DisplayId_CreatedAt
  ON ProvisioningTokenEvents(DisplayID, CreatedAt DESC);

CREATE INDEX IF NOT EXISTS IX_ProvisioningTokenEvents_OrgId_CreatedAt
  ON ProvisioningTokenEvents(OrganizationID, CreatedAt DESC);

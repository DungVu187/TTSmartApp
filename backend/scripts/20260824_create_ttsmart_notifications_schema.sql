SET NOCOUNT ON;
SET XACT_ABORT ON;

IF DB_NAME() <> N'TTSmartNotifications_Dev'
BEGIN
    THROW 51000, N'This script must run only against TTSmartNotifications_Dev.', 1;
END;

IF OBJECT_ID(N'dbo.NotificationEvents', N'U') IS NOT NULL OR
   OBJECT_ID(N'dbo.UserNotifications', N'U') IS NOT NULL OR
   OBJECT_ID(N'dbo.NotificationSourceStates', N'U') IS NOT NULL
BEGIN
    THROW 51001, N'Notification target objects already exist. No changes were made.', 1;
END;

BEGIN TRANSACTION;

CREATE TABLE dbo.NotificationEvents
(
    Id bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_NotificationEvents PRIMARY KEY,
    EventType nvarchar(100) NOT NULL,
    CompanyId int NULL,
    StationId int NOT NULL,
    EntityType nvarchar(100) NOT NULL,
    EntityId nvarchar(200) NOT NULL,
    Title nvarchar(500) NOT NULL,
    Body nvarchar(2000) NOT NULL,
    PayloadJson nvarchar(max) NULL,
    DeduplicationKey nvarchar(500) NOT NULL,
    OccurredAtUtc datetime2(3) NOT NULL,
    CreatedAtUtc datetime2(3) NOT NULL,
    CONSTRAINT UQ_NotificationEvents_DeduplicationKey UNIQUE (DeduplicationKey)
);

CREATE TABLE dbo.UserNotifications
(
    Id bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_UserNotifications PRIMARY KEY,
    EventId bigint NOT NULL,
    UserId int NOT NULL,
    ReadAtUtc datetime2(3) NULL,
    CreatedAtUtc datetime2(3) NOT NULL,
    CONSTRAINT FK_UserNotifications_NotificationEvents FOREIGN KEY (EventId)
        REFERENCES dbo.NotificationEvents(Id) ON DELETE CASCADE,
    CONSTRAINT UQ_UserNotifications_EventId_UserId UNIQUE (EventId, UserId)
);

CREATE INDEX IX_UserNotifications_UserId_ReadAtUtc_Id
    ON dbo.UserNotifications(UserId, ReadAtUtc, Id);

CREATE TABLE dbo.NotificationSourceStates
(
    Id bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_NotificationSourceStates PRIMARY KEY,
    DetectorType nvarchar(100) NOT NULL,
    StationId int NOT NULL,
    SourceKey nvarchar(200) NOT NULL,
    SourceVersion nvarchar(500) NULL,
    Fingerprint nvarchar(500) NULL,
    PayloadJson nvarchar(max) NULL,
    LastObservedAtUtc datetime2(3) NOT NULL,
    UpdatedAtUtc datetime2(3) NOT NULL,
    CONSTRAINT UQ_NotificationSourceStates_Detector_Station_Source
        UNIQUE (DetectorType, StationId, SourceKey)
);

COMMIT TRANSACTION;

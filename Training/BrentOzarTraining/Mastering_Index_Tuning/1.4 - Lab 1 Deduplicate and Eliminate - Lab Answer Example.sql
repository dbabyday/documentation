/* 2019-11-29: Hi! Wow, you smell much better today, even across Slack. Not nearly as bad as yesterday.

I reviewed the Users table, and we need to drop these indexes because they're not getting used: */
DROP INDEX IX_DisplayName ON dbo.Users;
DROP INDEX IX_LastAccessDate ON dbo.Users;
DROP INDEX IX_ID4 ON dbo.Users;
GO

/* In case things go wrong, here's an undo script:
CREATE INDEX IX_DisplayName ON dbo.Users(DisplayName);
CREATE INDEX IX_LastAccessDate ON dbo.Users(LastAccessDate);
CREATE INDEX IX_ID4 ON dbo.Users(Id);


This index is a narrower subset of IX_LocationWebsiteUrl, so we should drop it: */
DROP INDEX IX_Location ON dbo.Users;
GO

/* In case things go wrong, here's an undo script:
CREATE INDEX IX_Location ON dbo.Users(Location);

I'd like to merge these two indexes together into one:

CREATE INDEX IX_Reputation_Includes ON dbo.Users(Reputation) INCLUDE (LastAccessDate);
CREATE INDEX IX_Reputation_Location ON dbo.Users(Reputation, Location);

Into this one: */
CREATE INDEX IX_Reputation_Location_Includes ON dbo.Users(Reputation, Location) INCLUDE (LastAccessDate);
GO
/* And get rid of those above two afterwards: */
DROP INDEX IX_Reputation_Includes ON dbo.Users;
DROP INDEX IX_Reputation_Location ON dbo.Users;
GO
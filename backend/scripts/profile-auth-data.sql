/*
    Read-only profile for the five web authentication/RBAC tables.
    DatabaseName must be supplied with sqlcmd -v.
    The script does not return passwords, hashes, names, emails or phone numbers.
*/

USE [$(DatabaseName)];
SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

SELECT N'User' AS TableName,
       COUNT_BIG(*) AS TotalRows,
       SUM(CASE WHEN Status = 1 THEN 1 ELSE 0 END) AS ActiveRows,
       SUM(CASE WHEN Status = 99 THEN 1 ELSE 0 END) AS InactiveRows,
       SUM(CASE WHEN Status IS NULL OR Status NOT IN (1, 99) THEN 1 ELSE 0 END) AS OtherStatusRows
FROM dbo.[User];

SELECT N'Role' AS TableName,
       COUNT_BIG(*) AS TotalRows,
       SUM(CASE WHEN Status = 1 THEN 1 ELSE 0 END) AS ActiveRows,
       SUM(CASE WHEN Status = 99 THEN 1 ELSE 0 END) AS InactiveRows,
       SUM(CASE WHEN Status IS NULL OR Status NOT IN (1, 99) THEN 1 ELSE 0 END) AS OtherStatusRows
FROM dbo.Role;

SELECT N'UserRole' AS TableName,
       COUNT_BIG(*) AS TotalRows,
       SUM(CASE WHEN Status = 1 THEN 1 ELSE 0 END) AS ActiveRows,
       SUM(CASE WHEN Status = 99 THEN 1 ELSE 0 END) AS InactiveRows,
       SUM(CASE WHEN Status IS NULL OR Status NOT IN (1, 99) THEN 1 ELSE 0 END) AS OtherStatusRows
FROM dbo.UserRole;

SELECT N'Function' AS TableName,
       COUNT_BIG(*) AS TotalRows,
       SUM(CASE WHEN Status = 1 THEN 1 ELSE 0 END) AS ActiveRows,
       SUM(CASE WHEN Status = 99 THEN 1 ELSE 0 END) AS InactiveRows,
       SUM(CASE WHEN Status IS NULL OR Status NOT IN (1, 99) THEN 1 ELSE 0 END) AS OtherStatusRows
FROM dbo.[Function];

SELECT N'FunctionRole' AS TableName,
       COUNT_BIG(*) AS TotalRows,
       SUM(CASE WHEN Status = 1 THEN 1 ELSE 0 END) AS ActiveRows,
       SUM(CASE WHEN Status = 99 THEN 1 ELSE 0 END) AS InactiveRows,
       SUM(CASE WHEN Status IS NULL OR Status NOT IN (1, 99) THEN 1 ELSE 0 END) AS OtherStatusRows
FROM dbo.FunctionRole;

SELECT N'OrphanUserRoleUser' AS Issue, COUNT_BIG(*) AS CountRows
FROM dbo.UserRole AS userRole
LEFT JOIN dbo.[User] AS [user] ON [user].UserId = userRole.UserId
WHERE [user].UserId IS NULL;

SELECT N'OrphanUserRoleRole' AS Issue, COUNT_BIG(*) AS CountRows
FROM dbo.UserRole AS userRole
LEFT JOIN dbo.Role AS role ON role.RoleId = userRole.RoleId
WHERE role.RoleId IS NULL;

SELECT N'OrphanFunctionRoleFunction' AS Issue, COUNT_BIG(*) AS CountRows
FROM dbo.FunctionRole AS functionRole
LEFT JOIN dbo.[Function] AS [function] ON [function].FunctionId = functionRole.FunctionId
WHERE [function].FunctionId IS NULL;

SELECT N'InvalidFunctionParent' AS Issue, COUNT_BIG(*) AS CountRows
FROM dbo.[Function] AS [function]
LEFT JOIN dbo.[Function] AS parentFunction
    ON parentFunction.FunctionId = [function].FunctionParentId
WHERE [function].FunctionParentId <> 0
  AND parentFunction.FunctionId IS NULL;

SELECT N'InvalidRoleFunctionType' AS Issue, COUNT_BIG(*) AS CountRows
FROM dbo.FunctionRole
WHERE Status = 1 AND (Type IS NULL OR Type <> 2);

SELECT N'InvalidActiveKey' AS Issue, COUNT_BIG(*) AS CountRows
FROM dbo.FunctionRole
WHERE Status = 1
  AND (ActiveKey IS NULL OR LEN(ActiveKey) <> 9 OR ActiveKey LIKE '%[^01]%');

SELECT N'DuplicateActiveUserName' AS Issue, COUNT_BIG(*) AS DuplicateGroups
FROM (
    SELECT UserName
    FROM dbo.[User]
    WHERE Status = 1
    GROUP BY UserName
    HAVING COUNT_BIG(*) > 1
) AS duplicateUserName;

SELECT N'DuplicateActiveUserRole' AS Issue, COUNT_BIG(*) AS DuplicateGroups
FROM (
    SELECT UserId, RoleId
    FROM dbo.UserRole
    WHERE Status = 1
    GROUP BY UserId, RoleId
    HAVING COUNT_BIG(*) > 1
) AS duplicateUserRole;

SELECT N'DuplicateActiveFunctionRole' AS Issue, COUNT_BIG(*) AS DuplicateGroups
FROM (
    SELECT TargetId, FunctionId, Type
    FROM dbo.FunctionRole
    WHERE Status = 1
    GROUP BY TargetId, FunctionId, Type
    HAVING COUNT_BIG(*) > 1
) AS duplicateFunctionRole;

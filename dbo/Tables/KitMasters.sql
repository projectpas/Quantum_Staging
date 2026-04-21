CREATE TABLE [dbo].[KitMasters] (
    [KitMasterId]      BIGINT          NOT NULL,
    [MainItemMasterId] BIGINT          NULL,
    [KitItemMasterId]  BIGINT          NULL,
    [Qty]              INT             NULL,
    [UnitCost]         DECIMAL (18, 2) NULL,
    [ConditionId]      BIGINT          NULL,
    [MasterCompanyId]  BIGINT          NULL,
    [Migrated_Id]      BIGINT          NULL,
    [SuccessMsg]       VARCHAR (500)   NULL,
    [ErrorMsg]         VARCHAR (500)   NULL,
    [Date_Created]     DATETIME2 (7)   NULL,
    CONSTRAINT [PK_KitMasters] PRIMARY KEY CLUSTERED ([KitMasterId] ASC)
);


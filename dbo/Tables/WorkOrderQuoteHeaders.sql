CREATE TABLE [dbo].[WorkOrderQuoteHeaders] (
    [WOQHeaderId]     BIGINT        NOT NULL,
    [WOQHeaderNumber] VARCHAR (100) NULL,
    [QuoteVersion]    VARCHAR (10)  NULL,
    [CustomerId]      BIGINT        NULL,
    [EntryDate]       DATETIME2 (7) NULL,
    [CurrencyId]      BIGINT        NULL,
    [Notes]           VARCHAR (MAX) NULL,
    [WqsId]           BIGINT        NULL,
    [ExpireDate]      DATETIME2 (7) NULL,
    [SentDate]        DATETIME2 (7) NULL,
    [ApprovedDate]    DATETIME2 (7) NULL,
    [DateCreated]     DATETIME2 (7) NULL,
    [MasterCompanyId] BIGINT        NULL,
    [Migrated_Id]     BIGINT        NULL,
    [SuccessMsg]      VARCHAR (500) NULL,
    [ErrorMsg]        VARCHAR (500) NULL,
    CONSTRAINT [PK_WorkOrderQuoteHeaders] PRIMARY KEY CLUSTERED ([WOQHeaderId] ASC)
);


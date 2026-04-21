CREATE TABLE [dbo].[StockTransactions] (
    [StockTransactionId]  BIGINT        NOT NULL,
    [StocklineParentId]   BIGINT        NULL,
    [StocklineId]         BIGINT        NULL,
    [WorkOrderMaterialId] BIGINT        NULL,
    [WorkOrderTaskToolId] BIGINT        NULL,
    [Qty]                 INT           NULL,
    [TranDate]            DATETIME2 (7) NULL,
    [TransactionType]     VARCHAR (10)  NULL,
    [ROPartId]            BIGINT        NULL,
    [QtyReverse]          INT           NULL,
    [QtyBilled]           INT           NULL,
    [EntryDate]           DATETIME2 (7) NULL,
    [MasterCompanyId]     BIGINT        NULL,
    [Migrated_Id]         BIGINT        NULL,
    [SuccessMsg]          VARCHAR (500) NULL,
    [ErrorMsg]            VARCHAR (500) NULL,
    CONSTRAINT [PK_StockTransactions] PRIMARY KEY CLUSTERED ([StockTransactionId] ASC)
);


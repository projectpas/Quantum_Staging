CREATE TABLE [dbo].[Term_Codes] (
    [TermCodesId]     INT             NOT NULL,
    [TermCode]        VARCHAR (250)   NULL,
    [Description]     VARCHAR (250)   NULL,
    [Days]            INT             NULL,
    [DueDays]         INT             NULL,
    [Discount]        DECIMAL (18, 2) NULL,
    [Cod_Flag]        BIT             NULL,
    [MasterCompanyId] BIGINT          NULL,
    CONSTRAINT [PK_Term_Codes] PRIMARY KEY CLUSTERED ([TermCodesId] ASC)
);


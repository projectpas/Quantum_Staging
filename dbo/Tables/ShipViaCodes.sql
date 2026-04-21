CREATE TABLE [dbo].[ShipViaCodes] (
    [ShipViaCodeId] INT           NOT NULL,
    [ShipViaCode]   VARCHAR (250) NULL,
    [Description]   VARCHAR (250) NULL,
    CONSTRAINT [PK_ShipViaCodes] PRIMARY KEY CLUSTERED ([ShipViaCodeId] ASC)
);


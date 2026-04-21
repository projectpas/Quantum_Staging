/*************************************************************             
 ** File:   [MigrateItemMasterRecords]
 ** Author:   Vishal Suthar
 ** Description: This stored procedure is used to Migrate Item Master Records
 ** Purpose:           
 ** Date:   11/02/2023

 ** PARAMETERS:

 ** RETURN VALUE:

 **************************************************************
  ** Change History
 **************************************************************
 ** PR   Date         Author			Change Description
 ** --   --------     -------			-----------------------
    1    11/02/2023   Vishal Suthar		Created
  

declare @p5 int
set @p5=NULL
declare @p6 int
set @p6=NULL
declare @p7 int
set @p7=NULL
declare @p8 int
set @p8=NULL
exec sp_executesql N'EXEC MigrateItemMasterRecords @FromMasterComanyID, @UserName, @Processed OUTPUT, @Migrated OUTPUT, @Failed OUTPUT, @Exists OUTPUT',N'@FromMasterComanyID int,@UserName nvarchar(12),@Processed int output,@Migrated int output,@Failed int output,@Exists int output',@FromMasterComanyID=12,@UserName=N'ROGER BENTLY',@Processed=@p5 output,@Migrated=@p6 output,@Failed=@p7 output,@Exists=@p8 output
select @p5, @p6, @p7, @p8
**************************************************************/
CREATE   PROCEDURE [dbo].[MigrateItemMasterRecords]
(
	@FromMasterComanyID INT = NULL,
	@UserName VARCHAR(100) NULL,
	@Processed INT OUTPUT,
	@Migrated INT OUTPUT,
	@Failed INT OUTPUT,
	@Exists INT OUTPUT
)
AS
BEGIN
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
  SET NOCOUNT ON
  
    BEGIN TRY  
    BEGIN TRANSACTION  
    BEGIN
		DECLARE @LoopID AS INT;

		IF OBJECT_ID(N'tempdb..#TempItemMaster') IS NOT NULL
		BEGIN
			DROP TABLE #TempItemMaster
		END

		CREATE TABLE #TempItemMaster
		(
			ID bigint NOT NULL IDENTITY,
			[ItemMasterId] [bigint] NOT NULL,
			[CurrencyId] [bigint] NULL,
			[ItemGroupId] [bigint] NULL,
			[ItemClassificationId] [bigint] NULL,
			[ManufacturerId] [bigint] NULL,
			[UnitOfMeasureId] [bigint] NULL,
			[PartNumber] [varchar](100) NULL,
			[PartDescription] [varchar](max) NULL,
			[Hazard_Material] [varchar](10) NULL,
			[DER_Flag] [varchar](10) NULL,
			[Reorder_Cond_Level] decimal(18, 2) NULL,
			[MinimumOrderQuantity] [int] NULL,
			[PartListPrice] decimal(18, 2) NULL,
			[NotesAdded] [varchar](5000) NULL,
			[IsActive] [varchar](10) NULL,
			[Date_Created] datetime2(7) NULL,
			[IsTimeLife] [varchar](10) NULL,
			[IsSerialized] [varchar](10) NULL,
			[Shelf_Life] [varchar](10) NULL,
			[List_Price_Date] datetime2(7) NULL,
			[ECC_Number] [varchar](100) NULL,
			[ITAR_Number] [varchar](100) NULL,
			[Shelf_Life_Days] [int] NULL,
			[PMA_Flag] [varchar](10) NULL,
			[Procurement] [varchar](100) NULL,
			[IsHOTPart] [varchar](10) NULL,
			[LeadDays] [int] NULL,
			[Migrated_Id] BIGINT NULL,
			[SuccessMsg] [varchar](500) NULL,
			[ErrorMsg] [varchar](500) NULL
		)

		INSERT INTO #TempItemMaster ([ItemMasterId],[CurrencyId],[ItemGroupId],[ItemClassificationId],[ManufacturerId],[UnitOfMeasureId],[PartNumber],[PartDescription],
		[Hazard_Material],[DER_Flag],[Reorder_Cond_Level],[MinimumOrderQuantity],[PartListPrice],[NotesAdded],[IsActive],[Date_Created],[IsTimeLife],[IsSerialized],
		[Shelf_Life],[List_Price_Date],[ECC_Number],[ITAR_Number],[Shelf_Life_Days],[PMA_Flag],[Procurement],[IsHOTPart],[LeadDays],[Migrated_Id],[SuccessMsg],[ErrorMsg])
		SELECT [ItemMasterId],[CurrencyId],[ItemGroupId],[ItemClassificationId],[ManufacturerId],[UnitOfMeasureId],[PartNumber],[PartDescription],
		[Hazard_Material],[DER_Flag],[Reorder_Cond_Level],[MinimumOrderQuantity],[PartListPrice],[NotesAdded],[IsActive],[Date_Created],[IsTimeLife],[IsSerialized],
		[Shelf_Life],[List_Price_Date],[ECC_Number],[ITAR_Number],[Shelf_Life_Days],[PMA_Flag],[Procurement],[IsHOTPart],[LeadDays],[Migrated_Id],[SuccessMsg],[ErrorMsg] 
		FROM [Quantum_Staging].dbo.ItemMasters IM WITH (NOLOCK) WHERE IM.Migrated_Id IS NULL;

		DECLARE @ProcessedRecords INT = 0;
		DECLARE @MigratedRecords INT = 0;
		DECLARE @RecordsWithError INT = 0;
		DECLARE @RecordExits INT = 0;

		DECLARE @TotCount AS INT;
		SELECT @TotCount = COUNT(*), @LoopID = MIN(ID) FROM #TempItemMaster;

		WHILE (@LoopID <= @TotCount)
		BEGIN
			SET @ProcessedRecords = @ProcessedRecords + 1;

			DECLARE @PN VARCHAR(100) = NULL;
			DECLARE @ManufacturerId BIGINT = 0;
			DECLARE @ItemGroupdId BIGINT = 0;
			DECLARE @ItemClassificationId BIGINT = 0;
			DECLARE @GLAccountId BIGINT = 0;
			DECLARE @UOM_AUTO_KEY AS FLOAT = 0;
			DECLARE @UOMId BIGINT = 0;
			DECLARE @PriorityId BIGINT = 0;
			DECLARE @CurrencyId BIGINT = 0;
			DECLARE @CurrentItemMasterId BIGINT = 0;
			DECLARE @InsertedPartId BIGINT = 0;
			DECLARE @InsertedItemMasterId BIGINT = 0;
			DECLARE @AssetAcquisitionTypeId_BUY BIGINT = 0;
			DECLARE @AssetAcquisitionTypeId_MAKE BIGINT = 0;

			DECLARE @FoundError BIT = 0;
			DECLARE @ErrorMsg VARCHAR(MAX) = '';

			SELECT @CurrentItemMasterId = ItemMasterId, @PN = PartNumber, @ManufacturerId = ManufacturerId, @ItemGroupdId = ItemGroupId, @ItemClassificationId = ItemClassificationId, @UOM_AUTO_KEY = UnitOfMeasureId FROM #TempItemMaster WHERE ID = @LoopID;

			IF (ISNULL(@PN, '') = '')
			BEGIN
				SET @FoundError = 1;
				SET @ErrorMsg = @ErrorMsg + '<p>Part Number is missing</p>'
			END
			IF (ISNULL(@ManufacturerId, 0) = 0)
			BEGIN
				SET @FoundError = 1;
				SET @ErrorMsg = @ErrorMsg + '<p>Manufacturer Id is missing</p>'
			END
			IF (ISNULL(@ItemGroupdId, 0) = 0)
			BEGIN
				SET @FoundError = 1;
				SET @ErrorMsg = @ErrorMsg + '<p>Item Groupd Id is missing</p>'
			END
			IF (ISNULL(@ItemClassificationId, 0) = 0)
			BEGIN
				SET @FoundError = 1;
				SET @ErrorMsg = @ErrorMsg + '<p>Item Classification Id is missing</p>'
			END
			IF (ISNULL(@UOM_AUTO_KEY, 0) = 0)
			BEGIN
				SET @FoundError = 1;
				SET @ErrorMsg = @ErrorMsg + '<p>Unit Of Measure is missing</p>'
			END
			
			IF (@FoundError = 1)
			BEGIN
				UPDATE IMs
				SET IMs.ErrorMsg = ErrorMsg
				FROM DBO.ItemMasters IMs WHERE IMs.ItemMasterId = @CurrentItemMasterId;

				SET @RecordsWithError = @RecordsWithError + 1;
			END

			IF (@FoundError = 0)
			BEGIN
				IF NOT EXISTS (SELECT 1 FROM [PAS_BETA].DBO.GLAccount GL WITH (NOLOCK) WHERE AccountCode = '10000' AND MasterCompanyId = @FromMasterComanyID)
				BEGIN
					INSERT INTO [PAS_BETA].DBO.GLAccount ([OldAccountCode],[AccountCode],[AccountName],[AccountDescription],[AllowManualJE],[GLAccountTypeId],[GLClassFlowClassificationId],
					[MasterCompanyId],[CreatedBy],[UpdatedBy],[CreatedDate],[UpdatedDate],[IsActive],[IsDeleted],[POROCategoryId],[GLAccountNodeId],[LedgerId],[LedgerName],[InterCompany],
					[Category1099Id],[Threshold],[IsManualJEReference],[ReferenceTypeId])
					VALUES (NULL, '10000', 'Cash', '', 1, (SELECT GLC.GLAccountClassId FROM [PAS_BETA].DBO.GLAccountClass GLC WITH (NOLOCK) WHERE GLC.GLAccountClassName = 'Asset' AND GLC.MasterCompanyId = @FromMasterComanyID), 
					(SELECT GLCF.GLClassFlowClassificationId FROM [PAS_BETA].DBO.GLCashFlowClassification GLCF WITH (NOLOCK) WHERE GLCF.GLClassFlowClassificationName = 'OPERATING ACTIVITY' AND GLCF.MasterCompanyId = @FromMasterComanyID),
					@FromMasterComanyID, @UserName, @UserName, GETDATE(), GETDATE(), 1, 0, NULL, NULL, 0, '', 0, NULL, NULL, NULL, NULL)
				END
				SELECT @GLAccountId = GLAccountId FROM [PAS_BETA].DBO.GLAccount GL WITH (NOLOCK) WHERE AccountCode = '10000' AND MasterCompanyId = @FromMasterComanyID;
				SELECT @UOMId = UnitOfMeasureId FROM [PAS_BETA].DBO.UnitOfMeasure MF WHERE UPPER(MF.ShortName) IN (SELECT UPPER(UOM_CODE) FROM [Quantum].QCTL_NEW_3.UOM_CODES Where UOM_AUTO_KEY = @UOM_AUTO_KEY) AND MasterCompanyId = @FromMasterComanyID;
				SELECT @ManufacturerId = ManufacturerId FROM [PAS_BETA].DBO.Manufacturer MF WHERE UPPER(MF.[Name]) IN (SELECT UPPER(DESCRIPTION) FROM [Quantum].QCTL_NEW_3.MANUFACTURER Where MFG_AUTO_KEY = @ManufacturerId) AND MasterCompanyId = @FromMasterComanyID;
				SELECT @PriorityId = PriorityId FROM [PAS_BETA].DBO.[Priority] P WHERE UPPER(Description) = 'ROUTINE' AND MasterCompanyId = @FromMasterComanyID;
				SELECT @CurrencyId = CurrencyId FROM [PAS_BETA].DBO.[Currency] C WHERE UPPER(Code) = 'USD' AND MasterCompanyId = @FromMasterComanyID;
				SELECT @AssetAcquisitionTypeId_BUY = AssetAcquisitionTypeId FROM [PAS_BETA].DBO.[AssetAcquisitionType] C WHERE UPPER(Name) = 'BUY' AND MasterCompanyId = @FromMasterComanyID;
				SELECT @AssetAcquisitionTypeId_MAKE = AssetAcquisitionTypeId FROM [PAS_BETA].DBO.[AssetAcquisitionType] C WHERE UPPER(Name) = 'MAKE' AND MasterCompanyId = @FromMasterComanyID;

				DECLARE @DefaultSiteId BIGINT;
				SELECT @DefaultSiteId = SiteId FROM [PAS_BETA].dbo.[Site] WHERE UPPER([Name]) = UPPER('MIG') AND MasterCompanyId = @FromMasterComanyID;

				IF NOT EXISTS (SELECT 1 FROM [PAS_BETA].dbo.[ItemMaster] WITH (NOLOCK) WHERE UPPER([partnumber]) = UPPER(@PN) AND MasterCompanyId = @FromMasterComanyID)
				BEGIN
					INSERT INTO [PAS_BETA].[dbo].[MasterParts]
					([PartNumber], [Description], [MasterCompanyId], [CreatedDate], [CreatedBy], [UpdatedDate], [UpdatedBy], [IsActive], [IsDeleted], [ManufacturerId], [PartType])
					SELECT T.PartNumber, T.PartDescription, @FromMasterComanyID, GETDATE(), @UserName, GETDATE(), @UserName, 1, 0, @ManufacturerId, NULL
					FROM #TempItemMaster AS T WHERE ID = @LoopID;

					SET @InsertedPartId = SCOPE_IDENTITY();

					INSERT INTO [PAS_BETA].[dbo].[ItemMaster]
					 ([ItemTypeId],[PartAlternatePartId],[ItemGroupId],[ItemClassificationId],[IsHazardousMaterial],[IsExpirationDateAvailable],[ExpirationDate]
					,[IsReceivedDateAvailable],[DaysReceived],[IsManufacturingDateAvailable],[ManufacturingDays],[IsTagDateAvailable],[TagDays],[IsOpenDateAvailable]
					,[OpenDays],[IsShippedDateAvailable],[ShippedDays],[IsOtherDateAvailable],[OtherDays],[ProvisionId],[ManufacturerId],[IsDER],[NationalStockNumber],[IsSchematic]
					,[OverhaulHours],[RPHours],[TestHours],[RFQTracking],[GLAccountId],[PurchaseUnitOfMeasureId],[StockUnitOfMeasureId],[ConsumeUnitOfMeasureId],[LeadTimeDays]
					,[ReorderPoint],[ReorderQuantiy],[MinimumOrderQuantity],[PartListPrice],[PriorityId],[WarningId],[Memo],[ExportCountryId],[ExportValue],[ExportCurrencyId]
					,[ExportWeight],[ExportWeightUnit],[ExportSizeLength],[ExportSizeWidth],[ExportSizeHeight],[ExportSizeUnit],[ExportClassificationId],[PurchaseCurrencyId]
					,[SalesIsFixedPrice],[SalesCurrencyId],[SalesLastSalePriceDate],[SalesLastSalesDiscountPercentDate],[IsActive],[CurrencyId],[MasterCompanyId],[CreatedBy]
					,[UpdatedBy],[CreatedDate],[UpdatedDate],[TurnTimeOverhaulHours],[TurnTimeRepairHours],[SoldUnitOfMeasureId],[IsDeleted],[ExportUomId],[partnumber],[PartDescription]
					,[isTimeLife],[isSerialized],[ManagementStructureId],[ShelfLife],[DiscountPurchasePercent],[UnitCost],[ListPrice],[PriceDate],[ItemNonStockClassificationId]
					,[StockLevel],[ExportECCN],[ITARNumber],[ShelfLifeAvailable],[mfgHours],[IsPma],[turnTimeMfg],[turnTimeBenchTest],[IsExportUnspecified],[IsExportNONMilitary]
					,[IsExportMilitary],[IsExportDual],[IsOemPNId],[MasterPartId],[RepairUnitOfMeasureId],[RevisedPartId],[SiteId],[WarehouseId],[LocationId],[ShelfId]
					,[BinId],[ItemMasterAssetTypeId],[IsHotItem],[ExportSizeUnitOfMeasureId],[IsAcquiredMethodBuy],[IsOEM],[RevisedPart],[OEMPN],[ItemClassificationName]
					,[ItemGroup],[AssetAcquistionType],[ManufacturerName],[PurchaseUnitOfMeasure],[StockUnitOfMeasure],[ConsumeUnitOfMeasure],[PurchaseCurrency],[SalesCurrency]
					,[GLAccount],[Priority],[SiteName],[WarehouseName],[LocationName],[ShelfName],[BinName],[CurrentStlNo],[MTBUR],[NE],[NS],[OH],[REP],[SVC],[Figure],[Item])

					SELECT 1, NULL, @ItemGroupdId, @ItemClassificationId, (CASE WHEN HAZARD_MATERIAL = 'T' THEN 1 ELSE 0 END), 0, NULL
					,0, 0, 0, 0, 0, 0, 0
					,0, 0, 0, 0, 0, NULL, @ManufacturerId, (CASE WHEN DER_FLAG = 'T' THEN 1 ELSE 0 END), NULL, 0
					,0, 0, 0, 0, @GLAccountId, @UOMId, NULL, NULL, CAST(ISNULL(LeadDays, 0) AS INT)
					,CAST(ISNULL(REORDER_COND_LEVEL, 0) AS INT), 0, CAST(MinimumOrderQuantity AS INT), CAST(PartListPrice AS DECIMAL), @PriorityId, NULL, NotesAdded, NULL, NULL, NULL
					,NULL, NULL, NULL, NULL, NULL, NULL, NULL, @CurrencyId
					,NULL, @CurrencyId, GETDATE(), GETDATE(), CASE WHEN T.IsActive = 'T' THEN 1 ELSE 0 END, @CurrencyId, @FromMasterComanyID, @UserName
					,@UserName, CASE WHEN T.DATE_CREATED IS NOT NULL THEN CAST(T.DATE_CREATED AS Datetime2) ELSE GETDATE() END, CASE WHEN T.DATE_CREATED IS NOT NULL THEN CAST(T.DATE_CREATED AS Datetime2) ELSE GETDATE() END, 0, 0, NULL, 0, NULL, T.PartNumber, T.PartDescription
					,(CASE WHEN ISNULL(T.IsTimeLife, 'F') = 'T' THEN 1 ELSE 0 END), (CASE WHEN ISNULL(T.IsSerialized, 'F') = 'T' THEN 1 ELSE 0 END), NULL, (CASE WHEN ISNULL(T.SHELF_LIFE, 'F') = 'T' THEN 1 ELSE 0 END), NULL, NULL, CAST(ISNULL(PartListPrice, 0) AS decimal), LIST_PRICE_DATE, NULL
					,0, ECC_NUMBER, ITAR_NUMBER, CAST(SHELF_LIFE_DAYS AS NUMERIC), 0, (CASE WHEN ISNULL(T.PMA_FLAG, 'F') = 'T' THEN 1 ELSE 0 END), 0, 0, NULL, NULL
					,NULL, NULL, NULL, @InsertedPartId, NULL, NULL, @DefaultSiteId, NULL, NULL, NULL
					,NULL, (CASE WHEN T.PROCUREMENT = 'BUY' THEN @AssetAcquisitionTypeId_BUY WHEN T.PROCUREMENT = 'MAKE' THEN @AssetAcquisitionTypeId_MAKE ELSE @AssetAcquisitionTypeId_BUY END), (CASE WHEN ISNULL(T.IsHOTPart, 'F') = 'T' THEN 1 ELSE 0 END), NULL, 0, (CASE WHEN ISNULL(T.PMA_FLAG, 'F') = 'F' THEN 1 ELSE 0 END), NULL, NULL, NULL
					,NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL
					,NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, 0, 0, 0, 0, 0, NULL, NULL
					FROM #TempItemMaster AS T WHERE ID = @LoopID;

					SET @InsertedItemMasterId = SCOPE_IDENTITY();

					EXEC [PAS_BETA].dbo.UpdateItemMasterDetail @InsertedItemMasterId;

					UPDATE IMs
					SET IMs.Migrated_Id = @InsertedPartId,
					IMs.SuccessMsg = 'Record migrated successfully'
					FROM DBO.ItemMasters IMs WHERE IMs.ItemMasterId = @CurrentItemMasterId;

					SET @MigratedRecords = @MigratedRecords + 1;
				END
				ELSE
				BEGIN
					UPDATE IMs
					SET IMs.ErrorMsg = ISNULL(ErrorMsg, '') + '<p>Item Master record already exists</p>'
					FROM DBO.ItemMasters IMs WHERE IMs.ItemMasterId = @CurrentItemMasterId;

					SET @RecordExits = @RecordExits + 1;
				END
			END

			SET @LoopID = @LoopID + 1;
		END
	END

	COMMIT TRANSACTION

	SET @Processed = @ProcessedRecords;
	SET @Migrated = @MigratedRecords;
	SET @Failed = @RecordsWithError;
	SET @Exists = @RecordExits;

	SELECT @Processed, @Migrated, @Failed, @Exists;
  END TRY
  BEGIN CATCH
    IF @@trancount > 0
	  ROLLBACK TRAN;
	  SELECT
    ERROR_NUMBER() AS ErrorNumber,
    ERROR_STATE() AS ErrorState,
    ERROR_SEVERITY() AS ErrorSeverity,
    ERROR_PROCEDURE() AS ErrorProcedure,
    ERROR_LINE() AS ErrorLine,
    ERROR_MESSAGE() AS ErrorMessage;
	  DECLARE @ErrorLogID int
	  ,@DatabaseName varchar(100) = DB_NAME()
		-----------------------------------PLEASE CHANGE THE VALUES FROM HERE TILL THE NEXT LINE---------------------------------------
	  ,@AdhocComments varchar(150) = 'MigrateItemMasterRecords'
	  ,@ProcedureParameters varchar(3000) = '@Parameter1 = ' + ISNULL(CAST(@FromMasterComanyID AS VARCHAR(10)), '') + ''
	  ,@ApplicationName varchar(100) = 'PAS'
	  -----------------------------------PLEASE DO NOT EDIT BELOW----------------------------------------
	  RAISERROR ('Unexpected Error Occured in the database. Please let the support team know of the error number : %d', 16, 1, @ErrorLogID)  
	  RETURN (1);  
	 END CATCH  
END
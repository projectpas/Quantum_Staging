/* 
[dbo].[ItemMasterStockList] 1, 10, NULL, 1, 12 
*/
CREATE   PROCEDURE [dbo].[ItemMasterStockList]
	@PageNumber INT = NULL,
	@PageSize INT = NULL,
	@SortColumn VARCHAR(50) = NULL,
	@SortOrder INT = NULL,
	@MasterCompanyId BIGINT = NULL
AS
BEGIN
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
	BEGIN TRY

	DECLARE @RecordFrom INT;
	DECLARE @Count INT;
	DECLARE @IsActive BIT;
	
	SET @RecordFrom = (@PageNumber - 1) * @PageSize;
	
	IF @SortColumn IS NULL
	BEGIN
		SET @SortColumn = UPPER('CreatedDate')
	END 
	ELSE
	BEGIN 
		Set @SortColumn = UPPER(@SortColumn)
	END	
	
	SET @IsActive = NULL;
		
		;WITH Result AS(
			SELECT DISTINCT im.ItemMasterId,
				im.PartNumber,
				im.PartDescription,
				(ISNULL(im.ManufacturerName,'')) 'Manufacturerdesc',
				im.ItemClassificationName 'Classificationdesc',
				(ISNULL(im.ItemGroup,'')) 'ItemGroup',
				im.NationalStockNumber,	
				CASE WHEN im.IsSerialized = 1 THEN 'Yes' ELSE 'No' END AS IsSerialized,
				CASE WHEN im.IsTimeLife = 1 THEN 'Yes' ELSE 'No' END AS IsTimeLife,
				im.IsActive,
				ItemType = CASE WHEN im.ItemTypeId = 1 THEN 'Stock' ELSE 'NonStock' END,					   
				CAST(im.IsHazardousMaterial AS varchar) 'IsHazardousMaterial',
				StockType = (CASE WHEN im.IsPma = 1 AND im.IsDER = 1 THEN 'PMA&DER'
									WHEN im.IsPma = 1 AND im.IsDER = 0 THEN 'PMA' 
					                WHEN im.IsPma = 0 AND im.IsDER = 1  THEN 'DER' 
									ELSE 'OEM'
							END),                       
				im.CreatedDate,
                im.UpdatedDate,
				im.CreatedBy,
                im.UpdatedBy,	
				im.IsDeleted
			FROM dbo.ItemMasters IMs WITH (NOLOCK)
			LEFT JOIN [PAS_BETA].dbo.ItemMaster im ON IMs.Migrated_Id = im.ItemMasterId
		 	  WHERE ((im.IsDeleted = 0) AND (@IsActive IS NULL OR im.IsActive = @IsActive))
			  AND im.MasterCompanyId=@MasterCompanyId AND im.ItemTypeId = 1 	
			), ResultCount AS(Select COUNT(ItemMasterId) AS totalItems FROM Result)
			SELECT * INTO #TempResult FROM  Result

			SELECT @Count = COUNT(ItemMasterId) FROM #TempResult			

			SELECT *, @Count AS NumberOfItems FROM #TempResult ORDER BY  
			CASE WHEN (@SortOrder = 1 AND @SortColumn = 'PartNumber')  THEN PartNumber END ASC,
			CASE WHEN (@SortOrder = -1 AND @SortColumn='PartNumber')  THEN PartNumber END DESC,
			CASE WHEN (@SortOrder = 1 AND @SortColumn='PartDescription')  THEN PartDescription END ASC,
			CASE WHEN (@SortOrder = -1 AND @SortColumn='PartDescription')  THEN PartDescription END DESC,
			CASE WHEN (@SortOrder = 1 AND @SortColumn='Manufacturerdesc')  THEN Manufacturerdesc END ASC,
			CASE WHEN (@SortOrder=-1 AND @SortColumn='Manufacturerdesc')  THEN Manufacturerdesc END DESC,			
			CASE WHEN (@SortOrder=1  AND @SortColumn='Classificationdesc')  THEN Classificationdesc END ASC,
			CASE WHEN (@SortOrder=-1 AND @SortColumn='Classificationdesc')  THEN Classificationdesc END DESC,
			CASE WHEN (@SortOrder=1  AND @SortColumn='ItemGroup')  THEN ItemGroup END ASC,
			CASE WHEN (@SortOrder=-1 AND @SortColumn='ItemGroup')  THEN ItemGroup END DESC,
			CASE WHEN (@SortOrder=1  AND @SortColumn='NationalStockNumber')  THEN NationalStockNumber END ASC,
			CASE WHEN (@SortOrder=-1 AND @SortColumn='NationalStockNumber')  THEN NationalStockNumber END DESC, 			
			CASE WHEN (@SortOrder=1  AND @SortColumn='IsSerialized')  THEN IsSerialized END ASC,
			CASE WHEN (@SortOrder=-1 AND @SortColumn='IsSerialized')  THEN IsSerialized END DESC, 
			CASE WHEN (@SortOrder=1  AND @SortColumn='IsTimeLife')  THEN IsTimeLife END ASC,
			CASE WHEN (@SortOrder=-1 AND @SortColumn='IsTimeLife')  THEN IsTimeLife END DESC,	
			CASE WHEN (@SortOrder=1  AND @SortColumn='ItemType')  THEN ItemType END ASC,
			CASE WHEN (@SortOrder=-1 AND @SortColumn='ItemType')  THEN ItemType END DESC,
			CASE WHEN (@SortOrder=1  AND @SortColumn='StockType')  THEN StockType END ASC,
			CASE WHEN (@SortOrder=-1 AND @SortColumn='StockType')  THEN StockType END DESC,			
			CASE WHEN (@SortOrder=1  AND @SortColumn='CreatedBy')  THEN CreatedBy END ASC,
			CASE WHEN (@SortOrder=-1 AND @SortColumn='CreatedBy')  THEN CreatedBy END DESC,
			CASE WHEN (@SortOrder=1  AND @SortColumn='CreatedDate')  THEN CreatedDate END ASC,
			CASE WHEN (@SortOrder=-1 AND @SortColumn='CreatedDate')  THEN CreatedDate END DESC,
			CASE WHEN (@SortOrder=1  AND @SortColumn='UpdatedBy')  THEN UpdatedBy END ASC,
			CASE WHEN (@SortOrder=-1 AND @SortColumn='UpdatedBy')  THEN UpdatedBy END DESC,
			CASE WHEN (@SortOrder=1  AND @SortColumn='UpdatedDate')  THEN UpdatedDate END ASC,
			CASE WHEN (@SortOrder=-1 AND @SortColumn='UpdatedDate')  THEN UpdatedDate END DESC			
			OFFSET @RecordFrom ROWS 
			FETCH NEXT @PageSize ROWS ONLY
		END TRY
	BEGIN CATCH	
		     DECLARE @ErrorLogID INT
			,@DatabaseName VARCHAR(100) = db_name()
			-----------------------------------PLEASE CHANGE THE VALUES FROM HERE TILL THE NEXT LINE----------------------------------------
			,@AdhocComments VARCHAR(150) = 'ProcItemMasterStockList'
			,@ProcedureParameters VARCHAR(3000) = 
			     '@Parameter1 = ''' + CAST(ISNULL(@PageNumber, '') as Varchar(100))
				 + ' @Parameter2 = ''' +  CAST(ISNULL(@PageSize, '') as Varchar(100))
				 + ' @Parameter3 = ''' + CAST(ISNULL(@SortColumn, '') as Varchar(100))
				 + ' @Parameter4 = ''' + CAST(ISNULL(@SortOrder, '') as Varchar(100))
				 + ' @Parameter5 = ''' + CAST(ISNULL(@MasterCompanyId   , '') as Varchar(100))
				,@ApplicationName VARCHAR(100) = 'PAS'

		-----------------------------------PLEASE DO NOT EDIT BELOW----------------------------------------
		EXEC spLogException @DatabaseName = @DatabaseName
			,@AdhocComments = @AdhocComments
			,@ProcedureParameters = @ProcedureParameters
			,@ApplicationName = @ApplicationName
			,@ErrorLogID = @ErrorLogID OUTPUT;

		RAISERROR ('Unexpected Error Occured in the database. Please let the support team know of the error number : %d', 16, 1, @ErrorLogID)

		RETURN (1);
	END CATCH
END

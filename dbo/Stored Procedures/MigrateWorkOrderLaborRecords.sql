/*************************************************************             
 ** File:   [MigrateWorkOrderLaborRecords]
 ** Author:   Vishal Suthar
 ** Description: This stored procedure is used to Migrate Employee Records
 ** Purpose:           
 ** Date:   18/01/2024

 ** PARAMETERS:

 ** RETURN VALUE:

 **************************************************************
  ** Change History
 **************************************************************
 ** PR   Date         Author			Change Description
 ** --   --------     -------			-----------------------
    1    18/01/2024   Vishal Suthar		Created
  

declare @p5 int
set @p5=NULL
declare @p6 int
set @p6=NULL
declare @p7 int
set @p7=NULL
declare @p8 int
set @p8=NULL
exec sp_executesql N'EXEC MigrateWorkOrderLaborRecords @FromMasterComanyID, @UserName, @Processed OUTPUT, @Migrated OUTPUT, @Failed OUTPUT, @Exists OUTPUT',N'@FromMasterComanyID int,@UserName nvarchar(12),@Processed int output,@Migrated int output,@Failed int output,@Exists int output',@FromMasterComanyID=12,@UserName=N'ROGER BENTLY',@Processed=@p5 output,@Migrated=@p6 output,@Failed=@p7 output,@Exists=@p8 output
select @p5, @p6, @p7, @p8
**************************************************************/
CREATE   PROCEDURE [dbo].[MigrateWorkOrderLaborRecords]
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

		IF OBJECT_ID(N'tempdb..#TempDISTINCTWorkOrderTask') IS NOT NULL
		BEGIN
			DROP TABLE #TempDISTINCTWorkOrderTask
		END

		CREATE TABLE #TempDISTINCTWorkOrderTask
		(
			ID bigint NOT NULL IDENTITY,
			[WorkOrderId] [bigint] NULL
		)

		INSERT INTO #TempDISTINCTWorkOrderTask ([WorkOrderId])
		SELECT DISTINCT [WorkOrderId] FROM [Quantum_Staging].dbo.[WorkOrderTasks] WOT WITH (NOLOCK) WHERE WOT.Migrated_Id IS NULL ORDER BY WOT.WorkOrderId;

		DECLARE @ProcessedRecords INT = 0;
		DECLARE @MigratedRecords INT = 0;
		DECLARE @RecordsWithError INT = 0;
		DECLARE @RecordExits INT = 0;

		DECLARE @TotCount AS INT;
		SELECT @TotCount = COUNT(*), @LoopID = MIN(ID) FROM #TempDISTINCTWorkOrderTask;

		WHILE (@LoopID <= @TotCount)
		BEGIN
			SET @ProcessedRecords = @ProcessedRecords + 1;

			DECLARE @WOO_AUTO_KEY BIGINT;
			SELECT @WOO_AUTO_KEY = WorkOrderId FROM #TempDISTINCTWorkOrderTask AS T WHERE ID = @LoopID;

			DECLARE @WO_Num VARCHAR(100);
			SELECT @WO_Num = WO.WorkOrderNumber FROM Quantum_Staging.dbo.WorkOrderHeaders AS WO WHERE WO.WorkOrderId = @WOO_AUTO_KEY;

			DECLARE @WorkOrder_Id_In_PAS BIGINT;
			SELECT @WorkOrder_Id_In_PAS = WO.WorkOrderId FROM [dbo].[WorkOrder] AS WO WHERE UPPER(WO.WorkOrderNum) = UPPER(@WO_Num) AND WO.MasterCompanyId = @FromMasterComanyID;

			IF (ISNULL(@WorkOrder_Id_In_PAS, 0) != 0)
			BEGIN
				DECLARE @DefaultTaskStatusId BIGINT = NULL;
				DECLARE @DefaultEmployeeId BIGINT = NULL;
				DECLARE @WorkFlowWorkOrderId BIGINT = NULL;
				DECLARE @EmployeeExpertiseId BIGINT = NULL;
				DECLARE @Inserted_WorkOrderLaborHeaderId BIGINT = NULL;
		
				SELECT @DefaultEmployeeId = U.[EmployeeId] FROM [dbo].[AspNetUsers] U WITH(NOLOCK) WHERE JobTitle = 'ADMIN' AND [MasterCompanyId] = @FromMasterComanyID;
				SELECT @EmployeeExpertiseId = EmpExpert.[EmployeeExpertiseId] FROM [dbo].[EmployeeExpertise] EmpExpert WITH(NOLOCK) WHERE EmpExpCode = 'TECHNICIAN' AND [MasterCompanyId] = @FromMasterComanyID;
				SELECT @WorkFlowWorkOrderId = WorkFlowWorkOrderId FROM [dbo].[WorkOrderWorkFlow] AS WOWF WHERE WOWF.WorkOrderId = @WorkOrder_Id_In_PAS;
				SELECT @DefaultTaskStatusId = EmpExpert.[TaskStatusId] FROM [dbo].[TaskStatus] EmpExpert WITH(NOLOCK) WHERE [Description] = 'IN-PROCESS' AND [MasterCompanyId] = @FromMasterComanyID;

				IF (ISNULL(@WorkFlowWorkOrderId, 0) != 0)
				BEGIN
					IF NOT EXISTS (SELECT TOP 1 1 FROM [DBO].[WorkOrderLaborHeader] WHERE WorkOrderId = @WorkOrder_Id_In_PAS AND WorkFlowWorkOrderId = @WorkFlowWorkOrderId AND MasterCompanyId = @FromMasterComanyID)
					BEGIN
						INSERT INTO [DBO].[WorkOrderLaborHeader] ([WorkOrderId],[WorkFlowWorkOrderId],[DataEnteredBy],[HoursorClockorScan],[IsTaskCompletedByOne],[WorkOrderHoursType],
						[LabourMemo],[MasterCompanyId],[CreatedBy],[UpdatedBy],[CreatedDate],[UpdatedDate],[IsActive],[IsDeleted],[ExpertiseId],[EmployeeId],[TotalWorkHours],[WOPartNoId])
						SELECT @WorkOrder_Id_In_PAS, @WorkFlowWorkOrderId, @DefaultEmployeeId, 2, 0, 1, 
						'', @FromMasterComanyID, @UserName, @UserName, GETDATE(), GETDATE(), 1, 0, @EmployeeExpertiseId, NULL, 0, 0
						FROM #TempDISTINCTWorkOrderTask WHERE ID = @LoopID;

						SELECT @Inserted_WorkOrderLaborHeaderId = SCOPE_IDENTITY();
					END
					ELSE
					BEGIN
						SELECT @Inserted_WorkOrderLaborHeaderId = WorkOrderLaborHeaderId FROM [DBO].[WorkOrderLaborHeader] 
						WHERE WorkOrderId = @WorkOrder_Id_In_PAS AND WorkFlowWorkOrderId = @WorkFlowWorkOrderId AND MasterCompanyId = @FromMasterComanyID;
					END

					IF OBJECT_ID(N'tempdb..#TempWO_TASK') IS NOT NULL
					BEGIN
						DROP TABLE #TempWO_TASK
					END

					CREATE TABLE #TempWO_TASK
					(
						ID bigint NOT NULL IDENTITY,
						[WorkOrderTaskId] [bigint] NOT NULL,
						[WorkOrderId] [bigint] NULL,
						[OperationTaskId] [bigint] NULL,
						[WorkOrderTakMasterId] [bigint] NULL,
						[WorkOrderStageId] [bigint] NULL,
						[OperationMasterId] [bigint] NULL,
						[Notes] [varchar](max) NULL,
						[StdDays] [int] NULL,
						[DelayDays] [int] NULL,
						[LastStatusChange] [datetime2](7) NULL,
						[TaskDays] [decimal](18, 2) NULL,
						[DaysVar] [decimal](18, 2) NULL,
						[LaborHours] [decimal](18, 2) NULL,
						[LaborVar] [decimal](18, 2) NULL,
						[FirstOpenDate] [datetime2](7) NULL,
						[LastCloseDate] [datetime2](7) NULL,
						[TaskStart] [datetime2](7) NULL,
						[WorkOrderParentTaskId] [bigint] NULL,
						[SysUserId] [bigint] NULL,
						[SysUserSignOff] [decimal](18, 2) NULL,
						[SignOffDate] [datetime2](7) NULL,
						[CustomerId] [bigint] NULL,
						[DateCreated] [datetime2](7) NULL,
						[MasterCompanyId] [bigint] NULL,
						[Migrated_Id] [bigint] NULL,
						[SuccessMsg] [varchar](500) NULL,
						[ErrorMsg] [varchar](500) NULL
					)

					INSERT INTO #TempWO_TASK ([WorkOrderTaskId],[WorkOrderId],[OperationTaskId],[WorkOrderTakMasterId],[WorkOrderStageId],[OperationMasterId],[Notes],[StdDays],[DelayDays],[LastStatusChange],[TaskDays],
						[DaysVar],[LaborHours],[LaborVar],[FirstOpenDate],[LastCloseDate],[TaskStart],[WorkOrderParentTaskId],[SysUserId],[SysUserSignOff],[SignOffDate],[CustomerId],[DateCreated],[MasterCompanyId],
						[Migrated_Id],[SuccessMsg],[ErrorMsg])
					SELECT [WorkOrderTaskId],[WorkOrderId],[OperationTaskId],[WorkOrderTakMasterId],[WorkOrderStageId],[OperationMasterId],[Notes],[StdDays],[DelayDays],[LastStatusChange],[TaskDays],
						[DaysVar],[LaborHours],[LaborVar],[FirstOpenDate],[LastCloseDate],[TaskStart],[WorkOrderParentTaskId],[SysUserId],[SysUserSignOff],[SignOffDate],[CustomerId],[DateCreated],[MasterCompanyId],
						[Migrated_Id],[SuccessMsg],[ErrorMsg]
					FROM Quantum_Staging.dbo.WorkOrderTasks WHERE WorkOrderId = @WOO_AUTO_KEY;

					DECLARE @ChildLoopID AS INT;
					DECLARE @ChildTotCount AS INT;
					SELECT @ChildTotCount = COUNT(*), @ChildLoopID = MIN(ID) FROM #TempWO_TASK;

					WHILE (@ChildLoopID <= @ChildTotCount)
					BEGIN
						DECLARE @WTM_AUTO_KEY BIGINT;
						DECLARE @WOT_AUTO_KEY BIGINT;
						DECLARE @SYSUR_AUTO_KEY BIGINT;
						DECLARE @WO_TASK_DESC VARCHAR(500);
						DECLARE @TaskId_In_PAS BIGINT = NULL;
						DECLARE @EmployeeId_In_WOTask_PAS BIGINT;
						DECLARE @EmployeeCode_In_WOTask_Quantum VARCHAR(500);
			
						SELECT @WTM_AUTO_KEY = WorkOrderTakMasterId, @WOT_AUTO_KEY = WorkOrderTaskId, @SYSUR_AUTO_KEY = T.SysUserId FROM #TempWO_TASK AS T WHERE ID = @ChildLoopID;
						SELECT @WO_TASK_DESC = [DESCRIPTION] FROM [Quantum].QCTL_NEW_3.WO_TASK_MASTER AS TM WHERE TM.WTM_AUTO_KEY = @WTM_AUTO_KEY;
						SELECT @EmployeeCode_In_WOTask_Quantum = Emp.EmployeeCode FROM Quantum_Staging.dbo.Employees AS Emp WHERE Emp.SysUserId = @SYSUR_AUTO_KEY;

						IF NOT EXISTS (SELECT TOP 1 1 FROM [DBO].[Task] T WITH (NOLOCK) WHERE UPPER(T.Description) = UPPER(@WO_TASK_DESC) AND T.MasterCompanyId = @FromMasterComanyID)
						BEGIN
							INSERT INTO [DBO].[Task] ([Description],[Memo],[MasterCompanyId],[CreatedBy],[UpdatedBy],[CreatedDate],[UpdatedDate],[IsActive],[IsDeleted],[Sequence],[IsTravelerTask])
							SELECT UPPER(@WO_TASK_DESC), '', @FromMasterComanyID, @UserName, @UserName, GETDATE(), GETDATE(), 1, 0, (@ChildLoopID + 50), 1
							FROM #TempWO_TASK AS T WHERE ID = @ChildLoopID;

							SELECT @TaskId_In_PAS = SCOPE_IDENTITY();
						END
						ELSE
						BEGIN
							SELECT @TaskId_In_PAS = T.TaskId FROM [DBO].[Task] T WHERE UPPER([Description]) = UPPER(@WO_TASK_DESC) AND T.MasterCompanyId = @FromMasterComanyID;
						END

						SELECT @EmployeeId_In_WOTask_PAS = Emp.EmployeeId FROM [DBO].[Employee] Emp 
						WHERE UPPER(Emp.[EmployeeCode]) = UPPER(@EmployeeCode_In_WOTask_Quantum) AND Emp.MasterCompanyId = @FromMasterComanyID;

						INSERT INTO [DBO].[WorkOrderLabor] ([WorkOrderLaborHeaderId],[TaskId],[ExpertiseId],[EmployeeId],[Hours],[Adjustments],[AdjustedHours],[Memo],[CreatedBy],[UpdatedBy],
							[CreatedDate],[UpdatedDate],[IsActive],[IsDeleted],[StartDate],[EndDate],[BillableId],[IsFromWorkFlow],[MasterCompanyId],[DirectLaborOHCost],[BurdaenRatePercentageId],
							[BurdenRateAmount],[TotalCostPerHour],[TotalCost],[TaskStatusId],[StatusChangedDate],[TaskInstruction],[IsBegin])
						SELECT @Inserted_WorkOrderLaborHeaderId, @TaskId_In_PAS, @EmployeeExpertiseId, @EmployeeId_In_WOTask_PAS, 0, 0, 0, '', @UserName, @UserName, 
							T.DateCreated, T.DateCreated, 1, 0, T.FirstOpenDate, NULL, 1, 0, @FromMasterComanyID, 0, NULL, 
							0, 0, 0, @DefaultTaskStatusId, T.LastCloseDate, NULL, NULL
						FROM #TempWO_TASK AS T WHERE ID = @ChildLoopID;

						DECLARE @Hours DECIMAL(18, 2), @Total_Minutes DECIMAL(18, 2), @FinalHourMin DECIMAL(18, 2);
						DECLARE @FinalHours INT = 0, @FinalMinutes INT = 0;
						DECLARE @Inserted_WorkOrderLaborId BIGINT;

						SELECT @Inserted_WorkOrderLaborId = SCOPE_IDENTITY();

						IF OBJECT_ID(N'tempdb..#TempWO_TASK_LABOR') IS NOT NULL
						BEGIN
							DROP TABLE #TempWO_TASK_LABOR
						END

						CREATE TABLE #TempWO_TASK_LABOR
						(
							ID bigint NOT NULL IDENTITY,
							[WorkOrderTaskLaborId] [bigint] NOT NULL,
							[WorkOrderTaskId] [bigint] NULL,
							[SysUserId] [bigint] NULL,
							[SysUserEntryId] [bigint] NULL,
							[StartTime] [datetime2](7) NULL,
							[StopTime] [datetime2](7) NULL,
							[Hours] [decimal](18, 2) NULL,
							[Notes] [varchar](max) NULL,
							[BillingRate] [decimal](18, 2) NULL,
							[BurdenRate] [decimal](18, 2) NULL,
							[WorkOrderSkillsId] [bigint] NULL,
							[ItemMasterId] [bigint] NULL,
							[HoursBilled] [decimal](18, 2) NULL,
							[HoursBillable] [decimal](18, 2) NULL,
							[SvrStartTime] [datetime2](7) NULL,
							[SvrStopTime] [datetime2](7) NULL,
							[DeleteDate] [datetime2](7) NULL,
							[DateCreated] [datetime2](7) NULL,
							[MasterCompanyId] [bigint] NULL,
							[Migrated_Id] [bigint] NULL,
							[SuccessMsg] [varchar](500) NULL,
							[ErrorMsg] [varchar](500) NULL
						)

						INSERT INTO #TempWO_TASK_LABOR ([WorkOrderTaskLaborId],[WorkOrderTaskId],[SysUserId],[SysUserEntryId],[StartTime],[StopTime],[Hours],[Notes],[BillingRate],[BurdenRate],[WorkOrderSkillsId],[ItemMasterId],
							[HoursBilled],[HoursBillable],[SvrStartTime],[SvrStopTime],[DeleteDate],[DateCreated],[MasterCompanyId],[Migrated_Id],[SuccessMsg],[ErrorMsg])
						SELECT [WorkOrderTaskLaborId],[WorkOrderTaskId],[SysUserId],[SysUserEntryId],[StartTime],[StopTime],[Hours],[Notes],[BillingRate],[BurdenRate],[WorkOrderSkillsId],[ItemMasterId],
							[HoursBilled],[HoursBillable],[SvrStartTime],[SvrStopTime],[DeleteDate],[DateCreated],[MasterCompanyId],[Migrated_Id],[SuccessMsg],[ErrorMsg]
						FROM Quantum_Staging.dbo.WorkOrderTaskLabors WHERE WorkOrderTaskId = @WOT_AUTO_KEY;

						DECLARE @Final_HourlyRate DECIMAL(18, 2) = 0;
						DECLARE @TotalFinalMinutes DECIMAL(18, 2) = 0;

						DECLARE @ChildLoopID_Labor AS INT;
						DECLARE @TotCount_Labor AS INT;
						SELECT @TotCount_Labor = COUNT(*), @ChildLoopID_Labor = MIN(ID) FROM #TempWO_TASK_LABOR;

						WHILE (@ChildLoopID_Labor <= @TotCount_Labor)
						BEGIN
							DECLARE @SYSUR_AUTO_KEY_WorkOrderLaborTracking BIGINT;
							DECLARE @EmployeeCode_In_WorkOrderLaborTracking VARCHAR(250);
							DECLARE @EmployeeCode_In_WorkOrderLaborTracking_PAS BIGINT;

							SELECT @SYSUR_AUTO_KEY_WorkOrderLaborTracking = T.SysUserId FROM #TempWO_TASK_LABOR AS T WHERE ID = @ChildLoopID_Labor;
							SELECT @EmployeeCode_In_WorkOrderLaborTracking = Emp.EmployeeCode FROM Quantum_Staging.dbo.Employees AS Emp WHERE Emp.SysUserId = @SYSUR_AUTO_KEY_WorkOrderLaborTracking;

							SELECT @EmployeeCode_In_WorkOrderLaborTracking_PAS = Emp.EmployeeId FROM [DBO].[Employee] Emp 
							WHERE UPPER(Emp.[EmployeeCode]) = UPPER(@EmployeeCode_In_WorkOrderLaborTracking) AND Emp.MasterCompanyId = @FromMasterComanyID;

							DECLARE @Hours_1 DECIMAL(18, 2), @Hoursly_Rate DECIMAL(18, 2), @Total_Minutes_1 DECIMAL(18, 2), @FinalHourMin_1 DECIMAL(18, 2);
							DECLARE @FinalHours_1 INT, @FinalMinutes_1 INT;

							SELECT @Hours_1 = T.HoursBillable, @Hoursly_Rate = T.BurdenRate FROM #TempWO_TASK_LABOR AS T WHERE ID = @ChildLoopID_Labor;
							SET @Total_Minutes_1 = (@Hours_1 * 60);

							SET @FinalHours_1 = ROUND(@Hours_1, 0, 1);
							SET @FinalMinutes_1 = (@Total_Minutes_1 % 60);

							INSERT INTO [DBO].[WorkOrderLaborTracking] ([WorkOrderLaborId],[TaskId],[EmployeeId],[StartTime],[EndTime],[TotalHours],[TotalMinutes],[IsCompleted],
							[MasterCompanyId],[CreatedBy],[UpdatedBy],[CreatedDate],[UpdatedDate],[IsActive],[IsDeleted])
							SELECT @Inserted_WorkOrderLaborId, @TaskId_In_PAS, @EmployeeCode_In_WorkOrderLaborTracking_PAS, T.StartTime, T.StopTime, @FinalHours_1, @FinalMinutes_1, 1,
							@FromMasterComanyID, @UserName, @UserName, T.DateCreated, T.DateCreated, 1, 0
							FROM #TempWO_TASK_LABOR AS T WHERE ID = @ChildLoopID_Labor;

							SET @FinalHours = @FinalHours + @FinalHours_1;
							SET @FinalMinutes = @FinalMinutes + @FinalMinutes_1;

							IF (@Hoursly_Rate > 0)
							BEGIN
								SET @Final_HourlyRate = @Hoursly_Rate;
							END

							SET @ChildLoopID_Labor = @ChildLoopID_Labor + 1;
						END

						IF (@FinalHours >= 0 AND @FinalMinutes >= 0)
						BEGIN
							SET @TotalFinalMinutes = 0;

							SET @TotalFinalMinutes = @FinalHours * 60;
							SET @TotalFinalMinutes = @TotalFinalMinutes + @FinalMinutes;

							DECLARE @FinalHoursToUpdate INT;
							DECLARE @FinalMinutesToUpdate INT;

							SET @FinalHoursToUpdate = @TotalFinalMinutes / 60;
							SET @FinalMinutesToUpdate = @TotalFinalMinutes % 60;

							IF (@FinalHoursToUpdate >= 0 OR @FinalMinutesToUpdate >= 0)
							BEGIN
								DECLARE @FinalHourlyAmout DECIMAL(18, 2);

								SET @FinalHourlyAmout = (CAST(@TotalFinalMinutes AS float) / 60) * @Final_HourlyRate;

								SET @FinalHourMin = CAST((CAST(ISNULL(@FinalHoursToUpdate, 0) AS VARCHAR) + '.' + CAST(ISNULL(@FinalMinutesToUpdate, 0) AS VARCHAR)) AS DECIMAL(18, 2));

								UPDATE [DBO].[WorkOrderLabor] SET [Hours] = @FinalHourMin, [AdjustedHours] = @FinalHourMin, TotalCostPerHour = @Final_HourlyRate, TotalCost = @FinalHourlyAmout
								WHERE WorkOrderLaborId = @Inserted_WorkOrderLaborId;
							END
						END
					END
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
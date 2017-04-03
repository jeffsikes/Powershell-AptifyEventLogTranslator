USE [msdb]
GO

/* You must find and replace the following variables before running this script! */
/* [YOUR DATABASE NAME] - The database where Log_Aptify resides */
/* [Your Login Name] - Your SQL Server User Login */
/* [Your Email Operator] - The SQL Server Email Operator */
/* [Your Email Profile Name] - The SQL Server Email Profile being Utilized */
/* [Your recipient names] - Recipient(s) of the Error Log Email */

/****** Object:  Job [Report - Aptify Hourly Error Log Summary]    Script Date: 4/2/2017 8:09:43 PM ******/
BEGIN TRANSACTION

DECLARE @ReturnCode INT
SELECT @ReturnCode = 0

/****** Object:  JobCategory [[Uncategorized (Local)]]    Script Date: 4/2/2017 8:09:43 PM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'Report - Aptify Hourly Error Log Summary', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'This report summarizes Error Logs collated from various Aptify Servers using a PowerShell Script on each server (running as a Scheduled Task)  The summary is sent just after the top of each hour after the PowerShell script is set to run.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'[Your Login Name]', 
		@notify_email_operator_name=N'[Your Email Operator]', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Create Email]    Script Date: 4/2/2017 8:09:44 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Create Email', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'IF ((SELECT COUNT(1) FROM Log_Aptify WHERE ExceptionTimestamp BETWEEN DATEADD(HOUR, -1, getdate()) AND GETDATE()) > 0)
BEGIN

	DECLARE @tableHtml AS NVARCHAR(MAX)

	SET @tableHTML = 
	N''<style type="text/css">
	#box-table
	{
	font-family: "Lucida Sans Unicode", "Lucida Grande", Sans-Serif;
	font-size: 12px;
	text-align: left;
	border-collapse: collapse;
	border-top: 7px solid #9baff1;
	border-bottom: 7px solid #9baff1;
	}
	#box-table th
	{
	font-size: 12px;
	font-weight: normal;
	background: #b9c9fe;
	border-right: 2px solid #9baff1;
	border-left: 2px solid #9baff1;
	border-bottom: 2px solid #9baff1;
	padding:6px;
	color: #039;
	text-align:left;
	}
	#box-table td
	{
	border-right: 1px solid #aabcfe;
	border-left: 1px solid #aabcfe;
	border-bottom: 1px solid #aabcfe;
	color: #669;
	padding:6px;
	text-align:left;
	}
	tr:nth-child(odd) { background-color:#eee; }
	tr:nth-child(even) { background-color:#fff; } 

	h3 { 
	font-family: "Lucida Sans Unicode", "Lucida Grande", Sans-Serif;
	font-size: 14px;
	font-weight:bold;
	text-align: left;
	}
	pre {  padding:6px; color:#000000; margin-bottom:10px; margin-top:10px; }
	</style>''+ 
	N''<h3>Aptify Errors from '' + CAST(DATEADD(HOUR, -1, getdate()) AS VARCHAR(20)) + '' to '' + CAST(GETDATE() AS VARCHAR(20)) + ''</h3>'' +
	N''<pre>SELECT * FROM Log_Aptify WHERE ExceptionTimestamp BETWEEN '''''' + CAST(DATEADD(HOUR, -1, getdate()) AS VARCHAR(20)) + '''''' AND '''''' + CAST(GETDATE() AS VARCHAR(20)) + ''''''</pre>'' +
	N''<table id="box-table" >'' +
	N''<tr>
	<th>Server</th>
	<th>User</th>
	<th>ExceptionType</th>
	<th>Total Errors</th>
	</tr>'' +
	CAST ( ( 

	SELECT td = ScriptServer,'''',
	td = WindowsIdentity,'''',
	td = ExceptionType,'''',
	td = COUNT(ID),''''
	FROM Log_Aptify 
	WHERE ExceptionTimestamp BETWEEN DATEADD(HOUR, -1, getdate()) AND GETDATE()
	GROUP BY ScriptServer, WindowsIdentity, ExceptionType
	ORDER BY COUNT(ID) DESC
	FOR XML PATH(''tr''), TYPE 
	) AS NVARCHAR(MAX) ) +
	N''</table>'' 

	EXEC msdb.dbo.sp_send_dbmail
	@profile_name=''[Your Email Profile Name]'',
	@recipients = ''[Your recipient names]'',
	@subject=''ERROR: Aptify Web, EBusiness, or Smart Client'',
	@body=@tableHTML,
	@body_format = ''html''

END


', 
		@database_name=N'[YOUR DATABASE NAME]', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Hourly, 5 Minutes Past the Hour', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=8, 
		@freq_subday_interval=1, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20170125, 
		@active_end_date=99991231, 
		@active_start_time=500, 
		@active_end_time=235959, 
		@schedule_uid=N'c60d3039-e89a-4a3f-83db-c0ca4638cd0f'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

GO




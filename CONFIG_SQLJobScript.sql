IF ((SELECT COUNT(1) FROM Log_Aptify WHERE ExceptionTimestamp BETWEEN DATEADD(HOUR, -1, getdate()) AND GETDATE()) > 0)
BEGIN

	DECLARE @tableHtml AS NVARCHAR(MAX)

	SET @tableHTML = 
	N'<style type="text/css">
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
	</style>'+ 
	N'<h3>Aptify Errors from ' + CAST(DATEADD(HOUR, -1, getdate()) AS VARCHAR(20)) + ' to ' + CAST(GETDATE() AS VARCHAR(20)) + '</h3>' +
	N'<pre>SELECT * FROM AANPDB.dbo.Log_Aptify WHERE ExceptionTimestamp BETWEEN ''' + CAST(DATEADD(HOUR, -1, getdate()) AS VARCHAR(20)) + ''' AND ''' + CAST(GETDATE() AS VARCHAR(20)) + '''</pre>' +
	N'<table id="box-table" >' +
	N'<tr>
	<th>Server</th>
	<th>User</th>
	<th>ExceptionType</th>
	<th>Total Errors</th>
	</tr>' +
	CAST ( ( 

	SELECT td = ScriptServer,'',
	td = WindowsIdentity,'',
	td = ExceptionType,'',
	td = COUNT(ID),''
	FROM AANPDB.dbo.Log_Aptify 
	WHERE ExceptionTimestamp BETWEEN DATEADD(HOUR, -1, getdate()) AND GETDATE()
	GROUP BY ScriptServer, WindowsIdentity, ExceptionType
	ORDER BY COUNT(ID) DESC
	FOR XML PATH('tr'), TYPE 
	) AS NVARCHAR(MAX) ) +
	N'</table>' 

	EXEC msdb.dbo.sp_send_dbmail
	@profile_name='[Your SQL Server Mail Profile Name]',
	@recipients = '[Your Recipients]',
	@subject='ERROR: Aptify Web, EBusiness, or Smart Client',
	@body=@tableHTML,
	@body_format = 'html'

END

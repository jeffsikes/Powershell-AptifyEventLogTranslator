$DBServer = "YOUR-SERVER-NAME-HERE"
$DBName = "YOUR-NON-APTIFY-DBNAME-HERE"
$smtpServer = "YOUR-SMTP-SERVER"
$emailSender = "YOUR-EMAIL-SENDER"
$emailRecipient = "YOUR-EMAIL-ERROR-RECIPIENT"

function BuildErrorInfo([string] $errorMessage) {
    
    $machineName = ParseAptifyErrorBlob "MachineName" "ExceptionManager.MachineName: " "ExceptionManager.TimeStamp: "
    $timestamp = ParseAptifyErrorBlob "TimeStamp" $errorMessage "ExceptionManager.TimeStamp: " "ExceptionManager.FullName: "
    $windowsIdentity = ParseAptifyErrorBlob "Windows Identity" $errorMessage "ExceptionManager.WindowsIdentity: " "1) Exception Information"
    $exceptionType = ParseAptifyErrorBlob "Exception Type" $errorMessage "Exception Type: " "ExceptionState: " "Message: "
    $exceptionState = ParseAptifyErrorBlob "Exception State" $errorMessage "ExceptionState: " "Message: "
    $message = ParseAptifyErrorBlob "Message" $errorMessage "Message: " "Data: "
    $dataText = ParseAptifyErrorBlob "Data" $errorMessage "Data: " "TargetSite: "
    $targetSite = ParseAptifyErrorBlob "Target Site" $errorMessage "TargetSite: " "HelpLink: "
    $source = ParseAptifyErrorBlob "Source" $errorMessage "Source: " "HResult: "
    $stackTrace = ParseAptifyErrorBlob "StackTrace" $errorMessage "StackTrace Information" ""
    $stackTrace = $stackTrace.Replace("*********************************************", "")

    $result = 0

    if (!([DateTime]::TryParse($timestamp, [ref]$result))) {
        $timestamp = Get-Date -Year 1920 -Month 1 -Day 1
    }

    $properties = @{
        MachineName = $machineName
        WindowsIdentity = $windowsIdentity
        ExceptionTimeStamp = $timestamp
        ExceptionType = $exceptionType
        ExceptionState = $exceptionState
        ExceptionMessage = $message
        ExceptionData = $dataText
        ExceptionSource = $source
        ExceptionTargetSite = $targetSite
        StackTrace = $stackTrace
    }


    return $properties
}


function ParseAptifyErrorBlob([string] $fieldName, [string] $errorMessage, [string] $startingNode, [string] $endingNode, [string] $alternativeEndingNode ="") 
{


    $returnValue = ""

    Try {

        $start = $errorMessage.IndexOf($startingNode)

        If ($start -ge 0)
        {
            $start = $start + $startingNode.Length

            $end = $errorMessage.Length

            If ($endingNode.Trim() -ne "") {
                $end = $errorMessage.IndexOf($endingNode)
            }

            If ($end -eq -1 -and $alternativeEndingNode -ne "") {
                $end = $errorMessage.IndexOf($alternativeEndingNode)
            }

            If ($start -lt $end -and $end -le $errorMessage.Length) {
                $returnValue = $errorMessage.Substring($start, $end - $start).Trim();
            }

            #Write-Host $fieldName
            ##Write-Host "Start: $start"
            ##Write-Host "End: $end"
            #Write-Host $returnValue
            #Write-Host "----------------------"
        }
    }
    Catch 
    {
        $ErrorMessage = $_.Exception.Message
        $FailedItem = $_.Exception.ItemName
 
        Write-Host $ErrorMessage
        Write-Host $FailedItem

        Write-Host $_.Exception
 
        #Send-MailMessage -From $emailSender -To $emailRecipient -Subject "Major Error" -SmtpServer $smtpServer -Body "We failed to read file $FailedItem. The error message was $ErrorMessage"
        Break
    }

    return $returnValue
    
}

$curentScriptServer = $env:COMPUTERNAME

##Determine last Error Log Run TimeStamp
$sqlConnection = New-Object System.Data.SqlClient.SqlConnection
$sqlConnection.ConnectionString = "Server=$DBServer;Database=$DBName;Integrated Security=True;"
$sqlConnection.Open()

$sqlCommand = New-Object System.Data.SqlClient.SqlCommand
$sqlCommand.Connection = $sqlConnection
$sqlCommand.CommandText = "SET NOCOUNT ON; SELECT MAX(ExceptionTimeStamp) AS ExceptionTimeStamp FROM Log_Aptify WHERE ScriptServer = '$curentScriptServer'"
 
# Quit if the SQL connection didn't open properly.
if ($sqlConnection.State -ne [Data.ConnectionState]::Open) {
    "Connection to DB is not open."
    Exit
}

$startTime = $sqlCommand.ExecuteScalar()

if ($startTime.ToString() -eq [String]::Empty) {
    $startTime = Get-Date -Minute 0 -Second 0
}
else {
    $ts = New-TimeSpan -Seconds 1
    $startTime = $startTime + $ts
}

$ts = New-TimeSpan -Days 0 -Hours 1 -Minutes 0

$endTime = $startTime + $ts

$currentTime = Get-Date

Write-Host "Searching Application Event Log..."
Write-Host "Start DateTime: $startTime"
Write-Host "End DateTime: $endTIme"

$events = Get-WinEvent -FilterHashtable @{LogName="Application"; ProviderName="Aptify*"; StartTime="$startTime"; EndTime="$endTime"}

$eventsCount = if ($events.Count -lt 1) { 0 } else { $events.Count }

## if nothing was found for that timespan, you need to move forward until you find a timespan that does have errors
## While eventsCount == 0 AND startTime <= currentTime
## Additionally, move forward until you reach the current date/time
while (($eventsCount -eq 0 -and $endTime -lt $currentTime) -or ($eventsCount -gt 0 -and $endTime -lt $currentTime)) {
    $startTime = $endTime
    $endTime = $endTime + $ts

    Write-Host "Searching Next Timeframe..."
    Write-Host "Start DateTime: $startTime"
    Write-Host "End DateTime: $endTIme"

    $events = Get-WinEvent -FilterHashtable @{LogName="Application"; ProviderName="Aptify*"; StartTime="$startTime"; EndTime="$endTime"}
    $eventsCount = if ($events.Count -lt 1) { 0 } else { $events.Count }

}

$found = 0;

$errorLogs = @( )
$dataMessage = @{ }

if ($eventsCount -gt 0) {
    foreach ($event in $events) { 
			$exceptionInfo = $($event.Properties[0].Value -replace "`n", "`r`n")

            $dataMessage = BuildErrorInfo $exceptionInfo

            $errorLogs += $dataMessage

            $found++
    }


}


## Add to SQL Database
 
# Quit if the SQL connection didn't open properly.
if ($sqlConnection.State -ne [Data.ConnectionState]::Open) {
    "Connection to DB is not open."
    Exit
}

$sqlCommand = New-Object System.Data.SqlClient.SqlCommand
$sqlCommand.Connection = $sqlConnection
$sqlCommand.CommandText = "SET NOCOUNT ON; " +
        "INSERT INTO Log_Aptify (MachineName, WindowsIdentity, ExceptionTimeStamp, ExceptionType, ExceptionState, ExceptionMessage, ExceptionData, ExceptionSource, ExceptionTargetSite, StackTrace, ScriptServer) " +
        "VALUES (@MachineName, @WindowsIdentity, @ExceptionTimeStamp, @ExceptionType, @ExceptionState, @ExceptionMessage, @ExceptionData, @ExceptionSource, @ExceptionTargetSite, @StackTrace, @ScriptServer); " +
        "SELECT SCOPE_IDENTITY() as [InsertedID]; "

$sqlCommand.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@MachineName",[Data.SQLDBType]::NVarChar, 100))) | Out-Null
$sqlCommand.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@WindowsIdentity",[Data.SQLDBType]::NVARCHAR, 100))) | Out-Null
$sqlCommand.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@ExceptionTimeStamp",[Data.SQLDBType]::DateTime2))) | Out-Null
$sqlCommand.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@ExceptionType",[Data.SQLDBType]::NVarChar, 100))) | Out-Null
$sqlCommand.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@ExceptionState",[Data.SQLDBType]::NVarChar, 255))) | Out-Null
$sqlCommand.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@ExceptionMessage",[Data.SQLDBType]::NVarChar, -1))) | Out-Null
$sqlCommand.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@ExceptionData",[Data.SQLDBType]::NVarChar, -1))) | Out-Null
$sqlCommand.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@ExceptionSource",[Data.SQLDBType]::NVarChar, 255))) | Out-Null
$sqlCommand.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@ExceptionTargetSite",[Data.SQLDBType]::NVarChar, 255))) | Out-Null
$sqlCommand.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@StackTrace",[Data.SQLDBType]::NVarChar, -1))) | Out-Null
$sqlCommand.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@ScriptServer",[Data.SQLDBType]::NVarChar, -1))) | Out-Null

foreach ($errorLog in $errorLogs) {
    # Here we set the values of the pre-existing parameters based on the $file iterator
    $sqlCommand.Parameters[0].Value = $errorLog.MachineName
    $sqlCommand.Parameters[1].Value = $errorLog.WindowsIdentity
    $sqlCommand.Parameters[2].Value = $errorLog.ExceptionTimeStamp
    $sqlCommand.Parameters[3].Value = $errorLog.ExceptionType
    $sqlCommand.Parameters[4].Value = $errorLog.ExceptionState
    $sqlCommand.Parameters[5].Value = $errorLog.ExceptionMessage
    $sqlCommand.Parameters[6].Value = $errorLog.ExceptionData
    $sqlCommand.Parameters[7].Value = $errorLog.ExceptionSource
    $sqlCommand.Parameters[8].Value = $errorLog.ExceptionTargetSite
    $sqlCommand.Parameters[9].Value = $errorLog.StackTrace
    $sqlCommand.Parameters[10].Value = $env:COMPUTERNAME


 
    # Run the query and get the scope ID back into $InsertedID
    $InsertedID = $sqlCommand.ExecuteScalar()

}

$totalCount =  $errorLogs.Count

Write-Host "Submitted $totalCount Errors to the database."

if ($sqlConnection.State -eq [Data.ConnectionState]::Open) {
    $sqlConnection.Close()
}

exit $totalCount

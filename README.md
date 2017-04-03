# Powershell-AptifyEventLogTranslator

## Purpose
The Aptify Smart Client and EBusiness Website, by default, write exceptions to the Application Event Log.  If you are on an Aptify Version less than 5.5.4, there is not currently a way to view these errors without monitoring the Server's Event Log directly.  Aptify 5.5.4 introduced the [Error Log Entity](https://kb.aptify.com/display/PK55/Configuring+the+Exception+Manager), which allows you to push these errors to a database, email address, or both.  If you can upgrade to Aptify 5.5.4, do it!  

One further advantage to the translator is the parsing of each error.  Aptify wraps the exception from the application within an Event Log node, so it can be difficult to report and summarize the types of issues that are occurring on your systems.  In addition, the translator allows you to push all errors from various servers to one centralized location. So you don't have to visit each server your Aptify Components are running on (Aptify Smart Client on an RDP Server, Aptify eBusiness on a separate web server for example)

Right now, the translator is configured to run outside of the Aptify Environment, writing to a table that is in a database separate from Aptify.  You can, however create a virtual entity within Aptify that would allow you to view the data within the log table.

## Error Parsing Overview
All Aptify related errors occurring within the range (an hour) are collected.  For each error, it then parses through the Event Log Entry to extract data in a more uniform matter.  This allows for better summarization and reporting on errors from Aptify.  **The parsing is a neat hack, but just that - a hack**.  It relies on the consistentcy of Aptify's error logging entry to parse through the error using common patterns.  If those patterns change, or perhaps aren't the same from Aptify 5.5.1 to 5.5.3 to 5.5.4, the script could fail to populate any data for the found error.

## Requirements
This script has been tested and utilized on the following environment:
* Aptify 5.5.3 (these scripts were created with Aptify 5.5.3, I can't verify their usability on other versions)
* Windows Server 2012 R2 Standard Edition (and the right to create and execute a Windows Scheduled Task)
* SQL Server 2008 or higher (and the right to create SQL Jobs if you want the hourly email)
* Powershell 4.0 and above (verified not working with Powershell 2.0)
   * [Verify your Powershell Version](http://stackoverflow.com/questions/1825585/determine-installed-powershell-version)
   * [Powershell Basics](https://msdn.microsoft.com/en-us/powershell/scripting/powershell-scripting)
   * [Set your Execution Policy](https://ss64.com/ps/set-executionpolicy.html) (My preference is RemoteSigned, but your needs may vary.)
   
## Setup

### Log Table
First you'll need a table to store the errors.  By default, it will be named Log_Aptify.  You can find the CREATE script in the repository.  Reminder - since this log is not populated via Aptify VB Component calls to an Entity, you will want to ensure that this table exists outside of your Aptify database.  

### Powershell Script
**Configuration changes to the script are required** 

Briefly, the Powershell Script searches the Application Event Log for Aptify related errors.  It then parses each error into more specific fields of information and sends it to the Log_Aptify table.

### Windows Scheduled Task
**Configuration changes to the script are required** 

Create a Windows Scheduled Tasks that runs the script on an hourly basis. I have included a Scheduled Task XML File that you can import. Be sure to update the ```<WorkingDirectory>``` to the location of the PowerShell script prior to the import.  Additionally, you will need to update the username/password that has privliges to run the script after the initial import.

### SQL Job
**Configuration changes to the script are required** 

The SQL Job summarizes the errors collected during a specific hour.  We receive a multitude of errors, so by default I am summarizing by Error Type to reduce the size of the email.  However, you can easily update the script to display every error that comes in if desired.  I recommend making the SQL Job Schedule on the hour, and run the Windows Scheduled Tasks at the :55s.  Example. Windows Scheduled Tasks at the 5:55 PM, SQL Jobs at the 6:00 PM.  The SQL Job script is included in the repository.    


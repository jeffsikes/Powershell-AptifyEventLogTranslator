USE [YOUR_NON_APTIFY_DATABASE_HERE]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[Log_Aptify](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[MachineName] [nvarchar](100) NULL DEFAULT (NULL),
	[WindowsIdentity] [nvarchar](100) NULL DEFAULT (NULL),
	[ExceptionTimestamp] [datetime] NULL DEFAULT (NULL),
	[ExceptionType] [nvarchar](100) NULL DEFAULT (NULL),
	[ExceptionState] [nvarchar](255) NULL DEFAULT (NULL),
	[ExceptionMessage] [nvarchar](max) NULL DEFAULT (NULL),
	[ExceptionData] [nvarchar](max) NULL DEFAULT (NULL),
	[ExceptionSource] [nvarchar](255) NULL DEFAULT (NULL),
	[ExceptionTargetSite] [nvarchar](255) NULL DEFAULT (NULL),
	[StackTrace] [nvarchar](max) NULL DEFAULT (NULL),
	[ScriptServer] [nvarchar](100) NULL DEFAULT (NULL)
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO


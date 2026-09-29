
/*
Execute this script only on below Server and databases
	GSF2_APAC_TEST
	GSF2_AMER_TEST
*/

DECLARE
	 @DatabaseName AS VARCHAR(50)=db_name()
	,@SQL AS NVARCHAR(1000)
	,@SQL2 AS NVARCHAR(1000)
	,@SQL3 AS NVARCHAR(1000)
	,@SQL4 AS NVARCHAR(1000)
	
IF (@DatabaseName LIKE 'GSF2_APAC_TEST' OR @DatabaseName LIKE 'GSF2_AMER_TEST')
	BEGIN

			 SET @SQL3='ALTER DATABASE '+QUOTENAME(@DatabaseName)+' SET NEW_BROKER WITH ROLLBACK IMMEDIATE'	
			 EXEC SP_EXECUTESQL  @SQL3
		  
			SET @SQL4='ALTER AUTHORIZATION ON database::'+QUOTENAME(@DatabaseName)+'  TO SA'
			EXEC SP_EXECUTESQL  @SQL4

			SET @SQL='ALTER DATABASE '+QUOTENAME(@DatabaseName)+' SET DISABLE_BROKER WITH ROLLBACK IMMEDIATE'

			IF EXISTS 
			(
				SELECT 
					1 
				FROM 
				    sys.databases 
				WHERE 
				    name=@DatabaseName 
				    AND Is_Broker_Enabled=1
			)
			BEGIN
				EXEC SP_EXECUTESQL @SQL
				PRINT 'Service Broker is disabled on '+@DatabaseName;
			END
				ELSE
				PRINT 'Service Broker is already disabled in '+@DatabaseName;

			-- STEP 2 : Enable TrustWorthy to ON

			SET @SQL2='ALTER DATABASE '+@DatabaseName+' SET TRUSTWORTHY OFF';
			EXEC SP_EXECUTESQL @SQL2
			PRINT 'TrustWorthy OFF  '+@DatabaseName

			SET @SQL='ALTER DATABASE '+QUOTENAME(@DatabaseName)+' SET ENABLE_BROKER WITH ROLLBACK IMMEDIATE'
			IF EXISTS 
			(
				SELECT 
					1 
				FROM 
				    sys.databases 
				WHERE 
				    name=@DatabaseName 
				    AND Is_Broker_Enabled=0
			)
			BEGIN
				EXEC SP_EXECUTESQL @SQL
				PRINT 'Service Broker is enabled on '+@DatabaseName;
			END
				ELSE
				PRINT 'Service Broker is already enabled on '+@DatabaseName;


			SET @SQL2='ALTER DATABASE '+@DatabaseName+' SET TRUSTWORTHY ON';
			EXEC SP_EXECUTESQL @SQL2
			PRINT 'TrustWorthy ON '+@DatabaseName


	
	PRINT 'DROP Services'
		IF  EXISTS (SELECT * FROM sys.services WHERE name = N'//GSF/DefectFix/ServiceIntiator')
			DROP SERVICE  [//GSF/DefectFix/ServiceIntiator];
		IF  EXISTS (SELECT * FROM sys.services WHERE name = N'//GSF/EventEquipment/ServiceIntiator')
			DROP SERVICE [//GSF/EventEquipment/ServiceIntiator];
		
		
	PRINT 'DROP QUEUES'
		IF  EXISTS (SELECT * FROM sys.service_queues WHERE name = N'DefectFixSourceQueue')
			DROP QUEUE [Test].[DefectFixSourceQueue];
		IF  EXISTS (SELECT * FROM sys.service_queues WHERE name = N'EventEquipmentSourceQueue')
			DROP QUEUE [Test].[EventEquipmentSourceQueue];
		
		
	PRINT 'DROP CONTRACTS'
		IF  EXISTS (SELECT * FROM sys.service_contracts WHERE name = N'//GSF/DefectFix/Contract')
			DROP CONTRACT [//GSF/DefectFix/Contract];
		IF  EXISTS (SELECT * FROM sys.service_contracts WHERE name = N'//GSF/EventEquipment/Contract')
			DROP CONTRACT [//GSF/EventEquipment/Contract]
		
	PRINT 'DROP MESSAGE TYPE'
		IF  EXISTS (SELECT * FROM sys.service_message_types WHERE name = N'//GSF/DefectFix/MessageRequest')
			DROP MESSAGE TYPE [//GSF/DefectFix/MessageRequest];
		IF  EXISTS (SELECT * FROM sys.service_message_types WHERE name = N'//GSF/DefectFix/MessageResponse')
			DROP MESSAGE TYPE [//GSF/DefectFix/MessageResponse];
		IF  EXISTS (SELECT * FROM sys.service_message_types WHERE name = N'//GSF/EventEquipment/MessageRequest')
			DROP MESSAGE TYPE [//GSF/EventEquipment/MessageRequest];
		IF  EXISTS (SELECT * FROM sys.service_message_types WHERE name = N'//GSF/EventEquipment/MessageResponse')
			DROP MESSAGE TYPE [//GSF/EventEquipment/MessageResponse];
		

	PRINT 'CREATE MESSAGE TYPE'
		CREATE MESSAGE TYPE [//GSF/DefectFix/MessageRequest] AUTHORIZATION [dbo] VALIDATION = WELL_FORMED_XML;
		CREATE MESSAGE TYPE [//GSF/DefectFix/MessageResponse] AUTHORIZATION [dbo] VALIDATION = WELL_FORMED_XML;
		CREATE MESSAGE TYPE [//GSF/EventEquipment/MessageRequest] AUTHORIZATION [dbo] VALIDATION = WELL_FORMED_XML;
		CREATE MESSAGE TYPE [//GSF/EventEquipment/MessageResponse] AUTHORIZATION [dbo] VALIDATION = WELL_FORMED_XML;

	PRINT 'CREATE CONTRACTS'
	   CREATE CONTRACT [//GSF/DefectFix/Contract] AUTHORIZATION dbo ([//GSF/DefectFix/MessageRequest] SENT BY INITIATOR,[//GSF/DefectFix/MessageResponse] SENT BY TARGET);
	   CREATE CONTRACT [//GSF/EventEquipment/Contract] AUTHORIZATION dbo ([//GSF/EventEquipment/MessageRequest] SENT BY INITIATOR,
	   [//GSF/EventEquipment/MessageResponse] SENT BY TARGET);

	PRINT 'CREATE QUEUES';
	   CREATE QUEUE [Test].[DefectFixSourceQueue] WITH STATUS = ON , RETENTION = OFF , POISON_MESSAGE_HANDLING (STATUS = ON)  ;
	   CREATE QUEUE [Test].[EventEquipmentSourceQueue] WITH STATUS = ON , RETENTION = OFF , POISON_MESSAGE_HANDLING (STATUS = ON)  ;


	PRINT 'CREATE SERVICES';
	   CREATE SERVICE [//GSF/DefectFix/ServiceIntiator]  AUTHORIZATION [dbo] ON QUEUE [Test].[DefectFixSourceQueue] ;
	   CREATE SERVICE [//GSF/EventEquipment/ServiceIntiator]  AUTHORIZATION [dbo] ON QUEUE [Test].[EventEquipmentSourceQueue] ;


END
GO


PRINT 'CREATE TRIGGER trg_DefectFix';
	IF  EXISTS (SELECT * FROM sys.triggers WHERE name = N'trg_DefectFix')
		DROP TRIGGER [Test].[trg_DefectFix];
				
	GO 			
	
	CREATE TRIGGER [Test].[trg_DefectFix]
	ON  [Test].[DefectFix]
	FOR INSERT, UPDATE  
	AS 
	BEGIN
		SET NOCOUNT ON;
		
		DECLARE 
			 @MessageBody AS XML 
			,@Handle AS UNIQUEIDENTIFIER; 
		
		--get relevant information from inserted/deleted and convert to xml message  
		SET @MessageBody = 
							(
								SELECT
									 EventId
									,DefectFixId
									,FixCodeId
								FROM
									INSERTED
								FOR XML RAW ('INSERTED')						
							)

		If (@MessageBody IS NOT NULL)  
		BEGIN 
			
			BEGIN DIALOG 
			
				CONVERSATION @Handle  
				FROM SERVICE 
					[//GSF/DefectFix/ServiceIntiator]   
				TO SERVICE 
					N'//GSF/DefectFix/TargetService'
				ON CONTRACT 
					[//GSF/DefectFix/Contract] WITH ENCRYPTION = OFF;   
				SEND ON CONVERSATION @Handle   
				MESSAGE TYPE 
					[//GSF/DefectFix/MessageRequest] (@MessageBody);
			
			END CONVERSATION @Handle
		END
	END



	GO

	ALTER TABLE [Test].[DefectFix] ENABLE TRIGGER [trg_DefectFix]
	GO


PRINT 'CREATE TRIGGER trg_EventEquipment';
	IF  EXISTS (SELECT * FROM sys.triggers WHERE name = N'trg_EventEquipment')
		DROP TRIGGER [Test].[trg_EventEquipment];
		
	GO 
	
	CREATE  TRIGGER [Test].[trg_EventEquipment]
	ON [Test].[EventEquipment]
	FOR INSERT  
	AS 
	BEGIN
		SET NOCOUNT ON;
		
		DECLARE 
			 @MessageBody AS XML  
			,@Handle AS UNIQUEIDENTIFIER;

		--get relevant information from inserted/deleted and convert to xml message  
		SET @MessageBody = 
						(
							SELECT 
								 EventId
								,EquipmentIdentification
							FROM 
								INSERTED 
							FOR XML RAW ('INSERTED')
						)               

		IF (@MessageBody IS NOT NULL)  
		BEGIN 
					
			BEGIN DIALOG 
			
				CONVERSATION @Handle   			
				FROM SERVICE 
					[//GSF/EventEquipment/ServiceIntiator]   
				TO SERVICE 
					N'//GSF/EventEquipment/TargetService'
				ON CONTRACT 
					[//GSF/EventEquipment/Contract] WITH ENCRYPTION = OFF;   
				SEND ON CONVERSATION @Handle   
				MESSAGE TYPE 
					[//GSF/EventEquipment/MessageRequest] (@MessageBody);
			
			END CONVERSATION @Handle
		END
	END


	GO

	ALTER TABLE [Test].[EventEquipment] ENABLE TRIGGER [trg_EventEquipment]
	GO


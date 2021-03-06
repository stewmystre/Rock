set nocount on

begin

	DECLARE @TargetGuid uniqueidentifier = NULL;

	----------------------------------------------
	-- README
	-- For single WF migrations, set @TargetGuid to the Guid of choice
	-- Otherwise it will target all WFs not in the #knownGuidsToIgnore
	-- list below.
	----------------------------------------------

	-- Uncomment and set for single WF
	--SET @TargetGuid = '3C569F99-BD0C-450E-AD3F-5F9FB1167B90';

	IF OBJECT_ID('tempdb..#codeTable') IS NOT NULL
		DROP TABLE #codeTable

	IF OBJECT_ID('tempdb..#knownGuidsToIgnore') IS NOT NULL
		DROP TABLE #knownGuidsToIgnore

	create table #knownGuidsToIgnore(
		[Guid] UniqueIdentifier, 
		CONSTRAINT [pk_knownGuidsToIgnore] PRIMARY KEY CLUSTERED  ( [Guid]) 
	);

	-- Categories
	insert into #knownGuidsToIgnore values 
	('8F8B272D-D351-485E-86D6-3EE5B7C84D99')  --Checkin

	-- Workflow Types
	insert into #knownGuidsToIgnore values 
	('036F2F0B-C2DC-49D0-A17B-CCDAC7FC71E2'),  --Photo Request
	('011E9F5A-60D4-4FF5-912A-290881E37EAF'),  --Checkin
	('C93EEC26-4BE3-4EB5-92D4-5C30EEF069D9'),  --Parse Labels
	('221BF486-A82C-40A7-85B7-BB44DA45582F'),  --Person Data Error
	('236AB611-EDE8-42B5-B559-6B6A88ADDDCB'),  --External Inquiry
	('417D8016-92DC-4F25-ACFF-A071B591FA4F'),  --Facilities Request
	('3540E9A7-FE30-43A9-8B0A-A372B63DFC93'),  --Sample workflow
	('51FE9641-FB8F-41BF-B09E-235900C3E53E'),  --IT Support
	('16D12EF7-C546-4039-9036-B73D118EDC90'),  --Background Check
	('885CBA61-44EA-4B4A-B6E1-289041B6A195'),  --DISC Request
	('F5AF8224-44DC-4918-AAB7-C7C9A5A6338D'),  --Profile Change Request
	('A84EA226-1CB2-453B-87B6-81F5360BAD3D'),  --Profile Update
	('2B2567EE-6920-4DC1-B2F4-2DE774AAD5A6'),  --Protection Application
	('655BE2A4-2735-4CF9-AEC8-7EF5BE92724C')   --Position Approval

	create table #codeTable (
    Id int identity(1,1) not null,
    CodeText nvarchar(max),
    CONSTRAINT [pk_codeTable] PRIMARY KEY CLUSTERED  ( [Id]) );

    insert into #codeTable
	values 
		('            #region FieldTypes'),
		('')
    
	-- field Types
	insert into #codeTable
	SELECT
        '            RockMigrationHelper.UpdateFieldType("'+    
        ft.Name+ '","'+ 
        ISNULL(ft.Description,'')+ '","'+ 
        ft.Assembly+ '","'+ 
        ft.Class+ '","'+ 
        CONVERT(nvarchar(50), ft.Guid)+ '");'
    from [FieldType] [ft]
    where (ft.IsSystem = 0)

    insert into #codeTable
	values 
		(''),
		('            #endregion'),
		('')

    insert into #codeTable
	values 
		('            #region EntityTypes'),
		('')

	-- entitiy types
    insert into #codeTable
    values 
		('            RockMigrationHelper.UpdateEntityType("Rock.Model.Workflow", "3540E9A7-FE30-43A9-8B0A-A372B63DFC93", true, true);' ),
		('            RockMigrationHelper.UpdateEntityType("Rock.Model.WorkflowActivity", "2CB52ED0-CB06-4D62-9E2C-73B60AFA4C9F", true, true);' ),
		('            RockMigrationHelper.UpdateEntityType("Rock.Model.WorkflowActionType", "23E3273A-B137-48A3-9AFF-C8DC832DDCA6", true, true);' )
	-- Action entity types
    insert into #codeTable
    SELECT DISTINCT
        '            RockMigrationHelper.UpdateEntityType("'+
		[et].[name]+ '","'+   
        CONVERT(nvarchar(50), [et].[Guid])+ '",'+     
		(CASE [et].[IsEntity] WHEN 1 THEN 'true' ELSE 'false' END) + ','+
		(CASE [et].[IsSecured] WHEN 1 THEN 'true' ELSE 'false' END) + ');'
    from [WorkflowActionType] [a]
	inner join [WorkflowActivityType] [at] on [a].[ActivityTypeId] = [at].[id]
	inner join [WorkflowType] [wt] on [at].[WorkflowTypeId] = [wt].[id]
	inner join [EntityType] [et] on [et].[Id] = [a].[EntityTypeId]
    where ( @TargetGuid IS NULL AND [wt].[Guid] not in (select [Guid] from #knownGuidsToIgnore) )
		OR
		  ( [wt].[Guid] = @TargetGuid )

	-- Action entity type attributes
    insert into #codeTable
    SELECT DISTINCT
        '            RockMigrationHelper.UpdateWorkflowActionEntityAttribute("'+ 
        CONVERT(nvarchar(50), [aet].[Guid])+ '","'+   
        CONVERT(nvarchar(50), [ft].[Guid])+ '","'+     
        [a].[Name]+ '","'+  
        [a].[Key]+ '","'+ 
        ISNULL(REPLACE([a].[Description],'"','\"'),'')+ '",'+ 
        CONVERT(varchar, [a].[Order])+ ',@"'+ 
        ISNULL([a].[DefaultValue],'')+ '","'+
        CONVERT(nvarchar(50), [a].[Guid])+ '");' +
        ' // ' + aet.Name + ':'+ a.Name
	from [Attribute] [a] 
	inner join [EntityType] [et] on [et].[Id] = [a].[EntityTypeId] and [et].Name = 'Rock.Model.WorkflowActionType'
    inner join [FieldType] [ft] on [ft].[Id] = [a].[FieldTypeId]
	inner join [EntityType] [aet] on CONVERT(varchar, [aet].[id]) = [a].[EntityTypeQualifierValue]
    where [a].[EntityTypeQualifierColumn] = 'EntityTypeId'
	and [aet].[id] in (
		select distinct [at].[EntityTypeId]
		from [WorkflowType] [wt]
		inner join [WorkflowActivityType] [act] on [act].[WorkflowTypeId] = [wt].[id]
		inner join [WorkflowActionType] [at] on [at].[ActivityTypeId] = [act].[id]
		and (
				( @TargetGuid IS NULL and [wt].[Guid] not in (select [Guid] from #knownGuidsToIgnore) )
			OR
				( [wt].[Guid] = @TargetGuid )
			)
	)

    insert into #codeTable
	values 
		(''),
		('            #endregion'),
		(''),
		('            #region Categories'),
		('')

	-- categories
    insert into #codeTable
    SELECT 
		'            RockMigrationHelper.UpdateCategory("' +
        CONVERT( nvarchar(50), [e].[Guid]) + '","'+ 
        [c].[Name] +  '","'+
        [c].[IconCssClass] +  '","'+
        ISNULL(REPLACE([c].[Description],'"','\"'),'')+ '","'+ 
        CONVERT( nvarchar(50), [c].[Guid])+ '",'+
		CONVERT( nvarchar, [c].[Order] )+ ');' +
		' // ' + c.Name 
    FROM [Category] [c] 
    inner join [EntityType] [e] on [e].[Id] = [c].[EntityTypeId]
    where [c].[Id] in (
		select [CategoryId] 
		from [WorkflowType]
		where (
				( @TargetGuid IS NULL and [Guid] not in (select [Guid] from #knownGuidsToIgnore) )
			OR
				( [Guid] = @TargetGuid )
			)
		)
    order by [c].[Order]

    insert into #codeTable
	values 
		(''),
		('            #endregion'),
		('')

	DECLARE @WorkflowTypeName varchar(100)
	DECLARE @WorkflowTypeId int

	DECLARE wfCursor INSENSITIVE CURSOR FOR
	SELECT [Id], [Name]
	FROM [WorkflowType]
	WHERE ( @TargetGuid IS NULL AND [Guid] not in (select [Guid] from #knownGuidsToIgnore ) )
	OR [Guid] = @TargetGuid 
	ORDER BY [Order]

	OPEN wfCursor
	FETCH NEXT FROM wfCursor
	INTO @WorkflowTypeId, @WorkflowTypeName

	WHILE (@@FETCH_STATUS <> -1)
	BEGIN

		IF (@@FETCH_STATUS = 0)
		BEGIN

			insert into #codeTable
			values 
				('            #region ' + @WorkflowTypeName),
				('')

			-- Workflow Type
			insert into #codeTable
			SELECT 
				'            RockMigrationHelper.UpdateWorkflowType('+ 
				(CASE [wt].[IsSystem] WHEN 1 THEN 'true' ELSE 'false' END) + ','+
				(CASE [wt].[IsActive] WHEN 1 THEN 'true' ELSE 'false' END) + ',"'+
				[wt].[Name]+ '","'+  
				ISNULL(REPLACE([wt].[Description],'"','\"'),'')+ '","'+ 
				CONVERT(nvarchar(50), [c].[Guid])+ '","'+     
				[wt].[WorkTerm]+ '","'+
				ISNULL([wt].[IconCssClass],'')+ '",'+ 
				CONVERT(varchar, ISNULL([wt].[ProcessingIntervalSeconds],0))+ ','+
				(CASE [wt].[IsPersisted] WHEN 1 THEN 'true' ELSE 'false' END) + ','+
				CONVERT(varchar, [wt].[LoggingLevel])+ ',"'+
				CONVERT(nvarchar(50), [wt].[Guid])+ '",'+
				CONVERT(varchar, ISNULL([wt].[Order],0))+ ');'+
				' // ' + wt.Name
			from [WorkflowType] [wt]
			inner join [Category] [c] on [c].[Id] = [wt].[CategoryId] 
			where [wt].[id] = @WorkflowTypeId 


			-- Workflow Type Attributes
			insert into #codeTable
			SELECT 
				'            RockMigrationHelper.UpdateWorkflowTypeAttribute("'+ 
				CONVERT(nvarchar(50), wt.Guid)+ '","'+   
				CONVERT(nvarchar(50), ft.Guid)+ '","'+     
				a.Name+ '","'+  
				a.[Key]+ '","'+ 
				ISNULL(a.Description,'')+ '",'+ 
				CONVERT(varchar, a.[Order])+ ',@"'+ 
				ISNULL(a.DefaultValue,'')+ '","'+
				CONVERT(nvarchar(50), a.Guid)+ '", '+
				(CASE a.IsGridColumn WHEN 1 THEN 'true' ELSE 'false' END) + ');' +
				' // ' + wt.Name + ':'+ a.Name
			from [WorkflowType] [wt]
			inner join [Attribute] [a] on cast([a].[EntityTypeQualifierValue] as int) = [wt].[Id] 
			inner join [EntityType] [et] on [et].[Id] = [a].[EntityTypeId] and [et].Name = 'Rock.Model.Workflow'
			inner join [FieldType] [ft] on [ft].[Id] = [a].[FieldTypeId]
			where EntityTypeQualifierColumn = 'WorkflowTypeId'
			and [wt].[id] = @WorkflowTypeId 
			order by [a].[Order]

			-- Workflow Type Attribute Qualifiers
			insert into #codeTable
			SELECT 
				'            RockMigrationHelper.AddAttributeQualifier("'+ 
				CONVERT(nvarchar(50), a.Guid)+ '","'+   
				CASE WHEN [dt].[guid] IS NOT NULL THEN 'definedtypeguid' ELSE [aq].[Key] END + '",@"'+ 
				CASE WHEN [dt].[guid] IS NOT NULL THEN CAST([dt].[guid] AS varchar(50) ) ELSE ISNULL([aq].[Value],'') END + '","'+
				CONVERT(nvarchar(50), [aq].[Guid])+ '");' +
				' // ' + [wt].[Name] + ':'+ [a].[Name]+ ':'+ [aq].[Key]
			from [WorkflowType] [wt]
			inner join [Attribute] [a] on cast([a].[EntityTypeQualifierValue] as int) = [wt].[Id] 
			inner join [FieldType] [ft] on [ft].[id] = [a].[FieldTypeId]
			inner join [AttributeQualifier] [aq] on [aq].[AttributeId] = [a].[Id]
			inner join [EntityType] [et] on [et].[Id] = [a].[EntityTypeId] and [et].Name = 'Rock.Model.Workflow'
			left outer join [DefinedType] [dt] 
				on [ft].[class] = 'Rock.Field.Types.DefinedValueFieldType'
				and [aq].[key] = 'definedtype' 
				and cast([dt].[id] as varchar(5) ) = [aq].[Value]
			where [a].[EntityTypeQualifierColumn] = 'WorkflowTypeId'
			and [wt].[id] = @WorkflowTypeId 
			order by [a].[Order], [aq].[Key]

			-- Workflow Activity Type
			insert into #codeTable
			SELECT 
				'            RockMigrationHelper.UpdateWorkflowActivityType("'+ 
				CONVERT(nvarchar(50), [wt].[Guid])+ '",'+     
				(CASE [at].[IsActive] WHEN 1 THEN 'true' ELSE 'false' END) + ',"'+
				[at].[Name]+ '","'+  
				ISNULL(REPLACE([at].[Description],'"','\"'),'')+ '",'+ 
				(CASE [at].IsActivatedWithWorkflow WHEN 1 THEN 'true' ELSE 'false' END) + ','+
				CONVERT(varchar, [at].[Order])+ ',"'+
				CONVERT(nvarchar(50), [at].[Guid])+ '");' +
				' // ' + wt.Name + ':'+ at.Name
			from [WorkflowActivityType] [at]
			inner join [WorkflowType] [wt] on [wt].[id] = [at].[WorkflowTypeId]
			where [wt].[id] = @WorkflowTypeId 
			order by [at].[order]

			-- Workflow Activity Type Attributes
			insert into #codeTable
			SELECT 
				'            RockMigrationHelper.UpdateWorkflowActivityTypeAttribute("'+ 
				CONVERT(nvarchar(50), at.Guid)+ '","'+   
				CONVERT(nvarchar(50), ft.Guid)+ '","'+     
				a.Name+ '","'+  
				a.[Key]+ '","'+ 
				ISNULL(a.Description,'')+ '",'+ 
				CONVERT(varchar, a.[Order])+ ',@"'+ 
				ISNULL(a.DefaultValue,'')+ '","'+
				CONVERT(nvarchar(50), a.Guid)+ '");' +
				' // ' + wt.Name + ':'+ at.Name + ':'+ a.Name
			from [WorkflowType] [wt]
			inner join [WorkflowActivityType] [at] on [at].[WorkflowTypeId] = [wt].[id]
			inner join [Attribute] [a] on cast([a].[EntityTypeQualifierValue] as int) = [at].[Id] 
			inner join [EntityType] [et] on [et].[Id] = [a].[EntityTypeId] and [et].Name = 'Rock.Model.WorkflowActivity'
			inner join [FieldType] [ft] on [ft].[Id] = [a].[FieldTypeId]
			where [a].[EntityTypeQualifierColumn] = 'ActivityTypeId'
			and [wt].[id] = @WorkflowTypeId 
			order by [at].[order], [a].[order]

			-- Workflow Activity Type Attribute Qualifiers
			insert into #codeTable
			SELECT 
				'            RockMigrationHelper.AddAttributeQualifier("'+ 
				CONVERT(nvarchar(50), a.Guid)+ '","'+   
				[aq].[Key]+ '",@"'+ 
				ISNULL([aq].[Value],'')+ '","'+
				CONVERT(nvarchar(50), [aq].[Guid])+ '");' +
				' // ' + [wt].[Name] + ':'+ [a].[Name]+ ':'+ [aq].[Key]
			from [WorkflowType] [wt]
			inner join [WorkflowActivityType] [at] on [at].[WorkflowTypeId] = [wt].[id]
			inner join [Attribute] [a] on cast([a].[EntityTypeQualifierValue] as int) = [at].[Id] 
			inner join [AttributeQualifier] [aq] on [aq].[AttributeId] = [a].[Id]
			inner join [EntityType] [et] on [et].[Id] = [a].[EntityTypeId] and [et].Name = 'Rock.Model.WorkflowActivity'
			where [a].[EntityTypeQualifierColumn] = 'ActivityTypeId'
			and [wt].[id] = @WorkflowTypeId 
			order by [at].[order], [a].[order], [aq].[key]

			-- Action Forms
			insert into #codeTable
			SELECT 
				'            RockMigrationHelper.UpdateWorkflowActionForm(@"'+ 
				REPLACE(ISNULL([f].[Header],''), '"', '""')+ '",@"'+ 
				REPLACE(ISNULL([f].[Footer],''), '"', '""')+ '","'+ 
				ISNULL([f].[Actions],'')+ '","'+ 
				(CASE WHEN [se].[Guid] IS NULL THEN '' ELSE CONVERT(nvarchar(50), [se].[Guid]) END) + '",'+
				(CASE [f].[IncludeActionsInNotification] WHEN 1 THEN 'true' ELSE 'false' END) + ',"'+
				ISNULL(CONVERT(nvarchar(50), [f].[ActionAttributeGuid]),'')+ '","'+ 
				CONVERT(nvarchar(50), [f].[Guid])+ '");' +
				' // ' + wt.Name + ':'+ at.Name + ':'+ a.Name
			from [WorkflowActionForm] [f]
			inner join [WorkflowActionType] [a] on [a].[WorkflowFormId] = [f].[id]
			inner join [WorkflowActivityType] [at] on [at].[id] = [a].[ActivityTypeId]
			inner join [WorkflowType] [wt] on [wt].[id] = [at].[WorkflowTypeId]
			left outer join [SystemEmail] [se] on [se].[id] = [f].[NotificationSystemEmailId]
			where [wt].[id] = @WorkflowTypeId 
			order by [at].[Order], [a].[Order]

			-- Action Form Attributes
			insert into #codeTable
			SELECT 
				'            RockMigrationHelper.UpdateWorkflowActionFormAttribute("'+ 
				CONVERT(nvarchar(50), [f].[Guid])+ '","' +
				CONVERT(nvarchar(50), [a].[Guid])+ '",' +
				CONVERT(varchar, [fa].[Order])+ ',' +
				(CASE [fa].[IsVisible] WHEN 1 THEN 'true' ELSE 'false' END) + ','+
				(CASE [fa].[IsReadOnly] WHEN 1 THEN 'true' ELSE 'false' END) + ','+
				(CASE [fa].[IsRequired] WHEN 1 THEN 'true' ELSE 'false' END) + ','+
				(CASE [fa].[HideLabel] WHEN 1 THEN 'true' ELSE 'false' END) + ',@"'+
				REPLACE(ISNULL([fa].[PreHtml],''), '"', '""') + '",@"'+
				REPLACE(ISNULL([fa].[PostHtml],''), '"', '""') +'","'+
				CONVERT(nvarchar(50), [fa].[Guid])+ '");' +
				' // '+ wt.Name+ ':'+ act.Name+ ':'+ at.Name+ ':'+ a.Name
			from [WorkflowActionFormAttribute] [fa]
			inner join [WorkflowActionForm] [f] on [f].[id] = [fa].[WorkflowActionFormId]
			inner join [Attribute] [a] on [a].[id] = [fa].[AttributeId]
			inner join [WorkflowActionType] [at] on [at].[WorkflowFormId] = [f].[id]
			inner join [WorkflowActivityType] [act] on [act].[id] = [at].[ActivityTypeId]
			inner join [WorkflowType] [wt] on [wt].[id] = [act].[WorkflowTypeId]
			where [wt].[id] = @WorkflowTypeId 
			order by [act].[Order], [at].[Order],[a].[Order]

			-- Workflow Action Type
			insert into #codeTable
			SELECT 
				'            RockMigrationHelper.UpdateWorkflowActionType("'+ 
				CONVERT(nvarchar(50), [at].[Guid])+ '","'+     
				[a].[Name]+ '",'+  
				CONVERT(varchar, [a].[Order])+ ',"'+
				CONVERT(nvarchar(50), [et].[Guid])+ '",'+     
				(CASE [a].[IsActionCompletedOnSuccess] WHEN 1 THEN 'true' ELSE 'false' END) + ','+
				(CASE [a].[IsActivityCompletedOnSuccess] WHEN 1 THEN 'true' ELSE 'false' END) + ',"'+
				(CASE WHEN [f].[Guid] IS NULL THEN '' ELSE CONVERT(nvarchar(50), [f].[Guid]) END) + '","'+
				ISNULL(CONVERT(nvarchar(50), [a].[CriteriaAttributeGuid]),'')+ '",'+ 
				CONVERT(varchar, [a].[CriteriaComparisonType])+ ',"'+ 
				ISNULL([a].[CriteriaValue],'')+ '","'+ 
				CONVERT(nvarchar(50), [a].[Guid])+ '");' +
				' // '+ wt.Name+ ':'+ at.Name+ ':'+ a.Name
			from [WorkflowActionType] [a]
			inner join [WorkflowActivityType] [at] on [at].[id] = [a].[ActivityTypeId]
			inner join [WorkflowType] [wt] on [wt].[id] = [at].[WorkflowTypeId]
			inner join [EntityType] [et] on [et].[id] = [a].[EntityTypeId]
			left outer join [WorkflowActionForm] [f] on [f].[id] = [a].[WorkflowFormId]
			where [wt].[id] = @WorkflowTypeId 
			order by [at].[Order], [a].[order]

			-- Workflow Action Type attributes values 
			insert into #codeTable
			SELECT 
				CASE WHEN [FT].[Guid] = 'E4EAB7B2-0B76-429B-AFE4-AD86D7428C70' THEN
				'            RockMigrationHelper.AddActionTypePersonAttributeValue("' ELSE
				'            RockMigrationHelper.AddActionTypeAttributeValue("' END+
				CONVERT(nvarchar(50), at.Guid)+ '","'+ 
				CONVERT(nvarchar(50), a.Guid)+ '",@"'+ 
				REPLACE(ISNULL(av.Value,''), '"', '""') + '");'+
				' // '+ wt.Name+ ':'+ act.Name+ ':'+ at.Name+ ':'+ a.Name
			from [AttributeValue] [av]
			inner join [WorkflowActionType] [at] on [at].[Id] = [av].[EntityId]
			inner join [Attribute] [a] on [a].[id] = [av].[AttributeId] AND [a].EntityTypeQualifierValue = CONVERT(nvarchar, [at].EntityTypeId)
			inner join [FieldType] [ft] on [ft].[id] = [a].[FieldTypeId] 
			inner join [EntityType] [et] on [et].[id] = [a].[EntityTypeId] and [et].[Name] = 'Rock.Model.WorkflowActionType'
			inner join [WorkflowActivityType] [act] on [act].[Id] = [at].[ActivityTypeId]
			inner join [WorkflowType] [wt] on [wt].[Id] = [act].[WorkflowTypeId] and [wt].[id] = @WorkflowTypeId 
			order by [act].[Order], [at].[Order], [a].[Order]

			insert into #codeTable
			values 
				(''),
				('            #endregion'),
				('')

			FETCH NEXT FROM wfCursor
			INTO @WorkflowTypeId, @WorkflowTypeName

		END

	END
	
	CLOSE wfCursor
	DEALLOCATE wfCursor

	insert into #codeTable
	values
		('            #region DefinedValue AttributeType qualifier helper'),
		(''),
		('            Sql( @"
			UPDATE [aq] SET [key] = ''definedtype'', [Value] = CAST( [dt].[Id] as varchar(5) )
			FROM [AttributeQualifier] [aq]
			INNER JOIN [Attribute] [a] ON [a].[Id] = [aq].[AttributeId]
			INNER JOIN [FieldType] [ft] ON [ft].[Id] = [a].[FieldTypeId]
			INNER JOIN [DefinedType] [dt] ON CAST([dt].[guid] AS varchar(50) ) = [aq].[value]
			WHERE [ft].[class] = ''Rock.Field.Types.DefinedValueFieldType''
			AND [aq].[key] = ''definedtypeguid''
		" );'),
		(''),
		('            #endregion')

    select CodeText [MigrationUp] from #codeTable
    order by Id

	IF OBJECT_ID('tempdb..#codeTable') IS NOT NULL
		DROP TABLE #codeTable

	IF OBJECT_ID('tempdb..#knownGuidsToIgnore') IS NOT NULL
		DROP TABLE #knownGuidsToIgnore

end
CREATE PROCEDURE [dbo].[sp_searchtext]
	@Search_String nvarchar(4000),
	@Xtypes nvarchar(100) = null,
	@Case_Sensitive bit = 0,
	@Name nvarchar(4000) = null,
	@Schema nvarchar(4000) = null,
	@Refine_Search_String nvarchar(4000) = null,
	@Exclude_Name nvarchar(4000) = null,
	@Exclude_Schema nvarchar(4000) = null,
	@Exclude_Search_String nvarchar(4000) = null
AS 
BEGIN
	SET NOCOUNT ON;
	
	-- reserved chars
	if @Search_String is not null
		set @Search_String = replace(replace(replace(@Search_String, '[', '[[]'), '%', '[%]'), '_', '[_]')
	
	if @Name is not null
		set @Name = replace(replace(replace(@Name, '[', '[[]'), '%', '[%]'), '_', '[_]')

	if @Schema is not null
		set @Schema = replace(replace(replace(@Schema, '[', '[[]'), '%', '[%]'), '_', '[_]')

	if @Refine_Search_String is not null
		set @Refine_Search_String = replace(replace(replace(@Refine_Search_String, '[', '[[]'), '%', '[%]'), '_', '[_]')
	
	if @Exclude_Name is not null
		set @Exclude_Name = replace(replace(replace(@Exclude_Name, '[', '[[]'), '%', '[%]'), '_', '[_]')
	
	if @Exclude_Schema is not null
		set @Exclude_Schema = replace(replace(replace(@Exclude_Schema, '[', '[[]'), '%', '[%]'), '_', '[_]')
	
	if @Exclude_Search_String is not null
		set @Exclude_Search_String = replace(replace(replace(@Exclude_Search_String, '[', '[[]'), '%', '[%]'), '_', '[_]')
	

	-- xtypes
	declare @Include_Types table (xtype char(2))
	declare @Exclude_Types table (xtype char(2))

	if @Xtypes is not null and @Xtypes <> ''
	begin
		declare @xtype nvarchar(10)
		declare @From_Index int = 1
		declare @To_Index int = charindex(',', @Xtypes)
		if @To_Index <> 0
		begin
			while @To_Index <> 0
			begin
				set @xtype = ltrim(rtrim(substring(@Xtypes, @From_Index, @To_Index - @From_Index)))
				if left(@xtype,1) = '-' and len(@xtype) between 2 and 3
					insert into @Exclude_Types values(upper(right(@xtype,len(@xtype)-1)))
				else if len(@xtype) between 1 and 2
					insert into @Include_Types values(upper(@xtype))

				set @From_Index = @To_Index + 1
				set @To_Index = charindex(',', @Xtypes, @From_Index)
				
				if @To_Index = 0
				begin
					set @xtype = ltrim(rtrim(substring(@Xtypes, @From_Index, len(@Xtypes))))
					if left(@xtype,1) = '-' and len(@xtype) between 2 and 3
						insert into @Exclude_Types values(upper(right(@xtype,len(@xtype)-1)))
					else if len(@xtype) between 1 and 2
						insert into @Include_Types values(upper(@xtype))
				end
			end
		end
		else
		begin
			set @xtype = ltrim(rtrim(@Xtypes))
			if left(@xtype,1) = '-' and len(@xtype) between 2 and 3
				insert into @Exclude_Types values(upper(right(@xtype,len(@xtype)-1)))
			else if len(@xtype) between 1 and 2
				insert into @Include_Types values(upper(@xtype))
		end
	end
	
	declare @IsIncludeTypes	int = (case when exists(select top 1 xtype from @Include_Types) then 1 else 0 end)
	declare @IsExcludeTypes	int = (case when exists(select top 1 xtype from @Exclude_Types) then 1 else 0 end)


	-- objects
	declare @objects table (
		id int, 
		xtype char(2),
		name sysname,
		[schema] sysname
	)
	
	if @Case_Sensitive is null or @Case_Sensitive = 0
	begin

		-- sysobjects
		insert into @objects
		select so.id, so.xtype, so.name, ss.name
		from sys.sysobjects so with (nolock)
		inner join sys.schemas ss with (nolock) on so.[uid] = ss.[schema_id]
		left outer join sys.syscomments sc with (nolock) on so.id = sc.id
		where (so.xtype <> 'TT')
		and (so.name like '%' + @Search_String + '%' or sc.[text] like '%' + @Search_String + '%')
		and (@IsIncludeTypes = 0 or so.xtype in (select xtype from @Include_Types))
		and (@IsExcludeTypes = 0 or so.xtype not in (select xtype from @Exclude_Types))
		and (@Name is null or @Name = '' or so.name like '%' + @Name + '%')
		and (@Exclude_Name is null or @Exclude_Name = '' or so.name not like '%' + @Exclude_Name + '%')
		and (@Schema is null or @Schema = '' or ss.name like '%' + @Schema + '%')
		and (@Exclude_Schema is null or @Exclude_Schema = '' or ss.name not like '%' + @Exclude_Schema + '%')
		and (@Refine_Search_String is null or @Refine_Search_String = '' or (so.name like '%' + @Refine_Search_String + '%' or sc.[text] like '%' + @Refine_Search_String + '%'))

		-- sysobjects Table type
		insert into @objects
		select so.id, so.xtype, stt.name, ss.name
		from sys.sysobjects so with (nolock)
		inner join sys.table_types stt with (nolock) on so.id = stt.type_table_object_id
		inner join sys.schemas ss with (nolock) on stt.[schema_id] = ss.[schema_id]
		left outer join sys.syscomments sc with (nolock) on so.id = sc.id
		where (so.xtype = 'TT')
		and (stt.name like '%' + @Search_String + '%' or sc.[text] like '%' + @Search_String + '%')
		and (@IsIncludeTypes = 0 or so.xtype in (select xtype from @Include_Types))
		and (@IsExcludeTypes = 0 or so.xtype not in (select xtype from @Exclude_Types))
		and (@Name is null or @Name = '' or stt.name like '%' + @Name + '%')
		and (@Exclude_Name is null or @Exclude_Name = '' or stt.name not like '%' + @Exclude_Name + '%')
		and (@Schema is null or @Schema = '' or ss.name like '%' + @Schema + '%')
		and (@Exclude_Schema is null or @Exclude_Schema = '' or ss.name not like '%' + @Exclude_Schema + '%')
		and (@Refine_Search_String is null or @Refine_Search_String = '' or (stt.name like '%' + @Refine_Search_String + '%' or sc.[text] like '%' + @Refine_Search_String + '%'))

		if @Exclude_Search_String is not null and @Exclude_Search_String <> '' 
		begin
			delete from @objects
			where id in (
				select objs.id
				from @objects objs
				inner join sys.sysobjects so with (nolock) on objs.id = so.id
				left outer join sys.syscomments sc with (nolock) on so.id = sc.id
				where (so.xtype <> 'TT')
				and (so.name like '%' + @Exclude_Search_String + '%' or sc.[text] like '%' + @Exclude_Search_String + '%')
			
				union all

				select objs.id
				from @objects objs
				inner join sys.sysobjects so with (nolock) on objs.id = so.id
				inner join sys.table_types stt with (nolock) on so.id = stt.type_table_object_id
				left outer join sys.syscomments sc with (nolock) on so.id = sc.id
				where (so.xtype = 'TT')
				and (stt.name like '%' + @Exclude_Search_String + '%' or sc.[text] like '%' + @Exclude_Search_String + '%')
			)
		end

		-- column objects
		insert into @objects
		select so.id, so.xtype, so.name, ss.name
		from sys.columns c with (nolock)
		inner join sys.sysobjects so with (nolock) on c.[object_id] = so.id
		inner join sys.schemas ss with (nolock) on so.[uid] = ss.[schema_id]
		where (so.xtype <> 'TT')
		and (c.name like '%' + @Search_String + '%')
		and (@IsIncludeTypes = 0 or so.xtype in (select xtype from @Include_Types))
		and (@IsExcludeTypes = 0 or so.xtype not in (select xtype from @Exclude_Types))
		and (@Name is null or @Name = '' or so.name like '%' + @Name + '%')
		and (@Exclude_Name is null or @Exclude_Name = '' or so.name not like '%' + @Exclude_Name + '%')
		and (@Schema is null or @Schema = '' or ss.name like '%' + @Schema + '%')
		and (@Exclude_Schema is null or @Exclude_Schema = '' or ss.name not like '%' + @Exclude_Schema + '%')
		and (@Refine_Search_String is null or @Refine_Search_String = '' or c.name like '%' + @Refine_Search_String + '%')
		and (@Exclude_Search_String is null or @Exclude_Search_String = '' or c.name not like '%' + @Exclude_Search_String + '%')
		
		-- column objects Table type
		insert into @objects
		select so.id, so.xtype, stt.name, ss.name
		from sys.sysobjects so with (nolock)
		inner join sys.table_types stt with (nolock) on so.id = stt.type_table_object_id
		inner join sys.schemas ss with (nolock) on stt.[schema_id] = ss.[schema_id]
		inner join sys.columns c with (nolock) on c.[object_id] = stt.type_table_object_id
		where (so.xtype = 'TT')
		and (c.name like '%' + @Search_String + '%')
		and (@IsIncludeTypes = 0 or so.xtype in (select xtype from @Include_Types))
		and (@IsExcludeTypes = 0 or so.xtype not in (select xtype from @Exclude_Types))
		and (@Name is null or @Name = '' or stt.name like '%' + @Name + '%')
		and (@Exclude_Name is null or @Exclude_Name = '' or stt.name not like '%' + @Exclude_Name + '%')
		and (@Schema is null or @Schema = '' or ss.name like '%' + @Schema + '%')
		and (@Exclude_Schema is null or @Exclude_Schema = '' or ss.name not like '%' + @Exclude_Schema + '%')
		and (@Refine_Search_String is null or @Refine_Search_String = '' or c.name like '%' + @Refine_Search_String + '%')
		and (@Exclude_Search_String is null or @Exclude_Search_String = '' or c.name not like '%' + @Exclude_Search_String + '%')

	end
	else if @Case_Sensitive = 1
	begin

		-- sysobjects
		insert into @objects
		select so.id, so.xtype, so.name, ss.name
		from sys.sysobjects so with (nolock)
		inner join sys.schemas ss with (nolock) on so.[uid] = ss.[schema_id]
		left outer join sys.syscomments sc with (nolock) on so.id = sc.id
		where (so.xtype <> 'TT')
		and (so.name collate Latin1_General_BIN like '%' + @Search_String + '%' collate Latin1_General_BIN or sc.[text] collate Latin1_General_BIN like '%' + @Search_String + '%' collate Latin1_General_BIN)
		and (@IsIncludeTypes = 0 or so.xtype in (select xtype from @Include_Types))
		and (@IsExcludeTypes = 0 or so.xtype not in (select xtype from @Exclude_Types))
		and (@Name is null or @Name = '' or so.name collate Latin1_General_BIN like '%' + @Name + '%' collate Latin1_General_BIN)
		and (@Exclude_Name is null or @Exclude_Name = '' or so.name collate Latin1_General_BIN not like '%' + @Exclude_Name + '%' collate Latin1_General_BIN)
		and (@Schema is null or @Schema = '' or ss.name collate Latin1_General_BIN like '%' + @Schema + '%' collate Latin1_General_BIN)
		and (@Exclude_Schema is null or @Exclude_Schema = '' or ss.name collate Latin1_General_BIN not like '%' + @Exclude_Schema + '%' collate Latin1_General_BIN)
		and (@Refine_Search_String is null or @Refine_Search_String = '' or (so.name collate Latin1_General_BIN like '%' + @Refine_Search_String + '%' collate Latin1_General_BIN or sc.[text] collate Latin1_General_BIN like '%' + @Refine_Search_String + '%' collate Latin1_General_BIN))

		-- sysobjects Table type
		insert into @objects
		select so.id, so.xtype, stt.name, ss.name
		from sys.sysobjects so with (nolock)
		inner join sys.table_types stt with (nolock) on so.id = stt.type_table_object_id
		inner join sys.schemas ss with (nolock) on stt.[schema_id] = ss.[schema_id]
		left outer join sys.syscomments sc with (nolock) on so.id = sc.id
		where (so.xtype = 'TT')
		and (stt.name collate Latin1_General_BIN like '%' + @Search_String + '%' collate Latin1_General_BIN or sc.[text] collate Latin1_General_BIN like '%' + @Search_String + '%' collate Latin1_General_BIN)
		and (@IsIncludeTypes = 0 or so.xtype in (select xtype from @Include_Types))
		and (@IsExcludeTypes = 0 or so.xtype not in (select xtype from @Exclude_Types))
		and (@Name is null or @Name = '' or stt.name collate Latin1_General_BIN like '%' + @Name + '%' collate Latin1_General_BIN)
		and (@Exclude_Name is null or @Exclude_Name = '' or stt.name collate Latin1_General_BIN not like '%' + @Exclude_Name + '%' collate Latin1_General_BIN)
		and (@Schema is null or @Schema = '' or ss.name collate Latin1_General_BIN like '%' + @Schema + '%' collate Latin1_General_BIN)
		and (@Exclude_Schema is null or @Exclude_Schema = '' or ss.name collate Latin1_General_BIN not like '%' + @Exclude_Schema + '%' collate Latin1_General_BIN)
		and (@Refine_Search_String is null or @Refine_Search_String = '' or (stt.name collate Latin1_General_BIN like '%' + @Refine_Search_String + '%' collate Latin1_General_BIN or sc.[text] collate Latin1_General_BIN like '%' + @Refine_Search_String + '%' collate Latin1_General_BIN))

		if @Exclude_Search_String is not null and @Exclude_Search_String <> '' 
		begin
			delete from @objects
			where id in (
				select objs.id
				from @objects objs
				inner join sys.sysobjects so with (nolock) on objs.id = so.id
				left outer join sys.syscomments sc with (nolock) on so.id = sc.id
				where (so.xtype <> 'TT')
				and (so.name collate Latin1_General_BIN like '%' + @Exclude_Search_String + '%' collate Latin1_General_BIN or sc.[text] collate Latin1_General_BIN like '%' + @Exclude_Search_String + '%' collate Latin1_General_BIN)

				union all

				select objs.id
				from @objects objs
				inner join sys.sysobjects so with (nolock) on objs.id = so.id
				inner join sys.table_types stt with (nolock) on so.id = stt.type_table_object_id
				left outer join sys.syscomments sc with (nolock) on so.id = sc.id
				where (so.xtype = 'TT')
				and (stt.name collate Latin1_General_BIN like '%' + @Exclude_Search_String + '%' collate Latin1_General_BIN or sc.[text] collate Latin1_General_BIN like '%' + @Exclude_Search_String + '%' collate Latin1_General_BIN)
			)
		end

		-- column objects
		insert into @objects
		select so.id, so.xtype, so.name, ss.name
		from sys.columns c with (nolock)
		inner join sys.sysobjects so with (nolock) on c.[object_id] = so.id
		inner join sys.schemas ss with (nolock) on so.[uid] = ss.[schema_id]
		where (so.xtype <> 'TT')
		and (c.name collate Latin1_General_BIN like '%' + @Search_String + '%' collate Latin1_General_BIN)
		and (@IsIncludeTypes = 0 or so.xtype in (select xtype from @Include_Types))
		and (@IsExcludeTypes = 0 or so.xtype not in (select xtype from @Exclude_Types))
		and (@Name is null or @Name = '' or so.name collate Latin1_General_BIN like '%' + @Name + '%' collate Latin1_General_BIN)
		and (@Exclude_Name is null or @Exclude_Name = '' or so.name collate Latin1_General_BIN not like '%' + @Exclude_Name + '%' collate Latin1_General_BIN)
		and (@Schema is null or @Schema = '' or ss.name collate Latin1_General_BIN like '%' + @Schema + '%' collate Latin1_General_BIN)
		and (@Exclude_Schema is null or @Exclude_Schema = '' or ss.name collate Latin1_General_BIN not like '%' + @Exclude_Schema + '%' collate Latin1_General_BIN)
		and (@Refine_Search_String is null or @Refine_Search_String = '' or c.name collate Latin1_General_BIN like '%' + @Refine_Search_String + '%' collate Latin1_General_BIN)
		and (@Exclude_Search_String is null or @Exclude_Search_String = '' or c.name collate Latin1_General_BIN not like '%' + @Exclude_Search_String + '%' collate Latin1_General_BIN)
		
		-- column objects Table type
		insert into @objects
		select so.id, so.xtype, stt.name, ss.name
		from sys.sysobjects so with (nolock)
		inner join sys.table_types stt with (nolock) on so.id = stt.type_table_object_id
		inner join sys.schemas ss with (nolock) on stt.[schema_id] = ss.[schema_id]
		inner join sys.columns c with (nolock) on c.[object_id] = stt.type_table_object_id
		where (so.xtype = 'TT')
		and (c.name collate Latin1_General_BIN like '%' + @Search_String + '%' collate Latin1_General_BIN)
		and (@IsIncludeTypes = 0 or so.xtype in (select xtype from @Include_Types))
		and (@IsExcludeTypes = 0 or so.xtype not in (select xtype from @Exclude_Types))
		and (@Name is null or @Name = '' or stt.name collate Latin1_General_BIN like '%' + @Name + '%' collate Latin1_General_BIN)
		and (@Exclude_Name is null or @Exclude_Name = '' or stt.name collate Latin1_General_BIN not like '%' + @Exclude_Name + '%' collate Latin1_General_BIN)
		and (@Schema is null or @Schema = '' or ss.name collate Latin1_General_BIN like '%' + @Schema + '%' collate Latin1_General_BIN)
		and (@Exclude_Schema is null or @Exclude_Schema = '' or ss.name collate Latin1_General_BIN not like '%' + @Exclude_Schema + '%' collate Latin1_General_BIN)
		and (@Refine_Search_String is null or @Refine_Search_String = '' or c.name collate Latin1_General_BIN like '%' + @Refine_Search_String + '%' collate Latin1_General_BIN)
		and (@Exclude_Search_String is null or @Exclude_Search_String = '' or c.name collate Latin1_General_BIN not like '%' + @Exclude_Search_String + '%' collate Latin1_General_BIN)

	end


	select distinct
		[schema],
		name,
		[type] = ltrim(rtrim(xtype)),

		-- http://msdn.microsoft.com/en-us/library/ms177596.aspx
		type_desc = (case 
			when xtype = 'AF' then 'Aggregate function (CLR)'
			when xtype = 'C'  then 'CHECK constraint'
			when xtype = 'D'  then 'Default or DEFAULT constraint'
			when xtype = 'F'  then 'FOREIGN KEY constraint'
			when xtype = 'FN' then 'Scalar function'
			when xtype = 'FS' then 'Assembly (CLR) scalar-function'
			when xtype = 'FT' then 'Assembly (CLR) table-valued function'
			when xtype = 'IF' then 'In-lined table-function'
			when xtype = 'IT' then 'Internal table'
			when xtype = 'L'  then 'Log'
			when xtype = 'P'  then 'Stored procedure'
			when xtype = 'PC' then 'Assembly (CLR) stored-procedure'
			when xtype = 'PK' then 'PRIMARY KEY constraint (type is K)'
			when xtype = 'RF' then 'Replication filter stored procedure'
			when xtype = 'S'  then 'System table'
			when xtype = 'SN' then 'Synonym'
			when xtype = 'SQ' then 'Service queue'
			when xtype = 'TA' then 'Assembly (CLR) DML trigger'
			when xtype = 'TF' then 'Table function'
			when xtype = 'TR' then 'SQL DML Trigger'
			when xtype = 'TT' then 'Table type'
			when xtype = 'U'  then 'User table'
			when xtype = 'UQ' then 'UNIQUE constraint (type is K)'
			when xtype = 'V'  then 'View'
			when xtype = 'X'  then 'Extended stored procedure'
			else '' end
		),

		[sp_helptext] = (case when xtype not in ('AF','F','FS','PK','SN','TT','U','UQ') then ('exec sp_helptext ''' + [schema] + '.' + name + '''') else '' end),

		[sp_help] = (case when xtype <> 'TT' then ('exec sp_help ''' + [schema] + '.' + name + '''') else '' end),
		
		[sp_columns] = (case 
			when xtype in ('S','SN','TF','U','V') then 'exec sp_columns ' + name 
			when xtype = 'TT' then 
				'select *' + ' ' +
				'from sys.columns with (nolock)' + ' ' +
				'where [object_id] = ' + cast(id as varchar) + ' ' +
				'order by column_id'
			when xtype in ('PK','UQ') then 
				'select Table_Name = schema_name(kc.[schema_id]) + ''.'' + object_name(kc.parent_object_id), Column_Name = col_name(ic.[object_id], ic.column_id), Sort_Order = (case when ic.is_descending_key = 1 then ''DESC'' else ''ASC'' end)' + ' ' +
				'from sys.key_constraints kc with (nolock)' + ' ' +
				'inner join sys.index_columns ic with (nolock) on kc.parent_object_id = ic.[object_id] and kc.unique_index_id = ic.index_id' + ' ' +
				'where kc.[object_id] = ' + cast(id as varchar) + ' ' +
				'order by ic.key_ordinal'
			when xtype = 'F' then 
				'select Foreign_Key = schema_name(f.[schema_id]) + ''.'' + f.name,' + ' ' +
				'Foreign_Table = schema_name(sop.[uid]) + ''.'' + object_name(f.parent_object_id),' + ' ' +
				'Foreign_Column = col_name(fc.parent_object_id, fc.parent_column_id),' + ' ' +
				'Primary_Table = schema_name(sof.[uid]) + ''.'' + object_name(f.referenced_object_id),' + ' ' +
				'Primary_Column = col_name(fc.referenced_object_id, fc.referenced_column_id)' + ' ' +
				'from sys.foreign_keys f with (nolock)' + ' ' +
				'inner join sys.foreign_key_columns fc with (nolock)' + ' ' +
				'on f.[object_id] = fc.constraint_object_id' + ' ' +
				'and f.[object_id] = ' + cast(id as varchar) + ' ' +
				'inner join sys.sysobjects sop with (nolock) on sop.id = f.parent_object_id' + ' ' +
				'inner join sys.sysobjects sof with (nolock) on sof.id = f.referenced_object_id'
			when xtype = 'D' then 
				'select Table_Name = schema_name([schema_id]) + ''.'' + object_name(parent_object_id), Column_Name = col_name(parent_object_id, parent_column_id)' + ' ' +
				'from sys.default_constraints with (nolock)' + ' ' +
				'where [object_id] = ' +  + cast(id as varchar)
			else '' end),

		[sysobjects] = 'select * from sys.sysobjects with (nolock) where id = ' + cast(id as varchar),

		[sp_searchtext] = 'exec sp_searchtext ''' + name + ''''

	from @objects
	order by type_desc, [schema], name

END
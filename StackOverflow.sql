set noexec off;
go
set nocount, xact_abort on;
go

if @@trancount != 0
begin
    raiserror(N'Open transaction not allowed.', 18, 1) with nowait;
    set noexec on;
end
go

use master;
go

declare @DropDatabase bit = 0;

if @DropDatabase = 1
begin
    if db_id('StackOverflowFun') is not null
    begin
        exec('alter database StackOverflowFun set single_user with rollback immediate;');
        exec('drop database StackOverflowFun;');
    end
end
go

if db_id('StackOverflowFun') is null
begin
    exec('create database StackOverflowFun;');
end
go

use StackOverflowFun;
go

if db_name() != 'StackOverflowFun'
begin
    raiserror(N'Open transaction not allowed.', 18, 1) with nowait;
    set noexec on;
end
go

create or alter procedure #DropAllTables
as
begin
    set nocount, xact_abort on;

    declare @Cr nchar(1) = nchar(13);
    declare @Lf nchar(1) = nchar(10);
    declare @CrLf nchar(2) = concat(@Cr, @Lf);
    declare @Tab nchar(1) = nchar(9);

    declare @AlterTableDropFkQueryTemplate nvarchar(max) = N'
alter table [##SchemaName##].[##TableName##] drop
##ConstraintFragmentList##
';

    declare @DropTableQueryTemplate nvarchar(max) = N'
drop table if exists [##SchemaName##].[##TableName##];
';

    declare @Query nvarchar(max);

    declare ForeignKeyCursor cursor local fast_forward for
        select
            --s.name as TableSchema,
            --t.name as TableName,
            --d1.ConstraintFragmentList,
            d2.Query
        from sys.tables t
        join sys.schemas s on t.schema_id = s.schema_id
        outer apply (
            select v4.V4 as ConstraintFragmentList
            from (
                select quotename(name) as FkName
                from sys.foreign_keys fk
                where fk.parent_object_id = t.object_id
                for xml path('')
            ) v1(V1)
            outer apply (select replace(V1, '</FkName><FkName>', concat(',', @CrLf, @Tab, 'constraint if exists '))) v2(V2)
            outer apply (select replace(V2, '<FkName>', concat(@Tab, 'constraint if exists '))) v3(V3)
            outer apply (select replace(V3, '</FkName>', concat(';', @CrLf))) v4(V4)
        ) d1
        outer apply (
            select v4.V4 as Query
            from (select @AlterTableDropFkQueryTemplate) v1(V1)
            outer apply (select replace(V1, '##SchemaName##', s.name)) v2(V2)
            outer apply (select replace(V2, '##TableName##', t.name)) v3(V3)
            outer apply (select replace(V3, '##ConstraintFragmentList##', d1.ConstraintFragmentList)) v4(V4)
        ) d2
        where d1.ConstraintFragmentList is not null;

    open ForeignKeyCursor;
    fetch next from ForeignKeyCursor into @Query;

    while @@fetch_status = 0
    begin
        --raiserror(@Query, 0, 1) with nowait;
        exec(@Query);
        fetch next from ForeignKeyCursor into @Query;
    end

    declare TableCursor cursor local fast_forward for
        select d1.Query
        from sys.tables t
        join sys.schemas s on t.schema_id = s.schema_id
        outer apply (
            select v3.V3 as Query
            from (select @DropTableQueryTemplate) v1(V1)
            outer apply (select replace(V1, '##SchemaName##', s.name)) v2(V2)
            outer apply (select replace(V2, '##TableName##', t.name)) v3(V3)
        ) d1;

    open TableCursor;
    fetch next from TableCursor into @Query;

    while @@fetch_status = 0
    begin
        --raiserror(@Query, 0, 1) with nowait;
        exec(@Query);
        fetch next from TableCursor into @Query;
    end
end
go

exec #DropAllTables;
go

/*
Aggregating dbo.Badges from the Brent Ozar StackOverflow2013 database:

select Name, count(1) as NumRows
from dbo.Badges
group by Name
order by count(1) desc;

Name	NumRows
Popular Question	1286465
Student	751807
Editor	630271
Scholar	594064
Notable Question	542758
Teacher	535840
Supporter	450118
Nice Answer	357470
Yearling	324457
Tumbleweed	317744
Commentator	290831
Nice Question	154689
Critic	133284
Enlightened	111244
Revival	107749
Necromancer	106301
Famous Question	106166
Autobiographer	105215
Custodian	95603
Good Answer	86967
*/
go

create table dbo.Badges (
    Id int identity(1,1) not null,
    Name nvarchar(40) not null,
    UserId int not null,
    Date datetime not null,

    constraint PK_Badges_Id primary key clustered (Id)
);
go

create table dbo.Comments (
    Id int identity(1,1) not null,
    CreationDate datetime not null,
    PostId int not null,
    Score int null,
    Text nvarchar(700) not null,
    UserId int null,

    constraint PK_Comments_Id primary key clustered (Id)
);
go

create table dbo.LinkTypes (
    Id int identity(1,1) not null,
    Type varchar(50) not null,

    constraint PK_LinkTypes_Id primary key clustered (Id)
);
go

create table dbo.PostLinks (
    Id int identity(1,1) not null,
    CreationDate datetime not null,
    PostId int not null,
    RelatedPostId int not null,
    LinkTypeId int not null,

    constraint PK_PostLinks_Id primary key clustered (Id)
);
go

create table dbo.Posts (
    Id int identity(1,1) not null,
    AcceptedAnswerId int null,
    AnswerCount int null,
    Body nvarchar(max) not null,
    ClosedDate datetime null,
    CommentCount int null,
    CommunityOwnedDate datetime null,
    CreationDate datetime not null,
    FavoriteCount int null,
    LastActivityDate datetime not null,
    LastEditDate datetime null,
    LastEditorDisplayName nvarchar(40) null,
    LastEditorUserId int null,
    OwnerUserId int null,
    ParentId int null,
    PostTypeId int not null,
    Score int not null,
    Tags nvarchar(150) null,
    Title nvarchar(250) null,
    ViewCount int not null,

    constraint PK_Posts_Id primary key clustered (Id)
);
go

create table dbo.PostTypes (
    Id int identity(1,1) not null,
    Type nvarchar(50) not null,

    constraint PK_PostTypes_Id primary key clustered (Id)
);
go

create table dbo.Users (
    Id int identity(1,1) not null,
    AboutMe nvarchar(max) null,
    Age int null,
    CreationDate datetime not null,
    DisplayName nvarchar(40) not null,
    DownVotes int not null,
    EmailHash nvarchar(40) null,
    LastAccessDate datetime not null,
    Location nvarchar(100) null,
    Reputation int not null,
    UpVotes int not null,
    Views int not null,
    WebsiteUrl nvarchar(200) null,
    AccountId int null,

    constraint PK_Users_Id primary key clustered (Id)
);
go

create table dbo.Votes (
    Id int identity(1,1) not null,
    PostId int not null,
    UserId int null,
    BountyAmount int null,
    VoteTypeId int not null,
    CreationDate datetime not null,

    constraint PK_Votes_Id primary key clustered (Id)
);
go

alter table dbo.Votes add
    constraint FK_Votes_PostId foreign key (PostId) references dbo.Posts (Id),
    constraint FK_Votes_UserId foreign key (UserId) references dbo.Users (Id);
go

create table dbo.VoteTypes (
    Id int identity(1,1) not null,
    Name varchar(50) not null,

    constraint PK_VoteTypes_Id primary key clustered (Id)
);
go

set noexec off;
go

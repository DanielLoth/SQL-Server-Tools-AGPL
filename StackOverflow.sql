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

if is_srvrolemember('sysadmin') != 1
begin
	raiserror(N'Must be sysadmin at script execution commencement.', 18, 1) with nowait;
	set noexec on;
end
go

use master;
go

if loginproperty('DbOwnerLogin', 'PasswordHash') is null
begin
	create login DbOwnerLogin with
		password = 'apsfghasiyjh298ajdsgsGDSHl@',
		check_expiration = off,
		check_policy = off;
end
go

alter login DbOwnerLogin disable;
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
	exec('alter authorization on database::StackOverflowFun to DbOwnerLogin;');
	--exec('alter database StackOverflowFun set trustworthy on;');
end
go

if loginproperty('StackOverflowFunDeployer', 'PasswordHash') is null
begin
	create login StackOverflowFunDeployer with
		password = 'Something reasonably strong*8',
		check_expiration = off,
		check_policy = off;
end
go

use msdb;
go

drop user if exists StackOverflowFunDeployer;
go

if user_id('StackOverflowFunDeployer') is null
begin
	create user StackOverflowFunDeployer for login StackOverflowFunDeployer;
end
go

alter role SQLAgentUserRole add member StackOverflowFunDeployer;
go

use StackOverflowFun;
go

if db_name() != 'StackOverflowFun'
begin
	raiserror(N'Must run under StackOverflowFun database.', 18, 1) with nowait;
	set noexec on;
end
go

drop user if exists StackOverflowFunDeployer;
go

if user_id('StackOverflowFunDeployer') is null
begin
	--create user StackOverflowFunDeployer without login;
	create user StackOverflowFunDeployer for login StackOverflowFunDeployer;
end
go

alter role db_owner add member StackOverflowFunDeployer;
go

execute as login = 'StackOverflowFunDeployer';
go

--exec msdb..sp_help_job;
go

--select suser_sname(), user_name();
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
		select d2.Query
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

/*
Id	Type
1	Linked
3	Duplicate
*/
create table dbo.LinkTypes (
	Id int identity(1,1) not null,
	Type varchar(50) not null,

	constraint PK_LinkTypes_Id primary key clustered (Id),
	index U__LinkTypes_Id unique nonclustered (Type)
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

	constraint PK_PostTypes_Id primary key clustered (Id),
	index U__PostTypes_Type unique nonclustered (Type)
);
go

--insert into dbo.PostTypes (Type)
--values
--Id	Type
--1	Question
--2	Answer
--3	Wiki
--4	TagWikiExerpt
--5	TagWiki
--6	ModeratorNomination
--7	WikiPlaceholder
--8	PrivilegeWiki

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

/*
Id	Name
1	AcceptedByOriginator
2	UpMod
3	DownMod
4	Offensive
5	Favorite
6	Close
7	Reopen
8	BountyStart
9	BountyClose
10	Deletion
11	Undeletion
12	Spam
13	InformModerator
15	ModeratorReview
16	ApproveEditSuggestion
*/
create table dbo.VoteTypes (
	Id int identity(1,1) not null,
	Name varchar(50) not null,

	constraint PK_VoteTypes_Id primary key clustered (Id)
);
go

alter table dbo.Badges add
	constraint FK_Badges_UserId foreign key (UserId) references dbo.Users (Id);
go

alter table dbo.Comments add
	constraint FK_Comments_PostId foreign key (PostId) references dbo.Posts (Id),
	constraint FK_Comments_UserId foreign key (UserId) references dbo.Users (Id);
go

alter table dbo.PostLinks add
	constraint FK_PostLinks_PostId foreign key (PostId) references dbo.Posts (Id),
	constraint FK_PostLinks_RelatedPostId foreign key (RelatedPostId) references dbo.Posts (Id),
	constraint FK_PostLinks_LinkTypeId foreign key (LinkTypeId) references dbo.LinkTypes (Id);
go

-- Posts
alter table dbo.Posts add
	constraint FK_Posts_AcceptedAnswerId foreign key (AcceptedAnswerId) references dbo.Posts (Id),
	constraint FK_Posts_LastEditorUserId foreign key (LastEditorUserId) references dbo.Users (Id),
	constraint FK_Posts_OwnerUserId foreign key (OwnerUserId) references dbo.Users (Id),
	constraint FK_Posts_ParentId foreign key (ParentId) references dbo.Posts (Id),
	constraint FK_Posts_PostTypeId foreign key (PostTypeId) references dbo.PostTypes (Id);
go

alter table dbo.Votes add
	constraint FK_Votes_PostId foreign key (PostId) references dbo.Posts (Id),
	constraint FK_Votes_UserId foreign key (UserId) references dbo.Users (Id);
go

--create or alter procedure dbo.P1
--with execute as caller
--as
--begin
--	set nocount, xact_abort on;
--end
--go

--select * from sys.procedures;
--select * from sys.all_sql_modules;
--go

--select name, is_db_chaining_on from sys.databases;

drop procedure if exists dbo.ExecP1;
go
drop procedure if exists U1.P1;
go
drop schema if exists U1;
go

drop user if exists U1;
go

create user U1 without login;
go

create schema U1 authorization U1;
go

create procedure U1.P1
as
begin
	select * from sys.objects;
end
go

if cert_id('Permission$ViewDatabaseState') is not null
begin
	drop certificate Permission$ViewDatabaseState;
end
go

create certificate Permission$ViewDatabaseState
	encryption by password = 'something'
	with subject = 'something';
go

create user Permission$ViewDatabaseState from certificate Permission$ViewDatabaseState;
go

grant control on database::StackOverflowFun to Permission$ViewDatabaseState;
go

exec('U1.P1') as user = 'U1';
go

add signature
	to U1.P1
	by certificate Permission$ViewDatabaseState
	with password = 'something';
go

alter certificate Permission$ViewDatabaseState remove private key;
go

exec('U1.P1') as user = 'U1';
go

drop procedure if exists U1.P1;
go

drop user if exists Permission$ViewDatabaseState;
go

if cert_id('Permission$ViewDatabaseState') is not null
begin
	drop certificate Permission$ViewDatabaseState;
end
go

set noexec off;
go

declare @Deadline datetime = dateadd(second, 5, getutcdate());
declare @CanRetry bit = iif(getutcdate() <= @Deadline and is_srvrolemember('sysadmin') != 1, 1, 0);

while getutcdate() <= @Deadline and is_srvrolemember('sysadmin') != 1
begin
	revert;
end
go

if is_srvrolemember('sysadmin') != 1 throw 50000, N'Could not revert to sysadmin security context.', 1;
go

using System;
using System.IO;
using System.IO.Packaging;
using System.Text;
using System.Xml;

using Microsoft.Data.SqlClient;
using Microsoft.SqlServer.Dac;
using Microsoft.SqlServer.Dac.Model;

namespace UnitTest;

public class UnitTest1
{
    [Fact]
    public void Test1()
    {
        var modelSqlV1 = """
            create table dbo.A (Id int primary key, C1 int null);
            go
            create user MyUser without login;
            go
            create user U2 without login;
            go
            create schema MySchema authorization MyUser;
            go
            create procedure MySchema.P1 as return 0;
            go
            grant execute on object::MySchema.P1 to U2;
            go
            """;

        var modelSqlV2 = """
            create table dbo.B (Id int primary key check (Id = 1), C11 int null);
            go
            create user MyUser without login;
            go
            create user U2 without login;
            go
            create schema MySchema authorization MyUser;
            go
            create procedure MySchema.P1 as return 0;
            go
            grant execute on object::MySchema.P1 to U2;
            go
            """;

        var modelRefactorLogV2 = """
            <?xml version="1.0" encoding="utf-8"?>
            <Operations Version="1.0" xmlns="http://schemas.microsoft.com/sqlserver/dac/Serialization/2012/02">
              <Operation Name="Rename Refactor" Key="954bc0b4-9f59-4994-a04e-a9d7f27ad7e4" ChangeDateTime="02/21/2026 11:05:19">
                <Property Name="ElementName" Value="[dbo].[A]" />
                <Property Name="ElementType" Value="SqlTable" />
                <Property Name="ParentElementName" Value="[dbo]" />
                <Property Name="ParentElementType" Value="SqlSchema" />
                <Property Name="NewName" Value="B" />
              </Operation>
              <Operation Name="Rename Refactor" Key="4b66db52-38d3-4e35-9e69-f475e1f6fc3d" ChangeDateTime="02/21/2026 11:05:23">
                <Property Name="ElementName" Value="[dbo].[B].[C1]" />
                <Property Name="ElementType" Value="SqlSimpleColumn" />
                <Property Name="ParentElementName" Value="[dbo].[B]" />
                <Property Name="ParentElementType" Value="SqlTable" />
                <Property Name="NewName" Value="C11" />
              </Operation>
            </Operations>
            """;

        var preDeploySql = """
            ------------------------------
            -- Pre-deploy
            ------------------------------
            go

            ------------------------------
            -- End of pre-deploy
            ------------------------------
            go
            """;

        var postDeploySql = """
            ------------------------------
            -- Post-deploy
            ------------------------------
            go

            revoke view any column encryption key definition to public;
            go
            revoke view any column master key definition to public;
            go

            ------------------------------
            -- End of post-deploy
            ------------------------------
            go
            """;

        var databaseName = "MyDatabase";

        var modelV1 = GetModel(modelSqlV1);
        var packageV1 = GetDacPackage(modelV1, preDeploySql, postDeploySql);
        var p1 = Publish(packageV1, databaseName, true);
        var p1Script = p1.DatabaseScript;
        var p1Report = GetPrettyDeployReport(p1);

        var modelV2 = GetModel(modelSqlV2);
        var packageV2 = GetDacPackage(modelV2, preDeploySql, postDeploySql, modelRefactorLogV2);
        var p2 = Publish(packageV2, databaseName, false);
        var p2Script = p2.DatabaseScript;
        var p2Report = GetPrettyDeployReport(p2);
    }

    private static string GetPrettyDeployReport(PublishResult result)
    {
        var xml = new XmlDocument();
        xml.LoadXml(result.DeploymentReport);

        using var sw = new StringWriter();
        xml.Save(sw);

        return sw.ToString();
    }

    private static PublishResult Publish(DacPackage package, string databaseName, bool createNew)
    {
        var connectionStringBuilder = GetConnectionStringBuilder(databaseName);
        var connectionString = connectionStringBuilder.ConnectionString;

        var profile = GetProfile();
        profile.TargetDatabaseName = databaseName;
        profile.TargetConnectionString = connectionString;
        profile.DeployOptions.CreateNewDatabase = createNew;

        var publishOptions = GetPublishOptions(profile);

        var dacServices = new DacServices(connectionString);
        var publishResult = dacServices.Publish(package, databaseName, publishOptions);

        return publishResult;
    }

    private static TSqlModel GetModel(string sql)
    {
        var model = new TSqlModel(SqlServerVersion.Sql160, new());
        model.AddObjects(sql);
        model.Validate();

        return model;
    }

    private static DacProfile GetProfile()
    {
        var profile = new DacProfile();

        profile.DeployOptions.IncludeCompositeObjects = true;
        profile.DeployOptions.ScriptDatabaseOptions = false;
        profile.DeployOptions.IgnorePreDeployScript = false;
        profile.DeployOptions.IgnorePostDeployScript = false;
        profile.DeployOptions.AllowIncompatiblePlatform = true;

        profile.DeployOptions.AdditionalDeploymentContributors = Contributor.ContributorId;

        return profile;
    }

    private static PublishOptions GetPublishOptions(DacProfile profile)
    {
        var publishOptions = new PublishOptions()
        {
            DeployOptions = profile.DeployOptions,
            GenerateDeploymentReport = true,
            GenerateDeploymentScript = true
        };

        return publishOptions;
    }

    private static SqlConnectionStringBuilder GetConnectionStringBuilder(string databaseName)
    {
        var csb = new SqlConnectionStringBuilder
        {
            DataSource = @".\SQL2022CS",
            InitialCatalog = databaseName,
            TrustServerCertificate = true,
            Encrypt = true,
            IntegratedSecurity = true
        };

        return csb;
    }

    private static DacPackage GetDacPackage(TSqlModel model, string preDeployScript, string postDeployScript, string? refactorLog = null)
    {
        static void AddFile(Package package, string filename, string code)
        {
            var uri = new Uri("/" + filename, UriKind.Relative);
            var part = package.CreatePart(uri, "text/plain", CompressionOption.Normal);

            using var writer = new StreamWriter(part.GetStream(), Encoding.UTF8);
            writer.Write(code);
        }

        var ms = new MemoryStream();

        var packageMetadata = new PackageMetadata
        {
            Name = "Package",
            Version = "1.0.0.0",
            Description = "In-memory package"
        };

        var packageOptions = new PackageOptions();

        if (!string.IsNullOrWhiteSpace(refactorLog))
        {
            var refactorLogPath = Path.GetTempFileName();
            File.WriteAllText(refactorLogPath, refactorLog);

            packageOptions.RefactorLogPath = refactorLogPath;
        }

        DacPackageExtensions.BuildPackage(ms, model, packageMetadata, packageOptions);

        ms.Position = 0;

        using (var package = Package.Open(ms, FileMode.Open, FileAccess.ReadWrite))
        {
            AddFile(package, "predeploy.sql", preDeployScript);
            AddFile(package, "postdeploy.sql", postDeployScript);
        }

        var fs = new MemoryStream(ms.ToArray());
        var dacPackage = DacPackage.Load(fs, DacSchemaModelStorageType.Memory, FileAccess.Read);

        return dacPackage;
    }
}

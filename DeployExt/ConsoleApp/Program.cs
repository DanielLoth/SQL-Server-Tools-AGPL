using System.IO.Packaging;
using System.Text;

using BenchmarkDotNet.Attributes;
using BenchmarkDotNet.Running;

using Microsoft.SqlServer.Dac;
using Microsoft.SqlServer.Dac.Model;

var summary = BenchmarkRunner.Run<B1>();

return 0;

public class B1
{
    private static readonly TSqlModel Model = GetModel();

    [Benchmark]
    public TSqlModel GetModelV1() => GetModel();

    [Benchmark]
    public DacPackage GetDacPackageV1() => GetDacPackage(GetModel());

    [Benchmark]
    public DacPackage GetDacPackageV2() => GetDacPackage(Model);

    [Benchmark]
    public DacPackage GetDacPackageWithPrePostDeploy() => GetDacPackage(
        Model,
        """
        -- Begin pre-deploy script
        go

        -- End pre-deploy script
        go
        """,
        """
        -- Begin post-deploy script
        go

        -- End post-deploy script
        go
        """);

    private static TSqlModel GetModel()
    {
        var model = new TSqlModel(SqlServerVersion.Sql160, new());
        model.AddObjects("""
            create user U1 without login;
            go
            create table dbo.A (Id int primary key);
            go
            """);

        model.Validate();

        return model;
    }

    private static DacPackage GetDacPackage(TSqlModel model)
    {
        var ms = new MemoryStream();

        DacPackageExtensions.BuildPackage(ms, model, new PackageMetadata
        {
            Name = "Package",
            Version = "1.0.0.0",
            Description = "In-memory package"
        });

        ms.Position = 0;

        var package = DacPackage.Load(ms, DacSchemaModelStorageType.Memory, FileAccess.Read);

        return package;
    }

    private static DacPackage GetDacPackage(TSqlModel model, string preDeployScript, string postDeployScript)
    {
        static void AddFile(Package package, string filename, string code)
        {
            var uri = new Uri("/" + filename, UriKind.Relative);
            var part = package.CreatePart(uri, "text/plain", CompressionOption.Normal);

            using var writer = new StreamWriter(part.GetStream(), Encoding.UTF8);
            writer.Write(code);
        }

        var ms = new MemoryStream();

        DacPackageExtensions.BuildPackage(ms, model, new PackageMetadata
        {
            Name = "Package",
            Version = "1.0.0.0",
            Description = "In-memory package"
        });

        ms.Position = 0;

        using (var package = System.IO.Packaging.Package.Open(ms, FileMode.Open, FileAccess.ReadWrite))
        {
            AddFile(package, "predeploy.sql", preDeployScript);
            AddFile(package, "postdeploy.sql", postDeployScript);
        }

        var fs = new MemoryStream(ms.ToArray());
        var dacPackage = DacPackage.Load(fs, DacSchemaModelStorageType.Memory, FileAccess.Read);

        return dacPackage;
    }
}

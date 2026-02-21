using System.Linq;

using Microsoft.SqlServer.Dac.Deployment;
using Microsoft.SqlServer.Dac.Model;

namespace UnitTest;

[ExportDeploymentPlanModifier(ContributorId, "1.0.0.0")]
public sealed class Contributor : DeploymentPlanModifier
{
    public const string ContributorId = nameof(Contributor);

    protected override void OnExecute(DeploymentPlanContributorContext context)
    {
        var allSteps = context.GetDeploymentSteps().ToList();
        var preDeploySteps = context.GetPreDeploySteps().ToList();
        var mainSteps = context.GetMainDeploySteps().ToList();
        var postDeploySteps = context.GetPostDeploySteps().ToList();

        var source = context.Source;
        var target = context.Target;

        var ps = source.GetObjects(DacQueryScopes.UserDefined, Permission.TypeClass).ToList();
        var pss = ps.Select(x => x.GetScript()).ToList();

        var ts = target.GetObjects(DacQueryScopes.UserDefined, Permission.TypeClass).ToList();
        var tss = ts.Select(x => x.GetScript()).ToList();

        _ = 1;
    }
}

using System;
using System.IO;
using System.Linq;

using Microsoft.SqlServer.Dac.Deployment;
using Microsoft.SqlServer.Dac.Model;
using Microsoft.SqlServer.TransactSql.ScriptDom;

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

        var collationComparer = context.Options.CompareUsingTargetCollation switch
        {
            true => context.Target.CollationComparer,
            _ => context.Source.CollationComparer
        };

        var source = context.Source;
        var target = context.Target;

        var pca = new PermissionChangeAccumulator(collationComparer);

        foreach (var step in mainSteps.Where(x => x is DeploymentScriptDomStep).Cast<DeploymentScriptDomStep>())
        {
            step.Script.Accept(pca);
        }

        var changesWithNoEffect = pca.GetPermissionChangesWithNoEffect();

        foreach (var step in mainSteps.Where(x => x is DeploymentScriptDomStep).Cast<DeploymentScriptDomStep>())
        {
            var pcv = new PermissionCheckVisitor(changesWithNoEffect, collationComparer);
            step.Script.Accept(pcv);

            if (pcv.IsRedundant)
            {
                Remove(context.PlanHandle, step);
            }

            var xx = new AlreadyGrantedPermissionVisitor(context);
            step.Script.Accept(xx);

            if (xx.IsRedundant)
            {
                Remove(context.PlanHandle, step);
            }
        }

        var ps = source.GetObjects(DacQueryScopes.All, Microsoft.SqlServer.Dac.Model.Permission.TypeClass).ToList();
        var pss = ps.Select(x => (x.Name, x.GetScript())).ToList();

        var ts = target.GetObjects(DacQueryScopes.All, Microsoft.SqlServer.Dac.Model.Permission.TypeClass).ToList();
        var tss = ts.Select(x => (x.Name, x.GetScript())).ToList();

        var parser = new TSql160Parser(false, SqlEngineType.Standalone);

        var s = parser.Parse(new StringReader(tss.First().Item2), out _);

        _ = 1;
    }
}

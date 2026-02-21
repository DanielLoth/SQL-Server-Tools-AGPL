using System.Collections.Generic;
using System.Linq;

using Microsoft.SqlServer.Dac.Deployment;

namespace UnitTest;

internal static class Extensions
{
    public static IEnumerable<DeploymentStep> GetPreDeploySteps(this DeploymentPlanContributorContext context) =>
        context.GetStepsBetweenInclusive<BeginPreDeploymentScriptStep, EndPreDeploymentScriptStep>();

    public static IEnumerable<DeploymentStep> GetPostDeploySteps(this DeploymentPlanContributorContext context) =>
        context.GetStepsBetweenInclusive<BeginPostDeploymentScriptStep, EndPostDeploymentScriptStep>();

    public static IEnumerable<DeploymentStep> GetMainDeploySteps(this DeploymentPlanContributorContext context) =>
        context.GetStepsBetweenExclusive<EndPreDeploymentScriptStep, BeginPostDeploymentScriptStep>();

    public static IEnumerable<DeploymentStep> GetStepsBetweenExclusive<TStart, TEnd>(this DeploymentPlanContributorContext context) =>
        context.GetStepsBetweenInclusive<TStart, TEnd>().SkipWhile(x => x is TStart).TakeWhile(x => x is not TEnd);

    public static IEnumerable<DeploymentStep> GetStepsBetweenInclusive<TStart, TEnd>(this DeploymentPlanContributorContext context)
    {
        var steps = context.GetDeploymentSteps();

        return steps
            .SkipWhile(x => x is not TStart)
            .TakeWhile(x => x.Previous is not TEnd)
            .ToList();
    }

    public static IEnumerable<DeploymentStep> GetDeploymentSteps(this DeploymentPlanContributorContext context)
    {
        var node = context.PlanHandle.Head;
        if (node == null)
        {
            return Enumerable.Empty<DeploymentStep>();
        }

        var steps = new List<DeploymentStep>();

        while (node != null)
        {
            steps.Add(node);
            node = node.Next;
        }

        return steps;
    }
}

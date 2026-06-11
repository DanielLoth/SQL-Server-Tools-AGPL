using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.AccessControl;

using Microsoft.SqlServer.Dac.Deployment;
using Microsoft.SqlServer.Dac.Model;
using Microsoft.SqlServer.TransactSql.ScriptDom;
using Microsoft.Win32;

namespace UnitTest;

internal sealed class PermissionChangeAccumulator : TSqlConcreteFragmentVisitor
{
    private readonly ModelCollationComparer comparer;
    private readonly HashSet<PermissionChange> grants = new();
    private readonly HashSet<PermissionChange> revokes = new();

    public PermissionChangeAccumulator(ModelCollationComparer comparer)
    {
        this.comparer = comparer;
    }

    public override void Visit(GrantStatement node) => Accumulate(node, grants);
    public override void Visit(RevokeStatement node) => Accumulate(node, revokes);

    private void Accumulate(SecurityStatement node, HashSet<PermissionChange> set)
    {
        foreach (var principal in node.Principals)
        {
            var principalName = principal.Identifier.GetName();
            var securableName = node.SecurityTargetObject switch
            {
                null => string.Empty,
                _ => node.SecurityTargetObject.ObjectName.MultiPartIdentifier.GetName()
            };

            foreach (var permission in node.Permissions)
            {
                var permissionName = permission.GetName();
                var change = new PermissionChange(principalName, securableName, permissionName, comparer);
                set.Add(change);
            }
        }
    }

    public HashSet<PermissionChange> GetPermissionChangesWithNoEffect() => grants.Intersect(revokes).ToHashSet();
}

public sealed class AlreadyGrantedPermissionVisitor : TSqlConcreteFragmentVisitor
{
    private readonly DeploymentPlanContributorContext context;
    private readonly ModelCollationComparer comparer;
    public bool IsRedundant { get; private set; } = false;

    public AlreadyGrantedPermissionVisitor(DeploymentPlanContributorContext context)
    {
        this.context = context;

        this.comparer = context.Options.CompareUsingTargetCollation switch
        {
            true => context.Target.CollationComparer,
            _ => context.Source.CollationComparer
        };
    }

    public override void Visit(GrantStatement node)
    {
        var targetPermissions = context.Target.GetObjects(DacQueryScopes.All, Microsoft.SqlServer.Dac.Model.Permission.TypeClass).ToList();
        var tss = targetPermissions.Select(x => (x.Name, x.GetScript())).ToList();

        foreach (var principal in node.Principals)
        {
            var principalName = principal.Identifier.GetName();
            var securableName = node.SecurityTargetObject switch
            {
                null => string.Empty,
                _ => node.SecurityTargetObject.ObjectName.MultiPartIdentifier.GetName()
            };

            foreach (var permission in node.Permissions)
            {
                var permissionName = permission.GetName();
                var change = new PermissionChange(principalName, securableName, permissionName, comparer);
            }
        }
    }
}

public sealed class PermissionCheckVisitor : TSqlConcreteFragmentVisitor
{
    private readonly ModelCollationComparer comparer;
    private HashSet<PermissionChange> ChangesWithNoEffect { get; set; } = new();
    public bool IsRedundant { get; private set; } = false;

    public PermissionCheckVisitor(HashSet<PermissionChange> changesWithNoEffect, ModelCollationComparer comparer)
    {
        ChangesWithNoEffect = changesWithNoEffect;
        this.comparer = comparer;
    }

    public override void Visit(GrantStatement node) => CheckStatement(node);
    public override void Visit(RevokeStatement node) => CheckStatement(node);

    private void CheckStatement(SecurityStatement node)
    {
        foreach (var principal in node.Principals)
        {
            var principalName = principal.Identifier.GetName();
            var securableName = node.SecurityTargetObject switch
            {
                null => string.Empty,
                _ => node.SecurityTargetObject.ObjectName.MultiPartIdentifier.GetName()
            };

            foreach (var permission in node.Permissions)
            {
                var permissionName = permission.GetName();
                var change = new PermissionChange(principalName, securableName, permissionName, comparer);

                if (ChangesWithNoEffect.Contains(change))
                {
                    IsRedundant = true;
                }
            }
        }
    }
}

public sealed class PermissionChange : IEquatable<PermissionChange>
{
    private readonly ModelCollationComparer comparer;

    public string PrincipalName { get; }
    public string SecurableName { get; }
    public string PermissionName { get; }

    public PermissionChange(string principalName, string securableName, string permissionName, ModelCollationComparer comparer)
    {
        PrincipalName = principalName;
        SecurableName = securableName;
        PermissionName = permissionName;
        this.comparer = comparer;
    }

    public bool Equals(PermissionChange? other)
    {
        if (other is null) return false;

        return comparer.Equals(PrincipalName, other.PrincipalName) &&
            comparer.Equals(SecurableName,  other.SecurableName) &&
            comparer.Equals(PermissionName, other.PermissionName);
    }
}

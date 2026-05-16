// Resolves Queue GroupMembers without sharing; controller stays with sharing for UI lists.
public without sharing class FEC_CaseAssignmentQueueRoleResolver {
    private class MemberAggregate {
        Set<Id> userIds = new Set<Id>();
        Set<Id> userRoleIds = new Set<Id>();
    }

    public static Set<Id> ensureQueueIds(
        Set<String> normalizedQueueNames,
        Set<Id> preliminaryIds
    ) {
        Set<Id> ids = new Set<Id>();
        ids.addAll(preliminaryIds != null ? preliminaryIds : new Set<Id>());
        if (!ids.isEmpty()) {
            return ids;
        }
        for (Group g : [
            SELECT Id
            FROM Group
            WHERE Type = 'Queue' AND Name IN :normalizedQueueNames
        ]) {
            ids.add(g.Id);
        }
        return ids;
    }

    public static List<FEC_CaseAssignmentConfigController.OptionItem> buildPicklist(
        Set<Id> queueIds
    ) {
        if (queueIds == null || queueIds.isEmpty()) {
            return new List<FEC_CaseAssignmentConfigController.OptionItem>();
        }

        MemberAggregate aggregate = walkQueueMembership(queueIds);
        if (aggregate.userIds.isEmpty() && aggregate.userRoleIds.isEmpty()) {
            return new List<FEC_CaseAssignmentConfigController.OptionItem>();
        }

        Set<String> roleNames = new Set<String>();

        if (!aggregate.userRoleIds.isEmpty()) {
            for (UserRole roleRecord : [
                SELECT Name
                FROM UserRole
                WHERE Id IN :aggregate.userRoleIds
            ]) {
                if (String.isNotBlank(roleRecord.Name)) {
                    roleNames.add(roleRecord.Name);
                }
            }
        }

        if (!aggregate.userIds.isEmpty()) {
            for (User userRecord : [
                SELECT UserRole.Name
                FROM User
                WHERE Id IN :aggregate.userIds AND UserRoleId != NULL
            ]) {
                if (
                    userRecord.UserRole != null &&
                    String.isNotBlank(userRecord.UserRole.Name)
                ) {
                    roleNames.add(userRecord.UserRole.Name);
                }
            }
        }

        List<String> sortedRoleNames = new List<String>();
        sortedRoleNames.addAll(roleNames);
        sortedRoleNames.sort();

        List<FEC_CaseAssignmentConfigController.OptionItem> options = new List<FEC_CaseAssignmentConfigController.OptionItem>();
        for (String roleName : sortedRoleNames) {
            options.add(
                new FEC_CaseAssignmentConfigController.OptionItem(roleName, roleName)
            );
        }
        return options;
    }

    private static MemberAggregate walkQueueMembership(Set<Id> rootQueueOrGroupIds) {
        MemberAggregate result = new MemberAggregate();
        if (rootQueueOrGroupIds == null || rootQueueOrGroupIds.isEmpty()) {
            return result;
        }

        Set<Id> visitedGroups = new Set<Id>();
        Set<Id> pendingGroups = new Set<Id>();
        pendingGroups.addAll(rootQueueOrGroupIds);

        while (!pendingGroups.isEmpty()) {
            Set<Id> batchGroupIds = new Set<Id>();
            batchGroupIds.addAll(pendingGroups);
            pendingGroups.clear();

            // Queues reference Role-backed Groups (Type=Role / RoleAndSubordinates*) where
            // membership is hierarchy-based — GroupMember is often empty. Use RelatedId.
            for (Group grp : [
                SELECT Id, Type, RelatedId
                FROM Group
                WHERE Id IN :batchGroupIds
            ]) {
                if (
                    grp.RelatedId != null &&
                    grp.RelatedId.getSobjectType() == UserRole.SObjectType
                ) {
                    if ('Role'.equals(grp.Type)) {
                        result.userRoleIds.add(grp.RelatedId);
                    } else if (
                        grp.Type != null && grp.Type.startsWith('RoleAnd')
                    ) {
                        result.userRoleIds.add(grp.RelatedId);
                        addDescendantUserRoleIds(grp.RelatedId, result.userRoleIds);
                    }
                }
            }

            for (GroupMember gm : [
                SELECT GroupId, UserOrGroupId
                FROM GroupMember
                WHERE GroupId IN :batchGroupIds
            ]) {
                if (gm.UserOrGroupId == null) {
                    continue;
                }

                Id memberId = gm.UserOrGroupId;
                Schema.SObjectType objType = memberId.getSObjectType();

                if (objType == User.SObjectType) {
                    result.userIds.add(memberId);
                } else if (objType == Group.SObjectType) {
                    if (!visitedGroups.contains(memberId)) {
                        pendingGroups.add(memberId);
                    }
                } else if (objType == UserRole.SObjectType) {
                    result.userRoleIds.add(memberId);
                }
            }
            visitedGroups.addAll(batchGroupIds);
        }
        return result;
    }

    private static void addDescendantUserRoleIds(Id parentRoleId, Set<Id> target) {
        Set<Id> frontier = new Set<Id>{ parentRoleId };
        while (!frontier.isEmpty()) {
            Map<Id, UserRole> children = new Map<Id, UserRole>(
                [SELECT Id FROM UserRole WHERE ParentRoleId IN :frontier]
            );
            if (children.isEmpty()) {
                break;
            }
            target.addAll(children.keySet());
            frontier = children.keySet();
        }
    }
}
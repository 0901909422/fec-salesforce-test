/**
 * Map Owner Id (User/Queue) → FEC_Team__c qua FEC_Main_Queue__c / Group.DeveloperName + FEC_Team_Queue__c.
 * Cache theo transaction — dùng chung RAH trigger, Assignment UI, export (tránh SOQL 101 submit NOC bulk).
 */
public without sharing class FEC_OwnerTeamLookupSvc {

    private static Map<Id, String> teamByOwnerId = new Map<Id, String>();
    private static Map<Id, String> userMainQueueById = new Map<Id, String>();
    private static Map<Id, String> groupDevNameById = new Map<Id, String>();
    private static Map<String, String> teamByQueueName = new Map<String, String>();
    private static Boolean teamByQueueNameLoaded = false;

    public static Map<Id, String> getByOwnerIds(Set<Id> ownerIds) {
        Map<Id, String> out = new Map<Id, String>();
        if (ownerIds == null || ownerIds.isEmpty()) {
            return out;
        }
        Set<Id> missing = new Set<Id>();
        for (Id oid : ownerIds) {
            if (oid != null && !teamByOwnerId.containsKey(oid)) {
                missing.add(oid);
            }
        }
        if (!missing.isEmpty()) {
            teamByOwnerId.putAll(resolveUncached(missing));
            for (Id oid : missing) {
                if (!teamByOwnerId.containsKey(oid)) {
                    teamByOwnerId.put(oid, null);
                }
            }
        }
        for (Id oid : ownerIds) {
            if (oid != null && teamByOwnerId.containsKey(oid)) {
                out.put(oid, teamByOwnerId.get(oid));
            }
        }
        return out;
    }

    private static Map<Id, String> resolveUncached(Set<Id> ownerIds) {
        Map<Id, String> out = new Map<Id, String>();
        if (ownerIds == null || ownerIds.isEmpty()) {
            return out;
        }
        ensureTeamByQueueNameMap();
        Map<Id, String> ownerToQueueName = buildOwnerToQueueName(ownerIds);
        if (ownerToQueueName.isEmpty()) {
            return out;
        }
        for (Id oid : ownerIds) {
            if (!ownerToQueueName.containsKey(oid)) {
                continue;
            }
            String qName = ownerToQueueName.get(oid);
            if (teamByQueueName.containsKey(qName)) {
                out.put(oid, teamByQueueName.get(qName));
            }
        }
        return out;
    }

    private static Map<Id, String> buildOwnerToQueueName(Set<Id> ownerIds) {
        Map<Id, String> ownerToQueueName = new Map<Id, String>();
        Set<Id> userIds = new Set<Id>();
        Set<Id> groupIds = new Set<Id>();
        for (Id oid : ownerIds) {
            if (oid == null) {
                continue;
            }
            String typeName = oid.getSObjectType().getDescribe().getName();
            if (typeName == FEC_ConstantCommon.SOBJECT_USER) {
                if (userMainQueueById.containsKey(oid)) {
                    if (String.isNotBlank(userMainQueueById.get(oid))) {
                        ownerToQueueName.put(oid, userMainQueueById.get(oid));
                    }
                } else {
                    userIds.add(oid);
                }
            } else if (typeName == FEC_ConstantCommon.SOBJECT_GROUP) {
                if (groupDevNameById.containsKey(oid)) {
                    if (String.isNotBlank(groupDevNameById.get(oid))) {
                        ownerToQueueName.put(oid, groupDevNameById.get(oid));
                    }
                } else {
                    groupIds.add(oid);
                }
            }
        }
        if (!userIds.isEmpty()) {
            for (User u : [
                SELECT Id, FEC_Main_Queue__c
                FROM User
                WHERE Id IN :userIds
            ]) {
                userMainQueueById.put(u.Id, u.FEC_Main_Queue__c);
                if (String.isNotBlank(u.FEC_Main_Queue__c)) {
                    ownerToQueueName.put(u.Id, u.FEC_Main_Queue__c);
                }
            }
            for (Id uid : userIds) {
                if (!userMainQueueById.containsKey(uid)) {
                    userMainQueueById.put(uid, null);
                }
            }
        }
        if (!groupIds.isEmpty()) {
            for (Group g : [
                SELECT Id, DeveloperName
                FROM Group
                WHERE Id IN :groupIds AND Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
            ]) {
                groupDevNameById.put(g.Id, g.DeveloperName);
                ownerToQueueName.put(g.Id, g.DeveloperName);
            }
            for (Id gid : groupIds) {
                if (!groupDevNameById.containsKey(gid)) {
                    groupDevNameById.put(gid, null);
                }
            }
        }
        return ownerToQueueName;
    }

    private static void ensureTeamByQueueNameMap() {
        if (teamByQueueNameLoaded) {
            return;
        }
        for (FEC_Team_Queue__c row : [
            SELECT FEC_Queue_Name__c, FEC_Team__c
            FROM FEC_Team_Queue__c
        ]) {
            if (String.isNotBlank(row.FEC_Queue_Name__c)) {
                teamByQueueName.put(row.FEC_Queue_Name__c, row.FEC_Team__c);
            }
        }
        teamByQueueNameLoaded = true;
    }
}

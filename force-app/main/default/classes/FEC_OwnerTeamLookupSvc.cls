/**
 * Map Owner Id (User/Queue) → team qua FEC_Main_Queue__c / Group.DeveloperName + FEC_Team_Queue__c.
 *
 * Hai luồng tách biệt:
 * - {@link #getByOwnerIds}: Case Status / FEC_Team__c (vd CSSupport, SP) — ưu tiên FEC_Team_Queue__c.FEC_Team__c,
 *   fallback FEC_Select_Team__c khi FEC_Team__c trống.
 * - {@link #getReportTeamByOwnerIds}: báo cáo TAT / FEC_Updated_Group__c — chỉ FEC_Team__c, chuẩn hóa mã ngắn (PM, CC, …).
 */
public without sharing class FEC_OwnerTeamLookupSvc {

    private static Map<Id, String> teamByOwnerId = new Map<Id, String>();
    private static Map<Id, String> reportTeamByOwnerId = new Map<Id, String>();
    private static Map<Id, String> userMainQueueById = new Map<Id, String>();
    private static Map<Id, String> groupDevNameById = new Map<Id, String>();
    private static Map<String, String> teamByQueueNameForCase = new Map<String, String>();
    private static Map<String, String> teamByQueueNameForReport = new Map<String, String>();
    private static Boolean teamByQueueNameLoaded = false;

    /** Team hiển thị trên Case (Pending - SP, FEC_Team__c). */
    public static Map<Id, String> getByOwnerIds(Set<Id> ownerIds) {
        return resolveTeamMap(ownerIds, teamByOwnerId, teamByQueueNameForCase, false);
    }

    /** Mã team ngắn cho báo cáo TAT (FEC_Updated_Group__c). */
    public static Map<Id, String> getReportTeamByOwnerIds(Set<Id> ownerIds) {
        return resolveTeamMap(ownerIds, reportTeamByOwnerId, teamByQueueNameForReport, true);
    }

    private static Map<Id, String> resolveTeamMap(
        Set<Id> ownerIds,
        Map<Id, String> cache,
        Map<String, String> queueTeamMap,
        Boolean forReport
    ) {
        Map<Id, String> out = new Map<Id, String>();
        if (ownerIds == null || ownerIds.isEmpty()) {
            return out;
        }
        Set<Id> missing = new Set<Id>();
        for (Id oid : ownerIds) {
            if (oid != null && !cache.containsKey(oid)) {
                missing.add(oid);
            }
        }
        if (!missing.isEmpty()) {
            ensureTeamByQueueNameMaps();
            cache.putAll(resolveUncached(missing, queueTeamMap));
            for (Id oid : missing) {
                if (!cache.containsKey(oid)) {
                    cache.put(oid, null);
                }
            }
        }
        for (Id oid : ownerIds) {
            if (oid != null && cache.containsKey(oid)) {
                out.put(oid, cache.get(oid));
            }
        }
        return out;
    }

    private static Map<Id, String> resolveUncached(
        Set<Id> ownerIds,
        Map<String, String> queueTeamMap
    ) {
        Map<Id, String> out = new Map<Id, String>();
        if (ownerIds == null || ownerIds.isEmpty()) {
            return out;
        }
        Map<Id, String> ownerToQueueName = buildOwnerToQueueName(ownerIds);
        if (ownerToQueueName.isEmpty()) {
            return out;
        }
        for (Id oid : ownerIds) {
            if (!ownerToQueueName.containsKey(oid)) {
                continue;
            }
            String qName = ownerToQueueName.get(oid);
            if (queueTeamMap.containsKey(qName)) {
                out.put(oid, queueTeamMap.get(qName));
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

    private static void ensureTeamByQueueNameMaps() {
        if (teamByQueueNameLoaded) {
            return;
        }
        for (FEC_Team_Queue__c row : [
            SELECT FEC_Queue_Name__c, FEC_Team__c, FEC_Select_Team__r.Name
            FROM FEC_Team_Queue__c
            WHERE FEC_Queue_Name__c != NULL
        ]) {
            String caseTeam = resolveTeamCodeForCase(row);
            if (String.isNotBlank(caseTeam)) {
                teamByQueueNameForCase.put(row.FEC_Queue_Name__c, caseTeam);
            }
            if (String.isNotBlank(row.FEC_Team__c)) {
                String reportTeam = FEC_TeamGroupCodeUtil.normalizeForReport(row.FEC_Team__c);
                if (String.isNotBlank(reportTeam)) {
                    teamByQueueNameForReport.put(row.FEC_Queue_Name__c, reportTeam);
                }
            }
        }
        teamByQueueNameLoaded = true;
    }

    /**
     * Team trên Case / Pending status: FEC_Team__c trước; FEC_Select_Team__c chỉ khi FEC_Team__c trống.
     */
    @TestVisible
    private static String resolveTeamCodeForCase(FEC_Team_Queue__c row) {
        if (row == null) {
            return null;
        }
        if (String.isNotBlank(row.FEC_Team__c)) {
            return row.FEC_Team__c.trim();
        }
        return row.FEC_Select_Team__r != null &&
            String.isNotBlank(row.FEC_Select_Team__r.Name)
            ? row.FEC_Select_Team__r.Name.trim()
            : null;
    }
}

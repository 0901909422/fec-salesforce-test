public without sharing class FEC_CaseTatFullProcessSvc {
    private static final String FEC_BUSINESS_HOURS_NAME = 'FEC Business Hours';

    private static Id cachedBusinessHoursId;
    private static Boolean businessHoursLookupDone = false;
    public static void applyBeforeSave(List<Case> cases, Map<Id, Case> oldMap) {
        if (cases == null || cases.isEmpty()) {
            return;
        }

        Id bhId = resolveBusinessHoursId();
        Datetime nowTs = System.now();

        for (Case c : cases) {
            if (!isPendingStatus(c.FEC_Case_Status__c)) {
                continue;
            }
            if (oldMap != null) {
                Case prior = oldMap.get(c.Id);
                if (prior != null && !needsRecalcPending(c, prior)) {
                    continue;
                }
            }
            applyFullProcessTat(c, c, bhId, nowTs);
        }
    }

    public static void syncAfterSave(List<Case> triggerCases, Map<Id, Case> oldMap) {
        if (triggerCases == null || triggerCases.isEmpty()) {
            return;
        }

        Set<Id> caseIds = new Set<Id>();
        for (Case c : triggerCases) {
            if (c.Id != null && shouldSyncAfterSave(c, oldMap)) {
                caseIds.add(c.Id);
            }
        }
        if (caseIds.isEmpty()) {
            return;
        }

        List<Case> rows = [
            SELECT
                Id,
                FEC_Case_Status__c,
                FEC_Case_Created_On__c,
                FEC_Last_Updated_On__c,
                CreatedDate,
                FEC_TAT_Full_Process_Hrs__c
            FROM Case
            WHERE Id IN :caseIds
        ];

        Id bhId = resolveBusinessHoursId();
        Datetime nowTs = System.now();
        List<Case> updates = new List<Case>();

        for (Case row : rows) {
            Case patch = new Case(Id = row.Id);
            applyFullProcessTat(patch, row, bhId, nowTs);
            if (patch.FEC_TAT_Full_Process_Hrs__c != row.FEC_TAT_Full_Process_Hrs__c) {
                updates.add(patch);
            }
        }

        if (updates.isEmpty()) {
            return;
        }

        Boolean priorFlag = FEC_CaseTriggerHandler.isSystemUpdate;
        FEC_CaseTriggerHandler.isSystemUpdate = true;
        try {
            Database.update(updates, AccessLevel.SYSTEM_MODE);
        } finally {
            FEC_CaseTriggerHandler.isSystemUpdate = priorFlag;
        }
    }

    private static Boolean shouldSyncAfterSave(Case c, Map<Id, Case> oldMap) {
        if (isResolvedStatus(c.FEC_Case_Status__c)) {
            return true;
        }
        if (isPendingStatus(c.FEC_Case_Status__c)) {
            return oldMap == null || needsRecalcPending(c, oldMap.get(c.Id));
        }
        if (oldMap != null) {
            Case prior = oldMap.get(c.Id);
            if (prior != null
                && (isResolvedStatus(prior.FEC_Case_Status__c)
                || isPendingStatus(prior.FEC_Case_Status__c))) {
                return true;
            }
        }
        return false;
    }

    private static void applyFullProcessTat(
        Case target,
        Case source,
        Id bhId,
        Datetime nowTs
    ) {
        String status = source.FEC_Case_Status__c;
        Datetime anchorStart = source.FEC_Case_Created_On__c != null
            ? source.FEC_Case_Created_On__c
            : source.CreatedDate;

        if (anchorStart == null) {
            target.FEC_TAT_Full_Process_Hrs__c = null;
            return;
        }

        Datetime anchorEnd;
        if (isResolvedStatus(status)) {
            anchorEnd = source.FEC_Last_Updated_On__c;
        } else if (isPendingStatus(status)) {
            anchorEnd = nowTs;
        } else {
            target.FEC_TAT_Full_Process_Hrs__c = null;
            return;
        }

        if (anchorEnd == null) {
            target.FEC_TAT_Full_Process_Hrs__c = null;
            return;
        }

        if (bhId == null) {
            target.FEC_TAT_Full_Process_Hrs__c = null;
            return;
        }

        if (anchorEnd <= anchorStart) {
            target.FEC_TAT_Full_Process_Hrs__c = 0;
            return;
        }

        Long diffMs = BusinessHours.diff(bhId, anchorStart, anchorEnd);
        if (diffMs == null || diffMs < 0) {
            target.FEC_TAT_Full_Process_Hrs__c = null;
            return;
        }

        target.FEC_TAT_Full_Process_Hrs__c = Decimal.valueOf(diffMs)
            .divide(3600000, 12, System.RoundingMode.HALF_UP)
            .setScale(2, System.RoundingMode.HALF_UP);
    }

    private static Boolean isResolvedStatus(String status) {
        return FEC_CommonUltils.isCaseStatusResolved(status);
    }

    private static Boolean isPendingStatus(String status) {
        return String.isNotBlank(status)
            && status.startsWith(FEC_ConstantCommon.CASE_STATUS_PENDING_PREFIX);
    }

    private static Boolean needsRecalcPending(Case n, Case o) {
        if (o == null) {
            return true;
        }
        return n.FEC_Case_Status__c != o.FEC_Case_Status__c
            || n.FEC_Case_Created_On__c != o.FEC_Case_Created_On__c;
    }

    private static Id resolveBusinessHoursId() {
        if (businessHoursLookupDone) {
            return cachedBusinessHoursId;
        }
        businessHoursLookupDone = true;

        List<BusinessHours> named = [
            SELECT Id
            FROM BusinessHours
            WHERE Name = :FEC_BUSINESS_HOURS_NAME AND IsActive = TRUE
            LIMIT 1
        ];
        if (!named.isEmpty()) {
            cachedBusinessHoursId = named[0].Id;
            return cachedBusinessHoursId;
        }

        List<BusinessHours> def = [
            SELECT Id FROM BusinessHours WHERE IsActive = TRUE AND IsDefault = TRUE LIMIT 1
        ];
        if (!def.isEmpty()) {
            cachedBusinessHoursId = def[0].Id;
        }
        return cachedBusinessHoursId;
    }
}

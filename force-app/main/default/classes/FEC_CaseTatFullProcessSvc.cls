public without sharing class FEC_CaseTatFullProcessSvc {
    private static final String FEC_BUSINESS_HOURS_NAME = 'FEC Business Hours';

    private static Id cachedBusinessHoursId;
    private static Boolean businessHoursLookupDone = false;
    // SOQL 101: cache/dedupe theo transaction, tránh query lặp khi submit NOC bulk.
    private static Boolean routingHistoryCaseSyncInProgress = false;
    private static Set<Id> fullTatSyncedCaseIdsThisTransaction = new Set<Id>();

    public static void applyBeforeSave(List<Case> cases, Map<Id, Case> oldMap) {
        if (cases == null || cases.isEmpty()) {
            return;
        }
        if (oldMap != null && FEC_CaseTriggerHandler.isSystemUpdate) {
            // SOQL 101: cache/dedupe theo transaction, tránh query lặp khi submit NOC bulk.
            return;
        }

        Id bhId = resolveBusinessHoursId();
        Datetime nowTs = System.now();

        for (Case c : cases) {
            if (!isPendingStatus(c.FEC_Case_Status__c)) {
                continue;
            }
            applyFullProcessTat(c, c, bhId, nowTs);
        }
    }

    // SOQL 101: cache/dedupe theo transaction, tránh query lặp khi submit NOC bulk.
    public static void syncCasesFromRoutingHistory(Set<Id> caseIds) {
        if (caseIds == null || caseIds.isEmpty() || routingHistoryCaseSyncInProgress) {
            return;
        }
        // SOQL 101: cache/dedupe theo transaction, tránh query lặp khi submit NOC bulk.
        Set<Id> toSync = new Set<Id>();
        for (Id caseId : caseIds) {
            if (caseId != null && !fullTatSyncedCaseIdsThisTransaction.contains(caseId)) {
                toSync.add(caseId);
            }
        }
        if (toSync.isEmpty()) {
            return;
        }
        routingHistoryCaseSyncInProgress = true;
        try {
            syncCasesFromRoutingHistoryInternal(toSync);
            fullTatSyncedCaseIdsThisTransaction.addAll(toSync);
        } finally {
            routingHistoryCaseSyncInProgress = false;
        }
    }

    private static void syncCasesFromRoutingHistoryInternal(Set<Id> caseIds) {
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
            if (!isPendingStatus(row.FEC_Case_Status__c) && !isResolvedStatus(row.FEC_Case_Status__c)) {
                continue;
            }
            Case patch = new Case(Id = row.Id);
            applyFullProcessTat(patch, row, bhId, nowTs);
            if (patch.FEC_TAT_Full_Process_Hrs__c != row.FEC_TAT_Full_Process_Hrs__c) {
                updates.add(patch);
            }
        }

        if (updates.isEmpty()) {
            return;
        }

        for (Case row : updates) {
            FEC_CaseInitUpdateService.registerSystemCaseUpdate(row.Id);
        }

        // SOQL 101: cache/dedupe theo transaction, tránh query lặp khi submit NOC bulk.
        Boolean priorFlag = FEC_CaseTriggerHandler.isSystemUpdate;
        FEC_CaseTriggerHandler.isSystemUpdate = true;
        try {
            Database.update(updates, AccessLevel.SYSTEM_MODE);
        } finally {
            FEC_CaseTriggerHandler.isSystemUpdate = priorFlag;
        }
    }

    public static void syncAfterSave(List<Case> triggerCases, Map<Id, Case> oldMap) {
        if (triggerCases == null || triggerCases.isEmpty()) {
            return;
        }
        if (FEC_CaseTriggerHandler.isSystemUpdate) {
            // SOQL 101: cache/dedupe theo transaction, tránh query lặp khi submit NOC bulk.
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

        for (Case row : updates) {
            FEC_CaseInitUpdateService.registerSystemCaseUpdate(row.Id);
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
            target.FEC_TAT_Full_Process_Hrs__c = FEC_RoutingHistTatSvc.formatTatDisplay(0L);
            return;
        }

        Long diffMs = FEC_BusinessHoursTatUtil.diffMsExcludingWeekends(
            bhId,
            anchorStart,
            anchorEnd
        );
        if (diffMs == null || diffMs < 0) {
            target.FEC_TAT_Full_Process_Hrs__c = null;
            return;
        }

        target.FEC_TAT_Full_Process_Hrs__c = FEC_RoutingHistTatSvc.formatTatDisplay(diffMs);
    }

    private static Boolean isResolvedStatus(String status) {
        return FEC_CommonUltils.isCaseStatusResolved(status);
    }

    private static Boolean isPendingStatus(String status) {
        if (String.isBlank(status)) {
            return false;
        }
        if (status == FEC_ConstantCommon.CASE_STATUS_PENDING) {
            return true;
        }
        return status.startsWith(FEC_ConstantCommon.CASE_STATUS_PENDING_PREFIX)
            || status.startsWith('Pending -');
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
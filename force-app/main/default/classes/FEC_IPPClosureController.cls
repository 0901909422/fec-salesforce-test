/****************************************************************************************
 * File Name    : FEC_IPPClosureController.cls
 * Description  : Controller for IPP Closure. Eligible IPPs are resolved across the system by Account Number and exclude rows linked to another Case (FEC_IPP_Closure_Case__c or FEC_IPP_To_Close__c on other Cases); if Case.FEC_IPP_To_Close__c is set, returns that IPP only for review.
 ****************************************************************************************/

public without sharing class FEC_IPPClosureController {

    /** Case.Status mà IPP được coi không còn "khóa" bởi case khác (Customer/Internal Resolved-*, Interaction Closed / Auto-Closed, v.v.). Trùng dùng cho SOQL và isReleasedClosureParentCaseStatus. */
    private static final Set<String> RELEASED_CLOSURE_PARENT_CASE_STATUSES = new Set<String>{
        FEC_ConstantCommon.CASE_STATUS_RESOLVED_REJECTED,
        FEC_ConstantCommon.CASE_STATUS_RESOLVED_CANCELLED,
        FEC_ConstantCommon.CASE_STATUS_AUTO_CANCELLED,
        FEC_ConstantCommon.CASE_STATUS_RESOLVED_CANNOT_CONTACT_CUSTOMER,
        FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED,
        FEC_ConstantCommon.CASE_STATUS_CLOSED,
        FEC_ConstantCommon.CASE_STATUS_AUTO_CLOSED,
        FEC_ConstantCommon.CASE_STATUS_CANCELLED
    };

    public class IPPClosureDTO {
        @AuraEnabled public String Id;
        @AuraEnabled public String ippRecordNo;
        @AuraEnabled public String ippPlan;
        @AuraEnabled public Date ippOpenDate;
        @AuraEnabled public Date ippFirstDueDate;
        @AuraEnabled public Date ippMatureDate;
        @AuraEnabled public Decimal ippBalance;
        @AuraEnabled public Decimal ippCurrentBalance;
        @AuraEnabled public Decimal ippInterestRate;
        @AuraEnabled public Decimal ippTerm;
        @AuraEnabled public Decimal ippCurrentTerm;
    }

    public class IPPClosureResultDTO {
        @AuraEnabled public List<IPPClosureDTO> rows;
        @AuraEnabled public Boolean showNoEligibleWarning;
        @AuraEnabled public Id savedIppToCloseOnCase;
    }

    /**
     * Get IPPs for closure: same Account Number as Case. If Case.FEC_IPP_To_Close__c is set, returns only that IPP. Otherwise returns IPPs with Current Balance != 0 and != null, excluding rows linked to another Case via FEC_IPP_Closure_Case__c, and excluding IPPs already chosen on another Case (FEC_IPP_To_Close__c, Id != this Case).
     */
    @AuraEnabled(cacheable=false)
    public static IPPClosureResultDTO getEligibleIPPsForClosure(Id caseId) {
        IPPClosureResultDTO wrapper = new IPPClosureResultDTO();
        wrapper.rows = new List<IPPClosureDTO>();
        wrapper.showNoEligibleWarning = false;
        if (caseId == null) {
            return wrapper;
        }
        String accountNumber = getAccountNumberFromCase(caseId);
        if (String.isBlank(accountNumber)) {
            return wrapper;
        }
        Id caseIppToClose = null;
        List<Case> caseForIpp = [
            SELECT FEC_IPP_To_Close__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        if (!caseForIpp.isEmpty()) {
            caseIppToClose = caseForIpp[0].FEC_IPP_To_Close__c;
            wrapper.savedIppToCloseOnCase = caseIppToClose;
        }
        List<FEC_IPP__c> ipps = queryEligibleIppsForClosure(caseId, accountNumber, caseIppToClose);
        List<FEC_IPP__c> accessibleIpps = ipps;
        if (caseIppToClose == null && !accessibleIpps.isEmpty()) {
            Set<Id> linkedCaseIds = new Set<Id>();
            for (FEC_IPP__c r : accessibleIpps) {
                if (r.FEC_IPP_Closure_Case__c != null && r.FEC_IPP_Closure_Case__c != caseId) {
                    linkedCaseIds.add(r.FEC_IPP_Closure_Case__c);
                }
            }
            Set<Id> pendingLinkedCaseIds = getPendingCaseIds(linkedCaseIds);
            if (!pendingLinkedCaseIds.isEmpty()) {
                List<FEC_IPP__c> filteredByClosureCaseStatus = new List<FEC_IPP__c>();
                for (FEC_IPP__c r : accessibleIpps) {
                    if (r.FEC_IPP_Closure_Case__c == null
                        || r.FEC_IPP_Closure_Case__c == caseId
                        || !pendingLinkedCaseIds.contains(r.FEC_IPP_Closure_Case__c)) {
                        filteredByClosureCaseStatus.add(r);
                    }
                }
                accessibleIpps = filteredByClosureCaseStatus;
            }
        }
        if (caseIppToClose == null && !accessibleIpps.isEmpty()) {
            Set<Id> ippIdSet = new Set<Id>();
            for (FEC_IPP__c r : accessibleIpps) {
                ippIdSet.add(r.Id);
            }
            Set<Id> blockedByOtherCase = getIppIdsReferencedByOtherCases(caseId, ippIdSet);
            if (!blockedByOtherCase.isEmpty()) {
                List<FEC_IPP__c> filtered = new List<FEC_IPP__c>();
                for (FEC_IPP__c r : accessibleIpps) {
                    if (!blockedByOtherCase.contains(r.Id)) {
                        filtered.add(r);
                    }
                }
                accessibleIpps = filtered;
            }
        }
        accessibleIpps = filterBlockedAndDuplicateIpps(caseId, accountNumber, accessibleIpps, caseIppToClose);
        for (FEC_IPP__c rec : accessibleIpps) {
            IPPClosureDTO dto = new IPPClosureDTO();
            dto.Id = rec.Id;
            dto.ippRecordNo = normalizeIppRecordNo(rec.FEC_IPP_Record_No__c);
            dto.ippPlan = rec.FEC_IPP_Plan__c;
            dto.ippOpenDate = rec.FEC_IPP_Open_Date__c;
            dto.ippFirstDueDate = rec.FEC_IPP_First_Due_Date__c;
            dto.ippMatureDate = rec.FEC_IPP_Mature_Date__c;
            dto.ippBalance = rec.FEC_IPP_Balance__c;
            dto.ippCurrentBalance = rec.FEC_IPP_Current_Balance__c;
            dto.ippInterestRate = rec.FEC_IPP_Interest_Rate__c;
            dto.ippTerm = rec.FEC_IPP_Term__c;
            dto.ippCurrentTerm = rec.FEC_IPP_Current_Term__c;
            wrapper.rows.add(dto);
        }
        wrapper.showNoEligibleWarning = wrapper.rows.isEmpty();
        return wrapper;
    }

    /**
     * Save selected IPP to Case (FEC_IPP_To_Close__c) and set FEC_IPP_Closure_Case__c on the IPP row. Call when user completes Case with a selected IPP.
     */
    @AuraEnabled
    public static Boolean saveSelectedIPPToCase(Id caseId, Id ippId) {
        if (caseId == null || ippId == null) {
            return false;
        }
        String accountNumber = getAccountNumberFromCase(caseId);
        if (String.isBlank(accountNumber)) {
            return false;
        }
        List<FEC_IPP__c> ippRows = [
            SELECT Id, FEC_Customer_History__c, FEC_Customer_History__r.FEC_Account_Number__c,
                   FEC_IPP_Record_No__c, FEC_IPP_Plan__c, FEC_IPP_Open_Date__c,
                   FEC_IPP_First_Due_Date__c, FEC_IPP_Mature_Date__c, FEC_IPP_Balance__c,
                   FEC_IPP_Current_Balance__c, FEC_IPP_Closure_Case__c
            FROM FEC_IPP__c
            WHERE Id = :ippId
            LIMIT 1
        ];
        if (ippRows.isEmpty()) {
            return false;
        }
        FEC_IPP__c ippRec = ippRows[0];
        if (ippRec.FEC_Customer_History__r == null
            || String.isBlank(ippRec.FEC_Customer_History__r.FEC_Account_Number__c)
            || ippRec.FEC_Customer_History__r.FEC_Account_Number__c != accountNumber) {
            return false;
        }
        if (ippRec.FEC_IPP_Closure_Case__c != null
            && ippRec.FEC_IPP_Closure_Case__c != caseId
            && isPendingCaseStatus(ippRec.FEC_IPP_Closure_Case__c)
            && !isReleasedClosureParentCaseStatus(ippRec.FEC_IPP_Closure_Case__c)) {
            return false;
        }
        Set<Id> checkBlocked = new Set<Id>();
        checkBlocked.add(ippId);
        if (!getIppIdsReferencedByOtherCases(caseId, checkBlocked).isEmpty()) {
            return false;
        }
        Set<String> blockedBusinessKeys = getIppBusinessKeysReferencedByOtherPendingCases(caseId, accountNumber);
        if (blockedBusinessKeys.contains(getIppBusinessKey(ippRec))
            || blockedBusinessKeys.contains(getIppRecordPlanKey(ippRec))
            || blockedBusinessKeys.contains(getIppClosureDedupKey(ippRec))) {
            return false;
        }
        if (ippRec.FEC_IPP_Current_Balance__c == null || ippRec.FEC_IPP_Current_Balance__c == 0) {
            return false;
        }
        List<Case> cases = [SELECT Id, FEC_IPP_To_Close__c FROM Case WHERE Id = :caseId LIMIT 1];
        if (cases.isEmpty()) {
            return false;
        }
        Case c = cases[0];
        List<FEC_IPP__c> ippToUpdate = new List<FEC_IPP__c>();
        Id previousIppId = c.FEC_IPP_To_Close__c;
        if (previousIppId != null && previousIppId != ippId) {
            ippToUpdate.add(new FEC_IPP__c(Id = previousIppId, FEC_IPP_Closure_Case__c = null));
        }
        ippToUpdate.add(new FEC_IPP__c(Id = ippId, FEC_IPP_Closure_Case__c = caseId));
        c.FEC_IPP_To_Close__c = ippId;
        try {
            update ippToUpdate;
            update c;
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    private static List<FEC_IPP__c> queryEligibleIppsForClosure(Id caseId, String accountNumber, Id caseIppToClose) {
        String ippSelect =
            'SELECT Id, FEC_IPP_Record_No__c, FEC_IPP_Plan__c, FEC_IPP_Open_Date__c,' +
            ' FEC_IPP_First_Due_Date__c, FEC_IPP_Mature_Date__c, FEC_IPP_Balance__c,' +
            ' FEC_IPP_Current_Balance__c, FEC_IPP_Interest_Rate__c, FEC_IPP_Term__c,' +
            ' FEC_IPP_Current_Term__c, FEC_Customer_History__c,' +
            ' FEC_Customer_History__r.FEC_Account_Number__c, FEC_IPP_Closure_Case__c,' +
            ' CreatedDate, LastModifiedDate' +
            ' FROM FEC_IPP__c' +
            ' WHERE (FEC_IPP_Closure_Case__c = null OR FEC_IPP_Closure_Case__c = :caseId' +
            ' OR FEC_IPP_Closure_Case__r.Status IN :RELEASED_CLOSURE_PARENT_CASE_STATUSES)' +
            ' AND FEC_Customer_History__r.FEC_Account_Number__c = :accountNumber';
        if (caseIppToClose != null) {
            ippSelect += ' AND Id = :caseIppToClose';
        } else {
            ippSelect +=
                ' AND FEC_IPP_Current_Balance__c != null' +
                ' AND FEC_IPP_Current_Balance__c != 0' +
                ' AND Id NOT IN (' +
                ' SELECT FEC_IPP_To_Close__c FROM Case' +
                ' WHERE FEC_IPP_To_Close__c != null' +
                ' AND Id != :caseId' +
                ' AND (FEC_Case_Status__c = \'Pending\' OR FEC_Case_Status__c LIKE \'Pending -%\'' +
                ' OR Status = \'Pending\' OR Status LIKE \'Pending%\')' +
                ')';
        }
        ippSelect += ' ORDER BY FEC_IPP_Record_No__c ASC NULLS LAST, CreatedDate DESC';
        return Database.query(ippSelect);
    }

    private static String getAccountNumberFromCase(Id caseId) {
        List<Case> cases = [
            SELECT Id, FEC_Account_or_Contract__c, FEC_Account_Number__c,
                   FEC_Account_or_Contract__r.FEC_Account_Number__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        if (cases.isEmpty()) {
            return null;
        }
        Case c = cases[0];
        if (c.FEC_Account_or_Contract__c != null
            && c.FEC_Account_or_Contract__r != null
            && String.isNotBlank(c.FEC_Account_or_Contract__r.FEC_Account_Number__c)) {
            return c.FEC_Account_or_Contract__r.FEC_Account_Number__c.trim();
        }
        if (String.isNotBlank(c.FEC_Account_Number__c)) {
            return c.FEC_Account_Number__c.trim();
        }
        return null;
    }

    private static Set<Id> getIppIdsReferencedByOtherCases(Id currentCaseId, Set<Id> ippIds) {
        Set<Id> blocked = new Set<Id>();
        if (currentCaseId == null || ippIds == null || ippIds.isEmpty()) {
            return blocked;
        }
        for (Case c : [
            SELECT FEC_IPP_To_Close__c
            FROM Case
            WHERE FEC_IPP_To_Close__c IN :ippIds
              AND Id != :currentCaseId
              AND (FEC_Case_Status__c = 'Pending' OR FEC_Case_Status__c LIKE 'Pending -%' OR Status = 'Pending' OR Status LIKE 'Pending%')
        ]) {
            if (c.FEC_IPP_To_Close__c != null) {
                blocked.add(c.FEC_IPP_To_Close__c);
            }
        }
        return blocked;
    }

    private static List<FEC_IPP__c> filterBlockedAndDuplicateIpps(
        Id currentCaseId,
        String accountNumber,
        List<FEC_IPP__c> ipps,
        Id caseIppToClose
    ) {
        if (ipps == null || ipps.isEmpty()) {
            return ipps;
        }
        Set<String> blockedBusinessKeys = getIppBusinessKeysReferencedByOtherPendingCases(currentCaseId, accountNumber);
        Map<String, List<FEC_IPP__c>> groupedByClosureKey = new Map<String, List<FEC_IPP__c>>();
        for (FEC_IPP__c r : ipps) {
            if (blockedBusinessKeys.contains(getIppBusinessKey(r))
                || blockedBusinessKeys.contains(getIppRecordPlanKey(r))
                || blockedBusinessKeys.contains(getIppClosureDedupKey(r))) {
                continue;
            }
            String closureKey = getIppClosureDedupKey(r);
            if (!groupedByClosureKey.containsKey(closureKey)) {
                groupedByClosureKey.put(closureKey, new List<FEC_IPP__c>());
            }
            groupedByClosureKey.get(closureKey).add(r);
        }
        List<FEC_IPP__c> filtered = new List<FEC_IPP__c>();
        Set<String> plansWithRecordNo = new Set<String>();
        for (String closureKey : groupedByClosureKey.keySet()) {
            List<FEC_IPP__c> groupRows = groupedByClosureKey.get(closureKey);
            if (groupRows == null || groupRows.isEmpty()) {
                continue;
            }
            FEC_IPP__c representative = mergeIppGroupForClosure(groupRows, currentCaseId, caseIppToClose);
            if (representative == null) {
                continue;
            }
            String plan = normalizeKeyValue(representative.FEC_IPP_Plan__c);
            if (String.isBlank(normalizeKeyValue(representative.FEC_IPP_Record_No__c)) && plansWithRecordNo.contains(plan)) {
                continue;
            }
            filtered.add(representative);
            if (String.isNotBlank(normalizeKeyValue(representative.FEC_IPP_Record_No__c))) {
                plansWithRecordNo.add(plan);
            }
        }
        filtered.sort(new IppClosureRecordNoComparator());
        return filtered;
    }

    private class IppClosureRecordNoComparator implements Comparator<FEC_IPP__c> {
        public Integer compare(FEC_IPP__c a, FEC_IPP__c b) {
            String recordNoA = a != null && a.FEC_IPP_Record_No__c != null ? a.FEC_IPP_Record_No__c.trim() : '';
            String recordNoB = b != null && b.FEC_IPP_Record_No__c != null ? b.FEC_IPP_Record_No__c.trim() : '';
            if (String.isBlank(recordNoA) && String.isBlank(recordNoB)) {
                return 0;
            }
            if (String.isBlank(recordNoA)) {
                return 1;
            }
            if (String.isBlank(recordNoB)) {
                return -1;
            }
            Integer lenCompare = recordNoA.length() - recordNoB.length();
            if (lenCompare != 0) {
                return lenCompare;
            }
            return recordNoA.compareTo(recordNoB);
        }
    }

    private static FEC_IPP__c mergeIppGroupForClosure(List<FEC_IPP__c> groupRows, Id currentCaseId, Id caseIppToClose) {
        if (groupRows == null || groupRows.isEmpty()) {
            return null;
        }
        FEC_IPP__c canonical = selectCanonicalIpp(groupRows, currentCaseId, caseIppToClose);
        if (canonical == null) {
            return null;
        }
        FEC_IPP__c merged = cloneIppForMerge(canonical);
        for (FEC_IPP__c row : groupRows) {
            if (row == null || row.Id == canonical.Id) {
                continue;
            }
            coalesceIppFields(merged, row);
        }
        return merged;
    }

    private static FEC_IPP__c selectCanonicalIpp(List<FEC_IPP__c> groupRows, Id currentCaseId, Id caseIppToClose) {
        FEC_IPP__c best = null;
        Integer bestScore = -1;
        Datetime bestCreatedDate;
        for (FEC_IPP__c row : groupRows) {
            if (row == null) {
                continue;
            }
            if (caseIppToClose != null && row.Id == caseIppToClose) {
                return row;
            }
            Integer rowScore = scoreIppCompleteness(row);
            if (row.FEC_IPP_Open_Date__c != null) {
                rowScore += 20;
            }
            if (row.FEC_IPP_Balance__c != null && row.FEC_IPP_Current_Balance__c != null
                && row.FEC_IPP_Balance__c == row.FEC_IPP_Current_Balance__c) {
                rowScore += 15;
            }
            if (row.FEC_IPP_Balance__c != null && row.FEC_IPP_Current_Balance__c != null
                && row.FEC_IPP_Balance__c != row.FEC_IPP_Current_Balance__c) {
                rowScore -= 10;
            }
            if (row.FEC_IPP_Closure_Case__c == currentCaseId) {
                rowScore += 50;
            }
            Boolean isBetter = best == null;
            if (!isBetter && rowScore > bestScore) {
                isBetter = true;
            }
            if (!isBetter && rowScore == bestScore && row.CreatedDate != null) {
                if (bestCreatedDate == null || row.CreatedDate > bestCreatedDate) {
                    isBetter = true;
                }
            }
            if (isBetter) {
                best = row;
                bestScore = rowScore;
                bestCreatedDate = row.CreatedDate;
            }
        }
        return best;
    }

    private static FEC_IPP__c cloneIppForMerge(FEC_IPP__c source) {
        FEC_IPP__c copy = new FEC_IPP__c(
            Id = source.Id,
            FEC_IPP_Record_No__c = source.FEC_IPP_Record_No__c,
            FEC_IPP_Plan__c = source.FEC_IPP_Plan__c,
            FEC_IPP_Open_Date__c = source.FEC_IPP_Open_Date__c,
            FEC_IPP_First_Due_Date__c = source.FEC_IPP_First_Due_Date__c,
            FEC_IPP_Mature_Date__c = source.FEC_IPP_Mature_Date__c,
            FEC_IPP_Balance__c = source.FEC_IPP_Balance__c,
            FEC_IPP_Current_Balance__c = source.FEC_IPP_Current_Balance__c,
            FEC_IPP_Interest_Rate__c = source.FEC_IPP_Interest_Rate__c,
            FEC_IPP_Term__c = source.FEC_IPP_Term__c,
            FEC_IPP_Current_Term__c = source.FEC_IPP_Current_Term__c,
            FEC_Customer_History__c = source.FEC_Customer_History__c,
            FEC_IPP_Closure_Case__c = source.FEC_IPP_Closure_Case__c
        );
        copy.FEC_Customer_History__r = source.FEC_Customer_History__r;
        return copy;
    }

    private static void coalesceIppFields(FEC_IPP__c primary, FEC_IPP__c secondary) {
        if (primary == null || secondary == null) {
            return;
        }
        if (String.isBlank(normalizeKeyValue(primary.FEC_IPP_Plan__c))
            && String.isNotBlank(normalizeKeyValue(secondary.FEC_IPP_Plan__c))) {
            primary.FEC_IPP_Plan__c = secondary.FEC_IPP_Plan__c;
        }
        if (!isSameIppPlanForCoalesce(primary, secondary)) {
            return;
        }
        if (primary.FEC_IPP_Open_Date__c == null && secondary.FEC_IPP_Open_Date__c != null) {
            primary.FEC_IPP_Open_Date__c = secondary.FEC_IPP_Open_Date__c;
        }
        if (primary.FEC_IPP_First_Due_Date__c == null && secondary.FEC_IPP_First_Due_Date__c != null) {
            primary.FEC_IPP_First_Due_Date__c = secondary.FEC_IPP_First_Due_Date__c;
        }
        if (primary.FEC_IPP_Mature_Date__c == null && secondary.FEC_IPP_Mature_Date__c != null) {
            primary.FEC_IPP_Mature_Date__c = secondary.FEC_IPP_Mature_Date__c;
        }
        if (primary.FEC_IPP_Balance__c == null && secondary.FEC_IPP_Balance__c != null) {
            primary.FEC_IPP_Balance__c = secondary.FEC_IPP_Balance__c;
        }
        if (primary.FEC_IPP_Current_Balance__c == null && secondary.FEC_IPP_Current_Balance__c != null) {
            primary.FEC_IPP_Current_Balance__c = secondary.FEC_IPP_Current_Balance__c;
        }
        if (primary.FEC_IPP_Interest_Rate__c == null && secondary.FEC_IPP_Interest_Rate__c != null) {
            primary.FEC_IPP_Interest_Rate__c = secondary.FEC_IPP_Interest_Rate__c;
        }
        if (primary.FEC_IPP_Term__c == null && secondary.FEC_IPP_Term__c != null) {
            primary.FEC_IPP_Term__c = secondary.FEC_IPP_Term__c;
        }
        if (primary.FEC_IPP_Current_Term__c == null && secondary.FEC_IPP_Current_Term__c != null) {
            primary.FEC_IPP_Current_Term__c = secondary.FEC_IPP_Current_Term__c;
        }
    }

    private static Boolean isSameIppPlanForCoalesce(FEC_IPP__c primary, FEC_IPP__c secondary) {
        String primaryPlan = normalizeKeyValue(primary.FEC_IPP_Plan__c);
        String secondaryPlan = normalizeKeyValue(secondary.FEC_IPP_Plan__c);
        if (String.isBlank(primaryPlan) || String.isBlank(secondaryPlan)) {
            return false;
        }
        return primaryPlan.equals(secondaryPlan);
    }

    private static Set<String> getIppBusinessKeysReferencedByOtherPendingCases(Id currentCaseId, String accountNumber) {
        Set<String> blockedBusinessKeys = new Set<String>();
        if (currentCaseId == null || String.isBlank(accountNumber)) {
            return blockedBusinessKeys;
        }
        for (Case c : [
            SELECT FEC_IPP_To_Close__r.FEC_IPP_Record_No__c,
                   FEC_IPP_To_Close__r.FEC_IPP_Plan__c,
                   FEC_IPP_To_Close__r.FEC_IPP_Open_Date__c,
                   FEC_IPP_To_Close__r.FEC_IPP_First_Due_Date__c,
                   FEC_IPP_To_Close__r.FEC_IPP_Mature_Date__c,
                   FEC_IPP_To_Close__r.FEC_IPP_Balance__c,
                   FEC_IPP_To_Close__r.FEC_IPP_Current_Balance__c
            FROM Case
            WHERE FEC_IPP_To_Close__c != null
              AND Id != :currentCaseId
              AND FEC_IPP_To_Close__r.FEC_Customer_History__r.FEC_Account_Number__c = :accountNumber
              AND (FEC_Case_Status__c = 'Pending' OR FEC_Case_Status__c LIKE 'Pending -%' OR Status = 'Pending' OR Status LIKE 'Pending%')
        ]) {
            blockedBusinessKeys.add(getIppBusinessKey(c.FEC_IPP_To_Close__r));
            blockedBusinessKeys.add(getIppRecordPlanKey(c.FEC_IPP_To_Close__r));
            blockedBusinessKeys.add(getIppClosureDedupKey(c.FEC_IPP_To_Close__r));
        }
        for (FEC_IPP__c r : [
            SELECT FEC_IPP_Record_No__c, FEC_IPP_Plan__c, FEC_IPP_Open_Date__c,
                   FEC_IPP_First_Due_Date__c, FEC_IPP_Mature_Date__c, FEC_IPP_Balance__c,
                   FEC_IPP_Current_Balance__c
            FROM FEC_IPP__c
            WHERE FEC_Customer_History__r.FEC_Account_Number__c = :accountNumber
              AND FEC_IPP_Closure_Case__c != null
              AND FEC_IPP_Closure_Case__c != :currentCaseId
              AND (FEC_IPP_Closure_Case__r.FEC_Case_Status__c = 'Pending'
                   OR FEC_IPP_Closure_Case__r.FEC_Case_Status__c LIKE 'Pending -%'
                   OR FEC_IPP_Closure_Case__r.Status = 'Pending'
                   OR FEC_IPP_Closure_Case__r.Status LIKE 'Pending%')
        ]) {
            blockedBusinessKeys.add(getIppBusinessKey(r));
            blockedBusinessKeys.add(getIppRecordPlanKey(r));
            blockedBusinessKeys.add(getIppClosureDedupKey(r));
        }
        return blockedBusinessKeys;
    }

    private static Integer scoreIppCompleteness(FEC_IPP__c ippRec) {
        if (ippRec == null) {
            return 0;
        }
        Integer score = 0;
        if (String.isNotBlank(ippRec.FEC_IPP_Record_No__c)) {
            score += 100;
        }
        if (ippRec.FEC_IPP_Open_Date__c != null) {
            score += 10;
        }
        if (ippRec.FEC_IPP_First_Due_Date__c != null) {
            score += 5;
        }
        if (ippRec.FEC_IPP_Mature_Date__c != null) {
            score += 5;
        }
        if (ippRec.FEC_IPP_Balance__c != null) {
            score += 3;
        }
        if (ippRec.FEC_IPP_Current_Balance__c != null) {
            score += 3;
        }
        if (ippRec.FEC_IPP_Interest_Rate__c != null) {
            score += 2;
        }
        if (ippRec.FEC_IPP_Term__c != null) {
            score += 2;
        }
        if (ippRec.FEC_IPP_Current_Term__c != null) {
            score += 1;
        }
        return score;
    }

    private static String getIppClosureDedupKey(FEC_IPP__c ippRec) {
        if (ippRec == null) {
            return '';
        }
        String recordNo = normalizeIppRecordNo(ippRec.FEC_IPP_Record_No__c);
        if (String.isNotBlank(recordNo)) {
            return 'RECNO|' + recordNo;
        }
        return getIppRecordPlanKey(ippRec);
    }

    private static String normalizeIppRecordNo(Object recordNoValue) {
        String trimmed = normalizeKeyValue(recordNoValue);
        if (String.isBlank(trimmed)) {
            return '';
        }
        if (trimmed.isNumeric() && trimmed.length() < 3) {
            return trimmed.leftPad(3, '0');
        }
        return trimmed;
    }

    private static String getIppRecordPlanKey(FEC_IPP__c ippRec) {
        if (ippRec == null) {
            return '';
        }
        String recordNo = normalizeIppRecordNo(ippRec.FEC_IPP_Record_No__c);
        String plan = normalizeKeyValue(ippRec.FEC_IPP_Plan__c);
        if (String.isNotBlank(recordNo)) {
            return recordNo + '|' + plan;
        }
        return 'PLAN|' + plan + '|' + normalizeKeyValue(ippRec.FEC_IPP_Open_Date__c);
    }

    private static String getIppBusinessKey(FEC_IPP__c ippRec) {
        if (ippRec == null) {
            return '';
        }
        return String.join(new List<String>{
            normalizeKeyValue(ippRec.FEC_IPP_Record_No__c),
            normalizeKeyValue(ippRec.FEC_IPP_Plan__c),
            normalizeKeyValue(ippRec.FEC_IPP_Open_Date__c),
            normalizeKeyValue(ippRec.FEC_IPP_First_Due_Date__c),
            normalizeKeyValue(ippRec.FEC_IPP_Mature_Date__c),
            normalizeKeyValue(ippRec.FEC_IPP_Balance__c),
            normalizeKeyValue(ippRec.FEC_IPP_Current_Balance__c)
        }, '|');
    }

    private static String normalizeKeyValue(Object value) {
        if (value == null) {
            return '';
        }
        return String.valueOf(value).trim();
    }

    private static Boolean isReleasedClosureParentCaseStatus(Id linkedCaseId) {
        if (linkedCaseId == null) {
            return false;
        }
        List<Case> released = [
            SELECT Id
            FROM Case
            WHERE Id = :linkedCaseId
              AND Status IN :RELEASED_CLOSURE_PARENT_CASE_STATUSES
            LIMIT 1
        ];
        return !released.isEmpty();
    }

    private static Boolean isPendingCaseStatus(Id linkedCaseId) {
        if (linkedCaseId == null) {
            return false;
        }
        List<Case> pendingCases = [
            SELECT Id
            FROM Case
            WHERE Id = :linkedCaseId
              AND (FEC_Case_Status__c = 'Pending' OR FEC_Case_Status__c LIKE 'Pending -%' OR Status = 'Pending' OR Status LIKE 'Pending%')
            LIMIT 1
        ];
        return !pendingCases.isEmpty();
    }

    private static Set<Id> getPendingCaseIds(Set<Id> caseIds) {
        Set<Id> pendingCaseIds = new Set<Id>();
        if (caseIds == null || caseIds.isEmpty()) {
            return pendingCaseIds;
        }
        for (Case c : [
            SELECT Id
            FROM Case
            WHERE Id IN :caseIds
              AND (FEC_Case_Status__c = 'Pending' OR FEC_Case_Status__c LIKE 'Pending -%' OR Status = 'Pending' OR Status LIKE 'Pending%')
        ]) {
            pendingCaseIds.add(c.Id);
        }
        return pendingCaseIds;
    }

}
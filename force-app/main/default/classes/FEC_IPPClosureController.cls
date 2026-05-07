/****************************************************************************************
 * File Name    : FEC_IPPClosureController.cls
 * Description  : Controller for IPP Closure. Eligible IPPs exclude rows linked to another Case (FEC_IPP_Closure_Case__c or FEC_IPP_To_Close__c on other Cases); if Case.FEC_IPP_To_Close__c is set, returns that IPP only for review.
 ****************************************************************************************/

public without sharing class FEC_IPPClosureController {

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
     * Get IPPs for closure: same Customer History as Case. If Case.FEC_IPP_To_Close__c is set, returns only that IPP. Otherwise returns IPPs with Current Balance != 0 and != null, excluding rows linked to another Case via FEC_IPP_Closure_Case__c, and excluding IPPs already chosen on another Case (FEC_IPP_To_Close__c, Id != this Case).
     */
    @AuraEnabled(cacheable=false)
    public static IPPClosureResultDTO getEligibleIPPsForClosure(Id caseId) {
        IPPClosureResultDTO wrapper = new IPPClosureResultDTO();
        wrapper.rows = new List<IPPClosureDTO>();
        wrapper.showNoEligibleWarning = false;
        if (caseId == null) {
            return wrapper;
        }
        Id customerHistoryId = getCustomerHistoryIdFromCase(caseId);
        if (customerHistoryId == null) {
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
        List<FEC_IPP__c> ipps;
        if (caseIppToClose != null) {
            ipps = [
                SELECT Id, FEC_IPP_Record_No__c, FEC_IPP_Plan__c, FEC_IPP_Open_Date__c,
                       FEC_IPP_First_Due_Date__c, FEC_IPP_Mature_Date__c, FEC_IPP_Balance__c,
                       FEC_IPP_Current_Balance__c, FEC_IPP_Interest_Rate__c, FEC_IPP_Term__c,
                       FEC_IPP_Current_Term__c, FEC_Customer_History__c
                FROM FEC_IPP__c
                WHERE Id = :caseIppToClose
                  AND FEC_Customer_History__c = :customerHistoryId
                  AND (FEC_IPP_Closure_Case__c = null OR FEC_IPP_Closure_Case__c = :caseId)
                LIMIT 1
            ];
        } else {
            ipps = [
                SELECT Id, FEC_IPP_Record_No__c, FEC_IPP_Plan__c, FEC_IPP_Open_Date__c,
                       FEC_IPP_First_Due_Date__c, FEC_IPP_Mature_Date__c, FEC_IPP_Balance__c,
                       FEC_IPP_Current_Balance__c, FEC_IPP_Interest_Rate__c, FEC_IPP_Term__c,
                       FEC_IPP_Current_Term__c, FEC_Customer_History__c, FEC_IPP_Closure_Case__c,
                       FEC_IPP_Closure_Case__r.FEC_Case_Status__c
                FROM FEC_IPP__c
                WHERE FEC_Customer_History__c = :customerHistoryId
                  AND FEC_IPP_Current_Balance__c != null
                  AND FEC_IPP_Current_Balance__c != 0
                  AND (FEC_IPP_Closure_Case__c = null OR FEC_IPP_Closure_Case__c = :caseId)
                  AND Id NOT IN (
                      SELECT FEC_IPP_To_Close__c
                      FROM Case
                      WHERE FEC_IPP_To_Close__c != null
                        AND Id != :caseId
                        AND FEC_Case_Status__c LIKE 'Pending-%'
                  )
                ORDER BY FEC_IPP_Record_No__c ASC NULLS LAST
            ];
        }
        SObjectAccessDecision decision = Security.stripInaccessible(AccessType.READABLE, ipps);
        List<FEC_IPP__c> accessibleIpps = new List<FEC_IPP__c>();
        for (SObject so : decision.getRecords()) {
            accessibleIpps.add((FEC_IPP__c) so);
        }
        if (caseIppToClose == null && !accessibleIpps.isEmpty()) {
            List<FEC_IPP__c> filteredByClosureCaseStatus = new List<FEC_IPP__c>();
            for (FEC_IPP__c r : accessibleIpps) {
                if (r.FEC_IPP_Closure_Case__c == null || r.FEC_IPP_Closure_Case__c == caseId) {
                    filteredByClosureCaseStatus.add(r);
                } else if (!isPendingCaseStatusValue(r.FEC_IPP_Closure_Case__r != null ? r.FEC_IPP_Closure_Case__r.FEC_Case_Status__c : null)) {
                    filteredByClosureCaseStatus.add(r);
                }
            }
            accessibleIpps = filteredByClosureCaseStatus;
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
        for (FEC_IPP__c rec : accessibleIpps) {
            IPPClosureDTO dto = new IPPClosureDTO();
            dto.Id = rec.Id;
            dto.ippRecordNo = rec.FEC_IPP_Record_No__c;
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
        Id customerHistoryId = getCustomerHistoryIdFromCase(caseId);
        if (customerHistoryId == null) {
            return false;
        }
        List<FEC_IPP__c> ippRows = [
            SELECT Id, FEC_Customer_History__c, FEC_IPP_Current_Balance__c, FEC_IPP_Closure_Case__c
            FROM FEC_IPP__c
            WHERE Id = :ippId
            LIMIT 1
        ];
        if (ippRows.isEmpty()) {
            return false;
        }
        SObjectAccessDecision ippDecision = Security.stripInaccessible(AccessType.READABLE, ippRows);
        List<SObject> ippReadable = ippDecision.getRecords();
        if (ippReadable.isEmpty()) {
            return false;
        }
        FEC_IPP__c ippRec = (FEC_IPP__c) ippReadable[0];
        if (ippRec.FEC_Customer_History__c != customerHistoryId) {
            return false;
        }
        if (ippRec.FEC_IPP_Closure_Case__c != null
            && ippRec.FEC_IPP_Closure_Case__c != caseId
            && isPendingCaseStatus(ippRec.FEC_IPP_Closure_Case__c)) {
            return false;
        }
        Set<Id> checkBlocked = new Set<Id>();
        checkBlocked.add(ippId);
        if (!getIppIdsReferencedByOtherCases(caseId, checkBlocked).isEmpty()) {
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

    private static Id getCustomerHistoryIdFromCase(Id caseId) {
        List<Case> cases = [
            SELECT Id, FEC_Account_or_Contract__c, FEC_Account_Number__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        if (cases.isEmpty()) {
            return null;
        }
        Case c = cases[0];
        if (c.FEC_Account_or_Contract__c != null) {
            return c.FEC_Account_or_Contract__c;
        }
        if (String.isNotBlank(c.FEC_Account_Number__c)) {
            List<FEC_Customer_History__c> histories = [
                SELECT Id FROM FEC_Customer_History__c
                WHERE FEC_Account_Number__c = :c.FEC_Account_Number__c
                LIMIT 1
            ];
            if (!histories.isEmpty()) {
                return histories[0].Id;
            }
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
              AND FEC_Case_Status__c LIKE 'Pending-%'
        ]) {
            if (c.FEC_IPP_To_Close__c != null) {
                blocked.add(c.FEC_IPP_To_Close__c);
            }
        }
        return blocked;
    }

    private static Boolean isPendingCaseStatus(Id linkedCaseId) {
        if (linkedCaseId == null) {
            return false;
        }
        List<Case> pendingCases = [
            SELECT Id
            FROM Case
            WHERE Id = :linkedCaseId
              AND FEC_Case_Status__c LIKE 'Pending-%'
            LIMIT 1
        ];
        return !pendingCases.isEmpty();
    }

    private static Boolean isPendingCaseStatusValue(String caseStatusValue) {
        return String.isNotBlank(caseStatusValue) && caseStatusValue.startsWith('Pending-');
    }

}
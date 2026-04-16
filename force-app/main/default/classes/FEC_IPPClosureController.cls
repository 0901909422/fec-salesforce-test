/****************************************************************************************
 * File Name    : FEC_IPPClosureController.cls
 * Description  : Controller for IPP Closure. Lists IPPs (Current Balance != 0) for selection; if Case.FEC_IPP_To_Close__c is set, returns that IPP only for display.
 ****************************************************************************************/

public with sharing class FEC_IPPClosureController {

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
     * Get IPPs for closure: same Customer History as Case. If Case.FEC_IPP_To_Close__c is set, returns only that IPP (review / later stages). Otherwise returns all IPPs with Current Balance != 0 and != null.
     */
    @AuraEnabled(cacheable=false)
    public static IPPClosureResultDTO getEligibleIPPsForClosure(Id caseId) {
        IPPClosureResultDTO wrapper = new IPPClosureResultDTO();
        wrapper.rows = new List<IPPClosureDTO>();
        wrapper.showNoEligibleWarning = false;
        if (caseId == null) {
            return wrapper;
        }
        if (!Schema.sObjectType.Case.isAccessible() || !Schema.sObjectType.FEC_IPP__c.isAccessible()) {
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
        List<FEC_IPP__c> ipps = [
            SELECT Id, FEC_IPP_Record_No__c, FEC_IPP_Plan__c, FEC_IPP_Open_Date__c,
                   FEC_IPP_First_Due_Date__c, FEC_IPP_Mature_Date__c, FEC_IPP_Balance__c,
                   FEC_IPP_Current_Balance__c, FEC_IPP_Interest_Rate__c, FEC_IPP_Term__c,
                   FEC_IPP_Current_Term__c, FEC_Customer_History__c
            FROM FEC_IPP__c
            WHERE FEC_Customer_History__c = :customerHistoryId
            ORDER BY FEC_IPP_Record_No__c ASC NULLS LAST
        ];
        SObjectAccessDecision decision = Security.stripInaccessible(AccessType.READABLE, ipps);
        List<FEC_IPP__c> accessibleIpps = new List<FEC_IPP__c>();
        for (SObject so : decision.getRecords()) {
            accessibleIpps.add((FEC_IPP__c) so);
        }
        if (caseIppToClose != null) {
            FEC_IPP__c chosen = null;
            for (FEC_IPP__c rec : accessibleIpps) {
                if (rec.Id == caseIppToClose) {
                    chosen = rec;
                    break;
                }
            }
            if (chosen == null) {
                List<FEC_IPP__c> byId = [
                    SELECT Id, FEC_IPP_Record_No__c, FEC_IPP_Plan__c, FEC_IPP_Open_Date__c,
                           FEC_IPP_First_Due_Date__c, FEC_IPP_Mature_Date__c, FEC_IPP_Balance__c,
                           FEC_IPP_Current_Balance__c, FEC_IPP_Interest_Rate__c, FEC_IPP_Term__c,
                           FEC_IPP_Current_Term__c, FEC_Customer_History__c
                    FROM FEC_IPP__c
                    WHERE Id = :caseIppToClose
                    AND FEC_Customer_History__c = :customerHistoryId
                    LIMIT 1
                ];
                if (!byId.isEmpty()) {
                    SObjectAccessDecision dec2 = Security.stripInaccessible(AccessType.READABLE, byId);
                    if (!dec2.getRecords().isEmpty()) {
                        chosen = (FEC_IPP__c) dec2.getRecords()[0];
                    }
                }
            }
            if (chosen != null) {
                IPPClosureDTO dto = new IPPClosureDTO();
                dto.Id = chosen.Id;
                dto.ippRecordNo = chosen.FEC_IPP_Record_No__c;
                dto.ippPlan = chosen.FEC_IPP_Plan__c;
                dto.ippOpenDate = chosen.FEC_IPP_Open_Date__c;
                dto.ippFirstDueDate = chosen.FEC_IPP_First_Due_Date__c;
                dto.ippMatureDate = chosen.FEC_IPP_Mature_Date__c;
                dto.ippBalance = chosen.FEC_IPP_Balance__c;
                dto.ippCurrentBalance = chosen.FEC_IPP_Current_Balance__c;
                dto.ippInterestRate = chosen.FEC_IPP_Interest_Rate__c;
                dto.ippTerm = chosen.FEC_IPP_Term__c;
                dto.ippCurrentTerm = chosen.FEC_IPP_Current_Term__c;
                wrapper.rows.add(dto);
            }
            wrapper.showNoEligibleWarning = wrapper.rows.isEmpty();
            return wrapper;
        }
        for (FEC_IPP__c rec : accessibleIpps) {
            if (rec.FEC_IPP_Current_Balance__c == null || rec.FEC_IPP_Current_Balance__c == 0) {
                continue;
            }
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
     * Save selected IPP to Case (FEC_IPP_To_Close__c). Call when user completes Case with a selected IPP.
     */
    @AuraEnabled
    public static Boolean saveSelectedIPPToCase(Id caseId, Id ippId) {
        if (caseId == null || ippId == null) {
            return false;
        }
        if (!Schema.sObjectType.Case.isAccessible() || !Schema.sObjectType.Case.isUpdateable()) {
            return false;
        }
        if (!Schema.sObjectType.FEC_IPP__c.isAccessible()) {
            return false;
        }
        Id customerHistoryId = getCustomerHistoryIdFromCase(caseId);
        if (customerHistoryId == null) {
            return false;
        }
        List<FEC_IPP__c> ippRows = [
            SELECT Id, FEC_Customer_History__c, FEC_IPP_Current_Balance__c
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
        if (ippRec.FEC_IPP_Current_Balance__c == null || ippRec.FEC_IPP_Current_Balance__c == 0) {
            return false;
        }
        List<Case> cases = [SELECT Id, FEC_IPP_To_Close__c FROM Case WHERE Id = :caseId LIMIT 1];
        if (cases.isEmpty()) {
            return false;
        }
        Case c = cases[0];
        c.FEC_IPP_To_Close__c = ippId;
        try {
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
            if (!Schema.sObjectType.FEC_Customer_History__c.isAccessible()) {
                return null;
            }
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

}
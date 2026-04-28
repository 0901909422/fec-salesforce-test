public with sharing class FEC_InteractionHighlightController {
    
    @AuraEnabled(cacheable=true)
    public static InteractionHighlightData getInteractionHighlightData(String caseId) {
        try {
            InteractionHighlightData result = new InteractionHighlightData();
            
            Case caseRecord = [
                SELECT 
                    Id,
                    RecordType.Name,
                    RecordType.DeveloperName,
                    FEC_Interaction__c,
                    FEC_Interaction_ID__c,
                    FEC_ID_Search__c,
                    FEC_Interaction_Status__c,
                    FEC_Channel__c,
                    FEC_Interaction_Subchannel__c,
                    FEC_Last_Updated_On__c,
                    FEC_Last_Updated_By__c,
                    FEC_Account_or_Contract__c,
                    FEC_CIF_Number__c,
                    FEC_Category__r.Name,
                    FEC_Complain_Type__c,
                    FEC_SubCategory__r.FEC_Code__c,
                    FEC_Case_Status__c,
                    FEC_Case_Created_On__c,
                    CreatedDate
                FROM Case
                WHERE Id = :caseId
                LIMIT 1
            ];
            
            if (caseRecord == null) {
                return result;
            }
            
            // Nếu RecordType.Name khác "Interaction", lấy data từ FEC_Interaction__c
            Case interactionCase = caseRecord;
            if (caseRecord.RecordType.DeveloperName != FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME && caseRecord.FEC_Interaction__c != null) {
                List<Case> interactionCases = [
                    SELECT 
                        Id,
                        FEC_Interaction_ID__c,
                        FEC_ID_Search__c,
                        FEC_Interaction_Status__c,
                        FEC_Channel__c,
                        FEC_Interaction_Subchannel__c,
                        FEC_Last_Updated_On__c,
                        FEC_Last_Updated_By__c,
                        FEC_Account_or_Contract__c,
                        FEC_CIF_Number__c,
                        FEC_Category__r.Name,
                        FEC_Complain_Type__c,
                        FEC_SubCategory__r.FEC_Code__c,
                        FEC_Case_Status__c,
                        FEC_Case_Created_On__c,
                        CreatedDate
                    FROM Case
                    WHERE Id = :caseRecord.FEC_Interaction__c
                    LIMIT 1
                ];
                
                if (!interactionCases.isEmpty()) {
                    interactionCase = interactionCases[0];
                }
            }
            
            result.interactionId = interactionCase.FEC_Interaction_ID__c;
            result.caseId = interactionCase.Id;
            result.interactionIdSearch = interactionCase.FEC_ID_Search__c;
            if (String.isBlank(result.interactionId) && interactionCase.FEC_ID_Search__c != null) {
                result.interactionId = '<a href="/' + interactionCase.Id + '" target="_self">' + interactionCase.FEC_ID_Search__c + '</a>';
            }
            result.interactionStatus = interactionCase.FEC_Interaction_Status__c;
            result.interactionChannel = interactionCase.FEC_Channel__c;
            result.interactionSubStatus = interactionCase.FEC_Interaction_Subchannel__c;
            result.lastUpdatedOn = interactionCase.FEC_Last_Updated_On__c;
            result.lastUpdatedBy = interactionCase.FEC_Last_Updated_By__c;
            FEC_Customer_History__c customerHistory = null;
            if (interactionCase.FEC_Account_or_Contract__c != null) {
                List<FEC_Customer_History__c> histories = [
                    SELECT FEC_Customer_Name__c, FEC_National_ID_Passport_ID__c, FEC_Gender__c,
                           FEC_Date_of_Birth__c, FEC_Primary_Phone__c, FEC_Email__c, FEC_Customer_Segment__c
                    FROM FEC_Customer_History__c
                    WHERE Id = :interactionCase.FEC_Account_or_Contract__c
                    LIMIT 1
                ];
                
                if (!histories.isEmpty()) {
                    customerHistory = histories[0];
                    result.customerName = customerHistory.FEC_Customer_Name__c;
                    result.nationalId = customerHistory.FEC_National_ID_Passport_ID__c;
                    result.nationalIdMasked = FEC_CommonUltils.maskNationalIdOrPassport(customerHistory.FEC_National_ID_Passport_ID__c);
                    result.gender = customerHistory.FEC_Gender__c;
                    result.dateOfBirth = customerHistory.FEC_Date_of_Birth__c;
                    result.primaryPhone = customerHistory.FEC_Primary_Phone__c;
                    result.email = customerHistory.FEC_Email__c;
                    result.customerSegment = customerHistory.FEC_Customer_Segment__c;
                }
            }
            
            result.customerCategory = determineCustomerCategory(caseRecord, customerHistory);
            
            return result;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    private static String determineCustomerCategory(Case caseRecord, FEC_Customer_History__c customerHistory) {
        Set<Id> customerIds = new Set<Id>();
        Id interactionCaseId = null;
        if (caseRecord.RecordType.DeveloperName == FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME) {
            String uploadCategory = getCategoryFromUploadList(caseRecord);
            if (uploadCategory != null) return uploadCategory;
            interactionCaseId = caseRecord.Id;
            customerIds = getCustomerIdsFromInteraction(caseRecord.Id);
        } else if (caseRecord.FEC_Interaction__c != null) {
            interactionCaseId = caseRecord.FEC_Interaction__c;
            customerIds = getCustomerIdsFromInteraction(caseRecord.FEC_Interaction__c);
        }
        if (caseRecord.FEC_Account_or_Contract__c != null) {
            customerIds.add(caseRecord.FEC_Account_or_Contract__c);
        }
        if (!customerIds.isEmpty()) {
            String result = determineCustomerCategoryFromCustomerIds(customerIds);
            if (result == FEC_ConstantCommon.CUSTOMER_CATEGORY_NEUTRAL) {
                if (interactionCaseId != null) {
                    String fraudFromInteraction = checkSuspectedFraudFromInteractionCases(interactionCaseId);
                    if (fraudFromInteraction != null) return fraudFromInteraction;
                }
                if (caseRecord.RecordType.DeveloperName == FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME && isSuspectedFraud(caseRecord)) {
                    return FEC_ConstantCommon.CUSTOMER_CATEGORY_SUSPECTED_FRAUD;
                }
            }
            return result;
        }
        String uploadCategory = getCategoryFromUploadList(caseRecord);
        if (uploadCategory != null) return uploadCategory;
        if (interactionCaseId != null) {
            String fraudFromInteraction = checkSuspectedFraudFromInteractionCases(interactionCaseId);
            if (fraudFromInteraction != null) return fraudFromInteraction;
        }
        if (isSuspectedFraud(caseRecord)) return FEC_ConstantCommon.CUSTOMER_CATEGORY_SUSPECTED_FRAUD;
        if (isMedia(caseRecord)) return FEC_ConstantCommon.CUSTOMER_CATEGORY_MEDIA;
        if (isSeriousComplaint(caseRecord)) return FEC_ConstantCommon.CUSTOMER_CATEGORY_SERIOUS_COMPLAINT;
        return FEC_ConstantCommon.CUSTOMER_CATEGORY_NEUTRAL;
    }

    private static String checkSuspectedFraudFromInteractionCases(Id interactionCaseId) {
        List<Case> interactionCases = [
            SELECT FEC_Account_or_Contract__c, FEC_CIF_Number__c, FEC_Category__r.Name, FEC_Complain_Type__c,
                   FEC_SubCategory__r.FEC_Code__c, FEC_Case_Created_On__c, FEC_Case_Status__c, CreatedDate
            FROM Case
            WHERE FEC_Interaction__c = :interactionCaseId
            AND RecordType.DeveloperName = :FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME
        ];
        for (Case c : interactionCases) {
            if (isSuspectedFraud(c)) return FEC_ConstantCommon.CUSTOMER_CATEGORY_SUSPECTED_FRAUD;
        }
        return null;
    }

    private static String determineCustomerCategoryFromCustomerIds(Set<Id> customerIds) {
        if (customerIds == null || customerIds.isEmpty()) return FEC_ConstantCommon.CUSTOMER_CATEGORY_NEUTRAL;
        List<Case> allCustomerCases = getAllCasesForCustomers(expandCustomerIdsBySameNameOrCif(customerIds));
        String uploadCat = getCategoryFromUploadListBulk(allCustomerCases);
        if (uploadCat != null) return uploadCat;
        String cat = FEC_ConstantCommon.CUSTOMER_CATEGORY_NEUTRAL;
        for (Case c : allCustomerCases) {
            if (isSuspectedFraud(c)) return FEC_ConstantCommon.CUSTOMER_CATEGORY_SUSPECTED_FRAUD;
            if (isMedia(c)) cat = FEC_ConstantCommon.CUSTOMER_CATEGORY_MEDIA;
            if (isSeriousComplaint(c) && cat != FEC_ConstantCommon.CUSTOMER_CATEGORY_MEDIA) cat = FEC_ConstantCommon.CUSTOMER_CATEGORY_SERIOUS_COMPLAINT;
        }
        return cat;
    }

    private static Set<Id> getCustomerIdsFromInteraction(Id interactionCaseId) {
        Set<Id> customerIds = new Set<Id>();
        for (Case c : [
            SELECT FEC_Account_or_Contract__c
            FROM Case
            WHERE FEC_Interaction__c = :interactionCaseId
            AND FEC_Account_or_Contract__c != null
        ]) {
            customerIds.add(c.FEC_Account_or_Contract__c);
        }
        return customerIds;
    }

    private static List<Case> getAllCasesForCustomers(Set<Id> customerIds) {
        if (customerIds == null || customerIds.isEmpty()) return new List<Case>();
        Set<String> cifNumbers = getCustomerCifNumbers(customerIds);
        String rtDevName = FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME;
        if (cifNumbers.isEmpty()) {
            return [
                SELECT FEC_Account_or_Contract__c, FEC_CIF_Number__c, FEC_Category__r.Name, FEC_Complain_Type__c,
                       FEC_SubCategory__r.FEC_Code__c, FEC_Case_Created_On__c, FEC_Case_Status__c, CreatedDate
                FROM Case
                WHERE RecordType.DeveloperName = :rtDevName
                AND FEC_Account_or_Contract__c IN :customerIds
            ];
        }
        return [
            SELECT FEC_Account_or_Contract__c, FEC_CIF_Number__c, FEC_Category__r.Name, FEC_Complain_Type__c,
                   FEC_SubCategory__r.FEC_Code__c, FEC_Case_Created_On__c, FEC_Case_Status__c, CreatedDate
            FROM Case
            WHERE RecordType.DeveloperName = :rtDevName
            AND (FEC_Account_or_Contract__c IN :customerIds OR FEC_CIF_Number__c IN :cifNumbers)
        ];
    }

    private static Set<Id> expandCustomerIdsBySameNameOrCif(Set<Id> customerIds) {
        if (customerIds == null || customerIds.isEmpty()) return new Set<Id>();
        Set<String> names = new Set<String>();
        Set<String> accountNumbers = new Set<String>();
        Set<String> cifNumbers = new Set<String>();
        for (FEC_Customer_History__c h : [
            SELECT Name, FEC_Account_Number__c, FEC_CIF_Number__c
            FROM FEC_Customer_History__c
            WHERE Id IN :customerIds
        ]) {
            if (String.isNotBlank(h.Name)) names.add(h.Name);
            if (String.isNotBlank(h.FEC_Account_Number__c)) accountNumbers.add(h.FEC_Account_Number__c);
            if (String.isNotBlank(h.FEC_CIF_Number__c)) cifNumbers.add(h.FEC_CIF_Number__c);
        }
        if (names.isEmpty() && accountNumbers.isEmpty() && cifNumbers.isEmpty()) return customerIds;
        Set<Id> expanded = new Set<Id>(customerIds);
        List<FEC_Customer_History__c> sameNameOrCif = queryHistoriesBySameNameAccountOrCif(customerIds, names, accountNumbers, cifNumbers);
        for (FEC_Customer_History__c h : sameNameOrCif) {
            expanded.add(h.Id);
        }
        return expanded;
    }

    private static List<FEC_Customer_History__c> queryHistoriesBySameNameAccountOrCif(Set<Id> customerIds, Set<String> names, Set<String> accountNumbers, Set<String> cifNumbers) {
        return [SELECT Id FROM FEC_Customer_History__c WHERE Id NOT IN :customerIds AND (Name IN :names OR FEC_Account_Number__c IN :accountNumbers OR FEC_CIF_Number__c IN :cifNumbers)];
    }

    private static Set<String> getCustomerCifNumbers(Set<Id> customerIds) {
        Set<String> cifNumbers = new Set<String>();
        if (customerIds == null || customerIds.isEmpty()) return cifNumbers;
        for (FEC_Customer_History__c h : [
            SELECT FEC_CIF_Number__c
            FROM FEC_Customer_History__c
            WHERE Id IN :customerIds
            AND FEC_CIF_Number__c != null
        ]) {
            cifNumbers.add(h.FEC_CIF_Number__c);
        }
        return cifNumbers;
    }

    private static String getCategoryFromUploadList(Case caseRecord) {
        AccountOrContractInfo info = getAccountOrContractInfo(caseRecord);
        String name = info.accountOrContractName;
        String cif = caseRecord != null ? caseRecord.FEC_CIF_Number__c : null;
        if (String.isBlank(name) && String.isBlank(cif)) return null;
        Datetime dt90 = Datetime.now().addDays(-90);
        List<FEC_Customer_Segmentation__c> segs;
        if (String.isNotBlank(name) && String.isNotBlank(cif)) {
            segs = [SELECT FEC_Customer_Segment__c, FEC_Survey_Points__c FROM FEC_Customer_Segmentation__c
                WHERE ( (Name = :name OR FEC_CIF_Number__c = :cif) AND FEC_Customer_Segment__c = :FEC_ConstantCommon.CUSTOMER_CATEGORY_VIP )
                    OR ( Name = :name AND CreatedDate >= :dt90 AND FEC_Survey_Points__c >= 1 AND FEC_Survey_Points__c <= 3 )
                ORDER BY CreatedDate DESC LIMIT 1];
        } else if (String.isNotBlank(name)) {
            segs = [SELECT FEC_Customer_Segment__c, FEC_Survey_Points__c FROM FEC_Customer_Segmentation__c
                WHERE ( Name = :name AND FEC_Customer_Segment__c = :FEC_ConstantCommon.CUSTOMER_CATEGORY_VIP )
                    OR ( Name = :name AND CreatedDate >= :dt90 AND FEC_Survey_Points__c >= 1 AND FEC_Survey_Points__c <= 3 )
                ORDER BY CreatedDate DESC LIMIT 1];
        } else {
            segs = [SELECT FEC_Customer_Segment__c, FEC_Survey_Points__c FROM FEC_Customer_Segmentation__c
                WHERE FEC_CIF_Number__c = :cif AND FEC_Customer_Segment__c = :FEC_ConstantCommon.CUSTOMER_CATEGORY_VIP
                ORDER BY CreatedDate DESC LIMIT 1];
        }
        if (segs.isEmpty()) return null;
        FEC_Customer_Segmentation__c s = segs[0];
        if (s.FEC_Customer_Segment__c == FEC_ConstantCommon.CUSTOMER_CATEGORY_VIP) return FEC_ConstantCommon.CUSTOMER_CATEGORY_VIP;
        if (s.FEC_Survey_Points__c >= 1 && s.FEC_Survey_Points__c <= 3) return FEC_ConstantCommon.CUSTOMER_CATEGORY_UNHAPPY;
        return null;
    }

    /** Bulk check VIP/Unhappy for many cases in 2 SOQL instead of 2*N. Use in determineFromCustomerIds to avoid governor limit. */
    private static String getCategoryFromUploadListBulk(List<Case> cases) {
        if (cases == null || cases.isEmpty()) return null;
        Set<Id> accountOrContractIds = new Set<Id>();
        Set<String> caseCifs = new Set<String>();
        for (Case c : cases) {
            if (c.FEC_Account_or_Contract__c != null) accountOrContractIds.add(c.FEC_Account_or_Contract__c);
            if (String.isNotBlank(c.FEC_CIF_Number__c)) caseCifs.add(c.FEC_CIF_Number__c);
        }
        Map<Id, AccountOrContractInfo> infoByAccountId = new Map<Id, AccountOrContractInfo>();
        Set<String> allNames = new Set<String>();
        Set<String> allCifs = new Set<String>(caseCifs);
        if (!accountOrContractIds.isEmpty()) {
            for (FEC_Customer_History__c h : [
                SELECT Id, Name, FEC_Account_Number__c, FEC_Contract_Number__c, FEC_CIF_Number__c
                FROM FEC_Customer_History__c
                WHERE Id IN :accountOrContractIds
            ]) {
                AccountOrContractInfo info = new AccountOrContractInfo();
                info.accountOrContractName = h.Name;
                info.cif = h.FEC_CIF_Number__c;
                info.names = new List<String>();
                if (String.isNotBlank(h.Name)) { info.names.add(h.Name); allNames.add(h.Name); }
                if (String.isNotBlank(h.FEC_CIF_Number__c)) allCifs.add(h.FEC_CIF_Number__c);
                if (String.isNotBlank(h.FEC_Account_Number__c) && !info.names.contains(h.FEC_Account_Number__c)) info.names.add(h.FEC_Account_Number__c);
                if (String.isNotBlank(h.FEC_Contract_Number__c) && !info.names.contains(h.FEC_Contract_Number__c)) info.names.add(h.FEC_Contract_Number__c);
                infoByAccountId.put(h.Id, info);
            }
        }
        if (allNames.isEmpty() && allCifs.isEmpty()) return null;
        Datetime dt90DaysAgo = Datetime.now().addDays(-90);
        List<FEC_Customer_Segmentation__c> segmentations = [
            SELECT Id, Name, FEC_CIF_Number__c, FEC_Customer_Segment__c, FEC_Survey_Points__c, CreatedDate
            FROM FEC_Customer_Segmentation__c
            WHERE (Name IN :allNames OR FEC_CIF_Number__c IN :allCifs)
            AND (
                (FEC_Customer_Segment__c = :FEC_ConstantCommon.CUSTOMER_CATEGORY_VIP)
                OR (CreatedDate >= :dt90DaysAgo AND FEC_Survey_Points__c >= 1 AND FEC_Survey_Points__c <= 3)
            )
            ORDER BY CreatedDate DESC
            LIMIT 500
        ];
        if (segmentations.isEmpty()) return null;
        for (Case c : cases) {
            String accountOrContractName = '';
            String caseCif = c.FEC_CIF_Number__c;
            if (c.FEC_Account_or_Contract__c != null && infoByAccountId.containsKey(c.FEC_Account_or_Contract__c)) {
                AccountOrContractInfo info = infoByAccountId.get(c.FEC_Account_or_Contract__c);
                accountOrContractName = info.accountOrContractName != null ? info.accountOrContractName : '';
                if (String.isBlank(caseCif)) caseCif = info.cif;
            }
            if (String.isBlank(accountOrContractName) && String.isBlank(caseCif)) continue;
            for (FEC_Customer_Segmentation__c seg : segmentations) {
                Boolean nameMatch = String.isNotBlank(accountOrContractName) && seg.Name == accountOrContractName;
                Boolean cifMatch = String.isNotBlank(caseCif) && seg.FEC_CIF_Number__c == caseCif;
                if (!nameMatch && !cifMatch) continue;
                if (seg.FEC_Customer_Segment__c == FEC_ConstantCommon.CUSTOMER_CATEGORY_VIP) return FEC_ConstantCommon.CUSTOMER_CATEGORY_VIP;
                if ((seg.FEC_Survey_Points__c >= 1 && seg.FEC_Survey_Points__c <= 3) && nameMatch) return FEC_ConstantCommon.CUSTOMER_CATEGORY_UNHAPPY;
                break;
            }
        }
        return null;
    }
    
    private static Boolean isSuspectedFraud(Case caseRecord) {
        if (caseRecord.FEC_Category__r?.Name != FEC_ConstantCommon.FEC_CATEGORY_COMPLAINT) return false;
        if (caseRecord.FEC_Complain_Type__c != FEC_ConstantCommon.FEC_COMPLAIN_TYPE_NORMAL && caseRecord.FEC_Complain_Type__c != FEC_ConstantCommon.FEC_COMPLAIN_TYPE_URGENT && caseRecord.FEC_Complain_Type__c != FEC_ConstantCommon.FEC_COMPLAIN_TYPE_HIGH_RISK) return false;
        String code = caseRecord.FEC_SubCategory__r?.FEC_Code__c;
        if (code != FEC_ConstantCommon.FEC_SUB_CATEGORY_CODE_CL01 && code != FEC_ConstantCommon.FEC_SUB_CATEGORY_CODE_CC01) return false;
        Date createdDate = getCaseCreatedDate(caseRecord);
        if (createdDate == null || createdDate < Date.today().addMonths(-6)) return false;
        return !isExcludedStatus(caseRecord.FEC_Case_Status__c);
    }
    
    private static Boolean isMedia(Case caseRecord) {
        if (caseRecord.FEC_Category__r?.Name != FEC_ConstantCommon.FEC_CATEGORY_COMPLAINT) return false;
        if (caseRecord.FEC_Complain_Type__c != FEC_ConstantCommon.FEC_COMPLAIN_TYPE_URGENT) return false;
        String code = caseRecord.FEC_SubCategory__r?.FEC_Code__c;
        if (code == FEC_ConstantCommon.FEC_SUB_CATEGORY_CODE_CL01 || code == FEC_ConstantCommon.FEC_SUB_CATEGORY_CODE_CC01) return false;
        Date createdDate = getCaseCreatedDate(caseRecord);
        if (createdDate == null || createdDate < Date.today().addMonths(-3)) return false;
        return !isExcludedStatus(caseRecord.FEC_Case_Status__c);
    }
    
    private static Boolean isSeriousComplaint(Case caseRecord) {
        if (caseRecord.FEC_Category__r?.Name != FEC_ConstantCommon.FEC_CATEGORY_COMPLAINT) return false;
        if (caseRecord.FEC_Complain_Type__c != FEC_ConstantCommon.FEC_COMPLAIN_TYPE_HIGH_RISK) return false;
        String code = caseRecord.FEC_SubCategory__r?.FEC_Code__c;
        if (code == FEC_ConstantCommon.FEC_SUB_CATEGORY_CODE_CL01 || code == FEC_ConstantCommon.FEC_SUB_CATEGORY_CODE_CC01) return false;
        Date createdDate = getCaseCreatedDate(caseRecord);
        if (createdDate == null || createdDate < Date.today().addMonths(-3)) return false;
        return !isExcludedStatus(caseRecord.FEC_Case_Status__c);
    }
    
    private static Date getCaseCreatedDate(Case caseRecord) {
        return caseRecord.FEC_Case_Created_On__c != null ? caseRecord.FEC_Case_Created_On__c.date() : null;
    }
    
    private static Boolean isExcludedStatus(String status) {
        if (String.isBlank(status)) return false;
        String s = status.trim();
        return s == FEC_ConstantCommon.CASE_STATUS_OPEN || s == FEC_ConstantCommon.CASE_STATUS_RESOLVED_CANCELLED || s == FEC_ConstantCommon.CASE_STATUS_AUTO_CANCELLED;
    }
    
    private static AccountOrContractInfo getAccountOrContractInfo(Case caseRecord) {
        AccountOrContractInfo info = new AccountOrContractInfo();
        info.names = new List<String>();
        if (caseRecord == null || caseRecord.FEC_Account_or_Contract__c == null) return info;
        List<FEC_Customer_History__c> histories = [
            SELECT Name, FEC_Account_Number__c, FEC_Contract_Number__c, FEC_CIF_Number__c
            FROM FEC_Customer_History__c
            WHERE Id = :caseRecord.FEC_Account_or_Contract__c
            LIMIT 1
        ];
        if (histories.isEmpty()) return info;
        FEC_Customer_History__c h = histories[0];
        info.accountOrContractName = h.Name;
        if (String.isNotBlank(h.Name)) info.names.add(h.Name);
        if (String.isNotBlank(h.FEC_Account_Number__c) && !info.names.contains(h.FEC_Account_Number__c)) info.names.add(h.FEC_Account_Number__c);
        if (String.isNotBlank(h.FEC_Contract_Number__c) && !info.names.contains(h.FEC_Contract_Number__c)) info.names.add(h.FEC_Contract_Number__c);
        info.cif = h.FEC_CIF_Number__c;
        return info;
    }
    
    @AuraEnabled
    public static void logSensitiveAccess(String fieldName, Id caseId) {
        try {
            User u = [
                SELECT Username, UserRole.Name
                FROM User
                WHERE Id = :UserInfo.getUserId()
                LIMIT 1
            ];
            
            FEC_CommonUltils.logSensitiveAccess(
                FEC_ConstantCommon.SECTION_CUSTOMER_INFORMATION,
                fieldName,
                u.Username.split('@')[0],
                u.UserRole != null ? u.UserRole.Name : null,
                caseId
            );
        } catch (Exception e) {
            System.debug('Error logging sensitive access: ' + e.getMessage());
        }
    }
    
    private class AccountOrContractInfo {
        List<String> names;
        String cif;
        String accountOrContractName;
    }

    public class InteractionHighlightData {
        @AuraEnabled public String interactionId;
        @AuraEnabled public String caseId;
        @AuraEnabled public String interactionIdSearch;
        @AuraEnabled public String customerCategory;
        @AuraEnabled public String customerName;
        @AuraEnabled public String nationalId;
        @AuraEnabled public String nationalIdMasked;
        @AuraEnabled public String gender;
        @AuraEnabled public Date dateOfBirth;
        @AuraEnabled public String primaryPhone;
        @AuraEnabled public String email;
        @AuraEnabled public String customerSegment;
        @AuraEnabled public String interactionStatus;
        @AuraEnabled public String interactionChannel;
        @AuraEnabled public String interactionSubStatus;
        @AuraEnabled public DateTime lastUpdatedOn;
        @AuraEnabled public String lastUpdatedBy;
    }
}
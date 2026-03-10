public with sharing class FEC_InteractionHighlightController {
    
    @AuraEnabled(cacheable=true)
    public static InteractionHighlightData getInteractionHighlightData(String caseId) {
        try {
            InteractionHighlightData result = new InteractionHighlightData();
            
            Case caseRecord = [
                SELECT 
                    Id,
                    RecordType.Name,
                    FEC_Interaction__c,
                    FEC_Interaction_ID__c,
                    FEC_ID_Search__c,
                    FEC_Interaction_Status__c,
                    FEC_Channel__c,
                    FEC_Interaction_Subchannel__c,
                    FEC_Last_Updated_On__c,
                    FEC_Last_Updated_By__c,
                    FEC_Account_or_Contract__c,
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
            if (caseRecord.RecordType.Name != FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME && caseRecord.FEC_Interaction__c != null) {
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
        if (caseRecord.RecordType.Name == FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME) {
            String uploadCategory = getCategoryFromUploadList(caseRecord);
            if (uploadCategory != null) return uploadCategory;
            return determineCustomerCategoryFromRelatedCases(caseRecord.Id);
        }
        if (caseRecord.FEC_Interaction__c != null) {
            return determineCustomerCategoryFromRelatedCases(caseRecord.FEC_Interaction__c);
        }
        String uploadCategory = getCategoryFromUploadList(caseRecord);
        if (uploadCategory != null) return uploadCategory;
        if (isSuspectedFraud(caseRecord)) return FEC_ConstantCommon.CUSTOMER_CATEGORY_SUSPECTED_FRAUD;
        if (isMedia(caseRecord)) return FEC_ConstantCommon.CUSTOMER_CATEGORY_MEDIA;
        if (isSeriousComplaint(caseRecord)) return FEC_ConstantCommon.CUSTOMER_CATEGORY_SERIOUS_COMPLAINT;
        return FEC_ConstantCommon.CUSTOMER_CATEGORY_NEUTRAL;
    }

    private static String determineCustomerCategoryFromRelatedCases(Id interactionCaseId) {
        Set<Id> customerIds = getCustomerIdsFromInteraction(interactionCaseId);
        if (customerIds.isEmpty()) return FEC_ConstantCommon.CUSTOMER_CATEGORY_NEUTRAL;
        List<Case> allCustomerCases = getAllCasesForCustomers(customerIds);
        for (Case c : allCustomerCases) {
            String uploadCategory = getCategoryFromUploadList(c);
            if (uploadCategory != null) return uploadCategory;
        }
        for (Case c : allCustomerCases) {
            if (isSuspectedFraud(c)) return FEC_ConstantCommon.CUSTOMER_CATEGORY_SUSPECTED_FRAUD;
        }
        for (Case c : allCustomerCases) {
            if (isMedia(c)) return FEC_ConstantCommon.CUSTOMER_CATEGORY_MEDIA;
        }
        for (Case c : allCustomerCases) {
            if (isSeriousComplaint(c)) return FEC_ConstantCommon.CUSTOMER_CATEGORY_SERIOUS_COMPLAINT;
        }
        return FEC_ConstantCommon.CUSTOMER_CATEGORY_NEUTRAL;
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
        return [
            SELECT FEC_Account_or_Contract__c, FEC_Category__r.Name, FEC_Complain_Type__c,
                   FEC_SubCategory__r.FEC_Code__c, FEC_Case_Created_On__c, FEC_Case_Status__c
            FROM Case
            WHERE FEC_Account_or_Contract__c IN :customerIds
        ];
    }

    private static String getCategoryFromUploadList(Case caseRecord) {
        AccountOrContractInfo info = getAccountOrContractInfo(caseRecord);
        if (String.isBlank(info.accountOrContractName) && String.isBlank(info.cif)) return null;
        List<FEC_Customer_Segmentation__c> segmentations;
        if (String.isBlank(info.accountOrContractName)) {
            segmentations = [
                SELECT Id, FEC_Customer_Segment__c, FEC_Survey_Points__c, CreatedDate
                FROM FEC_Customer_Segmentation__c
                WHERE FEC_CIF_Number__c = :info.cif
                AND (FEC_Customer_Segment__c = :FEC_ConstantCommon.CUSTOMER_CATEGORY_VIP OR (FEC_Survey_Points__c >= 1 AND FEC_Survey_Points__c <= 3))
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
        } else if (String.isBlank(info.cif)) {
            segmentations = [
                SELECT Id, FEC_Customer_Segment__c, FEC_Survey_Points__c, CreatedDate
                FROM FEC_Customer_Segmentation__c
                WHERE Name = :info.accountOrContractName
                AND (FEC_Customer_Segment__c = :FEC_ConstantCommon.CUSTOMER_CATEGORY_VIP OR (FEC_Survey_Points__c >= 1 AND FEC_Survey_Points__c <= 3))
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
        } else {
            segmentations = [
                SELECT Id, FEC_Customer_Segment__c, FEC_Survey_Points__c, CreatedDate
                FROM FEC_Customer_Segmentation__c
                WHERE (Name = :info.accountOrContractName OR FEC_CIF_Number__c = :info.cif)
                AND (FEC_Customer_Segment__c = :FEC_ConstantCommon.CUSTOMER_CATEGORY_VIP OR (FEC_Survey_Points__c >= 1 AND FEC_Survey_Points__c <= 3))
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
        }
        if (segmentations.isEmpty()) return null;
        FEC_Customer_Segmentation__c seg = segmentations[0];
        if (seg.FEC_Customer_Segment__c == FEC_ConstantCommon.CUSTOMER_CATEGORY_VIP) return FEC_ConstantCommon.CUSTOMER_CATEGORY_VIP;
        if (seg.FEC_Survey_Points__c >= 1 && seg.FEC_Survey_Points__c <= 3) return FEC_ConstantCommon.CUSTOMER_CATEGORY_UNHAPPY;
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
        if (caseRecord.FEC_Case_Created_On__c != null) {
            return caseRecord.FEC_Case_Created_On__c.date();
        }
        return null;
    }
    
    private static Boolean isExcludedStatus(String status) {
        if (String.isBlank(status)) return false;
        return status == FEC_ConstantCommon.CASE_STATUS_OPEN || status == FEC_ConstantCommon.CASE_STATUS_RESOLVED_CANCELLED || status == FEC_ConstantCommon.CASE_STATUS_AUTO_CANCELLED;
    }
    
    private static Boolean isUnhappy(Case caseRecord) {
        AccountOrContractInfo info = getAccountOrContractInfo(caseRecord);
        if (String.isBlank(info.accountOrContractName)) return false;
        List<FEC_Customer_Segmentation__c> segmentations = [
            SELECT Id
            FROM FEC_Customer_Segmentation__c
            WHERE Name = :info.accountOrContractName
            AND FEC_Survey_Points__c >= 1
            AND FEC_Survey_Points__c <= 3
            LIMIT 1
        ];
        return !segmentations.isEmpty();
    }

    private static Boolean isVIP(Case caseRecord) {
        AccountOrContractInfo info = getAccountOrContractInfo(caseRecord);
        if (String.isBlank(info.accountOrContractName) && String.isBlank(info.cif)) return false;
        List<FEC_Customer_Segmentation__c> segmentations;
        if (String.isBlank(info.accountOrContractName)) {
            segmentations = [
                SELECT Id
                FROM FEC_Customer_Segmentation__c
                WHERE FEC_CIF_Number__c = :info.cif
                AND FEC_Customer_Segment__c = :FEC_ConstantCommon.CUSTOMER_CATEGORY_VIP
                LIMIT 1
            ];
        } else if (String.isBlank(info.cif)) {
            segmentations = [
                SELECT Id
                FROM FEC_Customer_Segmentation__c
                WHERE Name = :info.accountOrContractName
                AND FEC_Customer_Segment__c = :FEC_ConstantCommon.CUSTOMER_CATEGORY_VIP
                LIMIT 1
            ];
        } else {
            segmentations = [
                SELECT Id
                FROM FEC_Customer_Segmentation__c
                WHERE (Name = :info.accountOrContractName OR FEC_CIF_Number__c = :info.cif)
                AND FEC_Customer_Segment__c = :FEC_ConstantCommon.CUSTOMER_CATEGORY_VIP
                LIMIT 1
            ];
        }
        return !segmentations.isEmpty();
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

    private static List<String> getAccountOrContractNamesToMatch(Case caseRecord) {
        List<String> namesToMatch = new List<String>();
        if (caseRecord == null || caseRecord.FEC_Account_or_Contract__c == null) return namesToMatch;
        List<FEC_Customer_History__c> histories = [
            SELECT Name, FEC_Account_Number__c, FEC_Contract_Number__c
            FROM FEC_Customer_History__c
            WHERE Id = :caseRecord.FEC_Account_or_Contract__c
            LIMIT 1
        ];
        if (histories.isEmpty()) return namesToMatch;
        FEC_Customer_History__c h = histories[0];
        if (String.isNotBlank(h.Name)) namesToMatch.add(h.Name);
        if (String.isNotBlank(h.FEC_Account_Number__c) && !namesToMatch.contains(h.FEC_Account_Number__c)) namesToMatch.add(h.FEC_Account_Number__c);
        if (String.isNotBlank(h.FEC_Contract_Number__c) && !namesToMatch.contains(h.FEC_Contract_Number__c)) namesToMatch.add(h.FEC_Contract_Number__c);
        return namesToMatch;
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
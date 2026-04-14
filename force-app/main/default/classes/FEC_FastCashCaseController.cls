public with sharing class FEC_FastCashCaseController {

    private static final Integer DEFAULT_FAST_CASH_TENURE = 1;

    public class CaseFastCashStateDTO {
        @AuraEnabled public Id actualNatureOfCaseId;
        @AuraEnabled public Decimal requestedAmount;
        @AuraEnabled public Decimal maxAmount;
        @AuraEnabled public String applicationId;
    }

    public class FastCashEligibilityDTO {
        @AuraEnabled public Boolean callCompleted;
        @AuraEnabled public String fastCashStatus;
        @AuraEnabled public String errorCode;
        @AuraEnabled public String errorDescription;
        @AuraEnabled public Decimal maxAmount;
        @AuraEnabled public String technicalMessage;
    }

    public class SaveFastCashResultDTO {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String errorMessage;
    }

    public class BlockResultDTO {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String sysCode;
        @AuraEnabled public String sysDescription;
        @AuraEnabled public String errorMessage;
    }

    /**
     * Đọc trạng thái Fast Cash trên Case (NOC, số tiền, Application ID).
     */
    @AuraEnabled(cacheable=false)
    public static CaseFastCashStateDTO getCaseFastCashState(Id caseId) {
        CaseFastCashStateDTO dto = new CaseFastCashStateDTO();
        if (caseId == null || !Schema.sObjectType.Case.isAccessible()) {
            return dto;
        }
        List<Case> rows = [
            SELECT FEC_Actual_Nature_of_Case__c,
                FEC_Requested_Amount__c,
                FEC_Max_Amount__c,
                FEC_Application_ID__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        rows = (List<Case>) Security.stripInaccessible(AccessType.READABLE, rows).getRecords();
        if (rows.isEmpty()) {
            return dto;
        }
        Case c = rows[0];
        dto.actualNatureOfCaseId = c.FEC_Actual_Nature_of_Case__c;
        dto.requestedAmount = c.FEC_Requested_Amount__c;
        dto.maxAmount = c.FEC_Max_Amount__c;
        dto.applicationId = c.FEC_Application_ID__c;
        return dto;
    }

    /**
     * Kiểm tra điều kiện Fast Cash / hạn mức tối đa — cùng luồng dữ liệu thẻ với GetCardSecInfo (C360 / Card).
     */
    @AuraEnabled(cacheable=false)
    public static FastCashEligibilityDTO checkFastCashEligibility(Id caseId) {
        FastCashEligibilityDTO outDto = new FastCashEligibilityDTO();
        outDto.callCompleted = false;
        if (caseId == null) {
            outDto.technicalMessage = String.format(
                System.Label.FEC_MSG_Param_Required,
                new List<String>{ 'Case Id' }
            );
            return outDto;
        }
        if (!Schema.sObjectType.Case.isAccessible()) {
            outDto.technicalMessage = System.Label.FEC_MSG_Insufficient_Access;
            return outDto;
        }
        List<Case> caseRows = queryCaseForFastCash(caseId);
        caseRows = (List<Case>) Security.stripInaccessible(AccessType.READABLE, caseRows).getRecords();
        if (caseRows.isEmpty()) {
            outDto.technicalMessage = String.format(System.Label.FEC_MSG_Not_Found, new List<String>{ 'Case' });
            return outDto;
        }
        Case c = caseRows[0];
        String productTypeName = c.FEC_Product_Type__c != null ? c.FEC_Product_Type__r.Name : null;
        String accountNumber = FEC_CommonUltils.resolveAccountNumber(
            productTypeName,
            c.FEC_Account_or_Contract__r != null ? c.FEC_Account_or_Contract__r.FEC_Account_Number__c : null,
            c.FEC_Account_or_Contract__r != null ? c.FEC_Account_or_Contract__r.FEC_Contract_Number__c : null
        );
        if (String.isBlank(accountNumber)) {
            accountNumber = c.FEC_Account_Number__c;
        }
        if (String.isBlank(accountNumber)) {
            outDto.fastCashStatus = System.Label.FEC_LBL_Fast_Cash_Status_Not_Eligible;
            outDto.errorCode = 'NO_ACCOUNT';
            outDto.errorDescription = System.Label.FEC_MSG_AccountNumber_Invalid;
            outDto.callCompleted = true;
            return outDto;
        }
        FEC_GetCardSecInfo.ResponseWrapper sec;
        try {
            sec = FEC_GetCardSecInfo.getCardSecInfo(accountNumber);
        } catch (Exception e) {
            outDto.fastCashStatus = System.Label.FEC_LBL_Fast_Cash_Status_Not_Eligible;
            outDto.errorCode = 'API';
            outDto.errorDescription = e.getMessage();
            outDto.callCompleted = true;
            return outDto;
        }
        Decimal remainingCash = null;
        if (sec != null
            && sec.CardSecInfo != null
            && sec.CardSecInfo.MainCardBalance != null) {
            remainingCash = sec.CardSecInfo.MainCardBalance.RemainingCashLimit;
        }
        if (remainingCash != null && remainingCash > 0) {
            outDto.fastCashStatus = System.Label.FEC_LBL_Fast_Cash_Status_Eligible;
            outDto.maxAmount = remainingCash;
        } else {
            outDto.fastCashStatus = System.Label.FEC_LBL_Fast_Cash_Status_Not_Eligible;
            outDto.errorCode = 'LIMIT';
            outDto.errorDescription = System.Label.FEC_MSG_API_Error;
        }
        outDto.callCompleted = true;
        return outDto;
    }

    @AuraEnabled
    public static SaveFastCashResultDTO saveFastCashCaseAmounts(Id caseId, Decimal requestedAmount, Decimal maxAmount) {
        SaveFastCashResultDTO res = new SaveFastCashResultDTO();
        res.success = false;
        if (caseId == null) {
            res.errorMessage = String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'Case Id' });
            return res;
        }
        if (!Schema.sObjectType.Case.isUpdateable()) {
            res.errorMessage = System.Label.FEC_MSG_Insufficient_Access;
            return res;
        }
        Case toUpd = new Case(Id = caseId);
        if (requestedAmount != null) {
            toUpd.FEC_Requested_Amount__c = requestedAmount;
        }
        if (maxAmount != null) {
            toUpd.FEC_Max_Amount__c = maxAmount;
        }
        SObjectAccessDecision dec = Security.stripInaccessible(AccessType.UPDATABLE, new List<SObject>{ toUpd });
        List<SObject> safe = dec.getRecords();
        if (safe.isEmpty()) {
            res.errorMessage = System.Label.FEC_MSG_Insufficient_Access;
            return res;
        }
        try {
            update safe;
        } catch (Exception e) {
            res.errorMessage = System.Label.FEC_Unknown_Error;
            return res;
        }
        res.success = true;
        return res;
    }

    @AuraEnabled
    public static BlockResultDTO executeFastCashBlock(Id caseId, Decimal blockAmount) {
        BlockResultDTO res = new BlockResultDTO();
        res.success = false;
        if (caseId == null || blockAmount == null) {
            res.errorMessage = String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'Case / Amount' });
            return res;
        }
        if (!Schema.sObjectType.Case.isAccessible()) {
            res.errorMessage = System.Label.FEC_MSG_Insufficient_Access;
            return res;
        }
        List<Case> caseRows = queryCaseForFastCash(caseId);
        caseRows = (List<Case>) Security.stripInaccessible(AccessType.READABLE, caseRows).getRecords();
        if (caseRows.isEmpty()) {
            res.errorMessage = String.format(System.Label.FEC_MSG_Not_Found, new List<String>{ 'Case' });
            return res;
        }
        Case c = caseRows[0];
        String productTypeName = c.FEC_Product_Type__c != null ? c.FEC_Product_Type__r.Name : null;
        String accountNumber = FEC_CommonUltils.resolveAccountNumber(
            productTypeName,
            c.FEC_Account_or_Contract__r != null ? c.FEC_Account_or_Contract__r.FEC_Account_Number__c : null,
            c.FEC_Account_or_Contract__r != null ? c.FEC_Account_or_Contract__r.FEC_Contract_Number__c : null
        );
        if (String.isBlank(accountNumber)) {
            accountNumber = c.FEC_Account_Number__c;
        }
        if (String.isBlank(accountNumber)) {
            res.errorMessage = System.Label.FEC_MSG_AccountNumber_Invalid;
            return res;
        }
        String crmId = resolveApplicationIdForCase(c, accountNumber);
        if (String.isBlank(crmId)) {
            res.errorMessage = String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'Application Id' });
            return res;
        }
        String disbChannel = resolveDisbursementChannel(crmId);
        if (String.isBlank(disbChannel)) {
            disbChannel = FEC_ConstantCommon.PRODUCT_TYPE_CARD;
        }
        FEC_CMSIPPBlockWS.ResponseWrapper apiRes;
        try {
            apiRes = FEC_CMSIPPBlockWS.cmsIPPBlockWS(
                FEC_ConstantCommon.REQUESTOR_CRM,
                crmId,
                disbChannel,
                accountNumber,
                blockAmount,
                DEFAULT_FAST_CASH_TENURE,
                true,
                '',
                0,
                '',
                '',
                '',
                0,
                0,
                ''
            );
        } catch (Exception e) {
            res.errorMessage = System.Label.FEC_Unknown_Error;
            return res;
        }
        if (apiRes == null || apiRes.Sys == null) {
            res.errorMessage = System.Label.FEC_MSG_Response_Null;
            return res;
        }
        res.sysCode = apiRes.Sys.Code;
        res.sysDescription = apiRes.Sys.Description;
        if (isCmsBlockBusinessSuccess(apiRes)) {
            res.success = true;
            saveFastCashCaseAmounts(caseId, blockAmount, c.FEC_Max_Amount__c);
        } else {
            res.errorMessage = String.isNotBlank(apiRes.Sys.Description)
                ? apiRes.Sys.Description
                : System.Label.FEC_Unknown_Error;
        }
        return res;
    }

    private static List<Case> queryCaseForFastCash(Id caseId) {
        return [
            SELECT Id,
                FEC_Account_Number__c,
                FEC_Application_ID__c,
                FEC_Max_Amount__c,
                FEC_Account_or_Contract__r.FEC_Account_Number__c,
                FEC_Account_or_Contract__r.FEC_Contract_Number__c,
                FEC_Product_Type__r.Name
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
    }

    private static String resolveApplicationIdForCase(Case c, String accountNumber) {
        if (c == null) {
            return null;
        }
        if (String.isNotBlank(c.FEC_Application_ID__c)) {
            return c.FEC_Application_ID__c.trim();
        }
        if (String.isBlank(accountNumber)) {
            return null;
        }
        if (!Pattern.matches(FEC_ConstantCommon.PATTERN_ACCOUNT_NUMBER, accountNumber)) {
            return null;
        }
        try {
            FEC_GetCustomerList.ResponseWrapper response = FEC_GetCustomerList.getCustomerList(
                FEC_ConstantCommon.REQUESTOR_CRM,
                null,
                false,
                null,
                null,
                null,
                null,
                accountNumber,
                null,
                null,
                null
            );
            if (response != null
                && response.Sys != null
                && '1'.equals(response.Sys.Code)
                && response.Customers != null
                && !response.Customers.isEmpty()) {
                FEC_GetCustomerList.Customer customer = response.Customers[0];
                if (customer.Applications != null && !customer.Applications.isEmpty()) {
                    return customer.Applications[0].ApplicationID;
                }
            }
        } catch (Exception e) {
            return null;
        }
        return null;
    }

    private static String resolveDisbursementChannel(String applicationId) {
        if (String.isBlank(applicationId)) {
            return null;
        }
        try {
            FEC_GetCustomerSaleDisburseInfoCallout.CustomerSaleDisburseInfoResponse saleRes =
                FEC_GetCustomerSaleDisburseInfoCallout.getCustomerSaleDisburseInfo(applicationId);
            if (saleRes != null
                && saleRes.CustomerSaleInfos != null
                && !saleRes.CustomerSaleInfos.isEmpty()) {
                String ch = saleRes.CustomerSaleInfos[0].DISB_CHANNEL;
                return String.isNotBlank(ch) ? ch.trim() : null;
            }
        } catch (Exception e) {
            return null;
        }
        return null;
    }

    private static Boolean isCmsBlockBusinessSuccess(FEC_CMSIPPBlockWS.ResponseWrapper w) {
        if (w == null || w.Sys == null || String.isBlank(w.Sys.Code)) {
            return false;
        }
        String c = w.Sys.Code.trim();
        return '0'.equals(c) || '1'.equals(c);
    }
}
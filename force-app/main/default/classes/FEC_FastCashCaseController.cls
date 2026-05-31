public without sharing class FEC_FastCashCaseController {

    // 29/05/2026 14:00 linhdev - CMSIPPBlockWS spec: Tenure=0, DisbChannel=PC, NO_IPP=true, CampaignName=TMN, FlatRate=0
    // 31/05/2026 linhdev - RequestorID PEGA-CSM theo payload integration CMSIPPBlock success
    private static final Integer DEFAULT_FAST_CASH_TENURE = 0;
    private static final String DEFAULT_CMS_IPP_DISB_CHANNEL = 'PC';
    private static final String DEFAULT_CMS_IPP_CAMPAIGN_NAME = 'TMN';
    private static final String DEFAULT_CMS_IPP_REQUESTOR_ID = FEC_ConstantCommon.REQUESTOR_PEGA_CSM_LEGACY;

    public class CaseFastCashStateDTO {
        @AuraEnabled public Id actualNatureOfCaseId;
        @AuraEnabled public Decimal requestedAmount;
        @AuraEnabled public Decimal maxAmount;
        @AuraEnabled public String applicationId;
        @AuraEnabled public String disbursementStatus;
        @AuraEnabled public Date disbursementDate;
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

    public class FastCashBlockContextDTO {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String crmId;
        @AuraEnabled public String disbChannel;
        @AuraEnabled public String errorMessage;
    }

    @AuraEnabled(cacheable=false)
    public static CaseFastCashStateDTO getCaseFastCashState(Id caseId) {
        CaseFastCashStateDTO dto = new CaseFastCashStateDTO();
        if (caseId == null) {
            return dto;
        }
        List<Case> rows = [
            SELECT FEC_Actual_Nature_of_Case__c,
                FEC_Requested_Amount__c,
                FEC_Max_Amount__c,
                FEC_Application_ID__c,
                FEC_Disbursement_Status__c,
                FEC_Disbursement_Date__c,
                FEC_Account_or_Contract__r.FEC_Disbursement_Date__c,
                (
                    SELECT FEC_PD_Disbursement_Status__c
                    FROM Pending_Disbursements__r
                    LIMIT 1
                )
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        if (rows.isEmpty()) {
            return dto;
        }
        Case c = rows[0];
        dto.actualNatureOfCaseId = c.FEC_Actual_Nature_of_Case__c;
        dto.requestedAmount = c.FEC_Requested_Amount__c;
        dto.maxAmount = c.FEC_Max_Amount__c;
        dto.applicationId = c.FEC_Application_ID__c;
        dto.disbursementStatus = resolveDisbursementStatusForCase(c);
        dto.disbursementDate = resolveDisbursementDateForCase(c);
        return dto;
    }

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
        List<Case> caseRows = queryCaseForFastCash(caseId);
        if (caseRows.isEmpty()) {
            outDto.technicalMessage = String.format(System.Label.FEC_MSG_Not_Found, new List<String>{ 'Case' });
            return outDto;
        }
        Case c = caseRows[0];
        String accountNumber = resolveAccountNumberForCase(c);
        if (String.isBlank(accountNumber)) {
            return notEligibleNoAccount(outDto);
        }
        FEC_CheckEligibilityIPPCallout.CheckEligibilityResult ipp =
            FEC_CheckEligibilityIPPCallout.checkAccountEligibility(accountNumber);
        if (!ipp.success) {
            return notEligibleFromIppFailure(outDto, ipp);
        }
        if (!isAccEligibilityTrue(ipp.accEligibility)) {
            outDto.callCompleted = true;
            outDto.fastCashStatus = System.Label.FEC_LBL_Fast_Cash_Status_Not_Eligible;
            outDto.errorCode = String.isNotBlank(ipp.code) ? ipp.code : '';
            outDto.errorDescription = resolveIppUserDescription(ipp);
            return outDto;
        }
        return loadMaxFromCardSecAndFinish(outDto, accountNumber);
    }

    @AuraEnabled
    public static SaveFastCashResultDTO saveFastCashCaseAmounts(Id caseId, Decimal requestedAmount, Decimal maxAmount) {
        SaveFastCashResultDTO res = new SaveFastCashResultDTO();
        res.success = false;
        if (caseId == null) {
            res.errorMessage = String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'Case Id' });
            return res;
        }
        Case toUpd = new Case(Id = caseId);
        if (requestedAmount != null) {
            toUpd.FEC_Requested_Amount__c = requestedAmount;
        }
        if (maxAmount != null) {
            toUpd.FEC_Max_Amount__c = maxAmount;
        }
        try {
            update toUpd;
        } catch (Exception e) {
            res.errorMessage = System.Label.FEC_Unknown_Error;
            return res;
        }
        res.success = true;
        return res;
    }

    @AuraEnabled
    public static SaveFastCashResultDTO finalizeFastCashOnSubmit(Id caseId, Decimal requestedAmount, Decimal maxAmount) {
        SaveFastCashResultDTO res = saveFastCashCaseAmounts(caseId, requestedAmount, maxAmount);
        if (!res.success) {
            return res;
        }
        if (caseId == null) {
            return res;
        }
        List<Case> rows = [
            SELECT Id,
                FEC_Application_ID__c,
                FEC_SubCategory__r.FEC_Code__c,
                (
                    SELECT Id, FEC_PD_Disbursement_Status__c
                    FROM Pending_Disbursements__r
                    LIMIT 1
                )
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        if (rows.isEmpty()) {
            return res;
        }
        Case c = rows[0];
        if (!isFastCashRc35Case(c)) {
            return res;
        }
        try {
            applyDefaultPendingDisbursementStatusOnSubmit(c);
        } catch (Exception e) {
            res.success = false;
            res.errorMessage = System.Label.FEC_Unknown_Error;
        }
        return res;
    }

    @AuraEnabled
    public static FastCashBlockContextDTO prepareFastCashBlockContext(Id caseId) {
        FastCashBlockContextDTO ctx = new FastCashBlockContextDTO();
        ctx.success = false;
        if (caseId == null) {
            ctx.errorMessage = String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'Case Id' });
            return ctx;
        }
        List<Case> caseRows = queryCaseForFastCash(caseId);
        if (caseRows.isEmpty()) {
            ctx.errorMessage = String.format(System.Label.FEC_MSG_Not_Found, new List<String>{ 'Case' });
            return ctx;
        }
        Case c = caseRows[0];
        // 29/05/2026 14:00 linhdev - CrmID: số từ FEC_ID_Search__c (Case.FEC_Case_ID__c); Account: FEC_Account_Contract_Number_Text__c
        String crmId = resolveCrmIdForCmsIppBlock(c);
        if (String.isBlank(crmId)) {
            ctx.errorMessage = String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'Case ID' });
            return ctx;
        }
        String accountNumber = resolveAccountForCmsIppBlock(c);
        if (String.isBlank(accountNumber)) {
            ctx.errorMessage = System.Label.FEC_MSG_AccountNumber_Invalid;
            return ctx;
        }
        ctx.crmId = crmId;
        ctx.disbChannel = DEFAULT_CMS_IPP_DISB_CHANNEL;
        ctx.success = true;
        return ctx;
    }

    @AuraEnabled
    public static BlockResultDTO executeFastCashBlock(
        Id caseId,
        Decimal blockAmount,
        String crmId,
        String disbChannel
    ) {
        BlockResultDTO res = new BlockResultDTO();
        res.success = false;
        Case c;
        try {
            if (caseId == null) {
                res.errorMessage = String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'Case Id' });
                return res;
            }
            List<Case> caseRows = queryCaseForFastCash(caseId);
            if (caseRows.isEmpty()) {
                res.errorMessage = String.format(System.Label.FEC_MSG_Not_Found, new List<String>{ 'Case' });
                return res;
            }
            c = caseRows[0];
            // 29/05/2026 14:00 linhdev - map payload CMSIPPBlockWS theo spec (Case fields + default PC/TMN/0)
            String crmIdForApi = resolveCrmIdForCmsIppBlock(c);
            if (String.isBlank(crmIdForApi)) {
                res.errorMessage = String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'Case ID' });
                return res;
            }
            String accountNumber = resolveAccountForCmsIppBlock(c);
            if (String.isBlank(accountNumber)) {
                res.errorMessage = System.Label.FEC_MSG_AccountNumber_Invalid;
                return res;
            }
            Decimal amountForApi = resolveBlockAmountForCmsIppBlock(c, blockAmount);
            if (amountForApi == null) {
                res.errorMessage = String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'Amount' });
                return res;
            }
            FEC_CMSIPPBlockWS.ResponseWrapper apiRes;
            try {
                apiRes = FEC_CMSIPPBlockWS.cmsIPPBlockWS(
                    DEFAULT_CMS_IPP_REQUESTOR_ID,
                    crmIdForApi,
                    DEFAULT_CMS_IPP_DISB_CHANNEL,
                    accountNumber,
                    amountForApi,
                    DEFAULT_FAST_CASH_TENURE,
                    true,
                    DEFAULT_CMS_IPP_CAMPAIGN_NAME,
                    0,
                    '',
                    '',
                    '',
                    0,
                    0,
                    ''
                );
            } catch (Exception e) {
                FEC_CommonUltils.logApi(
                    'FEC_CMS_IPP_BlockWS',
                    null,
                    FEC_ConstantCommon.API_METHOD_POST,
                    null,
                    null,
                    e.getMessage()
                );
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
                saveFastCashCaseAmounts(caseId, amountForApi, c.FEC_Max_Amount__c);
            } else {
                res.errorMessage = String.isNotBlank(apiRes.Sys.Description)
                    ? apiRes.Sys.Description
                    : System.Label.FEC_Unknown_Error;
            }
            return res;
        } finally {
            if (c != null) {
                FEC_CommonUltils.createProcessActionHistory(
                    FEC_CMSIPPBlockWS.API_CONFIG_NAME,
                    c,
                    res.success == true
                );
            }
        }
    }

    private static FastCashEligibilityDTO notEligibleNoAccount(FastCashEligibilityDTO outDto) {
        outDto.callCompleted = true;
        outDto.fastCashStatus = System.Label.FEC_LBL_Fast_Cash_Status_Not_Eligible;
        outDto.errorCode = 'NO_ACCOUNT';
        outDto.errorDescription = System.Label.FEC_MSG_AccountNumber_Invalid;
        return outDto;
    }

    private static FastCashEligibilityDTO notEligibleFromIppFailure(
        FastCashEligibilityDTO outDto,
        FEC_CheckEligibilityIPPCallout.CheckEligibilityResult ipp
    ) {
        outDto.callCompleted = true;
        outDto.fastCashStatus = System.Label.FEC_LBL_Fast_Cash_Status_Not_Eligible;
        outDto.errorCode = String.isNotBlank(ipp.code) ? ipp.code : 'API';
        outDto.errorDescription = resolveIppUserDescription(ipp);
        return outDto;
    }

    private static String resolveIppUserDescription(FEC_CheckEligibilityIPPCallout.CheckEligibilityResult ipp) {
        if (String.isNotBlank(ipp.description)) {
            return ipp.description;
        }
        if (String.isNotBlank(ipp.errorMessage)) {
            return ipp.errorMessage;
        }
        return System.Label.FEC_MSG_API_Error;
    }

    private static Boolean isAccEligibilityTrue(String accEligibility) {
        if (String.isBlank(accEligibility)) {
            return false;
        }
        String e = accEligibility.trim();
        return 'true'.equalsIgnoreCase(e) || 'eligible'.equalsIgnoreCase(e) || '1'.equals(e);
    }

    private static FastCashEligibilityDTO loadMaxFromCardSecAndFinish(FastCashEligibilityDTO outDto, String accountNumber) {
        FEC_GetCardSecInfo.ResponseWrapper sec;
        try {
            sec = FEC_GetCardSecInfo.getCardSecInfo(accountNumber);
        } catch (Exception e) {
            outDto.callCompleted = true;
            outDto.fastCashStatus = System.Label.FEC_LBL_Fast_Cash_Status_Not_Eligible;
            outDto.errorCode = 'CARD_SEC';
            outDto.errorDescription = System.Label.FEC_MSG_API_Error;
            return outDto;
        }
        Decimal remainingCash = null;
        if (sec != null
            && sec.CardSecInfo != null
            && sec.CardSecInfo.MainCardBalance != null) {
            remainingCash = sec.CardSecInfo.MainCardBalance.RemainingCashLimit;
        }
        if (remainingCash != null && remainingCash > 0) {
            outDto.callCompleted = true;
            outDto.fastCashStatus = System.Label.FEC_LBL_Fast_Cash_Status_Eligible;
            outDto.maxAmount = remainingCash;
        } else {
            outDto.callCompleted = true;
            outDto.fastCashStatus = System.Label.FEC_LBL_Fast_Cash_Status_Not_Eligible;
            outDto.errorCode = 'LIMIT';
            outDto.errorDescription = System.Label.FEC_MSG_API_Error;
        }
        return outDto;
    }

    private static String resolveAccountNumberForCase(Case c) {
        if (c == null) {
            return null;
        }
        String productTypeName = c.FEC_Product_Type__c != null ? c.FEC_Product_Type__r.Name : null;
        String accountNumber = FEC_CommonUltils.resolveAccountNumber(
            productTypeName,
            c.FEC_Account_or_Contract__r != null ? c.FEC_Account_or_Contract__r.FEC_Account_Number__c : null,
            c.FEC_Account_or_Contract__r != null ? c.FEC_Account_or_Contract__r.FEC_Contract_Number__c : null
        );
        if (String.isBlank(accountNumber)) {
            accountNumber = c.FEC_Account_Number__c;
        }
        return accountNumber;
    }

    // 29/05/2026 14:00 linhdev - CrmID: lấy phần số sau prefix trong FEC_ID_Search__c (vd S-1651 → 1651)
    @TestVisible
    private static String resolveCrmIdForCmsIppBlock(Case c) {
        if (c == null || String.isBlank(c.FEC_ID_Search__c)) {
            return null;
        }
        String idSearch = c.FEC_ID_Search__c.trim();
        if (idSearch.contains(FEC_ConstantCommon.FEC_ID_SEARCH_DELIMITER)) {
            String numberPart = idSearch.substringAfterLast(FEC_ConstantCommon.FEC_ID_SEARCH_DELIMITER);
            return String.isNotBlank(numberPart) ? numberPart.trim() : null;
        }
        return idSearch;
    }

    // 29/05/2026 14:00 linhdev - Account: Case.FEC_Account_Contract_Number_Text__c (16/19 số)
    @TestVisible
    private static String resolveAccountForCmsIppBlock(Case c) {
        if (c == null || String.isBlank(c.FEC_Account_Contract_Number_Text__c)) {
            return null;
        }
        String raw = c.FEC_Account_Contract_Number_Text__c.trim();
        if (!Pattern.matches(FEC_ConstantCommon.PATTERN_ACCOUNT_NUMBER, raw)) {
            return null;
        }
        return raw;
    }

    // 29/05/2026 14:00 linhdev - Amount: Case.FEC_Requested_Amount__c (spec Fast Cash Requested Amount), fallback UI
    @TestVisible
    private static Decimal resolveBlockAmountForCmsIppBlock(Case c, Decimal blockAmountFromUi) {
        if (c != null && c.FEC_Requested_Amount__c != null) {
            return c.FEC_Requested_Amount__c;
        }
        return blockAmountFromUi;
    }

    private static List<Case> queryCaseForFastCash(Id caseId) {
        return [
            SELECT Id,
                FEC_Account_Number__c,
                FEC_Application_ID__c,
                FEC_Max_Amount__c,
                FEC_Requested_Amount__c,
                FEC_ID_Search__c,
                FEC_Account_Contract_Number_Text__c,
                FEC_Current_Case_Stage__c,
                FEC_Current_Case_Stage__r.Name,
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
        return '0'.equals(c) || '1'.equals(c) || '4'.equals(c);
    }

    private static Boolean isFastCashRc35Case(Case c) {
        if (c == null || c.FEC_SubCategory__r == null) {
            return false;
        }
        String code = c.FEC_SubCategory__r.FEC_Code__c;
        return FEC_ConstantCommon.FAST_CASH_SUB_CATEGORY_CODE_RC35.equalsIgnoreCase(
            String.isBlank(code) ? '' : code.trim()
        );
    }

    private static String resolveDisbursementStatusForCase(Case c) {
        if (c == null) {
            return null;
        }
        if (c.Pending_Disbursements__r != null && !c.Pending_Disbursements__r.isEmpty()) {
            String fromPending = c.Pending_Disbursements__r[0].FEC_PD_Disbursement_Status__c;
            if (String.isNotBlank(fromPending)) {
                return mapDisbursementStatusForDisplay(fromPending);
            }
        }
        return mapDisbursementStatusForDisplay(c.FEC_Disbursement_Status__c);
    }

    private static Date resolveDisbursementDateForCase(Case c) {
        if (c == null) {
            return null;
        }
        if (c.FEC_Account_or_Contract__r != null
            && c.FEC_Account_or_Contract__r.FEC_Disbursement_Date__c != null) {
            return c.FEC_Account_or_Contract__r.FEC_Disbursement_Date__c;
        }
        return c.FEC_Disbursement_Date__c;
    }

    private static void applyDefaultPendingDisbursementStatusOnSubmit(Case c) {
        if (c == null || c.Id == null) {
            return;
        }
        if (c.Pending_Disbursements__r != null
            && !c.Pending_Disbursements__r.isEmpty()
            && String.isNotBlank(c.Pending_Disbursements__r[0].FEC_PD_Disbursement_Status__c)) {
            return;
        }
        upsertPendingDisbursementStatus(
            c.Id,
            FEC_ConstantCommon.FAST_CASH_DISB_STATUS_PENDING_CUSTOMER_WITHDRAWAL,
            c.FEC_Application_ID__c
        );
    }

    public static void upsertPendingDisbursementStatus(Id caseId, String status, String applicationId) {
        if (caseId == null || String.isBlank(status)) {
            return;
        }
        if (!Schema.sObjectType.FEC_Pending_Disbursement__c.isAccessible()) {
            return;
        }
        List<FEC_Pending_Disbursement__c> rows = [
            SELECT Id, FEC_PD_Disbursement_Status__c
            FROM FEC_Pending_Disbursement__c
            WHERE FEC_Case__c = :caseId
            LIMIT 1
        ];
        if (!rows.isEmpty()) {
            if (!Schema.sObjectType.FEC_Pending_Disbursement__c.isUpdateable()) {
                return;
            }
            FEC_Pending_Disbursement__c upd = new FEC_Pending_Disbursement__c(
                Id = rows[0].Id,
                FEC_PD_Disbursement_Status__c = status
            );
            List<FEC_Pending_Disbursement__c> safeUpd = (List<FEC_Pending_Disbursement__c>) Security.stripInaccessible(
                AccessType.UPDATABLE,
                new List<FEC_Pending_Disbursement__c>{ upd }
            ).getRecords();
            if (!safeUpd.isEmpty()) {
                update safeUpd;
            }
            return;
        }
        if (!Schema.sObjectType.FEC_Pending_Disbursement__c.isCreateable()) {
            return;
        }
        FEC_Pending_Disbursement__c ins = new FEC_Pending_Disbursement__c(
            FEC_Case__c = caseId,
            FEC_PD_Disbursement_Status__c = status
        );
        if (String.isNotBlank(applicationId)) {
            ins.FEC_PD_Application_ID__c = applicationId;
        }
        List<FEC_Pending_Disbursement__c> safeIns = (List<FEC_Pending_Disbursement__c>) Security.stripInaccessible(
            AccessType.CREATABLE,
            new List<FEC_Pending_Disbursement__c>{ ins }
        ).getRecords();
        if (!safeIns.isEmpty()) {
            insert safeIns;
        }
    }

    public static void updateCustomerHistoryDisbursementDate(Id historyId, Date disbDate) {
        if (historyId == null || disbDate == null) {
            return;
        }
        if (!Schema.sObjectType.FEC_Customer_History__c.isUpdateable()) {
            return;
        }
        FEC_Customer_History__c upd = new FEC_Customer_History__c(
            Id = historyId,
            FEC_Disbursement_Date__c = disbDate
        );
        List<FEC_Customer_History__c> safeUpd = (List<FEC_Customer_History__c>) Security.stripInaccessible(
            AccessType.UPDATABLE,
            new List<FEC_Customer_History__c>{ upd }
        ).getRecords();
        if (!safeUpd.isEmpty()) {
            update safeUpd;
        }
    }

    public static String mapDisbursementStatusForDisplay(String storedStatus) {
        if (String.isBlank(storedStatus)) {
            return storedStatus;
        }
        String s = storedStatus.trim();
        if (FEC_ConstantCommon.DISB_API_STATUS_WITHDRAWN.equalsIgnoreCase(s)) {
            return FEC_ConstantCommon.FAST_CASH_DISB_STATUS_SUCCESS;
        }
        if (FEC_ConstantCommon.DISB_API_STATUS_CANCELLED_BY_CUSTOMER.equalsIgnoreCase(s)) {
            return FEC_ConstantCommon.FAST_CASH_DISB_STATUS_RESOLVED_CUSTOMER_CANCELLED;
        }
        if (FEC_ConstantCommon.DISB_API_STATUS_AUTO_CANCELLED.equalsIgnoreCase(s)) {
            return FEC_ConstantCommon.FAST_CASH_DISB_STATUS_RESOLVED_WITHDRAWAL_EXPIRED;
        }
        return s;
    }

    public static String mapApiDisbursementStatusToCaseValue(String apiStatus) {
        return mapDisbursementStatusForDisplay(apiStatus);
    }
}

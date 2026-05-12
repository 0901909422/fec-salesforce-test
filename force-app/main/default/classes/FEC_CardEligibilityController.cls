/***************************************************************************************
 * File Name    : FEC_CardEligibilityController
 * Author       : Antigravity
 * Date         : 2026-04-15
 * Description  : Apex Controller for Card Eligibility Section LWC.
 *                Handles:
 *                  1. Top-up/ E-voucher Eligibility  → CheckAccountEligibility API
 *                  2. Fast Cash/ IPP Eligibility      → CheckEligibility SOAP API
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
 * 1.0      2026-04-15     Antigravity         Create
 ***************************************************************************************/
public with sharing class FEC_CardEligibilityController {

    // =========================================================================
    // RESPONSE WRAPPERS
    // =========================================================================

    /**
     * Wrapper for Top-up / E-voucher eligibility (CheckAccountEligibility API)
     */
    public class TopUpEligibilityResult {
        @AuraEnabled public Boolean success          { get; set; }
        @AuraEnabled public Integer httpStatus      { get; set; }
        @AuraEnabled public String  availableCreditLimit { get; set; }
        @AuraEnabled public String  reason           { get; set; }
        @AuraEnabled public String  errorMessage     { get; set; }
    }

    /**
     * Wrapper for Fast Cash / IPP Eligibility (CheckEligibility SOAP API)
     * Mirrors FEC_CheckEligibilityIPPCallout.CheckEligibilityResult with extra fields
     */
    public class IPPEligibilityResult {
        @AuraEnabled public Boolean           success        { get; set; }
        @AuraEnabled public Integer           httpStatus     { get; set; }
        @AuraEnabled public String            fastCashStatus { get; set; }  // accEligibility
        @AuraEnabled public String            ippStatus      { get; set; }  // "Eligible" / "Not Eligible"
        @AuraEnabled public String            creditLimit    { get; set; }
        @AuraEnabled public String            errorCode      { get; set; }
        @AuraEnabled public String            description    { get; set; }
        @AuraEnabled public String            errorMessage   { get; set; }
        @AuraEnabled public List<IPPTenorRow> tenorList      { get; set; }
    }

    /**
     * Một dòng trong bảng IPP Eligibility
     */
    public class IPPTenorRow {
        @AuraEnabled public Integer id             { get; set; }
        @AuraEnabled public String  tenure         { get; set; }
        @AuraEnabled public String  rate           { get; set; }
        @AuraEnabled public String  registrationRate { get; set; }
        @AuraEnabled public Decimal monthlyInstallment { get; set; }
        @AuraEnabled public Decimal conversionFee  { get; set; }
    }

    /** Bundle đọc từ FEC_Customer_History__c (neo Case.FEC_Account_or_Contract__c). */
    public class CardEligibilityBundle {
        @AuraEnabled public TopUpEligibilityResult topUpResult { get; set; }
        @AuraEnabled public IPPEligibilityResult   ippResult   { get; set; }
    }

    // =========================================================================
    // AURA-ENABLED METHODS
    // =========================================================================

    /**
     * Resolves the account number for Card eligibility APIs from the Case.
     * Uses Case lookup to FEC_Customer_History__c when populated (FEC_Account_or_Contract__c
     * or legacy FEC_Customer_History__c if present), then FEC_Account_Number__c on CH.
     * Falls back to Card / Account / formula fields on Case when CH has no account number.
     */
    @AuraEnabled(cacheable=true)
    public static String resolveAccountNumberFromCase(Id caseId) {
        if (caseId == null) {
            return null;
        }
        Map<String, Schema.SObjectField> caseFm = Case.SObjectType.getDescribe().fields.getMap();
        List<String> selectParts = new List<String>();
        String apiChLookup = resolveCaseFieldApi(caseFm, 'FEC_Customer_History__c');
        String apiAcctContract = resolveCaseFieldApi(caseFm, 'FEC_Account_or_Contract__c');
        String apiCardAcct = resolveCaseFieldApi(caseFm, 'FEC_Card_Account_Number__c');
        String apiCaseAcct = resolveCaseFieldApi(caseFm, 'FEC_Account_Number__c');
        String apiContractText = resolveCaseFieldApi(caseFm, 'FEC_Account_Contract_Number_Text__c');
        addResolvedField(selectParts, apiChLookup);
        addResolvedField(selectParts, apiAcctContract);
        addResolvedField(selectParts, apiCardAcct);
        addResolvedField(selectParts, apiCaseAcct);
        addResolvedField(selectParts, apiContractText);
        if (selectParts.isEmpty()) {
            return null;
        }
        String soql = 'SELECT ' + String.join(selectParts, ', ') + ' FROM Case WHERE Id = :caseId LIMIT 1';
        SObject c = Database.query(soql);

        Id chId = null;
        if (String.isNotBlank(apiChLookup)) {
            chId = (Id) c.get(apiChLookup);
        }
        if (chId == null && String.isNotBlank(apiAcctContract)) {
            chId = (Id) c.get(apiAcctContract);
        }

        if (chId != null) {
            List<FEC_Customer_History__c> histories = [
                SELECT FEC_Account_Number__c
                FROM FEC_Customer_History__c
                WHERE Id = :chId
                LIMIT 1
            ];
            if (!histories.isEmpty() && String.isNotBlank(histories[0].FEC_Account_Number__c)) {
                return histories[0].FEC_Account_Number__c.trim();
            }
        }

        if (String.isNotBlank(apiCardAcct)) {
            String v = (String) c.get(apiCardAcct);
            if (String.isNotBlank(v)) {
                return v.trim();
            }
        }
        if (String.isNotBlank(apiCaseAcct)) {
            String v = (String) c.get(apiCaseAcct);
            if (String.isNotBlank(v)) {
                return v.trim();
            }
        }
        if (String.isNotBlank(apiContractText)) {
            String v = (String) c.get(apiContractText);
            if (String.isNotBlank(v)) {
                return v.trim();
            }
        }
        return null;
    }

    /** Describe map keys are often lowercase; resolve to real API name for SOQL/c.get */
    private static String resolveCaseFieldApi(Map<String, Schema.SObjectField> fm, String apiName) {
        for (String k : fm.keySet()) {
            if (k != null && k.equalsIgnoreCase(apiName)) {
                return fm.get(k).getDescribe().getName();
            }
        }
        return null;
    }

    private static void addResolvedField(List<String> parts, String resolvedApi) {
        if (String.isNotBlank(resolvedApi)) {
            parts.add(resolvedApi);
        }
    }

    /**
     * Customer History để lưu/đọc Card eligibility: Case.FEC_Account_or_Contract__c → FEC_Customer_History__c.Id.
     */
    private static Id resolveCaseCustomerHistoryIdForCardEligibility(Id caseId) {
        if (caseId == null) {
            return null;
        }
        Case c = [
            SELECT FEC_Account_or_Contract__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        return c.FEC_Account_or_Contract__c;
    }

    /**
     * Đọc snapshot Card eligibility trên FEC_Customer_History__c (khi Case có FEC_Account_or_Contract__c).
     */
    @AuraEnabled(cacheable = true)
    public static CardEligibilityBundle loadCardEligibilityFromCustomerHistory(Id caseId) {
        CardEligibilityBundle bundle = new CardEligibilityBundle();
        if (caseId == null) {
            return bundle;
        }
        Id chId = resolveCaseCustomerHistoryIdForCardEligibility(caseId);
        if (chId == null) {
            return bundle;
        }
        List<FEC_Customer_History__c> rows = [
            SELECT
                FEC_Available_Credit_Limit__c,
                FEC_Reason__c,
                FEC_Fast_Cash_Status__c,
                FEC_Error_Code__c,
                FEC_Description__c,
                FEC_IPP_Status__c,
                FEC_Limit__c
            FROM FEC_Customer_History__c
            WHERE Id = :chId
            LIMIT 1
        ];
        if (rows.isEmpty()) {
            return bundle;
        }
        FEC_Customer_History__c row = rows[0];

        Boolean hasTopUp =
            row.FEC_Available_Credit_Limit__c != null || String.isNotBlank(row.FEC_Reason__c);
        if (hasTopUp) {
            TopUpEligibilityResult tur = new TopUpEligibilityResult();
            tur.success = true;
            tur.httpStatus = 200;
            if (row.FEC_Available_Credit_Limit__c != null) {
                tur.availableCreditLimit = String.valueOf(row.FEC_Available_Credit_Limit__c);
            }
            tur.reason = row.FEC_Reason__c;
            bundle.topUpResult = tur;
        }

        Boolean hasIpp =
            String.isNotBlank(row.FEC_Fast_Cash_Status__c)
            || String.isNotBlank(row.FEC_Error_Code__c)
            || String.isNotBlank(row.FEC_Description__c)
            || String.isNotBlank(row.FEC_IPP_Status__c)
            || row.FEC_Limit__c != null;
        if (hasIpp) {
            IPPEligibilityResult ipr = new IPPEligibilityResult();
            ipr.success = true;
            ipr.httpStatus = 200;
            ipr.fastCashStatus = row.FEC_Fast_Cash_Status__c;
            ipr.errorCode = row.FEC_Error_Code__c;
            ipr.description = row.FEC_Description__c;
            ipr.ippStatus = row.FEC_IPP_Status__c;
            if (row.FEC_Limit__c != null) {
                ipr.creditLimit = String.valueOf(row.FEC_Limit__c);
            }
            ipr.tenorList = new List<IPPTenorRow>();
            bundle.ippResult = ipr;
        }
        return bundle;
    }

    private static Boolean isHttp200(Integer httpStatus) {
        return httpStatus != null && httpStatus == 200;
    }

    private static String truncateLongText(String value, Integer maxLen) {
        if (String.isBlank(value)) {
            return null;
        }
        return value.length() > maxLen ? value.substring(0, maxLen) : value;
    }

    private static String truncateText255(String value) {
        return truncateLongText(value, 255);
    }

    private static void persistTopUpToCustomerHistory(Id caseId, TopUpEligibilityResult result) {
        if (caseId == null || result == null || !isHttp200(result.httpStatus)) {
            return;
        }
        Id chId = resolveCaseCustomerHistoryIdForCardEligibility(caseId);
        if (chId == null) {
            return;
        }
        Decimal acl = null;
        if (String.isNotBlank(result.availableCreditLimit)) {
            try {
                acl = Decimal.valueOf(result.availableCreditLimit.trim());
            } catch (Exception e) {
                acl = null;
            }
        }
        update new FEC_Customer_History__c(
            Id = chId,
            FEC_Available_Credit_Limit__c = acl,
            FEC_Reason__c = truncateLongText(result.reason, 32768)
        );
    }

    private static void persistIppToCustomerHistory(Id caseId, IPPEligibilityResult result) {
        if (caseId == null || result == null || !isHttp200(result.httpStatus)) {
            return;
        }
        Id chId = resolveCaseCustomerHistoryIdForCardEligibility(caseId);
        if (chId == null) {
            return;
        }
        Decimal lim = null;
        if (String.isNotBlank(result.creditLimit)) {
            try {
                lim = Decimal.valueOf(result.creditLimit.trim());
            } catch (Exception e) {
                lim = null;
            }
        }
        update new FEC_Customer_History__c(
            Id = chId,
            FEC_Fast_Cash_Status__c = truncateText255(result.fastCashStatus),
            FEC_Error_Code__c = truncateText255(result.errorCode),
            FEC_Description__c = truncateLongText(result.description, 32768),
            FEC_IPP_Status__c = truncateText255(result.ippStatus),
            FEC_Limit__c = lim
        );
    }

    /**
     * Fetch Top-up / E-voucher eligibility for given account number.
     * Calls FEC_CheckAccountEligibilityCallout (SOAP CMS_RewardDebitWS / CheckAccountEligibility).
     *
     * @param accountNumber  Card account number
     * @return TopUpEligibilityResult
     */
    @AuraEnabled
    public static TopUpEligibilityResult checkTopUpEligibility(Id caseId, String accountNumber) {
        TopUpEligibilityResult result = new TopUpEligibilityResult();
        result.success = false;

        try {
            if (String.isBlank(accountNumber)) {
                result.httpStatus = 0;
                result.errorMessage = String.format(
                    System.Label.FEC_MSG_Param_Required,
                    new List<String>{ 'Account Number' }
                );
                return result;
            }

            FEC_CheckAccountEligibilityCallout.CheckAccountEligibilityResult apiResult =
                FEC_CheckAccountEligibilityCallout.checkAccountEligibility(accountNumber);

            result.httpStatus = apiResult.httpStatus;
            result.success = apiResult.success;
            result.availableCreditLimit = (apiResult.availCr != null)
                ? String.valueOf(apiResult.availCr)
                : null;
            result.reason = apiResult.description;
            if (String.isBlank(result.reason) && String.isNotBlank(apiResult.customerName)) {
                result.reason = apiResult.customerName;
            }
            result.errorMessage = apiResult.errorMessage;

            persistTopUpToCustomerHistory(caseId, result);

        } catch (Exception e) {
            result.success      = false;
            result.httpStatus   = 0;
            result.errorMessage = e.getMessage();
        }

        return result;
    }

    /**
     * Fetch Fast Cash / IPP eligibility for given account number.
     * Calls FEC_CheckEligibilityIPPCallout (SOAP API) then fetches IPP detail list.
     *
     * @param accountNumber  Card account number
     * @return IPPEligibilityResult
     */
    @AuraEnabled
    public static IPPEligibilityResult checkIPPEligibility(Id caseId, String accountNumber) {
        IPPEligibilityResult result = new IPPEligibilityResult();
        result.success    = false;
        result.tenorList  = new List<IPPTenorRow>();

        try {
            if (String.isBlank(accountNumber)) {
                result.httpStatus = 0;
                result.errorMessage = String.format(
                    System.Label.FEC_MSG_Param_Required,
                    new List<String>{ 'Account Number' }
                );
                return result;
            }

            // Call IPP eligibility SOAP API
            FEC_CheckEligibilityIPPCallout.CheckEligibilityResult apiResult =
                FEC_CheckEligibilityIPPCallout.checkAccountEligibility(accountNumber);

            result.httpStatus  = apiResult.httpStatus;
            result.success      = apiResult.success;
            result.errorMessage = apiResult.errorMessage;
            result.errorCode    = apiResult.code;
            result.description  = apiResult.description;

            // Map eligibility fields
            String elig = apiResult.accEligibility;
            Boolean isEligible = ('true'.equalsIgnoreCase(elig) || 'eligible'.equalsIgnoreCase(elig) || '1'.equals(elig));
            result.fastCashStatus = isEligible
                ? System.Label.FEC_MSG_Status_Eligible
                : System.Label.FEC_MSG_Status_Not_Eligible;
            result.ippStatus = isEligible
                ? System.Label.FEC_MSG_Status_Eligible
                : System.Label.FEC_MSG_Status_Not_Eligible;

            // Populate mock / placeholder tenor table (replace with real API call if available)
            if (isEligible) {
                result.tenorList = buildTenorList(accountNumber);
            }

            persistIppToCustomerHistory(caseId, result);

        } catch (Exception e) {
            result.success      = false;
            result.httpStatus   = 0;
            result.errorMessage = e.getMessage();
        }

        return result;
    }

    // =========================================================================
    // HELPER : Build IPP tenor table
    // Replace this with the actual API call to retrieve IPP plan details
    // =========================================================================
    private static List<IPPTenorRow> buildTenorList(String accountNumber) {
        List<IPPTenorRow> rows = new List<IPPTenorRow>();

        // Fetch IPP plan details using existing callout
        try {
            FEC_GetIPPDetailsCallout.IPPRequest req = new FEC_GetIPPDetailsCallout.IPPRequest();
            req.accountNumber = accountNumber;
            req.effectiveDate = Date.today().format();
            req.postingDate   = Date.today().format();
            req.amount        = 0;

            FEC_GetIPPDetailsCallout.IPPDetailsResponse detail =
                FEC_GetIPPDetailsCallout.getIPPDetails(req);

            if (detail != null && detail.status != 'ERROR') {
                IPPTenorRow row       = new IPPTenorRow();
                row.id                = 1;
                row.tenure            = detail.ippTerm;
                row.rate              = detail.interestRate != null
                    ? (detail.interestRate * 100).setScale(2) + '%' : null;
                row.registrationRate  = null;
                row.monthlyInstallment = detail.installmentAmount;
                row.conversionFee     = detail.conversionFee;
                rows.add(row);
            }
        } catch (Exception e) {
            // Return empty list if IPP detail fetch fails
            System.debug('IPP detail fetch error: ' + e.getMessage());
        }

        return rows;
    }
}

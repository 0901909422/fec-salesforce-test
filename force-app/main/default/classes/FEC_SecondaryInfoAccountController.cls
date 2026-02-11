/****************************************************************************************
 * File Name    : FEC_SecondaryInfoAccountController.Apex
 * Author       : Quangdv7
 * Date         : 2025-01-10
 * Description  : Call data object Case
 * Modification Log
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0      2025-01-10     Quangdv7             Create
 
****************************************************************************************/

public without sharing class FEC_SecondaryInfoAccountController {

    /* ===================== DTO ===================== */
    public class SecondaryAccountDTO {
        @AuraEnabled public Map<String, String> helpTexts;

        /* ===== LIMIT ===== */
        @AuraEnabled public String dailyRetailLimit;
        @AuraEnabled public String oneTimeRetailLimit;
        @AuraEnabled public String dailyRetailNumber;

        @AuraEnabled public String dailyCashLimit;
        @AuraEnabled public String oneTimeCashLimit;
        @AuraEnabled public String dailyCashNumber;
        @AuraEnabled public String availableCashLimit;

        @AuraEnabled public String dailyECommerceLimit;
        @AuraEnabled public String oneTimeECommerceLimit;
        @AuraEnabled public String dailyECommerceNumber;

        @AuraEnabled public String lastCreditLimit;
        @AuraEnabled public String lastCreditLimitDate;

        /* ===== MAIN CARD ===== */
        @AuraEnabled public String embossingName;
        @AuraEnabled public String statementNotificationType;
        @AuraEnabled public String firstTransactionAmount;
        @AuraEnabled public String firstEffectiveDate;
        @AuraEnabled public String lastTransactionAmount;
        @AuraEnabled public String lastEffectiveDate;
        @AuraEnabled public String lastAdvanceAmount;
        @AuraEnabled public String lastAdvanceDate;
        @AuraEnabled public String memorableQuestion;

        /* ===== PIN ===== */
        @AuraEnabled public String lastPinStatus;
        @AuraEnabled public String lastPinActionDate;

        /* ===== FEE ===== */
        @AuraEnabled public String annualFee;
        @AuraEnabled public String lastAFDate;

        /* ===== COLLECTION ===== */
        @AuraEnabled public String responsibleUnit;
        @AuraEnabled public String responsiblePerson;
        @AuraEnabled public String dateAssigned;
        @AuraEnabled public String delinquencyDate;

        /* ===== SALES ===== */
        @AuraEnabled public String ccCode;
        @AuraEnabled public String ccName;
        @AuraEnabled public String dsaCode;
        @AuraEnabled public String dsaName;
        @AuraEnabled public String tsaCode;
        @AuraEnabled public String tsaName;
    }

    /* ===================== LOAD (INIT SCREEN) ===================== */
    @AuraEnabled
    public static SecondaryAccountDTO loadSecondaryAccount(Id caseId) {
        syncFromApi(caseId);
        return loadFromDb(caseId);
    }

    /* ===================== REFRESH BUTTON ===================== */
    @AuraEnabled
    public static SecondaryAccountDTO refreshSecondaryAccount(Id caseId) {
        syncFromApi(caseId);
        return loadFromDb(caseId);
    }

   /* ===================== CALL API & UPDATE DB ===================== */
    private static void syncFromApi(Id caseId) {

        Case c = [
            SELECT FEC_Account_or_Contract__c, FEC_Account_Number__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        if (c.FEC_Account_or_Contract__c == null) return;

        FEC_Customer_History__c acc = [
            SELECT Id
            FROM FEC_Customer_History__c
            WHERE Id = :c.FEC_Account_or_Contract__c
            LIMIT 1
        ];

        /* ===== CARD API ===== */
        try {
            FEC_GetCardSecInfo.ResponseWrapper res =
                FEC_GetCardSecInfo.callGetCardSecInfo(
                    FEC_CommonUltils.generateTransactionId(),
                    FEC_ConstantCommon.REQUESTOR_CRM,
                    Datetime.now().formatGMT(FEC_ConstantCommon.DATETIME_FORMAT),
                    c.FEC_Account_Number__c
                );

            if (res != null && res.CardSecInfo != null) {

                FEC_GetCardSecInfo.CardSecInfo info = res.CardSecInfo;

                FEC_GetCardSecInfo.MainCardProduct p = info.MainCardProduct;
                if (p != null) {
                    acc.FEC_Daily_Retail_Limit__c     = p.DailyRetailLimit;
                    acc.FEC_Daily_Retail_Number__c    = p.DailyRetailNumber;
                    acc.FEC_Daily_Cash_Limit__c       = p.DailyCashLimit;
                    acc.FEC_Daily_Cash_Number__c      = p.DailyCashNumber;
                    acc.FEC_Last_Credit_Limit__c      = p.LastCreditLimit;
                    acc.FEC_Last_Credit_Limit_Date__c = p.LastCreditLimitDate;
                    acc.FEC_Delinquency_Date__c       = p.LastDelinquencyDate;
                }

                FEC_GetCardSecInfo.MainCardPlastic pl = info.MainCardPlastic;
                if (pl != null) {
                    acc.FEC_Embossing_Name__c = pl.EmbossingName;
                }

                FEC_GetCardSecInfo.PassDue pd = info.PassDue;
                if (pd != null) {
                    acc.FEC_Responsible_Unit__c    = pd.ResponsibleUnit;
                    acc.FEC_Responsible_Person__c = pd.ResposiblePerson;
                }
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }

        /* ===== SALE API ===== */
        try {
            FEC_GetCustomerSaleDisburseInfoCallout.CustomerSaleDisburseInfoResponse saleRes =
                FEC_GetCustomerSaleDisburseInfoCallout.getCustomerSaleDisburseInfo(
                    c.FEC_Account_Number__c
                );

            if (saleRes != null &&
                saleRes.Sys != null &&
                saleRes.Sys.Code == 1 &&
                saleRes.CustomerSaleInfos != null &&
                !saleRes.CustomerSaleInfos.isEmpty()
            ) {
                FEC_GetCustomerSaleDisburseInfoCallout.CustomerSaleInfo s =
                    saleRes.CustomerSaleInfos[0];

                acc.FEC_CC_Code__c  = s.CC_CODE;
                acc.FEC_CC_Name__c  = s.CC_NAME;
                acc.FEC_DSA_Code__c = s.DSA_CODE;
                acc.FEC_DSA_Name__c = s.DSA_NAME;
                acc.FEC_TSA_Code__c = s.TSA_CODE;
                acc.FEC_TSA_Name__c = s.TSA_NAME;
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }

        update acc;
    }


    /* ===================== LOAD DB ONLY ===================== */
    private static SecondaryAccountDTO loadFromDb(Id caseId) {

        Case c = [
            SELECT FEC_Account_or_Contract__c
            FROM Case WHERE Id = :caseId LIMIT 1
        ];

        FEC_Customer_History__c a = [
            SELECT
                FEC_Daily_Retail_Limit__c,
                FEC_Daily_Retail_Number__c,
                FEC_Daily_Cash_Limit__c,
                FEC_Daily_Cash_Number__c,
                FEC_Last_Credit_Limit__c,
                FEC_Last_Credit_Limit_Date__c,
                FEC_Embossing_Name__c,
                FEC_Responsible_Unit__c,
                FEC_Responsible_Person__c,
                FEC_Delinquency_Date__c,
                FEC_CC_Code__c,
                FEC_CC_Name__c,
                FEC_DSA_Code__c,
                FEC_DSA_Name__c,
                FEC_TSA_Code__c,
                FEC_TSA_Name__c
            FROM FEC_Customer_History__c
            WHERE Id = :c.FEC_Account_or_Contract__c
            LIMIT 1
        ];

        return mapToDTO(a);
    }

    /* ===================== DTO MAPPER (DB ONLY) ===================== */
    private static SecondaryAccountDTO mapToDTO(FEC_Customer_History__c a) {
        SecondaryAccountDTO d = new SecondaryAccountDTO();
        d.helpTexts = buildHelpTextMap();

        d.dailyRetailLimit    = fmt(a.FEC_Daily_Retail_Limit__c);
        d.dailyRetailNumber   = fmt(a.FEC_Daily_Retail_Number__c);
        d.dailyCashLimit      = fmt(a.FEC_Daily_Cash_Limit__c);
        d.dailyCashNumber     = fmt(a.FEC_Daily_Cash_Number__c);
        d.lastCreditLimit     = fmt(a.FEC_Last_Credit_Limit__c);
        d.lastCreditLimitDate = fmtDate(a.FEC_Last_Credit_Limit_Date__c);

        d.embossingName       = a.FEC_Embossing_Name__c;
        d.responsibleUnit     = a.FEC_Responsible_Unit__c;
        d.responsiblePerson   = a.FEC_Responsible_Person__c;
        d.delinquencyDate     = fmtDate(a.FEC_Delinquency_Date__c);

        d.ccCode  = a.FEC_CC_Code__c;
        d.ccName  = a.FEC_CC_Name__c;
        d.dsaCode = a.FEC_DSA_Code__c;
        d.dsaName = a.FEC_DSA_Name__c;
        d.tsaCode = a.FEC_TSA_Code__c;
        d.tsaName = a.FEC_TSA_Name__c;

        return d;
    }

    /* ===================== HELPERS ===================== */
    private static String fmt(Decimal d) {
        return d == null ? '' : d.format();
    }
    private static String fmtDate(Date d) {
        return d == null ? '' : d.format();
    }
    private static Map<String, String> buildHelpTextMap() {
        Map<String, String> m = new Map<String, String>();
        for (Schema.SObjectField f :
            FEC_Customer_History__c.SObjectType.getDescribe().fields.getMap().values()) {
            if (String.isNotBlank(f.getDescribe().getInlineHelpText())) {
                m.put(f.getDescribe().getName(), f.getDescribe().getInlineHelpText());
            }
        }
        return m;
    }
}
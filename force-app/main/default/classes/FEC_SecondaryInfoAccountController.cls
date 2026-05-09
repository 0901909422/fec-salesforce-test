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
        @AuraEnabled public String dailyRetailNumber;
        @AuraEnabled public String dailyCashLimit;
        @AuraEnabled public String dailyCashNumber;
        @AuraEnabled public String lastCreditLimit;
        @AuraEnabled public String lastCreditLimitDate;

        /* ===== MAIN CARD ===== */
        @AuraEnabled public String embossingName;
        @AuraEnabled public String statementNotificationType;

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
            SELECT FEC_Account_or_Contract__c, FEC_Account_Number__c, FEC_Product_Type__r.Name,
            FEC_Is_Test_API__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];

        if (c.FEC_Is_Test_API__c == true) {
            throw new AuraHandledException(
                String.format(
                    System.Label.FEC_MSG_API_Error,
                    new List<String>{ 'Call Fail' }
                )
            );
        }
      
        String accountNumber;
        String cifNumber;
        String applicationID;
        FEC_Customer_History__c acc;

        /* ========= 1. TRY LOCAL ========= */
        if (c.FEC_Account_or_Contract__c != null){
            acc = [
                SELECT Id,FEC_Account_Number__c,FEC_CIF_Number__c,FEC_Application_ID__c,FEC_Contract_Number__c
                FROM FEC_Customer_History__c
                WHERE Id = :c.FEC_Account_or_Contract__c
                LIMIT 1
            ];

            accountNumber = FEC_CommonUltils.resolveAccountNumber(
                c.FEC_Product_Type__r.Name,
                acc.FEC_Account_Number__c,
                acc.FEC_Contract_Number__c
            );
            cifNumber = acc.FEC_CIF_Number__c;
            applicationID = acc.FEC_Application_ID__c;
        }

        /* ===== CARD API ===== */
        try {
            FEC_GetCardSecInfo.ResponseWrapper res =
                FEC_GetCardSecInfo.callGetCardSecInfo(
                    FEC_CommonUltils.generateTransactionId(),
                    FEC_ConstantCommon.REQUESTOR_CRM,
                    Datetime.now().formatGMT(FEC_ConstantCommon.DATETIME_FORMAT),
                    accountNumber,
                    c.FEC_Is_Test_API__c
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
                    acc.FEC_Statement_Notification_Type__c = P.StatementNotificationType;
                }

                FEC_GetCardSecInfo.MainCardPlastic pl = info.MainCardPlastic;
                if (pl != null) {
                    acc.FEC_Embossing_Name__c = pl.EmbossingName;
                }

                FEC_GetCardSecInfo.PassDue pd = info.PassDue;
                if (pd != null) {
                    acc.FEC_Responsible_Unit__c    = pd.ResponsibleUnit;
                    acc.FEC_Responsible_Person__c = pd.ResposiblePerson;
                    acc.FEC_Date_Assigned__c = pd.DateAssgined;
                }
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }

        /* ===== SALE API ===== */
        try {

            FEC_GetCustomerSaleDisburseInfoCallout.CustomerSaleDisburseInfoResponse saleRes =
                FEC_GetCustomerSaleDisburseInfoCallout.getCustomerSaleDisburseInfo(applicationID);

            if (FEC_GetCustomerSaleDisburseInfoCallout.isSuccess(saleRes)) {

                FEC_GetCustomerSaleDisburseInfoCallout.CustomerSaleInfo s =
                    FEC_GetCustomerSaleDisburseInfoCallout.getFirstSaleInfo(saleRes);

                if (s != null) {
                    acc.FEC_CC_Code__c  = s.CC_CODE;
                    acc.FEC_CC_Name__c  = s.CC_NAME;
                    acc.FEC_DSA_Code__c = s.DSA_CODE;
                    acc.FEC_DSA_Name__c = s.DSA_NAME;
                    acc.FEC_TSA_Code__c = s.TSA_CODE;
                    acc.FEC_TSA_Name__c = s.TSA_NAME;
                }
            }

        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
        update acc;
    }


    /* ===================== LOAD DB ONLY ===================== */
    private static SecondaryAccountDTO loadFromDb(Id caseId) {

        Case c = [
            SELECT FEC_Account_or_Contract__c,FEC_Is_Test_API__c
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
                FEC_Statement_Notification_Type__c,
                FEC_Date_Assigned__c,
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
        d.helpTexts = FEC_CommonUltils.buildHelpTextMap(FEC_Customer_History__c.SObjectType);

        d.dailyRetailLimit    = FEC_CommonUltils.decimalToString(a.FEC_Daily_Retail_Limit__c);
        d.dailyRetailNumber   = FEC_CommonUltils.decimalToString(a.FEC_Daily_Retail_Number__c);
        d.dailyCashLimit      = FEC_CommonUltils.decimalToString(a.FEC_Daily_Cash_Limit__c);
        d.dailyCashNumber     = FEC_CommonUltils.decimalToString(a.FEC_Daily_Cash_Number__c);
        d.lastCreditLimit     = FEC_CommonUltils.decimalToString(a.FEC_Last_Credit_Limit__c);
        d.lastCreditLimitDate = FEC_CommonUltils.formatDate(a.FEC_Last_Credit_Limit_Date__c);

        d.embossingName       = a.FEC_Embossing_Name__c;
        d.statementNotificationType = a.FEC_Statement_Notification_Type__c;
        d.responsibleUnit     = a.FEC_Responsible_Unit__c;
        d.responsiblePerson   = a.FEC_Responsible_Person__c;
        d.delinquencyDate     = FEC_CommonUltils.formatDate(a.FEC_Delinquency_Date__c);
        d.dateAssigned        = FEC_CommonUltils.formatDate(a.FEC_Date_Assigned__c);

        d.ccCode  = a.FEC_CC_Code__c;
        d.ccName  = a.FEC_CC_Name__c;
        d.dsaCode = a.FEC_DSA_Code__c;
        d.dsaName = a.FEC_DSA_Name__c;
        d.tsaCode = a.FEC_TSA_Code__c;
        d.tsaName = a.FEC_TSA_Name__c;

        return d;
    }

}
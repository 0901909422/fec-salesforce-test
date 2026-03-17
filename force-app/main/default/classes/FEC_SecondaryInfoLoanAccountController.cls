public without sharing class FEC_SecondaryInfoLoanAccountController {

    /* ===================== LOAD (INIT SCREEN) ===================== */

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> loadSecondaryLoanInfo(Id caseId) {
        if (caseId == null) {
            throw new AuraHandledException(
                String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'Case Id'})
            );
        }

        Case c = [
            SELECT FEC_Account_or_Contract__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];

        if (c.FEC_Account_or_Contract__c == null) {
            throw new AuraHandledException(System.Label.FEC_MSG_Not_Account_Linked);
        }

        try {
            syncFromApi(c);
        } catch (Exception e) {
            System.debug('### SecondaryInfo syncFromApi ERROR: ' + e.getStackTraceString());
        }
        return loadFromDb(c);
    }

    /* ===================== REFRESH BUTTON ===================== */

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> refreshSecondaryLoanInfo(Id caseId) {
        if (caseId == null) {
            throw new AuraHandledException(
                String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'Case Id'})
            );
        }

        Case c = [
            SELECT FEC_Account_or_Contract__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];

        if (c.FEC_Account_or_Contract__c == null) {
            throw new AuraHandledException(System.Label.FEC_MSG_Not_Account_Linked);
        }

        try {
            syncFromApi(c);
        } catch (Exception e) {
            System.debug('### SecondaryInfo refresh syncFromApi ERROR: ' + e.getStackTraceString());
        }
        return loadFromDb(c);
    }

    /* ===================== CALL API & UPDATE DB ===================== */

    private static void syncFromApi(Case c) {
        Id historyId = c.FEC_Account_or_Contract__c;

        List<FEC_Customer_History__c> historyList = [
            SELECT FEC_Contract_Number__c
            FROM FEC_Customer_History__c
            WHERE Id = :historyId
            LIMIT 1
        ];
        String contractNumber = (historyList.isEmpty() || historyList[0] == null)
            ? null
            : historyList[0].FEC_Contract_Number__c;

        FEC_Customer_History__c upd = new FEC_Customer_History__c(Id = historyId);
        Boolean hasUpdate = false;
        String applicationId;

        /* ===== LOAN API → Collection Info + ApplicationID ===== */
        try {
            if (String.isNotBlank(contractNumber)) {
                FEC_GetLoanBasicInfo.ResponseWrapper loanRes =
                    FEC_GetLoanBasicInfo.callGetLoanBasicInfo(
                        FEC_CommonUltils.generateTransactionId(),
                        FEC_ConstantCommon.REQUESTOR_CRM,
                        Datetime.now().formatGMT(FEC_ConstantCommon.DATETIME_FORMAT),
                        contractNumber
                    );

                if (loanRes?.LoanBasicInfo?.PassDue != null) {
                    upd.FEC_Responsible_Unit__c = loanRes.LoanBasicInfo.PassDue.ResponsibleUnit;
                    hasUpdate = true;
                }

                if (loanRes?.LoanBasicInfo?.Loan != null) {
                    applicationId = loanRes.LoanBasicInfo.Loan.ApplicationID;
                    upd.FEC_Application_ID__c = applicationId;
                    hasUpdate = true;
                }
            }
        } catch (Exception e) {
            System.debug('### LOAN API ERROR (SecondaryInfo): ' + e.getMessage());
        }

        /* ===== LOAN SEC API → Responsible Person + Date Assigned ===== */
        try {
            if (String.isNotBlank(contractNumber)) {
                FEC_GetLoanSecInfo.ResponseWrapper secRes =
                    FEC_GetLoanSecInfo.callGetLoanSecInfo(
                        FEC_CommonUltils.generateTransactionId(),
                        FEC_ConstantCommon.REQUESTOR_CRM,
                        Datetime.now().formatGMT(FEC_ConstantCommon.DATETIME_FORMAT),
                        contractNumber
                    );

                if (secRes?.LoanSecInfo?.PassDue != null) {
                    upd.FEC_Responsible_Person__c = secRes.LoanSecInfo.PassDue.ResponsiblePerson;
                    upd.FEC_Date_Assigned__c      = secRes.LoanSecInfo.PassDue.DateAssigned;
                    hasUpdate = true;
                }
            }
        } catch (Exception e) {
            System.debug('### LOAN SEC API ERROR (SecondaryInfo): ' + e.getMessage());
        }

        /* ===== SALE/DISBURSE API → Disbursement + Sales (Application ID từ Loan Basic) ===== */
        try {
            if (String.isNotBlank(applicationId)) {
                FEC_GetCustomerSaleDisburseInfoCallout.CustomerSaleDisburseInfoResponse saleRes =
                    FEC_GetCustomerSaleDisburseInfoCallout.getCustomerSaleDisburseInfo(applicationId);

                if (saleRes != null && saleRes.CustomerSaleInfos != null && !saleRes.CustomerSaleInfos.isEmpty()) {
                    FEC_GetCustomerSaleDisburseInfoCallout.CustomerSaleInfo s = saleRes.CustomerSaleInfos[0];

                    upd.FEC_CC_Code__c = s.CC_CODE;
                    upd.FEC_CC_Name__c = s.CC_NAME;
                    upd.FEC_DSA_Code__c = s.DSA_CODE;
                    upd.FEC_DSA_Name__c = s.DSA_NAME;
                    upd.FEC_TSA_Code__c = s.TSA_CODE;
                    upd.FEC_TSA_Name__c = s.TSA_NAME;
                    upd.FEC_Bank_Name__c             = s.BANK_NAME;
                    upd.FEC_Branch_Name__c           = s.BRANCH_NAME;
                    upd.FEC_Account_Number__c        = s.BANK_ACCOUNT_NUMBER;
                    upd.FEC_Disbursement_Channel__c  = s.DISB_CHANNEL;
                    upd.FEC_Disbursement_Date__c     = FEC_CommonUltils.parseDate(s.DATE_STATUS);
                    upd.FEC_Is_Top_Up_Account__c     = s.TOPUP_FLAG;
                    upd.FEC_Top_Up_Loan_Amount_Requested__c  = s.TOP_UP_LOAN_AMT;
                    upd.FEC_Top_Up_Old_A_c_Outstanding__c    = s.TOP_UP_OLD_AC_OUSTANDING;
                    upd.FEC_Top_Up_Old_Account_App_ID__c     = s.TOP_UP_AGREEMENT_ID;

                    hasUpdate = true;
                }
            }
        } catch (Exception e) {
            System.debug('### SALE API ERROR (SecondaryInfo): ' + e.getMessage());
        }

        if (hasUpdate) {
            update upd;
        }
    }

    /* ===================== LOAD DB ONLY ===================== */

    private static Map<String, Object> loadFromDb(Case c) {

        FEC_Customer_History__c a = [
            SELECT
                FEC_Responsible_Unit__c,
                FEC_Responsible_Person__c,
                FEC_CC_Code__c,
                FEC_CC_Name__c,
                FEC_DSA_Code__c,
                FEC_DSA_Name__c,
                FEC_TSA_Code__c,
                FEC_TSA_Name__c,
                FEC_Bank_Name__c,
                FEC_Branch_Name__c,
                FEC_Account_Number__c,
                FEC_Disbursement_Channel__c,
                FEC_Disbursement_Date__c,
                FEC_Is_Top_Up_Account__c,
                FEC_Top_Up_Loan_Amount_Requested__c,
                FEC_Top_Up_Old_A_c_Outstanding__c,
                FEC_Top_Up_Old_Account_App_ID__c,
                FEC_Date_Assigned__c
            FROM FEC_Customer_History__c
            WHERE Id = :c.FEC_Account_or_Contract__c
            LIMIT 1
        ];

        return mapToResult(a);
    }

    /* ===================== MAP RECORD → RESULT ===================== */

    private static Map<String, Object> mapToResult(FEC_Customer_History__c a) {
        Map<String, Object> result = new Map<String, Object>();

        /* ===== Disbursement ===== */
        result.put('bankName', a.FEC_Bank_Name__c);
        result.put('branchName', a.FEC_Branch_Name__c);
        result.put('accountNumber', a.FEC_Account_Number__c);
        result.put('disbursementChannel', a.FEC_Disbursement_Channel__c);
        result.put('disbursementDate', FEC_CommonUltils.formatDate(a.FEC_Disbursement_Date__c));
        result.put('isTopUpAccount', a.FEC_Is_Top_Up_Account__c == null ? null : (a.FEC_Is_Top_Up_Account__c == 'Y' ? 'Yes' : 'No'));
        result.put('topUpLoanAmountRequested', FEC_CommonUltils.formatCurrency(a.FEC_Top_Up_Loan_Amount_Requested__c, 2));
        result.put('topUpOldAcOutstanding', FEC_CommonUltils.formatCurrency(a.FEC_Top_Up_Old_A_c_Outstanding__c, 2));
        result.put('topUpOldAcAppId', a.FEC_Top_Up_Old_Account_App_ID__c);

        /* ===== Collection Info ===== */
        result.put('responsibleUnit', a.FEC_Responsible_Unit__c);
        result.put('responsiblePerson', a.FEC_Responsible_Person__c);
        result.put('dateAssigned', a.FEC_Date_Assigned__c != null ? FEC_CommonUltils.formatDate(a.FEC_Date_Assigned__c) : '0');

        /* ===== Sales Info ===== */
        result.put('ccCode', a.FEC_CC_Code__c);
        result.put('ccName', a.FEC_CC_Name__c);
        result.put('dsaCode', a.FEC_DSA_Code__c);
        result.put('dsaName', a.FEC_DSA_Name__c);
        result.put('tsaCode', a.FEC_TSA_Code__c);
        result.put('tsaName', a.FEC_TSA_Name__c);
        result.put('helpTexts', FEC_CommonUltils.buildHelpTextMap(FEC_Customer_History__c.SObjectType));

        return result;
    }
}

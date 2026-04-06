/****************************************************************************************
 * File Name    : FEC_MainInfoAccountController.Apex
 * Author       : Quangdv7
 * Date         : 2025-01-10
 * Description  : Call data object Case
 * Modification Log
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0      2025-01-10     Quangdv7             Create
 
****************************************************************************************/

public without sharing class FEC_MainInfoAccountController {

    /* ===================== DTO ===================== */

    public class MainInfoDTO {
        @AuraEnabled public Map<String, String> helpTexts;
        @AuraEnabled public String accountNumber;
        @AuraEnabled public String contractNumber;
        @AuraEnabled public String accountStatus;
        @AuraEnabled public String applicationId;
        @AuraEnabled public String accountOpenDate;
        @AuraEnabled public String accountCloseDate;
        @AuraEnabled public String eSignStatus;
        @AuraEnabled public String creditLimit;
        @AuraEnabled public String otb;
        @AuraEnabled public String currentBalance;
        @AuraEnabled public String holdAmount;
        @AuraEnabled public String totalBalance;
        @AuraEnabled public Boolean isFromAccount;
       /* ===== ACCOUNT STATUS ===== */
        @AuraEnabled public String warningCode;
        @AuraEnabled public String blockCode1;
        @AuraEnabled public String blockDate1;
        @AuraEnabled public String reason1;
        @AuraEnabled public String daysPastDue;
        @AuraEnabled public String blockCode2;
        @AuraEnabled public String blockDate2;
        @AuraEnabled public String reason2;  
        /* ===== CARD ===== */
        @AuraEnabled public String cardNumber; 
        @AuraEnabled public String cardType; 
        @AuraEnabled public String plasticID; 
        @AuraEnabled public String expiryDate; 
        @AuraEnabled public String digitalCardID; 
        @AuraEnabled public String schemeID; 
        @AuraEnabled public String schemeDesc; 
        @AuraEnabled public String customerSegment; 
        @AuraEnabled public String productAssociation; 
        @AuraEnabled public String insuranceFlag; 
        /* ===== CARD STATUS ===== */
        @AuraEnabled public String cardBlockCode;
        @AuraEnabled public String cardBlockDate;
        @AuraEnabled public String blockedBy;
        @AuraEnabled public String cardActivationStatus;
        @AuraEnabled public String cardActivationDate;
        @AuraEnabled public String eCommerceStatus;
        @AuraEnabled public String fraudMonitorFlag;
        @AuraEnabled public String fraudMonitorDate;
        @AuraEnabled public String localUse;
        @AuraEnabled public String availablePoints;
        @AuraEnabled public String remark;
        /* ===== DEBT SALE ===== */
        @AuraEnabled public String debtSaleCompanyName;  
        @AuraEnabled public String debtSoldDate;          
        @AuraEnabled public String principalSold;        
        @AuraEnabled public String interestSold;         
        @AuraEnabled public String soldNote;            
        @AuraEnabled public String debtSaleType; 
    }

    public class RewardEligibilityResult {
        @AuraEnabled public Boolean isEligible;
        @AuraEnabled public String message;
        @AuraEnabled public String availablePoints;
        @AuraEnabled public String remark;
    }

    /* ===================== MAIN ===================== */

    @AuraEnabled(cacheable=false)
    public static MainInfoDTO loadAccountInfo(Id caseId) {

        if (caseId == null) {
            throw new AuraHandledException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'Case Id'}));
        }

        Case c = [
            SELECT Id, FEC_Account_or_Contract__c, FEC_Account_Number__c,FEC_Product_Type__r.Name
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];

        String accountNumber;
        String cifNumber;

        /* ========= 1. TRY LOCAL ========= */
        if (c.FEC_Account_or_Contract__c != null) {
            FEC_Customer_History__c acc = [
                SELECT FEC_Account_Number__c,FEC_CIF_Number__c,FEC_Contract_Number__c
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
        }

        /* ========= 2. CALL GetCardBasicInfo ========= */

        FEC_GetCardBasicInfo.ResponseWrapper cardRes;

        try {
            cardRes = FEC_GetCardBasicInfo.callGetCardBasicInfo(
                FEC_CommonUltils.generateTransactionId(),
                FEC_ConstantCommon.REQUESTOR_CRM,
                Datetime.now().formatGMT(FEC_ConstantCommon.DATETIME_FORMAT),
                accountNumber
            );
        } catch (Exception e) {
            System.debug(System.Label.FEC_MSG_API_Error + e.getMessage());
            cardRes = null;
        }

        /* ========= 3. CALL CUSTOMER LIST ========= */
        FEC_GetCustomerList.ResponseWrapper cusRes;

        try {
            cusRes = FEC_GetCustomerList.getCustomerList(
                FEC_ConstantCommon.REQUESTOR_PEGA_CSM_HYPHEN,
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
        } catch (Exception e) {
            System.debug(System.Label.FEC_MSG_API_Error + e.getMessage());
            cusRes = null;
        }

        /* ========= 4. CALL GetApplicationsList ========= */
        FEC_GetApplicationsList.ResponseWrapper appRes;

        try {
                appRes = FEC_GetApplicationsList.callGetApplicationsList(
                        FEC_CommonUltils.generateTransactionId(),
                        FEC_ConstantCommon.REQUESTOR_CRM,
                        Datetime.now().format(FEC_ConstantCommon.DATETIME_FORMAT),
                        cifNumber
                        
                    );
            } catch (Exception e) {
                System.debug(System.Label.FEC_MSG_API_Error + e.getMessage());
                appRes = null;
        }

        /* ========= 5. CALL EMEA_ACCOUNT_INQ ========= */
        FEC_EmeaAccountInqService.EmeaResult emeaRes;

        try {
            FEC_EmeaAccountInqService.EmeaInput input =
                new FEC_EmeaAccountInqService.EmeaInput();

            input.context    = FEC_ConstantCommon.REQUESTOR_CONTEXT;
            input.name       = UserInfo.getUserId();
            input.org        = FEC_ConstantCommon.REQUESTOR_ORG;
            input.account    = accountNumber;
            input.dualInd    = FEC_ConstantCommon.SUCCESS_STATUS_CODE;
            input.vmxVersion = FEC_ConstantCommon.REQUESTOR_VMXVERSION_EMEA;

            emeaRes = FEC_EmeaAccountInqService.callAccountInquiry(input);

        } catch (Exception e) {
            System.debug(System.Label.FEC_MSG_API_Error + e.getMessage());
            emeaRes = null;
        }

        /* ========= 6. CALL GetCardSecInfo ========= */
        FEC_GetCardSecInfo.ResponseWrapper cardSecRes;

        try {
           cardSecRes =  FEC_GetCardSecInfo.callGetCardSecInfo(
                    FEC_CommonUltils.generateTransactionId(),
                    FEC_ConstantCommon.REQUESTOR_CRM,
                    Datetime.now().formatGMT(FEC_ConstantCommon.DATETIME_FORMAT),
                    accountNumber
                );
        } catch (Exception e) {
            System.debug(System.Label.FEC_MSG_API_Error + e.getMessage());
            cardSecRes = null;
        }

        updateAccountFromAPI(c.FEC_Account_or_Contract__c, cardRes, cusRes, emeaRes, appRes, cardSecRes);

        return getAccountInfoLocal(c.FEC_Account_or_Contract__c);
    }

    @AuraEnabled
    public static RewardEligibilityResult checkRewardEligibility(Id caseId) {
        try {
            if (caseId == null) {
                throw new AuraHandledException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'Case Id'}));
            }
            
            Case c = [
                SELECT Id, FEC_Account_or_Contract__c, FEC_Account_Number__c
                FROM Case 
                WHERE Id = :caseId 
                LIMIT 1
            ];
            
            if (c.FEC_Account_or_Contract__c == null) {
                throw new AuraHandledException(System.Label.FEC_MSG_Not_Account_Linked);
            }
            
            FEC_Customer_History__c acc = [
                SELECT FEC_Account_Number__c
                FROM FEC_Customer_History__c 
                WHERE Id = :c.FEC_Account_or_Contract__c 
                LIMIT 1
            ];
            
            String accountNumber = acc.FEC_Account_Number__c;
            
            if (String.isBlank(accountNumber)) {
                throw new AuraHandledException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'AccountNumber'}));
            }
            
            FEC_GetRewardEligibility.ResponseWrapper apiResponse = 
                FEC_GetRewardEligibility.callGetRewardEligibility(
                    FEC_CommonUltils.generateTransactionId(),
                    FEC_ConstantCommon.REQUESTOR_CRM,
                    Datetime.now().formatGMT(FEC_ConstantCommon.DATETIME_FORMAT),
                    accountNumber
                );
            
            Boolean isEligible = (apiResponse.Sys.Code == 0);
            String remark = '';
            
            if (isEligible) {
                remark = apiResponse.Sys.Description;
            } else {
                remark = System.Label.FEC_MSG_Eligible;
            }
            
            FEC_Customer_History__c accToUpdate = new FEC_Customer_History__c(
                Id = c.FEC_Account_or_Contract__c
            );
            accToUpdate.FEC_Available_Points__c = apiResponse.AvailablePoints;
            accToUpdate.FEC_Remark__c = remark;
            update accToUpdate;
            
            RewardEligibilityResult result = new RewardEligibilityResult();
            result.isEligible = isEligible;
            result.message = isEligible 
                ? System.Label.FEC_MSG_Reward_Eligibility_Success
                : System.Label.FEC_MSG_Reward_Eligibility_Error;
            result.availablePoints = FEC_CommonUltils.formatCurrency(apiResponse.AvailablePoints, 0);
            result.remark = remark;
            
            return result;
            
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /* ===================== LOCAL READ ONLY ===================== */

    @AuraEnabled(cacheable=true)
    public static MainInfoDTO getAccountInfoLocal(Id accountId) {

        List<FEC_Customer_History__c> lst = [
            SELECT
                FEC_Account_Number__c,
                FEC_Contract_Number__c,
                FEC_Account_Status__c,
                FEC_Application_ID__c,
                FEC_Account_Open_Date__c,
                FEC_Account_Close_Date__c,
                FEC_E_sign_Status__c,
                FEC_Credit_Limit__c,
                FEC_OTB__c,
                FEC_Current_Balance__c,
                FEC_Hold_Amount__c,
                FEC_Total_Balance__c,
                FEC_Warning_Code__c,
                FEC_Block_Code_1__c,
                FEC_Block_Date_1__c,
                FEC_Reason_1__c,
                FEC_Block_Code_2__c,
                FEC_Block_Date_2__c,
                FEC_Reason_2__c,
                FEC_Block_Code__c,
                FEC_Block_Date__c,
                FEC_Blocked_By__c,
                FEC_Card_Activation_Status__c,
                FEC_Card_Activation_Date__c,
                FEC_E_Commerce_Status__c,
                FEC_Fraud_Monitor_Flag__c,
                FEC_Fraud_Monitor_Date__c,
                FEC_Local_Use__c,
                FEC_Available_Points__c,
                FEC_Remark__c,
                FEC_Company_Name__c,
                FEC_Sold_Date__c,
                FEC_Principal_Sold__c,
                FEC_Interest_Sold__c,
                FEC_Sold_Note__c,
                FEC_Debt_Sale_Type__c,
                FEC_Insurance_Flag__c,
                FEC_Product_Association__c,
                FEC_Customer_Segment__c,
                FEC_Scheme_Desc__c,
                FEC_Scheme_ID__c,
                FEC_Card_Number__c,
                FEC_Card_Type__c,
                FEC_Plastic_ID__c,
                FEC_Digital_Card_ID__c,
                FEC_Expiry_Date__c,
                FEC_Days_Past_Due__c
            FROM FEC_Customer_History__c
            WHERE Id = :accountId
            LIMIT 1
        ];

        if (lst.isEmpty()) return null;

        return mapToDTO(lst[0]);
    }

    /* ===================== REFRESH ===================== */

    @AuraEnabled
    public static MainInfoDTO refreshAccountInfo(Id caseId) {

        if (caseId == null) {
            throw new AuraHandledException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'Case Id'}));
        }

        Case c = [
            SELECT Id, FEC_Account_or_Contract__c, FEC_Account_Number__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];

        String accountNumber;
        String cifNumber;

        if (c.FEC_Account_or_Contract__c != null) {
            FEC_Customer_History__c acc = [
                SELECT FEC_Account_Number__c, FEC_CIF_Number__c
                FROM FEC_Customer_History__c
                WHERE Id = :c.FEC_Account_or_Contract__c
                LIMIT 1
            ];

            accountNumber = acc.FEC_Account_Number__c;
            cifNumber = acc.FEC_CIF_Number__c;
        }

        /* ========= 1. CALL GetCardBasicInfo ========= */
        FEC_GetCardBasicInfo.ResponseWrapper cardRes;

        try {
            cardRes = FEC_GetCardBasicInfo.callGetCardBasicInfo(
                FEC_CommonUltils.generateTransactionId(),
                FEC_ConstantCommon.REQUESTOR_CRM,
                Datetime.now().formatGMT(FEC_ConstantCommon.DATETIME_FORMAT),
                accountNumber
            );
        } catch (Exception e) {
            System.debug(System.Label.FEC_MSG_API_Error + e.getMessage());
            cardRes = null;
        }

        /* ========= 2. CALL CUSTOMER LIST ========= */
        FEC_GetCustomerList.ResponseWrapper cusRes;

        try {
            cusRes = FEC_GetCustomerList.getCustomerList(
                FEC_ConstantCommon.REQUESTOR_PEGA_CSM_HYPHEN,
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
        } catch (Exception e) {
            System.debug(System.Label.FEC_MSG_API_Error + e.getMessage());
            cusRes = null;
        }

        /* ========= 3. CALL FEC_GetApplicationsList ========= */
        FEC_GetApplicationsList.ResponseWrapper appRes;
        try {
                appRes = FEC_GetApplicationsList.callGetApplicationsList(
                        FEC_CommonUltils.generateTransactionId(),
                        FEC_ConstantCommon.REQUESTOR_CRM,
                        Datetime.now().format(FEC_ConstantCommon.DATETIME_FORMAT),
                        cifNumber
                    );
        } catch (Exception e) {
            System.debug(System.Label.FEC_MSG_API_Error + e.getMessage());
            appRes = null;
        }

        /* ========= 4. CALL FEC_MFASOUTSTANDINGAUTHINQ ========= */
        FEC_EmeaAccountInqService.EmeaResult emeaRes;

        try {
            FEC_EmeaAccountInqService.EmeaInput input =
                new FEC_EmeaAccountInqService.EmeaInput();

            input.context    = FEC_ConstantCommon.REQUESTOR_CONTEXT;
            input.name       = UserInfo.getUserId();
            input.org        = FEC_ConstantCommon.REQUESTOR_ORG;
            input.account    = accountNumber;
            input.dualInd    = FEC_ConstantCommon.SUCCESS_STATUS_CODE;
            input.vmxVersion = FEC_ConstantCommon.REQUESTOR_VMXVERSION_EMEA;

            emeaRes = FEC_EmeaAccountInqService.callAccountInquiry(input);

        } catch (Exception e) {
            System.debug(System.Label.FEC_MSG_API_Error + e.getMessage());
            emeaRes = null;
        }

        /* ========= 5. CALL GetCardSecInfo ========= */
        FEC_GetCardSecInfo.ResponseWrapper cardSecRes;

        try {
           cardSecRes =  FEC_GetCardSecInfo.callGetCardSecInfo(
                    FEC_CommonUltils.generateTransactionId(),
                    FEC_ConstantCommon.REQUESTOR_CRM,
                    Datetime.now().formatGMT(FEC_ConstantCommon.DATETIME_FORMAT),
                    accountNumber
                );
        } catch (Exception e) {
            System.debug(System.Label.FEC_MSG_API_Error + e.getMessage());
            cardSecRes = null;
        }

        updateAccountFromAPI(c.FEC_Account_or_Contract__c, cardRes, cusRes, emeaRes, appRes, cardSecRes);

        return getAccountInfoLocal(c.FEC_Account_or_Contract__c);
    }

    /* ===================== MAPPER ===================== */

    private static MainInfoDTO mapToDTO(FEC_Customer_History__c acc) {
        MainInfoDTO dto = new MainInfoDTO();
        dto.helpTexts = FEC_CommonUltils.buildHelpTextMap(FEC_Customer_History__c.SObjectType);
        dto.accountNumber   = acc.FEC_Account_Number__c;
        dto.contractNumber  = acc.FEC_Contract_Number__c;
        dto.accountStatus   = acc.FEC_Account_Status__c;
        dto.applicationId   = acc.FEC_Application_ID__c;
        dto.accountOpenDate = FEC_CommonUltils.formatDate(acc.FEC_Account_Open_Date__c);
        dto.creditLimit     = FEC_CommonUltils.formatCurrency(acc.FEC_Credit_Limit__c, 0);
        dto.otb             = FEC_CommonUltils.formatCurrency(acc.FEC_OTB__c, 0);
        dto.currentBalance  = FEC_CommonUltils.formatCurrency(acc.FEC_Current_Balance__c, 2);
        dto.holdAmount      = FEC_CommonUltils.formatCurrency(acc.FEC_Hold_Amount__c, 0);
        dto.totalBalance    = FEC_CommonUltils.formatCurrency(acc.FEC_Total_Balance__c, 2);
        dto.isFromAccount   = true;
        /* ===== ACCOUNT STATUS  ===== */
        dto.warningCode = acc.FEC_Warning_Code__c;
        dto.blockCode1  = acc.FEC_Block_Code_1__c;
        dto.blockDate1  = FEC_CommonUltils.formatDate(acc.FEC_Block_Date_1__c);
        dto.reason1     = acc.FEC_Reason_1__c;
        dto.blockCode2  = acc.FEC_Block_Code_2__c;
        dto.blockDate2  = FEC_CommonUltils.formatDate(acc.FEC_Block_Date_2__c);
        dto.reason2     = acc.FEC_Reason_2__c;
        dto.daysPastDue = FEC_CommonUltils.decimalToString(acc.FEC_Days_Past_Due__c);
        /* ===== CARD ===== */
        dto.cardNumber  = acc.FEC_Card_Number__c;
        dto.cardType    = acc.FEC_Card_Type__c;
        dto.plasticID   = acc.FEC_Plastic_ID__c;
        dto.digitalCardID = acc.FEC_Digital_Card_ID__c;
        dto.expiryDate    = FEC_CommonUltils.formatDate(acc.FEC_Expiry_Date__c);
        dto.schemeID    = acc.FEC_Scheme_ID__c;
        dto.schemeDesc  = acc.FEC_Scheme_Desc__c;
        dto.customerSegment = acc.FEC_Customer_Segment__c;
        dto.productAssociation  = acc.FEC_Product_Association__c;
        dto.insuranceFlag    = acc.FEC_Insurance_Flag__c;
        /* ===== CARD STATUS ===== */
        dto.cardBlockCode        = acc.FEC_Block_Code__c;
        dto.cardBlockDate        = FEC_CommonUltils.formatDate(acc.FEC_Block_Date__c);
        dto.blockedBy            = acc.FEC_Blocked_By__c;
        dto.cardActivationStatus = acc.FEC_Card_Activation_Status__c;
        dto.cardActivationDate   = FEC_CommonUltils.formatDate(acc.FEC_Card_Activation_Date__c);
        dto.eCommerceStatus      = acc.FEC_E_Commerce_Status__c;
        dto.fraudMonitorFlag     = acc.FEC_Fraud_Monitor_Flag__c;
        dto.fraudMonitorDate     = FEC_CommonUltils.formatDate(acc.FEC_Fraud_Monitor_Date__c);
        dto.localUse             = acc.FEC_Local_Use__c;
        dto.availablePoints      = FEC_CommonUltils.formatCurrency(acc.FEC_Available_Points__c, 0);
        dto.remark               = acc.FEC_Remark__c;
        /* ===== DEBT SALE ===== */
        dto.debtSaleCompanyName = acc.FEC_Company_Name__c;
        dto.debtSoldDate        = FEC_CommonUltils.formatDate(acc.FEC_Sold_Date__c);
        dto.principalSold       = FEC_CommonUltils.formatCurrency(acc.FEC_Principal_Sold__c, 2);
        dto.interestSold        = FEC_CommonUltils.formatCurrency(acc.FEC_Interest_Sold__c, 2);
        dto.soldNote            = acc.FEC_Sold_Note__c;
        dto.debtSaleType        = acc.FEC_Debt_Sale_Type__c;
        return dto;
    }

    /* ===================== HELPERS ===================== */

    private static void updateAccountFromAPI(
        Id accountId,
        FEC_GetCardBasicInfo.ResponseWrapper cardRes,
        FEC_GetCustomerList.ResponseWrapper cusRes,
        FEC_EmeaAccountInqService.EmeaResult emeaRes,
        FEC_GetApplicationsList.ResponseWrapper appRes,
        FEC_GetCardSecInfo.ResponseWrapper cardSecRes
    ) {
        if (accountId == null) return;

        FEC_GetCardBasicInfo.MainCard m;
            if(cardRes != null && cardRes.CardBasicInfo != null){
                m = cardRes.CardBasicInfo.MainCard;
            }

            Decimal dpd;
            if(cardRes != null 
                && cardRes.CardBasicInfo != null 
                && cardRes.CardBasicInfo.PassDue != null){
                dpd = cardRes.CardBasicInfo.PassDue.DPD;
            }

        FEC_GetCustomerList.Application a;
            if(cusRes != null 
                && cusRes.Customers != null 
                && !cusRes.Customers.isEmpty()
                && cusRes.Customers[0].Applications != null
                && !cusRes.Customers[0].Applications.isEmpty()){
                a = cusRes.Customers[0].Applications[0];
            }
       FEC_GetApplicationsList.ApplicationInfo l;
            if (appRes != null 
                && appRes.Applications != null 
                && !appRes.Applications.isEmpty()) {

                l = appRes.Applications[0];
            }

        FEC_GetCardSecInfo.MainCardBalance cs;

            if(cardSecRes != null 
                && cardSecRes.CardSecInfo != null
                && cardSecRes.CardSecInfo.MainCardBalance != null){
                cs = cardSecRes.CardSecInfo.MainCardBalance;
            }

        Date activationDateParsed = null;

        if (cardRes != null &&
            cardRes.CardBasicInfo != null &&
            cardRes.CardBasicInfo.CardHistories != null &&
            cardRes.CardBasicInfo.CardHistories.CardHistory != null &&
            !cardRes.CardBasicInfo.CardHistories.CardHistory.isEmpty()) {

            activationDateParsed = FEC_CommonUltils.parseDate(
                String.valueOf(cardRes.CardBasicInfo.CardHistories.CardHistory[0].CardActivationDate)
            );
        }

        Boolean ecomFlag;
            if(cardSecRes != null
                && cardSecRes.CardSecInfo != null
                && cardSecRes.CardSecInfo.MainCardPlastic != null){

                ecomFlag = cardSecRes.CardSecInfo.MainCardPlastic.EcomActiveFlag;
            }
        String localUse;
        if (emeaRes != null) {
            localUse = emeaRes.localUseInd;
        }
        
        FEC_Customer_History__c rec = new FEC_Customer_History__c(
            Id = accountId,
            FEC_Account_Number__c = m != null ? m.AccountNumber : null,
            FEC_Contract_Number__c = m != null ? m.ContractNumber : null,
            FEC_Account_Status__c = m != null ? m.Status : null,
            FEC_Credit_Limit__c = m != null ? m.CreditLimit : null,
            FEC_OTB__c = m != null ? m.OTB : null,
            FEC_Current_Balance__c = cs != null ? cs.CurrentBalance : null,
            FEC_Hold_Amount__c = m != null ? m.HoldAmount : null,
            FEC_Total_Balance__c = cs != null ? cs.TotalBalance : null,
            FEC_Application_ID__c = a != null ? a.ApplicationId : null,
            FEC_Account_Open_Date__c = l != null ? l.DateStatus : null,
            /* ===== ACCOUNT STATUS ===== */
            FEC_Warning_Code__c = m != null ? m.WarningCode : null,
            FEC_Block_Code_1__c = m != null ? m.BlockCode1 : null,
            FEC_Block_Date_1__c = m != null ? m.AccountBlockCode1Date : null,
            FEC_Reason_1__c = m != null ? m.RsnBlockCode1 : null,
            FEC_Block_Code_2__c = m != null ? m.BlockCode2 : null,
            FEC_Block_Date_2__c = m != null ? m.AccountBlockCode2Date : null,
            FEC_Reason_2__c = m != null ? m.RsnBlockCode2 : null,
            FEC_Days_Past_Due__c = dpd,
            /* ===== CARD ===== */
            FEC_Card_Number__c = m != null ? m.MaskedCardNumber : null,
            FEC_Insurance_Flag__c = m != null ? FEC_CommonUltils.normalizeInsuranceFlag(m.InsuranceFlag) : null,
            FEC_Customer_Segment__c = m != null ? m.CustomerSegment : null,
            FEC_Expiry_Date__c = m != null ? m.ExpiryDate : null,
            //FEC_Card_Type__c =  m != null ? m.DigitalCardIndicator : null,
            FEC_Plastic_ID__c = m != null ? m.PlasticIndicator : null,
            FEC_Scheme_ID__c      = a != null ? a.SchemeId : null,
            FEC_Scheme_Desc__c    = a != null ? a.SchemeDesc : null,
            /* ===== CARD STATUS ===== */
            FEC_Block_Code__c = m != null ? m.BlockCode: null,
            FEC_Block_Date__c   = m != null ? m.BlckDate : null,
            //FEC_Blocked_By__c = m
            FEC_Card_Activation_Status__c = m != null ? FEC_CommonUltils.checkActiveAndInacive(m.ActivatedFlag) : null,
            FEC_Card_Activation_Date__c = activationDateParsed,
            FEC_E_Commerce_Status__c = ecomFlag != null ? FEC_CommonUltils.checkEcomFlag(ecomFlag): null,
            FEC_Local_Use__c = localUse
            /* ===== DEBT SALE ===== */
        );
    } 
}
public with sharing class FEC_MainInfoAccountController {

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
            throw new AuraHandledException('CaseId is required');
        }

        Case c = [
            SELECT Id, FEC_Account_or_Contract__c, FEC_Account_Number__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];

        /* ========= 1. TRY LOCAL ========= */

        if (c.FEC_Account_or_Contract__c != null) {
            MainInfoDTO dto = getAccountInfoLocal(c.FEC_Account_or_Contract__c);
            if (dto != null) {
                return dto;
            }
        }

        /* ========= 2. CALL API ========= */

        FEC_GetCardBasicInfo.ResponseWrapper response;

        try {
            response = FEC_GetCardBasicInfo.callGetCardBasicInfo(
                generateTransactionId(),
                FEC_ConstantCommon.REQUESTOR_CRM,
                Datetime.now().formatGMT(FEC_ConstantCommon.DATETIME_FORMAT),
                '0001500010000000022'
            );
        } catch (Exception e) {
            throw new AuraHandledException('API ERROR: ' + e.getMessage());
        }

        FEC_Customer_History__c acc = createAccountFromAPI(response,caseId);
        update new Case(
            Id = caseId,
            FEC_Account_or_Contract__c = acc.Id
        );

        return mapToDTO(acc);
    }

    @AuraEnabled
    public static RewardEligibilityResult checkRewardEligibility(Id caseId) {
        try {
            if (caseId == null) {
                throw new AuraHandledException('Case ID is required');
            }
            
            Case c = [
                SELECT Id, FEC_Account_or_Contract__c, FEC_Account_Number__c
                FROM Case 
                WHERE Id = :caseId 
                LIMIT 1
            ];
            
            if (c.FEC_Account_or_Contract__c == null) {
                throw new AuraHandledException('No account linked to this case');
            }
            
            FEC_Customer_History__c acc = [
                SELECT FEC_Account_Number__c
                FROM FEC_Customer_History__c 
                WHERE Id = :c.FEC_Account_or_Contract__c 
                LIMIT 1
            ];
            
            String accountNumber = acc.FEC_Account_Number__c;
            if (String.isBlank(accountNumber)) {
                accountNumber = c.FEC_Account_Number__c;
            }
            
            if (String.isBlank(accountNumber)) {
                throw new AuraHandledException('Account number not found');
            }
            
            FEC_GetRewardEligibility.ResponseWrapper apiResponse = 
                FEC_GetRewardEligibility.callGetRewardEligibility(
                    generateTransactionId(),
                    FEC_ConstantCommon.REQUESTOR_CRM,
                    Datetime.now().formatGMT(FEC_ConstantCommon.DATETIME_FORMAT),
                    accountNumber
                );
            
            Boolean isEligible = (apiResponse.Sys.Code == 1);
            String remark = '';
            
            if (isEligible) {
                remark = 'Eligible for rewards program';
            } else {
                remark = apiResponse.Sys.Description != null 
                    ? apiResponse.Sys.Description 
                    : 'Failed-LMS Account is Not Available (Minimum available points should more than 50000)';
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
                ? 'Reward eligibility check successful' 
                : 'Reward eligibility check failed';
            result.availablePoints = formatCurrency(apiResponse.AvailablePoints, 0);
            result.remark = remark;
            
            return result;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error: ' + e.getMessage());
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
            throw new AuraHandledException('CaseId is required');
        }

        Case c = [
            SELECT Id, FEC_Account_or_Contract__c, FEC_Account_Number__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];

        FEC_GetCardBasicInfo.ResponseWrapper response;

        try {
            response = FEC_GetCardBasicInfo.callGetCardBasicInfo(
                generateTransactionId(),
                FEC_ConstantCommon.REQUESTOR_CRM,
                Datetime.now().formatGMT(FEC_ConstantCommon.DATETIME_FORMAT),
                '0001500010000000022'
            );
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }

        updateAccountFromAPI(c.FEC_Account_or_Contract__c, response);

        return getAccountInfoLocal(c.FEC_Account_or_Contract__c);
    }


    /* ===================== MAPPER ===================== */

    private static MainInfoDTO mapToDTO(FEC_Customer_History__c acc) {
        MainInfoDTO dto = new MainInfoDTO();
        dto.helpTexts = buildHelpTextMap();
        dto.accountNumber   = acc.FEC_Account_Number__c;
        dto.contractNumber  = acc.FEC_Contract_Number__c;
        dto.accountStatus   = acc.FEC_Account_Status__c;
        dto.applicationId   = acc.FEC_Application_ID__c;
        dto.accountOpenDate = formatDate(acc.FEC_Account_Open_Date__c);
        dto.accountCloseDate= formatDate(acc.FEC_Account_Close_Date__c);
        dto.eSignStatus     = acc.FEC_E_sign_Status__c;
        dto.creditLimit     = formatCurrency(acc.FEC_Credit_Limit__c, 0);
        dto.otb             = formatCurrency(acc.FEC_OTB__c, 0);
        dto.currentBalance  = formatCurrency(acc.FEC_Current_Balance__c, 2);
        dto.holdAmount      = formatCurrency(acc.FEC_Hold_Amount__c, 0);
        dto.totalBalance    = formatCurrency(acc.FEC_Total_Balance__c, 2);
        dto.isFromAccount   = true;
        /* ===== ACCOUNT STATUS  ===== */
        dto.warningCode = acc.FEC_Warning_Code__c;
        dto.blockCode1  = acc.FEC_Block_Code_1__c;
        dto.blockDate1  = formatDate(acc.FEC_Block_Date_1__c);
        dto.reason1     = acc.FEC_Reason_1__c;
        dto.blockCode2  = acc.FEC_Block_Code_2__c;
        dto.blockDate2  = formatDate(acc.FEC_Block_Date_2__c);
        dto.reason2     = acc.FEC_Reason_2__c;
        dto.daysPastDue = decimalToString(acc.FEC_Days_Past_Due__c);
        /* ===== CARD ===== */
        dto.cardNumber  = acc.FEC_Card_Number__c;
        dto.cardType    = acc.FEC_Card_Type__c;
        dto.plasticID   = acc.FEC_Plastic_ID__c;
        dto.digitalCardID = acc.FEC_Digital_Card_ID__c;
        dto.expiryDate    = formatDate(acc.FEC_Expiry_Date__c);
        dto.schemeID    = acc.FEC_Scheme_ID__c;
        dto.schemeDesc  = acc.FEC_Scheme_Desc__c;
        dto.customerSegment = acc.FEC_Customer_Segment__c;
        dto.productAssociation  = acc.FEC_Product_Association__c;
        dto.insuranceFlag    = acc.FEC_Insurance_Flag__c;
        /* ===== CARD STATUS ===== */
        dto.cardBlockCode        = acc.FEC_Block_Code__c;
        dto.cardBlockDate        = formatDate(acc.FEC_Block_Date__c);
        dto.blockedBy            = acc.FEC_Blocked_By__c;
        dto.cardActivationStatus = acc.FEC_Card_Activation_Status__c;
        dto.cardActivationDate   = formatDate(acc.FEC_Card_Activation_Date__c);
        dto.eCommerceStatus      = acc.FEC_E_Commerce_Status__c;
        dto.fraudMonitorFlag     = acc.FEC_Fraud_Monitor_Flag__c;
        dto.fraudMonitorDate     = formatDate(acc.FEC_Fraud_Monitor_Date__c);
        dto.localUse             = acc.FEC_Local_Use__c;
        dto.availablePoints      = formatCurrency(acc.FEC_Available_Points__c, 0);
        dto.remark               = acc.FEC_Remark__c;
        /* ===== DEBT SALE ===== */
        dto.debtSaleCompanyName = acc.FEC_Company_Name__c;
        dto.debtSoldDate        = formatDate(acc.FEC_Sold_Date__c);
        dto.principalSold       = formatCurrency(acc.FEC_Principal_Sold__c, 2);
        dto.interestSold        = formatCurrency(acc.FEC_Interest_Sold__c, 2);
        dto.soldNote            = acc.FEC_Sold_Note__c;
        dto.debtSaleType        = acc.FEC_Debt_Sale_Type__c;
        return dto;
    }

    /* ===================== HELPERS ===================== */

    private static FEC_Customer_History__c createAccountFromAPI(
        FEC_GetCardBasicInfo.ResponseWrapper response,
        Id caseId
    ) {
        FEC_GetCardBasicInfo.MainCard m = response.CardBasicInfo.MainCard;

        FEC_Customer_History__c acc = new FEC_Customer_History__c(
            FEC_Case__c = caseId,
            Name = 'Account ' + m.AccountNumber,
            FEC_Account_Number__c = m.AccountNumber,
            FEC_Contract_Number__c = m.ContractNumber,
           // FEC_Account_Status__c = m.Status,
            FEC_Credit_Limit__c = m.CreditLimit,
            FEC_OTB__c = m.OTB,
            FEC_Current_Balance__c = response.CardBasicInfo.Statement?.StatementBalance,
            FEC_Hold_Amount__c = m.HoldAmount,
            FEC_Total_Balance__c = response.CardBasicInfo.Statement?.StatementBalance,
            //FEC_Application_ID__c = m.BlockCode1,
            //FEC_Account_Open_Date__c = m.AccountBlockCode2Date,
            //FEC_Account_Close_Date__c = m.ExpiryDate,
            FEC_E_sign_Status__c = 'Yes',

            /* ===== ACCOUNT STATUS ===== */
            FEC_Warning_Code__c = m.WarningCode,
            FEC_Block_Code_1__c = m.BlockCode1,
            FEC_Block_Date_1__c = m.AccountBlockCode1Date,
            FEC_Reason_1__c     = m.RsnBlockCode1,
            FEC_Block_Code_2__c = m.BlockCode2,
            FEC_Block_Date_2__c = m.AccountBlockCode2Date,
            FEC_Reason_2__c     = m.RsnBlockCode2,
            //FEC_Days_Past_Due__c = m.,

            /* ===== CARD ===== */
            FEC_Insurance_Flag__c = m.InsuranceFlag,
            //FEC_Product_Association__c = m.ProductAssociation,
            FEC_Customer_Segment__c = m.CustomerSegment,
            //FEC_Scheme_Desc__c = m.
            // FEC_Scheme_ID__c = m.
            //FEC_Card_Number__c
            //FEC_Card_Type__c = m.
            //FEC_Plastic_ID__c = m.
            //FEC_Digital_Card_ID__c = m.
            FEC_Expiry_Date__c = m.ExpiryDate
            /* ===== CARD STATUS ===== */
            //FEC_Block_Code__c            = m.
            //FEC_Block_Date__c         = m.FEC_Block_Date__c,
            //FEC_Blocked_By__c      = m.FEC_Blocked_By__c,
            //FEC_Card_Activation_Status__c          = m.cardActivationStatus == 'Active' ? 'Active':'Inactive'
            //FEC_Card_Activation_Date__c  = m.FEC_Card_Activation_Date__c,
            //FEC_ECommerce_Status__c    = m.FEC_ECommerce_Status__c,
            //FEC_Fraud_Monitor_Flag__c        = m.FEC_Fraud_Monitor_Flag__c,
            //FEC_Fraud_Monitor_Date__c      = m.FEC_Fraud_Monitor_Date__c,
            //FEC_Local_Use__c      = m.FEC_Local_Use__c,
            //FEC_Rewards_Eligibility__c = m.FEC_Rewards_Eligibility__c
            //FEC_Remark__c                  = m.FEC_Remark__c
            /* ===== DEBT SALE ===== */
            //FEC_Company_Name__c = m.FEC_Company_Name__c
            //FEC_Sold_Date__c = m.FEC_Sold_Date__c
            //FEC_Principal_Sold__c = m.FEC_Principal_Sold__c
            //FEC_Interest_Sold__c = m.FEC_Interest_Sold__c
            //FEC_Sold_Note__c =m.FEC_Sold_Note__c
            //FEC_Debt_Sale_Type__c =m.FEC_Debt_Sale_Type__c
        );

        insert acc;
        return acc;
    }

    private static void updateAccountFromAPI(
        Id accountId,
        FEC_GetCardBasicInfo.ResponseWrapper response
    ) {
        if (accountId == null) return;

        FEC_GetCardBasicInfo.MainCard m = response.CardBasicInfo.MainCard;

        update new FEC_Customer_History__c(
            Id = accountId,
            FEC_Account_Number__c = m.AccountNumber,
            FEC_Contract_Number__c = m.ContractNumber,
           // FEC_Account_Status__c = m.Status,
            FEC_Credit_Limit__c = m.CreditLimit,
            FEC_OTB__c = m.OTB,
            FEC_Current_Balance__c = response.CardBasicInfo.Statement?.StatementBalance,
            FEC_Hold_Amount__c = m.HoldAmount,
            FEC_Total_Balance__c = response.CardBasicInfo.Statement?.StatementBalance,
            FEC_E_sign_Status__c = 'Yes',
            /* ===== ACCOUNT STATUS ===== */
            FEC_Warning_Code__c = m.WarningCode,
            FEC_Block_Code_1__c = m.BlockCode1,
            FEC_Block_Date_1__c = m.AccountBlockCode1Date,
            FEC_Reason_1__c     = m.RsnBlockCode1,
            FEC_Block_Code_2__c = m.BlockCode2,
            FEC_Block_Date_2__c = m.AccountBlockCode2Date,
            FEC_Reason_2__c     = m.RsnBlockCode2,
            //FEC_Days_Past_Due__c = m.,
            /* ===== CARD ===== */
            FEC_Insurance_Flag__c = m.InsuranceFlag,
            //FEC_Product_Association__c = m.ProductAssociation,
            FEC_Customer_Segment__c = m.CustomerSegment,
            //FEC_Scheme_Desc__c = m.
            // FEC_Scheme_ID__c = m.
            //FEC_Card_Number__c
            //FEC_Card_Type__c = m.
            //FEC_Plastic_ID__c = m.
            //FEC_Digital_Card_ID__c = m.
            FEC_Expiry_Date__c = m.ExpiryDate
            /* ===== CARD STATUS ===== */
            //FEC_Block_Code__c            = m.
            //FEC_Block_Date__c         = m.FEC_Block_Date__c,
            //FEC_Blocked_By__c      = m.FEC_Blocked_By__c,
            //FEC_Card_Activation_Status__c          = m.cardActivationStatus == 'Active' ? 'Active':'Inactive'
            //FEC_Card_Activation_Date__c  = m.FEC_Card_Activation_Date__c,
            //FEC_ECommerce_Status__c    = m.FEC_ECommerce_Status__c,
            //FEC_Fraud_Monitor_Flag__c        = m.FEC_Fraud_Monitor_Flag__c,
            //FEC_Fraud_Monitor_Date__c      = m.FEC_Fraud_Monitor_Date__c,
            //FEC_Local_Use__c      = m.FEC_Local_Use__c,
            //FEC_Rewards_Eligibility__c = m.FEC_Rewards_Eligibility__c
            //FEC_Remark__c                  = m.FEC_Remark__c
            /* ===== DEBT SALE ===== */
            //FEC_Company_Name__c = m.FEC_Company_Name__c
            //FEC_Sold_Date__c = m.FEC_Sold_Date__c
            //FEC_Principal_Sold__c = m.FEC_Principal_Sold__c
            //FEC_Interest_Sold__c = m.FEC_Interest_Sold__c
            //FEC_Sold_Note__c =m.FEC_Sold_Note__c
            //FEC_Debt_Sale_Type__c =m.FEC_Debt_Sale_Type__c
        );
    }
    /* ===================== HELP TEXT RESOLVER ===================== */
    private static Map<String, String> buildHelpTextMap() {
        Map<String, String> result = new Map<String, String>();

        Map<String, Schema.SObjectField> fieldMap =
            FEC_Customer_History__c.SObjectType
                .getDescribe()
                .fields.getMap();

        for (String fieldName : fieldMap.keySet()) {
            String helpText =
                fieldMap.get(fieldName)
                        .getDescribe()
                        .getInlineHelpText();

            if (String.isNotBlank(helpText)) {
                result.put(fieldName, helpText);
            }
        }
        return result;
    }

    private static String generateTransactionId() {
        return Datetime.now().getTime() + '_' +
               String.valueOf(Math.abs(Crypto.getRandomInteger())).substring(0, 6);
    }

    private static String formatDate(Date d) {
        if (d == null) return '';
        return d.format();
    }

    private static String formatCurrency(Decimal amount, Integer scale) {
        if (amount == null) return '';
        return amount.setScale(scale).format();
    }
    private static String decimalToString(Decimal d) {
        return d == null ? '' : d.format();
    }
}
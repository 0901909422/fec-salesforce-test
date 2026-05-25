public with sharing class FEC_CardPaymentController {
    
    /** DTO */
    public class CardPaymentTotalsDTO {
        @AuraEnabled public Map<String, String> helpTexts;
        @AuraEnabled public Decimal fullPaymentAmount;
        @AuraEnabled public Decimal loanBalance;
        @AuraEnabled public Decimal fullPaymentWithoutIPP;
        @AuraEnabled public Decimal fullIPPPaymentAmount;
        @AuraEnabled public Decimal totalCurrentBalance;
        @AuraEnabled public Decimal totalCloseFeeAmount;
        @AuraEnabled public Decimal totalPlanPaymentAmount;
        @AuraEnabled public Decimal totalAccruedInterest;
        @AuraEnabled public Decimal totalIPPAccruedInterest;
        @AuraEnabled public Decimal totalPerDiem;
        @AuraEnabled public Decimal totalDeferredInterest;
    }
    
    /** Tải Card Payment: query DB → gọi API mỗi lần load; save chỉ INSERT mới (key Rec+Plan). */
    @AuraEnabled(cacheable=false)
    public static List<Map<String, Object>> loadCardPaymentInfo(Id caseId) {
        if (caseId == null) {
            throw new AuraHandledException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'Case Id'}));
        }

        Case c = [SELECT Id, FEC_Account_or_Contract__c, FEC_Account_Number__c, FEC_Account_or_Contract__r.FEC_Account_Number__c FROM Case WHERE Id = :caseId LIMIT 1];
        Id customerHistoryId = c.FEC_Account_or_Contract__c;
        String accountNumber = getAccountNumber(c);
        List<Map<String, Object>> records = new List<Map<String, Object>>();
        try {
            List<FEC_Card_Payment__c> payments = [
                SELECT FEC_Rec__c, FEC_Plan__c, FEC_REF_Number__c, FEC_Current_Balance__c, FEC_Open_Date__c,
                       FEC_Base_Rate__c, FEC_Begin_Date__c, FEC_Accrued_Interest__c, FEC_Per_Diem__c,
                       FEC_Deferred_Interest__c, FEC_IPP_Interest__c, FEC_IPP_Accrued_Interest__c,
                       FEC_Close_Fee__c, FEC_Close_Fee_Amount__c, FEC_Plan_Payment_Amount__c
                FROM FEC_Card_Payment__c
                WHERE FEC_Customer_History__c = :customerHistoryId
                ORDER BY FEC_Open_Date__c DESC NULLS LAST
            ];
            for (FEC_Card_Payment__c p : payments) {
                records.add(buildCardPaymentRecordMap(p));
            }
        } catch (Exception e) { }

        // Mock OFF: gọi GetCardPlanInfo, save DB; Mock ON: fallback hardcode
        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        if (apiSetting != null && apiSetting.FEC_Call_Mock__c == false) {
            try {
                if (String.isNotBlank(accountNumber)) {
                    Id custHistoryId = customerHistoryId;
                    if (custHistoryId == null) {
                        List<FEC_Customer_History__c> histories = [SELECT Id FROM FEC_Customer_History__c WHERE FEC_Account_Number__c = :accountNumber LIMIT 1];
                        if (!histories.isEmpty()) { custHistoryId = histories[0].Id; }
                    }
                    if (custHistoryId != null) {
                        FEC_GetCardPlanInfo.CardPlanResult apiResult = FEC_GetCardPlanInfo.getCardPlanInfo(accountNumber);
                        if (apiResult != null && apiResult.responseCode == '1' && apiResult.plans != null && !apiResult.plans.isEmpty()) {
                            saveCardPlanToDatabase(apiResult.plans, accountNumber, custHistoryId);
                            List<FEC_Card_Payment__c> payments = [
                                SELECT FEC_Rec__c, FEC_REF_Number__c, FEC_Current_Balance__c, FEC_Open_Date__c, FEC_Plan__c, FEC_Base_Rate__c,
                                       FEC_Begin_Date__c, FEC_Accrued_Interest__c, FEC_Per_Diem__c, FEC_Deferred_Interest__c, FEC_IPP_Interest__c,
                                       FEC_IPP_Accrued_Interest__c, FEC_Close_Fee__c, FEC_Close_Fee_Amount__c, FEC_Plan_Payment_Amount__c
                                FROM FEC_Card_Payment__c
                                WHERE FEC_Customer_History__c = :custHistoryId
                                ORDER BY FEC_Open_Date__c DESC NULLS LAST
                            ];
                            records = new List<Map<String, Object>>();
                            for (FEC_Card_Payment__c p : payments) {
                                records.add(buildCardPaymentRecordMap(p));
                            }
                            if (!records.isEmpty()) {
                                return records;
                            }
                        }
                    }
                }
            } catch (Exception e) {
                System.debug('Mock GetCardPlanInfo error: ' + e.getMessage());
            }
            return FEC_MockData.getHardcodedCardPaymentRecordsForUI();
        }

        // Gọi GetCardPlanInfo mỗi lần load
        if (String.isBlank(accountNumber)) {
            return records;
        }

        try {
            FEC_GetCardPlanInfo.CardPlanResult apiResult = FEC_GetCardPlanInfo.getCardPlanInfo(accountNumber);
            if (apiResult != null && apiResult.responseCode == '1' && !apiResult.plans.isEmpty()) {
                saveCardPlanToDatabase(apiResult.plans, accountNumber, customerHistoryId);
            }
        } catch (Exception e) {
            System.debug('### GetCardPlanInfo API FAILED: ' + e.getMessage());
        }

        try {
            List<FEC_Card_Payment__c> payments = [
                SELECT FEC_Rec__c, FEC_Plan__c, FEC_REF_Number__c, FEC_Current_Balance__c, FEC_Open_Date__c,
                       FEC_Base_Rate__c, FEC_Begin_Date__c, FEC_Accrued_Interest__c, FEC_Per_Diem__c,
                       FEC_Deferred_Interest__c, FEC_IPP_Interest__c, FEC_IPP_Accrued_Interest__c,
                       FEC_Close_Fee__c, FEC_Close_Fee_Amount__c, FEC_Plan_Payment_Amount__c
                FROM FEC_Card_Payment__c
                WHERE FEC_Customer_History__c = :customerHistoryId
                ORDER BY FEC_Open_Date__c DESC NULLS LAST
            ];
            records = new List<Map<String, Object>>();
            for (FEC_Card_Payment__c p : payments) {
                records.add(buildCardPaymentRecordMap(p));
            }
        } catch (Exception e) { }
        return records;
    }

    /** Account Number: ưu tiên lookup FEC_Account_or_Contract__, fallback Case.FEC_Account_Number__c */
    private static String getAccountNumber(Case c) {
        if (c.FEC_Account_or_Contract__c != null) {
            FEC_Customer_History__c h = [
                SELECT FEC_Account_Number__c
                FROM FEC_Customer_History__c
                WHERE Id = :c.FEC_Account_or_Contract__c
                LIMIT 1
            ];
            if (String.isNotBlank(h.FEC_Account_Number__c)) {
                return h.FEC_Account_Number__c;
            }
        }
        return c.FEC_Account_Number__c;
    }

    /** Map FEC_Card_Payment__c → Map cho LWC */
    private static Map<String, Object> buildCardPaymentRecordMap(FEC_Card_Payment__c p) {
        Map<String, Object> record = new Map<String, Object>();
        record.put('FEC_Rec__c', p.FEC_Rec__c);
        record.put('FEC_REF_Number__c', p.FEC_REF_Number__c);
        record.put('FEC_Current_Balance__c', p.FEC_Current_Balance__c);
        record.put('FEC_Open_Date__c', p.FEC_Open_Date__c);
        record.put('FEC_Plan__c', p.FEC_Plan__c);
        record.put('FEC_Base_Rate__c', p.FEC_Base_Rate__c);
        record.put('FEC_Begin_Date__c', p.FEC_Begin_Date__c);
        record.put('FEC_Accrued_Interest__c', p.FEC_Accrued_Interest__c);
        record.put('FEC_Per_Diem__c', p.FEC_Per_Diem__c);
        record.put('FEC_Deferred_Interest__c', p.FEC_Deferred_Interest__c);
        record.put('FEC_IPP_Interest__c', p.FEC_IPP_Interest__c);
        record.put('FEC_IPP_Accrued_Interest__c', p.FEC_IPP_Accrued_Interest__c);
        record.put('FEC_Close_Fee__c', p.FEC_Close_Fee__c);
        record.put('FEC_Close_Fee_Amount__c', p.FEC_Close_Fee_Amount__c);
        record.put('FEC_Plan_Payment_Amount__c', p.FEC_Plan_Payment_Amount__c);
        return record;
    }
    
    /** Wrapper loadCardPaymentInfo() cho backward compatibility */
    @AuraEnabled(cacheable=false)
    public static List<Map<String, Object>> getCardPaymentRecords(String caseId) {
        return loadCardPaymentInfo(caseId);
    }
    
    /** Tải Card Payment Totals: query DB → gọi API mỗi lần load. */
    @AuraEnabled(cacheable=false)
    public static CardPaymentTotalsDTO loadCardPaymentTotals(Id caseId) {
        if (caseId == null) {
            throw new AuraHandledException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'Case Id'}));
        }

        CardPaymentTotalsDTO dto = new CardPaymentTotalsDTO();
        dto.fullPaymentAmount = 0;
        dto.loanBalance = 0;
        dto.fullPaymentWithoutIPP = 0;
        dto.fullIPPPaymentAmount = 0;
        dto.totalCurrentBalance = 0;
        dto.totalCloseFeeAmount = 0;
        dto.totalPlanPaymentAmount = 0;
        dto.totalAccruedInterest = 0;
        dto.totalIPPAccruedInterest = 0;
        dto.totalPerDiem = 0;
        dto.totalDeferredInterest = 0;
        dto.helpTexts = FEC_CommonUltils.buildHelpTextMap(FEC_Card_Payment__c.SObjectType);

        Case c = [SELECT Id, FEC_Account_or_Contract__c, FEC_Account_Number__c, FEC_Account_or_Contract__r.FEC_Account_Number__c FROM Case WHERE Id = :caseId LIMIT 1];
        Id customerHistoryId = c.FEC_Account_or_Contract__c;
        String accountNumber = getAccountNumber(c);
        if (customerHistoryId == null) return dto;

        Boolean needOnlyAggregateAndSaveSeven = false;
        try {
            List<FEC_Card_Payment__c> cardPayments = [
                SELECT FEC_Full_Payment_Amount__c, FEC_Loan_Balance__c, FEC_Full_Payment_Without_IPP__c, FEC_Full_IPP_Payment_Amount__c,
                       FEC_Total_Current_Balance__c, FEC_Total_Close_Fee_Amount__c, FEC_Total_Plan_Payment_Amount__c,
                       FEC_Total_Accrued_Interest__c, FEC_Total_IPP_Accrued_Interest__c, FEC_Total_Per_Diem__c, FEC_Total_Deferred_Interest__c
                FROM FEC_Card_Payment__c
                WHERE FEC_Customer_History__c = :customerHistoryId
                  AND (FEC_Full_Payment_Amount__c != null OR FEC_Loan_Balance__c != null OR FEC_Full_Payment_Without_IPP__c != null OR FEC_Full_IPP_Payment_Amount__c != null
                       OR FEC_Total_Current_Balance__c != null OR FEC_Total_Close_Fee_Amount__c != null OR FEC_Total_Plan_Payment_Amount__c != null
                       OR FEC_Total_Accrued_Interest__c != null OR FEC_Total_IPP_Accrued_Interest__c != null OR FEC_Total_Per_Diem__c != null OR FEC_Total_Deferred_Interest__c != null)
                ORDER BY CreatedDate ASC
                LIMIT 1
            ];

            if (!cardPayments.isEmpty()) {
                FEC_Card_Payment__c payment = cardPayments[0];
                dto.fullPaymentAmount = payment.FEC_Full_Payment_Amount__c != null ? payment.FEC_Full_Payment_Amount__c : 0;
                dto.loanBalance = payment.FEC_Loan_Balance__c != null ? payment.FEC_Loan_Balance__c : 0;
                dto.fullPaymentWithoutIPP = payment.FEC_Full_Payment_Without_IPP__c != null ? payment.FEC_Full_Payment_Without_IPP__c : 0;
                dto.fullIPPPaymentAmount = payment.FEC_Full_IPP_Payment_Amount__c != null ? payment.FEC_Full_IPP_Payment_Amount__c : 0;
                dto.totalCurrentBalance = payment.FEC_Total_Current_Balance__c != null ? payment.FEC_Total_Current_Balance__c : 0;
                dto.totalCloseFeeAmount = payment.FEC_Total_Close_Fee_Amount__c != null ? payment.FEC_Total_Close_Fee_Amount__c : 0;
                dto.totalPlanPaymentAmount = payment.FEC_Total_Plan_Payment_Amount__c != null ? payment.FEC_Total_Plan_Payment_Amount__c : 0;
                dto.totalAccruedInterest = payment.FEC_Total_Accrued_Interest__c != null ? payment.FEC_Total_Accrued_Interest__c : 0;
                dto.totalIPPAccruedInterest = payment.FEC_Total_IPP_Accrued_Interest__c != null ? payment.FEC_Total_IPP_Accrued_Interest__c : 0;
                dto.totalPerDiem = payment.FEC_Total_Per_Diem__c != null ? payment.FEC_Total_Per_Diem__c : 0;
                dto.totalDeferredInterest = payment.FEC_Total_Deferred_Interest__c != null ? payment.FEC_Total_Deferred_Interest__c : 0;
                Boolean hasAllSeven = payment.FEC_Total_Current_Balance__c != null && payment.FEC_Total_Close_Fee_Amount__c != null && payment.FEC_Total_Plan_Payment_Amount__c != null
                    && payment.FEC_Total_Accrued_Interest__c != null && payment.FEC_Total_IPP_Accrued_Interest__c != null && payment.FEC_Total_Per_Diem__c != null && payment.FEC_Total_Deferred_Interest__c != null;
                if (!hasAllSeven) {
                    needOnlyAggregateAndSaveSeven = true;
                }
            }
        } catch (Exception e) { }
        if (needOnlyAggregateAndSaveSeven) {
            Decimal totalCurrentBalance = 0;
            Decimal totalCloseFeeAmount = 0;
            Decimal totalPlanPaymentAmount = 0;
            Decimal totalAccruedInterest = 0;
            Decimal totalIPPAccruedInterest = 0;
            Decimal totalPerDiem = 0;
            Decimal totalDeferredInterest = 0;
            try {
                List<AggregateResult> agg = [
                    SELECT SUM(FEC_Current_Balance__c) s1, SUM(FEC_Close_Fee_Amount__c) s2, SUM(FEC_Plan_Payment_Amount__c) s3,
                           SUM(FEC_Accrued_Interest__c) s4, SUM(FEC_IPP_Accrued_Interest__c) s5, SUM(FEC_Per_Diem__c) s6, SUM(FEC_Deferred_Interest__c) s7
                    FROM FEC_Card_Payment__c
                    WHERE FEC_Customer_History__c = :customerHistoryId
                ];
                if (!agg.isEmpty()) {
                    totalCurrentBalance = agg[0].get('s1') != null ? (Decimal) agg[0].get('s1') : 0;
                    totalCloseFeeAmount = agg[0].get('s2') != null ? (Decimal) agg[0].get('s2') : 0;
                    totalPlanPaymentAmount = agg[0].get('s3') != null ? (Decimal) agg[0].get('s3') : 0;
                    totalAccruedInterest = agg[0].get('s4') != null ? (Decimal) agg[0].get('s4') : 0;
                    totalIPPAccruedInterest = agg[0].get('s5') != null ? (Decimal) agg[0].get('s5') : 0;
                    totalPerDiem = agg[0].get('s6') != null ? (Decimal) agg[0].get('s6') : 0;
                    totalDeferredInterest = agg[0].get('s7') != null ? (Decimal) agg[0].get('s7') : 0;
                }
            } catch (Exception e) {
                System.debug('Aggregate 7 totals error: ' + e.getMessage());
            }
            saveCardPaymentTotalsToDatabase(customerHistoryId, dto.fullPaymentAmount, dto.loanBalance, dto.fullPaymentWithoutIPP, dto.fullIPPPaymentAmount,
                    totalCurrentBalance, totalCloseFeeAmount, totalPlanPaymentAmount, totalAccruedInterest, totalIPPAccruedInterest, totalPerDiem, totalDeferredInterest);
            try {
                List<FEC_Card_Payment__c> cardPayments = [
                    SELECT FEC_Full_Payment_Amount__c, FEC_Loan_Balance__c, FEC_Full_Payment_Without_IPP__c, FEC_Full_IPP_Payment_Amount__c,
                           FEC_Total_Current_Balance__c, FEC_Total_Close_Fee_Amount__c, FEC_Total_Plan_Payment_Amount__c,
                           FEC_Total_Accrued_Interest__c, FEC_Total_IPP_Accrued_Interest__c, FEC_Total_Per_Diem__c, FEC_Total_Deferred_Interest__c
                    FROM FEC_Card_Payment__c
                    WHERE FEC_Customer_History__c = :customerHistoryId
                    ORDER BY CreatedDate ASC
                    LIMIT 1
                ];
                if (!cardPayments.isEmpty()) {
                    FEC_Card_Payment__c payment = cardPayments[0];
                    dto.totalCurrentBalance = payment.FEC_Total_Current_Balance__c != null ? payment.FEC_Total_Current_Balance__c : 0;
                    dto.totalCloseFeeAmount = payment.FEC_Total_Close_Fee_Amount__c != null ? payment.FEC_Total_Close_Fee_Amount__c : 0;
                    dto.totalPlanPaymentAmount = payment.FEC_Total_Plan_Payment_Amount__c != null ? payment.FEC_Total_Plan_Payment_Amount__c : 0;
                    dto.totalAccruedInterest = payment.FEC_Total_Accrued_Interest__c != null ? payment.FEC_Total_Accrued_Interest__c : 0;
                    dto.totalIPPAccruedInterest = payment.FEC_Total_IPP_Accrued_Interest__c != null ? payment.FEC_Total_IPP_Accrued_Interest__c : 0;
                    dto.totalPerDiem = payment.FEC_Total_Per_Diem__c != null ? payment.FEC_Total_Per_Diem__c : 0;
                    dto.totalDeferredInterest = payment.FEC_Total_Deferred_Interest__c != null ? payment.FEC_Total_Deferred_Interest__c : 0;
                }
            } catch (Exception e) { }
            return dto;
        }

        // Gọi 4 API mỗi lần load: GetCardPaymentInfo, GetCardBasicInfo, EmeaAccountInq, GetCardPlanInfo
        if (String.isBlank(accountNumber)) return dto;
        FEC_API_Setting__c apiSettingTotals = FEC_API_Setting__c.getOrgDefaults();
        Boolean isMockTotals = (apiSettingTotals != null && apiSettingTotals.FEC_Call_Mock__c == true);

        try {
            Decimal fullPaymentAmount = 0;
            Decimal loanBalance = 0;
            Decimal fullPaymentWithoutIPP = 0;

        try {
            FEC_GetCardPaymentInfo.CardPaymentResult paymentResult = 
                FEC_GetCardPaymentInfo.getCardPaymentInfo(accountNumber, Date.today());
            
            if (paymentResult != null && paymentResult.fullPaymentAmount != null) {
                fullPaymentAmount = paymentResult.fullPaymentAmount;
            }
        } catch (Exception e) {
            System.debug('GetCardPaymentInfo API error: ' + e.getMessage());
        }

        try {
            String transId = UUID.randomUUID().toString();
            String requestorId = FEC_ConstantCommon.REQUESTOR_CRM;
            String dateTimeStr = Datetime.now().format(FEC_ConstantCommon.DATETIME_FORMAT);
            
            FEC_GetCardBasicInfo.ResponseWrapper basicInfoResult = 
                FEC_GetCardBasicInfo.callGetCardBasicInfo(transId, requestorId, dateTimeStr, accountNumber);
            
            if (basicInfoResult != null && 
                basicInfoResult.CardBasicInfo != null && 
                basicInfoResult.CardBasicInfo.MainCard != null &&
                basicInfoResult.CardBasicInfo.MainCard.LoanBalance != null) {
                loanBalance = basicInfoResult.CardBasicInfo.MainCard.LoanBalance;
            }
        } catch (Exception e) {
            System.debug('GetCardBasicInfo API error: ' + e.getMessage());
        }

        try {
            Decimal onlineTotalBalance = 0;
            try {
                FEC_EmeaAccountInqService.EmeaInput emeaInput = new FEC_EmeaAccountInqService.EmeaInput();
                emeaInput.context = 'ACCOUNT';
                emeaInput.name = 'ACCOUNT_INQ';
                emeaInput.org = 'FEC';
                emeaInput.account = accountNumber;
                
                FEC_EmeaAccountInqService.EmeaResult emeaResult = 
                    FEC_EmeaAccountInqService.callAccountInquiry(emeaInput);
                
                if (emeaResult != null && emeaResult.responseCode == '1') {
                    Decimal currBal = emeaResult.currBal != null ? emeaResult.currBal : 0;
                    Decimal amtMemoDb = emeaResult.amtMemoDb != null ? emeaResult.amtMemoDb : 0;
                    Decimal amtMemoCr = emeaResult.amtMemoCr != null ? emeaResult.amtMemoCr : 0;
                    onlineTotalBalance = currBal + amtMemoDb - amtMemoCr;
                }
            } catch (Exception e) {
                System.debug('M_CMS_EMEA_ACCOUNT_INQ API error: ' + e.getMessage());
            }

            Decimal totalDeferredInterestPlan = 0;
            Decimal totalAccuredInterestPlan = 0;
            Decimal totalPerDiemPlan = 0;
            
            try {
                FEC_GetCardPlanInfo.CardPlanResult planResult = 
                    FEC_GetCardPlanInfo.getCardPlanInfo(accountNumber);
                
                if (planResult != null && planResult.responseCode == '1' && planResult.plans != null) {
                    for (FEC_GetCardPlanInfo.CardPlan plan : planResult.plans) {
                        if (String.isNotBlank(plan.planNumber) && !plan.planNumber.startsWith('9')) {
                            if (plan.deferredInterest != null) {
                                totalDeferredInterestPlan += plan.deferredInterest;
                            }
                            if (plan.accruedInterest != null) {
                                totalAccuredInterestPlan += plan.accruedInterest / 100;
                            }
                            if (plan.perDiem != null) {
                                totalPerDiemPlan += plan.perDiem / 100;
                            }
                        }
                    }
                }
            } catch (Exception e) {
                System.debug('GetCardPlanInfo API error: ' + e.getMessage());
            }

            fullPaymentWithoutIPP = onlineTotalBalance + totalDeferredInterestPlan + totalAccuredInterestPlan + totalPerDiemPlan - loanBalance;
        } catch (Exception e) {
            System.debug('Calculate Full Payment Without IPP error: ' + e.getMessage());
        }

        /* ===== 4. Tính Full IPP Payment Amount ===== */
        Decimal fullIPPPaymentAmount = 0;
        if (fullPaymentAmount != 0 && fullPaymentWithoutIPP != 0) {
            // Full IPP Payment Amount = Full Payment Amount - Full Payment Without IPP
            fullIPPPaymentAmount = fullPaymentAmount - fullPaymentWithoutIPP;
        }

        Decimal totalCurrentBalance = 0;
        Decimal totalCloseFeeAmount = 0;
        Decimal totalPlanPaymentAmount = 0;
        Decimal totalAccruedInterest = 0;
        Decimal totalIPPAccruedInterest = 0;
        Decimal totalPerDiem = 0;
        Decimal totalDeferredInterest = 0;
        try {
            List<AggregateResult> agg = [
                SELECT SUM(FEC_Current_Balance__c) s1, SUM(FEC_Close_Fee_Amount__c) s2, SUM(FEC_Plan_Payment_Amount__c) s3,
                       SUM(FEC_Accrued_Interest__c) s4, SUM(FEC_IPP_Accrued_Interest__c) s5, SUM(FEC_Per_Diem__c) s6, SUM(FEC_Deferred_Interest__c) s7
                FROM FEC_Card_Payment__c
                WHERE FEC_Customer_History__c = :customerHistoryId
            ];
            if (!agg.isEmpty()) {
                totalCurrentBalance = agg[0].get('s1') != null ? (Decimal) agg[0].get('s1') : 0;
                totalCloseFeeAmount = agg[0].get('s2') != null ? (Decimal) agg[0].get('s2') : 0;
                totalPlanPaymentAmount = agg[0].get('s3') != null ? (Decimal) agg[0].get('s3') : 0;
                totalAccruedInterest = agg[0].get('s4') != null ? (Decimal) agg[0].get('s4') : 0;
                totalIPPAccruedInterest = agg[0].get('s5') != null ? (Decimal) agg[0].get('s5') : 0;
                totalPerDiem = agg[0].get('s6') != null ? (Decimal) agg[0].get('s6') : 0;
                totalDeferredInterest = agg[0].get('s7') != null ? (Decimal) agg[0].get('s7') : 0;
            }
        } catch (Exception e) {
            System.debug('Aggregate 7 totals error: ' + e.getMessage());
        }

        if (fullPaymentAmount != 0 || loanBalance != 0 || fullPaymentWithoutIPP != 0 || fullIPPPaymentAmount != 0
                || totalCurrentBalance != 0 || totalCloseFeeAmount != 0 || totalPlanPaymentAmount != 0 || totalAccruedInterest != 0
                || totalIPPAccruedInterest != 0 || totalPerDiem != 0 || totalDeferredInterest != 0) {
            saveCardPaymentTotalsToDatabase(customerHistoryId, fullPaymentAmount, loanBalance, fullPaymentWithoutIPP, fullIPPPaymentAmount,
                    totalCurrentBalance, totalCloseFeeAmount, totalPlanPaymentAmount, totalAccruedInterest, totalIPPAccruedInterest, totalPerDiem, totalDeferredInterest);
        }

        try {
            List<FEC_Card_Payment__c> cardPayments = [
                SELECT FEC_Full_Payment_Amount__c, FEC_Loan_Balance__c, FEC_Full_Payment_Without_IPP__c, FEC_Full_IPP_Payment_Amount__c,
                       FEC_Total_Current_Balance__c, FEC_Total_Close_Fee_Amount__c, FEC_Total_Plan_Payment_Amount__c,
                       FEC_Total_Accrued_Interest__c, FEC_Total_IPP_Accrued_Interest__c, FEC_Total_Per_Diem__c, FEC_Total_Deferred_Interest__c
                FROM FEC_Card_Payment__c
                WHERE FEC_Customer_History__c = :customerHistoryId
                  AND (FEC_Full_Payment_Amount__c != null OR FEC_Loan_Balance__c != null OR FEC_Full_Payment_Without_IPP__c != null OR FEC_Full_IPP_Payment_Amount__c != null
                       OR FEC_Total_Current_Balance__c != null OR FEC_Total_Close_Fee_Amount__c != null OR FEC_Total_Plan_Payment_Amount__c != null
                       OR FEC_Total_Accrued_Interest__c != null OR FEC_Total_IPP_Accrued_Interest__c != null OR FEC_Total_Per_Diem__c != null OR FEC_Total_Deferred_Interest__c != null)
                ORDER BY CreatedDate ASC
                LIMIT 1
            ];

            if (!cardPayments.isEmpty()) {
                FEC_Card_Payment__c payment = cardPayments[0];
                dto.fullPaymentAmount = payment.FEC_Full_Payment_Amount__c != null ? payment.FEC_Full_Payment_Amount__c : 0;
                dto.loanBalance = payment.FEC_Loan_Balance__c != null ? payment.FEC_Loan_Balance__c : 0;
                dto.fullPaymentWithoutIPP = payment.FEC_Full_Payment_Without_IPP__c != null ? payment.FEC_Full_Payment_Without_IPP__c : 0;
                dto.fullIPPPaymentAmount = payment.FEC_Full_IPP_Payment_Amount__c != null ? payment.FEC_Full_IPP_Payment_Amount__c : 0;
                dto.totalCurrentBalance = payment.FEC_Total_Current_Balance__c != null ? payment.FEC_Total_Current_Balance__c : 0;
                dto.totalCloseFeeAmount = payment.FEC_Total_Close_Fee_Amount__c != null ? payment.FEC_Total_Close_Fee_Amount__c : 0;
                dto.totalPlanPaymentAmount = payment.FEC_Total_Plan_Payment_Amount__c != null ? payment.FEC_Total_Plan_Payment_Amount__c : 0;
                dto.totalAccruedInterest = payment.FEC_Total_Accrued_Interest__c != null ? payment.FEC_Total_Accrued_Interest__c : 0;
                dto.totalIPPAccruedInterest = payment.FEC_Total_IPP_Accrued_Interest__c != null ? payment.FEC_Total_IPP_Accrued_Interest__c : 0;
                dto.totalPerDiem = payment.FEC_Total_Per_Diem__c != null ? payment.FEC_Total_Per_Diem__c : 0;
                dto.totalDeferredInterest = payment.FEC_Total_Deferred_Interest__c != null ? payment.FEC_Total_Deferred_Interest__c : 0;
            } else {
                throw new AuraHandledException(System.Label.FEC_MSG_Error_API_Label);
            }
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            if (isMockTotals) {
                return FEC_MockData.getHardcodedCardPaymentTotalsForUI();
            }
            throw new AuraHandledException(System.Label.FEC_MSG_Error_API_Label);
        }

        return dto;
        } catch (Exception e) {
            if (isMockTotals) {
                return FEC_MockData.getHardcodedCardPaymentTotalsForUI();
            }
            throw new AuraHandledException(System.Label.FEC_MSG_Error_API_Label);
        }
    }

    /**
     * Tạo CardPaymentTotalsDTO từ helpTexts + List 11 số (thứ tự: fullPaymentAmount, loanBalance, fullPaymentWithoutIPP, fullIPPPaymentAmount,
     * totalCurrentBalance, totalCloseFeeAmount, totalPlanPaymentAmount, totalAccruedInterest, totalIPPAccruedInterest, totalPerDiem, totalDeferredInterest).
     * FEC_MockData gọi method này (tên khác buildCardPaymentTotalsDTO để tránh conflict với bản cũ trên org).
     */
    public static CardPaymentTotalsDTO createCardPaymentTotalsFromValues(Map<String, String> helpTexts, List<Decimal> values) {
        if (values == null || values.size() < 11) {
            return buildCardPaymentTotalsDTO(helpTexts, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
        }
        return buildCardPaymentTotalsDTO(
            helpTexts,
            values[0], values[1], values[2], values[3],
            values[4], values[5], values[6], values[7], values[8], values[9], values[10]
        );
    }

    /** Build CardPaymentTotalsDTO từ các tham số. */
    public static CardPaymentTotalsDTO buildCardPaymentTotalsDTO(
            Map<String, String> helpTexts,
            Decimal fullPaymentAmount, Decimal loanBalance, Decimal fullPaymentWithoutIPP, Decimal fullIPPPaymentAmount,
            Decimal totalCurrentBalance, Decimal totalCloseFeeAmount, Decimal totalPlanPaymentAmount,
            Decimal totalAccruedInterest, Decimal totalIPPAccruedInterest, Decimal totalPerDiem, Decimal totalDeferredInterest) {
        CardPaymentTotalsDTO dto = new CardPaymentTotalsDTO();
        dto.helpTexts = helpTexts;
        dto.fullPaymentAmount = fullPaymentAmount != null ? fullPaymentAmount : 0;
        dto.loanBalance = loanBalance != null ? loanBalance : 0;
        dto.fullPaymentWithoutIPP = fullPaymentWithoutIPP != null ? fullPaymentWithoutIPP : 0;
        dto.fullIPPPaymentAmount = fullIPPPaymentAmount != null ? fullIPPPaymentAmount : 0;
        dto.totalCurrentBalance = totalCurrentBalance != null ? totalCurrentBalance : 0;
        dto.totalCloseFeeAmount = totalCloseFeeAmount != null ? totalCloseFeeAmount : 0;
        dto.totalPlanPaymentAmount = totalPlanPaymentAmount != null ? totalPlanPaymentAmount : 0;
        dto.totalAccruedInterest = totalAccruedInterest != null ? totalAccruedInterest : 0;
        dto.totalIPPAccruedInterest = totalIPPAccruedInterest != null ? totalIPPAccruedInterest : 0;
        dto.totalPerDiem = totalPerDiem != null ? totalPerDiem : 0;
        dto.totalDeferredInterest = totalDeferredInterest != null ? totalDeferredInterest : 0;
        return dto;
    }

    /**
     * Get Card Payment totals
     * Method này wrapper của loadCardPaymentTotals() để backward compatibility
     * @param caseId - The Case record ID
     * @return CardPaymentTotalsDTO containing payment totals and help texts
     */
    @AuraEnabled(cacheable=false)
    public static CardPaymentTotalsDTO getCardPaymentTotals(String caseId) {
        // Sử dụng loadCardPaymentTotals() - method này tự động query database và gọi API nếu cần
        return loadCardPaymentTotals(caseId);
    }

    /** Lưu totals vào DB: chỉ set field khi null. */
    private static void saveCardPaymentTotalsToDatabase(Id customerHistoryId, Decimal fullPaymentAmount, Decimal loanBalance, Decimal fullPaymentWithoutIPP, Decimal fullIPPPaymentAmount,
            Decimal totalCurrentBalance, Decimal totalCloseFeeAmount, Decimal totalPlanPaymentAmount, Decimal totalAccruedInterest, Decimal totalIPPAccruedInterest, Decimal totalPerDiem, Decimal totalDeferredInterest) {
        if (customerHistoryId == null) {
            return;
        }

        try {
            List<FEC_Card_Payment__c> existingPayments = [
                SELECT Id, FEC_Full_Payment_Amount__c, FEC_Loan_Balance__c, FEC_Full_Payment_Without_IPP__c, FEC_Full_IPP_Payment_Amount__c,
                       FEC_Total_Current_Balance__c, FEC_Total_Close_Fee_Amount__c, FEC_Total_Plan_Payment_Amount__c,
                       FEC_Total_Accrued_Interest__c, FEC_Total_IPP_Accrued_Interest__c, FEC_Total_Per_Diem__c, FEC_Total_Deferred_Interest__c
                FROM FEC_Card_Payment__c
                WHERE FEC_Customer_History__c = :customerHistoryId
                ORDER BY CreatedDate ASC
                LIMIT 1
            ];

            FEC_Card_Payment__c paymentToUpdate;

            if (!existingPayments.isEmpty()) {
                paymentToUpdate = existingPayments[0];
                // Chỉ bỏ qua khi đã có đủ cả 11 field (4 totals + 7 tổng)
                Boolean hasAllTotals = (paymentToUpdate.FEC_Full_Payment_Amount__c != null || paymentToUpdate.FEC_Loan_Balance__c != null || paymentToUpdate.FEC_Full_Payment_Without_IPP__c != null || paymentToUpdate.FEC_Full_IPP_Payment_Amount__c != null)
                    && (paymentToUpdate.FEC_Total_Current_Balance__c != null || paymentToUpdate.FEC_Total_Close_Fee_Amount__c != null || paymentToUpdate.FEC_Total_Plan_Payment_Amount__c != null
                        || paymentToUpdate.FEC_Total_Accrued_Interest__c != null || paymentToUpdate.FEC_Total_IPP_Accrued_Interest__c != null || paymentToUpdate.FEC_Total_Per_Diem__c != null || paymentToUpdate.FEC_Total_Deferred_Interest__c != null);
                if (hasAllTotals) {
                    return;
                }
            } else {
                paymentToUpdate = new FEC_Card_Payment__c();
                paymentToUpdate.FEC_Customer_History__c = customerHistoryId;
            }

            Boolean needsUpdate = false;

            if (paymentToUpdate.FEC_Full_Payment_Amount__c == null && fullPaymentAmount != 0) {
                paymentToUpdate.FEC_Full_Payment_Amount__c = fullPaymentAmount;
                needsUpdate = true;
            }
            if (paymentToUpdate.FEC_Loan_Balance__c == null && loanBalance != 0) {
                paymentToUpdate.FEC_Loan_Balance__c = loanBalance;
                needsUpdate = true;
            }
            if (paymentToUpdate.FEC_Full_Payment_Without_IPP__c == null && fullPaymentWithoutIPP != 0) {
                paymentToUpdate.FEC_Full_Payment_Without_IPP__c = fullPaymentWithoutIPP;
                needsUpdate = true;
            }
            if (paymentToUpdate.FEC_Full_IPP_Payment_Amount__c == null && fullIPPPaymentAmount != 0) {
                paymentToUpdate.FEC_Full_IPP_Payment_Amount__c = fullIPPPaymentAmount;
                needsUpdate = true;
            }
            if (paymentToUpdate.FEC_Total_Current_Balance__c == null && totalCurrentBalance != 0) {
                paymentToUpdate.FEC_Total_Current_Balance__c = totalCurrentBalance;
                needsUpdate = true;
            }
            if (paymentToUpdate.FEC_Total_Close_Fee_Amount__c == null && totalCloseFeeAmount != 0) {
                paymentToUpdate.FEC_Total_Close_Fee_Amount__c = totalCloseFeeAmount;
                needsUpdate = true;
            }
            if (paymentToUpdate.FEC_Total_Plan_Payment_Amount__c == null && totalPlanPaymentAmount != 0) {
                paymentToUpdate.FEC_Total_Plan_Payment_Amount__c = totalPlanPaymentAmount;
                needsUpdate = true;
            }
            if (paymentToUpdate.FEC_Total_Accrued_Interest__c == null && totalAccruedInterest != 0) {
                paymentToUpdate.FEC_Total_Accrued_Interest__c = totalAccruedInterest;
                needsUpdate = true;
            }
            if (paymentToUpdate.FEC_Total_IPP_Accrued_Interest__c == null && totalIPPAccruedInterest != 0) {
                paymentToUpdate.FEC_Total_IPP_Accrued_Interest__c = totalIPPAccruedInterest;
                needsUpdate = true;
            }
            if (paymentToUpdate.FEC_Total_Per_Diem__c == null && totalPerDiem != 0) {
                paymentToUpdate.FEC_Total_Per_Diem__c = totalPerDiem;
                needsUpdate = true;
            }
            if (paymentToUpdate.FEC_Total_Deferred_Interest__c == null && totalDeferredInterest != 0) {
                paymentToUpdate.FEC_Total_Deferred_Interest__c = totalDeferredInterest;
                needsUpdate = true;
            }

            if (needsUpdate) {
                if (paymentToUpdate.Id != null) {
                    update paymentToUpdate;
                } else {
                    insert paymentToUpdate;
                }
            }
        } catch (Exception e) {
            System.debug('Save Card Payment Totals error: ' + e.getMessage());
        }
    }
    
    /** Lưu Card Plan từ API vào FEC_Card_Payment__c (chỉ INSERT, key Rec+Plan). */
    private static void saveCardPlanToDatabase(List<FEC_GetCardPlanInfo.CardPlan> planList, String accountNumber, Id customerHistoryId) {
        if (customerHistoryId == null) {
            List<FEC_Customer_History__c> histories = [
                SELECT Id FROM FEC_Customer_History__c 
                WHERE FEC_Account_Number__c = :accountNumber 
                LIMIT 1
            ];
            if (!histories.isEmpty()) {
                customerHistoryId = histories[0].Id;
            }
        }
        
        if (customerHistoryId == null) {
            return;
        }
        
        // Query records cũ để kiểm tra (chỉ INSERT nếu chưa có)
        List<FEC_Card_Payment__c> existingRecords = [
            SELECT Id, FEC_Rec__c, FEC_Plan__c, FEC_Customer_History__c
            FROM FEC_Card_Payment__c 
            WHERE FEC_Customer_History__c = :customerHistoryId
        ];
        Set<String> existingKeys = new Set<String>();
        for (FEC_Card_Payment__c existing : existingRecords) {
            String key = (existing.FEC_Rec__c != null ? existing.FEC_Rec__c : '') + '_' + 
                        (existing.FEC_Plan__c != null ? existing.FEC_Plan__c : '');
            existingKeys.add(key);
        }
        
        List<FEC_Card_Payment__c> recordsToInsert = new List<FEC_Card_Payment__c>();

        for (FEC_GetCardPlanInfo.CardPlan p : planList) {
            // Tạo key để kiểm tra: Rec__c + Plan__c
            String key = (p.recordNumber != null ? p.recordNumber : '') + '_' + 
                        (p.planNumber != null ? p.planNumber : '');
            if (existingKeys.contains(key)) {
                continue;
            }
            FEC_Card_Payment__c record = new FEC_Card_Payment__c();
            record.FEC_Customer_History__c = customerHistoryId;
            record.FEC_Rec__c = p.recordNumber;
            record.FEC_Plan__c = p.planNumber;
            record.FEC_REF_Number__c = p.refNumber;
            record.FEC_Open_Date__c = FEC_CommonUltils.parseDate(p.openDate);
            record.FEC_Begin_Date__c = FEC_CommonUltils.parseDate(p.beginDate);
            Decimal currentBalance = p.currentBalance != null ? p.currentBalance : 0;
            Decimal accruedInterest = p.accruedInterest != null ? p.accruedInterest : 0;
            Decimal perDiem = p.perDiem != null ? p.perDiem : 0;
            Decimal deferredInterest = p.deferredInterest != null ? p.deferredInterest : 0;
            Decimal ippAccruedInterest = p.additionalAccruedInt != null ? p.additionalAccruedInt : 0;
            
            record.FEC_Current_Balance__c = currentBalance;       // PlanCurrentBalance
            // baseRate đã chuẩn hóa từ XML: 4 ký tự đầu / 100 (vd 1000000 → 10%)
            record.FEC_Base_Rate__c = p.baseRate;
            record.FEC_Deferred_Interest__c = deferredInterest;   // DeferredInterest
            record.FEC_Accrued_Interest__c = accruedInterest;     // AccruedInterest
            record.FEC_Per_Diem__c = perDiem;                     // PerDiem
            record.FEC_IPP_Interest__c = p.ippInterest;           // IPPInterest
            record.FEC_IPP_Accrued_Interest__c = ippAccruedInterest; // AccruedInt (IPP)
            
            // Close Fee % = (Close Fee Amount / Current Balance) * 100
            // FEC_Close_Fee__c là Decimal/Percent field
            Decimal closeFeePercent = 0;
            if (p.closeFeeIndicator == 'Y' && currentBalance > 0 && p.closeFeeIndicatorAmt != null) {
                closeFeePercent = (p.closeFeeIndicatorAmt / currentBalance) * 100;
                closeFeePercent = closeFeePercent.setScale(2, RoundingMode.HALF_UP);
            }
            record.FEC_Close_Fee__c = closeFeePercent;
            Decimal closeFeeAmount = p.closeFeeIndicatorAmt != null ? p.closeFeeIndicatorAmt : 0;
            record.FEC_Close_Fee_Amount__c = closeFeeAmount;
            Decimal planPaymentAmount = p.totalPaymentAmount != null ? p.totalPaymentAmount : 0;
            record.FEC_Plan_Payment_Amount__c = planPaymentAmount;

            recordsToInsert.add(record);
        }

        if (!recordsToInsert.isEmpty()) {
            try {
                insert recordsToInsert;
            } catch (Exception e) {
                throw new AuraHandledException(e.getMessage());
            }
        }
    }
    

}
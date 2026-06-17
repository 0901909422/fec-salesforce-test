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
    
    /** Tải Card Payment: Mock ON → hardcode; Mock OFF → query DB → gọi API → save → trả DB (không fallback mock khi lỗi). */
    @AuraEnabled(cacheable=false)
    public static List<Map<String, Object>> loadCardPaymentInfo(Id caseId) {
        if (caseId == null) {
            throw new AuraHandledException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'Case Id'}));
        }

        if (isCallMockEnabled()) {
            return FEC_MockData.getHardcodedCardPaymentRecordsForUI();
        }

        Case c = [SELECT Id, FEC_Account_or_Contract__c, FEC_Account_Number__c, FEC_Account_or_Contract__r.FEC_Account_Number__c FROM Case WHERE Id = :caseId LIMIT 1];
        Id customerHistoryId = c.FEC_Account_or_Contract__c;
        String accountNumber = getAccountNumber(c);
        List<Map<String, Object>> records = queryCardPaymentRecordMaps(customerHistoryId);

        if (String.isBlank(accountNumber)) {
            return records;
        }

        try {
            FEC_GetCardPlanInfo.CardPlanResult apiResult = FEC_GetCardPlanInfo.getCardPlanInfo(accountNumber);
            if (apiResult != null && apiResult.responseCode == '1' && apiResult.plans != null && !apiResult.plans.isEmpty()) {
                Id custHistoryId = resolveCustomerHistoryId(customerHistoryId, accountNumber);
                if (custHistoryId != null) {
                    saveCardPlanToDatabase(apiResult.plans, accountNumber, custHistoryId);
                    return queryCardPaymentRecordMaps(custHistoryId);
                }
            }
        } catch (Exception e) {
            System.debug('### GetCardPlanInfo API FAILED: ' + e.getMessage());
        }

        return records;
    }

    private static Boolean isCallMockEnabled() {
        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        return apiSetting != null && apiSetting.FEC_Call_Mock__c == true;
    }

    private static Id resolveCustomerHistoryId(Id customerHistoryId, String accountNumber) {
        if (customerHistoryId != null) {
            return customerHistoryId;
        }
        if (String.isBlank(accountNumber)) {
            return null;
        }
        List<FEC_Customer_History__c> histories = [
            SELECT Id
            FROM FEC_Customer_History__c
            WHERE FEC_Account_Number__c = :accountNumber
            LIMIT 1
        ];
        return histories.isEmpty() ? null : histories[0].Id;
    }

    private static List<Map<String, Object>> queryCardPaymentRecordMaps(Id customerHistoryId) {
        List<Map<String, Object>> records = new List<Map<String, Object>>();
        if (customerHistoryId == null) {
            return records;
        }
        // IPP Accrued Interest chỉ hiện khi (NextStatementDate - today) ≤ 4 ngày
        Boolean showIppAccruedInterest = resolveShowIppAccruedInterest(customerHistoryId);
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
                records.add(buildCardPaymentRecordMap(p, showIppAccruedInterest));
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

    /** Map FEC_Card_Payment__c → Map cho LWC.
     *  showIppAccruedInterest: true khi (NextStatementDate - today) ≤ 4 ngày. */
    private static Map<String, Object> buildCardPaymentRecordMap(FEC_Card_Payment__c p, Boolean showIppAccruedInterest) {
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
        // IPP Accrued Interest: chỉ show khi (NextStatementDate - today) ≤ 4 ngày
        record.put('FEC_IPP_Accrued_Interest__c', showIppAccruedInterest ? p.FEC_IPP_Accrued_Interest__c : null);
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
    
    /** Tải Card Payment Totals: Mock ON → hardcode; Mock OFF → query DB → gọi API (không fallback mock khi lỗi). */
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

        if (isCallMockEnabled()) {
            return FEC_MockData.getHardcodedCardPaymentTotalsForUI();
        }

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
            totalIPPAccruedInterest = applyIppAccruedInterestTotalRule(totalIPPAccruedInterest, customerHistoryId);
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

        // Gọi 3 API mỗi lần load: GetCardBasicInfo, EmeaAccountInq, GetCardPlanInfo
        if (String.isBlank(accountNumber)) return dto;

        try {
            Decimal fullPaymentAmount = 0;
            Decimal loanBalance = 0;
            Decimal fullPaymentWithoutIPP = 0;
            Decimal onlineTotalBalance = 0;

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

        Decimal fullIPPPaymentAmount = 0;
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

        totalIPPAccruedInterest = applyIppAccruedInterestTotalRule(totalIPPAccruedInterest, customerHistoryId);

        // Full Payment Amount = OnlineTotalBalance + Sum(AccruedInterest + DeferredInterest + PerDiem + IPPAccruedInterest + CloseFeeAmount)
        fullPaymentAmount = onlineTotalBalance + totalAccruedInterest + totalDeferredInterest
                + totalPerDiem + totalIPPAccruedInterest + totalCloseFeeAmount;

        if (fullPaymentAmount != 0 && fullPaymentWithoutIPP != 0) {
            fullIPPPaymentAmount = fullPaymentAmount - fullPaymentWithoutIPP;
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
            throw new AuraHandledException(System.Label.FEC_MSG_Error_API_Label);
        }

        return dto;
        } catch (Exception e) {
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

    /** Lưu totals vào DB (upsert record đầu tiên theo Customer History). */
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
            } else {
                paymentToUpdate = new FEC_Card_Payment__c();
                paymentToUpdate.FEC_Customer_History__c = customerHistoryId;
            }

            paymentToUpdate.FEC_Full_Payment_Amount__c = fullPaymentAmount;
            paymentToUpdate.FEC_Loan_Balance__c = loanBalance;
            paymentToUpdate.FEC_Full_Payment_Without_IPP__c = fullPaymentWithoutIPP;
            paymentToUpdate.FEC_Full_IPP_Payment_Amount__c = fullIPPPaymentAmount;
            paymentToUpdate.FEC_Total_Current_Balance__c = totalCurrentBalance;
            paymentToUpdate.FEC_Total_Close_Fee_Amount__c = totalCloseFeeAmount;
            paymentToUpdate.FEC_Total_Plan_Payment_Amount__c = totalPlanPaymentAmount;
            paymentToUpdate.FEC_Total_Accrued_Interest__c = totalAccruedInterest;
            paymentToUpdate.FEC_Total_IPP_Accrued_Interest__c = totalIPPAccruedInterest;
            paymentToUpdate.FEC_Total_Per_Diem__c = totalPerDiem;
            paymentToUpdate.FEC_Total_Deferred_Interest__c = totalDeferredInterest;

            if (paymentToUpdate.Id != null) {
                update paymentToUpdate;
            } else {
                insert paymentToUpdate;
            }
        } catch (Exception e) {
            System.debug('Save Card Payment Totals error: ' + e.getMessage());
        }
    }

    private static String buildCardPlanSyncKey(String rec, String plan) {
        return (rec != null ? rec.trim() : '') + '_' + (plan != null ? plan.trim() : '');
    }

    /** true khi (NextStatementDate - today) ≤ 4 ngày. */
    public static Boolean resolveShowIppAccruedInterest(Id customerHistoryId) {
        if (customerHistoryId == null) {
            return false;
        }
        try {
            List<FEC_Customer_History__c> histories = [
                SELECT FEC_Next_Statement_Date__c
                FROM FEC_Customer_History__c
                WHERE Id = :customerHistoryId
                LIMIT 1
            ];
            if (!histories.isEmpty() && histories[0].FEC_Next_Statement_Date__c != null) {
                Integer daysUntilNextStatement = Date.today().daysBetween(histories[0].FEC_Next_Statement_Date__c);
                return daysUntilNextStatement <= 4;
            }
        } catch (Exception e) {
            System.debug('Query NextStatementDate error: ' + e.getMessage());
        }
        return false;
    }

    /** Total IPP Accrued Interest: chỉ cộng vào Full Payment khi (NextStatementDate - today) ≤ 4 ngày. */
    public static Decimal applyIppAccruedInterestTotalRule(Decimal aggregatedIppAccrued, Id customerHistoryId) {
        if (!resolveShowIppAccruedInterest(customerHistoryId)) {
            return 0;
        }
        return aggregatedIppAccrued != null ? aggregatedIppAccrued : 0;
    }

    /**
     * PlanPaymentAmount = PlanCurrentBalance + AccruedInterest/100 + PerDiem/100
     *   + DeferredInterest + IPPAccruedInterest + CloseFeeAmount
     * IPPAccruedInterest chỉ cộng khi (NextStatementDate - today) ≤ 4 ngày.
     */
    public static Decimal calculatePlanPaymentAmount(FEC_GetCardPlanInfo.CardPlan p, Boolean showIppAccruedInterest) {
        Decimal currentBalance = p.currentBalance != null ? p.currentBalance : 0;
        Decimal accruedInterest = p.accruedInterest != null ? p.accruedInterest / 100 : 0;
        Decimal perDiem = p.perDiem != null ? p.perDiem / 100 : 0;
        Decimal deferredInterest = p.deferredInterest != null ? p.deferredInterest : 0;
        Decimal ippAccruedInterest = 0;
        if (showIppAccruedInterest && p.additionalAccruedInt != null) {
            ippAccruedInterest = p.additionalAccruedInt;
        }
        Decimal closeFeeAmount = p.closeFeeAmount != null ? p.closeFeeAmount : 0;
        return currentBalance + accruedInterest + perDiem + deferredInterest + ippAccruedInterest + closeFeeAmount;
    }

    /** Map CardPlan API → FEC_Card_Payment__c field values. */
    private static void populateCardPaymentFromPlan(
        FEC_Card_Payment__c record,
        FEC_GetCardPlanInfo.CardPlan p,
        Id customerHistoryId,
        Boolean showIppAccruedInterest
    ) {
        record.FEC_Customer_History__c = customerHistoryId;
        record.FEC_Rec__c = p.recordNumber;
        record.FEC_Plan__c = p.planNumber;
        record.FEC_REF_Number__c = p.refNumber;
        record.FEC_Open_Date__c = FEC_CommonUltils.parseDate(p.openDate);
        record.FEC_Begin_Date__c = FEC_CommonUltils.parseDate(p.beginDate);

        Decimal currentBalance = p.currentBalance != null ? p.currentBalance : 0;
        Decimal accruedInterest = p.accruedInterest != null ? p.accruedInterest / 100 : 0;
        Decimal perDiem = p.perDiem != null ? p.perDiem / 100 : 0;
        Decimal deferredInterest = p.deferredInterest != null ? p.deferredInterest : 0;
        Decimal ippAccruedInterest = p.additionalAccruedInt != null ? p.additionalAccruedInt : 0;

        record.FEC_Current_Balance__c = currentBalance;
        record.FEC_Base_Rate__c = p.baseRate;
        record.FEC_Deferred_Interest__c = deferredInterest;
        record.FEC_Accrued_Interest__c = accruedInterest;
        record.FEC_Per_Diem__c = perDiem;
        record.FEC_IPP_Interest__c = p.ippInterest;
        record.FEC_IPP_Accrued_Interest__c = ippAccruedInterest;

        Decimal closeFeePercent = 0;
        if (p.closeFeeIndicatorAmt != null) {
            closeFeePercent = (p.closeFeeIndicatorAmt / 100000).setScale(2, RoundingMode.HALF_UP);
        }
        record.FEC_Close_Fee__c = closeFeePercent;
        record.FEC_Close_Fee_Amount__c = p.closeFeeAmount != null ? p.closeFeeAmount : 0;
        record.FEC_Plan_Payment_Amount__c = calculatePlanPaymentAmount(p, showIppAccruedInterest);
    }
    
    /** Lưu Card Plan từ API vào FEC_Card_Payment__c (upsert theo key Rec+Plan). */
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
        
        Map<String, FEC_Card_Payment__c> existingByKey = new Map<String, FEC_Card_Payment__c>();
        for (FEC_Card_Payment__c existing : [
            SELECT Id, FEC_Rec__c, FEC_Plan__c
            FROM FEC_Card_Payment__c
            WHERE FEC_Customer_History__c = :customerHistoryId
        ]) {
            existingByKey.put(buildCardPlanSyncKey(existing.FEC_Rec__c, existing.FEC_Plan__c), existing);
        }

        List<FEC_Card_Payment__c> recordsToInsert = new List<FEC_Card_Payment__c>();
        List<FEC_Card_Payment__c> recordsToUpdate = new List<FEC_Card_Payment__c>();
        Boolean showIppAccruedInterest = resolveShowIppAccruedInterest(customerHistoryId);

        for (FEC_GetCardPlanInfo.CardPlan p : planList) {
            String key = buildCardPlanSyncKey(p.recordNumber, p.planNumber);
            FEC_Card_Payment__c record;
            if (existingByKey.containsKey(key)) {
                record = existingByKey.get(key);
                recordsToUpdate.add(record);
            } else {
                record = new FEC_Card_Payment__c();
                recordsToInsert.add(record);
            }
            populateCardPaymentFromPlan(record, p, customerHistoryId, showIppAccruedInterest);
        }

        try {
            if (!recordsToInsert.isEmpty()) {
                insert recordsToInsert;
            }
            if (!recordsToUpdate.isEmpty()) {
                update recordsToUpdate;
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    

}
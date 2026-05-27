/****************************************************************************************
 * File Name    : FEC_PaymentHistoryController.Apex
 * Author       : Quangdv7
 * Date         : 2025-01-20
 * Description  : Call data object Case
 * Modification Log
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0      2025-01-20     Quangdv7             Create
 
****************************************************************************************/

public without sharing class FEC_PaymentHistoryController {

    /* =====================================================
       DTOs 
       ===================================================== */
    public class PaymentHistoryDTO {
        @AuraEnabled public Integer paymentNo;
        @AuraEnabled public Date    paymentDate;
        @AuraEnabled public Date    bookingDate;
        @AuraEnabled public Decimal paymentAmount;
        @AuraEnabled public String  particulars;
        @AuraEnabled public Decimal totalPaymentAmount;
    }

    public class RealtimePaymentDTO {
        @AuraEnabled public Date    paymentDate;
        @AuraEnabled public Decimal paymentAmount;
        @AuraEnabled public String  paymentChannel;
    }

    /* =====================================================
       GET CUSTOMER HISTORY ID FROM CASE
       ===================================================== */
    private static Case getCaseWithCustomerHistory(Id caseId) {
        return [
            SELECT FEC_Account_or_Contract__c, FEC_Product_Type__r.Name
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
    }

    private static Id getCustomerHistoryId(Id caseId) {
        Case c = getCaseWithCustomerHistory(caseId);
        if (c.FEC_Account_or_Contract__c == null) {
            throw new AuraHandledException(System.Label.FEC_MSG_Not_Account_Linked);
        }
        return c.FEC_Account_or_Contract__c;
    }

    private static String getCustomerAccountNumber(Id caseId) {
        Case c = getCaseWithCustomerHistory(caseId);
        if (c.FEC_Account_or_Contract__c == null) {
            throw new AuraHandledException(System.Label.FEC_MSG_Not_Account_Linked);
        }

        FEC_Customer_History__c ch = [
            SELECT FEC_Account_Number__c, FEC_Contract_Number__c
            FROM FEC_Customer_History__c
            WHERE Id = :c.FEC_Account_or_Contract__c
            LIMIT 1
        ];

        return FEC_CommonUltils.resolveAccountNumber(
            c.FEC_Product_Type__r.Name,
            ch.FEC_Account_Number__c,
            ch.FEC_Contract_Number__c
        );
    }

    /* =====================================================
        BILLING PAYMENT
       ===================================================== */
    @AuraEnabled
    public static void syncPaymentHistory(Id caseId) {

        String accountNumber;
        Id customerHistoryId;
        try {
            Case c = [
                SELECT FEC_Account_or_Contract__c, FEC_Product_Type__r.Name
                FROM Case
                WHERE Id = :caseId
                LIMIT 1
            ];
            if (c.FEC_Account_or_Contract__c == null) return;

            FEC_Customer_History__c ch = [
                SELECT FEC_Account_Number__c, FEC_Contract_Number__c
                FROM FEC_Customer_History__c
                WHERE Id = :c.FEC_Account_or_Contract__c
                LIMIT 1
            ];

            customerHistoryId = c.FEC_Account_or_Contract__c;
            accountNumber = FEC_CommonUltils.resolveAccountNumber(
                c.FEC_Product_Type__r.Name,
                ch.FEC_Account_Number__c,
                ch.FEC_Contract_Number__c
            );
        } catch (Exception e) {
            return;
        }

        FEC_GetCardSecInfo.ResponseWrapper cardSecRes;
        try {
            cardSecRes = FEC_GetCardSecInfo.getCardSecInfo(accountNumber);
        } catch (Exception e) {
            cardSecRes = null;
        }

        if (cardSecRes == null
            || cardSecRes.CardSecInfo == null
            || cardSecRes.CardSecInfo.FinancialTransactions == null
            || cardSecRes.CardSecInfo.FinancialTransactions.isEmpty()) {
            return;
        }

        Map<String, FEC_Payment_History__c> existingMap = new Map<String, FEC_Payment_History__c>();
        for (FEC_Payment_History__c h : [
            SELECT Id, FEC_Payment_Date__c, FEC_Particulars__c
            FROM FEC_Payment_History__c
            WHERE FEC_Customer_History__c = :customerHistoryId
            AND FEC_Payment_Channel__c = NULL
        ]) {
            String key = String.valueOf(h.FEC_Payment_Date__c) + '|' + h.FEC_Particulars__c;
            existingMap.put(key, h);
        }

        List<FEC_Payment_History__c> toUpsert = new List<FEC_Payment_History__c>();
        Decimal totalAmount = 0;

        for (FEC_GetCardSecInfo.FinancialTransaction ft
                : cardSecRes.CardSecInfo.FinancialTransactions) {

            if (ft.PaymentFlag != 'Y') continue;

            Date paymentDate = FEC_CommonUltils.parseDate(ft.SettlementDate);
            Date bookingDate = FEC_CommonUltils.parseDate(ft.PostingDate);
            Decimal amount   = ft.TRNXAmount != null ? ft.TRNXAmount : 0;
            String key       = String.valueOf(paymentDate) + '|' + ft.RRN;

            FEC_Payment_History__c r =
                existingMap.containsKey(key)
                ? existingMap.get(key)
                : new FEC_Payment_History__c(
                    FEC_Customer_History__c = customerHistoryId
                );

            r.FEC_Payment_Date__c   = paymentDate;
            r.FEC_Booking_Date__c   = bookingDate;
            r.FEC_Payment_Amount__c = amount;
            r.FEC_Particulars__c    = ft.RRN;

            if (ft.TRNXAmount != null) totalAmount += ft.TRNXAmount;
            toUpsert.add(r);
        }

        for (FEC_Payment_History__c r : toUpsert) {
            r.FEC_Total_Payment_Amount__c = totalAmount;
        }

        if (!toUpsert.isEmpty()) upsert toUpsert;
    }

    /* =====================================================
       LOAD BILLING PAYMENT – UI
       ===================================================== */
    @AuraEnabled(cacheable=false)
    public static List<PaymentHistoryDTO> loadPaymentHistory(Id caseId) {

        Id customerHistoryId;
        try {
            Case c = [
                SELECT FEC_Account_or_Contract__c
                FROM Case
                WHERE Id = :caseId
                LIMIT 1
            ];
            customerHistoryId = c.FEC_Account_or_Contract__c;
            if (customerHistoryId == null) return new List<PaymentHistoryDTO>();
        } catch (Exception e) {
            return new List<PaymentHistoryDTO>();
        }

        List<PaymentHistoryDTO> result = new List<PaymentHistoryDTO>();
        Integer idx = 1;

        for (FEC_Payment_History__c r : [
            SELECT
                FEC_Payment_Date__c,
                FEC_Booking_Date__c,
                FEC_Payment_Amount__c,
                FEC_Particulars__c,
                FEC_Total_Payment_Amount__c
            FROM FEC_Payment_History__c
            WHERE FEC_Customer_History__c = :customerHistoryId
            AND FEC_Payment_Channel__c = NULL
            ORDER BY FEC_Payment_Date__c DESC
        ]) {
            PaymentHistoryDTO dto = new PaymentHistoryDTO();
            dto.paymentNo          = idx++;
            dto.paymentDate        = r.FEC_Payment_Date__c;
            dto.bookingDate        = r.FEC_Booking_Date__c;
            dto.paymentAmount      = r.FEC_Payment_Amount__c;
            dto.particulars        = r.FEC_Particulars__c;
            dto.totalPaymentAmount = r.FEC_Total_Payment_Amount__c;
            result.add(dto);
        }

        return result;
    }

    /* =====================================================
        REALTIME PAYMENT 
       ===================================================== */
    @AuraEnabled
    public static void syncRealtimePayment(Id caseId) {

        Id customerHistoryId;
        String contractOrAccountNo;
        try {
            customerHistoryId = getCustomerHistoryId(caseId);
            contractOrAccountNo = getCustomerAccountNumber(caseId);
        } catch (Exception e) {
            return;
        }

        FEC_GetPaymentInfo.ResponseWrapper apiRes;
        try {
            apiRes = FEC_GetPaymentInfo.callGetPaymentInfo(
                String.valueOf(UUID.randomUUID()),
                FEC_ConstantCommon.REQUESTOR_CRM,
                Datetime.now().formatGMT(FEC_ConstantCommon.DATETIME_FORMAT),
                contractOrAccountNo
            );
        } catch (Exception e) {
            apiRes = null;
        }

        if (apiRes == null || apiRes.Payments == null) {
            return;
        }

        Map<String, FEC_Payment_History__c> existingMap = new Map<String, FEC_Payment_History__c>();

        for (FEC_Payment_History__c h : [
            SELECT Id, FEC_Payment_Date__c, FEC_Payment_Channel__c
            FROM FEC_Payment_History__c
            WHERE FEC_Customer_History__c = :customerHistoryId
              AND FEC_Payment_Channel__c != NULL
        ]) {
            String key = h.FEC_Payment_Date__c + '|' + h.FEC_Payment_Channel__c;
            existingMap.put(key, h);
        }

        List<FEC_Payment_History__c> toUpsert = new List<FEC_Payment_History__c>();

        for (FEC_GetPaymentInfo.PaymentInfo p : apiRes.Payments) {

            Date paymentDate = FEC_CommonUltils.parseDate(p.TransactionDate);
            String key = paymentDate + '|' + p.Username;

            FEC_Payment_History__c r =
                existingMap.containsKey(key)
                ? existingMap.get(key)
                : new FEC_Payment_History__c(
                    FEC_Customer_History__c = customerHistoryId
                );

            r.FEC_Payment_Date__c    = paymentDate;
            r.FEC_Payment_Amount__c  = p.AmountPaid;
            r.FEC_Payment_Channel__c = p.Username;

            toUpsert.add(r);
        }

        if (!toUpsert.isEmpty()) {
            upsert toUpsert;
        }
    }

    /* =====================================================
       LOAD REALTIME PAYMENT 
       ===================================================== */
    @AuraEnabled(cacheable=false)
    public static List<RealtimePaymentDTO> loadRealtimePayment(Id caseId) {

        Id customerHistoryId;
        try {
            Case c = [
                SELECT FEC_Account_or_Contract__c
                FROM Case
                WHERE Id = :caseId
                LIMIT 1
            ];
            customerHistoryId = c.FEC_Account_or_Contract__c;
            if (customerHistoryId == null) return new List<RealtimePaymentDTO>();
        } catch (Exception e) {
            return new List<RealtimePaymentDTO>();
        }

        List<RealtimePaymentDTO> result = new List<RealtimePaymentDTO>();

        for (FEC_Payment_History__c r : [
            SELECT
                FEC_Payment_Date__c,
                FEC_Payment_Amount__c,
                FEC_Payment_Channel__c
            FROM FEC_Payment_History__c
            WHERE FEC_Customer_History__c = :customerHistoryId
            AND FEC_Payment_Channel__c != NULL
            ORDER BY FEC_Payment_Date__c DESC
        ]) {
            RealtimePaymentDTO dto = new RealtimePaymentDTO();
            dto.paymentDate    = r.FEC_Payment_Date__c;
            dto.paymentAmount  = r.FEC_Payment_Amount__c;
            dto.paymentChannel = r.FEC_Payment_Channel__c;
            result.add(dto);
        }

        return result;
    }

}
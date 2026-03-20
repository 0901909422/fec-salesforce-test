/** Controller LWC 4 section: GetLoanBasicInfo, GetLoanSecInfo, GetPaymentInfo. */
public with sharing class FEC_RepaySchedPayHistController {

    public class FieldItemDTO {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        public FieldItemDTO(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    public class RepaymentScheduleTotalsDTO {
        @AuraEnabled public String totalInstallmentAmount;
        @AuraEnabled public String totalPrincipal;
        @AuraEnabled public String totalInterest;
    }

    /** Repayment Schedule row. */
    public class RepaymentScheduleRowDTO {
        @AuraEnabled public Integer rowIndex;
        @AuraEnabled public String installmentNo;
        @AuraEnabled public String dueDate;
        @AuraEnabled public String openingPrincipal;
        @AuraEnabled public String emi;
        @AuraEnabled public String repaymentFee;
        @AuraEnabled public String installmentAmount;
        @AuraEnabled public String principal;
        @AuraEnabled public String interest;
        @AuraEnabled public String closingPrincipal;
    }

    public class PaymentHistoryTotalsDTO {
        @AuraEnabled public String totalPaymentAmount;
    }

    /** Payment History row. */
    public class PaymentHistoryRowDTO {
        @AuraEnabled public Integer paymentNo;
        @AuraEnabled public String paymentDate;
        @AuraEnabled public String bookingDate;
        @AuraEnabled public String paymentAmount;
        @AuraEnabled public String particulars;
        @AuraEnabled public String paymentChannel;
    }

    /** Real-Time Payment row. */
    public class RealTimePaymentRowDTO {
        @AuraEnabled public Integer rowIndex;
        @AuraEnabled public String paymentDate;
        @AuraEnabled public String paymentAmount;
        @AuraEnabled public String paymentChannel;
    }

    public class SectionDataResult {
        @AuraEnabled public Map<String, String> helpTexts;
        @AuraEnabled public String errorMessage;
        @AuraEnabled public RepaymentScheduleTotalsDTO repaymentScheduleTotals;
        @AuraEnabled public List<RepaymentScheduleRowDTO> repaymentScheduleTable;
        @AuraEnabled public PaymentHistoryTotalsDTO paymentHistoryTotals;
        @AuraEnabled public List<PaymentHistoryRowDTO> paymentHistoryTable;
        @AuraEnabled public List<RealTimePaymentRowDTO> realTimePaymentTable;
        @AuraEnabled public List<FieldItemDTO> repaymentSchedulePaymentHistory;
    }

    private static final String HYPHEN = '-';

    /** Chuỗi ngày API (yyyy-MM-dd...) → dd/MM/yyyy. */
    private static String formatTransactionDateDDMMYYYY(String transactionDate) {
        if (String.isBlank(transactionDate)) {
            return HYPHEN;
        }
        try {
            String d = transactionDate.length() >= 10 ? transactionDate.substring(0, 10) : transactionDate;
            return FEC_CommonUltils.formatDateDDMMYYYY(Date.valueOf(d));
        } catch (Exception e) {
            return transactionDate;
        }
    }

    /** Transaction_Date (yyyy-MM-dd) → Date. */
    private static Date parseTransactionDateToDate(String transactionDate) {
        if (String.isBlank(transactionDate)) return null;
        try {
            String d = transactionDate.length() >= 10 ? transactionDate.substring(0, 10) : transactionDate;
            return Date.valueOf(d);
        } catch (Exception e) {
            return null;
        }
    }

    private static String getContractNumber(Id caseId) {
        List<Case> cases = [SELECT Id, FEC_Account_or_Contract__c FROM Case WHERE Id = :caseId LIMIT 1];
        if (cases.isEmpty() || cases[0].FEC_Account_or_Contract__c == null) return null;
        List<FEC_Customer_History__c> histories = [
            SELECT FEC_Contract_Number__c
            FROM FEC_Customer_History__c
            WHERE Id = :cases[0].FEC_Account_or_Contract__c
            LIMIT 1
        ];
        return (histories.isEmpty() || String.isBlank(histories[0].FEC_Contract_Number__c))
            ? null
            : histories[0].FEC_Contract_Number__c;
    }

    private static Id getCustomerHistoryId(Id caseId) {
        List<Case> cases = [SELECT FEC_Account_or_Contract__c FROM Case WHERE Id = :caseId LIMIT 1];
        return (cases.isEmpty() || cases[0].FEC_Account_or_Contract__c == null) ? null : cases[0].FEC_Account_or_Contract__c;
    }

    private static void fillRepaymentScheduleFromBasic(
        SectionDataResult result,
        FEC_GetLoanBasicInfo.ResponseWrapper basicRes
    ) {
        result.repaymentScheduleTotals = new RepaymentScheduleTotalsDTO();
        result.repaymentScheduleTotals.totalInstallmentAmount = HYPHEN;
        result.repaymentScheduleTotals.totalPrincipal = HYPHEN;
        result.repaymentScheduleTotals.totalInterest = HYPHEN;
        result.repaymentScheduleTable = new List<RepaymentScheduleRowDTO>();

        if (basicRes == null || basicRes.LoanBasicInfo == null) return;

        FEC_GetLoanBasicInfo.Loan loan = basicRes.LoanBasicInfo.Loan;
        if (loan != null && loan.TotalInstallmentAmount != null) {
            result.repaymentScheduleTotals.totalInstallmentAmount = String.valueOf(loan.TotalInstallmentAmount);
        }

        List<FEC_GetLoanBasicInfo.RepaymentSchedule> schedules = basicRes.LoanBasicInfo.RepaymentSchedules;
        if (schedules != null && !schedules.isEmpty()) {
            Decimal sumPrincipal = 0;
            Decimal sumInterest = 0;
            Integer idx = 0;
            for (FEC_GetLoanBasicInfo.RepaymentSchedule rs : schedules) {
                RepaymentScheduleRowDTO row = new RepaymentScheduleRowDTO();
                row.rowIndex = ++idx;
                row.installmentNo = FEC_CommonUltils.defaultToEmpty(rs.InstallmentNo);
                String dueStr = FEC_CommonUltils.formatDateDDMMYYYY(rs.DueDate);
                row.dueDate = String.isNotBlank(dueStr) ? dueStr : HYPHEN;
                row.openingPrincipal = FEC_CommonUltils.decimalToString(rs.OpeningPrincipal);
                row.emi = FEC_CommonUltils.decimalToString(rs.EMI);
                row.repaymentFee = FEC_CommonUltils.decimalToString(rs.RepaymentFee);
                row.installmentAmount = FEC_CommonUltils.decimalToString(rs.InstallmentAmount);
                row.principal = FEC_CommonUltils.decimalToString(rs.Principal);
                row.interest = FEC_CommonUltils.decimalToString(rs.Interest);
                row.closingPrincipal = FEC_CommonUltils.decimalToString(rs.ClosingPrincipal);
                result.repaymentScheduleTable.add(row);
                if (rs.Principal != null) sumPrincipal += rs.Principal;
                if (rs.Interest != null) sumInterest += rs.Interest;
            }
            result.repaymentScheduleTotals.totalPrincipal = sumPrincipal != 0 ? String.valueOf(sumPrincipal) : HYPHEN;
            result.repaymentScheduleTotals.totalInterest = sumInterest != 0 ? String.valueOf(sumInterest) : HYPHEN;
        }
    }

    /** RS → FEC_RePayment_Schedule__c */
    private static void saveRepaymentScheduleToObject(Id caseId, FEC_GetLoanBasicInfo.ResponseWrapper basicRes) {
        if (caseId == null) return;
        List<FEC_RePayment_Schedule__c> existing = [
            SELECT Id
            FROM FEC_RePayment_Schedule__c
            WHERE FEC_Case__c = :caseId
        ];
        if (!existing.isEmpty()) {
            delete existing;
        }
        if (basicRes == null || basicRes.LoanBasicInfo == null || basicRes.LoanBasicInfo.RepaymentSchedules == null
            || basicRes.LoanBasicInfo.RepaymentSchedules.isEmpty()) {
            return;
        }
        Decimal totalInstallmentAmount = null;
        FEC_GetLoanBasicInfo.Loan loan = basicRes.LoanBasicInfo.Loan;
        if (loan != null && loan.TotalInstallmentAmount != null) {
            totalInstallmentAmount = loan.TotalInstallmentAmount;
        }
        Decimal sumPrincipal = 0;
        Decimal sumInterest = 0;
        for (FEC_GetLoanBasicInfo.RepaymentSchedule rs : basicRes.LoanBasicInfo.RepaymentSchedules) {
            if (rs.Principal != null) sumPrincipal += rs.Principal;
            if (rs.Interest != null) sumInterest += rs.Interest;
        }
        List<FEC_RePayment_Schedule__c> toInsert = new List<FEC_RePayment_Schedule__c>();
        for (FEC_GetLoanBasicInfo.RepaymentSchedule rs : basicRes.LoanBasicInfo.RepaymentSchedules) {
            FEC_RePayment_Schedule__c rec = new FEC_RePayment_Schedule__c();
            rec.FEC_Case__c = caseId;
            rec.FEC_Customer_History__c = getCustomerHistoryId(caseId);
            rec.FEC_Installment_No__c = rs.InstallmentNo;
            rec.FEC_Installment_Due_Date__c = rs.DueDate;
            rec.FEC_EMI__c = rs.EMI;
            rec.FEC_Repayment_Fee__c = rs.RepaymentFee;
            rec.FEC_Installment_Amount__c = rs.InstallmentAmount;
            rec.FEC_Principal__c = rs.Principal;
            rec.FEC_Interest__c = rs.Interest;
            rec.FEC_Opening_Principal__c = rs.OpeningPrincipal;
            rec.FEC_Closing_Principal__c = rs.ClosingPrincipal;
            rec.FEC_Total_Installment_Amount__c = totalInstallmentAmount;
            rec.FEC_Total_Principal__c = sumPrincipal != 0 ? sumPrincipal : null;
            rec.FEC_Total_Interest__c = sumInterest != 0 ? sumInterest : null;
            toInsert.add(rec);
        }
        if (!toInsert.isEmpty()) {
            insert toInsert;
        }
    }

    private static void fillPaymentHistoryFromApis(
        SectionDataResult result,
        FEC_GetLoanBasicInfo.ResponseWrapper basicRes,
        FEC_GetLoanSecInfo.ResponseWrapper secRes,
        FEC_GetPaymentInfo.ResponseWrapper paymentRes
    ) {
        result.paymentHistoryTotals = new PaymentHistoryTotalsDTO();
        result.paymentHistoryTotals.totalPaymentAmount = HYPHEN;
        result.paymentHistoryTable = new List<PaymentHistoryRowDTO>();

        List<FEC_GetLoanBasicInfo.PaymentHistory> basicPh = (basicRes != null && basicRes.LoanBasicInfo != null && basicRes.LoanBasicInfo.PaymentHistories != null)
            ? basicRes.LoanBasicInfo.PaymentHistories
            : new List<FEC_GetLoanBasicInfo.PaymentHistory>();
        List<FEC_GetLoanSecInfo.PaymentHistory> secPh = (secRes != null && secRes.LoanSecInfo != null && secRes.LoanSecInfo.PaymentHistories != null)
            ? secRes.LoanSecInfo.PaymentHistories
            : new List<FEC_GetLoanSecInfo.PaymentHistory>();
        List<FEC_GetPaymentInfo.PaymentInfo> payments = (paymentRes != null && paymentRes.Payments != null)
            ? paymentRes.Payments
            : new List<FEC_GetPaymentInfo.PaymentInfo>();

        Integer rowCount = Math.max(Math.max(basicPh.size(), secPh.size()), payments.size());
        Decimal sumPaymentAmount = 0;
        for (Integer i = 0; i < rowCount; i++) {
            PaymentHistoryRowDTO row = new PaymentHistoryRowDTO();
            row.paymentNo = i + 1;
            if (i < basicPh.size() && basicPh[i].ValueDate != null) {
                String pd = FEC_CommonUltils.formatDateDDMMYYYY(basicPh[i].ValueDate);
                row.paymentDate = String.isNotBlank(pd) ? pd : HYPHEN;
            } else {
                row.paymentDate = HYPHEN;
            }
            if (i < secPh.size() && secPh[i].BookingDate != null) {
                String bd = FEC_CommonUltils.formatDateDDMMYYYY(secPh[i].BookingDate);
                row.bookingDate = String.isNotBlank(bd) ? bd : HYPHEN;
            } else {
                row.bookingDate = HYPHEN;
            }
            row.paymentAmount = i < secPh.size() ? FEC_CommonUltils.decimalToString(secPh[i].AmountOfMoney) : HYPHEN;
            if (i < secPh.size() && secPh[i].AmountOfMoney != null) {
                sumPaymentAmount += secPh[i].AmountOfMoney;
            }
            row.particulars = (i < secPh.size() && secPh[i].ChkNo != null) ? secPh[i].ChkNo : HYPHEN;
            row.paymentChannel = (i < payments.size() && payments[i].Username != null) ? payments[i].Username : HYPHEN;
            result.paymentHistoryTable.add(row);
        }

        if (sumPaymentAmount != 0) {
            result.paymentHistoryTotals.totalPaymentAmount = String.valueOf(sumPaymentAmount);
        }
    }

    /** PH → FEC_Payment_History__c */
    private static void savePaymentHistoryToObject(
        Id customerHistoryId,
        FEC_GetLoanBasicInfo.ResponseWrapper basicRes,
        FEC_GetLoanSecInfo.ResponseWrapper secRes,
        FEC_GetPaymentInfo.ResponseWrapper paymentRes
    ) {
        if (customerHistoryId == null) return;
        List<FEC_Payment_History__c> existing = [
            SELECT Id FROM FEC_Payment_History__c WHERE FEC_Customer_History__c = :customerHistoryId
        ];
        if (!existing.isEmpty()) delete existing;

        List<FEC_GetLoanBasicInfo.PaymentHistory> basicPh = (basicRes != null && basicRes.LoanBasicInfo != null && basicRes.LoanBasicInfo.PaymentHistories != null)
            ? basicRes.LoanBasicInfo.PaymentHistories : new List<FEC_GetLoanBasicInfo.PaymentHistory>();
        List<FEC_GetLoanSecInfo.PaymentHistory> secPh = (secRes != null && secRes.LoanSecInfo != null && secRes.LoanSecInfo.PaymentHistories != null)
            ? secRes.LoanSecInfo.PaymentHistories : new List<FEC_GetLoanSecInfo.PaymentHistory>();
        List<FEC_GetPaymentInfo.PaymentInfo> payments = (paymentRes != null && paymentRes.Payments != null)
            ? paymentRes.Payments : new List<FEC_GetPaymentInfo.PaymentInfo>();

        Integer rowCount = Math.max(Math.max(basicPh.size(), secPh.size()), payments.size());
        if (rowCount == 0) return;

        Decimal totalPaymentAmount = 0;
        for (Integer j = 0; j < secPh.size(); j++) {
            if (secPh[j].AmountOfMoney != null) totalPaymentAmount += secPh[j].AmountOfMoney;
        }

        List<FEC_Payment_History__c> toInsert = new List<FEC_Payment_History__c>();
        for (Integer i = 0; i < rowCount; i++) {
            FEC_Payment_History__c rec = new FEC_Payment_History__c();
            rec.FEC_Customer_History__c = customerHistoryId;
            rec.FEC_Payment_No__c = i + 1;
            // GetPaymentInfo: TransactionDate→FEC_Payment_Date__c, AmountPaid→FEC_Payment_Amount__c, Username→FEC_Payment_Channel__c
            // GetLoanSecInfo: BookingDate→FEC_Booking_Date__c, AmountOfMoney→FEC_Payment_Amount__c, ChkNo→FEC_Particulars__c, ValueDate→FEC_Payment_Date__c
            // GetLoanBasicInfo: ValueDate→FEC_Payment_Date__c, AmountOfMoney→FEC_Payment_Amount__c
            if (i < payments.size()) {
                rec.FEC_Payment_Date__c = parseTransactionDateToDate(payments[i].TransactionDate);
                if (rec.FEC_Payment_Date__c == null) rec.FEC_Payment_Date__c = (i < secPh.size() && secPh[i].ValueDate != null) ? secPh[i].ValueDate : (i < basicPh.size() ? basicPh[i].ValueDate : null);
                rec.FEC_Payment_Amount__c = payments[i].AmountPaid != null ? payments[i].AmountPaid : (i < secPh.size() ? secPh[i].AmountOfMoney : (i < basicPh.size() ? basicPh[i].AmountOfMoney : null));
                rec.FEC_Payment_Channel__c = payments[i].Username != null ? payments[i].Username : null;
            } else {
                rec.FEC_Payment_Date__c = (i < secPh.size() && secPh[i].ValueDate != null) ? secPh[i].ValueDate : (i < basicPh.size() ? basicPh[i].ValueDate : null);
                rec.FEC_Payment_Amount__c = i < secPh.size() ? secPh[i].AmountOfMoney : (i < basicPh.size() ? basicPh[i].AmountOfMoney : null);
                rec.FEC_Payment_Channel__c = null;
            }
            rec.FEC_Booking_Date__c = i < secPh.size() ? secPh[i].BookingDate : null;
            rec.FEC_Particulars__c = (i < secPh.size() && secPh[i].ChkNo != null) ? secPh[i].ChkNo : null;
            rec.FEC_Total_Payment_Amount__c = totalPaymentAmount != 0 ? totalPaymentAmount : null;
            toInsert.add(rec);
        }
        insert toInsert;
    }

    private static void fillRealTimePaymentFromApi(
        SectionDataResult result,
        FEC_GetPaymentInfo.ResponseWrapper paymentRes
    ) {
        result.realTimePaymentTable = new List<RealTimePaymentRowDTO>();
        if (paymentRes == null || paymentRes.Payments == null || paymentRes.Payments.isEmpty()) return;
        Integer idx = 0;
        for (FEC_GetPaymentInfo.PaymentInfo p : paymentRes.Payments) {
            RealTimePaymentRowDTO row = new RealTimePaymentRowDTO();
            row.rowIndex = ++idx;
            row.paymentDate = formatTransactionDateDDMMYYYY(p.TransactionDate);
            row.paymentAmount = FEC_CommonUltils.decimalToString(p.AmountPaid);
            row.paymentChannel = p.Username != null ? p.Username : HYPHEN;
            result.realTimePaymentTable.add(row);
        }
    }

    private static void fillRepaymentSchedulePaymentHistory(SectionDataResult result) {
        result.repaymentSchedulePaymentHistory = new List<FieldItemDTO>();

        if (result.repaymentScheduleTotals != null) {
            result.repaymentSchedulePaymentHistory.add(new FieldItemDTO(System.Label.FEC_Repay_Total_Installment_Amount_Label, result.repaymentScheduleTotals.totalInstallmentAmount != null ? result.repaymentScheduleTotals.totalInstallmentAmount : HYPHEN));
            result.repaymentSchedulePaymentHistory.add(new FieldItemDTO(System.Label.FEC_Repay_Total_Principal_Label, result.repaymentScheduleTotals.totalPrincipal != null ? result.repaymentScheduleTotals.totalPrincipal : HYPHEN));
            result.repaymentSchedulePaymentHistory.add(new FieldItemDTO(System.Label.FEC_Repay_Total_Interest_Label, result.repaymentScheduleTotals.totalInterest != null ? result.repaymentScheduleTotals.totalInterest : HYPHEN));
        }
        if (result.repaymentScheduleTable != null && !result.repaymentScheduleTable.isEmpty()) {
            for (RepaymentScheduleRowDTO row : result.repaymentScheduleTable) {
                result.repaymentSchedulePaymentHistory.add(new FieldItemDTO(System.Label.FEC_Repay_Installment_No_Label, row.installmentNo != null ? row.installmentNo : HYPHEN));
                result.repaymentSchedulePaymentHistory.add(new FieldItemDTO(System.Label.FEC_Repay_Installment_Due_Date_Label, row.dueDate != null ? row.dueDate : HYPHEN));
                result.repaymentSchedulePaymentHistory.add(new FieldItemDTO(System.Label.FEC_Repay_Opening_Principal_Label, row.openingPrincipal != null ? row.openingPrincipal : HYPHEN));
                result.repaymentSchedulePaymentHistory.add(new FieldItemDTO(System.Label.FEC_Repay_EMI_Label, row.emi != null ? row.emi : HYPHEN));
                result.repaymentSchedulePaymentHistory.add(new FieldItemDTO(System.Label.FEC_Repay_Repayment_Fee_Label, row.repaymentFee != null ? row.repaymentFee : HYPHEN));
                result.repaymentSchedulePaymentHistory.add(new FieldItemDTO(System.Label.FEC_Repay_Installment_Amount_Label, row.installmentAmount != null ? row.installmentAmount : HYPHEN));
                result.repaymentSchedulePaymentHistory.add(new FieldItemDTO(System.Label.FEC_Repay_Principal_Label, row.principal != null ? row.principal : HYPHEN));
                result.repaymentSchedulePaymentHistory.add(new FieldItemDTO(System.Label.FEC_Repay_Interest_Label, row.interest != null ? row.interest : HYPHEN));
                result.repaymentSchedulePaymentHistory.add(new FieldItemDTO(System.Label.FEC_Repay_Closing_Principal_Label, row.closingPrincipal != null ? row.closingPrincipal : HYPHEN));
            }
        }

        if (result.paymentHistoryTotals != null && result.paymentHistoryTotals.totalPaymentAmount != null) {
            result.repaymentSchedulePaymentHistory.add(new FieldItemDTO(System.Label.FEC_Repay_Total_Payment_Amount_Label, result.paymentHistoryTotals.totalPaymentAmount));
        }
        if (result.paymentHistoryTable != null && !result.paymentHistoryTable.isEmpty()) {
            for (PaymentHistoryRowDTO row : result.paymentHistoryTable) {
                result.repaymentSchedulePaymentHistory.add(new FieldItemDTO(System.Label.FEC_Repay_Payment_No_Label, FEC_CommonUltils.defaultToEmpty(row.paymentNo)));
                result.repaymentSchedulePaymentHistory.add(new FieldItemDTO(System.Label.FEC_Repay_Payment_Date_Label, row.paymentDate != null ? row.paymentDate : HYPHEN));
                result.repaymentSchedulePaymentHistory.add(new FieldItemDTO(System.Label.FEC_Repay_Booking_Date_Label, row.bookingDate != null ? row.bookingDate : HYPHEN));
                result.repaymentSchedulePaymentHistory.add(new FieldItemDTO(System.Label.FEC_Repay_Payment_Amount_Label, row.paymentAmount != null ? row.paymentAmount : HYPHEN));
                result.repaymentSchedulePaymentHistory.add(new FieldItemDTO(System.Label.FEC_Repay_Particulars_Label, row.particulars != null ? row.particulars : HYPHEN));
                result.repaymentSchedulePaymentHistory.add(new FieldItemDTO(System.Label.FEC_Repay_Payment_Channel_Label, row.paymentChannel != null ? row.paymentChannel : HYPHEN));
            }
        }
    }

    /** 4 section từ 3 API. */
    @AuraEnabled(cacheable=false)
    public static SectionDataResult getSectionData(Id caseId) {
        SectionDataResult result = new SectionDataResult();
        result.helpTexts = new Map<String, String>();
        result.helpTexts.putAll(FEC_CommonUltils.buildHelpTextMap(FEC_RePayment_Schedule__c.SObjectType));
        result.helpTexts.putAll(FEC_CommonUltils.buildHelpTextMap(FEC_Payment_History__c.SObjectType));
        result.errorMessage = null;
        result.repaymentScheduleTotals = new RepaymentScheduleTotalsDTO();
        result.repaymentScheduleTable = new List<RepaymentScheduleRowDTO>();
        result.paymentHistoryTotals = new PaymentHistoryTotalsDTO();
        result.paymentHistoryTable = new List<PaymentHistoryRowDTO>();
        result.realTimePaymentTable = new List<RealTimePaymentRowDTO>();
        result.repaymentSchedulePaymentHistory = new List<FieldItemDTO>();

        if (caseId == null) {
            result.errorMessage = String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'Case Id' });
            return result;
        }

        String contractNumber = getContractNumber(caseId);
        if (String.isBlank(contractNumber)) {
            result.errorMessage = System.Label.FEC_MSG_Error_API_Label;
            return result;
        }

        String transId = FEC_CommonUltils.generateTransactionId();
        String dateTimeStr = Datetime.now().formatGMT(FEC_ConstantCommon.DATETIME_FORMAT);
        String requestorId = FEC_ConstantCommon.REQUESTOR_CRM;

        FEC_GetLoanBasicInfo.ResponseWrapper basicRes = null;
        FEC_GetLoanSecInfo.ResponseWrapper secRes = null;
        FEC_GetPaymentInfo.ResponseWrapper paymentRes = null;

        try {
            basicRes = FEC_GetLoanBasicInfo.callGetLoanBasicInfo(transId, requestorId, dateTimeStr, contractNumber);
        } catch (Exception e) { }

        try {
            secRes = FEC_GetLoanSecInfo.callGetLoanSecInfo(transId, requestorId, dateTimeStr, contractNumber);
        } catch (Exception e) { }

        try {
            paymentRes = FEC_GetPaymentInfo.callGetPaymentInfo(transId, requestorId, dateTimeStr, contractNumber);
            if (paymentRes != null && paymentRes.Payments != null) {
                System.debug('### GetPaymentInfo success, contract=' + contractNumber + ', Payments count=' + paymentRes.Payments.size());
            }
        } catch (Exception e) {
            System.debug('### GetPaymentInfo failed, contract=' + contractNumber + ': ' + e.getMessage());
        }

        fillRepaymentScheduleFromBasic(result, basicRes);
        try {
            saveRepaymentScheduleToObject(caseId, basicRes);
        } catch (Exception e) {
            System.debug('### saveRepaymentScheduleToObject failed, case=' + caseId + ': ' + e.getMessage());
        }
        fillPaymentHistoryFromApis(result, basicRes, secRes, paymentRes);
        try {
            savePaymentHistoryToObject(getCustomerHistoryId(caseId), basicRes, secRes, paymentRes);
        } catch (Exception e) {
            System.debug('### savePaymentHistoryToObject failed, case=' + caseId + ': ' + e.getMessage());
        }
        fillRealTimePaymentFromApi(result, paymentRes);
        fillRepaymentSchedulePaymentHistory(result);

        return result;
    }

    /** Stub: LWC refresh. */
    @AuraEnabled
    public static void refreshRealTimePayment(Id caseId) {
        if (caseId == null) return;
    }
}
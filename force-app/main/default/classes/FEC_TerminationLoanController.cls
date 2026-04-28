/****************************************************************************************
 * File Name    : FEC_TerminationLoanController
 * Description  : Controller cho LWC Termination (Loan). Gọi GetLoanBasicInfo + GetLoanSecInfo.
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0      2026-03-13     toannd61            Create
****************************************************************************************/

public with sharing class FEC_TerminationLoanController {

    /** DTO trả về cho LWC. */
    public class TerminationDataDTO {
        @AuraEnabled public Map<String, String> helpTexts;
        @AuraEnabled public List<Map<String, Object>> earlyTermination;
        @AuraEnabled public List<Map<String, Object>> overdue;
        @AuraEnabled public List<Map<String, Object>> feeChargeList;
        @AuraEnabled public String error;
    }

    /** Lấy dữ liệu Termination từ GetLoanBasicInfo + GetLoanSecInfo. */
    @AuraEnabled(cacheable=false)
    public static TerminationDataDTO getTerminationData(Id caseId) {
        TerminationDataDTO dto = new TerminationDataDTO();
        dto.helpTexts = FEC_CommonUltils.buildHelpTextMap(FEC_Customer_History__c.SObjectType);
        dto.earlyTermination = new List<Map<String, Object>>();
        dto.overdue = new List<Map<String, Object>>();
        dto.feeChargeList = new List<Map<String, Object>>();
        
        if (caseId == null) {
            dto.error = String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'Case Id' });
            return dto;
        }

        List<Case> cases = [SELECT Id, FEC_Account_or_Contract__c FROM Case WHERE Id = :caseId LIMIT 1];
        if (cases.isEmpty() || cases[0].FEC_Account_or_Contract__c == null) {
            dto.error = System.Label.FEC_MSG_Error_API_Label;
            return dto;
        }

        List<FEC_Customer_History__c> histories = [
            SELECT Id, FEC_Contract_Number__c
            FROM FEC_Customer_History__c
            WHERE Id = :cases[0].FEC_Account_or_Contract__c
            LIMIT 1
        ];
        if (histories.isEmpty() || String.isBlank(histories[0].FEC_Contract_Number__c)) {
            dto.error = System.Label.FEC_MSG_Error_API_Label;
            return dto;
        }

        String contractNumber = histories[0].FEC_Contract_Number__c;
        String transId = FEC_CommonUltils.generateTransactionId();
        String dateTimeStr = Datetime.now().formatGMT(FEC_ConstantCommon.DATETIME_FORMAT);
        String requestorId = FEC_ConstantCommon.REQUESTOR_CRM;

        FEC_GetLoanBasicInfo.ResponseWrapper basicRes = null;
        FEC_GetLoanSecInfo.ResponseWrapper secRes = null;

        Map<String, Object> result = new Map<String, Object>();
        result.put('earlyTermination', dto.earlyTermination);
        result.put('overdue', dto.overdue);
        result.put('feeChargeList', dto.feeChargeList);

        try {
            basicRes = FEC_GetLoanBasicInfo.callGetLoanBasicInfo(transId, requestorId, dateTimeStr, contractNumber);
        } catch (Exception e) {
            dto.error = e.getMessage();
            return dto;
        }

        try {
            secRes = FEC_GetLoanSecInfo.callGetLoanSecInfo(transId, requestorId, dateTimeStr, contractNumber);
        } catch (Exception e) {
            dto.error = e.getMessage();
            return dto;
        }

        buildEarlyTermination(result, basicRes, secRes);
        buildOverdue(result, basicRes, secRes);
        buildFeeChargeList(result, basicRes);
        if (secRes?.LoanSecInfo != null) {
            saveEarlyTerminationToRecord(histories[0].Id, secRes);
        }
        if (basicRes?.LoanBasicInfo != null) {
            saveFeeChargeToRecord(histories[0].Id, basicRes);
        }
        dto.earlyTermination = (List<Map<String, Object>>)result.get('earlyTermination');
        dto.overdue = (List<Map<String, Object>>)result.get('overdue');
        dto.feeChargeList = (List<Map<String, Object>>)result.get('feeChargeList');
        return dto;
    }

    private static void buildEarlyTermination(
        Map<String, Object> result,
        FEC_GetLoanBasicInfo.ResponseWrapper basicRes,
        FEC_GetLoanSecInfo.ResponseWrapper secRes
    ) {
        List<Map<String, Object>> rows = new List<Map<String, Object>>();
        FEC_GetLoanSecInfo.Loan secLoan = secRes?.LoanSecInfo?.Loan;
        FEC_GetLoanSecInfo.TerminationSimulation termSim = secRes?.LoanSecInfo?.TerminationSimulation;
        FEC_GetLoanSecInfo.LPI lpi = secRes?.LoanSecInfo?.LPI;

        addField(rows, System.Label.FEC_Termination_Field_Termination_Amount_Label, termSim?.NetReceivable, true);
        addField(rows, System.Label.FEC_Termination_Field_Excess_Amount_Label, termSim?.ExcessAmounts, false);
        addField(rows, System.Label.FEC_Termination_Field_Pre_Payment_Penalty_Label, termSim?.PrePaymentPenalty, false);
        addField(rows, System.Label.FEC_Termination_Field_Total_Installment_Paid_Label, secLoan?.TotalInstallmentPaid, false);
        addField(rows, System.Label.FEC_Termination_Field_Current_Balance_Principal_Label, termSim?.CurrentBalancePrincipal, false);
        addField(rows, System.Label.FEC_Termination_Field_Pending_Penal_Interest_Label, lpi?.PendingPenalInt, false);
        addField(rows, System.Label.FEC_Termination_Field_Total_Principal_Paid_Label, secLoan?.TotalPrincipalPaid, false);
        addField(rows, System.Label.FEC_Termination_Field_Interest_On_Termination_Label, termSim?.InterestOnTermination, false);
        addField(rows, System.Label.FEC_Termination_Field_LPI_Paid_Label, lpi?.AppliedLPI, false);
        addField(rows, System.Label.FEC_Termination_Field_Total_Interest_Paid_Label, secLoan?.TotalInterestPaid, false);
        result.put('earlyTermination', rows);
    }

    /** Lưu Early Termination (LoanSecInfo) → FEC_Customer_History__c. */
    private static void saveEarlyTerminationToRecord(Id customerHistoryId, FEC_GetLoanSecInfo.ResponseWrapper secRes) {
        FEC_GetLoanSecInfo.Loan secLoan = secRes.LoanSecInfo.Loan;
        FEC_GetLoanSecInfo.TerminationSimulation termSim = secRes.LoanSecInfo.TerminationSimulation;
        FEC_GetLoanSecInfo.LPI lpi = secRes.LoanSecInfo.LPI;

        List<FEC_Customer_History__c> histories = [
            SELECT Id
            FROM FEC_Customer_History__c
            WHERE Id = :customerHistoryId
            LIMIT 1
        ];
        if (histories.isEmpty()) {
            return;
        }

        FEC_Customer_History__c rec = histories[0];
        rec.FEC_Termination_Amount__c = termSim?.NetReceivable;
        rec.FEC_Excess_Amount__c = termSim?.ExcessAmounts;
        rec.FEC_Pre_Payment_Penalty__c = termSim?.PrePaymentPenalty;
        rec.FEC_Total_Installment_Paid__c = secLoan?.TotalInstallmentPaid;
        rec.FEC_Current_Balance_Principal__c = termSim?.CurrentBalancePrincipal;
        rec.FEC_Pending_Penal_Interest__c = lpi?.PendingPenalInt;
        rec.FEC_Total_Principal_Paid__c = secLoan?.TotalPrincipalPaid;
        rec.FEC_Interest_On_Termination__c = termSim?.InterestOnTermination;
        rec.FEC_LPI_Paid__c = lpi?.AppliedLPI;
        rec.FEC_Total_Interest_Paid__c = secLoan?.TotalInterestPaid;
        rec.FEC_Total_Overdue_Amount__c = termSim?.TotalDues;
        rec.FEC_Installments_Overdue__c = termSim?.InstallmentsOverdue;
        rec.FEC_Penalty_Fee_Overdue__c = termSim?.PenaltyFeeOverdue;
        rec.FEC_Repayment_Fee_Overdue__c = termSim?.RepaymentFeeOverdue;

        update rec;
    }

    /** Lưu Fee/Charge + Overdue (GetLoanBasicInfo) → FEC_Customer_History__c. */
    private static void saveFeeChargeToRecord(Id customerHistoryId, FEC_GetLoanBasicInfo.ResponseWrapper basicRes) {
        FEC_GetLoanBasicInfo.InterestOnOverdueInterest iooi = basicRes?.LoanBasicInfo?.InterestOnOverdueInterest;
        FEC_GetLoanBasicInfo.PassDue passDue = basicRes?.LoanBasicInfo?.PassDue;
        FEC_GetLoanBasicInfo.Product product = basicRes?.LoanBasicInfo?.Product;
        if (iooi == null && passDue == null && product == null) {
            return;
        }

        List<FEC_Customer_History__c> histories = [
            SELECT Id
            FROM FEC_Customer_History__c
            WHERE Id = :customerHistoryId
            LIMIT 1
        ];
        if (histories.isEmpty()) {
            return;
        }
        FEC_Customer_History__c rec = histories[0];

        if (iooi != null) {
            rec.FEC_Assessed_Amount__c = iooi.AssessedAmount;
            rec.FEC_Collected_Amount__c = iooi.CollectedAmount;
            rec.FEC_Waived_Amount__c = iooi.WaivedAmount;
            rec.FEC_Outstanding_Amount__c = iooi.OutstandingAmount;
        }
        if (passDue != null) {
            rec.FEC_Overdue_Penalty__c = parseDecimalFromString(String.valueOf(passDue.OverduePenalty));
        }
        if (product != null) {
            rec.FEC_Principal_Overdue__c = product.PrincipalDue;
            rec.FEC_Interest_Overdue__c = product.InterestDue;
        }
        update rec;
    }

    private static void buildOverdue(
        Map<String, Object> result,
        FEC_GetLoanBasicInfo.ResponseWrapper basicRes,
        FEC_GetLoanSecInfo.ResponseWrapper secRes
    ) {
        List<Map<String, Object>> rows = new List<Map<String, Object>>();
        FEC_GetLoanBasicInfo.PassDue passDue = basicRes?.LoanBasicInfo?.PassDue;
        FEC_GetLoanBasicInfo.Product product = basicRes?.LoanBasicInfo?.Product;
        FEC_GetLoanSecInfo.TerminationSimulation termSim = secRes?.LoanSecInfo?.TerminationSimulation;

        addField(rows, System.Label.FEC_Termination_Field_Total_Overdue_Amount_Label, termSim?.TotalDues, false);
        addField(rows, System.Label.FEC_Termination_Field_Principal_Overdue_Label, product?.PrincipalDue, false);
        addField(rows, System.Label.FEC_Termination_Field_Interest_Overdue_Label, product?.InterestDue, false);
        addField(rows, System.Label.FEC_Termination_Field_Installments_Overdue_Label, termSim?.InstallmentsOverdue, false);
        addField(rows, System.Label.FEC_Termination_Field_Penalty_Fee_Overdue_Label, termSim?.PenaltyFeeOverdue, false);
        addField(rows, System.Label.FEC_Termination_Field_Overdue_Penalty_Label, passDue?.OverduePenalty, false);

        result.put('overdue', rows);
    }

    private static void buildFeeChargeList(
        Map<String, Object> result,
        FEC_GetLoanBasicInfo.ResponseWrapper basicRes
    ) {
        List<Map<String, Object>> listData = new List<Map<String, Object>>();

        FEC_GetLoanBasicInfo.InterestOnOverdueInterest iooi = basicRes?.LoanBasicInfo?.InterestOnOverdueInterest;
        if (iooi != null) {
            listData.add(buildFeeRow('Interest on Overdue Interest', iooi.AssessedAmount, iooi.CollectedAmount, iooi.WaivedAmount, iooi.OutstandingAmount));
        }

        result.put('feeChargeList', listData);
    }

    private static Map<String, Object> buildFeeRow(String typeName, Decimal assessed, Decimal collected, Decimal waived, Decimal outstanding) {
        Map<String, Object> row = new Map<String, Object>();
        row.put('type', typeName);
        row.put('assessedAmount', assessed);
        row.put('collectedAmount', collected);
        row.put('waivedAmount', waived != null ? waived : 0);
        row.put('outstandingAmount', outstanding);
        return row;
    }

    private static void addField(List<Map<String, Object>> rows, String label, Decimal value, Boolean isNegative) {
        Map<String, Object> m = new Map<String, Object>();
        m.put('label', label);
        m.put('value', value);
        m.put(
            'valueFormatted',
            value != null ? FEC_CommonUltils.formatDecimalPlainScale(value, 2) : null
        );
        m.put('isNegative', isNegative != null && isNegative);
        rows.add(m);
    }

    private static Decimal parseDecimalFromString(String s) {
        if (String.isBlank(s)) {
            return null;
        }
        try {
            return Decimal.valueOf(s.trim());
        } catch (Exception e) {
            return null;
        }
    }
}
/****************************************************************************************
 * File Name    : FEC_IncorrectPaymentController.cls
 * Description  : Controller for Incorrect Payment Handling LWC - GetLoanSecInfo (PaymentHistories), subcode config, save adjustments.
 ****************************************************************************************/

public with sharing class FEC_IncorrectPaymentController {
    public class PaymentDTO {
        @AuraEnabled public String id;
        @AuraEnabled public String paymentNo;
        @AuraEnabled public String paymentDate;
        @AuraEnabled public String bookingDate;
        @AuraEnabled public Decimal paymentAmount;
        @AuraEnabled public String particulars;
    }

    public class SubCodeConfigDTO {
        @AuraEnabled public String subCode;
        @AuraEnabled public String incorrectContractNumber;
        @AuraEnabled public String paymentMethod;
        @AuraEnabled public String billDate;
        @AuraEnabled public Decimal billAmount;
        @AuraEnabled public String correctContractNumber;
        @AuraEnabled public Decimal adjustedAmount;
    }

    public class AdjustmentDTO {
        @AuraEnabled public String correctContract { get; set; }
        @AuraEnabled public Decimal adjustedAmount { get; set; }
        
        // Constructor for JSON deserialization
        public AdjustmentDTO() {
            this.correctContract = null;
            this.adjustedAmount = null;
        }
    }

    @AuraEnabled
    public static List<PaymentDTO> getPaymentHistoryFromSOAP(String contractNumber) {
        if (String.isBlank(contractNumber)) {
            return new List<PaymentDTO>();
        }
        String trimmed = contractNumber.trim();
        FEC_GetLoanSecInfo.ResponseWrapper loanRes;
        try {
            loanRes = FEC_GetLoanSecInfo.getLoanSecInfo(trimmed);
            if (loanRes == null || loanRes.Sys == null || loanRes.Sys.Code != 1) {
                String msg = (loanRes != null && loanRes.Sys != null && String.isNotBlank(loanRes.Sys.Description))
                    ? loanRes.Sys.Description
                    : Label.FEC_MSG_IncorrectPayment_LoanInfo_NotRetrieved;
                throw new AuraHandledException(msg);
            }
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(String.isNotBlank(e.getMessage()) ? e.getMessage() : Label.FEC_MSG_IncorrectPayment_LoanInfo_NotRetrieved);
        }
        List<PaymentDTO> result = new List<PaymentDTO>();
        List<FEC_GetLoanSecInfo.PaymentHistory> histories = (loanRes != null && loanRes.LoanSecInfo != null && loanRes.LoanSecInfo.PaymentHistories != null)
            ? loanRes.LoanSecInfo.PaymentHistories
            : new List<FEC_GetLoanSecInfo.PaymentHistory>();
        Integer idx = 0;
        for (Integer i = 0; i < histories.size(); i++) {
            FEC_GetLoanSecInfo.PaymentHistory ph = histories[i];
            if (ph == null) {
                continue;
            }
            PaymentDTO dto = new PaymentDTO();
            dto.id = FEC_ConstantCommon.PAYMENT_PREFIX + String.valueOf(idx);
            dto.paymentNo = String.valueOf(idx + 1);
            dto.paymentDate = FEC_CommonUltils.formatDateDDMMYYYY(ph.ValueDate);
            dto.bookingDate = FEC_CommonUltils.formatDateDDMMYYYY(ph.BookingDate);
            dto.paymentAmount = ph.AmountOfMoney;
            dto.particulars = ph.ChkNo != null ? ph.ChkNo : FEC_ConstantCommon.STR_EMPTY;
            result.add(dto);
            idx++;
        }
        return result;
    }

    @AuraEnabled
    public static SubCodeConfigDTO getSubCodeConfig(Id caseId) {
        SubCodeConfigDTO dto = new SubCodeConfigDTO();
        dto.subCode = FEC_ConstantCommon.STR_EMPTY;
        dto.incorrectContractNumber = FEC_ConstantCommon.STR_EMPTY;
        dto.paymentMethod = FEC_ConstantCommon.STR_EMPTY;
        dto.billDate = null;
        dto.billAmount = null;
        dto.correctContractNumber = FEC_ConstantCommon.STR_EMPTY;
        dto.adjustedAmount = null;
        if (caseId == null) return dto;
        List<Case> cases = [
            SELECT Id, FEC_SubCode__c, FEC_Incorrect_Contract_Number__c, FEC_Payment_Method__c,
                FEC_Bill_Date__c, FEC_Bill_Amount__c, FEC_Correct_Contract_Number__c, FEC_Adjusted_Amount__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        if (cases.isEmpty()) return dto;
        dto.incorrectContractNumber = cases[0].FEC_Incorrect_Contract_Number__c != null ? cases[0].FEC_Incorrect_Contract_Number__c : FEC_ConstantCommon.STR_EMPTY;
        dto.paymentMethod = cases[0].FEC_Payment_Method__c != null ? cases[0].FEC_Payment_Method__c : FEC_ConstantCommon.STR_EMPTY;
        dto.billDate = cases[0].FEC_Bill_Date__c != null ? String.valueOf(cases[0].FEC_Bill_Date__c) : null;
        dto.billAmount = cases[0].FEC_Bill_Amount__c;
        dto.correctContractNumber = cases[0].FEC_Correct_Contract_Number__c != null ? cases[0].FEC_Correct_Contract_Number__c : FEC_ConstantCommon.STR_EMPTY;
        dto.adjustedAmount = cases[0].FEC_Adjusted_Amount__c;
        if (cases[0].FEC_SubCode__c == null) return dto;
        Id subCodeId = cases[0].FEC_SubCode__c;
        List<FEC_Nature_of_Case__c> nocs = [
            SELECT Id, FEC_Sub_Code__c, FEC_Sub_Code__r.FEC_Code__c
            FROM FEC_Nature_of_Case__c
            WHERE FEC_Sub_Code__c = :subCodeId
            LIMIT 1
        ];
        if (nocs.isEmpty() || nocs[0].FEC_Sub_Code__r == null) return dto;
        dto.subCode = nocs[0].FEC_Sub_Code__r.FEC_Code__c != null ? nocs[0].FEC_Sub_Code__r.FEC_Code__c : FEC_ConstantCommon.STR_EMPTY;
        return dto;
    }

    @AuraEnabled(cacheable=true)
    public static List<FEC_CommonUltils.PicklistOption> getPaymentMethodOptions() {
        List<FEC_CommonUltils.PicklistOption> result = new List<FEC_CommonUltils.PicklistOption>();
        
        Schema.DescribeFieldResult fieldResult = Case.FEC_Payment_Method__c.getDescribe();
        List<Schema.PicklistEntry> picklistEntries = fieldResult.getPicklistValues();
        
        for (Schema.PicklistEntry entry : picklistEntries) {
            if (entry.isActive()) {
                result.add(new FEC_CommonUltils.PicklistOption(entry.getLabel(), entry.getValue(), null));
            }
        }
        
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<FEC_CommonUltils.PicklistOption> getIncorrectContractOptions(Id caseId) {
        List<FEC_CommonUltils.PicklistOption> result = new List<FEC_CommonUltils.PicklistOption>();
        
        // Get picklist values from field metadata
        Schema.DescribeFieldResult fieldResult = Case.FEC_Correct_Contract_Number__c.getDescribe();
        List<Schema.PicklistEntry> picklistEntries = fieldResult.getPicklistValues();
        
        for (Schema.PicklistEntry entry : picklistEntries) {
            if (entry.isActive()) {
                result.add(new FEC_CommonUltils.PicklistOption(entry.getLabel(), entry.getValue(), null));
            }
        }
        
        // Also add contract numbers from Case if available
        if (caseId != null && Schema.sObjectType.Case.isAccessible()) {
            List<Case> cases = [
                SELECT FEC_Contract_Number__c, FEC_Incorrect_Contract_Number__c,
                    FEC_Account_or_Contract__r.FEC_Contract_Number__c
                FROM Case
                WHERE Id = :caseId
                LIMIT 1
            ];
            
            if (!cases.isEmpty()) {
                Case c = cases[0];
                Set<String> existingValues = new Set<String>();
                for (FEC_CommonUltils.PicklistOption opt : result) {
                    existingValues.add(opt.value);
                }
                
                // Add contract numbers from Case if not already in picklist
                addContractIfNotExists(result, existingValues, c.FEC_Contract_Number__c);
                addContractIfNotExists(result, existingValues, c.FEC_Incorrect_Contract_Number__c);
                if (c.FEC_Account_or_Contract__r != null) {
                    addContractIfNotExists(result, existingValues, c.FEC_Account_or_Contract__r.FEC_Contract_Number__c);
                }
            }
        }
        
        return result;
    }
    
    private static void addContractIfNotExists(List<FEC_CommonUltils.PicklistOption> opts, Set<String> existingValues, String contractNum) {
        if (String.isBlank(contractNum)) {
            return;
        }
        String trimmed = contractNum.trim();
        if (existingValues.contains(trimmed)) {
            return;
        }
        existingValues.add(trimmed);
        opts.add(new FEC_CommonUltils.PicklistOption(trimmed, trimmed, null));
    }

    @AuraEnabled
    public static void saveAdjustment(
        Id caseId,
        String incorrectContract,
        String paymentMethod,
        String billDate,
        Decimal billAmount,
        List<AdjustmentDTO> adjustments
    ) {
        if (caseId == null) {
            throw new AuraHandledException(
                String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'Case Id'})
            );
        }
        if (adjustments == null || adjustments.isEmpty()) {
            throw new AuraHandledException(
                String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'Adjustments'})
            );
        }
        
        List<AdjustmentDTO> validAdjs = new List<AdjustmentDTO>();
        for (AdjustmentDTO adj : adjustments) {
            // Check if row has both Correct Contract and Adjusted Amount filled
            Boolean hasCorrectContract = adj != null && String.isNotBlank(adj.correctContract);
            Boolean hasAdjustedAmount = adj != null && adj.adjustedAmount != null;
            Boolean rowOk = hasCorrectContract && hasAdjustedAmount;
            
            if (rowOk) {
                validAdjs.add(adj);
            }
        }
        
        if (validAdjs.isEmpty()) {
            throw new AuraHandledException(Label.FEC_MSG_IncorrectPayment_No_Valid_Adjustment_Row);
        }
        AdjustmentDTO first = validAdjs[0];
        if (String.isBlank(paymentMethod)) {
            throw new AuraHandledException(
                String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'Payment Method'})
            );
        }
        if (billAmount != null && billAmount != 0 && !validAdjs.isEmpty()) {
            Decimal sumAdjusted = 0;
            for (AdjustmentDTO adj : validAdjs) {
                sumAdjusted += adj.adjustedAmount;
            }
            if (Math.abs(sumAdjusted - billAmount) > 0.01) {
                throw new AuraHandledException(Label.FEC_MSG_Adjusted_Amount_Must_Equal_Payment);
            }
        }
        List<Case> cases = [
            SELECT Id, FEC_Bill_Date__c, FEC_Bill_Amount__c, FEC_Correct_Contract_Number__c, FEC_Adjusted_Amount__c, FEC_Incorrect_Contract_Number__c, FEC_Payment_Method__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        if (cases.isEmpty()) {
            throw new AuraHandledException(Label.FEC_MSG_IncorrectPayment_Case_Not_Found);
        }
        if (!Schema.sObjectType.Case.isUpdateable()) {
            throw new AuraHandledException(Label.FEC_MSG_IncorrectPayment_No_Update_Case_Access);
        }
        
        // Update Case fields
        Case c = cases[0];
        if (String.isNotBlank(billDate)) {
            try {
                c.FEC_Bill_Date__c = Date.valueOf(billDate);
            } catch (Exception e) {
                c.FEC_Bill_Date__c = null;
            }
        } else {
            c.FEC_Bill_Date__c = null;
        }
        c.FEC_Bill_Amount__c = billAmount != null ? billAmount : null;
        c.FEC_Incorrect_Contract_Number__c = String.isNotBlank(incorrectContract) ? incorrectContract.trim() : null;
        c.FEC_Payment_Method__c = paymentMethod != null ? paymentMethod.trim() : null;
        c.FEC_Correct_Contract_Number__c = String.isNotBlank(first.correctContract) ? first.correctContract.trim() : null;
        c.FEC_Adjusted_Amount__c = first.adjustedAmount != null ? first.adjustedAmount : null;
        List<Case> toUpdate = new List<Case>{ c };
        toUpdate = (List<Case>) Security.stripInaccessible(AccessType.UPDATABLE, toUpdate).getRecords();
        if (toUpdate.isEmpty()) {
            throw new AuraHandledException(Label.FEC_MSG_IncorrectPayment_No_Update_Case_Fields_Access);
        }
        
        try {
            update toUpdate;
        } catch (DmlException e) {
            throw new AuraHandledException(e.getDmlMessage(0));
        }
    }
}
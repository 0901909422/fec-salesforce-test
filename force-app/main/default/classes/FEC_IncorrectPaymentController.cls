/****************************************************************************************
 * File Name    : FEC_IncorrectPaymentController.cls
 * Description  : Controller for Incorrect Payment Handling LWC - GetLoanSecInfo (PaymentHistories), subcode config, save adjustments.
 ****************************************************************************************/

public without sharing class FEC_IncorrectPaymentController {
    public class PaymentDTO {
        @AuraEnabled public String id;
        @AuraEnabled public String paymentNo;
        @AuraEnabled public String paymentDate;
        @AuraEnabled public String bookingDate;
        @AuraEnabled public Decimal paymentAmount;
        @AuraEnabled public String particulars;
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

    public class SubCodeConfigDTO {
        @AuraEnabled public String subCode;
        @AuraEnabled public String incorrectContractNumber;
        @AuraEnabled public String paymentMethod;
        @AuraEnabled public String billDate;
        @AuraEnabled public Decimal billAmount;
        @AuraEnabled public String correctContractNumber;
        @AuraEnabled public String inputCorrectContractNumber;
        @AuraEnabled public Decimal adjustedAmount;
        @AuraEnabled public List<AdjustmentDTO> adjustmentRows;
        @AuraEnabled public String selectedPaymentHistoryId;
    }

    // 18/06/2026 17:30 linhdev - API 24 GetLoanSecInfo: ContractNumber = giá trị user chọn từ API 20 (Applications.ContractNumber)
    @AuraEnabled
    public static List<PaymentDTO> getPaymentHistoryFromSOAP(Id caseId, String contractNumber) {
        if (String.isBlank(contractNumber)) {
            return new List<PaymentDTO>();
        }
        String trimmed = contractNumber.trim();
        FEC_GetLoanSecInfo.ResponseWrapper loanRes;
        try {
            loanRes = FEC_GetLoanSecInfo.getLoanSecInfo(trimmed);
        } catch (Exception e) {
            // 19/06/2026 linhdev - không throw sau callout: Aura rollback sẽ hủy @future ghi FEC_API_Log__c
            return new List<PaymentDTO>();
        }
        if (loanRes == null || loanRes.Sys == null || loanRes.Sys.Code != 1) {
            return new List<PaymentDTO>();
        }
        List<FEC_GetLoanSecInfo.PaymentHistory> histories = (loanRes.LoanSecInfo != null && loanRes.LoanSecInfo.PaymentHistories != null)
                ? loanRes.LoanSecInfo.PaymentHistories
                : new List<FEC_GetLoanSecInfo.PaymentHistory>();
            List<FEC_GetLoanSecInfo.PaymentHistory> sortedHistories = sortPaymentHistoriesNewestFirst(histories);
            if (sortedHistories.isEmpty()) {
                return new List<PaymentDTO>();
            }
            Id customerHistoryId = getCustomerHistoryIdFromCase(caseId);
            List<FEC_Payment_History__c> savedRows = saveIncorrectPaymentHistoryToObject(customerHistoryId, sortedHistories);
            List<PaymentDTO> result = new List<PaymentDTO>();
            Integer idx = 0;
            for (Integer i = 0; i < sortedHistories.size(); i++) {
                FEC_GetLoanSecInfo.PaymentHistory ph = sortedHistories[i];
                if (ph == null) {
                    continue;
                }
                FEC_Payment_History__c rec = (savedRows != null && i < savedRows.size()) ? savedRows[i] : null;
                PaymentDTO dto = new PaymentDTO();
                dto.id = (rec != null && rec.Id != null)
                    ? String.valueOf(rec.Id)
                    : FEC_ConstantCommon.PAYMENT_PREFIX + String.valueOf(idx);
                dto.paymentNo = (rec != null && rec.FEC_Payment_No__c != null)
                    ? String.valueOf(rec.FEC_Payment_No__c)
                    : String.valueOf(idx + 1);
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
        dto.inputCorrectContractNumber = FEC_ConstantCommon.STR_EMPTY;
        dto.adjustedAmount = null;
        dto.adjustmentRows = null;
        if (caseId == null) return dto;
        List<Case> cases = [
            SELECT Id, FEC_SubCode__c, FEC_Incorrect_Contract_Number__c, FEC_Payment_Method__c,
                FEC_Bill_Date__c, FEC_Bill_Amount__c,
                FEC_Correct_Contract_Number__c,
                FEC_Input_Correct_Contract_Number__c, FEC_Adjusted_Amount__c,
                FEC_Incorrect_Payment_Adj_Rows__c, FEC_Selected_Payment_History__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        if (cases.isEmpty()) return dto;
        dto.incorrectContractNumber = cases[0].FEC_Incorrect_Contract_Number__c != null ? cases[0].FEC_Incorrect_Contract_Number__c : FEC_ConstantCommon.STR_EMPTY;
        dto.paymentMethod = cases[0].FEC_Payment_Method__c != null ? cases[0].FEC_Payment_Method__c : FEC_ConstantCommon.STR_EMPTY;
        dto.billDate = cases[0].FEC_Bill_Date__c != null ? String.valueOf(cases[0].FEC_Bill_Date__c) : null;
        dto.billAmount = cases[0].FEC_Bill_Amount__c;
        // 18/06/2026 14:00 linhdev - FEC_Correct_Contract_Number__c là Text; fallback FEC_Input_Correct_Contract_Number__c cho dữ liệu cũ
        dto.correctContractNumber = cases[0].FEC_Correct_Contract_Number__c != null ? cases[0].FEC_Correct_Contract_Number__c : FEC_ConstantCommon.STR_EMPTY;
        if (String.isBlank(dto.correctContractNumber) && cases[0].FEC_Input_Correct_Contract_Number__c != null) {
            dto.correctContractNumber = cases[0].FEC_Input_Correct_Contract_Number__c;
        }
        dto.inputCorrectContractNumber = cases[0].FEC_Input_Correct_Contract_Number__c != null ? cases[0].FEC_Input_Correct_Contract_Number__c : FEC_ConstantCommon.STR_EMPTY;
        dto.adjustedAmount = cases[0].FEC_Adjusted_Amount__c;
        dto.selectedPaymentHistoryId = cases[0].FEC_Selected_Payment_History__c != null
            ? String.valueOf(cases[0].FEC_Selected_Payment_History__c)
            : null;
        String adjRowsJson = cases[0].FEC_Incorrect_Payment_Adj_Rows__c;
        if (String.isNotBlank(adjRowsJson)) {
            try {
                List<AdjustmentDTO> parsedRows = (List<AdjustmentDTO>) JSON.deserialize(adjRowsJson.trim(), List<AdjustmentDTO>.class);
                if (parsedRows != null && !parsedRows.isEmpty()) {
                    dto.adjustmentRows = parsedRows;
                }
            } catch (Exception parseEx) {
                dto.adjustmentRows = null;
            }
        }
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

    // 18/06/2026 16:00 linhdev - lưu FEC_Selected_Payment_History__c khi user chọn dòng Payment History
    @AuraEnabled
    public static void saveSelectedPaymentHistory(Id caseId, Id paymentHistoryId) {
        if (caseId == null) {
            throw new AuraHandledException(
                String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'Case Id'})
            );
        }
        List<Case> cases = [SELECT Id FROM Case WHERE Id = :caseId LIMIT 1];
        if (cases.isEmpty()) {
            throw new AuraHandledException(Label.FEC_MSG_IncorrectPayment_Case_Not_Found);
        }
        Case c = cases[0];
        c.FEC_Selected_Payment_History__c = paymentHistoryId;
        try {
            update new List<Case>{ c };
        } catch (DmlException e) {
            throw new AuraHandledException(e.getDmlMessage(0));
        }
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

    // 18/06/2026 10:00 linhdev - API 20 GetCustomerList cho Correct Account/Contract (Add Item)
    @AuraEnabled
    public static List<FEC_CommonUltils.PicklistOption> getCorrectContractOptions(Id caseId) {
        return getLoanContractOptionsFromApi(caseId);
    }

    // 18/06/2026 10:00 linhdev - API 20 GetCustomerList cho Incorrect Contract Number
    @AuraEnabled
    public static List<FEC_CommonUltils.PicklistOption> getIncorrectContractOptions(Id caseId) {
        return getLoanContractOptionsFromApi(caseId);
    }

    // 18/06/2026 17:30 linhdev - Gọi API 20, chỉ trả ContractNumber từ Applications (không merge Account/Contract trên Salesforce)
    @AuraEnabled
    public static List<FEC_CommonUltils.PicklistOption> getLoanContractOptionsFromApi(Id caseId) {
        List<FEC_CommonUltils.PicklistOption> result = new List<FEC_CommonUltils.PicklistOption>();
        if (caseId == null) {
            return result;
        }
        try {
            FEC_GetCustomerList.ResponseWrapper cusRes = callGetCustomerListForCase(caseId);
            Set<String> existingValues = new Set<String>();
            for (String contractNum : extractLoanContractNumbers(cusRes)) {
                addContractIfNotExists(result, existingValues, contractNum);
            }
        } catch (Exception apiEx) {
            System.debug('getLoanContractOptionsFromApi GetCustomerList failed: ' + apiEx.getMessage());
        }
        return result;
    }

    private static FEC_GetCustomerList.ResponseWrapper callGetCustomerListForCase(Id caseId) {
        if (caseId == null) {
            return null;
        }
        List<Case> cases = [
            SELECT FEC_National_ID_Passport_ID__c, FEC_Account_Contract_Number_Text__c,
                FEC_Account_or_Contract__c,
                FEC_Account_or_Contract__r.FEC_Account_Number__c,
                FEC_Account_or_Contract__r.FEC_Contract_Number__c,
                FEC_Product_Type__r.Name
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        if (cases.isEmpty()) {
            return null;
        }
        Case c = cases[0];
        String nationalId = c.FEC_National_ID_Passport_ID__c;
        String requestorId = FEC_ConstantCommon.REQUESTOR_PEGA_CSM_HYPHEN;
        // 18/06/2026 18:30 linhdev - luồng Incorrect Payment: truyền Case.FEC_Account_Contract_Number_Text__c vào API 20 (AccountNumber param)
        if (String.isNotBlank(c.FEC_Account_Contract_Number_Text__c)) {
            return FEC_GetCustomerList.getCustomerList(
                requestorId, null, false, null, nationalId, null, null, c.FEC_Account_Contract_Number_Text__c.trim(), null, null, null
            );
        }
        String rawAccountNumber = c.FEC_Account_or_Contract__r != null ? c.FEC_Account_or_Contract__r.FEC_Account_Number__c : null;
        String rawContractNumber = c.FEC_Account_or_Contract__r != null ? c.FEC_Account_or_Contract__r.FEC_Contract_Number__c : null;
        String productTypeName = c.FEC_Product_Type__r != null ? c.FEC_Product_Type__r.Name : null;
        String accountNumber = FEC_CommonUltils.resolveAccountNumber(productTypeName, rawAccountNumber, rawContractNumber);
        if (String.isNotBlank(accountNumber)) {
            return FEC_GetCustomerList.getCustomerList(
                requestorId, null, false, null, nationalId, null, null, accountNumber, null, null, null
            );
        }
        if (String.isNotBlank(rawContractNumber)) {
            return FEC_GetCustomerList.getCustomerList(
                requestorId, null, false, null, nationalId, null, null, null, rawContractNumber, null, null
            );
        }
        if (String.isNotBlank(nationalId)) {
            return FEC_GetCustomerList.getCustomerList(
                requestorId, null, false, null, nationalId, null, null, null, null, null, null
            );
        }
        return null;
    }

    private static List<String> extractLoanContractNumbers(FEC_GetCustomerList.ResponseWrapper res) {
        Set<String> contracts = new Set<String>();
        if (res == null || res.Customers == null) {
            return new List<String>();
        }
        for (FEC_GetCustomerList.Customer cust : res.Customers) {
            if (cust == null || cust.Applications == null) {
                continue;
            }
            for (FEC_GetCustomerList.Application app : cust.Applications) {
                if (app != null && String.isNotBlank(app.ContractNumber)) {
                    contracts.add(app.ContractNumber.trim());
                }
            }
        }
        List<String> sorted = new List<String>(contracts);
        sorted.sort();
        return sorted;
    }

    private static Id getCustomerHistoryIdFromCase(Id caseId) {
        if (caseId == null) {
            return null;
        }
        List<Case> cases = [SELECT FEC_Account_or_Contract__c FROM Case WHERE Id = :caseId LIMIT 1];
        return (cases.isEmpty() || cases[0].FEC_Account_or_Contract__c == null) ? null : cases[0].FEC_Account_or_Contract__c;
    }

    private static List<FEC_GetLoanSecInfo.PaymentHistory> sortPaymentHistoriesNewestFirst(
        List<FEC_GetLoanSecInfo.PaymentHistory> histories
    ) {
        List<FEC_GetLoanSecInfo.PaymentHistory> sorted = new List<FEC_GetLoanSecInfo.PaymentHistory>();
        if (histories == null) {
            return sorted;
        }
        for (FEC_GetLoanSecInfo.PaymentHistory ph : histories) {
            if (ph != null) {
                sorted.add(ph);
            }
        }
        sorted.sort(new PaymentHistoryDateDescComparator());
        return sorted;
    }

    private class PaymentHistoryDateDescComparator implements System.Comparator<FEC_GetLoanSecInfo.PaymentHistory> {
        public Integer compare(FEC_GetLoanSecInfo.PaymentHistory a, FEC_GetLoanSecInfo.PaymentHistory b) {
            Date da = a != null ? a.ValueDate : null;
            Date db = b != null ? b.ValueDate : null;
            if (da == null && db == null) {
                return 0;
            }
            if (da == null) {
                return 1;
            }
            if (db == null) {
                return -1;
            }
            if (da > db) {
                return -1;
            }
            if (da < db) {
                return 1;
            }
            return 0;
        }
    }

    private static List<FEC_Payment_History__c> saveIncorrectPaymentHistoryToObject(
        Id customerHistoryId,
        List<FEC_GetLoanSecInfo.PaymentHistory> secPh
    ) {
        List<FEC_Payment_History__c> inserted = new List<FEC_Payment_History__c>();
        if (secPh == null || secPh.isEmpty() || customerHistoryId == null) {
            return inserted;
        }
        List<FEC_Payment_History__c> existing = [
            SELECT Id FROM FEC_Payment_History__c WHERE FEC_Customer_History__c = :customerHistoryId
        ];
        if (!existing.isEmpty()) {
            delete existing;
        }
        List<FEC_Payment_History__c> toInsert = new List<FEC_Payment_History__c>();
        Integer paymentNo = 0;
        for (FEC_GetLoanSecInfo.PaymentHistory ph : secPh) {
            if (ph == null) {
                continue;
            }
            paymentNo++;
            FEC_Payment_History__c rec = new FEC_Payment_History__c();
            rec.FEC_Customer_History__c = customerHistoryId;
            rec.FEC_Payment_No__c = paymentNo;
            rec.FEC_Payment_Date__c = ph.ValueDate;
            rec.FEC_Booking_Date__c = ph.BookingDate;
            rec.FEC_Payment_Amount__c = ph.AmountOfMoney;
            rec.FEC_Particulars__c = ph.ChkNo;
            toInsert.add(rec);
        }
        if (!toInsert.isEmpty()) {
            insert toInsert;
            inserted.addAll(toInsert);
        }
        return inserted;
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

    // 18/06/2026 14:00 linhdev - FEC_Correct_Contract_Number__c là Text: lưu trực tiếp giá trị chọn từ API hoặc nhập tay
    private static void applyCorrectContractInputAndPicklist(Case c, String correctContract) {
        String trimmed = String.isNotBlank(correctContract) ? correctContract.trim() : null;
        c.FEC_Correct_Contract_Number__c = trimmed;
        c.FEC_Input_Correct_Contract_Number__c = trimmed;
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
            SELECT Id, FEC_Bill_Date__c, FEC_Bill_Amount__c,
                FEC_Correct_Contract_Number__c,
                FEC_Adjusted_Amount__c, FEC_Incorrect_Contract_Number__c, FEC_Payment_Method__c,
                FEC_Incorrect_Payment_Adj_Rows__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        if (cases.isEmpty()) {
            throw new AuraHandledException(Label.FEC_MSG_IncorrectPayment_Case_Not_Found);
        }
        
        // Update Case fields
        Case c = cases[0];
        c.FEC_Bill_Date__c = FEC_CommonUltils.toDateStr(billDate);
        c.FEC_Bill_Amount__c = billAmount != null ? billAmount : null;
        c.FEC_Incorrect_Contract_Number__c = String.isNotBlank(incorrectContract) ? incorrectContract.trim() : null;
        c.FEC_Payment_Method__c = paymentMethod != null ? paymentMethod.trim() : null;
        applyCorrectContractInputAndPicklist(c, first.correctContract);
        c.FEC_Adjusted_Amount__c = first.adjustedAmount != null ? first.adjustedAmount : null;
        c.FEC_Incorrect_Payment_Adj_Rows__c = JSON.serialize(validAdjs);
        Savepoint sp = Database.setSavepoint();
        try {
            update new List<Case>{ c };
            syncIncorrectPaymentInfoRows(caseId, validAdjs);
        } catch (AuraHandledException e) {
            Database.rollback(sp);
            throw e;
        } catch (DmlException e) {
            Database.rollback(sp);
            throw new AuraHandledException(e.getDmlMessage(0));
        }
    }
    //Fix jira FECREDIT_CSM_2025_KH-1271
    private static String resolveIncorrectPaymentInfoCorrectContractField(Map<String, Schema.SObjectField> fieldMap) {
        if (fieldMap.containsKey('fec_correct_account_contract__c')) {
            return 'FEC_Correct_Account_Contract__c';
        }
        if (fieldMap.containsKey('fec_correct_contract_number__c')) {
            return 'FEC_Correct_Contract_Number__c';
        }
        return null;
    }

    private static void syncIncorrectPaymentInfoRows(Id caseId, List<AdjustmentDTO> rows) {
        if (caseId == null || rows == null || rows.isEmpty()) {
            return;
        }
        Schema.SObjectType infoType = Schema.getGlobalDescribe().get('FEC_Incorrect_Payment_Info__c');
        if (infoType == null) {
            return;
        }
        String correctFieldApi = resolveIncorrectPaymentInfoCorrectContractField(infoType.getDescribe().fields.getMap());
        Id cid = caseId;
        List<SObject> toDelete = Database.query(
            'SELECT Id FROM FEC_Incorrect_Payment_Info__c WHERE FEC_Case__c = :cid'
        );
        if (!toDelete.isEmpty()) {
            delete toDelete;
        }
        List<SObject> toInsert = new List<SObject>();
        for (AdjustmentDTO adj : rows) {
            if (adj == null) {
                continue;
            }
            SObject rec = infoType.newSObject();
            rec.put('FEC_Case__c', caseId);
            if (String.isNotBlank(correctFieldApi)) {
                rec.put(correctFieldApi, String.isNotBlank(adj.correctContract) ? adj.correctContract.trim() : null);
            }
            rec.put('FEC_Adjusted_Amount__c', adj.adjustedAmount);
            toInsert.add(rec);
        }
        if (toInsert.isEmpty()) {
            return;
        }
        Database.insert(toInsert, true);
    }

    @AuraEnabled
    public static void saveAdjustmentDraft(
        Id caseId,
        String incorrectContract,
        String paymentMethod,
        String billDate,
        Decimal billAmount,
        String correctContract,
        Decimal adjustedAmount
    ) {
        if (caseId == null) {
            throw new AuraHandledException(
                String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'Case Id'})
            );
        }

        List<Case> cases = [
            SELECT Id, FEC_Bill_Date__c, FEC_Bill_Amount__c,
                FEC_Correct_Contract_Number__c,
                FEC_Adjusted_Amount__c, FEC_Incorrect_Contract_Number__c, FEC_Payment_Method__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        if (cases.isEmpty()) {
            throw new AuraHandledException(Label.FEC_MSG_IncorrectPayment_Case_Not_Found);
        }

        Case c = cases[0];
        c.FEC_Bill_Date__c = FEC_CommonUltils.toDateStr(billDate);
        c.FEC_Bill_Amount__c = billAmount != null ? billAmount : null;
        c.FEC_Incorrect_Contract_Number__c = String.isNotBlank(incorrectContract) ? incorrectContract.trim() : null;
        c.FEC_Payment_Method__c = String.isNotBlank(paymentMethod) ? paymentMethod.trim() : null;
        applyCorrectContractInputAndPicklist(c, correctContract);
        c.FEC_Adjusted_Amount__c = adjustedAmount != null ? adjustedAmount : null;

        try {
            update new List<Case>{ c };
        } catch (DmlException e) {
            throw new AuraHandledException(e.getDmlMessage(0));
        }
    }
}
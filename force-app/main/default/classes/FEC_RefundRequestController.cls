public with sharing class FEC_RefundRequestController {

    private static final String OBJ_CUSTOMER_HISTORY = 'FEC_Customer_History__c';
    private static final String FLD_BANK_NAME = 'FEC_Bank_Name__c';
    private static final String FLD_PROVINCE_CITY = 'FEC_Province_City__c';
    private static final String OBJ_BANK_NAME = 'FEC_Bank_Name__c';
    private static final String FLD_BANK_NAME_NOACCENT = 'FEC_Bank_Name_Noaccent__c';
    private static final String OBJ_BANK_BRANCH = 'FEC_Bank_Branch__c';
    private static final String FLD_BANK_BRANCH_NAME_NOACCENT = 'FEC_Bank_Branch_Name_Noaccent__c';

    public class RefundFormDefaultsDTO {
        @AuraEnabled public String customerHistoryId;
        @AuraEnabled public String defaultBeneficiaryUpperNoAccent;
        @AuraEnabled public String beneficiaryName;
        @AuraEnabled public String beneficiaryAccount;
        @AuraEnabled public String bankPicklistValue;
        @AuraEnabled public String bankBranch;
        @AuraEnabled public String provinceCity;
    }

    public class PicklistOptionDTO {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
    }

    public class ReceiptLineDTO {
        @AuraEnabled public String receiptDateIso;
        @AuraEnabled public Decimal receiptAmount;
        @AuraEnabled public String transactionNo;
        @AuraEnabled public String paymentChannel;
    }

    @AuraEnabled(cacheable=true)
    public static List<ReceiptLineDTO> getExistingReceiptLines(Id caseId) {
        List<ReceiptLineDTO> out = new List<ReceiptLineDTO>();
        if (caseId == null || !Schema.sObjectType.FEC_Case_Refund_Details__c.isAccessible()) {
            return out;
        }
        List<FEC_Case_Refund_Details__c> rows = [
            SELECT FEC_Receipt_Date__c, FEC_Receipt_Amount__c, FEC_Transaction_Number__c, FEC_Payment_Channel__c
            FROM FEC_Case_Refund_Details__c
            WHERE FEC_Case__c = :caseId
            ORDER BY CreatedDate
        ];
        rows = (List<FEC_Case_Refund_Details__c>) Security.stripInaccessible(AccessType.READABLE, rows).getRecords();
        for (FEC_Case_Refund_Details__c r : rows) {
            ReceiptLineDTO row = new ReceiptLineDTO();
            if (r.FEC_Receipt_Date__c != null) {
                row.receiptDateIso = String.valueOf(r.FEC_Receipt_Date__c);
            }
            row.receiptAmount = r.FEC_Receipt_Amount__c;
            row.transactionNo = r.FEC_Transaction_Number__c;
            row.paymentChannel = r.FEC_Payment_Channel__c;
            out.add(row);
        }
        return out;
    }

    public class SaveRefundResultDTO {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String errorMessage;
    }

    @AuraEnabled(cacheable=true)
    public static List<PicklistOptionDTO> getBankNamePicklistOptions() {
        List<PicklistOptionDTO> out = new List<PicklistOptionDTO>();
        Schema.SObjectType t = Schema.getGlobalDescribe().get(OBJ_BANK_NAME);
        if (t == null || !t.getDescribe().isAccessible()) {
            return out;
        }
        String soql = 'SELECT ' + FLD_BANK_NAME_NOACCENT + ' FROM ' + OBJ_BANK_NAME
            + ' WHERE ' + FLD_BANK_NAME_NOACCENT + ' != null ORDER BY ' + FLD_BANK_NAME_NOACCENT;
        List<SObject> rows = Security.stripInaccessible(AccessType.READABLE, Database.query(soql)).getRecords();
        Set<String> seen = new Set<String>();
        for (SObject r : rows) {
            String val = (String) r.get(FLD_BANK_NAME_NOACCENT);
            if (String.isBlank(val) || seen.contains(val)) {
                continue;
            }
            seen.add(val);
            PicklistOptionDTO row = new PicklistOptionDTO();
            row.label = val;
            row.value = val;
            out.add(row);
        }
        return out;
    }

    @AuraEnabled(cacheable=true)
    public static List<PicklistOptionDTO> getProvinceCityOptions() {
        return getPicklistOptions(OBJ_CUSTOMER_HISTORY, FLD_PROVINCE_CITY);
    }

    @AuraEnabled(cacheable=true)
    public static List<PicklistOptionDTO> getBankBranchOptions() {
        List<PicklistOptionDTO> out = new List<PicklistOptionDTO>();
        Schema.SObjectType t = Schema.getGlobalDescribe().get(OBJ_BANK_BRANCH);
        if (t == null || !t.getDescribe().isAccessible()) {
            return out;
        }
        String soql = 'SELECT ' + FLD_BANK_BRANCH_NAME_NOACCENT + ' FROM ' + OBJ_BANK_BRANCH
            + ' WHERE ' + FLD_BANK_BRANCH_NAME_NOACCENT + ' != null ORDER BY ' + FLD_BANK_BRANCH_NAME_NOACCENT;
        List<SObject> rows = Security.stripInaccessible(AccessType.READABLE, Database.query(soql)).getRecords();
        Set<String> seen = new Set<String>();
        for (SObject r : rows) {
            String val = (String) r.get(FLD_BANK_BRANCH_NAME_NOACCENT);
            if (String.isBlank(val) || seen.contains(val)) {
                continue;
            }
            seen.add(val);
            PicklistOptionDTO row = new PicklistOptionDTO();
            row.label = val;
            row.value = val;
            out.add(row);
        }
        return out;
    }

    @AuraEnabled(cacheable=true)
    public static RefundFormDefaultsDTO getRefundFormDefaults(Id caseId) {
        RefundFormDefaultsDTO dto = new RefundFormDefaultsDTO();
        if (caseId == null || !Schema.sObjectType.Case.isAccessible()) {
            return dto;
        }
        List<Case> caseRows = [
            SELECT Id,
                FEC_Account_or_Contract__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        caseRows = (List<Case>) Security.stripInaccessible(AccessType.READABLE, caseRows).getRecords();
        if (caseRows.isEmpty()) {
            return dto;
        }
        Case c = caseRows[0];
        if (c.FEC_Account_or_Contract__c == null || !Schema.sObjectType.FEC_Customer_History__c.isAccessible()) {
            return dto;
        }
        dto.customerHistoryId = c.FEC_Account_or_Contract__c;
        List<FEC_Customer_History__c> histories = [
            SELECT Id,
                FEC_Customer_Name__c,
                FEC_First_Name__c,
                FEC_Middle_Name__c,
                FEC_Last_Name__c,
                FEC_Beneficiary_Name__c,
                FEC_Beneficiary_Account__c,
                FEC_Bank_Name__c,
                FEC_Bank_Branch__c,
                FEC_Province_City__c
            FROM FEC_Customer_History__c
            WHERE Id = :c.FEC_Account_or_Contract__c
            LIMIT 1
        ];
        histories = (List<FEC_Customer_History__c>) Security.stripInaccessible(AccessType.READABLE, histories).getRecords();
        if (histories.isEmpty()) {
            return dto;
        }
        FEC_Customer_History__c h = histories[0];
        String rawName = h.FEC_Customer_Name__c;
        if (String.isBlank(rawName)) {
            List<String> parts = new List<String>();
            if (String.isNotBlank(h.FEC_First_Name__c)) {
                parts.add(h.FEC_First_Name__c.trim());
            }
            if (String.isNotBlank(h.FEC_Middle_Name__c)) {
                parts.add(h.FEC_Middle_Name__c.trim());
            }
            if (String.isNotBlank(h.FEC_Last_Name__c)) {
                parts.add(h.FEC_Last_Name__c.trim());
            }
            rawName = String.join(parts, ' ');
        }
        dto.defaultBeneficiaryUpperNoAccent = FEC_CommonUltils.toUpperNoVietnameseAccent(rawName);
        dto.beneficiaryName = String.isNotBlank(h.FEC_Beneficiary_Name__c) ? h.FEC_Beneficiary_Name__c : dto.defaultBeneficiaryUpperNoAccent;
        dto.beneficiaryAccount = h.FEC_Beneficiary_Account__c;
        dto.bankPicklistValue = h.FEC_Bank_Name__c;
        dto.bankBranch = h.FEC_Bank_Branch__c;
        dto.provinceCity = h.FEC_Province_City__c;
        return dto;
    }

    @AuraEnabled
    public static SaveRefundResultDTO saveRefundRequest(
        Id caseId,
        Decimal refundAmount,
        List<ReceiptLineDTO> receiptLines,
        String beneficiaryName,
        String beneficiaryAccount,
        String bankPicklistValue,
        String bankBranch,
        String provinceCity
    ) {
        SaveRefundResultDTO res = new SaveRefundResultDTO();
        res.success = false;
        if (caseId == null) {
            res.errorMessage = String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'Case Id' });
            return res;
        }
        if (!Schema.sObjectType.FEC_Case_Refund_Details__c.isDeletable()
            || !Schema.sObjectType.FEC_Case_Refund_Details__c.isCreateable()
            || !Schema.sObjectType.FEC_Customer_History__c.isUpdateable()
            || !Schema.sObjectType.Case.isUpdateable()) {
            res.errorMessage = System.Label.FEC_MSG_Insufficient_Access;
            return res;
        }
        if (refundAmount != null && refundAmount < 0) {
            res.errorMessage = System.Label.FEC_MSG_Refund_Request_Amount_Nonnegative;
            return res;
        }
        if (receiptLines == null || receiptLines.isEmpty()) {
            res.errorMessage = System.Label.FEC_MSG_Refund_Request_Receipt_Lines_Required;
            return res;
        }
        List<Case> caseRows = [
            SELECT Id,
                FEC_Account_or_Contract__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        caseRows = (List<Case>) Security.stripInaccessible(AccessType.READABLE, caseRows).getRecords();
        if (caseRows.isEmpty()) {
            res.errorMessage = String.format(System.Label.FEC_MSG_Not_Found, new List<String>{ 'Case' });
            return res;
        }
        Case c = caseRows[0];
        if (c.FEC_Account_or_Contract__c == null) {
            res.errorMessage = String.format(System.Label.FEC_MSG_Not_Found, new List<String>{ 'Customer History' });
            return res;
        }
        Date todayDt = Date.today();
        List<FEC_Case_Refund_Details__c> toInsert = new List<FEC_Case_Refund_Details__c>();
        for (ReceiptLineDTO line : receiptLines) {
            if (line == null) {
                continue;
            }
            if (String.isBlank(line.receiptDateIso) || line.receiptAmount == null || line.receiptAmount <= 0 || String.isBlank(line.transactionNo)
                || String.isBlank(line.paymentChannel)) {
                res.errorMessage = System.Label.FEC_MSG_Refund_Request_Receipt_Line_Incomplete;
                return res;
            }
            Date rd = FEC_CommonUltils.parseDate(line.receiptDateIso);
            if (rd == null) {
                res.errorMessage = String.format(System.Label.FEC_MSG_Param_Date_Format_Invalid, new List<String>{ 'Receipt date', String.isNotBlank(line.receiptDateIso) ? line.receiptDateIso : '' });
                return res;
            }
            if (rd > todayDt) {
                res.errorMessage = System.Label.FEC_MSG_Refund_Request_Receipt_Date_Future;
                return res;
            }
            FEC_Case_Refund_Details__c dtl = new FEC_Case_Refund_Details__c();
            dtl.FEC_Case__c = caseId;
            dtl.FEC_Receipt_Date__c = rd;
            dtl.FEC_Receipt_Amount__c = line.receiptAmount;
            dtl.FEC_Transaction_Number__c = line.transactionNo.trim();
            dtl.FEC_Payment_Channel__c = line.paymentChannel.trim();
            toInsert.add(dtl);
        }
        if (toInsert.isEmpty()) {
            res.errorMessage = System.Label.FEC_MSG_Refund_Request_Receipt_Lines_Required;
            return res;
        }
        if (String.isBlank(beneficiaryName)
            || String.isBlank(beneficiaryAccount)
            || String.isBlank(bankBranch)
            || String.isBlank(provinceCity)) {
            res.errorMessage = System.Label.FEC_MSG_Card_Block_Beneficiary_Required;
            return res;
        }
        if (String.isBlank(bankPicklistValue)) {
            res.errorMessage = String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ System.Label.FEC_LBL_Bank_Name });
            return res;
        }
        Savepoint sp = Database.setSavepoint();
        try {
            List<FEC_Case_Refund_Details__c> existing = [
                SELECT Id
                FROM FEC_Case_Refund_Details__c
                WHERE FEC_Case__c = :caseId
            ];
            existing = (List<FEC_Case_Refund_Details__c>) Security.stripInaccessible(AccessType.READABLE, existing).getRecords();
            if (!existing.isEmpty()) {
                if (!Schema.sObjectType.FEC_Case_Refund_Details__c.isDeletable()) {
                    res.errorMessage = System.Label.FEC_MSG_Insufficient_Access;
                    return res;
                }
                List<Id> delIds = new List<Id>();
                for (FEC_Case_Refund_Details__c e : existing) {
                    delIds.add(e.Id);
                }
                Database.delete(delIds, false);
            }
            FEC_Customer_History__c histUpd = new FEC_Customer_History__c(
                Id = c.FEC_Account_or_Contract__c,
                FEC_Beneficiary_Name__c = beneficiaryName.trim(),
                FEC_Beneficiary_Account__c = beneficiaryAccount.trim(),
                FEC_Bank_Name__c = bankPicklistValue.trim(),
                FEC_Bank_Branch__c = bankBranch.trim(),
                FEC_Province_City__c = provinceCity.trim()
            );
            Case caseUpd = new Case(Id = c.Id);
            caseUpd.put('FEC_Refund_Request_Amount__c', refundAmount);
            SObjectAccessDecision histDec = Security.stripInaccessible(AccessType.UPDATABLE, new List<SObject>{ histUpd });
            if (histDec.getRecords().isEmpty()) {
                Database.rollback(sp);
                res.errorMessage = System.Label.FEC_MSG_Insufficient_Access;
                return res;
            }
            update histDec.getRecords();
            SObjectAccessDecision caseDec = Security.stripInaccessible(AccessType.UPDATABLE, new List<SObject>{ caseUpd });
            if (caseDec.getRecords().isEmpty()) {
                Database.rollback(sp);
                res.errorMessage = System.Label.FEC_MSG_Insufficient_Access;
                return res;
            }
            update caseDec.getRecords();
            SObjectAccessDecision insDec = Security.stripInaccessible(AccessType.CREATABLE, toInsert);
            if (insDec.getRecords().isEmpty()) {
                Database.rollback(sp);
                res.errorMessage = System.Label.FEC_MSG_Insufficient_Access;
                return res;
            }
            insert insDec.getRecords();
            res.success = true;
        } catch (Exception e) {
            Database.rollback(sp);
            res.errorMessage = System.Label.FEC_Toast_Save_Error_Message;
        }
        return res;
    }

    private static List<PicklistOptionDTO> getPicklistOptions(String objectApiName, String fieldApiName) {
        List<PicklistOptionDTO> out = new List<PicklistOptionDTO>();
        Schema.SObjectType t = Schema.getGlobalDescribe().get(objectApiName);
        if (t == null || !t.getDescribe().isAccessible()) {
            return out;
        }
        Map<String, Schema.SObjectField> fields = t.getDescribe().fields.getMap();
        if (!fields.containsKey(fieldApiName)) {
            return out;
        }
        Schema.DescribeFieldResult d = fields.get(fieldApiName).getDescribe();
        if (!d.isAccessible()) {
            return out;
        }
        for (Schema.PicklistEntry pe : d.getPicklistValues()) {
            if (!pe.isActive()) {
                continue;
            }
            PicklistOptionDTO row = new PicklistOptionDTO();
            row.label = pe.getLabel();
            row.value = pe.getValue();
            out.add(row);
        }
        return out;
    }
}

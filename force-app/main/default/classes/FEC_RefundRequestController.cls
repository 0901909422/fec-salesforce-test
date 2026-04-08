public with sharing class FEC_RefundRequestController {

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

    @AuraEnabled
    public static SaveRefundResultDTO saveRefundRequest(
        Id caseId,
        Decimal refundAmount,
        List<ReceiptLineDTO> receiptLines
    ) {
        SaveRefundResultDTO res = new SaveRefundResultDTO();
        res.success = false;
        if (caseId == null) {
            res.errorMessage = String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'Case Id' });
            return res;
        }
        if (!Schema.sObjectType.FEC_Case_Refund_Details__c.isDeletable()
            || !Schema.sObjectType.FEC_Case_Refund_Details__c.isCreateable()
            || !Schema.sObjectType.Case.isUpdateable()) {
            res.errorMessage = System.Label.FEC_MSG_Insufficient_Access;
            return res;
        }
        if (refundAmount == null) {
            res.errorMessage = String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ System.Label.FEC_LBL_Refund_Amount });
            return res;
        }
        if (refundAmount <= 0) {
            res.errorMessage = System.Label.FEC_MSG_Refund_Request_Refund_Amount_Positive;
            return res;
        }
        if (receiptLines == null || receiptLines.isEmpty()) {
            res.errorMessage = System.Label.FEC_MSG_Refund_Request_Receipt_Lines_Required;
            return res;
        }
        List<Case> caseRows = [
            SELECT Id
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
            Case caseUpd = new Case(Id = c.Id);
            caseUpd.put('FEC_Refund_Request_Amount__c', refundAmount);
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
}

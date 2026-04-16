/****************************************************************************************
 * File Name    : FEC_RefundRequestController.cls
 * Description  : Refund Request LWC — draft JSON on Case; submit writes Case amount + FEC_Case_Refund_Details__c and clears draft.
 ****************************************************************************************/

public with sharing class FEC_RefundRequestController {

    public class ReceiptLineDTO {
        @AuraEnabled public String detailId { get; set; }
        @AuraEnabled public String receiptDateIso { get; set; }
        @AuraEnabled public Decimal receiptAmount { get; set; }
        @AuraEnabled public String transactionNo { get; set; }
        @AuraEnabled public String paymentChannel { get; set; }

        public ReceiptLineDTO() {
            this.detailId = null;
            this.receiptDateIso = null;
            this.receiptAmount = null;
            this.transactionNo = null;
            this.paymentChannel = null;
        }
    }

    public class RefundRequestDataDTO {
        @AuraEnabled public Decimal refundAmount { get; set; }
        @AuraEnabled public List<ReceiptLineDTO> receiptLines { get; set; }

        public RefundRequestDataDTO() {
            this.refundAmount = null;
            this.receiptLines = new List<ReceiptLineDTO>();
        }
    }

    @AuraEnabled
    public static RefundRequestDataDTO getRefundRequestData(Id caseId) {
        RefundRequestDataDTO dto = new RefundRequestDataDTO();
        dto.receiptLines = new List<ReceiptLineDTO>();
        if (caseId == null || !Schema.sObjectType.Case.isAccessible()) {
            return dto;
        }
        List<Case> caseRows = [
            SELECT FEC_Refund_Amount__c, FEC_Refund_Request_Draft__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        caseRows = (List<Case>) Security.stripInaccessible(AccessType.READABLE, caseRows).getRecords();
        if (caseRows.isEmpty()) {
            return dto;
        }
        Case c = caseRows[0];
        if (String.isNotBlank(c.FEC_Refund_Request_Draft__c)) {
            try {
                RefundRequestDataDTO fromDraft = (RefundRequestDataDTO) JSON.deserialize(c.FEC_Refund_Request_Draft__c, RefundRequestDataDTO.class);
                if (fromDraft != null) {
                    dto.refundAmount = fromDraft.refundAmount;
                    dto.receiptLines = normalizeReceiptLines(fromDraft.receiptLines);
                    return dto;
                }
            } catch (Exception ex) {
            }
        }
        dto.refundAmount = c.FEC_Refund_Amount__c;
        dto.receiptLines = loadReceiptLinesFromDetails(caseId);
        return dto;
    }

    @AuraEnabled
    public static void saveRefundRequestDraft(Id caseId, Decimal refundAmount, List<ReceiptLineDTO> receiptLines) {
        if (caseId == null) {
            throw new AuraHandledException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'Case Id' }));
        }
        if (!Schema.sObjectType.Case.isUpdateable()) {
            throw new AuraHandledException(System.Label.FEC_MSG_Insufficient_Access);
        }
        loadCaseOrThrow(caseId);
        RefundRequestDataDTO wrap = new RefundRequestDataDTO();
        wrap.refundAmount = refundAmount;
        wrap.receiptLines = receiptLines == null ? new List<ReceiptLineDTO>() : receiptLines;
        String json = JSON.serialize(wrap);
        Case u = new Case(Id = caseId, FEC_Refund_Request_Draft__c = json);
        SObjectAccessDecision dec = Security.stripInaccessible(AccessType.UPDATABLE, new List<SObject>{ u });
        if (dec.getRecords().isEmpty()) {
            throw new AuraHandledException(System.Label.FEC_MSG_Insufficient_Access);
        }
        Case toUpd = (Case) dec.getRecords()[0];
        if (String.isBlank(toUpd.FEC_Refund_Request_Draft__c)) {
            throw new AuraHandledException(System.Label.FEC_MSG_Insufficient_Access);
        }
        update new List<Case>{ toUpd };
    }

    @AuraEnabled
    public static void saveRefundRequest(Id caseId, Decimal refundAmount, List<ReceiptLineDTO> receiptLines) {
        if (caseId == null) {
            throw new AuraHandledException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'Case Id' }));
        }
        assertRefundSubmitWritable();
        assertSubmitRefundAmountAndLinesPresent(refundAmount, receiptLines);
        loadCaseOrThrow(caseId);
        assertSubmitRefundLinesValidated(receiptLines);
        persistRefundSubmit(caseId, refundAmount, receiptLines);
    }

    private static List<ReceiptLineDTO> normalizeReceiptLines(List<ReceiptLineDTO> inList) {
        List<ReceiptLineDTO> out = new List<ReceiptLineDTO>();
        if (inList == null) {
            return out;
        }
        for (ReceiptLineDTO x : inList) {
            if (x != null) {
                out.add(x);
            }
        }
        return out;
    }

    private static List<ReceiptLineDTO> loadReceiptLinesFromDetails(Id caseId) {
        List<ReceiptLineDTO> out = new List<ReceiptLineDTO>();
        if (!Schema.sObjectType.FEC_Case_Refund_Details__c.isAccessible()) {
            return out;
        }
        List<FEC_Case_Refund_Details__c> rows = [
            SELECT Id, FEC_Receipt_Date__c, FEC_Receipt_Amount__c, FEC_Transaction_Number__c, FEC_Payment_Channel__c
            FROM FEC_Case_Refund_Details__c
            WHERE FEC_Case__c = :caseId
            ORDER BY CreatedDate
        ];
        rows = (List<FEC_Case_Refund_Details__c>) Security.stripInaccessible(AccessType.READABLE, rows).getRecords();
        for (FEC_Case_Refund_Details__c r : rows) {
            ReceiptLineDTO row = new ReceiptLineDTO();
            row.detailId = String.valueOf(r.Id);
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

    private static void assertRefundSubmitWritable() {
        if (!Schema.sObjectType.Case.isUpdateable()) {
            throw new AuraHandledException(System.Label.FEC_MSG_Insufficient_Access);
        }
        if (!Schema.sObjectType.FEC_Case_Refund_Details__c.isDeletable()
            || !Schema.sObjectType.FEC_Case_Refund_Details__c.isCreateable()
            || !Schema.sObjectType.FEC_Case_Refund_Details__c.isUpdateable()) {
            throw new AuraHandledException(System.Label.FEC_MSG_Insufficient_Access);
        }
    }

    private static Case loadCaseOrThrow(Id caseId) {
        List<Case> caseRows = [
            SELECT Id
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        caseRows = (List<Case>) Security.stripInaccessible(AccessType.READABLE, caseRows).getRecords();
        if (caseRows.isEmpty()) {
            throw new AuraHandledException(String.format(System.Label.FEC_MSG_Not_Found, new List<String>{ 'Case' }));
        }
        return caseRows[0];
    }

    private static void assertSubmitRefundAmountAndLinesPresent(Decimal refundAmount, List<ReceiptLineDTO> receiptLines) {
        if (refundAmount == null) {
            throw new AuraHandledException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ System.Label.FEC_LBL_Refund_Amount }));
        }
        if (refundAmount <= 0) {
            throw new AuraHandledException(System.Label.FEC_MSG_Refund_Request_Refund_Amount_Positive);
        }
        if (receiptLines == null || receiptLines.isEmpty()) {
            throw new AuraHandledException(System.Label.FEC_MSG_Refund_Request_Receipt_Lines_Required);
        }
    }

    private static void assertSubmitRefundLinesValidated(List<ReceiptLineDTO> receiptLines) {
        Date todayDt = Date.today();
        Integer validLineCount = 0;
        for (ReceiptLineDTO line : receiptLines) {
            if (line == null) {
                continue;
            }
            Boolean lineBlank = String.isBlank(line.receiptDateIso) && (line.receiptAmount == null || line.receiptAmount <= 0)
                && String.isBlank(line.transactionNo) && String.isBlank(line.paymentChannel);
            if (lineBlank) {
                continue;
            }
            validLineCount++;
            if (String.isBlank(line.receiptDateIso) || line.receiptAmount == null || line.receiptAmount <= 0 || String.isBlank(line.transactionNo)
                || String.isBlank(line.paymentChannel)) {
                throw new AuraHandledException(System.Label.FEC_MSG_Refund_Request_Receipt_Line_Incomplete);
            }
            Date rd = FEC_CommonUltils.parseDate(line.receiptDateIso);
            if (rd == null) {
                throw new AuraHandledException(String.format(System.Label.FEC_MSG_Param_Date_Format_Invalid, new List<String>{ 'Receipt date', String.isNotBlank(line.receiptDateIso) ? line.receiptDateIso : '' }));
            }
            if (rd > todayDt) {
                throw new AuraHandledException(System.Label.FEC_MSG_Refund_Request_Receipt_Date_Future);
            }
        }
        if (validLineCount == 0) {
            throw new AuraHandledException(System.Label.FEC_MSG_Refund_Request_Receipt_Lines_Required);
        }
    }

    private static void persistRefundSubmit(Id caseId, Decimal refundAmount, List<ReceiptLineDTO> receiptLines) {
        Savepoint sp = Database.setSavepoint();
        try {
            Case caseUpd = new Case(Id = caseId);
            caseUpd.FEC_Refund_Amount__c = refundAmount;
            caseUpd.FEC_Refund_Request_Draft__c = null;
            SObjectAccessDecision caseDec = Security.stripInaccessible(AccessType.UPDATABLE, new List<SObject>{ caseUpd });
            if (caseDec.getRecords().isEmpty()) {
                Database.rollback(sp);
                throw new AuraHandledException(System.Label.FEC_MSG_Insufficient_Access);
            }
            update caseDec.getRecords();
            syncRefundReceiptDetailsMerge(caseId, receiptLines, sp);
        } catch (AuraHandledException e) {
            Database.rollback(sp);
            throw e;
        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException(System.Label.FEC_Toast_Save_Error_Message);
        }
    }

    private static Id parseDetailIdSafe(String detailIdStr) {
        if (String.isBlank(detailIdStr)) {
            return null;
        }
        try {
            return Id.valueOf(detailIdStr.trim());
        } catch (Exception ex) {
            return null;
        }
    }

    private static void applyReceiptLineDtoToDetail(FEC_Case_Refund_Details__c dtl, Id caseId, ReceiptLineDTO line, Boolean setParent) {
        if (setParent) {
            dtl.FEC_Case__c = caseId;
        }
        if (String.isNotBlank(line.receiptDateIso)) {
            Date rd = FEC_CommonUltils.parseDate(line.receiptDateIso);
            dtl.FEC_Receipt_Date__c = rd;
        } else {
            dtl.FEC_Receipt_Date__c = null;
        }
        if (line.receiptAmount != null) {
            dtl.FEC_Receipt_Amount__c = line.receiptAmount;
        } else {
            dtl.FEC_Receipt_Amount__c = null;
        }
        if (String.isNotBlank(line.transactionNo)) {
            dtl.FEC_Transaction_Number__c = line.transactionNo.trim();
        } else {
            dtl.FEC_Transaction_Number__c = null;
        }
        if (String.isNotBlank(line.paymentChannel)) {
            dtl.FEC_Payment_Channel__c = line.paymentChannel.trim();
        } else {
            dtl.FEC_Payment_Channel__c = null;
        }
    }

    private static void syncRefundReceiptDetailsMerge(Id caseId, List<ReceiptLineDTO> receiptLines, Savepoint sp) {
        if (receiptLines == null || receiptLines.isEmpty()) {
            List<FEC_Case_Refund_Details__c> wipe = [
                SELECT Id
                FROM FEC_Case_Refund_Details__c
                WHERE FEC_Case__c = :caseId
            ];
            wipe = (List<FEC_Case_Refund_Details__c>) Security.stripInaccessible(AccessType.READABLE, wipe).getRecords();
            if (!wipe.isEmpty()) {
                if (!Schema.sObjectType.FEC_Case_Refund_Details__c.isDeletable()) {
                    Database.rollback(sp);
                    throw new AuraHandledException(System.Label.FEC_MSG_Insufficient_Access);
                }
                Database.delete(wipe, false);
            }
            return;
        }
        List<FEC_Case_Refund_Details__c> existingAll = [
            SELECT Id, FEC_Case__c, FEC_Receipt_Date__c, FEC_Receipt_Amount__c, FEC_Transaction_Number__c, FEC_Payment_Channel__c
            FROM FEC_Case_Refund_Details__c
            WHERE FEC_Case__c = :caseId
        ];
        existingAll = (List<FEC_Case_Refund_Details__c>) Security.stripInaccessible(AccessType.READABLE, existingAll).getRecords();
        Map<Id, FEC_Case_Refund_Details__c> existingById = new Map<Id, FEC_Case_Refund_Details__c>(existingAll);
        Map<Id, FEC_Case_Refund_Details__c> updateById = new Map<Id, FEC_Case_Refund_Details__c>();
        List<FEC_Case_Refund_Details__c> toInsert = new List<FEC_Case_Refund_Details__c>();
        for (ReceiptLineDTO line : receiptLines) {
            if (line == null) {
                continue;
            }
            Id detailId = parseDetailIdSafe(line.detailId);
            if (detailId != null && existingById.containsKey(detailId)) {
                FEC_Case_Refund_Details__c upd = new FEC_Case_Refund_Details__c(Id = detailId);
                applyReceiptLineDtoToDetail(upd, caseId, line, false);
                updateById.put(detailId, upd);
            } else {
                FEC_Case_Refund_Details__c ins = new FEC_Case_Refund_Details__c();
                applyReceiptLineDtoToDetail(ins, caseId, line, true);
                toInsert.add(ins);
            }
        }
        Set<Id> matchedExistingIds = new Set<Id>(updateById.keySet());
        List<Id> delIds = new List<Id>();
        for (FEC_Case_Refund_Details__c e : existingAll) {
            if (!matchedExistingIds.contains(e.Id)) {
                delIds.add(e.Id);
            }
        }
        if (!delIds.isEmpty()) {
            if (!Schema.sObjectType.FEC_Case_Refund_Details__c.isDeletable()) {
                Database.rollback(sp);
                throw new AuraHandledException(System.Label.FEC_MSG_Insufficient_Access);
            }
            Database.delete(delIds, false);
        }
        if (!updateById.isEmpty()) {
            SObjectAccessDecision updDec = Security.stripInaccessible(AccessType.UPDATABLE, updateById.values());
            if (updDec.getRecords().isEmpty()) {
                Database.rollback(sp);
                throw new AuraHandledException(System.Label.FEC_MSG_Insufficient_Access);
            }
            update updDec.getRecords();
        }
        if (!toInsert.isEmpty()) {
            SObjectAccessDecision insDec = Security.stripInaccessible(AccessType.CREATABLE, toInsert);
            if (insDec.getRecords().isEmpty()) {
                Database.rollback(sp);
                throw new AuraHandledException(System.Label.FEC_MSG_Insufficient_Access);
            }
            insert insDec.getRecords();
        }
    }
}

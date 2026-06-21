/**
 * Post-success hook for CMS card operations — syncs non-monetary updates to VMX.
 */
public without sharing class FEC_CmsVmxIntegrationService {

    public static final String OP_BLOCK_CARD = 'BLOCK_CARD';
    public static final String OP_UNBLOCK_CARD = 'UNBLOCK_CARD';
    public static final String OP_PIN_RESET = 'PIN_RESET';
    public static final String OP_PIN_REPLACEMENT = 'PIN_REPLACEMENT';
    public static final String OP_CARD_REPLACEMENT = 'CARD_REPLACEMENT';

    private static final String MEMO_1_DATETIME_FORMAT = 'dd/MM/yyyy HH:mm';
    private static final String MEMO_1_ACTION_BLOCK_CARD = 'Action Block Card-';
    private static final String MEMO_1_ACTION_UNBLOCK_CARD = 'Action Unblock Card-';
    private static final String MEMO_1_ACTION_RESET_PIN = 'Action Reset PIN-';
    private static final String MEMO_1_ACTION_REISSUE_PIN = 'Action Reissue PIN-';
    private static final String MEMO_1_ACTION_REPLACE_CARD = 'Action Replace Card-';
    private static final String MEMO_2_PIN = 'Old Block Code =(null)  New Block Code = (null)';

    /**
     * Invoked after LockUnlock, PIN Reissue, or Replace Card APIs return business success.
     * Dùng deferred logging để tránh lỗi "uncommitted work pending" khi có nhiều callout
     * (fetchCurrentBlockCode + executeNonmonUpdate) trong cùng transaction.
     */
    public static FEC_VmxNonmonUpdCallout.NonmonUpdResult onCmsOperationSuccess(Id caseId, String operationType) {
        return onCmsOperationSuccess(caseId, operationType, null);
    }

    /**
     * Overload nhận newBlockCode từ caller để tránh phụ thuộc vào DB (field chưa chắc đã được save).
     * Dùng cho Block Card / Unblock Card khi blockCode được pass trực tiếp từ LWC params.
     */
    public static FEC_VmxNonmonUpdCallout.NonmonUpdResult onCmsOperationSuccess(Id caseId, String operationType, String newBlockCode) {
        return onCmsOperationSuccess(caseId, operationType, newBlockCode, null);
    }

    /**
     * Overload đầy đủ nhận cả newBlockCode và oldBlockCode từ caller.
     * oldBlockCode: block code trước khi thao tác (dùng cho Unblock Card — sau khi unblock thì inquiry không còn BLK_CD).
     * newBlockCode: block code sau khi thao tác (dùng cho Block Card — giá trị user chọn).
     */
    public static FEC_VmxNonmonUpdCallout.NonmonUpdResult onCmsOperationSuccess(Id caseId, String operationType, String newBlockCode, String oldBlockCode) {
        if (caseId == null || String.isBlank(operationType)) {
            return null;
        }

        FEC_CommonUltils.beginDeferredApiLogging();
        try {
            FEC_VmxNonmonUpdCallout.NonmonUpdInput input = buildNonmonUpdInput(caseId, operationType, newBlockCode, oldBlockCode);
            return FEC_VmxNonmonUpdCallout.executeNonmonUpdate(input);
        } catch (Exception ex) {
            FEC_CommonUltils.logException(
                'FEC_CmsVmxIntegrationService',
                'onCmsOperationSuccess',
                ex.getMessage(),
                ex.getStackTraceString()
            );
            return null;
        } finally {
            FEC_VmxNonmonUpdCallout.logApiResponse();
            FEC_CommonUltils.flushDeferredApiLogs();
        }
    }

    @TestVisible
    private static FEC_VmxNonmonUpdCallout.NonmonUpdInput buildNonmonUpdInput(Id caseId, String operationType) {
        return buildNonmonUpdInput(caseId, operationType, null, null);
    }

    @TestVisible
    private static FEC_VmxNonmonUpdCallout.NonmonUpdInput buildNonmonUpdInput(Id caseId, String operationType, String newBlockCode) {
        return buildNonmonUpdInput(caseId, operationType, newBlockCode, null);
    }

    @TestVisible
    private static FEC_VmxNonmonUpdCallout.NonmonUpdInput buildNonmonUpdInput(Id caseId, String operationType, String newBlockCode, String oldBlockCode) {
        Case caseRecord = loadCase(caseId);

        // Nếu oldBlockCode không được truyền vào thì fallback gọi inquiry API.
        // Với Block/Unblock Card, oldBlockCode luôn được truyền từ LWC nên không cần gọi API.
        String resolvedOldBlockCode = oldBlockCode;
        if (resolvedOldBlockCode == null && requiresCurrentBlockCodeLookup(operationType)) {
            resolvedOldBlockCode = fetchCurrentBlockCode(caseRecord);
        }

        // Ưu tiên newBlockCode được truyền vào từ caller (giá trị thực tế từ LWC/params),
        // fallback về field trên Case nếu không có.
        String resolvedNewBlockCode = String.isNotBlank(newBlockCode)
            ? newBlockCode
            : caseRecord.FEC_New_Block_Code__c;

        FEC_VmxNonmonUpdCallout.NonmonUpdInput input = FEC_VmxNonmonUpdCallout.buildDefaultInput();
        input.account = caseRecord.FEC_Account_Number__c;
        input.memo1 = buildMemo1(caseRecord.FEC_ID_Search__c, operationType);
        input.memo2 = buildMemo2(operationType, resolvedNewBlockCode, resolvedOldBlockCode);
        // TODO: map actionCode from operationType
        return input;
    }

    @TestVisible
    private static String buildMemo1(String idSearch, String operationType) {
        String nowFormatted = Datetime.now().format(MEMO_1_DATETIME_FORMAT);
        String idSearchValue = String.isNotBlank(idSearch) ? idSearch.trim() : '';
        return nowFormatted + '-' + resolveMemo1ActionLabel(operationType) + idSearchValue;
    }

    @TestVisible
    private static String buildMemo2(String operationType, String newBlockCode, String currentBlockCode) {
        if (OP_PIN_RESET.equals(operationType) || OP_PIN_REPLACEMENT.equals(operationType)) {
            return MEMO_2_PIN;
        }

        String oldBlk = normalizeMemoValue(currentBlockCode);
        if (OP_CARD_REPLACEMENT.equals(operationType)) {
            return 'Old Block Code =' + oldBlk + ' New Block Code =(null)';
        }

        String newBlk = normalizeMemoValue(newBlockCode);
        return 'Old Block Code = ' + oldBlk + ' New Block Code =' + newBlk;
    }

    @TestVisible
    private static Boolean requiresCurrentBlockCodeLookup(String operationType) {
        return OP_BLOCK_CARD.equals(operationType)
            || OP_UNBLOCK_CARD.equals(operationType)
            || OP_CARD_REPLACEMENT.equals(operationType);
    }

    @TestVisible
    private static String fetchCurrentBlockCode(Case caseRecord) {
        if (caseRecord == null || String.isBlank(caseRecord.FEC_Account_Number__c)) {
            return null;
        }

        try {
            FEC_MCMSCARDTOCARDINQEMEA.ResponseWrapper response = FEC_MCMSCARDTOCARDINQEMEA.callService(
                FEC_CommonUltils.generateTransactionUUID(),
                FEC_ConstantCommon.REQUESTOR_CRM,
                Datetime.now().format(FEC_ConstantCommon.DATETIME_FORMAT),
                FEC_ConstantCommon.REQUESTOR_VMXVERSION_EMEA_CARD,
                FEC_ConstantCommon.REQUESTOR_VMX_CONTEXT,
                FEC_ConstantCommon.REQUESTOR_VMX_CONTEXT,
                FEC_ConstantCommon.REQUESTOR_ORG_EMEA_CARD,
                caseRecord.FEC_Account_Number__c,
                caseRecord.FEC_Customer_Name__c
            );
            return extractCurrentBlockCode(response, resolveCardLast4(caseRecord));
        } catch (Exception ex) {
            FEC_CommonUltils.logException(
                'FEC_CmsVmxIntegrationService',
                'fetchCurrentBlockCode',
                ex.getMessage(),
                ex.getStackTraceString()
            );
            return null;
        } finally {
            FEC_MCMSCARDTOCARDINQEMEA.logApiResponse();
        }
    }

    @TestVisible
    private static String extractCurrentBlockCode(
        FEC_MCMSCARDTOCARDINQEMEA.ResponseWrapper response,
        String cardLast4
    ) {
        if (response?.VMXMsgOut?.OUTPUT_AREA?.OUTPUT_DATA == null
            || response.VMXMsgOut.OUTPUT_AREA.OUTPUT_DATA.isEmpty()) {
            return null;
        }

        for (FEC_MCMSCARDTOCARDINQEMEA.OutputData outputData : response.VMXMsgOut.OUTPUT_AREA.OUTPUT_DATA) {
            if (String.isBlank(outputData.CARD_NBR)) {
                continue;
            }

            String cardNbr = outputData.CARD_NBR.trim();
            String cardNbrLast4 = cardNbr.length() >= 4 ? cardNbr.right(4) : cardNbr;
            if (String.isNotBlank(cardLast4) && cardNbrLast4 != cardLast4) {
                continue;
            }

            return String.isNotBlank(outputData.BLK_CD) ? outputData.BLK_CD.trim() : null;
        }
        return null;
    }

    @TestVisible
    private static String resolveMemo1ActionLabel(String operationType) {
        if (OP_BLOCK_CARD.equals(operationType)) {
            return MEMO_1_ACTION_BLOCK_CARD;
        }
        if (OP_UNBLOCK_CARD.equals(operationType)) {
            return MEMO_1_ACTION_UNBLOCK_CARD;
        }
        if (OP_PIN_RESET.equals(operationType)) {
            return MEMO_1_ACTION_RESET_PIN;
        }
        if (OP_PIN_REPLACEMENT.equals(operationType)) {
            return MEMO_1_ACTION_REISSUE_PIN;
        }
        if (OP_CARD_REPLACEMENT.equals(operationType)) {
            return MEMO_1_ACTION_REPLACE_CARD;
        }
        throw new CalloutException(
            String.format(System.Label.FEC_MSG_Invalid, new List<String>{ 'Operation Type' })
        );
    }

    private static String normalizeMemoValue(String value) {
        return String.isNotBlank(value) ? value.trim() : '';
    }

    private static String resolveCardLast4(Case caseRecord) {
        String rawCard = caseRecord.FEC_Account_or_Contract__r?.FEC_Card_Number__c;
        if (String.isBlank(rawCard)) {
            return null;
        }
        String digits = rawCard.trim();
        return digits.length() >= 4 ? digits.right(4) : digits;
    }

    private static Case loadCase(Id caseId) {
        List<Case> caseRows = [
            SELECT FEC_Account_Number__c,
                FEC_New_Block_Code__c,
                FEC_ID_Search__c,
                FEC_Customer_Name__c,
                FEC_Account_or_Contract__r.FEC_Card_Number__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        if (caseRows.isEmpty()) {
            throw new CalloutException(
                String.format(System.Label.FEC_MSG_Not_Found, new List<String>{ 'Case' })
            );
        }
        return caseRows[0];
    }
}

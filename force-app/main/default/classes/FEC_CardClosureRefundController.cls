public with sharing class FEC_CardClosureRefundController {

    private static final String BLOCK_CODE_CARD = 'C';
    private static final String FUNC_BLOCK = 'B';
    private static final String FUNC_UNBLOCK = 'U';
    private static final String SUB_CODE_RC16_01 = 'RC16.01';
    private static final Integer MAX_BLOCK_SERVICE_ATTEMPTS = 3;
    private static final String LOS_RESOLVED_COMPLETED = 'Resolved-Completed';
    private static final String LOS_RESOLVED_CANCELLED = 'Resolved-Cancelled';
    private static final String DISB_ESB_ORIG = 'ORIG';
    private static final String DISB_ESB_SENT = 'SENT';
    private static final String DISB_ESB_LOCK = 'LOCK';
    private static final String DISB_ESB_CONFIRMED = 'CONFIRMED';
    private static final String DISB_ESB_CANCELLED = 'CANCELLED';
    private static final String DISB_ESB_CANCELLED_AUTO = 'CANCELLED_AUTO';
    private static final String CS_DECISION_NOTI_17 = 'Không có khoản chờ giải ngân';
    private static final String CS_DECISION_NOTI_18 = 'Có khoản chờ giải ngân. Cần tư vấn khách hàng giữ thẻ';

    public class LockUnlockResultDTO {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String code;
        @AuraEnabled public String description;
        @AuraEnabled public String transId;
        @AuraEnabled public String errorMessage;
        @AuraEnabled public Integer cardBlockServiceAttemptsAfter;
        @AuraEnabled public Boolean hideBlockCardAfterAction;
    }

    public class CardLockUiContextDTO {
        @AuraEnabled public Boolean hideBlockCardBySubCode;
        @AuraEnabled public Boolean showBlockCardButton;
        @AuraEnabled public Boolean attemptsExhausted;
        @AuraEnabled public Integer cardBlockServiceAttempts;
        @AuraEnabled public String pendingApplicationId;
        @AuraEnabled public String pendingApplicationStatus;
        @AuraEnabled public Decimal pendingDisbursedAmount;
        @AuraEnabled public Date pendingDisbursementApprovalDate;
        @AuraEnabled public String pendingDisbursementStatus;
        @AuraEnabled public String pendingCsDecision;
        @AuraEnabled public Boolean cardBlocked;
    }

    @AuraEnabled
    public static CardLockUiContextDTO getCardLockUnlockUiContext(Id caseId) {
        CardLockUiContextDTO dto = new CardLockUiContextDTO();
        dto.hideBlockCardBySubCode = false;
        dto.showBlockCardButton = false;
        dto.attemptsExhausted = false;
        dto.cardBlockServiceAttempts = 0;
        dto.cardBlocked = false;
        if (caseId == null || !Schema.sObjectType.Case.isAccessible() || !Schema.sObjectType.FEC_Customer_History__c.isAccessible()) {
            return dto;
        }
        List<Case> caseRows = [
            SELECT Id,
                FEC_SubCode__r.FEC_Code__c,
                FEC_Card_Block_Service_Attempts__c,
                FEC_Account_or_Contract__c,
                FEC_Account_Number__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        caseRows = (List<Case>) Security.stripInaccessible(AccessType.READABLE, caseRows).getRecords();
        if (caseRows.isEmpty()) {
            return dto;
        }
        Case c = caseRows[0];
        String subCode = c.FEC_SubCode__r != null ? c.FEC_SubCode__r.FEC_Code__c : null;
        dto.hideBlockCardBySubCode = SUB_CODE_RC16_01.equals(subCode);
        Decimal att = c.FEC_Card_Block_Service_Attempts__c;
        Integer attInt = att == null ? 0 : att.intValue();
        dto.cardBlockServiceAttempts = attInt;
        dto.attemptsExhausted = attInt >= MAX_BLOCK_SERVICE_ATTEMPTS;
        String cardBlock = null;
        String accountNumberForDisb = c.FEC_Account_Number__c;
        if (c.FEC_Account_or_Contract__c != null) {
            List<FEC_Customer_History__c> histories = [
                SELECT Id, FEC_Block_Code__c, FEC_Account_Number__c
                FROM FEC_Customer_History__c
                WHERE Id = :c.FEC_Account_or_Contract__c
                LIMIT 1
            ];
            histories = (List<FEC_Customer_History__c>) Security.stripInaccessible(AccessType.READABLE, histories).getRecords();
            if (!histories.isEmpty()) {
                FEC_Customer_History__c h = histories[0];
                cardBlock = h.FEC_Block_Code__c;
                if (String.isBlank(accountNumberForDisb)) {
                    accountNumberForDisb = h.FEC_Account_Number__c;
                }
            }
        }
        Boolean cardAlreadyC = BLOCK_CODE_CARD.equals(cardBlock);
        dto.cardBlocked = cardAlreadyC;
        dto.showBlockCardButton = !dto.hideBlockCardBySubCode && !dto.attemptsExhausted && !cardAlreadyC;
        Boolean pendingFromApi = false;
        if (!String.isBlank(accountNumberForDisb)) {
            try {
                FEC_GetDisbInfoByAcctCallout.GetDisbInfoByAcctExecutionResult disbExec =
                    FEC_GetDisbInfoByAcctCallout.getDisbInfoByAcctExecutionResult(accountNumberForDisb, null);
                FEC_GetDisbInfoByAcctCallout.logApiResponse();
                FEC_GetDisbInfoByAcctCallout.ResultWrapper rw =
                    FEC_GetDisbInfoByAcctCallout.convertToResultWrapper(disbExec.response);
                if (rw.isSuccess
                    && rw.applications != null
                    && !rw.applications.isEmpty()) {
                    FEC_GetDisbInfoByAcctCallout.ApplicationDetailWrapper w = rw.applications[0];
                    dto.pendingApplicationId = w.applicationId;
                    dto.pendingApplicationStatus = w.appStatusLos;
                    if (String.isNotBlank(w.disbAmount)) {
                        String amtStr = w.disbAmount.trim().replace(',', '');
                        try {
                            dto.pendingDisbursedAmount = Decimal.valueOf(amtStr);
                        } catch (Exception parseAmt) {
                            dto.pendingDisbursedAmount = null;
                        }
                    }
                    if (String.isNotBlank(w.requestedDt)) {
                        String dtPart = w.requestedDt.trim();
                        Integer spIdx = dtPart.indexOf(' ');
                        if (spIdx > 0) {
                            dtPart = dtPart.substring(0, spIdx);
                        }
                        List<String> ymd = dtPart.split('/');
                        if (ymd.size() == 3) {
                            try {
                                dto.pendingDisbursementApprovalDate = Date.newInstance(
                                    Integer.valueOf(ymd[0]),
                                    Integer.valueOf(ymd[1]),
                                    Integer.valueOf(ymd[2])
                                );
                            } catch (Exception parseDt) {
                                dto.pendingDisbursementApprovalDate = null;
                            }
                        }
                    }
                    dto.pendingDisbursementStatus = w.disbStatus;
                    dto.pendingCsDecision = resolvePendingDisbursementCsDecision(w.disbStatus, w.appStatusLos);
                    pendingFromApi = true;
                }
            } catch (Exception e) {
                pendingFromApi = false;
            }
        }
        if (!pendingFromApi && Schema.sObjectType.FEC_Pending_Disbursement__c.isAccessible()) {
            Map<String, Schema.SObjectField> pdFieldMap = Schema.SObjectType.FEC_Pending_Disbursement__c.fields.getMap();
            String caseLookupField = null;
            if (pdFieldMap.containsKey('FEC_Case__c')) {
                caseLookupField = 'FEC_Case__c';
            }
            if (!String.isBlank(caseLookupField)) {
                List<FEC_Pending_Disbursement__c> pendingRows = (List<FEC_Pending_Disbursement__c>) Database.query(
                    'SELECT FEC_PD_Application_ID__c,' +
                    ' FEC_PD_Application_Status__c,' +
                    ' FEC_PD_Disbursed_Amount__c,' +
                    ' FEC_PD_Disbursement_Approval_Date__c,' +
                    ' FEC_PD_Disbursement_Status__c' +
                    ' FROM FEC_Pending_Disbursement__c' +
                    ' WHERE ' + caseLookupField + ' = :caseId' +
                    ' LIMIT 1'
                );
                pendingRows = (List<FEC_Pending_Disbursement__c>) Security.stripInaccessible(AccessType.READABLE, pendingRows).getRecords();
                if (!pendingRows.isEmpty()) {
                    FEC_Pending_Disbursement__c p = pendingRows[0];
                    dto.pendingApplicationId = p.FEC_PD_Application_ID__c;
                    dto.pendingApplicationStatus = p.FEC_PD_Application_Status__c;
                    dto.pendingDisbursedAmount = p.FEC_PD_Disbursed_Amount__c;
                    dto.pendingDisbursementApprovalDate = p.FEC_PD_Disbursement_Approval_Date__c;
                    dto.pendingDisbursementStatus = p.FEC_PD_Disbursement_Status__c;
                    dto.pendingCsDecision = resolvePendingDisbursementCsDecision(
                        p.FEC_PD_Disbursement_Status__c,
                        p.FEC_PD_Application_Status__c
                    );
                }
            }
        }
        return dto;
    }

    private static String resolvePendingDisbursementCsDecision(String disbStatusEsb, String appStatusLos) {
        if (String.isBlank(disbStatusEsb)) {
            return null;
        }
        String esb = disbStatusEsb.trim().toUpperCase();
        if (esb == DISB_ESB_ORIG || esb == DISB_ESB_SENT || esb == DISB_ESB_LOCK) {
            return CS_DECISION_NOTI_17;
        }
        if (esb == DISB_ESB_CONFIRMED) {
            return losMatchesResolvedCompleted(appStatusLos) ? CS_DECISION_NOTI_18 : CS_DECISION_NOTI_17;
        }
        if (esb == DISB_ESB_CANCELLED || esb == DISB_ESB_CANCELLED_AUTO) {
            return losMatchesResolvedCancelled(appStatusLos) ? CS_DECISION_NOTI_18 : CS_DECISION_NOTI_17;
        }
        return null;
    }

    private static Boolean losMatchesResolvedCompleted(String appStatusLos) {
        return String.isNotBlank(appStatusLos) && LOS_RESOLVED_COMPLETED.equalsIgnoreCase(appStatusLos.trim());
    }

    private static Boolean losMatchesResolvedCancelled(String appStatusLos) {
        return String.isNotBlank(appStatusLos) && LOS_RESOLVED_CANCELLED.equalsIgnoreCase(appStatusLos.trim());
    }

    @AuraEnabled
    public static LockUnlockResultDTO blockCard(Id caseId) {
        return executeLockUnlock(caseId, FUNC_BLOCK);
    }

    @AuraEnabled
    public static LockUnlockResultDTO unblockCard(Id caseId) {
        return executeLockUnlock(caseId, FUNC_UNBLOCK);
    }

    private static LockUnlockResultDTO executeLockUnlock(Id caseId, String funcCode) {
        LockUnlockResultDTO dto = new LockUnlockResultDTO();
        dto.success = false;
        dto.code = null;
        dto.description = null;
        dto.transId = null;
        dto.errorMessage = null;
        dto.cardBlockServiceAttemptsAfter = null;
        dto.hideBlockCardAfterAction = false;

        if (caseId == null) {
            dto.errorMessage = String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'Case Id' });
            return dto;
        }

        if (String.isBlank(funcCode) || (funcCode != FUNC_BLOCK && funcCode != FUNC_UNBLOCK)) {
            dto.errorMessage = String.format(System.Label.FEC_MSG_Invalid, new List<String>{ 'Func' });
            return dto;
        }

        if (!Schema.sObjectType.Case.isAccessible()) {
            dto.errorMessage = System.Label.FEC_MSG_Card_LockUnlock_Case_Access_Denied;
            return dto;
        }
        if (!Schema.sObjectType.FEC_Customer_History__c.isAccessible()) {
            dto.errorMessage = System.Label.FEC_MSG_Card_LockUnlock_Customer_History_Access_Denied;
            return dto;
        }

        List<Case> caseRows = [
            SELECT Id,
                FEC_Account_Number__c,
                FEC_Account_or_Contract__c,
                FEC_SubCode__r.FEC_Code__c,
                FEC_Card_Block_Service_Attempts__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        caseRows = (List<Case>) Security.stripInaccessible(AccessType.READABLE, caseRows).getRecords();
        if (caseRows.isEmpty()) {
            dto.errorMessage = String.format(System.Label.FEC_MSG_Not_Found, new List<String>{ 'Case' });
            return dto;
        }

        Case c = caseRows[0];
        String subCode = c.FEC_SubCode__r != null ? c.FEC_SubCode__r.FEC_Code__c : null;
        if (funcCode == FUNC_BLOCK && SUB_CODE_RC16_01.equals(subCode)) {
            dto.errorMessage = String.format(System.Label.FEC_MSG_Invalid, new List<String>{ 'Sub Code for Block Card' });
            return dto;
        }

        if (c.FEC_Account_or_Contract__c == null) {
            dto.errorMessage = String.format(System.Label.FEC_MSG_Not_Found, new List<String>{ 'Customer History' });
            return dto;
        }

        List<FEC_Customer_History__c> historyRows = [
            SELECT Id, FEC_Account_Number__c, FEC_Card_Number__c, FEC_Block_Code__c, FEC_Block_Code_1__c
            FROM FEC_Customer_History__c
            WHERE Id = :c.FEC_Account_or_Contract__c
            LIMIT 1
        ];
        historyRows = (List<FEC_Customer_History__c>) Security.stripInaccessible(AccessType.READABLE, historyRows).getRecords();
        if (historyRows.isEmpty()) {
            dto.errorMessage = String.format(System.Label.FEC_MSG_Not_Found, new List<String>{ 'Customer History' });
            return dto;
        }

        FEC_Customer_History__c customerHistory = historyRows[0];
        String accountNumber = String.isNotBlank(customerHistory.FEC_Account_Number__c) ? customerHistory.FEC_Account_Number__c : c.FEC_Account_Number__c;
        if (String.isBlank(accountNumber)) {
            dto.errorMessage = String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'Account Number' });
            return dto;
        }

        String last4Digit = getLast4Digit(customerHistory.FEC_Card_Number__c);
        if (String.isBlank(last4Digit)) {
            dto.errorMessage = String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'Card Number' });
            return dto;
        }

        Boolean cardOnlyLock = false;
        if (funcCode == FUNC_BLOCK) {
            cardOnlyLock = isCardOnlyLockByAccountBlockCode1(customerHistory.FEC_Block_Code_1__c);
        }

        String transId = UUID.randomUUID().toString();
        FEC_CardLockUnLockCallout.ValidationResult validation = FEC_CardLockUnLockCallout.validateRequest(
            transId,
            FEC_ConstantCommon.REQUESTOR_CRM,
            BLOCK_CODE_CARD,
            funcCode,
            last4Digit,
            accountNumber
        );
        if (validation == null || !validation.isValid) {
            dto.errorMessage = validation != null ? validation.errorMessage : System.Label.FEC_MSG_Card_LockUnlock_Validation_Failed;
            return dto;
        }

        try {
            FEC_CardLockUnLockCallout.LockUnlockResponse response = FEC_CardLockUnLockCallout.callLockUnlockCard(
                transId,
                FEC_ConstantCommon.REQUESTOR_CRM,
                BLOCK_CODE_CARD,
                funcCode,
                last4Digit,
                accountNumber
            );
            FEC_CardLockUnLockCallout.logApiResponse();

            dto.transId = transId;
            dto.success = FEC_CardLockUnLockCallout.isSuccess(response);
            dto.code = response != null && response.Sys2 != null ? response.Sys2.Code : null;
            dto.description = response != null && response.Sys2 != null ? response.Sys2.Description : null;
            dto.errorMessage = response != null ? response.errorMessage : null;

            if (dto.success && funcCode == FUNC_BLOCK) {
                updateCustomerHistoryAfterBlock(customerHistory.Id, cardOnlyLock);
                resetCaseBlockServiceAttempts(caseId);
                dto.cardBlockServiceAttemptsAfter = 0;
                dto.hideBlockCardAfterAction = true;
            } else if (!dto.success && funcCode == FUNC_BLOCK) {
                Integer after = incrementCaseBlockServiceAttempts(caseId);
                dto.cardBlockServiceAttemptsAfter = after;
                dto.hideBlockCardAfterAction = after >= MAX_BLOCK_SERVICE_ATTEMPTS;
            }
        } catch (Exception ex) {
            dto.success = false;
            dto.errorMessage = funcCode == FUNC_UNBLOCK
                ? System.Label.FEC_MSG_Card_Unlock_Failed
                : System.Label.FEC_MSG_Card_Block_Failed;
            if (funcCode == FUNC_BLOCK) {
                Integer after = incrementCaseBlockServiceAttempts(caseId);
                dto.cardBlockServiceAttemptsAfter = after;
                dto.hideBlockCardAfterAction = after >= MAX_BLOCK_SERVICE_ATTEMPTS;
            }
        }

        return dto;
    }

    private static Boolean isCardOnlyLockByAccountBlockCode1(String blockCode1) {
        if (String.isBlank(blockCode1)) {
            return false;
        }
        String v = blockCode1.trim().toUpperCase();
        return v == 'F' || v == 'N';
    }

    private static Integer incrementCaseBlockServiceAttempts(Id caseId) {
        if (caseId == null || !Schema.sObjectType.Case.isUpdateable()) {
            return null;
        }
        List<Case> rows = [
            SELECT Id, FEC_Card_Block_Service_Attempts__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
            FOR UPDATE
        ];
        rows = (List<Case>) Security.stripInaccessible(AccessType.READABLE, rows).getRecords();
        if (rows.isEmpty()) {
            return null;
        }
        Decimal d = rows[0].FEC_Card_Block_Service_Attempts__c;
        Integer n = d == null ? 0 : d.intValue();
        if (n < MAX_BLOCK_SERVICE_ATTEMPTS) {
            n = n + 1;
        }
        Case upd = new Case(Id = caseId, FEC_Card_Block_Service_Attempts__c = n);
        List<Case> toUp = (List<Case>) Security.stripInaccessible(AccessType.UPDATABLE, new List<Case>{ upd }).getRecords();
        if (!toUp.isEmpty()) {
            update toUp;
        }
        return n;
    }

    private static void resetCaseBlockServiceAttempts(Id caseId) {
        if (caseId == null || !Schema.sObjectType.Case.isUpdateable()) {
            return;
        }
        Case upd = new Case(Id = caseId, FEC_Card_Block_Service_Attempts__c = 0);
        List<Case> toUp = (List<Case>) Security.stripInaccessible(AccessType.UPDATABLE, new List<Case>{ upd }).getRecords();
        if (!toUp.isEmpty()) {
            update toUp;
        }
    }

    private static void updateCustomerHistoryAfterBlock(Id customerHistoryId, Boolean cardOnlyLock) {
        if (customerHistoryId == null) {
            return;
        }
        if (!Schema.sObjectType.FEC_Customer_History__c.isUpdateable()) {
            return;
        }
        FEC_Customer_History__c recordToUpdate = new FEC_Customer_History__c(
            Id = customerHistoryId,
            FEC_Block_Code__c = BLOCK_CODE_CARD
        );
        if (!cardOnlyLock) {
            recordToUpdate.FEC_Block_Code_1__c = BLOCK_CODE_CARD;
        }
        List<FEC_Customer_History__c> updateRows = new List<FEC_Customer_History__c>{ recordToUpdate };
        updateRows = (List<FEC_Customer_History__c>) Security.stripInaccessible(AccessType.UPDATABLE, updateRows).getRecords();
        if (!updateRows.isEmpty()) {
            update updateRows;
        }
    }

    private static String getLast4Digit(String cardNumber) {
        if (String.isBlank(cardNumber)) {
            return null;
        }
        String digits = cardNumber.replaceAll('[^0-9]', '');
        if (String.isBlank(digits) || digits.length() < 4) {
            return null;
        }
        return digits.substring(digits.length() - 4);
    }
}
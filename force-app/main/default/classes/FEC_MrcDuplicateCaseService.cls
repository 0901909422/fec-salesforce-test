/**
 * RL05.02 — phát hiện Case RL05 đang xử lý trùng hợp đồng (case cũ hơn, cùng số HĐ),
 * banner trên Case Business, và áp Cancel theo FEC_MRC_Request_Handling_Option__c.
 */
public without sharing class FEC_MrcDuplicateCaseService {
    public static final String OPT_CANCEL_PREVIOUS =
        'Cancel previous request, create new request';
    public static final String OPT_CANCEL_NEW =
        'Cancel new request, continue previous request handling';

    private static Map<String, Case> olderDupRowCacheByKey = new Map<String, Case>();
    private static String cachedUserRoleName;
    private static Boolean userRoleNameResolved = false;

    /**
     * SOQL 101 (RL05.02 submit): bulk Cancel RAH từ dup — bỏ CaseManagerList/TAT/AutoHold trong trigger.
     */
    @TestVisible
    private static Boolean suppressRoutingHistoryTriggerSideEffects = false;

    public static Boolean isSuppressRoutingHistoryTriggerSideEffects() {
        return suppressRoutingHistoryTriggerSideEffects == true;
    }

    /**
     * RL05.02 submit trước route(): chỉ update Case/Remark sync; RAH dup ghi trong Queueable.
     */
    @TestVisible
    private static Boolean deferDupRoutingHistoryInsert = false;

    public static void setDeferDupRoutingHistoryInsert(Boolean defer) {
        deferDupRoutingHistoryInsert = defer == true;
    }

    public class OpenDupInfo {
        public String caseIdStr;
        public String caseNumber;
    }

    /** Trả Case RL05 đang mở, có CreatedDate nhỏ hơn case hiện tại (cùng hợp đồng). */
    public static OpenDupInfo findOlderOpenRl05DuplicateInfo(
        Id currentCaseId,
        Id customerHistoryId,
        String contractNumberText,
        Datetime currentCreatedDate,
        String subCategoryCode,
        String subCodeCode
    ) {
        Case dupRow = queryOlderOpenRl05DuplicateRow(
            currentCaseId,
            customerHistoryId,
            contractNumberText,
            currentCreatedDate,
            subCategoryCode,
            subCodeCode
        );
        if (dupRow == null) {
            return null;
        }
        OpenDupInfo out = new OpenDupInfo();
        out.caseIdStr = String.valueOf(dupRow.Id);
        out.caseNumber = resolveCaseIdForBanner(dupRow);
        return out;
    }

    /** Case ID hiển thị Noti-11 — FEC_Case_ID__c (formula) dùng FEC_ID_Search__c làm text. */
    private static String resolveCaseIdForBanner(Case caseRow) {
        if (caseRow == null) {
            return null;
        }
        if (String.isNotBlank(caseRow.FEC_ID_Search__c)) {
            return caseRow.FEC_ID_Search__c.trim();
        }
        return caseRow.CaseNumber;
    }

    public static Id findOlderOpenRl05DuplicateId(
        Id currentCaseId,
        Id customerHistoryId,
        String contractNumberText,
        Datetime currentCreatedDate,
        String subCategoryCode,
        String subCodeCode
    ) {
        Case dupRow = queryOlderOpenRl05DuplicateRow(
            currentCaseId,
            customerHistoryId,
            contractNumberText,
            currentCreatedDate,
            subCategoryCode,
            subCodeCode
        );
        return dupRow == null ? null : dupRow.Id;
    }

    private static String buildOlderDupCacheKey(
        Id currentCaseId,
        Id customerHistoryId,
        String contractNumberText,
        Datetime currentCreatedDate,
        String subCategoryCode,
        String subCodeCode
    ) {
        return String.valueOf(currentCaseId)
            + '|'
            + String.valueOf(customerHistoryId)
            + '|'
            + (contractNumberText == null ? '' : contractNumberText.trim())
            + '|'
            + String.valueOf(currentCreatedDate == null ? null : currentCreatedDate.getTime())
            + '|'
            + (subCategoryCode == null ? '' : subCategoryCode)
            + '|'
            + (subCodeCode == null ? '' : subCodeCode);
    }

    private static Case queryOlderOpenRl05DuplicateRow(
        Id currentCaseId,
        Id customerHistoryId,
        String contractNumberText,
        Datetime currentCreatedDate,
        String subCategoryCode,
        String subCodeCode
    ) {
        if (
            currentCaseId == null ||
            currentCreatedDate == null ||
            String.isBlank(subCodeCode) ||
            !subCodeCode.toUpperCase().contains('RL05.02')
        ) {
            return null;
        }
        if (String.isBlank(subCategoryCode) || !subCategoryCode.toUpperCase().contains('RL05')) {
            return null;
        }
        if (customerHistoryId == null && String.isBlank(contractNumberText)) {
            return null;
        }

        String cacheKey = buildOlderDupCacheKey(
            currentCaseId,
            customerHistoryId,
            contractNumberText,
            currentCreatedDate,
            subCategoryCode,
            subCodeCode
        );
        if (olderDupRowCacheByKey.containsKey(cacheKey)) {
            return olderDupRowCacheByKey.get(cacheKey);
        }

        String contractNum = String.isBlank(contractNumberText)
            ? null
            : contractNumberText.trim();
        List<Case> dups;
        if (String.isNotBlank(contractNum)) {
            dups = [
                SELECT
                    Id,
                    FEC_ID_Search__c,
                    CaseNumber,
                    FEC_Final_Status__c
                FROM Case
                WHERE
                    FEC_Account_Contract_Number_Text__c = :contractNum
                    AND Id != :currentCaseId
                    AND IsClosed = FALSE
                    AND FEC_SubCategory__r.FEC_Code__c LIKE '%RL05%'
                    AND (
                        FEC_SubCode__r.FEC_Code__c LIKE '%RL05.02%'
                        OR FEC_SubCode__r.Name LIKE '%RL05.02%'
                    )
                    AND FEC_Final_Status__c LIKE 'Pending%'
                    AND CreatedDate < :currentCreatedDate
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
        } else {
            dups = [
                SELECT
                    Id,
                    FEC_ID_Search__c,
                    CaseNumber,
                    FEC_Final_Status__c
                FROM Case
                WHERE
                    FEC_Account_or_Contract__c = :customerHistoryId
                    AND Id != :currentCaseId
                    AND IsClosed = FALSE
                    AND FEC_SubCategory__r.FEC_Code__c LIKE '%RL05%'
                    AND (
                        FEC_SubCode__r.FEC_Code__c LIKE '%RL05.02%'
                        OR FEC_SubCode__r.Name LIKE '%RL05.02%'
                    )
                    AND FEC_Final_Status__c LIKE 'Pending%'
                    AND CreatedDate < :currentCreatedDate
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
        }

        Case dupRow = dups.isEmpty() ? null : dups[0];
        olderDupRowCacheByKey.put(cacheKey, dupRow);
        return dupRow;
    }

    private static Boolean isRl0502SourceCase(Case sourceCaseRow) {
        if (sourceCaseRow == null || sourceCaseRow.FEC_SubCode__r == null) {
            return false;
        }
        String subCodeValue = sourceCaseRow.FEC_SubCode__r.FEC_Code__c;
        return String.isNotBlank(subCodeValue) &&
            subCodeValue.toUpperCase().contains('RL05.02');
    }

    /** Prefetch case trùng — không SELECT trong vòng lặp xử lý cancel. */
    private static Map<Id, Case> prefetchOlderDupRowBySourceCaseId(
        List<Case> sourceCaseRows
    ) {
        Map<Id, Case> olderDupBySourceId = new Map<Id, Case>();
        if (sourceCaseRows == null || sourceCaseRows.isEmpty()) {
            return olderDupBySourceId;
        }

        if (sourceCaseRows.size() == 1) {
            Case sourceCaseRow = sourceCaseRows[0];
            if (sourceCaseRow == null || sourceCaseRow.Id == null) {
                return olderDupBySourceId;
            }
            String subCategoryCode = sourceCaseRow.FEC_SubCategory__r == null
                ? null
                : sourceCaseRow.FEC_SubCategory__r.FEC_Code__c;
            String subCodeValue = sourceCaseRow.FEC_SubCode__r == null
                ? null
                : sourceCaseRow.FEC_SubCode__r.FEC_Code__c;
            olderDupBySourceId.put(
                sourceCaseRow.Id,
                queryOlderOpenRl05DuplicateRow(
                    sourceCaseRow.Id,
                    sourceCaseRow.FEC_Account_or_Contract__c,
                    sourceCaseRow.FEC_Account_Contract_Number_Text__c,
                    sourceCaseRow.CreatedDate,
                    subCategoryCode,
                    subCodeValue
                )
            );
            return olderDupBySourceId;
        }

        Set<String> contractNumbers = new Set<String>();
        Set<Id> customerHistoryIds = new Set<Id>();
        Map<Id, Case> eligibleSourceById = new Map<Id, Case>();

        for (Case sourceCaseRow : sourceCaseRows) {
            if (sourceCaseRow == null || sourceCaseRow.Id == null) {
                continue;
            }
            if (!isRl0502SourceCase(sourceCaseRow)) {
                continue;
            }
            eligibleSourceById.put(sourceCaseRow.Id, sourceCaseRow);
            if (String.isNotBlank(sourceCaseRow.FEC_Account_Contract_Number_Text__c)) {
                contractNumbers.add(
                    sourceCaseRow.FEC_Account_Contract_Number_Text__c.trim()
                );
            } else if (sourceCaseRow.FEC_Account_or_Contract__c != null) {
                customerHistoryIds.add(sourceCaseRow.FEC_Account_or_Contract__c);
            }
        }

        List<Case> candidateDupRows = new List<Case>();
        if (!contractNumbers.isEmpty()) {
            candidateDupRows.addAll(
                [
                    SELECT
                        Id,
                        FEC_ID_Search__c,
                        CaseNumber,
                        FEC_Final_Status__c,
                        CreatedDate,
                        FEC_Account_Contract_Number_Text__c,
                        FEC_Account_or_Contract__c
                    FROM Case
                    WHERE
                        FEC_Account_Contract_Number_Text__c IN :contractNumbers
                        AND IsClosed = FALSE
                        AND FEC_SubCategory__r.FEC_Code__c LIKE '%RL05%'
                        AND (
                            FEC_SubCode__r.FEC_Code__c LIKE '%RL05.02%'
                            OR FEC_SubCode__r.Name LIKE '%RL05.02%'
                        )
                        AND FEC_Final_Status__c LIKE 'Pending%'
                ]
            );
        }
        if (!customerHistoryIds.isEmpty()) {
            candidateDupRows.addAll(
                [
                    SELECT
                        Id,
                        FEC_ID_Search__c,
                        CaseNumber,
                        FEC_Final_Status__c,
                        CreatedDate,
                        FEC_Account_Contract_Number_Text__c,
                        FEC_Account_or_Contract__c
                    FROM Case
                    WHERE
                        FEC_Account_or_Contract__c IN :customerHistoryIds
                        AND IsClosed = FALSE
                        AND FEC_SubCategory__r.FEC_Code__c LIKE '%RL05%'
                        AND (
                            FEC_SubCode__r.FEC_Code__c LIKE '%RL05.02%'
                            OR FEC_SubCode__r.Name LIKE '%RL05.02%'
                        )
                        AND FEC_Final_Status__c LIKE 'Pending%'
                ]
            );
        }

        for (Id sourceCaseId : eligibleSourceById.keySet()) {
            Case sourceCaseRow = eligibleSourceById.get(sourceCaseId);
            Case matchedDup = selectOlderDupForSource(sourceCaseRow, candidateDupRows);
            olderDupBySourceId.put(sourceCaseId, matchedDup);
            if (matchedDup != null) {
                String cacheKey = buildOlderDupCacheKey(
                    sourceCaseRow.Id,
                    sourceCaseRow.FEC_Account_or_Contract__c,
                    sourceCaseRow.FEC_Account_Contract_Number_Text__c,
                    sourceCaseRow.CreatedDate,
                    sourceCaseRow.FEC_SubCategory__r == null
                        ? null
                        : sourceCaseRow.FEC_SubCategory__r.FEC_Code__c,
                    sourceCaseRow.FEC_SubCode__r == null
                        ? null
                        : sourceCaseRow.FEC_SubCode__r.FEC_Code__c
                );
                olderDupRowCacheByKey.put(cacheKey, matchedDup);
            }
        }
        return olderDupBySourceId;
    }

    private static Case selectOlderDupForSource(
        Case sourceCaseRow,
        List<Case> candidateDupRows
    ) {
        if (sourceCaseRow == null || candidateDupRows == null || candidateDupRows.isEmpty()) {
            return null;
        }
        Case bestMatch;
        for (Case candidateRow : candidateDupRows) {
            if (candidateRow == null || candidateRow.Id == sourceCaseRow.Id) {
                continue;
            }
            if (
                sourceCaseRow.CreatedDate != null &&
                candidateRow.CreatedDate >= sourceCaseRow.CreatedDate
            ) {
                continue;
            }
            if (
                String.isNotBlank(sourceCaseRow.FEC_Account_Contract_Number_Text__c) &&
                sourceCaseRow.FEC_Account_Contract_Number_Text__c.trim() !=
                candidateRow.FEC_Account_Contract_Number_Text__c
            ) {
                continue;
            }
            if (
                String.isBlank(sourceCaseRow.FEC_Account_Contract_Number_Text__c) &&
                sourceCaseRow.FEC_Account_or_Contract__c !=
                candidateRow.FEC_Account_or_Contract__c
            ) {
                continue;
            }
            if (bestMatch == null || candidateRow.CreatedDate > bestMatch.CreatedDate) {
                bestMatch = candidateRow;
            }
        }
        return bestMatch;
    }

    /** Giữ hook trigger (nếu có) — RL05.02 không auto-cancel khi đổi radio; chỉ submit Route To. */
    public static void applyHandlingOptionChanges(List<Case> newCases, Map<Id, Case> oldMap) {
        return;
    }

    /**
     * RL05.02 — Submit: "Chưa nhận MRC" + Option 1 (hủy Case cũ) → auto-cancel Case trùng cũ.
     * Chỉ chạy sau submit thành công (Route To), không chạy khi user mới chọn radio.
     */
    /**
     * Submit Route To — hủy case RL05 trùng (Option 1).
     * Dùng giá trị MRC từ LWC (params) để không phụ thuộc Queueable / đọc DB sau route.
     */
    public static void applyNotReceivedHandlingOptionOnSubmit(
        Id caseId,
        String customerConfirmation,
        String handlingOption
    ) {
        applyNotReceivedHandlingOptionOnSubmitNow(
            caseId,
            customerConfirmation,
            handlingOption
        );
    }

    public static void applyNotReceivedHandlingOptionOnSubmit(Id caseId) {
        applyNotReceivedHandlingOptionOnSubmit(caseId, null, null);
    }

    public static void applyNotReceivedHandlingOptionOnSubmitNow(Id caseId) {
        applyNotReceivedHandlingOptionOnSubmitNow(caseId, null, null);
    }

    /**
     * RL05.02 Submit Route To — "Đã nhận MRC" (action Cancel): auto-cancel Case trùng cũ,
     * giống Option 1 "hủy yêu cầu cũ" khi chưa nhận MRC.
     */
    public static void applyReceivedConfirmationDuplicateCancelOnSubmit(
        Id caseId,
        String customerConfirmationOverride
    ) {
        applyReceivedConfirmationDuplicateCancelNow(
            caseId,
            customerConfirmationOverride
        );
    }

    public static void applyReceivedConfirmationDuplicateCancelOnSubmit(Id caseId) {
        applyReceivedConfirmationDuplicateCancelOnSubmit(caseId, null);
    }

    public static void applyNotReceivedHandlingOptionOnSubmitNow(
        Id caseId,
        String customerConfirmationOverride,
        String handlingOptionOverride
    ) {
        if (caseId == null) {
            return;
        }
        List<Case> rows = [
            SELECT
                Id,
                CaseNumber,
                FEC_ID_Search__c,
                CreatedDate,
                FEC_Customer_Confirmation__c,
                FEC_MRC_Request_Handling_Option__c,
                FEC_Account_or_Contract__c,
                FEC_Account_Contract_Number_Text__c,
                FEC_SubCategory__r.FEC_Code__c,
                FEC_SubCode__r.FEC_Code__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        if (rows.isEmpty()) {
            return;
        }
        Case sourceCaseRow = mergeSourceCaseForDupCancel(
            rows[0],
            customerConfirmationOverride,
            handlingOptionOverride
        );
        if (sourceCaseRow == null) {
            return;
        }
        applyNotReceivedHandlingOptionCancel(
            new List<Case>{ sourceCaseRow },
            true
        );
    }

    private static Case mergeSourceCaseForDupCancel(
        Case loadedRow,
        String customerConfirmationOverride,
        String handlingOptionOverride
    ) {
        if (loadedRow == null) {
            return null;
        }
        Case sourceCaseRow = loadedRow;
        if (String.isNotBlank(customerConfirmationOverride)) {
            sourceCaseRow.FEC_Customer_Confirmation__c = customerConfirmationOverride.trim();
        }
        if (String.isNotBlank(handlingOptionOverride)) {
            sourceCaseRow.FEC_MRC_Request_Handling_Option__c = handlingOptionOverride.trim();
        }
        Boolean needsReload =
            String.isBlank(sourceCaseRow.FEC_Customer_Confirmation__c) ||
            String.isBlank(sourceCaseRow.FEC_MRC_Request_Handling_Option__c) ||
            sourceCaseRow.FEC_SubCode__r == null ||
            sourceCaseRow.FEC_SubCategory__r == null;
        if (!needsReload) {
            return sourceCaseRow;
        }
        List<Case> refreshed = [
            SELECT
                Id,
                CaseNumber,
                FEC_ID_Search__c,
                CreatedDate,
                FEC_Customer_Confirmation__c,
                FEC_MRC_Request_Handling_Option__c,
                FEC_Account_or_Contract__c,
                FEC_Account_Contract_Number_Text__c,
                FEC_SubCategory__r.FEC_Code__c,
                FEC_SubCode__r.FEC_Code__c
            FROM Case
            WHERE Id = :sourceCaseRow.Id
            LIMIT 1
        ];
        if (refreshed.isEmpty()) {
            return sourceCaseRow;
        }
        sourceCaseRow = refreshed[0];
        if (String.isNotBlank(customerConfirmationOverride)) {
            sourceCaseRow.FEC_Customer_Confirmation__c = customerConfirmationOverride.trim();
        }
        if (String.isNotBlank(handlingOptionOverride)) {
            sourceCaseRow.FEC_MRC_Request_Handling_Option__c = handlingOptionOverride.trim();
        }
        return sourceCaseRow;
    }

    private static Boolean isCancelPreviousHandlingOption(String handlingOption) {
        if (String.isBlank(handlingOption)) {
            return false;
        }
        String normalized = handlingOption.trim().toLowerCase();
        if (OPT_CANCEL_PREVIOUS.equalsIgnoreCase(handlingOption.trim())) {
            return true;
        }
        return normalized.contains('cancel previous') ||
            normalized.contains('hủy yêu cầu cũ') ||
            normalized.contains('huy yeu cau cu');
    }

    private static void applyNotReceivedHandlingOptionCancel(
        List<Case> sourceCaseRows,
        Boolean submitOnlyCancelPrevious
    ) {
        if (sourceCaseRows == null || sourceCaseRows.isEmpty()) {
            return;
        }

        List<Case> toCancelStatus = new List<Case>();
        List<FEC_Case_Remarks__c> remarks = new List<FEC_Case_Remarks__c>();
        List<CancelPreviousDupContext> cancelPreviousContexts =
            new List<CancelPreviousDupContext>();

        String emailLocal = emailLocalSafe(UserInfo.getUserEmail());
        String roleName = resolveUserRoleName();
        Map<Id, Case> olderDupBySourceId = prefetchOlderDupRowBySourceCaseId(
            sourceCaseRows
        );

        for (Case sourceCaseRow : sourceCaseRows) {
            if (!isNotReceivedConfirmation(sourceCaseRow.FEC_Customer_Confirmation__c)) {
                continue;
            }

            String subCategoryCode = sourceCaseRow.FEC_SubCategory__r == null
                ? null
                : sourceCaseRow.FEC_SubCategory__r.FEC_Code__c;
            String subCodeValue = sourceCaseRow.FEC_SubCode__r == null
                ? null
                : sourceCaseRow.FEC_SubCode__r.FEC_Code__c;
            Case olderDupRow = olderDupBySourceId.get(sourceCaseRow.Id);
            Id olderDupId = olderDupRow == null ? null : olderDupRow.Id;

            String handlingOption = sourceCaseRow.FEC_MRC_Request_Handling_Option__c;
            if (
                !isCancelPreviousHandlingOption(handlingOption) &&
                !OPT_CANCEL_NEW.equals(handlingOption)
            ) {
                continue;
            }
            if (
                String.isBlank(subCodeValue) ||
                !subCodeValue.toUpperCase().contains('RL05.02')
            ) {
                continue;
            }
            if (
                String.isBlank(subCategoryCode) ||
                !subCategoryCode.toUpperCase().contains('RL05')
            ) {
                continue;
            }

            if (isCancelPreviousHandlingOption(handlingOption)) {
                if (olderDupId == null) {
                    continue;
                }
                toCancelStatus.add(
                    new Case(
                        Id = olderDupId,
                        Status = FEC_ConstantCommon.CASE_STATUS_AUTO_CANCELLED
                    )
                );
                cancelPreviousContexts.add(
                    new CancelPreviousDupContext(olderDupId, sourceCaseRow)
                );
                remarks.add(
                    buildRemark(
                        olderDupId,
                        String.format(
                            System.Label.FEC_MRC_Dup_Remark_Cancel_Prev,
                            new List<String>{ resolveCaseIdForBanner(sourceCaseRow) }
                        ),
                        emailLocal,
                        roleName
                    )
                );
            } else if (
                !submitOnlyCancelPrevious &&
                OPT_CANCEL_NEW.equals(handlingOption)
            ) {
                String olderNum = FEC_ConstantCommon.STR_EMPTY;
                if (olderDupRow != null) {
                    olderNum = resolveCaseIdForBanner(olderDupRow);
                    if (olderNum == null) {
                        olderNum = FEC_ConstantCommon.STR_EMPTY;
                    }
                }
                toCancelStatus.add(
                    new Case(
                        Id = sourceCaseRow.Id,
                        Status = FEC_ConstantCommon.CASE_STATUS_AUTO_CANCELLED
                    )
                );
                remarks.add(
                    buildRemark(
                        sourceCaseRow.Id,
                        String.format(
                            System.Label.FEC_MRC_Dup_Remark_Cancel_New,
                            new List<String>{ olderNum }
                        ),
                        emailLocal,
                        roleName
                    )
                );
            }
        }

        if (toCancelStatus.isEmpty()) {
            return;
        }

        Set<Id> dupIds = new Set<Id>();
        for (CancelPreviousDupContext ctx : cancelPreviousContexts) {
            dupIds.add(ctx.dupCaseId);
        }
        Map<Id, String> dupStatusBefore = new Map<Id, String>();
        if (!dupIds.isEmpty()) {
            for (Case dupRow : [
                SELECT Id, FEC_Final_Status__c
                FROM Case
                WHERE Id IN :dupIds
            ]) {
                dupStatusBefore.put(dupRow.Id, dupRow.FEC_Final_Status__c);
            }
        }

        try {
            FEC_CaseTriggerHandler.isSystemUpdate = true;
            Database.update(toCancelStatus, AccessLevel.SYSTEM_MODE);
        } catch (Exception e) {
            System.debug(
                LoggingLevel.ERROR,
                'FEC_MrcDuplicateCaseService: update cancelled cases failed — ' +
                e.getMessage()
            );
            throw e;
        } finally {
            FEC_CaseTriggerHandler.isSystemUpdate = false;
        }

        if (!deferDupRoutingHistoryInsert) {
            recordRoutingActionHistoryForCasesBulk(
                cancelPreviousContexts,
                dupStatusBefore
            );
        }

        if (!remarks.isEmpty()) {
            try {
                Database.insert(remarks, AccessLevel.SYSTEM_MODE);
            } catch (Exception e) {
                System.debug(
                    LoggingLevel.ERROR,
                    'FEC_MrcDuplicateCaseService: insert remarks failed — ' +
                    e.getMessage()
                );
            }
        }
    }

    private class CancelPreviousDupContext {
        Id dupCaseId;
        Case newCase;

        CancelPreviousDupContext(Id dupCaseId, Case newCase) {
            this.dupCaseId = dupCaseId;
            this.newCase = newCase;
        }
    }

    private static FEC_Case_Remarks__c buildRemark(
        Id caseId,
        String body,
        String emailLocal,
        String roleName
    ) {
        FEC_Case_Remarks__c r = new FEC_Case_Remarks__c();
        r.FEC_Case__c = caseId;
        r.FEC_Case_Remarks__c = body;
        r.FEC_User__c = emailLocal;
        r.FEC_User_Role__c = roleName;
        return r;
    }

    private static String emailLocalSafe(String email) {
        if (String.isBlank(email) || !email.contains('@')) {
            return email;
        }
        return email.substring(0, email.indexOf('@'));
    }

    private static String resolveUserRoleName() {
        if (userRoleNameResolved) {
            return cachedUserRoleName;
        }
        userRoleNameResolved = true;
        Id rid = UserInfo.getUserRoleId();
        if (rid == null) {
            cachedUserRoleName = null;
            return null;
        }
        List<UserRole> rl = [
            SELECT Name
            FROM UserRole
            WHERE Id = :rid
            LIMIT 1
        ];
        cachedUserRoleName = rl.isEmpty() ? null : rl[0].Name;
        return cachedUserRoleName;
    }

    /**
     * RL05.02 — Routing Cancel hoặc Route To (action Cancel) + "Đã nhận MRC":
     * auto-cancel Case trùng cũ hơn → Resolved-AutoCancelled.
     */
    public static void applyReceivedConfirmationDuplicateCancel(Id newCaseId) {
        applyReceivedConfirmationDuplicateCancelNow(newCaseId, null);
    }

    private static void applyReceivedConfirmationDuplicateCancelNow(
        Id newCaseId,
        String customerConfirmationOverride
    ) {
        if (newCaseId == null) {
            return;
        }
        List<Case> newRows = [
            SELECT
                Id,
                CaseNumber,
                FEC_ID_Search__c,
                CreatedDate,
                FEC_Customer_Confirmation__c,
                FEC_Account_or_Contract__c,
                FEC_Account_Contract_Number_Text__c,
                FEC_SubCategory__r.FEC_Code__c,
                FEC_SubCode__r.FEC_Code__c
            FROM Case
            WHERE Id = :newCaseId
            LIMIT 1
        ];
        if (newRows.isEmpty()) {
            return;
        }
        Case newCase = newRows[0];
        if (String.isNotBlank(customerConfirmationOverride)) {
            newCase.FEC_Customer_Confirmation__c = customerConfirmationOverride.trim();
        }
        String subCat = newCase.FEC_SubCategory__r == null
            ? null
            : newCase.FEC_SubCategory__r.FEC_Code__c;
        String subCod = newCase.FEC_SubCode__r == null
            ? null
            : newCase.FEC_SubCode__r.FEC_Code__c;
        if (
            String.isBlank(subCod) ||
            !subCod.toUpperCase().contains('RL05.02') ||
            !isReceivedConfirmation(newCase.FEC_Customer_Confirmation__c)
        ) {
            return;
        }
        if (
            String.isBlank(subCat) ||
            !subCat.toUpperCase().contains('RL05')
        ) {
            return;
        }

        Map<Id, Case> olderDupBySourceId = prefetchOlderDupRowBySourceCaseId(
            new List<Case>{ newCase }
        );
        Case olderDupRow = olderDupBySourceId.get(newCase.Id);
        if (olderDupRow == null || olderDupRow.Id == null) {
            return;
        }
        Id olderDupId = olderDupRow.Id;

        String dupStatusBefore = olderDupRow.FEC_Final_Status__c;

        try {
            FEC_CaseTriggerHandler.isSystemUpdate = true;
            Database.update(
                new List<Case>{
                    new Case(
                        Id = olderDupId,
                        Status = FEC_ConstantCommon.CASE_STATUS_AUTO_CANCELLED
                    )
                },
                AccessLevel.SYSTEM_MODE
            );
        } catch (Exception e) {
            System.debug(
                LoggingLevel.ERROR,
                'FEC_MrcDuplicateCaseService.applyReceivedConfirmationDuplicateCancel: update dup failed — ' +
                e.getMessage()
            );
            return;
        } finally {
            FEC_CaseTriggerHandler.isSystemUpdate = false;
        }

        if (!deferDupRoutingHistoryInsert) {
            suppressRoutingHistoryTriggerSideEffects = true;
            try {
                recordRoutingActionHistoryForCase(
                    olderDupId,
                    'Cancel',
                    dupStatusBefore
                );
            } catch (Exception e) {
                System.debug(
                    LoggingLevel.ERROR,
                    'FEC_MrcDuplicateCaseService.applyReceivedConfirmationDuplicateCancel: RAH failed — ' +
                    e.getMessage()
                );
            } finally {
                suppressRoutingHistoryTriggerSideEffects = false;
            }
        }

        String emailLocal = emailLocalSafe(UserInfo.getUserEmail());
        String roleName = resolveUserRoleName();
        String newCaseDisplayId = resolveCaseIdForBanner(newCase);
        String remarkBody = String.format(
            System.Label.FEC_MRC_Dup_Remark_Cancel_Prev,
            new List<String>{
                String.isNotBlank(newCaseDisplayId)
                    ? newCaseDisplayId
                    : newCase.CaseNumber
            }
        );
        try {
            insert buildRemark(olderDupId, remarkBody, emailLocal, roleName);
        } catch (Exception e) {
            System.debug(
                LoggingLevel.ERROR,
                'FEC_MrcDuplicateCaseService.applyReceivedConfirmationDuplicateCancel: remark failed — ' +
                e.getMessage()
            );
        }
    }

    private static Boolean isNotReceivedConfirmation(String value) {
        if (String.isBlank(value)) {
            return false;
        }
        String normalized = value.trim().toLowerCase();
        return normalized.equals(
                FEC_MrcReturnCaseService.CONF_NOT_RECEIVED.toLowerCase()
            ) ||
            normalized.contains('not received') ||
            normalized.contains('chua nhan') ||
            normalized.contains('chua xac nhan') ||
            normalized.contains('chưa nhận') ||
            normalized.contains('chưa xác nhận');
    }

    private static Boolean isReceivedConfirmation(String value) {
        if (String.isBlank(value)) {
            return false;
        }
        String normalized = value.trim().toLowerCase();
        if (
            normalized.contains('not received') ||
            normalized.contains('chua nhan') ||
            normalized.contains('chua xac nhan') ||
            normalized.contains('chưa nhận') ||
            normalized.contains('chưa xác nhận')
        ) {
            return false;
        }
        return normalized.equals(
                FEC_MrcReturnCaseService.CONF_RECEIVED.toLowerCase()
            ) ||
            (normalized.contains('received') &&
            !normalized.contains('not received')) ||
            normalized.contains('đã nhận') ||
            normalized.contains('đã xác nhận');
    }

    /**
     * Ghi Routing Action History (Cancel Case trùng RL05, …) — delegate FEC_CaseBusinessService.createRoutingActionHis.
     */
    public static void createRoutingActionHistoryForCase(
        String routingAction,
        String decision,
        String oldOwnerName,
        Id originalOwnerId,
        String caseId,
        String stageName,
        String finalStatusBeforeSubmit,
        Id currentStageId
    ) {
        FEC_CaseBusinessService.createRoutingActionHis(
            routingAction,
            decision,
            oldOwnerName,
            originalOwnerId,
            caseId,
            stageName,
            finalStatusBeforeSubmit,
            currentStageId
        );
    }

    /** Bulk — một SOQL Case + một SOQL User; không gọi createRoutingActionHis trong loop. */
    private static void recordRoutingActionHistoryForCasesBulk(
        List<CancelPreviousDupContext> contexts,
        Map<Id, String> finalStatusBeforeByCaseId
    ) {
        if (contexts == null || contexts.isEmpty()) {
            return;
        }
        Set<Id> dupCaseIds = new Set<Id>();
        for (CancelPreviousDupContext ctx : contexts) {
            if (ctx.dupCaseId != null) {
                dupCaseIds.add(ctx.dupCaseId);
            }
        }
        if (dupCaseIds.isEmpty()) {
            return;
        }

        List<User> performUserRows = [
            SELECT Email, UserRole.Name, Id
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        if (performUserRows.isEmpty()) {
            return;
        }
        User performUserRow = performUserRows[0];
        String performUserEmailLocal = emailLocalSafe(performUserRow.Email);
        String performUserRoleName = performUserRow.UserRole?.Name;

        Map<Id, Case> dupCaseById = new Map<Id, Case>([
            SELECT
                Id,
                OwnerId,
                Owner.Name,
                FEC_Stage_Name__c,
                FEC_Current_Case_Stage__c,
                FEC_Final_Status__c
            FROM Case
            WHERE Id IN :dupCaseIds
        ]);

        List<FEC_Routing_Action_History__c> historiesToInsert =
            new List<FEC_Routing_Action_History__c>();

        for (CancelPreviousDupContext ctx : contexts) {
            Case dupCaseRow = dupCaseById.get(ctx.dupCaseId);
            if (dupCaseRow == null) {
                continue;
            }
            historiesToInsert.add(
                new FEC_Routing_Action_History__c(
                    FEC_Routing_Action__c = 'Cancel',
                    FEC_Decision__c = FEC_ConstantCommon.STR_EMPTY,
                    FEC_Case__c = ctx.dupCaseId,
                    FEC_Original_User_Queue__c = FEC_CaseBusinessService.resolveRoutingHistoryOwnerLabel(
                        dupCaseRow.OwnerId,
                        dupCaseRow.Owner?.Name
                    ),
                    FEC_Original_User_Queue_ID__c = dupCaseRow.OwnerId != null
                        ? String.valueOf(dupCaseRow.OwnerId)
                        : null,
                    FEC_Updated_User_Queue__c = FEC_CaseBusinessService.resolveRoutingHistoryOwnerLabel(
                        dupCaseRow.OwnerId,
                        dupCaseRow.Owner?.Name
                    ),
                    FEC_Updated_User_Queue_ID__c = dupCaseRow.OwnerId != null
                        ? String.valueOf(dupCaseRow.OwnerId)
                        : null,
                    FEC_Stage_Name__c = dupCaseRow.FEC_Stage_Name__c,
                    FEC_User__c = performUserEmailLocal,
                    FEC_User_Role__c = performUserRoleName,
                    FEC_Current_Status__c = finalStatusBeforeByCaseId.get(ctx.dupCaseId),
                    FEC_Changed_Status__c = dupCaseRow.FEC_Final_Status__c,
                    FEC_Previous_Stage__c = dupCaseRow.FEC_Current_Case_Stage__c
                )
            );
        }

        if (historiesToInsert.isEmpty()) {
            return;
        }

        suppressRoutingHistoryTriggerSideEffects = true;
        try {
            insert historiesToInsert;
        } catch (Exception e) {
            System.debug(
                LoggingLevel.ERROR,
                'FEC_MrcDuplicateCaseService: bulk RAH insert failed — ' +
                e.getMessage()
            );
        } finally {
            suppressRoutingHistoryTriggerSideEffects = false;
        }
    }

    /**
     * RL05 / MRC — ghi Routing Action History cho Case (vd. auto-cancel Case trùng TH1).
     */
    public static void recordRoutingActionHistoryForCase(
        Id caseId,
        String routingAction,
        String finalStatusBeforeSubmit
    ) {
        if (caseId == null || String.isBlank(routingAction)) {
            return;
        }
        List<Case> rows = [
            SELECT
                Id,
                OwnerId,
                Owner.Name,
                FEC_Stage_Name__c,
                FEC_Current_Case_Stage__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        if (rows.isEmpty()) {
            return;
        }
        Case targetCaseRow = rows[0];
        createRoutingActionHistoryForCase(
            routingAction,
            '',
            FEC_CaseBusinessService.resolveRoutingHistoryOwnerLabel(
                targetCaseRow.OwnerId,
                targetCaseRow.Owner?.Name
            ),
            targetCaseRow.OwnerId,
            String.valueOf(caseId),
            targetCaseRow.FEC_Stage_Name__c,
            finalStatusBeforeSubmit,
            targetCaseRow.FEC_Current_Case_Stage__c
        );
    }
}
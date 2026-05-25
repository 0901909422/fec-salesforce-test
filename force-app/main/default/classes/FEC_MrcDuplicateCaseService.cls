/**
 * RL05.02 — phát hiện Case RL05 đang xử lý trùng hợp đồng (case cũ hơn, cùng số HĐ),
 * banner trên Case Business, và áp Cancel theo FEC_MRC_Request_Handling_Option__c.
 */
public without sharing class FEC_MrcDuplicateCaseService {
    public static final String OPT_CANCEL_PREVIOUS =
        'Cancel previous request, create new request';
    public static final String OPT_CANCEL_NEW =
        'Cancel new request, continue previous request handling';

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
        Id dupId = findOlderOpenRl05DuplicateId(
            currentCaseId,
            customerHistoryId,
            contractNumberText,
            currentCreatedDate,
            subCategoryCode,
            subCodeCode
        );
        if (dupId == null) {
            return null;
        }
        List<Case> rows = [
            SELECT FEC_ID_Search__c, CaseNumber
            FROM Case
            WHERE Id = :dupId
            LIMIT 1
        ];
        if (rows.isEmpty()) {
            return null;
        }
        OpenDupInfo out = new OpenDupInfo();
        out.caseIdStr = String.valueOf(dupId);
        out.caseNumber = resolveCaseIdForBanner(rows[0]);
        return out;
    }

    /** Case ID hiển thị Noti-11 — FEC_Case_ID__c (formula) dùng FEC_ID_Search__c làm text. */
    private static String resolveCaseIdForBanner(Case c) {
        if (c == null) {
            return null;
        }
        if (String.isNotBlank(c.FEC_ID_Search__c)) {
            return c.FEC_ID_Search__c.trim();
        }
        return c.CaseNumber;
    }

    public static Id findOlderOpenRl05DuplicateId(
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

        String contractNum = String.isBlank(contractNumberText)
            ? null
            : contractNumberText.trim();
        List<Case> dups;
        if (String.isNotBlank(contractNum)) {
            dups = [
                SELECT Id
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
                SELECT Id
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
        return dups.isEmpty() ? null : dups[0].Id;
    }

    /** Giữ hook trigger (nếu có) — RL05.02 không auto-cancel khi đổi radio; chỉ submit Route To. */
    public static void applyHandlingOptionChanges(List<Case> newCases, Map<Id, Case> oldMap) {
        return;
    }

    /**
     * RL05.02 — Submit: "Chưa nhận MRC" + Option 1 (hủy Case cũ) → auto-cancel Case trùng cũ.
     * Chỉ chạy sau submit thành công (Route To), không chạy khi user mới chọn radio.
     */
    public static void applyNotReceivedHandlingOptionOnSubmit(Id caseId) {
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
        applyNotReceivedHandlingOptionCancel(rows, true);
    }

    private static void applyNotReceivedHandlingOptionCancel(
        List<Case> cases,
        Boolean submitOnlyCancelPrevious
    ) {
        if (cases == null || cases.isEmpty()) {
            return;
        }

        List<Case> toCancelStatus = new List<Case>();
        List<FEC_Case_Remarks__c> remarks = new List<FEC_Case_Remarks__c>();
        List<CancelPreviousDupContext> cancelPreviousContexts =
            new List<CancelPreviousDupContext>();

        String emailLocal = emailLocalSafe(UserInfo.getUserEmail());
        String roleName = resolveUserRoleName();

        for (Case c : cases) {
            if (!isNotReceivedConfirmation(c.FEC_Customer_Confirmation__c)) {
                continue;
            }

            String subCat = c.FEC_SubCategory__r == null
                ? null
                : c.FEC_SubCategory__r.FEC_Code__c;
            String subCod = c.FEC_SubCode__r == null
                ? null
                : c.FEC_SubCode__r.FEC_Code__c;
            Id olderDupId = findOlderOpenRl05DuplicateId(
                c.Id,
                c.FEC_Account_or_Contract__c,
                c.FEC_Account_Contract_Number_Text__c,
                c.CreatedDate,
                subCat,
                subCod
            );

            String opt = c.FEC_MRC_Request_Handling_Option__c;
            if (!OPT_CANCEL_PREVIOUS.equals(opt) && !OPT_CANCEL_NEW.equals(opt)) {
                continue;
            }
            if (String.isBlank(subCod) || !subCod.toUpperCase().contains('RL05.02')) {
                continue;
            }
            if (String.isBlank(subCat) || !subCat.toUpperCase().contains('RL05')) {
                continue;
            }

            if (OPT_CANCEL_PREVIOUS.equals(opt)) {
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
                    new CancelPreviousDupContext(olderDupId, c)
                );
                remarks.add(
                    buildRemark(
                        olderDupId,
                        String.format(
                            System.Label.FEC_MRC_Dup_Remark_Cancel_Prev,
                            new List<String>{ resolveCaseIdForBanner(c) }
                        ),
                        emailLocal,
                        roleName
                    )
                );
            } else if (!submitOnlyCancelPrevious && OPT_CANCEL_NEW.equals(opt)) {
                String olderNum = FEC_ConstantCommon.STR_EMPTY;
                if (olderDupId != null) {
                    List<Case> peerLst = [
                        SELECT FEC_ID_Search__c, CaseNumber
                        FROM Case
                        WHERE Id = :olderDupId
                        LIMIT 1
                    ];
                    if (!peerLst.isEmpty()) {
                        olderNum = resolveCaseIdForBanner(peerLst[0]);
                        if (olderNum == null) {
                            olderNum = FEC_ConstantCommon.STR_EMPTY;
                        }
                    }
                }
                toCancelStatus.add(
                    new Case(Id = c.Id, Status = FEC_ConstantCommon.CASE_STATUS_AUTO_CANCELLED)
                );
                remarks.add(
                    buildRemark(
                        c.Id,
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
            Database.update(toCancelStatus, AccessLevel.USER_MODE);
        } catch (Exception e) {
            System.debug(
                LoggingLevel.ERROR,
                'FEC_MrcDuplicateCaseService: update cancelled cases failed — ' +
                e.getMessage()
            );
            return;
        } finally {
            FEC_CaseTriggerHandler.isSystemUpdate = false;
        }

        for (CancelPreviousDupContext ctx : cancelPreviousContexts) {
            try {
                FEC_CaseBusinessService.recordRoutingActionHistoryForCase(
                    ctx.dupCaseId,
                    'Cancel',
                    dupStatusBefore.get(ctx.dupCaseId)
                );
            } catch (Exception e) {
                System.debug(
                    LoggingLevel.ERROR,
                    'FEC_MrcDuplicateCaseService: RAH cancel previous failed — ' +
                    e.getMessage()
                );
            }
        }

        if (!remarks.isEmpty()) {
            try {
                insert remarks;
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
        Id rid = UserInfo.getUserRoleId();
        if (rid == null) {
            return null;
        }
        List<UserRole> rl = [
            SELECT Name
            FROM UserRole
            WHERE Id = :rid
            LIMIT 1
        ];
        return rl.isEmpty() ? null : rl[0].Name;
    }

    /**
     * RL05.02 TH1 — Case mới Cancel + "Đã nhận MRC": auto-cancel Case trùng cũ hơn,
     * sinh Routing Action History và Case Remark theo spec.
     */
    public static void applyReceivedConfirmationDuplicateCancel(Id newCaseId) {
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
                FEC_SubCode__r.FEC_Code__c,
                FEC_Account_or_Contract__r.FEC_MRC_Status__c,
                FEC_Account_or_Contract__r.FEC_Status_ID__c
            FROM Case
            WHERE Id = :newCaseId
            LIMIT 1
        ];
        if (newRows.isEmpty()) {
            return;
        }
        Case newCase = newRows[0];
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

        Id olderDupId = findOlderOpenRl05DuplicateId(
            newCase.Id,
            newCase.FEC_Account_or_Contract__c,
            newCase.FEC_Account_Contract_Number_Text__c,
            newCase.CreatedDate,
            subCat,
            subCod
        );
        if (olderDupId == null) {
            return;
        }

        String mrcStatusId = null;
        if (newCase.FEC_Account_or_Contract__r != null) {
            mrcStatusId = newCase.FEC_Account_or_Contract__r.FEC_MRC_Status__c;
            if (String.isBlank(mrcStatusId)) {
                mrcStatusId = newCase.FEC_Account_or_Contract__r.FEC_Status_ID__c;
            }
        }
        if (!FEC_MrcReturnCaseService.meetsCondition2(mrcStatusId)) {
            return;
        }

        List<Case> dupRows = [
            SELECT
                Id,
                FEC_Final_Status__c,
                Status
            FROM Case
            WHERE Id = :olderDupId
            LIMIT 1
        ];
        if (dupRows.isEmpty()) {
            return;
        }
        String dupStatusBefore = dupRows[0].FEC_Final_Status__c;

        try {
            FEC_CaseTriggerHandler.isSystemUpdate = true;
            Database.update(
                new List<Case>{
                    new Case(
                        Id = olderDupId,
                        Status = FEC_ConstantCommon.CASE_STATUS_AUTO_CANCELLED
                    )
                },
                AccessLevel.USER_MODE
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

        try {
            FEC_CaseBusinessService.recordRoutingActionHistoryForCase(
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
        }

        String emailLocal = emailLocalSafe(UserInfo.getUserEmail());
        String roleName = resolveUserRoleName();
        String newCaseDisplayId = resolveCaseIdForBanner(newCase);
        String remarkBody = String.format(
            System.Label.FEC_MRC_Dup_Remark_Received_Confirm,
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
}
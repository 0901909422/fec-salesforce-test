/**
 * Export Batch Case Handling: load Assignment + Assignment Remarks từ FEC_Case_Remarks__c
 * (FEC_Remark_Type__c = Assignment), thay nguồn FEC_Routing_Action_History__c.
 */
public without sharing class FEC_BCH_ExportAssignmentRemarkLoader {

    public class AssignmentRemarkExportBundle {
        public String assignmentId = FEC_ConstantCommon.STR_EMPTY;
        public String assignmentOwner = FEC_ConstantCommon.STR_EMPTY;
        public String assignmentRemarks = FEC_ConstantCommon.STR_EMPTY;
        public String assignmentRemarksEnteredBy = FEC_ConstantCommon.STR_EMPTY;
        public String assignmentRemarksEnteredByRole = FEC_ConstantCommon.STR_EMPTY;
        public String assignmentRemarksEnteredOn = FEC_ConstantCommon.STR_EMPTY;
        private Integer lineIndex = 0;

        public Boolean hasData() {
            return String.isNotBlank(assignmentId)
                || String.isNotBlank(assignmentOwner)
                || String.isNotBlank(assignmentRemarks)
                || String.isNotBlank(assignmentRemarksEnteredBy)
                || String.isNotBlank(assignmentRemarksEnteredByRole)
                || String.isNotBlank(assignmentRemarksEnteredOn);
        }

        public void applyTo(FEC_BatchCaseHandlingExportRow row) {
            if (row == null) {
                return;
            }
            row.assignmentId = assignmentId;
            row.assignmentOwner = assignmentOwner;
            row.assignmentRemarks = assignmentRemarks;
            row.assignmentRemarksEnteredBy = assignmentRemarksEnteredBy;
            row.assignmentRemarksEnteredByRole = assignmentRemarksEnteredByRole;
            row.assignmentRemarksEnteredOn = assignmentRemarksEnteredOn;
        }

        public void addLine(
            String assignmentName,
            String assignmentOwnerText,
            String remarkText,
            String userText,
            String roleText,
            Datetime createdDt
        ) {
            lineIndex += 1;
            String prefix = '#' + String.valueOf(lineIndex) + ': ';
            assignmentId = appendLine(assignmentId, prefix + safeText(assignmentName));
            assignmentOwner = appendLine(assignmentOwner, prefix + safeText(assignmentOwnerText));
            assignmentRemarks = appendLine(assignmentRemarks, prefix + safeText(remarkText));
            assignmentRemarksEnteredBy = appendLine(assignmentRemarksEnteredBy, prefix + safeText(userText));
            assignmentRemarksEnteredByRole = appendLine(
                assignmentRemarksEnteredByRole,
                prefix + safeText(roleText)
            );
            assignmentRemarksEnteredOn = appendLine(
                assignmentRemarksEnteredOn,
                prefix + formatExportDatetime(createdDt)
            );
        }

        private String appendLine(String current, String incoming) {
            if (String.isBlank(incoming)) {
                return current;
            }
            if (String.isBlank(current)) {
                return incoming;
            }
            return current + '\n' + incoming;
        }

        private String safeText(String value) {
            return value == null ? FEC_ConstantCommon.STR_EMPTY : value;
        }

        private String formatExportDatetime(Datetime dt) {
            if (dt == null) {
                return FEC_ConstantCommon.STR_EMPTY;
            }
            return dt.format('dd/MM/yyyy hh:mm:ss a');
        }
    }

    public static Map<Id, AssignmentRemarkExportBundle> loadByCaseId(Set<Id> caseIds) {
        Map<Id, AssignmentRemarkExportBundle> out = new Map<Id, AssignmentRemarkExportBundle>();
        if (caseIds == null || caseIds.isEmpty()) {
            return out;
        }
        for (FEC_Case_Remarks__c remark : [
            SELECT
                FEC_Case__c,
                FEC_Case_Remarks__c,
                FEC_User__c,
                FEC_User_Role__c,
                CreatedDate,
                FEC_Assignment__r.Name,
                FEC_Assignment__r.FEC_Assignment_Owner_Text__c
            FROM FEC_Case_Remarks__c
            WHERE FEC_Case__c IN :caseIds
            AND FEC_Remark_Type__c = :FEC_ConstantCommon.REMARK_TYPE_ASSIGNMENT
            ORDER BY FEC_Case__c, CreatedDate ASC
        ]) {
            if (remark.FEC_Case__c == null) {
                continue;
            }
            if (!out.containsKey(remark.FEC_Case__c)) {
                out.put(remark.FEC_Case__c, new AssignmentRemarkExportBundle());
            }
            AssignmentRemarkExportBundle bundle = out.get(remark.FEC_Case__c);
            String assignmentName = remark.FEC_Assignment__r == null
                ? null
                : remark.FEC_Assignment__r.Name;
            String assignmentOwnerText = remark.FEC_Assignment__r == null
                ? null
                : remark.FEC_Assignment__r.FEC_Assignment_Owner_Text__c;
            bundle.addLine(
                assignmentName,
                assignmentOwnerText,
                remark.FEC_Case_Remarks__c,
                remark.FEC_User__c,
                remark.FEC_User_Role__c,
                remark.CreatedDate
            );
        }
        return out;
    }
}

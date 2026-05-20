/**
 * Enforces edit rules for FEC_Case_Assignment__c:
 * Draft – full edit.
 * Active – chỉ được đổi sang Archived nếu mọi field business (theo whitelist) không đổi so với bản trước update.
 * Archived – không đổi Status hay field business được giám sát.
 *
 * So sánh field business theo giá trị hiệu dụng: nếu field không nằm trong getPopulatedFieldsAsMap()
 * của bản new thì dùng giá trị Trigger.old (partial DML / field null trên new không bị hiểu nhầm là xóa).
 * Nếu field có trong map thì dùng giá trị trên new (kể cả query rồi assign).
 *
 * FEC_Running_Times__c: trên org thường được trigger/workflow khác cập nhật theo Status; khi Active → Archived
 * trigger đó có thể chạy trước và đổi nội dung long text — nhánh Active bỏ qua field này khi so sánh.
 */
public with sharing class FEC_CaseAssignmentMutationGuard {
    public static final String MSG_ARCHIVED_LOCKED =
        'Case Assignment có Status Archived không được chỉnh sửa.';
    public static final String MSG_ACTIVE_ONLY_ARCHIVE =
        'Khi Status là Active, chỉ được đổi Status sang Archived. Các field khác không được sửa.';

    private static final String RUNNING_TIMES_FIELD = 'FEC_Running_Times__c';

    private static final List<String> ASSIGNMENT_FIELDS_EXCEPT_STATUS = new List<String>{
        'Name',
        'OwnerId',
        'FEC_Business_Hours__c',
        'FEC_Assignment_Method__c',
        'FEC_Scheduled_Time__c',
        'FEC_Time_Slots__c',
        'FEC_Select_Queues__c',
        'FEC_Role__c',
        'FEC_Scale__c',
        RUNNING_TIMES_FIELD
    };

    public static void enforceBeforeUpdate(
        List<FEC_Case_Assignment__c> newList,
        Map<Id, FEC_Case_Assignment__c> oldMap
    ) {
        if (newList == null || newList.isEmpty() || oldMap == null || oldMap.isEmpty()) {
            return;
        }
        String archived = FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_ARCHIVED;
        String active = FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_ACTIVE;

        for (FEC_Case_Assignment__c newRow : newList) {
            FEC_Case_Assignment__c oldRow = oldMap.get(newRow.Id);
            if (oldRow == null) {
                continue;
            }
            String oldStatus = oldRow.FEC_Status__c;
            String newStatus = newRow.FEC_Status__c;

            if (oldStatus == archived) {
                if (
                    assignmentBusinessFieldsChanged(oldRow, newRow, false) ||
                    fieldValuesDiffer(oldStatus, newStatus)
                ) {
                    newRow.addError(MSG_ARCHIVED_LOCKED);
                }
                continue;
            }

            if (oldStatus == active) {
                Boolean businessChanged = assignmentBusinessFieldsChanged(oldRow, newRow, true);
                Boolean statusChanged = fieldValuesDiffer(oldStatus, newStatus);
                Boolean toArchived = newStatus == archived;

                if (!businessChanged && !statusChanged) {
                    continue;
                }
                if (!businessChanged && statusChanged && toArchived) {
                    continue;
                }
                newRow.addError(MSG_ACTIVE_ONLY_ARCHIVE);
            }
        }
    }

    /**
     * @param excludeRunningTimesWhenActiveSiblingTrigger refresh nội dung Running Times khi đổi Status;
     *        true = nhánh Active (bỏ qua Running Times); false = Archived (vẫn giám sát).
     */
    private static Boolean assignmentBusinessFieldsChanged(
        FEC_Case_Assignment__c oldRow,
        FEC_Case_Assignment__c newRow,
        Boolean excludeRunningTimesWhenActiveSiblingTrigger
    ) {
        Map<String, Object> populated = newRow.getPopulatedFieldsAsMap();
        if (populated == null) {
            populated = new Map<String, Object>();
        }
        for (String fieldName : ASSIGNMENT_FIELDS_EXCEPT_STATUS) {
            if (excludeRunningTimesWhenActiveSiblingTrigger && fieldName == RUNNING_TIMES_FIELD) {
                continue;
            }
            Object effectiveNew = populated.containsKey(fieldName)
                ? newRow.get(fieldName)
                : oldRow.get(fieldName);
            if (fieldValuesDiffer(oldRow.get(fieldName), effectiveNew)) {
                return true;
            }
        }
        return false;
    }

    private static Boolean fieldValuesDiffer(Object a, Object b) {
        if (a == null && b == null) {
            return false;
        }
        if (a == null || b == null) {
            return true;
        }
        if (isNumericLike(a) && isNumericLike(b)) {
            return toDecimal(a) != toDecimal(b);
        }
        if ((a instanceof Id) && (b instanceof Id)) {
            return (Id) a != (Id) b;
        }
        return !a.equals(b);
    }

    private static Boolean isNumericLike(Object o) {
        return o instanceof Integer ||
            o instanceof Long ||
            o instanceof Decimal ||
            o instanceof Double;
    }

    private static Decimal toDecimal(Object o) {
        if (o instanceof Decimal) {
            return (Decimal) o;
        }
        if (o instanceof Integer) {
            return Decimal.valueOf((Integer) o);
        }
        if (o instanceof Long) {
            return Decimal.valueOf((Long) o);
        }
        if (o instanceof Double) {
            return Decimal.valueOf((Double) o);
        }
        return Decimal.valueOf(String.valueOf(o));
    }
}

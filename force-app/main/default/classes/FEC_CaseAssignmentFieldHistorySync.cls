/**
 * Multiselect picklist field history does not populate OldValue/NewValue on *History objects.
 * Mirror Time Slots into a tracked text field so Case Assignment History shows both values.
 */
public with sharing class FEC_CaseAssignmentFieldHistorySync {
    private static final String TIME_SLOTS_FIELD = 'FEC_Time_Slots__c';
    private static final String TIME_SLOTS_TRACKED_FIELD = 'FEC_Time_Slots_Tracked__c';

    public static void syncTimeSlotsHistoryMirror(
        List<FEC_Case_Assignment__c> newList,
        Map<Id, FEC_Case_Assignment__c> oldMap
    ) {
        if (newList == null || newList.isEmpty()) {
            return;
        }
        Boolean isInsert = oldMap == null || oldMap.isEmpty();

        for (FEC_Case_Assignment__c row : newList) {
            Map<String, Object> populated = row.getPopulatedFieldsAsMap();
            if (populated == null) {
                populated = new Map<String, Object>();
            }

            FEC_Case_Assignment__c oldRow = isInsert ? null : oldMap.get(row.Id);
            String resolvedSlots = resolveTimeSlots(row, oldRow, populated);

            if (isInsert) {
                row.put(TIME_SLOTS_TRACKED_FIELD, resolvedSlots);
                continue;
            }

            if (oldRow == null) {
                continue;
            }

            Boolean slotsTouched = populated.containsKey(TIME_SLOTS_FIELD);
            Boolean mirrorStale = isMirrorStale(oldRow);
            if (!slotsTouched && !mirrorStale) {
                continue;
            }

            String oldSlots = oldRow.FEC_Time_Slots__c;
            if (!slotsTouched && mirrorStale) {
                row.put(TIME_SLOTS_TRACKED_FIELD, oldSlots);
                continue;
            }

            if (!valuesDiffer(oldSlots, resolvedSlots) && !mirrorStale) {
                continue;
            }

            row.put(TIME_SLOTS_TRACKED_FIELD, resolvedSlots);
        }
    }

    private static String resolveTimeSlots(
        FEC_Case_Assignment__c row,
        FEC_Case_Assignment__c oldRow,
        Map<String, Object> populated
    ) {
        Object effective = populated.containsKey(TIME_SLOTS_FIELD)
            ? row.get(TIME_SLOTS_FIELD)
            : (oldRow != null ? oldRow.get(TIME_SLOTS_FIELD) : null);
        return effective != null ? String.valueOf(effective) : null;
    }

    private static Boolean isMirrorStale(FEC_Case_Assignment__c oldRow) {
        String tracked = (String) oldRow.get(TIME_SLOTS_TRACKED_FIELD);
        return String.isBlank(tracked) && String.isNotBlank(oldRow.FEC_Time_Slots__c);
    }

    private static Boolean valuesDiffer(String left, String right) {
        if (String.isBlank(left) && String.isBlank(right)) {
            return false;
        }
        if (String.isBlank(left) || String.isBlank(right)) {
            return true;
        }
        return left != right;
    }
}

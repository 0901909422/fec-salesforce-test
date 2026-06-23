/**
 * Class Description: Cấp phát sequence number cho FEC_ID_Search__c qua FEC_Case_ID_Counter__c.
 * Dùng SELECT ... FOR UPDATE để lock counter row, tránh trùng ID khi volume lớn.
 */
public without sharing class FEC_CaseIdCounterService {

    private static final Integer MAX_ALLOCATE_RETRY = 3;

    /**
     * Cấp phát dãy số tiếp theo theo prefix.
     * @param countByPrefix Số lượng ID cần cấp phát cho từng prefix
     * @param initNumberByPrefix FEC_Init_Number__c theo prefix (legacy max)
     * @param counterNameByPrefix Counter Key (Name) theo prefix, vd: Interaction|Inbound
     * @return Map prefix -> danh sách số đã cấp phát
     */
    public static Map<String, List<Long>> allocateNextNumbers(
        Map<String, Integer> countByPrefix,
        Map<String, Long> initNumberByPrefix,
        Map<String, String> counterNameByPrefix
    ) {
        if (countByPrefix == null || countByPrefix.isEmpty()) {
            return new Map<String, List<Long>>();
        }

        Integer attempt = 0;
        while (attempt < MAX_ALLOCATE_RETRY) {
            attempt++;
            try {
                return allocateNextNumbersOnce(countByPrefix, initNumberByPrefix, counterNameByPrefix);
            } catch (DmlException ex) {
                if (!isDuplicateCounterException(ex) || attempt >= MAX_ALLOCATE_RETRY) {
                    throw ex;
                }
            }
        }

        return new Map<String, List<Long>>();
    }

    @TestVisible
    private static Map<String, List<Long>> allocateNextNumbersOnce(
        Map<String, Integer> countByPrefix,
        Map<String, Long> initNumberByPrefix,
        Map<String, String> counterNameByPrefix
    ) {
        Map<String, List<Long>> allocatedByPrefix = new Map<String, List<Long>>();
        Set<String> counterKeys = new Set<String>();

        for (String prefix : countByPrefix.keySet()) {
            Integer count = countByPrefix.get(prefix);
            if (count == null || count <= 0) {
                continue;
            }
            String counterKey = counterNameByPrefix != null ? counterNameByPrefix.get(prefix) : null;
            if (String.isNotBlank(counterKey)) {
                counterKeys.add(counterKey);
            }
        }

        if (counterKeys.isEmpty()) {
            return allocatedByPrefix;
        }

        Map<String, FEC_Case_ID_Counter__c> counterByName = new Map<String, FEC_Case_ID_Counter__c>();
        for (FEC_Case_ID_Counter__c counter : [
            SELECT Id, Name, FEC_Prefix__c, FEC_Current_Number__c
            FROM FEC_Case_ID_Counter__c
            WHERE Name IN :counterKeys
            FOR UPDATE
        ]) {
            counterByName.put(counter.Name, counter);
        }

        List<FEC_Case_ID_Counter__c> countersToInsert = new List<FEC_Case_ID_Counter__c>();
        List<FEC_Case_ID_Counter__c> countersToUpdate = new List<FEC_Case_ID_Counter__c>();

        for (String prefix : countByPrefix.keySet()) {
            Integer count = countByPrefix.get(prefix);
            if (count == null || count <= 0) {
                continue;
            }

            String counterKey = counterNameByPrefix != null ? counterNameByPrefix.get(prefix) : null;
            if (String.isBlank(counterKey)) {
                continue;
            }

            FEC_Case_ID_Counter__c counter = counterByName.get(counterKey);
            if (counter == null) {
                Long initNumber = resolveInitNumber(prefix, initNumberByPrefix);
                counter = new FEC_Case_ID_Counter__c(
                    Name = counterKey,
                    FEC_Prefix__c = prefix,
                    FEC_Current_Number__c = initNumber
                );
                countersToInsert.add(counter);
                counterByName.put(counterKey, counter);
            }

            Long currentNumber = counter.FEC_Current_Number__c != null
                ? counter.FEC_Current_Number__c.longValue()
                : 0L;
            currentNumber = applyInitNumberFloor(currentNumber, prefix, initNumberByPrefix);
            List<Long> allocatedNumbers = new List<Long>();

            for (Integer i = 0; i < count; i++) {
                currentNumber++;
                allocatedNumbers.add(currentNumber);
            }

            counter.FEC_Current_Number__c = currentNumber;
            allocatedByPrefix.put(prefix, allocatedNumbers);

            if (counter.Id != null) {
                countersToUpdate.add(counter);
            }
        }

        if (!countersToInsert.isEmpty()) {
            insert countersToInsert;
        }
        if (!countersToUpdate.isEmpty()) {
            update countersToUpdate;
        }

        return allocatedByPrefix;
    }

    private static Long resolveInitNumber(String prefix, Map<String, Long> initNumberByPrefix) {
        if (initNumberByPrefix == null || !initNumberByPrefix.containsKey(prefix)) {
            return 0L;
        }
        Long initNumber = initNumberByPrefix.get(prefix);
        return initNumber != null ? initNumber : 0L;
    }

    private static Long applyInitNumberFloor(
        Long currentNumber,
        String prefix,
        Map<String, Long> initNumberByPrefix
    ) {
        Long initNumber = resolveInitNumber(prefix, initNumberByPrefix);
        if (initNumber > 0 && currentNumber < initNumber) {
            return initNumber;
        }
        return currentNumber;
    }

    private static Boolean isDuplicateCounterException(DmlException ex) {
        for (Integer i = 0; i < ex.getNumDml(); i++) {
            System.StatusCode statusCode = ex.getDmlType(i);
            if (statusCode == System.StatusCode.DUPLICATE_VALUE
                || statusCode == System.StatusCode.FIELD_INTEGRITY_EXCEPTION) {
                return true;
            }
        }
        return false;
    }
}

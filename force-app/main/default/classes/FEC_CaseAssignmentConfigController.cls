public with sharing class FEC_CaseAssignmentConfigController {
    public class OptionItem {
        @AuraEnabled public String label;
        @AuraEnabled public String value;

        public OptionItem(String optionLabel, String optionValue) {
            label = optionLabel;
            value = optionValue;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<OptionItem> getActiveCaseQueues() {
        Map<Id, String> queueNameById = new Map<Id, String>();
        for (QueueSobject queueMapping : [
            SELECT QueueId, Queue.Name
            FROM QueueSobject
            WHERE SobjectType = 'Case'
        ]) {
            if (
                queueMapping.QueueId != null &&
                String.isNotBlank(queueMapping.Queue.Name)
            ) {
                queueNameById.put(queueMapping.QueueId, queueMapping.Queue.Name);
            }
        }

        List<String> sortedNames = new List<String>();
        sortedNames.addAll(queueNameById.values());
        sortedNames.sort();

        List<OptionItem> result = new List<OptionItem>();
        for (String queueName : sortedNames) {
            result.add(new OptionItem(queueName, queueName));
        }
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<OptionItem> getRoleOptions(List<String> queueNames) {
        if (queueNames == null || queueNames.isEmpty()) {
            return new List<OptionItem>();
        }

        Set<String> normalizedQueueNames = new Set<String>();
        for (String queueName : queueNames) {
            if (String.isNotBlank(queueName)) {
                normalizedQueueNames.add(queueName.trim());
            }
        }
        if (normalizedQueueNames.isEmpty()) {
            return new List<OptionItem>();
        }

        Set<Id> queueIdsFromCaseUi = resolveCaseQueueIds(normalizedQueueNames);
        Set<Id> resolvedQueueIds = FEC_CaseAssignmentQueueRoleResolver.ensureQueueIds(
            normalizedQueueNames,
            queueIdsFromCaseUi
        );
        return FEC_CaseAssignmentQueueRoleResolver.buildPicklist(resolvedQueueIds);
    }

    private static Set<Id> resolveCaseQueueIds(Set<String> normalizedQueueNames) {
        Set<Id> caseQueueIds = new Set<Id>();
        for (QueueSobject qs : [
            SELECT QueueId, Queue.Name
            FROM QueueSobject
            WHERE SobjectType = 'Case' AND QueueId != NULL
        ]) {
            if (
                qs.Queue != null &&
                String.isNotBlank(qs.Queue.Name) &&
                normalizedQueueNames.contains(qs.Queue.Name.trim())
            ) {
                caseQueueIds.add(qs.QueueId);
            }
        }
        return caseQueueIds;
    }

    @AuraEnabled(cacheable=true)
    public static List<OptionItem> getBusinessHourOptions() {
        List<OptionItem> options = new List<OptionItem>();
        for (BusinessHours item : [
            SELECT Id, Name
            FROM BusinessHours
            ORDER BY IsDefault DESC, Name ASC
        ]) {
            options.add(new OptionItem(item.Name, item.Id));
        }
        return options;
    }
}
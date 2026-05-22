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
        Set<String> queueDevNames = new Set<String>();
        for (FEC_Team_Queue__c teamQueueRow : [
            SELECT FEC_Queue_Name__c
            FROM FEC_Team_Queue__c
            WHERE FEC_Queue_Name__c != NULL
        ]) {
            queueDevNames.add(teamQueueRow.FEC_Queue_Name__c);
        }

        Map<String, String> labelByDevName = new Map<String, String>();
        for (Group queueGroup : [
            SELECT Name, DeveloperName
            FROM Group
            WHERE Type = 'Queue' AND DeveloperName IN :queueDevNames
        ]) {
            labelByDevName.put(queueGroup.DeveloperName, queueGroup.Name);
        }

        Set<String> seenLabels = new Set<String>();
        List<String> sortedLabels = new List<String>();
        for (String devName : queueDevNames) {
            String queueLabel = labelByDevName.get(devName);
            if (String.isBlank(queueLabel) || seenLabels.contains(queueLabel)) {
                continue;
            }
            seenLabels.add(queueLabel);
            sortedLabels.add(queueLabel);
        }
        sortedLabels.sort();

        List<OptionItem> result = new List<OptionItem>();
        for (String queueName : sortedLabels) {
            result.add(new OptionItem(queueName, queueName));
        }
        return result;
    }

    @AuraEnabled
    public static Boolean isCaseAssignmentNameTaken(
        String assignmentName,
        Id excludeRecordId
    ) {
        if (String.isBlank(assignmentName)) {
            return false;
        }
        String trimmedName = assignmentName.trim();
        List<FEC_Case_Assignment__c> matches = [
            SELECT Id
            FROM FEC_Case_Assignment__c
            WHERE Name = :trimmedName
            LIMIT 1
        ];
        if (matches.isEmpty()) {
            return false;
        }
        return excludeRecordId == null || matches[0].Id != excludeRecordId;
    }

    @AuraEnabled
    public static List<String> findQueuesMissingRoleCoverage(
        List<String> queueNames,
        List<String> assignedRoleNames
    ) {
        List<String> missingQueues = new List<String>();
        if (queueNames == null || queueNames.isEmpty()) {
            return missingQueues;
        }

        Set<String> assignedRoles = new Set<String>();
        if (assignedRoleNames != null) {
            for (String roleName : assignedRoleNames) {
                if (String.isNotBlank(roleName)) {
                    assignedRoles.add(roleName.trim());
                }
            }
        }

        for (String queueName : queueNames) {
            if (String.isBlank(queueName)) {
                continue;
            }
            String normalizedQueueName = queueName.trim();
            Set<String> singleQueue = new Set<String>{ normalizedQueueName };
            Set<Id> queueIdsFromCaseUi = resolveCaseQueueIds(singleQueue);
            Set<Id> resolvedQueueIds = FEC_CaseAssignmentQueueRoleResolver.ensureQueueIds(
                singleQueue,
                queueIdsFromCaseUi
            );
            List<OptionItem> queueRoleOptions =
                FEC_CaseAssignmentQueueRoleResolver.buildPicklist(resolvedQueueIds);
            if (queueRoleOptions.isEmpty()) {
                continue;
            }

            Boolean hasMatchingRole = false;
            for (OptionItem roleOption : queueRoleOptions) {
                if (assignedRoles.contains(roleOption.value)) {
                    hasMatchingRole = true;
                    break;
                }
            }
            if (!hasMatchingRole) {
                missingQueues.add(normalizedQueueName);
            }
        }

        missingQueues.sort();
        return missingQueues;
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
// Check picklist values của Status field - tìm CardOps
Schema.DescribeFieldResult f = Schema.SObjectType.Case.fields.getMap().get('Status').getDescribe();
for (Schema.PicklistEntry e : f.getPicklistValues()) {
    if (e.getValue().containsIgnoreCase('Card') || e.getLabel().containsIgnoreCase('Card')) {
        System.debug('Value: ' + e.getValue() + ' | Label: ' + e.getLabel());
    }
}

// Check case S-0450
List<Case> cases = [SELECT Id, CaseNumber, Status FROM Case WHERE FEC_ID_Search__c = 'S-0450' LIMIT 1];
if (!cases.isEmpty()) System.debug('S-0450 Status API value: ' + cases[0].Status);

// Check assignment type của manual assignments
String caseNumber = 'S-2660';

List<Case> cases = [SELECT Id, CaseNumber FROM Case WHERE CaseNumber = :caseNumber LIMIT 1];

if (cases.isEmpty()) {
    System.debug('Case not found');
} else {
    Case c = cases[0];
    System.debug('Case: ' + c.CaseNumber + ' (' + c.Id + ')');
    System.debug('');
    
    List<FEC_Assignment__c> assignments = [
        SELECT Id, Name, FEC_Assignment_Type__c, FEC_Manual__c, 
               FEC_Assignment_Status__c, CreatedDate
        FROM FEC_Assignment__c
        WHERE FEC_Case__c = :c.Id
        ORDER BY CreatedDate DESC
    ];
    
    System.debug('Total assignments: ' + assignments.size());
    System.debug('');
    
    for (FEC_Assignment__c a : assignments) {
        System.debug('Assignment: ' + a.Name);
        System.debug('  Type: ' + a.FEC_Assignment_Type__c);
        System.debug('  Manual: ' + a.FEC_Manual__c);
        System.debug('  Status: ' + a.FEC_Assignment_Status__c);
        System.debug('  Created: ' + a.CreatedDate);
        System.debug('');
    }
}

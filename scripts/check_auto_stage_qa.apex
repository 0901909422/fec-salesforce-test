// tungnm37: check case RL06.03 trên QA - tại sao không chuyển stage
// Thay bằng case number thực tế trên QA
String caseUrl = '5008500000HyheeAAB'; // từ URL trong comment

List<Case> cases = [
    SELECT Id, CaseNumber, FEC_Current_Case_Stage__c, FEC_Current_Case_Stage__r.Name,
           FEC_Product_Type__c, FEC_Category__c, FEC_SubCategory__c, FEC_SubCode__c,
           FEC_Is_Submited__c, Status
    FROM Case WHERE Id = :caseUrl LIMIT 1
];
if (cases.isEmpty()) { System.debug('Case not found'); return; }
Case c = cases[0];
System.debug('Case: ' + c.CaseNumber + ' | Stage: ' + c.FEC_Current_Case_Stage__r?.Name + ' | Submitted: ' + c.FEC_Is_Submited__c);

// Check NOC
List<FEC_Nature_of_Case__c> nocs = [
    SELECT Id, Name FROM FEC_Nature_of_Case__c
    WHERE FEC_Product_Type__c = :c.FEC_Product_Type__c
      AND FEC_Category__c = :c.FEC_Category__c
      AND FEC_Sub_Category__c = :c.FEC_SubCategory__c
      AND FEC_Sub_Code__c = :c.FEC_SubCode__c
    LIMIT 5
];
System.debug('NOCs found: ' + nocs.size());
for (FEC_Nature_of_Case__c n : nocs) System.debug('  NOC: ' + n.Id + ' | ' + n.Name);

if (!nocs.isEmpty()) {
    Set<Id> nocIds = new Map<Id, FEC_Nature_of_Case__c>(nocs).keySet();
    
    // Check stages
    List<FEC_Case_Stage__c> stages = [
        SELECT Id, Name, FEC_Default_Stage__c, FEC_Active__c
        FROM FEC_Case_Stage__c
        WHERE FEC_Nature_of_Cases__c IN :nocIds
        ORDER BY Name ASC
    ];
    System.debug('Stages for NOC: ' + stages.size());
    for (FEC_Case_Stage__c s : stages) {
        System.debug('  Stage: ' + s.Name + ' | Default=' + s.FEC_Default_Stage__c + ' | Active=' + s.FEC_Active__c + ' | Id=' + s.Id);
    }
    
    // Check non-default stages
    List<FEC_Case_Stage__c> nextStages = [
        SELECT Id, Name FROM FEC_Case_Stage__c
        WHERE FEC_Nature_of_Cases__c IN :nocIds
          AND FEC_Default_Stage__c = false
          AND FEC_Active__c = true
        ORDER BY Name ASC LIMIT 1
    ];
    System.debug('Next stage (non-default): ' + (nextStages.isEmpty() ? 'NOT FOUND' : nextStages[0].Name + ' | Id=' + nextStages[0].Id));
    System.debug('Current stage same as next: ' + (!nextStages.isEmpty() && nextStages[0].Id == c.FEC_Current_Case_Stage__c));
}

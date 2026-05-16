// tungnm37: check stage hiện tại và next stage theo NOC cho case RL06.03
String caseId = '5008500000HyheeAAB'; // case trên QA

List<Case> cases = [
    SELECT Id, CaseNumber, FEC_Current_Case_Stage__c, FEC_Current_Case_Stage__r.Name,
           FEC_Product_Type__c, FEC_Category__c, FEC_SubCategory__c, FEC_SubCode__c
    FROM Case WHERE Id = :caseId LIMIT 1
];
if (cases.isEmpty()) { System.debug('Case not found'); return; }
Case c = cases[0];
System.debug('Case: ' + c.CaseNumber + ' | Current Stage: ' + c.FEC_Current_Case_Stage__r?.Name);

// Tìm NOC
List<FEC_Nature_of_Case__c> nocs = [
    SELECT Id, Name FROM FEC_Nature_of_Case__c
    WHERE FEC_Product_Type__c = :c.FEC_Product_Type__c
      AND FEC_Category__c = :c.FEC_Category__c
      AND FEC_Sub_Category__c = :c.FEC_SubCategory__c
      AND FEC_Sub_Code__c = :c.FEC_SubCode__c
    LIMIT 5
];
System.debug('NOCs: ' + nocs.size());
if (nocs.isEmpty()) { System.debug('No NOC found'); return; }

Set<Id> nocIds = new Map<Id, FEC_Nature_of_Case__c>(nocs).keySet();

// Lấy tất cả stage theo NOC sort theo Name
List<FEC_Case_Stage__c> allStages = [
    SELECT Id, Name, FEC_Default_Stage__c, FEC_Active__c
    FROM FEC_Case_Stage__c
    WHERE FEC_Nature_of_Cases__c IN :nocIds
      AND FEC_Active__c = true
    ORDER BY Name ASC
];
System.debug('All stages for NOC (sorted by Name):');
Integer currentIndex = -1;
for (Integer i = 0; i < allStages.size(); i++) {
    FEC_Case_Stage__c s = allStages[i];
    Boolean isCurrent = s.Id == c.FEC_Current_Case_Stage__c;
    if (isCurrent) currentIndex = i;
    System.debug('  [' + i + '] ' + s.Name + (isCurrent ? ' <<< CURRENT' : '') + ' | Default=' + s.FEC_Default_Stage__c);
}

System.debug('Current index: ' + currentIndex);
if (currentIndex >= 0 && currentIndex + 1 < allStages.size()) {
    System.debug('Next stage: ' + allStages[currentIndex + 1].Name + ' | Id=' + allStages[currentIndex + 1].Id);
} else {
    System.debug('No next stage available');
}

// tungnm37: tìm case gần nhất có NOC để test hold case
List<Case> cases = [
    SELECT CaseNumber, FEC_Product_Type__c, FEC_Category__c, FEC_SubCategory__c, FEC_SubCode__c, FEC_Is_Submited__c
    FROM Case
    WHERE FEC_Product_Type__c != null
    ORDER BY CreatedDate DESC
    LIMIT 5
];
for (Case c : cases) {
    System.debug('Case: ' + c.CaseNumber + ' | Submitted: ' + c.FEC_Is_Submited__c + ' | PT: ' + c.FEC_Product_Type__c);
}

// Check tổng số Hold Case Config
Integer total = [SELECT COUNT() FROM FEC_Hold_Case_Config__c];
System.debug('Total Hold Case Configs: ' + total);

// Check Manual configs
List<FEC_Hold_Case_Config__c> manuals = [
    SELECT Id, FEC_NFU_Code__c, Hold_Case_Type__c, FEC_Nature_of_Cases__c, FEC_Active__c
    FROM FEC_Hold_Case_Config__c
    WHERE Hold_Case_Type__c = 'Manual' AND FEC_Active__c = true
    LIMIT 10
];
System.debug('Manual Active configs: ' + manuals.size());
for (FEC_Hold_Case_Config__c m : manuals) {
    System.debug('  NOC: ' + m.FEC_Nature_of_Cases__c + ' | NFU: ' + m.FEC_NFU_Code__c);
}

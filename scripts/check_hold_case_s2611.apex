// Check Hold Case Config cho bộ NOC của S-2611 (Loan/Feedback/FL05/FL05.03)
// Case S-2611 chưa save NOC → dùng params từ UI

// Tìm NOC khớp với Loan/Feedback/FL05/FL05.03
List<FEC_Nature_of_Case__c> nocs = [
    SELECT Id, FEC_Product_Type__r.Name, FEC_Category__r.Name,
           FEC_Sub_Category__r.Name, FEC_Sub_Code__r.Name
    FROM FEC_Nature_of_Case__c
    WHERE FEC_Sub_Code__r.FEC_Code__c = 'FL05.03'
    LIMIT 5
];
System.debug('NOCs with FL05.03: ' + nocs.size());
for (FEC_Nature_of_Case__c n : nocs) {
    System.debug('  NOC: ' + n.Id + ' | PT=' + n.FEC_Product_Type__r?.Name + ' | Cat=' + n.FEC_Category__r?.Name);
}

// Check Hold Case Config cho NOC a06Az0000KnEhimIAN (từ Case Stage)
List<FEC_Hold_Case_Config__c> configs = [
    SELECT Id, Name, Hold_Case_Type__c, FEC_Active__c, FEC_NFU_Code__c,
           FEC_Case_Stage__c, FEC_Nature_of_Cases__c
    FROM FEC_Hold_Case_Config__c
    WHERE FEC_Nature_of_Cases__c = 'a06Az0000KnEhimIAN'
];
System.debug('Hold Case Configs for NOC a06Az0000KnEhimIAN: ' + configs.size());
for (FEC_Hold_Case_Config__c c : configs) {
    System.debug('  ' + c.Name + ' | Type=' + c.Hold_Case_Type__c + ' | Active=' + c.FEC_Active__c + ' | NFU=' + c.FEC_NFU_Code__c + ' | Stage=' + c.FEC_Case_Stage__c);
}

// Check FEC_SubProcessService logic - getSubProcesses với NOC này
// showHoldCase check: Hold_Case_Type__c = 'Manual' AND FEC_Active__c = true
List<FEC_Hold_Case_Config__c> manualConfigs = [
    SELECT Id FROM FEC_Hold_Case_Config__c
    WHERE FEC_Nature_of_Cases__c = 'a06Az0000KnEhimIAN'
      AND Hold_Case_Type__c = 'Manual'
      AND FEC_Active__c = true
    LIMIT 1
];
System.debug('showHoldCase = ' + !manualConfigs.isEmpty());

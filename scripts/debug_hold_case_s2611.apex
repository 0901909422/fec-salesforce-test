// Debug getNFUReasons cho case S-2611
String caseId = '500Az00000PyuFV1AZ';

// 1. Case info
List<Case> cases = [
    SELECT Id, FEC_ID_Search__c, FEC_Product_Type__c, FEC_Category__c,
           FEC_SubCategory__c, FEC_SubCode__c, FEC_Current_Case_Stage__c,
           FEC_Current_Case_Stage__r.Name, FEC_Current_Case_Stage__r.FEC_Nature_of_Cases__c
    FROM Case WHERE Id = :caseId LIMIT 1
];
if (cases.isEmpty()) { System.debug('Case not found'); return; }
Case c = cases[0];
System.debug('Case: ' + c.FEC_ID_Search__c);
System.debug('PT=' + c.FEC_Product_Type__c + ' Cat=' + c.FEC_Category__c + ' SubCat=' + c.FEC_SubCategory__c + ' SubCode=' + c.FEC_SubCode__c);
System.debug('CurrentStage: ' + c.FEC_Current_Case_Stage__r?.Name);
System.debug('Stage.NOC: ' + c.FEC_Current_Case_Stage__r?.FEC_Nature_of_Cases__c);

// 2. NOC từ Case Stage
Id nocFromStage = c.FEC_Current_Case_Stage__r?.FEC_Nature_of_Cases__c;
System.debug('NOC from Stage: ' + nocFromStage);

// 3. Hold Case Config cho NOC này
if (nocFromStage != null) {
    List<FEC_Hold_Case_Config__c> configs = [
        SELECT Id, Name, Hold_Case_Type__c, FEC_Active__c, FEC_NFU_Code__c, FEC_Case_Stage__c
        FROM FEC_Hold_Case_Config__c
        WHERE FEC_Nature_of_Cases__c = :nocFromStage
    ];
    System.debug('Hold Case Configs: ' + configs.size());
    for (FEC_Hold_Case_Config__c cfg : configs) {
        System.debug('  ' + cfg.Name + ' | Type=' + cfg.Hold_Case_Type__c + ' | Active=' + cfg.FEC_Active__c + ' | NFU=' + cfg.FEC_NFU_Code__c);
    }
    
    List<FEC_Hold_Case_Config__c> manualConfigs = [
        SELECT Id FROM FEC_Hold_Case_Config__c
        WHERE FEC_Nature_of_Cases__c = :nocFromStage
          AND Hold_Case_Type__c = 'Manual'
          AND FEC_Active__c = true
    ];
    System.debug('Manual Active Configs: ' + manualConfigs.size());
}

// Debug: check NFU Reasons cho Case S-2579 (case đang test)
String caseId = '500Az00000Py9I9IAJ'; // S-2579 - có đủ NOC fields

// Lấy case mới nhất (chỉ để xem)
List<Case> latest = [
    SELECT Id, FEC_ID_Search__c, FEC_Product_Type__c, FEC_Category__c,
           FEC_SubCategory__c, FEC_SubCode__c
    FROM Case ORDER BY CreatedDate DESC LIMIT 5
];
System.debug('=== RECENT CASES ===');
for (Case c : latest) {
    System.debug(c.FEC_ID_Search__c + ' | PT=' + c.FEC_Product_Type__c + ' | Cat=' + c.FEC_Category__c + ' | SubCat=' + c.FEC_SubCategory__c + ' | SubCode=' + c.FEC_SubCode__c);
}

if (!latest.isEmpty()) System.debug('Latest case: ' + latest[0].FEC_ID_Search__c);

// Simulate getNFUReasons với S-2579
List<Case> cases = [
    SELECT FEC_Product_Type__c, FEC_Category__c, FEC_SubCategory__c, FEC_SubCode__c
    FROM Case WHERE Id = :caseId LIMIT 1
];
if (cases.isEmpty()) { System.debug('Case not found'); return; }
Case c = cases[0];

List<FEC_Nature_of_Case__c> nocs = [
    SELECT Id FROM FEC_Nature_of_Case__c
    WHERE FEC_Product_Type__c = :c.FEC_Product_Type__c
      AND FEC_Category__c = :c.FEC_Category__c
      AND FEC_Sub_Category__c = :c.FEC_SubCategory__c
      AND FEC_Sub_Code__c = :c.FEC_SubCode__c
    LIMIT 1
];
System.debug('NOCs found: ' + nocs.size());
if (nocs.isEmpty()) { System.debug('NO NOC FOUND'); return; }

List<FEC_Hold_Case_Config__c> configs = [
    SELECT FEC_NFU_Code__c, FEC_Active__c, Hold_Case_Type__c
    FROM FEC_Hold_Case_Config__c
    WHERE FEC_Nature_of_Cases__c = :nocs[0].Id
      AND FEC_Active__c = true
];
System.debug('Hold Case Configs: ' + configs.size());
for (FEC_Hold_Case_Config__c cfg : configs) {
    System.debug('  NFU_Code=' + cfg.FEC_NFU_Code__c + ' | Type=' + cfg.Hold_Case_Type__c + ' | Active=' + cfg.FEC_Active__c);
}

if (configs.isEmpty()) { System.debug('NO CONFIG FOUND'); return; }

Set<String> nfuCodes = new Set<String>();
for (FEC_Hold_Case_Config__c cfg : configs) {
    if (String.isNotBlank(cfg.FEC_NFU_Code__c)) {
        for (String code : cfg.FEC_NFU_Code__c.split(',')) {
            nfuCodes.add(code.trim());
        }
    }
}
System.debug('NFU Codes: ' + nfuCodes);

List<FEC_Hold_Case__c> holdCases = [
    SELECT FEC_NFU_Code__c, FEC_NFU_Reason_VN__c, FEC_NFU_Duration__c
    FROM FEC_Hold_Case__c WHERE FEC_NFU_Code__c IN :nfuCodes
];
System.debug('Hold Cases (NFU library): ' + holdCases.size());
for (FEC_Hold_Case__c hc : holdCases) {
    System.debug('  Code=' + hc.FEC_NFU_Code__c + ' | Reason=' + hc.FEC_NFU_Reason_VN__c + ' | Duration=' + hc.FEC_NFU_Duration__c);
}

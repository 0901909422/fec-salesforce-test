// Tạo Hold Case Config cho NOC của S-2579 để test
// Case S-2579: PT=a0AAz000008lPCyMAM, Cat=a02Az00001RRYydIAH, SubCat=a0CAz00002gu2HAMAY, SubCode=a0DAz000009OpalMAC

// 1. Tìm NOC khớp
List<FEC_Nature_of_Case__c> nocs = [
    SELECT Id FROM FEC_Nature_of_Case__c
    WHERE FEC_Product_Type__c = 'a0AAz000008lPCyMAM'
      AND FEC_Category__c = 'a02Az00001RRYydIAH'
      AND FEC_Sub_Category__c = 'a0CAz00002gu2HAMAY'
      AND FEC_Sub_Code__c = 'a0DAz000009OpalMAC'
    LIMIT 1
];
System.debug('NOC found: ' + nocs.size());
if (nocs.isEmpty()) { System.debug('NOC not found - check fields'); return; }

// 2. Check NFU Code có tồn tại không
List<FEC_Hold_Case__c> nfuCodes = [
    SELECT Id, FEC_NFU_Code__c, FEC_NFU_Reason_VN__c, FEC_NFU_Duration__c
    FROM FEC_Hold_Case__c LIMIT 3
];
System.debug('Available NFU Codes: ' + nfuCodes.size());
for (FEC_Hold_Case__c n : nfuCodes) {
    System.debug('  ' + n.FEC_NFU_Code__c + ' | ' + n.FEC_NFU_Reason_VN__c);
}

if (nfuCodes.isEmpty()) { System.debug('No NFU Codes found'); return; }

// 3. Tạo Hold Case Config Manual cho NOC này
FEC_Hold_Case_Config__c config = new FEC_Hold_Case_Config__c(
    FEC_Nature_of_Cases__c = nocs[0].Id,
    Hold_Case_Type__c = 'Manual',
    FEC_NFU_Code__c = nfuCodes[0].FEC_NFU_Code__c,
    FEC_Active__c = true
);
insert config;
System.debug('Created Hold Case Config: ' + config.Id + ' for NOC: ' + nocs[0].Id);
System.debug('NFU Code: ' + nfuCodes[0].FEC_NFU_Code__c);

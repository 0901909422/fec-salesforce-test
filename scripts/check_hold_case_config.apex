// tungnm37: check FEC_Hold_Case__c record cho CS_NFU_COMPLAINT30
List<FEC_Hold_Case__c> hcs = [
    SELECT Id, Name, FEC_NFU_Code__c, FEC_NFU_Reason_VN__c, FEC_NFU_Duration__c
    FROM FEC_Hold_Case__c
    WHERE FEC_NFU_Code__c = 'CS_NFU_COMPLAINT30'
    LIMIT 5
];
System.debug('FEC_Hold_Case__c records for CS_NFU_COMPLAINT30: ' + hcs.size());
for (FEC_Hold_Case__c h : hcs) {
    System.debug('  Id=' + h.Id + ' | Code=' + h.FEC_NFU_Code__c + ' | ReasonVN=' + h.FEC_NFU_Reason_VN__c + ' | Duration=' + h.FEC_NFU_Duration__c);
}

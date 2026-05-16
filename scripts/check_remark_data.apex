// Check remark data cho case gần nhất
List<FEC_Case_Remarks__c> remarks = [
    SELECT Id, FEC_Case_Remarks__c, Remark_Type__c, FEC_User__c, FEC_Stage_Name__c, CreatedDate, FEC_Case__r.FEC_Actual_Nature_of_Case__r.FEC_Business_Process__r.FEC_Code__c
    FROM FEC_Case_Remarks__c
    WHERE FEC_Case__r.FEC_Actual_Nature_of_Case__r.FEC_Business_Process__r.FEC_Code__c LIKE 'GSR%'
    ORDER BY CreatedDate DESC
    LIMIT 10
];
for (FEC_Case_Remarks__c r : remarks) {
    System.debug('id=' + r.Id + ' type=' + r.Remark_Type__c + ' remark=' + r.FEC_Case_Remarks__c + ' user=' + r.FEC_User__c);
}

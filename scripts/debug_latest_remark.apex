// Check case có bao nhiêu remark type Case
String caseId = '500Az00000OLboMIAT'; // case vừa submit

List<FEC_Case_Remarks__c> allRemarks = [
    SELECT Id, Remark_Type__c, FEC_User__c, FEC_Assignment__c, FEC_Case_Remarks__c, CreatedDate
    FROM FEC_Case_Remarks__c WHERE FEC_Case__c = :caseId ORDER BY CreatedDate DESC
];
System.debug('Total remarks for case = ' + allRemarks.size());
for (FEC_Case_Remarks__c r : allRemarks) {
    System.debug('  Remark Id=' + r.Id + ' Type=' + r.Remark_Type__c + ' User=' + r.FEC_User__c + ' Assignment=' + r.FEC_Assignment__c + ' Content=' + r.FEC_Case_Remarks__c + ' Created=' + r.CreatedDate);
}

// Check latest non-Assignment remark
List<FEC_Case_Remarks__c> latestRemarks = [
    SELECT Id, FEC_Case_Remarks__c, FEC_User__c, Remark_Type__c
    FROM FEC_Case_Remarks__c
    WHERE FEC_Case__c = :caseId AND Remark_Type__c != 'Assignment'
    ORDER BY CreatedDate DESC LIMIT 1
];
System.debug('Latest non-Assignment remark count = ' + latestRemarks.size());
if (!latestRemarks.isEmpty()) {
    System.debug('  Id=' + latestRemarks[0].Id + ' Type=' + latestRemarks[0].Remark_Type__c + ' User=' + latestRemarks[0].FEC_User__c);
}

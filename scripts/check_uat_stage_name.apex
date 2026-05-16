// Check UAT: FEC_Stage_Name__c đang lưu Id hay Name
List<Case> cases = [
    SELECT Id, FEC_ID_Search__c, FEC_Stage_Name__c,
           FEC_Current_Case_Stage__c,
           FEC_Current_Case_Stage__r.Name
    FROM Case
    WHERE FEC_ID_Search__c IN ('S-4352', 'S-4351', 'S-4350')
    ORDER BY FEC_ID_Search__c DESC
];
for (Case c : cases) {
    Boolean isId = c.FEC_Stage_Name__c != null && c.FEC_Stage_Name__c.length() == 18;
    System.debug(c.FEC_ID_Search__c
        + ' | FEC_Stage_Name__c=' + c.FEC_Stage_Name__c
        + ' | CurrentStage.Name=' + c.FEC_Current_Case_Stage__r?.Name
        + ' | isStoringId=' + isId);
}

// Check cases có Stage Name dạng text (không phải Id)
List<Case> recentWithName = [
    SELECT FEC_ID_Search__c, FEC_Stage_Name__c
    FROM Case
    WHERE FEC_Stage_Name__c != null
    ORDER BY CreatedDate DESC LIMIT 5
];
System.debug('=== Recent Cases FEC_Stage_Name__c ===');
for (Case c : recentWithName) {
    System.debug(c.FEC_ID_Search__c + ' | ' + c.FEC_Stage_Name__c);
}

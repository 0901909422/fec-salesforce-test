// Thêm CO vào FEC_User_Group__c của Stage Screen thuộc GSR/COF
List<FEC_Stage_Screen__c> screens = [
    SELECT Id, FEC_User_Group__c
    FROM FEC_Stage_Screen__c
    WHERE FEC_Active__c = true
    AND (FEC_Case_Stage__r.FEC_Nature_of_Cases__r.FEC_Business_Process__r.FEC_Code__c LIKE 'GSR%'
    OR FEC_Case_Stage__r.FEC_Nature_of_Cases__r.FEC_Business_Process__r.FEC_Code__c LIKE 'COF%')
];
System.debug('Stage Screens to check: ' + screens.size());
List<FEC_Stage_Screen__c> toUpdate = new List<FEC_Stage_Screen__c>();
for (FEC_Stage_Screen__c sc : screens) {
    if (String.isBlank(sc.FEC_User_Group__c) || !sc.FEC_User_Group__c.contains('CO')) {
        sc.FEC_User_Group__c = String.isBlank(sc.FEC_User_Group__c) ? 'CO' : sc.FEC_User_Group__c + ';CO';
        toUpdate.add(sc);
    }
}
System.debug('Stage Screens to update: ' + toUpdate.size());
if (!toUpdate.isEmpty()) {
    update toUpdate;
    System.debug('Updated ' + toUpdate.size() + ' Stage Screen records');
}

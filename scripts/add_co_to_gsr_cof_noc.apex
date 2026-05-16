// Thêm CO vào FEC_User_Group__c của tất cả NOC GSR/COF
// Chạy: sf apex run --file scripts/add_co_to_gsr_cof_noc.apex

List<FEC_Nature_of_Case__c> nocs = [
    SELECT Id, FEC_User_Group__c, FEC_Business_Process__r.FEC_Code__c
    FROM FEC_Nature_of_Case__c
    WHERE (FEC_Business_Process__r.FEC_Code__c LIKE 'GSR%'
        OR FEC_Business_Process__r.FEC_Code__c LIKE 'COF%')
];

System.debug('NOC count to update=' + nocs.size());

List<FEC_Nature_of_Case__c> toUpdate = new List<FEC_Nature_of_Case__c>();
for (FEC_Nature_of_Case__c n : nocs) {
    String ug = n.FEC_User_Group__c;
    if (String.isBlank(ug) || !ug.contains('CO')) {
        // Thêm CO vào multi-select picklist
        n.FEC_User_Group__c = String.isBlank(ug) ? 'CO' : ug + ';CO';
        toUpdate.add(n);
        System.debug('Will update NOC id=' + n.Id + ' code=' + n.FEC_Business_Process__r.FEC_Code__c + ' newGroup=' + n.FEC_User_Group__c);
    } else {
        System.debug('Already has CO: NOC id=' + n.Id);
    }
}

if (!toUpdate.isEmpty()) {
    update toUpdate;
    System.debug('Updated ' + toUpdate.size() + ' NOC records');
} else {
    System.debug('Nothing to update');
}

// Check Stage Screen cho CO
List<FEC_Stage_Screen__c> screens = [
    SELECT Id, FEC_User_Group__c, FEC_Case_Stage__r.Name, FEC_Action_Button__r.Name
    FROM FEC_Stage_Screen__c
    WHERE FEC_Active__c = true
    AND FEC_Action_Button__c != null
    AND FEC_Case_Stage__r.FEC_Nature_of_Cases__r.FEC_Business_Process__r.FEC_Code__c LIKE 'GSR%'
    LIMIT 20
];
System.debug('Stage Screens for GSR count=' + screens.size());
for (FEC_Stage_Screen__c sc : screens) {
    System.debug('Screen stage=' + sc.FEC_Case_Stage__r.Name + ' action=' + sc.FEC_Action_Button__r.Name + ' userGroup=' + sc.FEC_User_Group__c);
}

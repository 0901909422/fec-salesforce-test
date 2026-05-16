// Check Stage Screen có CO (CardOps) không cho NOC GSR
// Chạy: sf apex run --file scripts/check_co_stage_screen.apex

// 1. Lấy NOC GSR
List<FEC_Nature_of_Case__c> nocs = [
    SELECT Id, FEC_Business_Process__r.FEC_Code__c, FEC_User_Group__c
    FROM FEC_Nature_of_Case__c
    WHERE FEC_Business_Process__r.FEC_Code__c LIKE 'GSR%'
    LIMIT 5
];
System.debug('NOC GSR count=' + nocs.size());
for (FEC_Nature_of_Case__c n : nocs) {
    System.debug('NOC id=' + n.Id + ' code=' + n.FEC_Business_Process__r.FEC_Code__c + ' userGroup=' + n.FEC_User_Group__c);
}

// 2. Lấy Stage của NOC GSR
if (!nocs.isEmpty()) {
    List<FEC_Case_Stage__c> stages = [
        SELECT Id, Name, FEC_User_Group__c, FEC_Default_Stage__c
        FROM FEC_Case_Stage__c
        WHERE FEC_Nature_of_Cases__c = :nocs[0].Id
        AND FEC_Active__c = true
    ];
    System.debug('Stages count=' + stages.size());
    for (FEC_Case_Stage__c s : stages) {
        System.debug('Stage id=' + s.Id + ' name=' + s.Name + ' userGroup=' + s.FEC_User_Group__c + ' default=' + s.FEC_Default_Stage__c);
        
        // 3. Lấy Stage Screen của Stage này
        List<FEC_Stage_Screen__c> screens = [
            SELECT Id, FEC_User_Group__c, FEC_Action_Button__r.Name, FEC_Action_Button__r.FEC_Type__c, FEC_Action_Button__r.FEC_Code__c
            FROM FEC_Stage_Screen__c
            WHERE FEC_Case_Stage__c = :s.Id
            AND FEC_Active__c = true
            AND FEC_Action_Button__c != null
        ];
        System.debug('  Stage Screens count=' + screens.size());
        for (FEC_Stage_Screen__c sc : screens) {
            System.debug('  Screen userGroup=' + sc.FEC_User_Group__c + ' action=' + sc.FEC_Action_Button__r.Name + ' type=' + sc.FEC_Action_Button__r.FEC_Type__c);
        }
    }
}

// 4. Check user hiện tại
User u = [SELECT Id, FEC_User_Group__c, UserRole.Name FROM User WHERE Id = :UserInfo.getUserId()];
System.debug('Current user FEC_User_Group__c=' + u.FEC_User_Group__c + ' UserRole=' + u.UserRole?.Name);

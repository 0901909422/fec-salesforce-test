// Tạo Stage 1 và Stage 2 cho NOC-2068 (COF - CC01.01-Nhân viên yêu cầu tiền phí)
// Lấy Action Button "Route to" để dùng cho Stage Screen

FEC_Nature_of_Case__c noc2068 = [SELECT Id, Name FROM FEC_Nature_of_Case__c WHERE Name = 'NOC-2068' LIMIT 1];
System.debug('NOC-2068 Id=' + noc2068.Id);

// Lấy Action Button Route to
List<FEC_Action_Button__c> routeToBtn = [
    SELECT Id, Name, FEC_Code__c FROM FEC_Action_Button__c
    WHERE FEC_Code__c = 'Route to' AND FEC_Type__c = 'Routing Action' LIMIT 1
];
if (routeToBtn.isEmpty()) {
    System.debug('ERROR: Route to button not found');
    return;
}
System.debug('Route to button Id=' + routeToBtn[0].Id);

// Check existing stages
List<FEC_Case_Stage__c> existing = [SELECT Id, Name FROM FEC_Case_Stage__c WHERE FEC_Nature_of_Cases__c = :noc2068.Id];
System.debug('Existing stages=' + existing.size());
if (!existing.isEmpty()) {
    System.debug('Stages already exist, skipping creation');
    for (FEC_Case_Stage__c s : existing) System.debug('  ' + s.Name);
    return;
}

// Tạo Stage 1
FEC_Case_Stage__c stage1 = new FEC_Case_Stage__c(
    Name = 'COF - General Flow - CC01.01-Nhân viên yêu cầu tiền phí - Stage 1',
    FEC_Code__c = 'COF - General Flow - CC01.01-Nhân viên yêu cầu tiền phí - Stage 1',
    FEC_Nature_of_Cases__c = noc2068.Id,
    FEC_Default_Stage__c = true,
    FEC_Active__c = true
);
insert stage1;
System.debug('Created Stage 1 Id=' + stage1.Id);

// Tạo Stage 2
FEC_Case_Stage__c stage2 = new FEC_Case_Stage__c(
    Name = 'COF - General Flow - CC01.01-Nhân viên yêu cầu tiền phí - Stage 2',
    FEC_Code__c = 'COF - General Flow - CC01.01-Nhân viên yêu cầu tiền phí - Stage 2',
    FEC_Nature_of_Cases__c = noc2068.Id,
    FEC_Default_Stage__c = false,
    FEC_Active__c = true
);
insert stage2;
System.debug('Created Stage 2 Id=' + stage2.Id);

// Tạo Stage Change: Stage 1 → Stage 2 (Route to, Team CC)
FEC_Stage_Change__c sc = new FEC_Stage_Change__c(
    FEC_Previous_Stage__c = stage1.Id,
    FEC_Next_Stage__c = stage2.Id,
    FEC_Action_Button__c = routeToBtn[0].Id,
    FEC_Team_User_Group__c = 'CC',
    FEC_Active__c = true
);
insert sc;
System.debug('Created Stage Change Id=' + sc.Id);

// Tạo Stage Screen: nút Route to cho Stage 1, UserGroup CC
FEC_Stage_Screen__c ss = new FEC_Stage_Screen__c(
    FEC_Case_Stage__c = stage1.Id,
    FEC_Action_Button__c = routeToBtn[0].Id,
    FEC_User_Group__c = 'CC',
    FEC_Field_Type__c = 'All',
    FEC_Active__c = true
);
insert ss;
System.debug('Created Stage Screen Id=' + ss.Id);

System.debug('=== Setup complete for NOC-2068 ===');
System.debug('Stage 1 Id=' + stage1.Id);
System.debug('Stage 2 Id=' + stage2.Id);

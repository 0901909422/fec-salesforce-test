@IsTest
private class FEC_NatureOfCaseUserGroupService_Test {

    @IsTest
    static void testBuildRoleListForIncludes() {
        // 1. Lấy một Profile hợp lệ trong hệ thống để tạo User mẫu
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User' OR Name='System Administrator' LIMIT 1];
        
        String uniqueId = String.valueOf(DateTime.now().getTime());
        
        // 2. Tạo User thỏa mãn điều kiện thuộc CS Division (Frontline)
        User u1 = new User(
            Alias = 'usrfl1', 
            Email = 'usrfl1@fecredit.com.test',
            EmailEncodingKey = 'UTF-8', 
            LastName = 'Frontline User', 
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US', 
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles', 
            UserName = 'usrfl1_' + uniqueId + '@fecredit.com.test',
            FEC_User_Group__c = 'CC',
            FEC_User_Division_Group__c = FEC_NatureOfCaseUserGroupService.FRONT_LINE,
            IsActive = true
        );
        
        // 3. Tạo User thuộc nhóm loại trừ (CX)
        User u2 = new User(
            Alias = 'usrcx1', 
            Email = 'usrcx1@fecredit.com.test',
            EmailEncodingKey = 'UTF-8', 
            LastName = 'CX User', 
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US', 
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles', 
            UserName = 'usrcx1_' + uniqueId + '@fecredit.com.test',
            FEC_User_Group__c = 'CX', 
            FEC_User_Division_Group__c = FEC_NatureOfCaseUserGroupService.FRONT_LINE,
            IsActive = true
        );
        
        insert new List<User>{u1, u2};
        
        Test.startTest();
        // Phương thức nhận tham số đầu vào nhưng không sử dụng trong logic query nội bộ
        List<String> roles = FEC_NatureOfCaseUserGroupService.buildRoleListForIncludes('AnyGroup');
        Test.stopTest();
        
        System.assert(roles.contains('CC'), 'Danh sách phải chứa nhóm CC (CS Frontline/Back Office).');
        System.assert(!roles.contains('CX'), 'Danh sách không được chứa nhóm loại trừ CX.');
    }

    @IsTest
    static void testBuildRoleListForIncludes_includesBackOfficeGroup() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' OR Name = 'System Administrator' LIMIT 1];
        String uniqueId = String.valueOf(DateTime.now().getTime());
        User backOffice = new User(
            Alias = 'usrbo1',
            Email = 'usrbo1@fecredit.com.test',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Back Office User',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'usrbo1_' + uniqueId + '@fecredit.com.test',
            FEC_User_Group__c = 'CC',
            FEC_User_Division_Group__c = FEC_NatureOfCaseUserGroupService.BACK_OFFICE,
            IsActive = true
        );
        insert backOffice;

        Test.startTest();
        List<String> roles = FEC_NatureOfCaseUserGroupService.buildRoleListForIncludes('ignored');
        Test.stopTest();

        System.assert(roles.contains('CC'), 'Danh sách phải chứa nhóm user CS Back Office.');
    }

    @IsTest
    static void testBuildNatureOfCaseUserGroupFilterClause() {
        Test.startTest();
        
        // Nhánh 1: rolelst rỗng hoặc null
        String resNull = FEC_NatureOfCaseUserGroupService.buildNatureOfCaseUserGroupFilterClause(null, null);
        System.assertEquals('', resNull);
        
        String resEmpty = FEC_NatureOfCaseUserGroupService.buildNatureOfCaseUserGroupFilterClause(new List<String>(), null);
        System.assertEquals('', resEmpty);

        // Nhánh 2: Phần tử đầu tiên bị trống/blank
        String resBlank = FEC_NatureOfCaseUserGroupService.buildNatureOfCaseUserGroupFilterClause(new List<String>{''}, null);
        System.assertEquals('', resBlank);

        // Nhánh 3 & 4: Nhóm User nằm trong pool bổ sung (Bypass filter)
        String resBypass = FEC_NatureOfCaseUserGroupService.buildNatureOfCaseUserGroupFilterClause(
            new List<String>{'Team Alpha'}, 
            new List<String>{'Team Alpha', 'Team Beta', ' '}
        );
        System.assertEquals('', resBypass);

        // Nhánh 5: Nhóm User không nằm trong pool bổ sung -> sinh INCLUDES (đơn hoặc OR với pool)
        String resGenerate = FEC_NatureOfCaseUserGroupService.buildNatureOfCaseUserGroupFilterClause(
            new List<String>{'Team Delta'},
            new List<String>{'Team Alpha', 'Team Beta'}
        );
        System.assert(
            resGenerate.contains('FEC_User_Group__c INCLUDES (\'Team Delta\')'),
            'Filter must INCLUDES primary user group: ' + resGenerate
        );
        
        Test.stopTest();
    }

    @IsTest
    static void testBuildUserGroupIncludesWhereClause() {
        Test.startTest();
        
        // Nhánh 1: rolelst null hoặc trống
        String resNull = FEC_NatureOfCaseUserGroupService.buildUserGroupIncludesWhereClause(null);
        System.assertEquals('', resNull);

        // Nhánh 2: Nhóm bị Blank
        String resBlank = FEC_NatureOfCaseUserGroupService.buildUserGroupIncludesWhereClause(new List<String>{'   '});
        System.assertEquals('', resBlank);

        // Nhánh 3: Khởi tạo mệnh đề điều kiện thành công
        String resValid = FEC_NatureOfCaseUserGroupService.buildUserGroupIncludesWhereClause(new List<String>{'Team BackOffice'});
        System.assertEquals('AND FEC_User_Group__c INCLUDES (\'Team BackOffice\')', resValid);
        
        Test.stopTest();
    }

    private static void assertNatureOfCaseFilterIncludesGroups(
        String clause,
        List<String> expectedGroups
    ) {
        System.assert(String.isNotBlank(clause), 'Filter clause must not be blank.');
        System.assert(
            clause.startsWith('AND '),
            'Filter must start with AND: ' + clause
        );
        for (String groupName : expectedGroups) {
            System.assert(
                clause.contains(
                    'FEC_User_Group__c INCLUDES (\'' + groupName + '\')'
                ),
                'Missing INCLUDES for ' + groupName + ': ' + clause
            );
        }
    }
}
@IsTest
private class FEC_UMSUserManagementRestService_Test {
    @IsTest
    static void parseDateTimeInput_supportsIsoAndMmDdYyyy() {
        Datetime iso = FEC_UMSUserManagementRestService.parseDateTimeInput('2026-06-02T07:00:00Z');
        Datetime mdy = FEC_UMSUserManagementRestService.parseDateTimeInput('06-02-2026');
        Datetime bad = FEC_UMSUserManagementRestService.parseDateTimeInput('invalid');

        System.assertNotEquals(null, iso);
        System.assertNotEquals(null, mdy);
        System.assertEquals(null, bad);
    }

    @IsTest
    static void doGet_info_success() {
        User me = [SELECT Username FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];

    private static User adminUser() {
        List<User> admins = [
            SELECT Id
            FROM User
            WHERE IsActive = TRUE AND Profile.Name = 'System Administrator'
            LIMIT 1
        ];
        return admins.isEmpty() ? new User(Id = UserInfo.getUserId()) : admins[0];
    }

    private static Id umsQueueId() {
        return [SELECT Id FROM Group WHERE Type = 'Queue' AND DeveloperName LIKE 'UMS_Test_Queue_%' LIMIT 1].Id;
    }

    @TestSetup
    static void setupData() {
        String suffix = String.valueOf(System.currentTimeMillis());
        String devName = 'UMS_Test_Queue_' + suffix.right(8);

        Group umsQueue = new Group(
            Name = 'UMS Test Queue ' + suffix,
            DeveloperName = devName,
            Type = 'Queue'
        );
        insert umsQueue;

        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert new QueueSobject(QueueId = umsQueue.Id, SobjectType = 'Case');
        }

        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String username = 'ums.existing.' + suffix + '@test.invalid';
        User existing = new User(
            Alias = 'umsexist',
            Email = 'ums.existing.' + suffix + '@test.invalid',
            EmailEncodingKey = 'UTF-8',
            FirstName = 'Existing',
            LastName = 'User',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = username,
            IsActive = true
        );
        insert existing;

        // Assign Permission Sets cho FLS access
        FEC_TestDataFactory.assignStandardFECPermissions(existing.Id);

        System.runAs(adminUser()) {
            insert new GroupMember(GroupId = umsQueue.Id, UserOrGroupId = existing.Id);
        }
    }

    private static void setRestContext(String method, String uri, String body, Map<String, String> params) {
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/ums/v1/users/info';
        req.httpMethod = 'GET';
        req.addParameter('RequestorID', 'UT');
        req.addParameter('UserID', me.Username);
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        FEC_UMSUserManagementRestService.doGet();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
        String body = res.responseBody.toString();
        System.assert(body.contains('"Status":"S"'), body);
        System.assert(body.contains('"UserID":"' + me.Username + '"'), body);
    }

    @IsTest
    static void doGet_all_invalidDateRange() {
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/ums/v1/users';
        req.httpMethod = 'GET';
        req.addParameter('RequestorID', 'UT');
        req.addParameter('FromDate', '06-02-2026');
        req.addParameter('ToDate', '06-01-2026');
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        FEC_UMSUserManagementRestService.doGet();
        Test.stopTest();

        System.assertEquals(400, res.statusCode);
        System.assert(res.responseBody.toString().contains('"Status":"F"'));
    }

    @IsTest
    static void doPost_status_invalidAction() {
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/ums/v1/users/status';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(
            '{"RequestorID":"UT","ActionType":"X","UserList":[{"UserID":"abc"}]}'
        );
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        FEC_UMSUserManagementRestService.doPost();
        Test.stopTest();

        System.assertEquals(400, res.statusCode);
        System.assert(res.responseBody.toString().contains('ActionType must be D or R'));
    }

    @IsTest
    static void deriveTitleFromRole_stripsTrailingNumber() {
        System.assertEquals(
            'Customer Service E-com Team Leader',
            FEC_UMSUserManagementRestService.deriveTitleFromRole('Customer Service E-com Team Leader 1')
        );
        System.assertEquals(
            'Senior Customer Service Inbound Specialist',
            FEC_UMSUserManagementRestService.deriveTitleFromRole('Senior Customer Service Inbound Specialist 5')
        );
        System.assertEquals(
            'Unit Head of Customer Service Inbound',
            FEC_UMSUserManagementRestService.deriveTitleFromRole('Unit Head of Customer Service Inbound')
        );
        System.assertEquals(null, FEC_UMSUserManagementRestService.deriveTitleFromRole(null));
    }

    @IsTest
    static void getPermissionRoleList_returnsAssignedRolesForCurrentUser() {
        User me = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];

        Test.startTest();
        List<String> roles = FEC_UMSUserManagementRestService.getPermissionRoleList(me.Id);
        Test.stopTest();

        System.assertNotEquals(null, roles);
        Integer psaCount = [
            SELECT COUNT()
            FROM PermissionSetAssignment
            WHERE AssigneeId = :me.Id
            AND (
                PermissionSetGroupId != NULL OR
                (PermissionSet.IsOwnedByProfile = FALSE)
            )
        ];
        if (psaCount > 0) {
            System.assert(!roles.isEmpty(), 'User có permission assignment thì RoleList không rỗng');
        }
    }

    @IsTest
    static void doPost_upsert_missingRole() {
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/ums/v1/users';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(
            '{"RequestorID":"UT","UserList":[{"UserID":"u1","UserName":"Test","FEEmail":"t@fpt.com","ListUserRole":["FEC_PSG_CS_Senior_CS_Support_Specialist"]}]}'
        );
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        FEC_UMSUserManagementRestService.doPost();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
        System.assert(RestContext.response.responseBody.toString().contains('Missing required field: Role'));
    }

    @IsTest
    static void doPost_upsert_missingRequired() {
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/ums/v1/users';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{"RequestorID":"UT","UserList":[{"UserID":"u1"}]}');
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        FEC_UMSUserManagementRestService.doPost();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
        String body = res.responseBody.toString();
        System.assert(body.contains('"Status":"F"'), body);
        System.assert(body.contains('Missing required field'), body);
    }

    @IsTest
    static void resolveUserRoleId_returnsIdForExistingRole() {
        Id roleId = FEC_UMSUserManagementRestService.resolveUserRoleId(
            'Customer Service E-com Team Leader 1'
        );
        System.assertNotEquals(null, roleId);
        System.assertEquals(null, FEC_UMSUserManagementRestService.resolveUserRoleId('NONEXISTENT_ROLE_XYZ'));
    }

    @IsTest
    static void doPost_upsert_roleNotFound() {
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/ums/v1/users';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(
            '{"RequestorID":"UT","UserList":[{"UserID":"u1","UserName":"Test","FEEmail":"t@fpt.com","Role":"NONEXISTENT_ROLE_XYZ","ListUserRole":["FEC_PSG_CS_CS_Ecom_Team_Leader"]}]}'
        );
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        FEC_UMSUserManagementRestService.doPost();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
        System.assert(res.responseBody.toString().contains('UMS-007: Role not found'));
    }

    @IsTest
    static void doPost_upsert_psgNotFound() {
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/ums/v1/users';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(
            '{"RequestorID":"UT","UserList":[{"UserID":"u1","UserName":"Test","FEEmail":"t@fpt.com","Role":"Customer Service E-com Team Leader 1","ListUserRole":["NONEXISTENT_PSG_XYZ"]}]}'
        );
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        FEC_UMSUserManagementRestService.doPost();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
        System.assert(res.responseBody.toString().contains('UMS-005: Permission Set Group not found'));
    }

    @IsTest
    static void doPost_upsert_invalidUpdateType() {
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/ums/v1/users';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(
            '{"RequestorID":"UT","UpdateType":"X","UserList":[{"UserID":"u1","UserName":"Test","FEEmail":"t@fpt.com","Role":"Customer Service E-com Team Leader 1","ListUserRole":["FEC_PSG_CS_CS_Ecom_Team_Leader"]}]}'
        );
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        FEC_UMSUserManagementRestService.doPost();
        Test.stopTest();

        System.assertEquals(400, res.statusCode);
        System.assert(res.responseBody.toString().contains('Invalid UpdateType'));
    }

    @IsTest
    static void doPost_upsert_createUpdateRoleAndPsg() {
        String unique = String.valueOf(Datetime.now().getTime());
        String username = 'ums.test.' + unique + '@example.com';
        String roleName = 'Customer Service E-com Team Leader 1';
        String expectedTitle = 'Customer Service E-com Team Leader';
        Id expectedRoleId = FEC_UMSUserManagementRestService.resolveUserRoleId(roleName);

        RestRequest createReq = new RestRequest();
        createReq.requestUri = '/services/apexrest/ums/v1/users';
        createReq.httpMethod = 'POST';
        createReq.requestBody = Blob.valueOf(
            '{"RequestorID":"UT","UpdateType":"C","UserList":[{"UserID":"' + username +
            '","UserName":"UMS Test","FirstName":"UMS","LastName":"User","FEEmail":"' + username +
            '","MainQueue":"CS_Ecom","DefaultQueue":"CS_Ecom","Role":"' + roleName +
            '","ListUserRole":["FEC_PSG_CS_CS_Ecom_Team_Leader"]}]}'
        );
        RestResponse createRes = new RestResponse();
        RestContext.request = createReq;
        RestContext.response = createRes;

        Test.startTest();
        FEC_UMSUserManagementRestService.doPost();
        Test.stopTest();

        System.assertEquals(200, createRes.statusCode, createRes.responseBody.toString());
        System.assert(createRes.responseBody.toString().contains('Create success'), createRes.responseBody.toString());

        User created = [
            SELECT Id, UserRoleId, Title
            FROM User
            WHERE Username = :username
            LIMIT 1
        ];
        System.assertEquals(expectedRoleId, created.UserRoleId);
        System.assertEquals(expectedTitle, created.Title);

        Integer psgCount = [
            SELECT COUNT()
            FROM PermissionSetAssignment
            WHERE AssigneeId = :created.Id
            AND PermissionSetGroupId != NULL
        ];
        System.assert(psgCount > 0, 'PSG should be assigned on create');

        RestRequest replaceReq = new RestRequest();
        replaceReq.requestUri = '/services/apexrest/ums/v1/users';
        replaceReq.httpMethod = 'POST';
        replaceReq.requestBody = Blob.valueOf(
            '{"RequestorID":"UT","UpdateType":"R","UserList":[{"UserID":"' + username +
            '","UserName":"UMS Test","FEEmail":"' + username +
            '","MainQueue":"CS_Ecom","DefaultQueue":"CS_Ecom","Role":"' + roleName +
            '","ListUserRole":["FEC_PSG_CS_CS_Ecom_Specialist"]}]}'
        );
        RestResponse replaceRes = new RestResponse();
        RestContext.request = replaceReq;
        RestContext.response = replaceRes;
        FEC_UMSUserManagementRestService.doPost();

        System.assertEquals(200, replaceRes.statusCode, replaceRes.responseBody.toString());
        System.assert(replaceRes.responseBody.toString().contains('Update success'));

        PermissionSetGroup specialistPsg = [
            SELECT Id
            FROM PermissionSetGroup
            WHERE DeveloperName = 'FEC_PSG_CS_CS_Ecom_Specialist'
            LIMIT 1
        ];
        List<PermissionSetAssignment> assignments = [
            SELECT PermissionSetGroupId
            FROM PermissionSetAssignment
            WHERE AssigneeId = :created.Id
            AND PermissionSetGroupId != NULL
        ];
        System.assertEquals(1, assignments.size(), 'Replace should leave exactly one PSG');
        System.assertEquals(specialistPsg.Id, assignments[0].PermissionSetGroupId);
    }

    @IsTest
    static void doGet_all_success() {
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/ums/v1/users';
        req.httpMethod = 'GET';
        req.addParameter('RequestorID', 'UT');
        req.addParameter('FromDate', '01-01-1900');
        req.addParameter('ToDate', '01-02-1900');
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        FEC_UMSUserManagementRestService.doGet();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
        System.assert(res.responseBody.toString().contains('"Status":"S"'));
    }

    @IsTest
    static void doPost_status_deactivateAndReactivate() {
        Profile p = [SELECT Id FROM Profile WHERE Id = :UserInfo.getProfileId() LIMIT 1];
        String unique = String.valueOf(Datetime.now().getTime());
        User u = new User(
            Alias = 'umstst',
            Email = 'umsstatus' + unique + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'StatusTest',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'America/Los_Angeles',
            ProfileId = p.Id,
            Username = 'ums.status.' + unique + '@example.com',
            FEC_Main_Queue__c = 'CS_Ecom',
            IsActive = true
        );
        insert u;

        RestRequest deactivateReq = new RestRequest();
        deactivateReq.requestUri = '/services/apexrest/ums/v1/users/status';
        deactivateReq.httpMethod = 'POST';
        deactivateReq.requestBody = Blob.valueOf(
            '{"RequestorID":"UT","ActionType":"D","UserList":[{"UserID":"' + u.Username + '"}]}'
        );
        RestResponse deactivateRes = new RestResponse();
        RestContext.request = deactivateReq;
        RestContext.response = deactivateRes;

        Test.startTest();
        FEC_UMSUserManagementRestService.doPost();
        Test.stopTest();

        System.assertEquals(200, deactivateRes.statusCode);
        System.assert(deactivateRes.responseBody.toString().contains('User inactivated'));
        System.assertEquals(false, [SELECT IsActive FROM User WHERE Id = :u.Id].IsActive);

        RestRequest reactivateReq = new RestRequest();
        reactivateReq.requestUri = '/services/apexrest/ums/v1/users/status';
        reactivateReq.httpMethod = 'POST';
        reactivateReq.requestBody = Blob.valueOf(
            '{"RequestorID":"UT","ActionType":"R","UserList":[{"UserID":"' + u.Username + '"}]}'
        );
        RestResponse reactivateRes = new RestResponse();
        RestContext.request = reactivateReq;
        RestContext.response = reactivateRes;
        FEC_UMSUserManagementRestService.doPost();

        System.assertEquals(200, reactivateRes.statusCode);
        System.assert(reactivateRes.responseBody.toString().contains('User activated'));
        System.assertEquals(true, [SELECT IsActive FROM User WHERE Id = :u.Id].IsActive);
    }
}
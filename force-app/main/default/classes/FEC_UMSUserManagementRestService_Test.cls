@IsTest
private class FEC_UMSUserManagementRestService_Test {

    private static final String REQUESTOR_ID = 'PEGA-UMS-TEST';

    private static String queueDevName() {
        return [SELECT DeveloperName FROM Group WHERE Type = 'Queue' AND DeveloperName LIKE 'UMS_Test_Queue_%' LIMIT 1].DeveloperName;
    }

    private static String existingUsername() {
        return [SELECT Username FROM User WHERE Username LIKE 'ums.existing.%@test.invalid' LIMIT 1].Username;
    }

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

        System.runAs(adminUser()) {
            insert new GroupMember(GroupId = umsQueue.Id, UserOrGroupId = existing.Id);
        }
    }

    private static void setRestContext(String method, String uri, String body, Map<String, String> params) {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.httpMethod = method;
        req.requestURI = uri;
        if (body != null) {
            req.requestBody = Blob.valueOf(body);
        }
        if (params != null) {
            for (String key : params.keySet()) {
                req.addParameter(key, params.get(key));
            }
        }
        RestContext.request = req;
        RestContext.response = res;
    }

    private static FEC_UMSUserManagementRestService.UMSMutationResponse parseMutationResponse() {
        return (FEC_UMSUserManagementRestService.UMSMutationResponse) JSON.deserialize(
            RestContext.response.responseBody.toString(),
            FEC_UMSUserManagementRestService.UMSMutationResponse.class
        );
    }

    private static String buildUpsertBody(
        String updateType,
        String userId,
        List<String> roles
    ) {
        Map<String, Object> payload = new Map<String, Object>{
            'RequestorID' => REQUESTOR_ID,
            'UpdateType' => updateType,
            'UserList' => new List<Object>{
                new Map<String, Object>{
                    'UserID' => userId,
                    'UserName' => 'UMS User',
                    'FirstName' => 'UMS',
                    'LastName' => 'Test',
                    'FEEmail' => userId,
                    'Position' => 'Agent',
                    'OrgUnit' => 'CC',
                    'OrgDivision' => 'CS Frontline',
                    'MainQueue' => 'CS_Frontline_Queue',
                    'DefaultQueue' => 'CS_Frontline_Queue',
                    'ListUserRole' => roles
                }
            }
        };
        return JSON.serialize(payload);
    }

    @IsTest
    static void testDoPost_CreateUser_Success() {
        String suffix = String.valueOf(System.currentTimeMillis());
        String newUsername = 'ums.create.' + suffix + '@test.invalid';
        setRestContext(
            'POST',
            '/services/apexrest/ums/v1/users',
            buildUpsertBody('C', newUsername, new List<String>{ String.valueOf(umsQueueId()) }),
            null
        );

        Test.startTest();
        System.runAs(adminUser()) {
            FEC_UMSUserManagementRestService.doPost();
        }
        Test.stopTest();

        System.assertEquals(FEC_ConstantCommon.HTTP_STATUS_OK, RestContext.response.statusCode);
        FEC_UMSUserManagementRestService.UMSMutationResponse res = parseMutationResponse();
        System.assertEquals(1, res.Message.size());
        System.assertEquals('S', res.Message[0].Status);
        System.assertEquals('Create success', res.Message[0].Description);

        User created = [SELECT Id, Username, Email FROM User WHERE Username = :newUsername LIMIT 1];
        System.assertEquals(newUsername, created.Email);
    }

    @IsTest
    static void testDoPost_AppendUser_Success() {
        String username = existingUsername();
        setRestContext(
            'POST',
            '/services/apexrest/ums/v1/users',
            buildUpsertBody('A', username, new List<String>{ String.valueOf(umsQueueId()) }),
            null
        );

        Test.startTest();
        System.runAs(adminUser()) {
            FEC_UMSUserManagementRestService.doPost();
        }
        Test.stopTest();

        System.assertEquals(FEC_ConstantCommon.HTTP_STATUS_OK, RestContext.response.statusCode);
        FEC_UMSUserManagementRestService.UMSMutationResponse res = parseMutationResponse();
        System.assertEquals('S', res.Message[0].Status);
        System.assertEquals('Update success', res.Message[0].Description);
    }

    @IsTest
    static void testDoPost_UpdateUser_Replace() {
        String username = existingUsername();
        setRestContext(
            'POST',
            '/services/apexrest/ums/v1/users',
            buildUpsertBody('R', username, new List<String>{ String.valueOf(umsQueueId()) }),
            null
        );

        Test.startTest();
        System.runAs(adminUser()) {
            FEC_UMSUserManagementRestService.doPost();
        }
        Test.stopTest();

        System.assertEquals(FEC_ConstantCommon.HTTP_STATUS_OK, RestContext.response.statusCode);
        FEC_UMSUserManagementRestService.UMSMutationResponse res = parseMutationResponse();
        System.assertEquals('S', res.Message[0].Status);
        System.assertEquals('Update success', res.Message[0].Description);
    }

    @IsTest
    static void testDoPost_Status_DeactivateAndReactivate() {
        String username = existingUsername();

        String deactivateBody = JSON.serialize(new Map<String, Object>{
            'RequestorID' => REQUESTOR_ID,
            'ActionType' => 'D',
            'UserList' => new List<Object>{ new Map<String, Object>{ 'UserID' => username } }
        });
        setRestContext(
            'POST',
            '/services/apexrest/ums/v1/users/status',
            deactivateBody,
            null
        );

        Test.startTest();
        FEC_UMSUserManagementRestService.doPost();
        Test.stopTest();

        System.assertEquals(FEC_ConstantCommon.HTTP_STATUS_OK, RestContext.response.statusCode);
        FEC_UMSUserManagementRestService.UMSMutationResponse deactivateRes = parseMutationResponse();
        System.assertEquals('S', deactivateRes.Message[0].Status);
        System.assertEquals('User inactivated', deactivateRes.Message[0].Description);

        User deactivated = [SELECT IsActive FROM User WHERE Username = :username LIMIT 1];
        System.assertEquals(false, deactivated.IsActive);

        String reactivateBody = JSON.serialize(new Map<String, Object>{
            'RequestorID' => REQUESTOR_ID,
            'ActionType' => 'R',
            'UserList' => new List<Object>{ new Map<String, Object>{ 'UserID' => username } }
        });
        setRestContext(
            'POST',
            '/services/apexrest/ums/v1/users/status',
            reactivateBody,
            null
        );

        FEC_UMSUserManagementRestService.doPost();
        FEC_UMSUserManagementRestService.UMSMutationResponse reactivateRes = parseMutationResponse();
        System.assertEquals('S', reactivateRes.Message[0].Status);
        System.assertEquals('User activated', reactivateRes.Message[0].Description);

        User reactivated = [SELECT IsActive FROM User WHERE Username = :username LIMIT 1];
        System.assertEquals(true, reactivated.IsActive);
    }

    @IsTest
    static void testDoGet_GetUserInfo() {
        String username = existingUsername();
        setRestContext(
            'GET',
            '/services/apexrest/ums/v1/users/info',
            null,
            new Map<String, String>{
                'RequestorID' => REQUESTOR_ID,
                'UserID' => username
            }
        );

        Test.startTest();
        FEC_UMSUserManagementRestService.doGet();
        Test.stopTest();

        System.assertEquals(FEC_ConstantCommon.HTTP_STATUS_OK, RestContext.response.statusCode);
        FEC_UMSUserManagementRestService.UMSGetInfoResponse res =
            (FEC_UMSUserManagementRestService.UMSGetInfoResponse) JSON.deserialize(
                RestContext.response.responseBody.toString(),
                FEC_UMSUserManagementRestService.UMSGetInfoResponse.class
            );
        System.assertEquals('S', res.Status);
        System.assertNotEquals(null, res.Infor);
        System.assertEquals(username, res.Infor.UserID);
    }

    @IsTest
    static void testDoGet_GetAllUsers() {
        Datetime fromDt = Datetime.now().addDays(-1);
        Datetime toDt = Datetime.now().addDays(1);
        setRestContext(
            'GET',
            '/services/apexrest/ums/v1/users',
            null,
            new Map<String, String>{
                'RequestorID' => REQUESTOR_ID,
                'FromDate' => JSON.serialize(fromDt).replace('"', ''),
                'ToDate' => JSON.serialize(toDt).replace('"', '')
            }
        );

        Test.startTest();
        FEC_UMSUserManagementRestService.doGet();
        Test.stopTest();

        System.assertEquals(FEC_ConstantCommon.HTTP_STATUS_OK, RestContext.response.statusCode);
        FEC_UMSUserManagementRestService.UMSGetAllResponse res =
            (FEC_UMSUserManagementRestService.UMSGetAllResponse) JSON.deserialize(
                RestContext.response.responseBody.toString(),
                FEC_UMSUserManagementRestService.UMSGetAllResponse.class
            );
        System.assertEquals('S', res.Status);
        System.assertNotEquals(null, res.Data);
    }

    @IsTest
    static void testDoPost_ValidationErrors() {
        setRestContext('POST', '/services/apexrest/ums/v1/users', null, null);
        FEC_UMSUserManagementRestService.doPost();
        System.assertEquals(FEC_ConstantCommon.HTTP_STATUS_BAD_REQUEST, RestContext.response.statusCode);

        setRestContext(
            'POST',
            '/services/apexrest/ums/v1/users',
            JSON.serialize(new Map<String, Object>{
                'RequestorID' => REQUESTOR_ID,
                'UpdateType' => 'X',
                'UserList' => new List<Object>()
            }),
            null
        );
        FEC_UMSUserManagementRestService.doPost();
        System.assertEquals(FEC_ConstantCommon.HTTP_STATUS_BAD_REQUEST, RestContext.response.statusCode);

        String username = existingUsername();
        setRestContext(
            'POST',
            '/services/apexrest/ums/v1/users',
            buildUpsertBody('C', username, new List<String>{ queueDevName() }),
            null
        );
        FEC_UMSUserManagementRestService.doPost();
        FEC_UMSUserManagementRestService.UMSMutationResponse dupRes = parseMutationResponse();
        System.assertEquals('F', dupRes.Message[0].Status);
        System.assert(dupRes.Message[0].Description.contains('UMS-004'));
    }

    @IsTest
    static void testDoPost_Status_InvalidActionType() {
        setRestContext(
            'POST',
            '/services/apexrest/ums/v1/users/status',
            JSON.serialize(new Map<String, Object>{
                'RequestorID' => REQUESTOR_ID,
                'ActionType' => 'X',
                'UserList' => new List<Object>{ new Map<String, Object>{ 'UserID' => 'missing@test.invalid' } }
            }),
            null
        );

        Test.startTest();
        FEC_UMSUserManagementRestService.doPost();
        Test.stopTest();

        System.assertEquals(FEC_ConstantCommon.HTTP_STATUS_BAD_REQUEST, RestContext.response.statusCode);
    }

    @IsTest
    static void testDoGet_ValidationErrors() {
        setRestContext(
            'GET',
            '/services/apexrest/ums/v1/users/info',
            null,
            new Map<String, String>{ 'UserID' => 'missing@test.invalid' }
        );
        FEC_UMSUserManagementRestService.doGet();
        System.assertEquals(FEC_ConstantCommon.HTTP_STATUS_BAD_REQUEST, RestContext.response.statusCode);

        setRestContext(
            'GET',
            '/services/apexrest/ums/v1/users',
            null,
            new Map<String, String>{
                'RequestorID' => REQUESTOR_ID,
                'FromDate' => '06-01-2026',
                'ToDate' => '06-01-2025'
            }
        );
        FEC_UMSUserManagementRestService.doGet();
        System.assertEquals(FEC_ConstantCommon.HTTP_STATUS_BAD_REQUEST, RestContext.response.statusCode);
    }

    @IsTest
    static void testParseDateTimeInput() {
        Test.startTest();
        Datetime isoDt = FEC_UMSUserManagementRestService.parseDateTimeInput('2026-06-01T00:00:00.000Z');
        Datetime mmddDt = FEC_UMSUserManagementRestService.parseDateTimeInput('06-01-2026');
        Datetime blankDt = FEC_UMSUserManagementRestService.parseDateTimeInput('');
        Datetime invalidDt = FEC_UMSUserManagementRestService.parseDateTimeInput('bad-date');
        Test.stopTest();

        System.assertNotEquals(null, isoDt);
        System.assertNotEquals(null, mmddDt);
        System.assertEquals(null, blankDt);
        System.assertEquals(null, invalidDt);
    }
}

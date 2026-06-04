@IsTest
private class FEC_CofGsrAssignmentService_Test {

    @TestSetup
    static void setupData() {
        String suffix = String.valueOf(System.currentTimeMillis());

        FEC_Product_Type__c prod = new FEC_Product_Type__c(
            Name = 'Credit Card',
            FEC_Code__c = 'CC',
            FEC_Active__c = true
        );
        insert prod;
        FEC_Category__c cat = new FEC_Category__c(
            Name = 'Request',
            FEC_Code__c = 'Request',
            FEC_Active__c = true
        );
        insert cat;
        FEC_Sub_Category__c subCat = new FEC_Sub_Category__c(
            Name = 'RC27',
            FEC_Code__c = 'RC27',
            FEC_Active__c = true
        );
        insert subCat;
        FEC_Business_Process__c bp = new FEC_Business_Process__c(
            Name = 'COF GSR BP',
            FEC_Code__c = 'COFBP' + suffix,
            FEC_Active__c = true
        );
        insert bp;

        FEC_Nature_of_Case__c noc = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = prod.Id,
            FEC_Category__c = cat.Id,
            FEC_Sub_Category__c = subCat.Id,
            FEC_Business_Process__c = bp.Id,
            FEC_Active__c = true
        );
        insert noc;

        insert new FEC_Routing_Assignment__c(
            FEC_Nature_of_Cases__c = noc.Id,
            FEC_Team__c = 'CC',
            FEC_Queue__c = System.Label.FEC_CC_Queue_Name,
            FEC_Active__c = true
        );

        System.runAs(new User(Id = UserInfo.getUserId())) {
            Group q = new Group(
                Name = System.Label.FEC_CC_Queue_Name,
                DeveloperName = 'CC_Queue_' + suffix,
                Type = FEC_ConstantCommon.GROUP_TYPE_QUEUE
            );
            insert q;
            insert new QueueSobject(QueueId = q.Id, SobjectType = 'Case');
        }
    }

    private static User adminUser() {
        return [
            SELECT Id, Email, UserRole.Name
            FROM User
            WHERE Profile.Name = 'System Administrator' AND IsActive = true
            LIMIT 1
        ];
    }

    private static Case insertTestCase(String subject) {
        FEC_Case_Stage__c stage = new FEC_Case_Stage__c(
            Name = 'Stage 2',
            FEC_Code__c = 'S2-' + String.valueOf(System.currentTimeMillis()),
            FEC_Active__c = true
        );
        insert stage;

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            Case c = new Case(
                Subject = subject,
                Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
                FEC_Current_Case_Stage__c = stage.Id,
                FEC_ID_Search__c = 'COF-' + subject + '-' + String.valueOf(System.currentTimeMillis())
            );
            insert c;
            return c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }

    private static FEC_Nature_of_Case__c createNocWithRouting(String teamName, String queueName) {
        String suffix = String.valueOf(System.currentTimeMillis());
        FEC_Product_Type__c prod = new FEC_Product_Type__c(
            Name = 'Prod-' + suffix,
            FEC_Code__c = 'P' + suffix.right(6),
            FEC_Active__c = true
        );
        insert prod;
        FEC_Category__c cat = new FEC_Category__c(
            Name = 'Cat-' + suffix,
            FEC_Code__c = 'C' + suffix.right(6),
            FEC_Active__c = true
        );
        insert cat;
        FEC_Sub_Category__c subCat = new FEC_Sub_Category__c(
            Name = 'Sub-' + suffix,
            FEC_Code__c = 'S' + suffix.right(6),
            FEC_Active__c = true
        );
        insert subCat;
        FEC_Business_Process__c bp = new FEC_Business_Process__c(
            Name = 'BP-' + suffix,
            FEC_Code__c = 'BP' + suffix.right(6),
            FEC_Active__c = true
        );
        insert bp;

        FEC_Nature_of_Case__c noc = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = prod.Id,
            FEC_Category__c = cat.Id,
            FEC_Sub_Category__c = subCat.Id,
            FEC_Business_Process__c = bp.Id,
            FEC_Active__c = true
        );
        insert noc;

        insert new FEC_Routing_Assignment__c(
            FEC_Nature_of_Cases__c = noc.Id,
            FEC_Team__c = teamName,
            FEC_Queue__c = queueName,
            FEC_Active__c = true
        );
        return noc;
    }

    @IsTest
    static void testGetRoutingAssignments() {
        FEC_Nature_of_Case__c noc = [SELECT Id FROM FEC_Nature_of_Case__c LIMIT 1];

        Test.startTest();
        List<Map<String, String>> result =
            FEC_CofGsrAssignmentService.getRoutingAssignments(noc.Id, 'Individual');
        Test.stopTest();

        System.assert(result.size() > 0, 'Phải tìm thấy assignment.');
        System.assertEquals('CC', result[0].get('team'));
    }

    @IsTest
    static void testGetRoutingAssignments_BlankNatureOfCase() {
        Test.startTest();
        List<Map<String, String>> result =
            FEC_CofGsrAssignmentService.getRoutingAssignments(null, 'Individual');
        Test.stopTest();

        System.assertEquals(0, result.size(), 'Blank NOC id phải trả list rỗng.');
    }

    @IsTest
    static void testGetTeamQueueOptions() {
        Test.startTest();
        List<Map<String, String>> options = FEC_CofGsrAssignmentService.getTeamQueueOptions();
        Test.stopTest();

        System.assertNotEquals(null, options, 'Kết quả không được null.');
    }

    @IsTest
    static void testGetTeamQueueOptions_WithData() {
        Group ccQueue = [
            SELECT Id, DeveloperName
            FROM Group
            WHERE Name = :System.Label.FEC_CC_Queue_Name
              AND Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
            LIMIT 1
        ];
        FEC_Team__c team = new FEC_Team__c(Name = 'TEAM-' + String.valueOf(System.currentTimeMillis()));
        insert team;
        insert new FEC_Team_Queue__c(
            FEC_Select_Team__c = team.Id,
            FEC_Queue_Name__c = ccQueue.DeveloperName
        );

        Test.startTest();
        List<Map<String, String>> options = FEC_CofGsrAssignmentService.getTeamQueueOptions();
        Test.stopTest();

        System.assert(options.size() > 0, 'Phải có ít nhất 1 option.');
    }

    @IsTest
    static void testHasNonCcSpTeam() {
        FEC_Nature_of_Case__c noc = [SELECT Id FROM FEC_Nature_of_Case__c LIMIT 1];

        Test.startTest();
        Boolean result = FEC_CofGsrAssignmentService.hasNonCcSpTeam(new Set<Id>{ noc.Id });
        Test.stopTest();

        System.assertEquals(false, result, 'Team CC là CC/SP nên phải trả về false.');
    }

    @IsTest
    static void testHasNonCcSpTeam_TrueWithDifferentTeam() {
        FEC_Nature_of_Case__c noc = [SELECT Id FROM FEC_Nature_of_Case__c LIMIT 1];
        insert new FEC_Routing_Assignment__c(
            FEC_Nature_of_Cases__c = noc.Id,
            FEC_Team__c = 'QA',
            FEC_Queue__c = System.Label.FEC_CC_Queue_Name,
            FEC_Active__c = true
        );

        Test.startTest();
        Boolean result = FEC_CofGsrAssignmentService.hasNonCcSpTeam(new Set<Id>{ noc.Id });
        Test.stopTest();

        System.assertEquals(true, result, 'Có team khác CC/SP phải trả true.');
    }

    @IsTest
    static void testRouteToCofGsr_CcSpPath() {
        Case c = insertTestCase('COF GSR Route Test');
        FEC_Nature_of_Case__c noc = [SELECT Id FROM FEC_Nature_of_Case__c LIMIT 1];
        Group ccQueue = [
            SELECT Id
            FROM Group
            WHERE Name = :System.Label.FEC_CC_Queue_Name
            AND Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
            LIMIT 1
        ];

        Map<String, Object> params = new Map<String, Object>{
            'natureOfCaseId' => (String) noc.Id,
            'remarkContent' => 'Test remark'
        };

        Test.startTest();
        FEC_CofGsrAssignmentService.handleRouteToCofGsr(c.Id, params, 'Stage 1');
        Test.stopTest();

        Case updatedCase = [SELECT OwnerId FROM Case WHERE Id = :c.Id];
        System.assertEquals(ccQueue.Id, updatedCase.OwnerId, 'Case nên được route tới CC queue.');
    }

    @IsTest
    static void testRouteToCofGsr_ManualItemsPath() {
        Case c = insertTestCase('COF GSR Manual Route');
        FEC_Nature_of_Case__c noc = [SELECT Id FROM FEC_Nature_of_Case__c LIMIT 1];
        String jsonBody = '[{"teamName":"CC","queueName":"' + System.Label.FEC_CC_Queue_Name + '","remark":"manual remark"}]';

        Map<String, Object> params = new Map<String, Object>{
            'natureOfCaseId' => (String) noc.Id,
            'manualItemsJson' => jsonBody
        };

        Test.startTest();
        FEC_CofGsrAssignmentService.handleRouteToCofGsr(c.Id, params, 'Stage 2');
        Test.stopTest();

        Integer assignmentCount = [SELECT COUNT() FROM FEC_Assignment__c WHERE FEC_Case__c = :c.Id];
        System.assert(assignmentCount > 0, 'Manual items path phải tạo assignment.');
    }

    @IsTest
    static void testRouteToCofGsr_NonCcSpPath_MovesStage() {
        FEC_Nature_of_Case__c noc = createNocWithRouting('QA', System.Label.FEC_CC_Queue_Name);

        FEC_Case_Stage__c stage1 = new FEC_Case_Stage__c(
            Name = '001-Stage 1',
            FEC_Code__c = 'ST1-' + String.valueOf(System.currentTimeMillis()),
            FEC_Nature_of_Cases__c = noc.Id,
            FEC_Active__c = true
        );
        insert stage1;
        FEC_Case_Stage__c stage2 = new FEC_Case_Stage__c(
            Name = '002-Stage 2',
            FEC_Code__c = 'ST2-' + String.valueOf(System.currentTimeMillis()),
            FEC_Nature_of_Cases__c = noc.Id,
            FEC_Active__c = true
        );
        insert stage2;

        FEC_CaseTriggerHandler.isExecuting = true;
        Case c;
        try {
            c = new Case(
                Subject = 'COF GSR Non CCSP',
                Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
                FEC_Current_Case_Stage__c = stage1.Id,
                FEC_ID_Search__c = 'COF-NONCC-' + String.valueOf(System.currentTimeMillis())
            );
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Map<String, Object> params = new Map<String, Object>{
            'natureOfCaseId' => (String) noc.Id,
            'remarkContent' => 'auto route remark'
        };

        Test.startTest();
        FEC_CofGsrAssignmentService.handleRouteToCofGsr(c.Id, params, 'Stage 2');
        Test.stopTest();

        Case updatedCase = [SELECT FEC_Current_Case_Stage__c FROM Case WHERE Id = :c.Id];
        Integer assignmentCount = [SELECT COUNT() FROM FEC_Assignment__c WHERE FEC_Case__c = :c.Id];
        System.assertNotEquals(null, updatedCase.FEC_Current_Case_Stage__c, 'Case phải có current stage.');
        System.assert(assignmentCount > 0, 'Nhánh non CC/SP phải tạo assignment tự động.');
    }

    @IsTest
    static void testManualItems_EmptyJson() {
        Case c = insertTestCase('COF GSR Manual Empty');
        User admin = adminUser();

        Test.startTest();
        FEC_CofGsrAssignmentService.createAssignmentsFromManualItems(c.Id, '[]', admin, 'Stage 2');
        Test.stopTest();

        System.assertEquals(
            0,
            [SELECT COUNT() FROM FEC_Assignment__c WHERE FEC_Case__c = :c.Id],
            'JSON rỗng không tạo assignment.'
        );
    }

    // 04/06/2026 17:10 linhdev - gate COF/GSR Assignment trên route() (tránh SOQL 101 Phone Update)
    @IsTest
    static void testShouldCreateAssignmentsOnStandardRoute() {
        FEC_Nature_of_Case__c noc = [SELECT Id FROM FEC_Nature_of_Case__c LIMIT 1];
        Case c = insertTestCase('Route Assignment Gate');
        c = [
            SELECT
                Id,
                FEC_Current_Case_Stage__c,
                FEC_Current_Case_Stage__r.FEC_Business_Process__r.FEC_Code__c
            FROM Case
            WHERE Id = :c.Id
            LIMIT 1
        ];

        System.assertEquals(
            true,
            FEC_CofGsrAssignmentService.shouldCreateAssignmentsOnStandardRoute(c, noc.Id),
            'NOC COF/GSR phải bật luồng Assignment.'
        );
        System.assertEquals(
            false,
            FEC_CofGsrAssignmentService.shouldCreateAssignmentsOnStandardRoute(c, c.Id),
            'Input không phải NOC/Actual NOC phải trả false.'
        );
        System.assertEquals(
            false,
            FEC_CofGsrAssignmentService.shouldCreateAssignmentsOnStandardRoute(c, null),
            'Blank natureOfCaseId và stage không COF phải trả false.'
        );
    }

    @IsTest
    static void testResolveToNocIds() {
        FEC_Nature_of_Case__c noc = [SELECT Id FROM FEC_Nature_of_Case__c LIMIT 1];
        Case c = insertTestCase('COF GSR Resolve');

        Test.startTest();
        Set<Id> fromNoc = FEC_CofGsrAssignmentService.resolveToNocIds(noc.Id);
        Set<Id> fromBlank = FEC_CofGsrAssignmentService.resolveToNocIds(null);
        Set<Id> fromOtherObject = FEC_CofGsrAssignmentService.resolveToNocIds(c.Id);
        Test.stopTest();

        System.assert(fromNoc.contains(noc.Id), 'Từ NOC id phải resolve ra NOC hiện tại.');
        System.assertEquals(0, fromBlank.size(), 'Blank input phải trả rỗng.');
        System.assertEquals(0, fromOtherObject.size(), 'Input object khác NOC phải trả rỗng.');
    }

    @IsTest
    static void testCreateAssignmentsOnRoute_GuardClauses() {
        User admin = adminUser();
        FEC_Nature_of_Case__c noc = [SELECT Id FROM FEC_Nature_of_Case__c LIMIT 1];

        Test.startTest();
        FEC_CofGsrAssignmentService.createAssignmentsOnRoute(
            null,
            new Set<Id>{ noc.Id },
            admin,
            null,
            'Stage 2',
            null
        );
        FEC_CofGsrAssignmentService.createAssignmentsOnRoute(
            '500000000000000AAA',
            new Set<Id>(),
            admin,
            null,
            'Stage 2',
            null
        );
        Test.stopTest();

        System.assert(true, 'Guard clauses được thực thi không exception.');
    }

    @IsTest
    static void testCreateAssignmentsOnRoute_BlankRemark() {
        FEC_Nature_of_Case__c noc = createNocWithRouting('QA2', System.Label.FEC_CC_Queue_Name);
        Case c = insertTestCase('COF GSR Auto Assignment');
        User admin = adminUser();

        Test.startTest();
        FEC_CofGsrAssignmentService.createAssignmentsOnRoute(
            c.Id,
            new Set<Id>{ noc.Id },
            admin,
            null,
            'Stage 2',
            null
        );
        Test.stopTest();

        Integer assignmentCount = [SELECT COUNT() FROM FEC_Assignment__c WHERE FEC_Case__c = :c.Id];
        Integer historyCount = [SELECT COUNT() FROM FEC_Routing_Action_History__c WHERE FEC_Case__c = :c.Id];
        System.assert(assignmentCount > 0, 'createAssignmentsOnRoute phải tạo assignment.');
        System.assert(historyCount > 0, 'createAssignmentsOnRoute phải tạo routing history.');
    }

    @IsTest
    static void testGetRoutingAssignments_FromSiblingNoc() {
        String suffix = String.valueOf(System.currentTimeMillis());
        FEC_Product_Type__c prod = new FEC_Product_Type__c(Name = 'P-' + suffix, FEC_Code__c = 'PX' + suffix.right(6), FEC_Active__c = true);
        insert prod;
        FEC_Category__c cat = new FEC_Category__c(Name = 'C-' + suffix, FEC_Code__c = 'CX' + suffix.right(6), FEC_Active__c = true);
        insert cat;
        FEC_Sub_Category__c subCat = new FEC_Sub_Category__c(Name = 'S-' + suffix, FEC_Code__c = 'SX' + suffix.right(6), FEC_Active__c = true);
        insert subCat;
        FEC_Business_Process__c bp = new FEC_Business_Process__c(Name = 'BPX-' + suffix, FEC_Code__c = 'BX' + suffix.right(6), FEC_Active__c = true);
        insert bp;

        FEC_Nature_of_Case__c primaryNoc = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = prod.Id, FEC_Category__c = cat.Id, FEC_Sub_Category__c = subCat.Id, FEC_Business_Process__c = bp.Id, FEC_Active__c = true
        );
        FEC_Nature_of_Case__c siblingNoc = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = prod.Id, FEC_Category__c = cat.Id, FEC_Sub_Category__c = subCat.Id, FEC_Business_Process__c = bp.Id, FEC_Active__c = true
        );
        insert new List<FEC_Nature_of_Case__c>{ primaryNoc, siblingNoc };

        insert new FEC_Routing_Assignment__c(
            FEC_Nature_of_Cases__c = siblingNoc.Id,
            FEC_Team__c = 'QA3',
            FEC_Queue__c = System.Label.FEC_CC_Queue_Name,
            FEC_Active__c = true
        );

        Test.startTest();
        List<Map<String, String>> result = FEC_CofGsrAssignmentService.getRoutingAssignments(primaryNoc.Id, 'Individual');
        Test.stopTest();

        System.assert(result.size() > 0, 'Phải fallback sang sibling NOC để lấy assignment.');
    }

    @IsTest
    static void testGetRoutingAssignments_FromActualNoc() {
        String suffix = String.valueOf(System.currentTimeMillis());
        FEC_Product_Type__c prod = new FEC_Product_Type__c(Name = 'PA-' + suffix, FEC_Code__c = 'PA' + suffix.right(6), FEC_Active__c = true);
        insert prod;
        FEC_Category__c cat = new FEC_Category__c(Name = 'CA-' + suffix, FEC_Code__c = 'CA' + suffix.right(6), FEC_Active__c = true);
        insert cat;
        FEC_Sub_Category__c subCat = new FEC_Sub_Category__c(Name = 'SA-' + suffix, FEC_Code__c = 'SA' + suffix.right(6), FEC_Active__c = true);
        insert subCat;
        FEC_Business_Process__c bp = new FEC_Business_Process__c(Name = 'BPA-' + suffix, FEC_Code__c = 'BA' + suffix.right(6), FEC_Active__c = true);
        insert bp;

        FEC_Nature_of_Case__c noc = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = prod.Id, FEC_Category__c = cat.Id, FEC_Sub_Category__c = subCat.Id, FEC_Business_Process__c = bp.Id, FEC_Active__c = true
        );
        insert noc;
        insert new FEC_Routing_Assignment__c(
            FEC_Nature_of_Cases__c = noc.Id,
            FEC_Team__c = 'QA4',
            FEC_Queue__c = System.Label.FEC_CC_Queue_Name,
            FEC_Active__c = true
        );

        FEC_Actual_Nature_of_Case__c actualNoc = new FEC_Actual_Nature_of_Case__c(
            FEC_Business_Process__c = bp.Id,
            FEC_Category__c = cat.Id,
            FEC_Sub_Category__c = subCat.Id
        );
        insert actualNoc;

        Test.startTest();
        List<Map<String, String>> result = FEC_CofGsrAssignmentService.getRoutingAssignments(actualNoc.Id, 'Individual');
        Test.stopTest();

        System.assert(result.size() > 0, 'Phải fallback theo Actual NOC để lấy assignment.');
    }
}

@IsTest
private class FEC_AssignMasterPersist_Test {

    private static User testAgent;

    private class TestData {
        Id caseId;
        Id templateNocId;
        Id stageId;
        Id customerHistoryId;
    }

    private static void assignPermissionSetsIfPresent(Id userId, List<String> permissionSetNames) {
        if (permissionSetNames == null || permissionSetNames.isEmpty()) {
            return;
        }
        List<PermissionSet> psList = [
            SELECT Id
            FROM PermissionSet
            WHERE Name IN :permissionSetNames
        ];
        if (psList.isEmpty()) {
            return;
        }
        Set<Id> existing = new Set<Id>();
        for (PermissionSetAssignment psa : [
            SELECT PermissionSetId
            FROM PermissionSetAssignment
            WHERE AssigneeId = :userId
              AND PermissionSetId IN :psList
        ]) {
            existing.add(psa.PermissionSetId);
        }
        List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();
        for (PermissionSet ps : psList) {
            if (!existing.contains(ps.Id)) {
                assignments.add(new PermissionSetAssignment(
                    AssigneeId = userId,
                    PermissionSetId = ps.Id
                ));
            }
        }
        if (!assignments.isEmpty()) {
            insert assignments;
        }
    }

    private static void assignMasterDataPermissions(Id userId) {
        List<String> permissionSetNames = new List<String>{
            'FEC_MDM_Tool_Objects_Access',
            'FEC_Common_System_Setting',
            'FEC_MDM_Full_Field_Access',
            'FEC_CS_CS_Inbound_Specialist_Master_Data_Management',
            'FEC_RD_Payment_User_Master_Data_Management',
            'RD_IT_User_Master_Data_Management'
        };
        for (PermissionSet ps : [
            SELECT Name
            FROM PermissionSet
            WHERE Name LIKE '%Master_Data%'
            LIMIT 15
        ]) {
            if (!permissionSetNames.contains(ps.Name)) {
                permissionSetNames.add(ps.Name);
            }
        }
        assignPermissionSetsIfPresent(userId, permissionSetNames);
    }

    @TestSetup
    static void setupAgent() {
        List<Profile> adminProfiles = [
            SELECT Id
            FROM Profile
            WHERE Name = 'System Administrator'
            LIMIT 1
        ];
        Profile p = adminProfiles.isEmpty()
            ? [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1]
            : adminProfiles[0];
        testAgent = new User(
            Alias = 'ampagt',
            Email = 'amp.agent@test.invalid',
            EmailEncodingKey = 'UTF-8',
            LastName = 'AmpPersistAgent',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = 'amp.agent' + String.valueOf(System.currentTimeMillis()) + '@test.invalid',
            FEC_User_Group__c = 'CC'
        );
        insert testAgent;
        testAgent.FEC_User_Group__c = 'CC';
        update testAgent;
        assignMasterDataPermissions(testAgent.Id);
    }

    private static User prepareTestAgent() {
        User agent = getTestAgent();
        ensureAgentUserGroup(agent);
        return agent;
    }

    private static String assignmentTypeValue() {
        String preferred = 'Assignment';
        Schema.DescribeFieldResult typeDescribe =
            FEC_Master_Data_Setting__c.FEC_Type__c.getDescribe();
        for (Schema.PicklistEntry entry : typeDescribe.getPicklistValues()) {
            if (entry.getValue().equalsIgnoreCase(preferred)) {
                return entry.getValue();
            }
        }
        return preferred;
    }

    private static User getTestAgent() {
        return [
            SELECT Id, FEC_User_Group__c
            FROM User
            WHERE LastName = 'AmpPersistAgent'
            LIMIT 1
        ];
    }

    private static Boolean supportsActualMasterDataPersist() {
        Schema.SObjectType objType =
            Schema.getGlobalDescribe().get('FEC_Actual_Master_Data_Setting__c');
        if (objType == null) {
            return false;
        }
        return objType.getDescribe().fields.getMap().containsKey('FEC_Field_API_Name__c');
    }

    private static void ensureAgentUserGroup(User agent) {
        if (agent == null || String.isNotBlank(agent.FEC_User_Group__c)) {
            return;
        }
        agent.FEC_User_Group__c = 'CC';
        update agent;
    }

    private static Case insertCaseRow(Case c) {
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
        return c;
    }

    private static void insertOpenAssignment(Id caseId) {
        String status;
        for (Schema.PicklistEntry entry :
            FEC_Assignment__c.FEC_Assignment_Status__c.getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                status = entry.getValue();
                break;
            }
        }
        insert new FEC_Assignment__c(
            FEC_Case__c = caseId,
            FEC_Assignment_Name__c = 'AMP Assignment ' + String.valueOf(System.currentTimeMillis()),
            FEC_Assignment_Status__c = status,
            FEC_Assignment_Type__c = FEC_ConstantCommon.ASSIGNMENT_TYPE_ROUTING,
            FEC_Assignment_Owner__c = UserInfo.getUserId()
        );
    }

    private static void ensureCaseAssignmentCount(Id caseId) {
        insertOpenAssignment(caseId);
        Decimal assignmentCount = [
            SELECT FEC_Assignment_Count__c
            FROM Case
            WHERE Id = :caseId
        ].FEC_Assignment_Count__c;
        if (assignmentCount == null || assignmentCount <= 0) {
            insertOpenAssignment(caseId);
        }
    }

    private static Id resolveNatureIdForCase(Id caseId, Id fallbackNocId) {
        Case caseRow = [
            SELECT FEC_Product_Type__c, FEC_Category__c, FEC_SubCategory__c,
                   FEC_SubCode__c, FEC_Customer_Type__c, FEC_Actual_Nature_of_Case__c
            FROM Case
            WHERE Id = :caseId
        ];
        if (String.isNotBlank(caseRow.FEC_Actual_Nature_of_Case__c)) {
            return caseRow.FEC_Actual_Nature_of_Case__c;
        }
        List<String> customerTypes = new List<String>{ 'All' };
        if (String.isNotBlank(caseRow.FEC_Customer_Type__c)) {
            customerTypes.add(caseRow.FEC_Customer_Type__c);
        }
        List<FEC_Nature_of_Case__c> rows = [
            SELECT Id
            FROM FEC_Nature_of_Case__c
            WHERE FEC_Product_Type__c = :caseRow.FEC_Product_Type__c
              AND FEC_Category__c = :caseRow.FEC_Category__c
              AND FEC_Sub_Category__c = :caseRow.FEC_SubCategory__c
              AND FEC_Sub_Code__c = :caseRow.FEC_SubCode__c
              AND FEC_Customer_Type__c IN :customerTypes
              AND FEC_Active__c = TRUE
            LIMIT 1
        ];
        return rows.isEmpty() ? fallbackNocId : rows[0].Id;
    }

    private static String buildFieldValuesJson(List<FEC_AssignmentMasterFieldPersistService.FieldValueInput> inputs) {
        return JSON.serialize(inputs);
    }

    private static FEC_AssignmentMasterFieldPersistService.FieldValueInput fieldInput(
        String objectApiName,
        String fieldApiName,
        String value
    ) {
        FEC_AssignmentMasterFieldPersistService.FieldValueInput input =
            new FEC_AssignmentMasterFieldPersistService.FieldValueInput();
        input.objectApiName = objectApiName;
        input.fieldApiName = fieldApiName;
        input.value = value;
        return input;
    }

    private static void insertAssignmentMasterDataRow(
        Id natureId,
        Id stageId,
        String objectApiName,
        String fieldApiName,
        String label,
        Boolean mandatory,
        Decimal displayOrder
    ) {
        if (supportsActualMasterDataPersist()) {
            insert new FEC_Actual_Master_Data_Setting__c(
                FEC_Actual_Nature_of_Case__c = natureId,
                FEC_Stage_Name__c = stageId,
                FEC_Field_Order_Display__c = displayOrder,
                FEC_Sub_Section_Order__c = 1,
                FEC_Section__c = 'Assignment',
                FEC_Sub_Section__c = 'Assignment List',
                FEC_Type__c = assignmentTypeValue(),
                FEC_Field_Object_Name__c = objectApiName,
                FEC_Field_API_Name__c = fieldApiName,
                FEC_Field_Label_Name__c = label,
                FEC_Field_Status__c = true,
                FEC_Field_Editable__c = true,
                FEC_Editable_User_Group__c = 'CC',
                FEC_Field_Mandatory__c = mandatory
            );
            return;
        }
        insert new FEC_Master_Data_Setting__c(
            FEC_Nature_Of_Case__c = natureId,
            FEC_Stage_Name__c = stageId,
            FEC_Field_Order_Display__c = displayOrder,
            FEC_Sub_Section_Order__c = 1,
            FEC_Section__c = 'Assignment',
            FEC_Sub_Section__c = 'Assignment List',
            FEC_Type__c = assignmentTypeValue(),
            FEC_Field_Object_Name__c = objectApiName,
            FEC_Field_API_Name__c = fieldApiName,
            FEC_Field_Label_Name__c = label,
            FEC_Field_Status__c = true,
            FEC_Field_Editable__c = true,
            FEC_Editable_User_Group__c = 'CC',
            FEC_Field_Mandatory__c = mandatory
        );
    }

    private static TestData createPersistTestData(Boolean mandatorySubject, Boolean withAssignment) {
        String suffix = String.valueOf(System.currentTimeMillis());
        TestData data = new TestData();

        FEC_Business_Process__c bp = new FEC_Business_Process__c(
            Name = 'AMP Persist BP ' + suffix,
            FEC_Code__c = 'AMPBP' + suffix,
            FEC_Active__c = true
        );
        insert bp;

        FEC_Product_Type__c prod = new FEC_Product_Type__c(
            Name = 'AMP PT',
            FEC_Code__c = 'AMPPT' + suffix,
            FEC_Active__c = true
        );
        insert prod;
        FEC_Category__c cat = new FEC_Category__c(
            Name = 'AMP Cat',
            FEC_Code__c = 'AMPCAT' + suffix,
            FEC_Active__c = true
        );
        insert cat;
        FEC_Sub_Category__c subCat = new FEC_Sub_Category__c(
            Name = 'AMP SubCat',
            FEC_Code__c = 'AMPSUB' + suffix,
            FEC_Active__c = true
        );
        insert subCat;
        FEC_Sub_Code__c subCode = new FEC_Sub_Code__c(
            Name = 'AMP SubCode',
            FEC_Code__c = 'AMPSC' + suffix,
            FEC_Active__c = true
        );
        insert subCode;

        FEC_Nature_of_Case__c templateNoc = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = prod.Id,
            FEC_Category__c = cat.Id,
            FEC_Sub_Category__c = subCat.Id,
            FEC_Sub_Code__c = subCode.Id,
            FEC_Customer_Type__c = 'Existing',
            FEC_Business_Process__c = bp.Id,
            FEC_User_Group__c = 'CC',
            FEC_Active__c = true
        );
        insert templateNoc;
        data.templateNocId = templateNoc.Id;

        FEC_Case_Stage__c stage = new FEC_Case_Stage__c(
            Name = 'AMP Stage ' + suffix,
            FEC_Code__c = 'AMPSTG' + suffix,
            FEC_Nature_of_Cases__c = templateNoc.Id,
            FEC_Active__c = true,
            FEC_Business_Process__c = bp.Id,
            FEC_User_Group__c = 'CC'
        );
        insert stage;
        data.stageId = stage.Id;

        Case c = insertCaseRow(new Case(
            Subject = 'AMP Original Subject',
            OwnerId = UserInfo.getUserId(),
            Status = 'New',
            FEC_Product_Type__c = prod.Id,
            FEC_Category__c = cat.Id,
            FEC_SubCategory__c = subCat.Id,
            FEC_SubCode__c = subCode.Id,
            FEC_Customer_Type__c = 'Existing',
            FEC_Current_Case_Stage__c = stage.Id,
            FEC_ID_Search__c = 'AMP-' + suffix
        ));
        data.caseId = c.Id;

        if (withAssignment) {
            ensureCaseAssignmentCount(c.Id);
        }

        FEC_Customer_History__c customer = new FEC_Customer_History__c(
            Name = 'AMP-CUST-' + suffix,
            FEC_Case__c = c.Id,
            FEC_Customer_Type__c = 'Existing',
            FEC_Primary_Phone__c = '0900000001'
        );
        insert customer;
        data.customerHistoryId = customer.Id;
        c.FEC_Account_or_Contract__c = customer.Id;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Id natureIdForMds;
        if (supportsActualMasterDataPersist()) {
            FEC_Actual_Nature_of_Case__c actualNoc = new FEC_Actual_Nature_of_Case__c(
                FEC_Product_Type__c = prod.Id,
                FEC_Category__c = cat.Id,
                FEC_Sub_Category__c = subCat.Id,
                FEC_Sub_Code__c = subCode.Id,
                FEC_Business_Process__c = bp.Id
            );
            insert actualNoc;
            c.FEC_Actual_Nature_of_Case__c = actualNoc.Id;
            FEC_CaseTriggerHandler.isExecuting = true;
            try {
                update c;
            } finally {
                FEC_CaseTriggerHandler.isExecuting = false;
            }
            natureIdForMds = actualNoc.Id;
        } else {
            natureIdForMds = resolveNatureIdForCase(c.Id, templateNoc.Id);
        }
        data.templateNocId = natureIdForMds;

        insertAssignmentMasterDataRow(
            natureIdForMds,
            stage.Id,
            'Case',
            'Subject',
            'Subject Label',
            mandatorySubject,
            1
        );
        insertAssignmentMasterDataRow(
            natureIdForMds,
            stage.Id,
            'FEC_Customer_History__c',
            'FEC_Primary_Phone__c',
            'Primary Phone',
            false,
            2
        );

        return data;
    }

    @IsTest
    static void testPersistOnAssignmentSubmit_guardClauses() {
        Test.startTest();
        FEC_AssignmentMasterFieldPersistService.persistOnAssignmentSubmit(null, '[]');
        FEC_AssignmentMasterFieldPersistService.persistOnAssignmentSubmit(
            UserInfo.getUserId(),
            ''
        );
        Test.stopTest();
        System.assert(true, 'Guard clauses should not throw.');
    }

    @IsTest
    static void testPersistOnAssignmentSubmit_invalidJson() {
        Case c = insertCaseRow(new Case(
            Subject = 'AMP Invalid JSON',
            Status = 'New'
        ));

        Boolean thrown = false;
        Test.startTest();
        try {
            FEC_AssignmentMasterFieldPersistService.persistOnAssignmentSubmit(
                c.Id,
                '{not-valid-json'
            );
        } catch (AuraHandledException e) {
            thrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, thrown, 'Invalid JSON should throw AuraHandledException.');
    }

    @IsTest
    static void testPersistOnAssignmentSubmit_successCaseAndCustomerHistory() {
        System.runAs(prepareTestAgent()) {
            TestData data = createPersistTestData(false, true);
            String json = buildFieldValuesJson(new List<FEC_AssignmentMasterFieldPersistService.FieldValueInput>{
                fieldInput('Case', 'Subject', 'AMP Updated Subject'),
                fieldInput('FEC_Customer_History__c', 'FEC_Primary_Phone__c', '0911111111'),
                fieldInput(null, 'Ignored__c', 'x'),
                fieldInput('Case', '', 'x')
            });

            Test.startTest();
            FEC_AssignmentMasterFieldPersistService.persistOnAssignmentSubmit(data.caseId, json);
            Test.stopTest();

            Case updatedCase = [
                SELECT Subject
                FROM Case
                WHERE Id = :data.caseId
            ];
            System.assertEquals('AMP Updated Subject', updatedCase.Subject);
        }
    }

    @IsTest
    static void testPersistOnAssignmentSubmit_missingMandatoryField() {
        System.runAs(prepareTestAgent()) {
            TestData data = createPersistTestData(true, true);
            String json = buildFieldValuesJson(new List<FEC_AssignmentMasterFieldPersistService.FieldValueInput>{
                fieldInput('FEC_Customer_History__c', 'FEC_Primary_Phone__c', '0922222222')
            });

            Boolean thrown = false;
            Test.startTest();
            try {
                FEC_AssignmentMasterFieldPersistService.persistOnAssignmentSubmit(data.caseId, json);
            } catch (AuraHandledException e) {
                thrown = true;
            }
            Test.stopTest();

            System.assertEquals(true, thrown, 'Missing mandatory field should throw.');
        }
    }

    @IsTest
    static void testPersistOnAssignmentSubmit_emptyListValidatesMandatory() {
        System.runAs(prepareTestAgent()) {
            TestData data = createPersistTestData(true, true);

            Boolean thrown = false;
            Test.startTest();
            try {
                FEC_AssignmentMasterFieldPersistService.persistOnAssignmentSubmit(
                    data.caseId,
                    '[]'
                );
            } catch (AuraHandledException e) {
                thrown = true;
            }
            Test.stopTest();

            System.assertEquals(true, thrown, 'Empty payload should fail mandatory validation.');
        }
    }

    @IsTest
    static void testPersistOnAssignmentSubmit_noAssignmentCount() {
        System.runAs(prepareTestAgent()) {
            TestData data = createPersistTestData(false, false);

            String json = buildFieldValuesJson(new List<FEC_AssignmentMasterFieldPersistService.FieldValueInput>{
                fieldInput('Case', 'Subject', 'Should Not Persist')
            });

            Test.startTest();
            FEC_AssignmentMasterFieldPersistService.persistOnAssignmentSubmit(data.caseId, json);
            Test.stopTest();

            Case after = [SELECT Subject FROM Case WHERE Id = :data.caseId];
            System.assertEquals('AMP Original Subject', after.Subject);
        }
    }

    @IsTest
    static void testPersistOnAssignmentSubmit_skipDisallowedField() {
        System.runAs(prepareTestAgent()) {
            TestData data = createPersistTestData(false, true);
            String json = buildFieldValuesJson(new List<FEC_AssignmentMasterFieldPersistService.FieldValueInput>{
                fieldInput('Case', 'Subject', 'AMP Allowed Update'),
                fieldInput('Case', 'Description', 'Should Be Ignored')
            });

            Test.startTest();
            FEC_AssignmentMasterFieldPersistService.persistOnAssignmentSubmit(data.caseId, json);
            Test.stopTest();

            Case updatedCase = [SELECT Subject, Description FROM Case WHERE Id = :data.caseId];
            System.assertEquals('AMP Allowed Update', updatedCase.Subject);
            System.assertEquals(null, updatedCase.Description);
        }
    }

    @IsTest
    static void testPersistOnAssignmentSubmit_clearAssignmentName() {
        System.runAs(prepareTestAgent()) {
            TestData data = createPersistTestData(false, true);
            insertAssignmentMasterDataRow(
                data.templateNocId,
                data.stageId,
                'FEC_Assignment__c',
                'FEC_Assignment_Name__c',
                'Assignment Name',
                false,
                5
            );
            FEC_Assignment__c assignment = [
                SELECT Id
                FROM FEC_Assignment__c
                WHERE FEC_Case__c = :data.caseId
                LIMIT 1
            ];
            String json = buildFieldValuesJson(new List<FEC_AssignmentMasterFieldPersistService.FieldValueInput>{
                fieldInput('FEC_Assignment__c', 'FEC_Assignment_Name__c', '')
            });

            Boolean thrown = false;
            Test.startTest();
            try {
                FEC_AssignmentMasterFieldPersistService.persistOnAssignmentSubmit(data.caseId, json);
            } catch (Exception e) {
                thrown = true;
            }
            Test.stopTest();

            System.assertEquals(
                true,
                thrown,
                'Clearing required FEC_Assignment_Name__c should fail DML.'
            );
        }
    }

    @IsTest
    static void testPersistOnAssignmentSubmit_assignmentChildObject() {
        System.runAs(prepareTestAgent()) {
            TestData data = createPersistTestData(false, true);
            FEC_Assignment__c assignment = [
                SELECT Id
                FROM FEC_Assignment__c
                WHERE FEC_Case__c = :data.caseId
                LIMIT 1
            ];

            insertAssignmentMasterDataRow(
                data.templateNocId,
                data.stageId,
                'FEC_Assignment__c',
                'FEC_Assignment_Name__c',
                'Assignment Name',
                false,
                4
            );

            String newName = 'AMP Renamed Assignment';
            String json = buildFieldValuesJson(new List<FEC_AssignmentMasterFieldPersistService.FieldValueInput>{
                fieldInput('FEC_Assignment__c', 'FEC_Assignment_Name__c', newName)
            });

            Test.startTest();
            FEC_AssignmentMasterFieldPersistService.persistOnAssignmentSubmit(data.caseId, json);
            Test.stopTest();

            FEC_Assignment__c updatedAssignment = [
                SELECT FEC_Assignment_Name__c
                FROM FEC_Assignment__c
                WHERE Id = :assignment.Id
            ];
            System.assertEquals(newName, updatedAssignment.FEC_Assignment_Name__c);
        }
    }

    @IsTest
    static void testPersistOnAssignmentSubmit_revertContext() {
        System.runAs(prepareTestAgent()) {
            TestData data = createPersistTestData(false, true);
            insert new FEC_Routing_Action_History__c(
                FEC_Case__c = data.caseId,
                FEC_Next_Stage__c = data.stageId,
                FEC_IsReverted__c = true,
                FEC_Routing_Action__c = FEC_CaseBusinessService.REVERT
            );

            String json = buildFieldValuesJson(new List<FEC_AssignmentMasterFieldPersistService.FieldValueInput>{
                fieldInput('Case', 'Subject', 'AMP Revert Context Subject')
            });

            Test.startTest();
            FEC_AssignmentMasterFieldPersistService.persistOnAssignmentSubmit(data.caseId, json);
            Test.stopTest();

            Case updatedCase = [SELECT Subject FROM Case WHERE Id = :data.caseId];
            System.assertEquals('AMP Revert Context Subject', updatedCase.Subject);
        }
    }

    @IsTest
    static void testPersistOnAssignmentSubmit_templateMasterDataFallback() {
        if (supportsActualMasterDataPersist()) {
            System.assert(true, 'Template-only fallback covered when Actual MDS unavailable.');
            return;
        }
        System.runAs(prepareTestAgent()) {
            TestData data = createPersistTestData(false, true);
            String json = buildFieldValuesJson(new List<FEC_AssignmentMasterFieldPersistService.FieldValueInput>{
                fieldInput('Case', 'Subject', 'AMP Template MDS Subject')
            });

            Test.startTest();
            FEC_AssignmentMasterFieldPersistService.persistOnAssignmentSubmit(data.caseId, json);
            Test.stopTest();

            Case updatedCase = [SELECT Subject FROM Case WHERE Id = :data.caseId];
            System.assertEquals('AMP Template MDS Subject', updatedCase.Subject);
        }
    }
}

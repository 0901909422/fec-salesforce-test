/**
 * FEC_CasePayloadBuilderTest
 * ─────────────────────────────────────────────────────────────────────────────
 * Unit tests cho FEC_CasePayloadBuilder (build JSON payload cho case export).
 * ─────────────────────────────────────────────────────────────────────────────
 */
@IsTest
private class FEC_CasePayloadBuilderTest {

    // ══════════════════════════════════════════════════════════════════════════
    // Shared SOQL field list — mirrors fields accessed by buildOne()
    // ══════════════════════════════════════════════════════════════════════════

    private static String CASE_FIELDS = String.join(new List<String>{
        'Id', 'CaseNumber', 'Status', 'CreatedDate', 'LastModifiedDate', 'ClosedDate',
        'CreatedById', 'LastModifiedById', 'OwnerId', 'ParentId', 'RecordTypeId',
        'RecordType.Name',
        // Interaction
        'FEC_External_Interaction_ID__c', 'FEC_Channel__c', 'FEC_Case_Channel__c',
        'FEC_Created_By__c', 'FEC_Created_On__c',
        'FEC_Interaction_Start_On__c', 'FEC_Interaction_End_On__c',
        'FEC_Interaction_Duration__c', 'FEC_Interaction__c',
        'FEC_Interaction_Remarks__c', 'FEC_Interaction_Status__c',
        'FEC_Interaction_ID__c', 'FEC_Interaction_Owner__c',
        'FEC_Interaction_Masked_Phone__c', 'FEC_Genesys_Campaign_Name__c',
        'FEC_Genesys_Campaign__c', 'FEC_Routing_Action__c',
        // Resolved By (User lookup)
        'FEC_Interaction_Resolved_By__c',
        'FEC_Interaction_Resolved_By__r.Id',
        'FEC_Interaction_Resolved_By__r.Name',
        'FEC_Interaction_Resolved_By__r.Username',
        'FEC_Interaction_Resolved_By__r.Email',
        'FEC_Interaction_Resolved_By__r.Phone',
        'FEC_Interaction_Resolved_By__r.FEC_Agent_ID__c',
        'FEC_Interaction_Resolved_By__r.FEC_Default_Queue__c',
        // Customer / Contact
        'FEC_Phone_Number__c', 'FEC_Case_Phone_Number__c', 'FEC_Transcription__c',
        'FEC_KYC_Method__c', 'FEC_Interaction_Subchannel__c',
        'FEC_Other_Subchannel__c', 'FEC_Customer_Name__c', 'FEC_Customer_Type__c',
        'FEC_Customer_Username__c', 'FEC_Phone_Type__c',
        'FEC_Updated_Info_Phone_Type__c', 'FEC_Original_Info_Phone_Type__c',
        'FEC_Original_Info_Phone_Number__c', 'FEC_Updated_Info_Phone_Number__c',
        'FEC_Interaction_Email__c', 'FEC_Email_From__c', 'FEC_Email_CC__c',
        'FEC_Case_Email__c', 'FEC_User_Email_ID__c',
        'FEC_National_ID_Passport_ID__c', 'FEC_CIF_Number__c',
        'FEC_Account_Number__c', 'FEC_Contract_Number__c',
        'FEC_Correct_Contract_Number__c', 'FEC_Account_Contract_Number_Text__c',
        // Account/Contract (FEC_Customer_History__c lookup)
        'FEC_Account_or_Contract__c',
        'FEC_Account_or_Contract__r.Id',
        'FEC_Account_or_Contract__r.Name',
        'FEC_Account_or_Contract__r.FEC_Account_Number__c',
        'FEC_Account_or_Contract__r.FEC_Contract_Number__c',
        'FEC_Account_or_Contract__r.FEC_Customer_Name__c',
        'FEC_Account_or_Contract__r.FEC_CIF_Number__c',
        'FEC_Account_or_Contract__r.FEC_Contract_Status__c',
        'FEC_Account_or_Contract__r.FEC_Contract_Type__c',
        'FEC_Account_or_Contract__r.FEC_Product_Code__c',
        'FEC_Account_or_Contract__r.FEC_Account_Status__c',
        'FEC_Account_or_Contract__r.FEC_Credit_Limit__c',
        'FEC_Account_or_Contract__r.FEC_Current_Balance__c',
        'FEC_Account_or_Contract__r.FEC_OTB__c',
        'FEC_Account_or_Contract__r.FEC_Total_Balance__c',
        'FEC_Account_or_Contract__r.FEC_Date_of_Birth__c',
        'FEC_Account_or_Contract__r.FEC_National_ID_Passport_ID__c',
        'FEC_Account_or_Contract__r.FEC_Primary_Phone__c',
        'FEC_Account_or_Contract__r.FEC_Email__c',
        'FEC_Account_or_Contract__r.FEC_Gender__c',
        'FEC_Account_or_Contract__r.FEC_Card_Number__c',
        'FEC_Account_or_Contract__r.FEC_Card_Type__c',
        'FEC_Account_or_Contract__r.FEC_Expiry_Date__c',
        // Classification lookups (SObject with classMap fields)
        'FEC_Product_Type__c',
        'FEC_Product_Type__r.Id', 'FEC_Product_Type__r.Name',
        'FEC_Product_Type__r.FEC_Code__c', 'FEC_Product_Type__r.FEC_Alias__c',
        'FEC_Product_Type__r.FEC_Name_VN__c', 'FEC_Product_Type__r.FEC_Order__c',
        'FEC_Category__c',
        'FEC_Category__r.Id', 'FEC_Category__r.Name',
        'FEC_Category__r.FEC_Code__c', 'FEC_Category__r.FEC_Alias__c',
        'FEC_Category__r.FEC_Name_VN__c', 'FEC_Category__r.FEC_Order__c',
        'FEC_SubCategory__c',
        'FEC_SubCategory__r.Id', 'FEC_SubCategory__r.Name',
        'FEC_SubCategory__r.FEC_Code__c', 'FEC_SubCategory__r.FEC_Alias__c',
        'FEC_SubCategory__r.FEC_Name_VN__c', 'FEC_SubCategory__r.FEC_Order__c',
        'FEC_SubCode__c',
        'FEC_SubCode__r.Id', 'FEC_SubCode__r.Name',
        'FEC_SubCode__r.FEC_Code__c', 'FEC_SubCode__r.FEC_Alias__c',
        'FEC_SubCode__r.FEC_Name_VN__c', 'FEC_SubCode__r.FEC_Order__c',
        'FEC_New_Category__c',
        'FEC_New_Category__r.Id', 'FEC_New_Category__r.Name',
        'FEC_New_Category__r.FEC_Code__c', 'FEC_New_Category__r.FEC_Alias__c',
        'FEC_New_Category__r.FEC_Name_VN__c', 'FEC_New_Category__r.FEC_Order__c',
        'FEC_New_SubCategory__c',
        'FEC_New_SubCategory__r.Id', 'FEC_New_SubCategory__r.Name',
        'FEC_New_SubCategory__r.FEC_Code__c', 'FEC_New_SubCategory__r.FEC_Alias__c',
        'FEC_New_SubCategory__r.FEC_Name_VN__c', 'FEC_New_SubCategory__r.FEC_Order__c',
        'FEC_New_SubCode__c',
        'FEC_New_SubCode__r.Id', 'FEC_New_SubCode__r.Name',
        'FEC_New_SubCode__r.FEC_Code__c', 'FEC_New_SubCode__r.FEC_Alias__c',
        'FEC_New_SubCode__r.FEC_Name_VN__c', 'FEC_New_SubCode__r.FEC_Order__c',
        // Actual Nature of Case
        'FEC_Actual_Nature_of_Case__c',
        'FEC_Actual_Nature_of_Case__r.Id', 'FEC_Actual_Nature_of_Case__r.Name',
        'FEC_Actual_Nature_of_Case__r.FEC_Customer_Type__c',
        'FEC_Actual_Nature_of_Case__r.FEC_User_Group__c',
        'FEC_Actual_Nature_of_Case__r.FEC_Business_Process__c',
        'FEC_Actual_Nature_of_Case__r.FEC_Business_Process__r.Id',
        'FEC_Actual_Nature_of_Case__r.FEC_Business_Process__r.Name',
        'FEC_Actual_Nature_of_Case__r.FEC_Business_Process__r.FEC_Code__c',
        'FEC_Actual_Nature_of_Case__r.FEC_Business_Process__r.FEC_Alias__c',
        'FEC_Actual_Nature_of_Case__r.FEC_Business_Process__r.FEC_Name_VN__c',
        'FEC_Actual_Nature_of_Case__r.FEC_Business_Process__r.FEC_Order__c',
        // Business Process
        'FEC_Business_Process__c',
        'FEC_Business_Process__r.Id', 'FEC_Business_Process__r.Name',
        'FEC_Business_Process__r.FEC_Code__c', 'FEC_Business_Process__r.FEC_Alias__c',
        'FEC_Business_Process__r.FEC_Name_VN__c', 'FEC_Business_Process__r.FEC_Order__c',
        // Case management
        'FEC_Stage_Name__c', 'FEC_Complain_Type__c', 'FEC_Service_Case_Owner__c',
        'FEC_Final_Status__c', 'FEC_Task__c', 'FEC_Team__c',
        'FEC_Completed_User__c', 'FEC_Follow_Up_User__c',
        'FEC_Is_Submited__c', 'FEC_Is_Save_Closed__c', 'FEC_FCR__c',
        'FEC_Has_Account_or_Contract__c', 'EntitlementId',
        // SLA
        'FEC_SLA_Violating_Warning__c', 'FEC_SLA_Warning__c',
        'FEC_SLA_Notification_1__c', 'FEC_SLA_Notification_2__c', 'FEC_SLA_Notification_3__c',
        // Audit
        'FEC_Case_Created_On__c', 'FEC_Case_Created_By__c',
        'FEC_Last_Updated_On__c', 'FEC_Last_Updated_By__c', 'FEC_Case_ID__c',
        // D2C
        'FEC_CS_D2C_Assessment_Type__c', 'FEC_CS_D2C_Risk_Level__c',
        'FEC_Outcome_Code__c', 'FEC_Application_ID__c'
    }, ', ');

    // ══════════════════════════════════════════════════════════════════════════
    // Test data helpers
    // ══════════════════════════════════════════════════════════════════════════

    private static Case createTestCase() {
        Case c = new Case(Status = 'Closed', Subject = 'Test Payload');
        insert c;
        return Database.query('SELECT ' + CASE_FIELDS + ' FROM Case WHERE Id = \'' + c.Id + '\'');
    }

    private static List<Case> createTestCases(Integer count) {
        List<Case> cases = new List<Case>();
        for (Integer i = 0; i < count; i++) {
            cases.add(new Case(Status = 'Closed', Subject = 'Batch ' + i));
        }
        insert cases;
        Set<Id> caseIds = new Map<Id, Case>(cases).keySet();
        return Database.query('SELECT ' + CASE_FIELDS + ' FROM Case WHERE Id IN :caseIds');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Tests
    // ══════════════════════════════════════════════════════════════════════════

    @IsTest
    static void testBuildOne_BasicFields() {
        Case c = createTestCase();
        Map<Id, User> usersById = new Map<Id, User>([
            SELECT Id, Name, Username, Email, Phone, FEC_Agent_ID__c, FEC_Default_Queue__c
            FROM User WHERE Id = :UserInfo.getUserId()
        ]);

        Test.startTest();
        Map<String, Object> result = FEC_CasePayloadBuilder.buildOne(
            c,
            new List<FEC_Case_Remarks__c>(),
            new List<FEC_ChatHistory__c>(),
            usersById
        );
        Test.stopTest();

        System.assertEquals(c.Id, result.get('Id'), 'Id should match');
        System.assertEquals(c.CaseNumber, result.get('CaseNumber'), 'CaseNumber should match');
        System.assertEquals('Closed', result.get('Status'), 'Status should be Closed');
        System.assertNotEquals(null, result.get('CreatedDate'), 'CreatedDate should not be null');
    }

    @IsTest
    static void testBuildBatch_MultipleCases() {
        List<Case> cases = createTestCases(3);

        Map<Id, User> usersById = new Map<Id, User>([
            SELECT Id, Name, Username, Email, Phone, FEC_Agent_ID__c, FEC_Default_Queue__c
            FROM User WHERE Id = :UserInfo.getUserId()
        ]);
        Map<Id, List<FEC_Case_Remarks__c>> remarksMap = new Map<Id, List<FEC_Case_Remarks__c>>();
        Map<Id, List<FEC_ChatHistory__c>> chatsMap = new Map<Id, List<FEC_ChatHistory__c>>();

        Test.startTest();
        String jsonResult = FEC_CasePayloadBuilder.buildBatch(cases, remarksMap, chatsMap, usersById);
        Test.stopTest();

        List<Object> parsed = (List<Object>) JSON.deserializeUntyped(jsonResult);
        System.assertEquals(3, parsed.size(), 'Should serialize 3 cases');
    }

    @IsTest
    static void testBuildOne_WithNullRelationships() {
        Case c = createTestCase();
        Map<Id, User> emptyUsersById = new Map<Id, User>();

        Test.startTest();
        Map<String, Object> result = FEC_CasePayloadBuilder.buildOne(
            c,
            null,
            null,
            emptyUsersById
        );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null even with empty user map');
        System.assertEquals(null, result.get('CreatedBy'), 'CreatedBy should be null when user not in map');
    }

    @IsTest
    static void testBuildBatch_EmptyList() {
        Map<Id, User> usersById = new Map<Id, User>();
        Map<Id, List<FEC_Case_Remarks__c>> remarksMap = new Map<Id, List<FEC_Case_Remarks__c>>();
        Map<Id, List<FEC_ChatHistory__c>> chatsMap = new Map<Id, List<FEC_ChatHistory__c>>();

        Test.startTest();
        String jsonResult = FEC_CasePayloadBuilder.buildBatch(
            new List<Case>(), remarksMap, chatsMap, usersById
        );
        Test.stopTest();

        List<Object> parsed = (List<Object>) JSON.deserializeUntyped(jsonResult);
        System.assertEquals(0, parsed.size(), 'Empty case list should produce empty JSON array');
    }
}

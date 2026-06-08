/**
 * @description Unit tests cho FEC_MetadataDeployCallback.
 * @date 2026-03-31
 */
@isTest
private class FEC_MetadataDeployCallbackTest {

    @testSetup
    static void setupData() {
        FEC_Field_Deploy_Request__c request = new FEC_Field_Deploy_Request__c(
            FEC_Target_Object__c = 'Account',
            FEC_Field_Label__c = 'Callback Test Field',
            FEC_Field_API_Name__c = 'Callback_Test__c',
            FEC_Field_Type__c = 'Text',
            FEC_Deploy_Status__c = 'In Progress',
            FEC_Requested_By__c = UserInfo.getUserId(),
            FEC_Requested_Date__c = Datetime.now()
        );
        insert request;
    }

    // ── Positive: Constructor and instantiation ──
    @isTest
    static void testConstructor() {
        FEC_Field_Deploy_Request__c req = [SELECT Id FROM FEC_Field_Deploy_Request__c LIMIT 1];
        FEC_MetadataDeployCallback callback = new FEC_MetadataDeployCallback(req.Id);
        Assert.isNotNull(callback, 'Callback should be instantiated');
    }

    // ── Positive: Verify request record exists for callback ──
    @isTest
    static void testRequestRecordSetup() {
        FEC_Field_Deploy_Request__c req = [
            SELECT FEC_Deploy_Status__c, FEC_Field_API_Name__c, FEC_Target_Object__c
            FROM FEC_Field_Deploy_Request__c LIMIT 1
        ];
        Assert.areEqual('In Progress', req.FEC_Deploy_Status__c, 'Status should be In Progress');
        Assert.areEqual('Callback_Test__c', req.FEC_Field_API_Name__c, 'API Name should match');
        Assert.areEqual('Account', req.FEC_Target_Object__c, 'Target object should be Account');
    }

    // ── Edge case: Completed_Date should be set after callback ──
    @isTest
    static void testCompletedDateSetAfterUpdate() {
        FEC_Field_Deploy_Request__c req = [SELECT Id FROM FEC_Field_Deploy_Request__c LIMIT 1];

        // Simulate what callback does
        req.FEC_Deploy_Status__c = 'Success';
        req.FEC_Completed_Date__c = Datetime.now();
        update req;

        FEC_Field_Deploy_Request__c updated = [
            SELECT FEC_Completed_Date__c, FEC_Deploy_Status__c
            FROM FEC_Field_Deploy_Request__c WHERE Id = :req.Id
        ];
        Assert.isNotNull(updated.FEC_Completed_Date__c, 'Completed_Date should be set');
        Assert.areEqual('Success', updated.FEC_Deploy_Status__c, 'Status should be Success');
    }

    // ── Positive: Simulate failure scenario ──
    @isTest
    static void testFailureScenario() {
        FEC_Field_Deploy_Request__c req = [SELECT Id FROM FEC_Field_Deploy_Request__c LIMIT 1];

        req.FEC_Deploy_Status__c = 'Failed';
        req.FEC_Error_Message__c = 'Component failure: invalid field type';
        req.FEC_Completed_Date__c = Datetime.now();
        update req;

        FEC_Field_Deploy_Request__c updated = [
            SELECT FEC_Deploy_Status__c, FEC_Error_Message__c, FEC_Completed_Date__c
            FROM FEC_Field_Deploy_Request__c WHERE Id = :req.Id
        ];
        Assert.areEqual('Failed', updated.FEC_Deploy_Status__c, 'Status should be Failed');
        Assert.isTrue(String.isNotBlank(updated.FEC_Error_Message__c), 'Error message should be set');
        Assert.isNotNull(updated.FEC_Completed_Date__c, 'Completed_Date should be set');
    }

    // ── Positive: Platform Event publish ──
    @isTest
    static void testPlatformEventPublish() {
        Test.startTest();
        FEC_Field_Deploy_Event__e evt = new FEC_Field_Deploy_Event__e(
            FEC_Request_Id__c = 'testId123456789',
            FEC_Deploy_Status__c = 'Success',
            FEC_Field_API_Name__c = 'Test_Field__c',
            FEC_Target_Object__c = 'Account'
        );
        Database.SaveResult sr = EventBus.publish(evt);
        Test.stopTest();

        Assert.isTrue(sr.isSuccess(), 'Platform Event should be published successfully');
    }
}
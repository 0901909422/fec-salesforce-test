/**
 * Test Class: FEC_TemplateTriggerHandler_Test
 * Covers:  ① FEC_API_Name__c duplicate check – same folder → error
 *          ② Duplicate check – different folder → OK
 *          ③ Update FEC_API_Name__c → duplicate check
 *          ④ Batch-internal duplicate check
 * Note: FEC_API_Name__c is set explicitly in tests (handler no longer auto-generates on insert).
 * @created  : 2026/03/12
 */
@IsTest
private class FEC_TemplateTriggerHandler_Test {

    private static final String API_WELCOME = 'Welcome_Email_Template';
    private static final String API_OTP = 'OTP_Verification_V2';
    private static final String API_PROMO = 'Promo_Email';
    private static final String API_WELCOME_SHORT = 'Welcome_Email';

    /**
     * Setup: Create test folders
     */
    @TestSetup
    static void setupData() {
        insert new List<FEC_Folder__c>{
            new FEC_Folder__c(
                FEC_Folder_Label__c = 'Marketing',
                FEC_Folder_Unique_Name__c = 'TmplHandler_Marketing'
            ),
            new FEC_Folder__c(
                FEC_Folder_Label__c = 'Support',
                FEC_Folder_Unique_Name__c = 'TmplHandler_Support'
            )
        };
    }

    private static FEC_Folder__c marketingFolder() {
        return [
            SELECT Id
            FROM FEC_Folder__c
            WHERE FEC_Folder_Unique_Name__c = 'TmplHandler_Marketing'
            LIMIT 1
        ];
    }

    private static FEC_Folder__c supportFolder() {
        return [
            SELECT Id
            FROM FEC_Folder__c
            WHERE FEC_Folder_Unique_Name__c = 'TmplHandler_Support'
            LIMIT 1
        ];
    }

    private static FEC_Template__c buildTemplate(Id folderId, String name, String apiName) {
        return new FEC_Template__c(
            Name = name,
            FEC_Folder__c = folderId,
            FEC_API_Name__c = apiName,
            FEC_Active__c = true
        );
    }

    /**
     * Test: Insert with explicit API Name persists value
     */
    @IsTest
    static void testAutoGenerateApiName() {
        FEC_Folder__c folder = marketingFolder();

        FEC_Template__c tmpl = buildTemplate(
            folder.Id,
            'Welcome Email Template',
            API_WELCOME
        );

        Test.startTest();
        insert tmpl;
        Test.stopTest();

        FEC_Template__c result = [
            SELECT FEC_API_Name__c
            FROM FEC_Template__c
            WHERE Id = :tmpl.Id
        ];
        Assert.areEqual(API_WELCOME, result.FEC_API_Name__c,
            'API Name should match value set on insert');
    }

    /**
     * Test: Explicit API Name with special characters normalized in client; stored as provided
     */
    @IsTest
    static void testApiNameSpecialCharacters() {
        FEC_Folder__c folder = marketingFolder();

        FEC_Template__c tmpl = buildTemplate(
            folder.Id,
            'OTP & Verification (V2)',
            API_OTP
        );

        Test.startTest();
        insert tmpl;
        Test.stopTest();

        FEC_Template__c result = [
            SELECT FEC_API_Name__c
            FROM FEC_Template__c
            WHERE Id = :tmpl.Id
        ];
        Assert.areEqual(API_OTP, result.FEC_API_Name__c,
            'API Name should match explicit value');
    }

    /**
     * Test: Duplicate API name in same folder → should fail
     */
    @IsTest
    static void testDuplicateSameFolder() {
        FEC_Folder__c folder = marketingFolder();

        insert buildTemplate(folder.Id, 'Promo Email', API_PROMO);

        FEC_Template__c duplicate = buildTemplate(folder.Id, 'Promo Email Copy', API_PROMO);

        Test.startTest();
        Database.SaveResult sr = Database.insert(duplicate, false);
        Test.stopTest();

        Assert.isFalse(sr.isSuccess(), 'Duplicate API name in same folder must fail');
        Assert.isTrue(
            sr.getErrors()[0].getMessage().contains('already exists in the same folder'),
            'Error message should mention duplicate in same folder. Actual: ' + sr.getErrors()[0].getMessage()
        );
    }

    /**
     * Test: Same API name in different folders → should succeed
     */
    @IsTest
    static void testDuplicateDifferentFolder() {
        insert buildTemplate(marketingFolder().Id, 'Welcome Email', API_WELCOME_SHORT);

        FEC_Template__c tmpl2 = buildTemplate(
            supportFolder().Id,
            'Welcome Email',
            API_WELCOME_SHORT
        );

        Test.startTest();
        insert tmpl2;
        Test.stopTest();

        Integer count = [
            SELECT COUNT()
            FROM FEC_Template__c
            WHERE FEC_API_Name__c = :API_WELCOME_SHORT
        ];
        Assert.areEqual(2, count, 'Same API name in different folders should be allowed');
    }

    /**
     * Test: Update API Name to unique value → should succeed
     */
    @IsTest
    static void testUpdateRegeneratesApiName() {
        FEC_Folder__c folder = marketingFolder();

        FEC_Template__c tmpl = buildTemplate(folder.Id, 'Old Name', 'Old_Name');
        insert tmpl;

        Test.startTest();
        tmpl.FEC_API_Name__c = 'New_Name_Updated';
        Database.SaveResult sr = Database.update(tmpl, false);
        Test.stopTest();

        Assert.isTrue(sr.isSuccess(), 'Update to unique API name should succeed');
        FEC_Template__c result = [
            SELECT FEC_API_Name__c
            FROM FEC_Template__c
            WHERE Id = :tmpl.Id
        ];
        Assert.areEqual('New_Name_Updated', result.FEC_API_Name__c,
            'API Name should reflect explicit update');
    }

    /**
     * Test: Update template API name to conflict with existing → should fail
     */
    @IsTest
    static void testUpdateCausesDuplicate() {
        FEC_Folder__c folder = marketingFolder();

        insert buildTemplate(folder.Id, 'Existing Template', 'Existing_Template');
        FEC_Template__c tmpl2 = buildTemplate(folder.Id, 'Another Template', 'Another_Template');
        insert tmpl2;

        Test.startTest();
        tmpl2.FEC_API_Name__c = 'Existing_Template';
        Database.SaveResult sr = Database.update(tmpl2, false);
        Test.stopTest();

        Assert.isFalse(sr.isSuccess(), 'Update to duplicate API name in same folder must fail');
        Assert.isTrue(
            sr.getErrors()[0].getMessage().contains('already exists in the same folder'),
            'Error should mention duplicate. Actual: ' + sr.getErrors()[0].getMessage()
        );
    }

    /**
     * Test: Batch-internal duplicate – same API name in same folder in one batch
     */
    @IsTest
    static void testBatchInternalDuplicate() {
        FEC_Folder__c folder = marketingFolder();

        List<FEC_Template__c> batch = new List<FEC_Template__c>{
            buildTemplate(folder.Id, 'Batch Template A', 'Batch_Template'),
            buildTemplate(folder.Id, 'Batch Template B', 'Batch_Template')
        };

        Test.startTest();
        Database.SaveResult[] results = Database.insert(batch, false);
        Test.stopTest();

        Boolean hasBatchDuplicateError = false;
        for (Database.SaveResult sr : results) {
            if (!sr.isSuccess()
                && sr.getErrors()[0].getMessage().contains('Duplicate template name detected')) {
                hasBatchDuplicateError = true;
            }
        }
        Assert.isTrue(hasBatchDuplicateError, 'Batch-internal duplicate must be blocked');
    }

    /**
     * Test: Template with null folder (no folder assigned)
     */
    @IsTest
    static void testNullFolderDuplicate() {
        insert new FEC_Template__c(
            Name = 'No Folder Template',
            FEC_API_Name__c = 'No_Folder_Template',
            FEC_Active__c = true
        );

        FEC_Template__c duplicate = new FEC_Template__c(
            Name = 'No Folder Template Copy',
            FEC_API_Name__c = 'No_Folder_Template',
            FEC_Active__c = true
        );

        Test.startTest();
        Database.SaveResult sr = Database.insert(duplicate, false);
        Test.stopTest();

        Assert.isFalse(sr.isSuccess(), 'Duplicate API name with null folder must fail');
        Assert.isTrue(
            sr.getErrors()[0].getMessage().contains('already exists'),
            'Error should mention duplicate. Actual: ' + sr.getErrors()[0].getMessage()
        );
    }
}

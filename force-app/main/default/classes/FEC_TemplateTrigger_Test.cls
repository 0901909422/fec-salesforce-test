/**
 * Unit tests for FEC_TemplateTrigger (before insert/update — duplicate API name per folder).
 */
@IsTest
private class FEC_TemplateTrigger_Test {

    private static final String API_WELCOME = 'Welcome_Email';
    private static final String API_PROMO = 'Promo_Email';

    @TestSetup
    static void setupData() {
        insert new List<FEC_Folder__c>{
            new FEC_Folder__c(
                FEC_Folder_Label__c = 'Template Trigger Marketing',
                FEC_Folder_Unique_Name__c = 'TmplTrig_Marketing'
            ),
            new FEC_Folder__c(
                FEC_Folder_Label__c = 'Template Trigger Support',
                FEC_Folder_Unique_Name__c = 'TmplTrig_Support'
            )
        };
    }

    private static FEC_Folder__c marketingFolder() {
        return [
            SELECT Id
            FROM FEC_Folder__c
            WHERE FEC_Folder_Unique_Name__c = 'TmplTrig_Marketing'
            LIMIT 1
        ];
    }

    private static FEC_Folder__c supportFolder() {
        return [
            SELECT Id
            FROM FEC_Folder__c
            WHERE FEC_Folder_Unique_Name__c = 'TmplTrig_Support'
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

    @IsTest
    static void testBeforeInsert_AllowsUniqueApiNameInFolder() {
        FEC_Folder__c folder = marketingFolder();

        Test.startTest();
        FEC_Template__c tmpl = buildTemplate(folder.Id, 'Welcome', API_WELCOME);
        insert tmpl;
        Test.stopTest();

        System.assertEquals(
            1,
            [SELECT COUNT() FROM FEC_Template__c WHERE Id = :tmpl.Id]
        );
    }

    @IsTest
    static void testBeforeInsert_BlocksDuplicateApiNameInSameFolder() {
        FEC_Folder__c folder = marketingFolder();
        insert buildTemplate(folder.Id, 'Promo A', API_PROMO);

        FEC_Template__c duplicate = buildTemplate(folder.Id, 'Promo B', API_PROMO);

        Test.startTest();
        Database.SaveResult sr = Database.insert(duplicate, false);
        Test.stopTest();

        System.assert(!sr.isSuccess(), 'Duplicate API name in same folder must be blocked.');
        System.assert(
            sr.getErrors()[0].getMessage().contains('already exists in the same folder'),
            sr.getErrors()[0].getMessage()
        );
    }

    @IsTest
    static void testBeforeInsert_AllowsSameApiNameInDifferentFolders() {
        insert buildTemplate(marketingFolder().Id, 'Welcome Mkt', API_WELCOME);

        FEC_Template__c supportTemplate = buildTemplate(
            supportFolder().Id,
            'Welcome Support',
            API_WELCOME
        );

        Test.startTest();
        Database.SaveResult sr = Database.insert(supportTemplate, false);
        Test.stopTest();

        System.assert(sr.isSuccess(), 'Same API name in different folders should be allowed.');
        System.assertEquals(
            2,
            [SELECT COUNT() FROM FEC_Template__c WHERE FEC_API_Name__c = :API_WELCOME]
        );
    }

    @IsTest
    static void testBeforeUpdate_BlocksDuplicateWhenApiNameChanged() {
        FEC_Folder__c folder = marketingFolder();
        insert buildTemplate(folder.Id, 'Existing', 'Existing_Api');
        FEC_Template__c other = buildTemplate(folder.Id, 'Other', 'Other_Api');
        insert other;

        other.FEC_API_Name__c = 'Existing_Api';

        Test.startTest();
        Database.SaveResult sr = Database.update(other, false);
        Test.stopTest();

        System.assert(!sr.isSuccess(), 'Update to conflicting API name must be blocked.');
    }

    @IsTest
    static void testBeforeUpdate_AllowsSelfUpdateWithSameApiName() {
        FEC_Folder__c folder = marketingFolder();
        FEC_Template__c tmpl = buildTemplate(folder.Id, 'Self Update', API_WELCOME);
        insert tmpl;

        tmpl.FEC_Body__c = '<p>Updated body</p>';

        Test.startTest();
        Database.SaveResult sr = Database.update(tmpl, false);
        Test.stopTest();

        System.assert(sr.isSuccess(), 'Self update without API/folder change should succeed.');
    }

    @IsTest
    static void testBeforeInsert_BatchInternalDuplicate() {
        FEC_Folder__c folder = marketingFolder();
        List<FEC_Template__c> batch = new List<FEC_Template__c>{
            buildTemplate(folder.Id, 'Batch A', 'Batch_Dup'),
            buildTemplate(folder.Id, 'Batch B', 'Batch_Dup')
        };

        Test.startTest();
        Database.SaveResult[] results = Database.insert(batch, false);
        Test.stopTest();

        System.assertEquals(2, results.size());
        Boolean hasBatchDuplicateError = false;
        for (Database.SaveResult sr : results) {
            if (!sr.isSuccess()
                && sr.getErrors()[0].getMessage().contains('Duplicate template name detected')) {
                hasBatchDuplicateError = true;
            }
        }
        System.assert(hasBatchDuplicateError, 'Batch-internal duplicate must be blocked.');
    }

    @IsTest
    static void testBeforeInsert_NullFolderDuplicate() {
        insert new FEC_Template__c(
            Name = 'No Folder A',
            FEC_API_Name__c = 'No_Folder_Api',
            FEC_Active__c = true
        );

        FEC_Template__c duplicate = new FEC_Template__c(
            Name = 'No Folder B',
            FEC_API_Name__c = 'No_Folder_Api',
            FEC_Active__c = true
        );

        Test.startTest();
        Database.SaveResult sr = Database.insert(duplicate, false);
        Test.stopTest();

        System.assert(!sr.isSuccess(), 'Duplicate API name with null folder must be blocked.');
    }
}

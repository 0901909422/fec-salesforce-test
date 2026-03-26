/**
 * Test Class: FEC_TemplateService_Test
 * Covers Service-layer logic for templates: CRUD, content-history tracking,
 * merge-field extraction, and attachment retrieval.
 * @created  : 2026/03/12
 */
@IsTest
private class FEC_TemplateService_Test {

    @TestSetup
    static void setupData() {
        FEC_Folder__c folder = new FEC_Folder__c(FEC_Folder_Label__c = 'TestFolder');
        insert folder;

        FEC_Template__c tmpl = new FEC_Template__c(
            FEC_Template_Name__c = 'Service Test Template',
            FEC_Folder__c = folder.Id,
            FEC_Active__c = true,
            FEC_Subject_Line__c = 'Hello',
            FEC_Body__c = '<p>Original body</p>'
        );
        insert tmpl;
    }

    @IsTest
    static void testGetTemplate() {
        FEC_Template__c tmpl = [SELECT Id FROM FEC_Template__c LIMIT 1];

        Test.startTest();
        FEC_Template__c result = FEC_TemplateService.getTemplate(tmpl.Id);
        Test.stopTest();

        Assert.isNotNull(result);
        Assert.areEqual('Service Test Template', result.FEC_Template_Name__c);
    }

    @IsTest
    static void testGetTemplatesNoFilter() {
        Test.startTest();
        List<FEC_Template__c> results = FEC_TemplateService.getTemplates(null, null, false);
        Test.stopTest();

        Assert.areEqual(1, results.size());
    }

    @IsTest
    static void testSaveTemplateInsert() {
        FEC_Folder__c folder = [SELECT Id FROM FEC_Folder__c LIMIT 1];

        FEC_Template__c newTmpl = new FEC_Template__c(
            FEC_Template_Name__c = 'Brand New Template',
            FEC_Folder__c = folder.Id,
            FEC_Active__c = false,
            FEC_Body__c = '<p>New body</p>'
        );

        Test.startTest();
        Id savedId = FEC_TemplateService.saveTemplate(newTmpl, null);
        Test.stopTest();

        Assert.isNotNull(savedId, 'Should return saved record Id');
        FEC_Template__c saved = [SELECT FEC_Template_Name__c FROM FEC_Template__c WHERE Id = :savedId];
        Assert.areEqual('Brand New Template', saved.FEC_Template_Name__c);
    }

    @IsTest
    static void testSaveTemplateUpdateWithBodyChange() {
        FEC_Template__c tmpl = [SELECT Id, FEC_Body__c FROM FEC_Template__c LIMIT 1];
        String oldBody = tmpl.FEC_Body__c;
        tmpl.FEC_Body__c = '<p>Dear {{{Contact.FirstName}}}, updated body with {{{Organization.Name}}}</p>';

        Test.startTest();
        FEC_TemplateService.saveTemplate(tmpl, oldBody);
        Test.stopTest();

        // Verify content-history was created
        List<FEC_Content_History_Tracking__c> histories = [
            SELECT FEC_Original_Value__c, FEC_New_Value__c, FEC_Merge_Fields_Used__c
            FROM FEC_Content_History_Tracking__c
            WHERE FEC_Template__c = :tmpl.Id
        ];
        Assert.areEqual(1, histories.size(), 'Should create 1 content history record');
        Assert.areEqual(oldBody, histories[0].FEC_Original_Value__c);
        Assert.isTrue(
            histories[0].FEC_Merge_Fields_Used__c.contains('{{{Contact.FirstName}}}'),
            'Should extract merge fields from new body'
        );
    }

    @IsTest
    static void testSaveTemplateUpdateNoBodyChange() {
        FEC_Template__c tmpl = [SELECT Id, FEC_Body__c, FEC_Subject_Line__c FROM FEC_Template__c LIMIT 1];
        String oldBody = tmpl.FEC_Body__c;
        tmpl.FEC_Subject_Line__c = 'Updated Subject Only';

        Test.startTest();
        FEC_TemplateService.saveTemplate(tmpl, oldBody);
        Test.stopTest();

        // No content history should be created when body didn't change
        Integer historyCount = [
            SELECT COUNT()
            FROM FEC_Content_History_Tracking__c
            WHERE FEC_Template__c = :tmpl.Id
        ];
        Assert.areEqual(0, historyCount, 'No history when body unchanged');
    }

    @IsTest
    static void testDeleteTemplate() {
        FEC_Template__c tmpl = [SELECT Id FROM FEC_Template__c LIMIT 1];

        Test.startTest();
        FEC_TemplateService.deleteTemplate(tmpl.Id);
        Test.stopTest();

        Integer count = [SELECT COUNT() FROM FEC_Template__c WHERE Id = :tmpl.Id];
        Assert.areEqual(0, count, 'Template should be deleted');
    }

    @IsTest
    static void testGetAttachments() {
        FEC_Template__c tmpl = [SELECT Id FROM FEC_Template__c LIMIT 1];

        // Create a ContentVersion (which auto-creates ContentDocument)
        ContentVersion cv = new ContentVersion(
            Title = 'TestFile',
            PathOnClient = 'TestFile.pdf',
            VersionData = Blob.valueOf('test file content')
        );
        insert cv;

        // Get the auto-created ContentDocumentId
        cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];

        // Link it to the template
        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = cv.ContentDocumentId,
            LinkedEntityId = tmpl.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert cdl;

        Test.startTest();
        List<ContentDocumentLink> results = FEC_TemplateService.getAttachments(tmpl.Id);
        Test.stopTest();

        Assert.areEqual(1, results.size(), 'Should return 1 attachment');
        Assert.areEqual('TestFile', results[0].ContentDocument.Title);
    }

    @IsTest
    static void testExtractMergeFields() {
        String body = '<p>Hi {{{Contact.FirstName}}}, your org is {{{Organization.Name}}}. Code: {{{Case.OTP__c}}}</p>';

        Test.startTest();
        String result = FEC_TemplateService.extractMergeFields(body);
        Test.stopTest();

        Assert.isTrue(result.contains('{{{Contact.FirstName}}}'), 'Should contain Contact.FirstName');
        Assert.isTrue(result.contains('{{{Organization.Name}}}'), 'Should contain Organization.Name');
        Assert.isTrue(result.contains('{{{Case.OTP__c}}}'), 'Should contain Case.OTP__c');
    }

    @IsTest
    static void testExtractMergeFieldsEmpty() {
        Test.startTest();
        String result = FEC_TemplateService.extractMergeFields('<p>No merge fields here</p>');
        Test.stopTest();

        Assert.areEqual('', result, 'Should return empty string when no merge fields');
    }
}
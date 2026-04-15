/**
 * Test Class: FEC_TemplateController_Test
 * Covers @AuraEnabled controller methods for templates.
 * @created  : 2026/03/12
 */
@IsTest
private class FEC_TemplateController_Test {

    @TestSetup
    static void setupData() {
        FEC_Folder__c folder = new FEC_Folder__c(FEC_Folder_Label__c = 'ControllerTestFolder');
        insert folder;

        FEC_Template__c tmpl = new FEC_Template__c(
            Name = 'Controller Test Template',
            FEC_Folder__c = folder.Id,
            FEC_Active__c = true,
            FEC_Subject_Line__c = 'Test Subject',
            FEC_Body__c = '<p>Test body</p>'
        );
        insert tmpl;
    }

    @IsTest
    static void testGetTemplate() {
        FEC_Template__c tmpl = [SELECT Id FROM FEC_Template__c LIMIT 1];

        Test.startTest();
        FEC_Template__c result = FEC_TemplateController.getTemplate(tmpl.Id);
        Test.stopTest();

        Assert.isNotNull(result);
        Assert.areEqual('Controller Test Template', result.Name);
    }

    @IsTest
    static void testGetTemplates() {
        Test.startTest();
        List<FEC_Template__c> results = FEC_TemplateController.getTemplates(null, null, false);
        Test.stopTest();

        Assert.areEqual(1, results.size());
    }

    @IsTest
    static void testSaveTemplate() {
        FEC_Folder__c folder = [SELECT Id FROM FEC_Folder__c LIMIT 1];

        FEC_Template__c newTmpl = new FEC_Template__c(
            Name = 'New Via Controller',
            FEC_Folder__c = folder.Id,
            FEC_Active__c = false
        );

        String json = JSON.serialize(newTmpl);

        Test.startTest();
        Id savedId = FEC_TemplateController.saveTemplate(json, null);
        Test.stopTest();

        Assert.isNotNull(savedId);
        FEC_Template__c saved = [SELECT Name FROM FEC_Template__c WHERE Id = :savedId];
        Assert.areEqual('New Via Controller', saved.Name);
    }

    @IsTest
    static void testDeleteTemplate() {
        FEC_Template__c tmpl = [SELECT Id FROM FEC_Template__c LIMIT 1];

        Test.startTest();
        FEC_TemplateController.deleteTemplate(tmpl.Id);
        Test.stopTest();

        Integer count = [SELECT COUNT() FROM FEC_Template__c WHERE Id = :tmpl.Id];
        Assert.areEqual(0, count);
    }

    @IsTest
    static void testGetAttachments() {
        FEC_Template__c tmpl = [SELECT Id FROM FEC_Template__c LIMIT 1];

        Test.startTest();
        List<ContentDocumentLink> results = FEC_TemplateController.getAttachments(tmpl.Id);
        Test.stopTest();

        // No attachments in test setup → empty list
        Assert.isNotNull(results);
        Assert.areEqual(0, results.size());
    }

    @IsTest
    static void testGetContentHistory() {
        FEC_Template__c tmpl = [SELECT Id FROM FEC_Template__c LIMIT 1];

        Test.startTest();
        List<FEC_Content_History_Tracking__c> results = FEC_TemplateController.getContentHistory(tmpl.Id);
        Test.stopTest();

        Assert.isNotNull(results);
        Assert.areEqual(0, results.size(), 'No content history in test setup');
    }

    @IsTest
    static void testCreateDraftTemplate() {
        Test.startTest();
        Id draftId = FEC_TemplateController.createDraftTemplate();
        Test.stopTest();

        Assert.isNotNull(draftId, 'Controller should return a draft Id');
        FEC_Template__c draft = [SELECT Name FROM FEC_Template__c WHERE Id = :draftId];
        Assert.isTrue(draft.Name.startsWith('Draft-'), 'Draft name should start with Draft-');
    }

    @IsTest
    static void testDeleteDraftTemplate() {
        Id draftId = FEC_TemplateController.createDraftTemplate();

        Test.startTest();
        FEC_TemplateController.deleteDraftTemplate(draftId);
        Test.stopTest();

        Integer count = [SELECT COUNT() FROM FEC_Template__c WHERE Id = :draftId];
        Assert.areEqual(0, count, 'Draft should be deleted via controller');
    }
}
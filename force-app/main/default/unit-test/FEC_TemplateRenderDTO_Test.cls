/**
 * Unit tests for FEC_TemplateRenderDTO (template render result DTO + AttachedFile).
 */
@IsTest
private class FEC_TemplateRenderDTO_Test {

    @IsTest
    static void testConstructor_InitializesCollections() {
        FEC_TemplateRenderDTO dto = new FEC_TemplateRenderDTO();

        System.assertNotEquals(null, dto.AttachedFiles, 'AttachedFiles must be initialized.');
        System.assertNotEquals(null, dto.Warnings, 'Warnings must be initialized.');
        System.assertEquals(0, dto.AttachedFiles.size());
        System.assertEquals(0, dto.Warnings.size());
        System.assertEquals(null, dto.Subject);
        System.assertEquals(null, dto.Body);
    }

    @IsTest
    static void testSubjectAndBody_CanBeAssigned() {
        FEC_TemplateRenderDTO dto = new FEC_TemplateRenderDTO();
        dto.Subject = 'Test Subject';
        dto.Body = '<p>Rendered body</p>';

        System.assertEquals('Test Subject', dto.Subject);
        System.assertEquals('<p>Rendered body</p>', dto.Body);
    }

    @IsTest
    static void testWarnings_CanAddMessages() {
        FEC_TemplateRenderDTO dto = new FEC_TemplateRenderDTO();
        dto.Warnings.add('Missing merge field: Contact.Name');
        dto.Warnings.add('Attachment skipped');

        System.assertEquals(2, dto.Warnings.size());
        System.assertEquals('Missing merge field: Contact.Name', dto.Warnings[0]);
        System.assertEquals('Attachment skipped', dto.Warnings[1]);
    }

    @IsTest
    static void testAttachedFile_PropertiesCanBeSet() {
        ContentVersion cv = new ContentVersion(
            Title = 'Policy',
            PathOnClient = 'Policy.pdf',
            VersionData = Blob.valueOf('file-content')
        );
        insert cv;
        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];

        FEC_TemplateRenderDTO.AttachedFile file = new FEC_TemplateRenderDTO.AttachedFile();
        Blob data = Blob.valueOf('file-content');
        file.ContentVersionId = cv.Id;
        file.ContentDocumentId = cv.ContentDocumentId;
        file.Title = 'Policy.pdf';
        file.FileExtension = 'pdf';
        file.Size = 1024;
        file.VersionData = data;

        System.assertEquals(cv.Id, file.ContentVersionId);
        System.assertEquals(cv.ContentDocumentId, file.ContentDocumentId);
        System.assertEquals('Policy.pdf', file.Title);
        System.assertEquals('pdf', file.FileExtension);
        System.assertEquals(1024, file.Size);
        System.assertEquals(data, file.VersionData);
    }

    @IsTest
    static void testAttachedFiles_CanHoldMultipleEntries() {
        FEC_TemplateRenderDTO dto = new FEC_TemplateRenderDTO();

        FEC_TemplateRenderDTO.AttachedFile first = new FEC_TemplateRenderDTO.AttachedFile();
        first.Title = 'First.pdf';
        first.FileExtension = 'pdf';

        FEC_TemplateRenderDTO.AttachedFile second = new FEC_TemplateRenderDTO.AttachedFile();
        second.Title = 'Second.docx';
        second.FileExtension = 'docx';

        dto.AttachedFiles.add(first);
        dto.AttachedFiles.add(second);

        System.assertEquals(2, dto.AttachedFiles.size());
        System.assertEquals('First.pdf', dto.AttachedFiles[0].Title);
        System.assertEquals('Second.docx', dto.AttachedFiles[1].Title);
    }

    @IsTest
    static void testFullDto_BuildsTypicalRenderResult() {
        FEC_TemplateRenderDTO dto = new FEC_TemplateRenderDTO();
        dto.Subject = 'Welcome';
        dto.Body = '<p>Hello {{{Contact.Name}}}</p>';
        dto.Warnings.add('Optional warning');

        FEC_TemplateRenderDTO.AttachedFile attachment = new FEC_TemplateRenderDTO.AttachedFile();
        attachment.Title = 'Terms.pdf';
        attachment.FileExtension = 'pdf';
        attachment.Size = 2048;
        dto.AttachedFiles.add(attachment);

        System.assertEquals('Welcome', dto.Subject);
        System.assert(dto.Body.contains('Contact.Name'));
        System.assertEquals(1, dto.Warnings.size());
        System.assertEquals(1, dto.AttachedFiles.size());
        System.assertEquals('Terms.pdf', dto.AttachedFiles[0].Title);
    }
}

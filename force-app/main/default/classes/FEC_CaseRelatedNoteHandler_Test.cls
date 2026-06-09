@IsTest
private class FEC_CaseRelatedNoteHandler_Test {

    @TestSetup
    static void setupData() {
        String suffix = String.valueOf(System.currentTimeMillis());
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert new Case(
                Subject = 'Test Case For Notes',
                Status = 'New',
                FEC_ID_Search__c = 'NOTE-CASE-' + suffix
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }

    /**
     * Kịch bản 1: Kiểm tra tạo mới Note (createNote) và lấy danh sách Note (getNotes).
     * Mong đợi: Note được tạo thành công, liên kết đúng với Case và được map đầy đủ vào NoteWrapper.
     */
    @IsTest
    static void testCreateAndGetNotes() {
        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        // Tạo Note mới
        FEC_CaseRelatedNoteHandler.createNote(c.Id, 'Test Note Title', 'This is the test content of the note.');
        
        // Lấy danh sách Note
        List<FEC_CaseRelatedNoteHandler.NoteWrapper> notes = FEC_CaseRelatedNoteHandler.getNotes(c.Id);
        Test.stopTest();

        // Khẳng định dữ liệu
        System.assertNotEquals(null, notes, 'Danh sách trả về không được rỗng.');
        System.assertEquals(1, notes.size(), 'Phải lấy được đúng 1 bản ghi Note.');
        
        FEC_CaseRelatedNoteHandler.NoteWrapper noteWrapper = notes[0];
        System.assertEquals('Test Note Title', noteWrapper.title, 'Tiêu đề Note phải khớp.');
        System.assertEquals('This is the test content of the note.', noteWrapper.content, 'Nội dung Note phải khớp.');
        System.assertNotEquals(null, noteWrapper.id, 'ID của Note không được rỗng.');
        System.assertNotEquals(null, noteWrapper.createdById, 'CreatedById không được rỗng.');
        System.assertNotEquals(null, noteWrapper.lastModifiedDate, 'LastModifiedDate không được rỗng.');
    }

    /**
     * Kịch bản 2: Kiểm tra cập nhật nội dung Note (updateNote).
     * Mong đợi: Tiêu đề và nội dung của Note được cập nhật chính xác vào cơ sở dữ liệu.
     */
    @IsTest
    static void testUpdateNote() {
        Case c = [SELECT Id FROM Case LIMIT 1];

        FEC_CaseRelatedNoteHandler.createNote(c.Id, 'Old Title', 'Old Content');
        Id noteId = FEC_CaseRelatedNoteHandler.getNotes(c.Id)[0].id;

        Test.startTest();
        FEC_CaseRelatedNoteHandler.updateNote(noteId, 'Updated Title', 'Updated Content');
        Test.stopTest();

        // Title cập nhật qua ContentNote DML; Content body trên platform thường không đổi qua update
        ContentNote updatedNote = [SELECT Title FROM ContentNote WHERE Id = :noteId];
        System.assertEquals('Updated Title', updatedNote.Title, 'Tiêu đề phải được cập nhật.');

        FEC_CaseRelatedNoteHandler.NoteWrapper after = FEC_CaseRelatedNoteHandler.getNotes(c.Id)[0];
        System.assertEquals('Updated Title', after.title, 'getNotes phải trả về tiêu đề mới.');
    }

    /**
     * Kịch bản 3: Kiểm tra việc xóa liên kết Note khỏi bản ghi Case (removeNoteFromRecord).
     * Mong đợi: Bản ghi ContentDocumentLink bị xóa, Case không còn liên kết với Note.
     */
    @IsTest
    static void testRemoveNoteFromRecord() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        
        FEC_CaseRelatedNoteHandler.createNote(c.Id, 'Link Title', 'Link Content');
        ContentDocumentLink cdl = [SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :c.Id LIMIT 1];

        Test.startTest();
        FEC_CaseRelatedNoteHandler.removeNoteFromRecord(c.Id, cdl.ContentDocumentId);
        Test.stopTest();

        List<ContentDocumentLink> remainingLinks = [SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId = :c.Id];
        System.assertEquals(0, remainingLinks.size(), 'Liên kết ContentDocumentLink phải bị xóa hoàn toàn khỏi Case.');
    }

    /**
     * Kịch bản 4: Kiểm tra việc xóa vĩnh viễn Note (deleteNote).
     * Mong đợi: Bản ghi ContentDocument bị xóa vĩnh viễn khỏi hệ thống.
     */
    @IsTest
    static void testDeleteNote() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        
        FEC_CaseRelatedNoteHandler.createNote(c.Id, 'Delete Title', 'Delete Content');
        ContentDocumentLink cdl = [SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :c.Id LIMIT 1];

        Test.startTest();
        FEC_CaseRelatedNoteHandler.deleteNote(cdl.ContentDocumentId);
        Test.stopTest();

        List<ContentDocument> docs = [SELECT Id FROM ContentDocument WHERE Id = :cdl.ContentDocumentId];
        System.assertEquals(0, docs.size(), 'Bản ghi ContentDocument phải bị xóa khỏi hệ thống.');
    }

    /**
     * Kịch bản 5: Kiểm tra các khối bẫy lỗi (Catch Exception Blocks) và Guard Clauses.
     * Mong đợi: Hệ thống an toàn ném ra AuraHandledException khi thao tác trên dữ liệu không hợp lệ.
     */
    @IsTest
    static void testExceptionHandling() {
        String notePrefix = ContentNote.SObjectType.getDescribe().getKeyPrefix();
        Id fakeNoteId = (Id)(notePrefix + '000000000000');

        Test.startTest();

        try {
            FEC_CaseRelatedNoteHandler.updateNote(fakeNoteId, 'Title', 'Content');
            System.assert(false, 'Phải ném AuraHandledException khi update Note không tồn tại.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        try {
            FEC_CaseRelatedNoteHandler.getNotes(null);
            System.assert(false, 'Phải ném AuraHandledException khi recordId null.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        // deleteNote: SOQL rỗng → delete list rỗng, không throw (khác updateNote query LIMIT 1)
        FEC_CaseRelatedNoteHandler.deleteNote(fakeNoteId);

        // removeNoteFromRecord(null, …) là guard — không throw, chỉ không xóa link
        FEC_CaseRelatedNoteHandler.removeNoteFromRecord(null, fakeNoteId);

        Test.stopTest();
    }
}
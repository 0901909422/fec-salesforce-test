public with sharing class FEC_CaseRelatedNoteHandler {
    
    @AuraEnabled(cacheable=true)
    public static List<NoteWrapper> getNotes(Id recordId) {
        System.debug('getNotes');
        System.debug('recordId: ' + recordId);
        try {
            List<ContentDocumentLink> links = [
                SELECT ContentDocumentId
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :recordId
            ];
            
            Set<Id> contentIds = new Set<Id>();
            for (ContentDocumentLink l : links) {
                contentIds.add(l.ContentDocumentId);
            }
            
            List<NoteWrapper> result = new List<NoteWrapper>();
            
            if (!contentIds.isEmpty()) {
                List<ContentNote> listNotes = [
                    SELECT Id, Title, TextPreview,
                           CreatedBy.Name, LastModifiedDate
                    FROM ContentNote
                    WHERE Id IN :contentIds
                    ORDER BY LastModifiedDate DESC
                ];
                
                for (ContentNote note : listNotes) {
                    result.add(new NoteWrapper(
                        note.Id,
                    note.Title,
                    note.TextPreview,
                    note.CreatedBy.Name,
                    note.LastModifiedDate
                        ));
                }
            }
            
            return result;
            
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled
    public static void createNote(Id recordId, String title, String content) {
        
        ContentNote note = new ContentNote();
        note.Title = title;
        note.Content = Blob.valueOf(content);
        insert note;
        
        ContentDocumentLink link = new ContentDocumentLink();
        link.ContentDocumentId = note.Id;
        link.LinkedEntityId = recordId;
        link.ShareType = 'V';
        insert link;
    }
    
    @AuraEnabled
    public static void updateNote(Id noteId, String title, String content) {
        try {
            ContentNote note = [
            SELECT Id, Title
            FROM ContentNote
            WHERE Id = :noteId
            LIMIT 1
        ];
            
            note.Title = title;
            note.Content = Blob.valueOf(content);
            
            update note;
            
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    @AuraEnabled
    public static void removeNoteFromRecord(Id recordId, Id noteId) {
        try {
            List<ContentDocumentLink> links = [
            SELECT Id
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :recordId
            AND ContentDocumentId = :noteId
        ];
            
            if (!links.isEmpty()) {
                delete links;
            }
            
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    @AuraEnabled
    public static void deleteNote( Id noteId) {
        try {
            delete [
            SELECT Id
            FROM ContentDocument
            WHERE Id = :noteId
            LIMIT 1
        ];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    public class NoteWrapper {
        @AuraEnabled public Id id;
        @AuraEnabled public String title;
        @AuraEnabled public String preview;
        @AuraEnabled public String createdByName;
        @AuraEnabled public Datetime lastModifiedDate;
        
        public NoteWrapper(
            Id id,
        String title,
        String preview,
        String createdBy,
        Datetime lastModified
        ) {
            this.id = id;
            this.title = title;
            this.preview = preview;
            this.createdByName = createdBy;
            this.lastModifiedDate = lastModified;
        }
    }
}
public without sharing class FEC_ClearSessionController {

    public class UserResult {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String username;
        @AuraEnabled public String email;
        @AuraEnabled public String alias;
    }

    @AuraEnabled
    public static List<UserResult> searchUsers(String keyword) {
        if (String.isBlank(keyword) || keyword.trim().length() < 2) return new List<UserResult>();
        String q = '%' + keyword.trim() + '%';
        List<User> users = [
            SELECT Id, Name, Username, Email, Alias
            FROM User
            WHERE IsActive = true
            AND (Name LIKE :q OR Username LIKE :q OR Email LIKE :q OR Alias LIKE :q)
            ORDER BY Name ASC
            LIMIT 20
        ];
        List<UserResult> results = new List<UserResult>();
        for (User u : users) {
            UserResult r = new UserResult();
            r.id = u.Id;
            r.name = u.Name;
            r.username = u.Username;
            r.email = u.Email;
            r.alias = u.Alias;
            results.add(r);
        }
        return results;
    }

    @AuraEnabled
    public static Id clearSessions(List<Id> userIds) {
        if (userIds == null || userIds.isEmpty()) {
            throw new AuraHandledException('No users selected.');
        }

        List<String> userEmails = new List<String>();
        Boolean anyFailed = false;

        for (Id userId : userIds) {
            try {
                User u = [SELECT Email FROM User WHERE Id = :userId LIMIT 1];
                userEmails.add(u.Email);
                FEC_SessionUtil.forceClearSessions(userId);
            } catch (Exception e) {
                anyFailed = true;
            }
        }

        // Insert record in future to avoid MIXED_DML_OPERATION error
        insertClearSessionRecord(String.join(userEmails, ', '), anyFailed ? 'Failed' : 'Success');
        return null;
    }

    @future
    private static void insertClearSessionRecord(String userEmails, String status) {
        FEC_Clear_Session__c rec = new FEC_Clear_Session__c();
        rec.FEC_User__c = userEmails;
        rec.FEC_Status__c = status;
        insert rec;
    }

    @AuraEnabled(cacheable=true)
    public static List<FEC_Clear_Session__c> getAllClearSessions() {
        return [
            SELECT Id, Name, FEC_User__c, FEC_Status__c, CreatedById, CreatedBy.Name, CreatedDate
            FROM FEC_Clear_Session__c
            ORDER BY CreatedDate DESC
            LIMIT 200
        ];
    }
}

public with sharing class FEC_AssignmentListHandler {
    
    @AuraEnabled(cacheable=true)
    public static String getUserDepartment() {
        User u = [
        SELECT UserRole.Name, Profile.Name
        FROM User
        WHERE Id = :UserInfo.getUserId()
    ];
        
        if (u.UserRole.Name.contains('Support') ||
        u.UserRole.Name.contains('Customer Care')) {
            return 'CS';
        }
        
        return 'OTHER';
    }
    
    @AuraEnabled
    public static List<FEC_Assignment__c> getAssignments(String caseId) {
        
        if (caseId == null) {
            throw new AuraHandledException(System.Label.LBL_CaseIdRequired);
        }
        
        try {
            
            if (!Schema.sObjectType.FEC_Assignment__c.isAccessible()) {
                throw new AuraHandledException(
                    System.Label.FEC_MSG_NO_ACCESS_ASSIGNMENT
                    );
            }
            
            List<FEC_Assignment__c> records = [
            SELECT
                Id,
                Name,
                FEC_Assignment_Owner__c,
                FEC_Assignment_Owner__r.Name,
                FEC_Assignment_Owner__r.Email,
                FEC_Assignment_Status__c
            FROM FEC_Assignment__c
            WHERE FEC_Case__c = :caseId
        ];
            
            return records;
            
        } catch (Exception e) {
            
            System.debug(
                LoggingLevel.ERROR,
            'getAssignments error: ' + e.getMessage()
                );
            
            throw new AuraHandledException(
                System.Label.FEC_MSG_LOAD_ASSIGNMENT_FAILED
                );
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<FEC_Case_Remarks__c> getAssignmentRemarks(String caseId, String assignmentId) {
        
        if (caseId == null) {
            throw new AuraHandledException(System.Label.LBL_CaseIdRequired);
        }
        if (assignmentId == null) {
            throw new AuraHandledException(System.Label.FEC_MSG_ASSIGNMENT_ID_REQUIRED);
        }
        try {
            
            if (!Schema.sObjectType.FEC_Case_Remarks__c.isAccessible()) {
                throw new AuraHandledException(System.Label.FEC_MSG_NO_ACCESS_REMARK);
            }
            
            List<FEC_Case_Remarks__c> records = [
            SELECT
                 Id, FEC_Case_Remarks__c, FEC_Stage_Name__c, FEC_User__c, FEC_User_Role__c,  CreatedDate
            FROM FEC_Case_Remarks__c
            WHERE FEC_Remark_Type__c = :FEC_ConstantCommon.REMARK_TYPE_ASSIGNMENT
              AND FEC_Case__c = :caseId AND FEC_Assignment__c = :assignmentId
            ORDER BY CreatedDate DESC
        ];
            
            return records;
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'getCaseRemarks error: ' + e.getMessage());
            
            throw new AuraHandledException(System.Label.FEC_MSG_LOAD_REMARK_FAILED);
        }
    }
    
    
    public class SelectOptionWrapper {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        
        public SelectOptionWrapper(String value, String label) {
            this.value = value;
            this.label = label;
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<SelectOptionWrapper> getUsersInGroup() {
        
        User currentUser = [
        SELECT FEC_User_Group__c
        FROM User
        WHERE Id = :UserInfo.getUserId()
    ];
        
        List<User> users = [
        SELECT Id, Name
        FROM User
        WHERE FEC_User_Group__c = :currentUser.FEC_User_Group__c
        AND IsActive = true
    ];
        
        List<SelectOptionWrapper> result = new List<SelectOptionWrapper>();
        
        for (User u : users) {
            result.add(new SelectOptionWrapper(u.Id, u.Name));
        }
        
        return result;
    }
    
    
    @AuraEnabled(cacheable=true)
    public static List<SelectOptionWrapper> getQueuesForUser() {
        
        Id userId = UserInfo.getUserId();
        
        // 1. tìm queue user thuộc
        List<GroupMember> memberships = [
        SELECT GroupId
        FROM GroupMember
        WHERE UserOrGroupId = :userId
    ];
        
        Set<Id> queueIds = new Set<Id>();
        for (GroupMember gm : memberships) {
            queueIds.add(gm.GroupId);
        }
        
        // 2. lấy queue info
        List<Group> queues = [
        SELECT Id, Name
        FROM Group
        WHERE Id IN :queueIds
        AND Type = 'Queue'
    ];
        
        List<SelectOptionWrapper> result = new List<SelectOptionWrapper>();
        
        for (Group g : queues) {
            result.add(new SelectOptionWrapper(g.Id, g.Name));
        }
        
        return result;
    }
}
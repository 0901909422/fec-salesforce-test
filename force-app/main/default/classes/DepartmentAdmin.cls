/** 
 * @description DepartmentAdmin service for Queue and Queue Members exploration.
 * Enforces sharing. Provides paginated users for a given Queue.
 */
public without sharing class DepartmentAdmin {
    // Constant to use for custom history log
    public static final String CLASS_NAME = 'DepartmentAdmin';
    public static final String QUEUE_TYPE = 'Queue';
    public class QueueDto {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String email;
        @AuraEnabled public String devname;
        @AuraEnabled public String queueSobjectType;
        @AuraEnabled public Boolean mainqueue;
    }

    public class UserDto {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String userrole;
        @AuraEnabled public String email;
    }

    public class PagedUsers {
        @AuraEnabled public List<UserDto> users;
        @AuraEnabled public Integer totalSize;
        @AuraEnabled public Integer pageSize;
        @AuraEnabled public Integer offset;
        @AuraEnabled public Boolean hasMore;
        @AuraEnabled public String nextCursor;
    }

    /*------------------------------------------------------------
    Author:        Ha Linh
    Company:       Amaris
    Description:   Get Users assigned to a Queue using GroupMember, with pagination.
    @paramqueueId Target Queue Id (Group.Id where Type='Queue')
    @param pageSize Number of rows to return (1..200 recommended)
    @param lastUserId lastUserID to pagination
    Test Class:    
    History
    <Date>         <Authors Name>     <Brief Description of Change>
    2026/03/31      Ha Linh          Init
    ------------------------------------------------------------*/
    @AuraEnabled
    public static PagedUsers getQueueMembers(Id queueId, Integer pageSize, Id lastUserId) {
        PagedUsers page = new PagedUsers();
        page.users = new List<UserDto>();
        if (queueId == null) {
            return page; // return-early
        }
        Set<Id> userIdsInQueue = new Set<Id>();
        for (GroupMember gm : [
            SELECT UserOrGroupId 
            FROM GroupMember 
            WHERE GroupId = :queueId
        ]) {
            userIdsInQueue.add(gm.UserOrGroupId);
        }

        if (userIdsInQueue.isEmpty()) {
            return page;
        }
        List<User> users = new List<User>();
        String queryLastUserId = '';
        if (lastUserId != null) {
            queryLastUserId = 'AND Id > :lastUserId ';
        }
        String queryUser = 'SELECT Id, Name, Email, UserRole.Name ' +
                'FROM User ' +
                'WHERE Id IN :userIdsInQueue ' +
                queryLastUserId +
                'ORDER BY Id ' + 'LIMIT :pageSize';
        users = Database.query(queryUser);
        System.debug('### users: ' + users);
        for (User u : users) {
            UserDto ud = new UserDto();
            String roleName = u.UserRole != null ? u.UserRole.Name : 'No Role';
            ud.id = u.Id;
            ud.name = u.Name;
            ud.userrole = roleName;
            ud.email = u.Email;
            page.users.add(ud);
        }
        return page;
    }

    /*------------------------------------------------------------
    Author:        Ha Linh
    Company:       Amaris
    Description:   Get queues that a user belongs to
    @param userId The user ID to get queues for
    @return List of QueueDto objects
    Test Class:    
    History
    <Date>         <Authors Name>     <Brief Description of Change>
    2026/03/31      Ha Linh          Init
    ------------------------------------------------------------*/
    @AuraEnabled
    public static List<QueueDto> getUserQueues(Id userId) {
        if (userId == null) {
            return new List<QueueDto>();
        }
        List<User> users = Database.query(
            'SELECT Id, Name, FEC_Main_Queue__c, UserRole.Name FROM User WHERE Id = :userId LIMIT 1'
        );
        if (users.isEmpty()) {
            return new List<QueueDto>();
        }
        
        User u = users[0];
        String mainQueue = u.FEC_Main_Queue__c;
        List<QueueDto> result = new List<QueueDto>();
        Set<Id> queueIds = new Set<Id>();
        for (GroupMember gm : [
            SELECT GroupId
            FROM GroupMember
            WHERE UserOrGroupId = :userId
        ]) {
            queueIds.add(gm.GroupId);
        }
        
        // Get SObject types for queues
        Map<Id, String> queueSobjTypes = new Map<Id, String>();
        List<QueueSobject> qso = [
            SELECT QueueId, SobjectType
            FROM QueueSobject
            WHERE QueueId IN :queueIds
        ];
        for (QueueSobject qs : qso) {
            if (!queueSobjTypes.containsKey(qs.QueueId)) {
                queueSobjTypes.put(qs.QueueId, qs.SobjectType);
            }
        }
        
        for (Group g : [
            SELECT Id, Name, Email, DeveloperName
            FROM Group
            WHERE Id IN :queueIds
            AND Type = :QUEUE_TYPE
        ]) {
            QueueDto dto = new QueueDto();
            dto.id = g.Id;
            dto.name = g.Name;
            dto.email = g.Email;
            dto.devname = g.DeveloperName;
            dto.queueSobjectType = queueSobjTypes.get(g.Id);
            dto.mainqueue = g.DeveloperName == mainQueue;
            result.add(dto);
        }
        
        return result;
    }

    /*------------------------------------------------------------
    Author:        Ha Linh
    Company:       Amaris
    Description:   Add users to a queue
    @param queueId The queue to add users to
    @param userIds List of user IDs to add
    @return Boolean indicating success
    Test Class:    
    History
    <Date>         <Authors Name>     <Brief Description of Change>
    2026/03/31      Ha Linh          Init
    ------------------------------------------------------------*/
    @AuraEnabled
    public static Boolean addUsersToQueue(Id queueId, List<Id> userIds) {
        if (queueId == null || userIds == null || userIds.isEmpty()) {
            return false;
        }
        
        try {
            // Create GroupMember records to add users to queue
            List<GroupMember> groupMembers = new List<GroupMember>();
            for (Id userId : userIds) {
                GroupMember gm = new GroupMember();
                gm.GroupId = queueId;
                gm.UserOrGroupId = userId;
                groupMembers.add(gm);
            }
            Database.insert(groupMembers);
            List<String> emailAddToQueue = new List<String>();
            for (User u : [
                SELECT Email
                FROM User
                WHERE Id IN :userIds
            ]) {
                emailAddToQueue.add(u.Email);
            }
            insertCustomLog(queueId, CLASS_NAME, 'addUsersToQueue', 'Add User Success', '', String.join(emailAddToQueue, ', '));
            return true;
        } catch (DmlException dmlEx) {
            // All-or-none failed, nothing inserted. Log detailed DML messages.
            List<String> msgs = new List<String>();
            for (Integer i = 0; i < dmlEx.getNumDml(); i++) {
                msgs.add(dmlEx.getDmlMessage(i));
            }
            System.debug('Error adding users to queue: ' + String.join(msgs, ';'));
            return false;
        }
    }
    
    /*------------------------------------------------------------
    Author:        Ha Linh
    Company:       Amaris
    Description:  Because error when inser Set up Obj and Custom Object, so need to user future function to insert custom history log
    @param TargetObjectId The Queue ID/ Team ID
    @param className ClassName
    @param methodName MethodName
    @param actionName Action in UI (Add User, Remove User, Main Queue .....)
    @param oldValue Old value
    @param newValue New Value
    Test Class:    
    History
    <Date>         <Authors Name>     <Brief Description of Change>
    2026/03/31      Ha Linh          Init
    ------------------------------------------------------------*/
    @future
    public static void insertCustomLog(String TargetObjectId, String className, 
                                String methodName, String actionName, 
                                String oldValue, String newValue) {
        CustomLog.logOldNew(TargetObjectId, className, methodName, actionName, oldValue, newValue);
    }
    /*------------------------------------------------------------
    Author:        Ha Linh
    Company:       Amaris
    Description:   Remove a user from a queue
    @param queueId The queue to remove users to
    @param userId The user ID to remove
    @return Boolean indicating success
    Test Class:    
    History
    <Date>         <Authors Name>     <Brief Description of Change>
    2026/03/31      Ha Linh          Init
    ------------------------------------------------------------*/
    @AuraEnabled
    public static Boolean removeUserFromQueue(Id queueId, Id userId) {
        if (queueId == null || userId == null) {
            return false;
        }
        
        try {
            // Find and delete the GroupMember record that connects the user to the queue
            List<GroupMember> groupMembersToDelete = [
                SELECT Id
                FROM GroupMember
                WHERE GroupId = :queueId
                AND UserOrGroupId = :userId
            ];
            System.debug('### groupMembersToDelete: ' + groupMembersToDelete);
            if (!groupMembersToDelete.isEmpty()) {
                Database.delete(groupMembersToDelete);
                List<User> users = [
                    SELECT Email
                    FROM User
                    WHERE Id = :userId
                ];
                insertCustomLog(queueId, CLASS_NAME, 'removeUserFromQueue', 'Remove User Success', users[0].Email, users[0].Email);
                return true;
            }
            return false;
        } catch (Exception e) {
            System.debug('Error removing user from queue: ' + e.getMessage());
            return false;
        }
    }
    /*------------------------------------------------------------
    Author:        Ha Linh
    Company:       Amaris
    Description:   Check if the given queue is the main queue of the user by comparing with User.FEC_Main_Queue__c field
    @param developerName The queue to check
    @param userId The user ID to check
    @return Boolean if the queue is the main queue of the user
    Test Class:    
    History
    <Date>         <Authors Name>     <Brief Description of Change>
    2026/04/22      Ha Linh          Init
    ------------------------------------------------------------*/
    @AuraEnabled
    public static Boolean isMainQueueOfUser(Id userId, String developerName) {
        try {
            List<User> user = [
                SELECT Id
                FROM User
                WHERE Id = :userId AND FEC_Main_Queue__c = :developerName
                LIMIT 1
            ];
            System.debug('## isMainQueueOfUser user: ' + !user.isEmpty() + ' userId: ' + userId + ' developerName: ' + developerName);
            return !user.isEmpty();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /*------------------------------------------------------------
    Author:        Ha Linh
    Company:       Amaris
    Description:   Search for active users by name or email
    @param searchTerm The term to search for in names or emails
    @return List of UserDto objects
    Test Class:    
    History
    <Date>         <Authors Name>     <Brief Description of Change>
    2026/03/31      Ha Linh          Init
    ------------------------------------------------------------*/
    @AuraEnabled
    public static List<UserDto> searchActiveUsers(String searchTerm, List<Id> excludedIds) {
        if (String.isBlank(searchTerm)) {
            return new List<UserDto>();
        }
        
        // Search for active users by name or email (case insensitive)
        List<User> users = [
            SELECT Id, Name, Email, UserRole.Name
            FROM User
            WHERE IsActive = true AND Id NOT IN :excludedIds
            AND (Name LIKE :('%' + searchTerm + '%') OR Email LIKE :('%' + searchTerm + '%'))
            ORDER BY Name
            LIMIT 100
        ];
        
        List<UserDto> results = new List<UserDto>();
        for (User u : users) {
            String roleName = u.UserRole != null ? u.UserRole.Name : 'No Role';
            UserDto result = new UserDto();
            result.id = u.Id;
            result.name = u.Name;
            result.userrole = roleName;
            result.email = u.Email;
            results.add(result);
        }
        
        return results;
    }
    /*------------------------------------------------------------
    Author:        Ha Linh
    Company:       Amaris
    Description:   Get Queue information by DeveloperName or Queue Id
    @param developerName The DeveloperName of the Queue (Group.DeveloperName)
    @param queueId The Id of the Queue (Group.Id)
    @return QueueDto if a Queue with that DeveloperName or Id exists, otherwise null.
    Test Class:    
    History
    <Date>         <Authors Name>     <Brief Description of Change>
    2026/03/31      Ha Linh          Init
    ------------------------------------------------------------*/
    @AuraEnabled
    public static QueueDto getQueueValidBaseNameOrId(String developerName, Id queueId) {
        System.debug('queues data queueId ' + queueId);
        System.debug('queues data developerName ' + developerName);
        // Return early for invalid input
        if (String.isBlank(developerName) && queueId == null) {
            return null;
        }
        String query = 'SELECT Id, Name, DeveloperName FROM Group WHERE Type =' + ' \'' + QUEUE_TYPE + '\'';
        if (String.isNotBlank(developerName)) {
            query += ' AND DeveloperName = ' + '\'' + String.escapeSingleQuotes(developerName) + '\'';
        } else if (queueId != null) {
            query += ' AND Id = ' + '\'' + queueId + '\'';
        } else {
            return null; 
        }
        query += ' LIMIT 1';
        List<Group> queues = Database.query(query);
        if (!queues.isEmpty()) {
            Group g = queues[0];
            QueueDto dto = new QueueDto();
            dto.id = g.Id;
            dto.name = g.Name;
            dto.devname = g.DeveloperName;
            return dto;
        }
        
        return null;
    }
    /*------------------------------------------------------------
    Author:        Ha Linh
    Company:       Amaris
    Description:   Updates User.FEC_Main_Queue__c (Text) for a given user
    @param userId - Target User Id
    @param queueId The Id of the Queue (Group.Id)
    @param namequeue - Text value to set into FEC_Main_Queue__c (can be null/blank to clear)
    @return Boolean indicating success
    Test Class:    
    History
    <Date>         <Authors Name>     <Brief Description of Change>
    2026/03/31      Ha Linh          Init
    ------------------------------------------------------------*/
    @AuraEnabled
    public static Boolean updateMainQueueForUser(Id queueId, Id userId, String namequeue) {
        // We must ALWAYS throw AuraHandledException with the exact prefix "Unable to update main queue:"
        try {
            List<User> users = [
                SELECT Id, Email, FEC_Main_Queue__c
                FROM User
                WHERE Id = :userId
                LIMIT 1
            ];
            if (users.isEmpty()) {
                // User not found -> throw AuraHandledException with required prefix
                throw new AuraHandledException(System.Label.CS_OrgChart_Text_UserDetail_MainQueue_User_NotFound);
            }
            User u = users[0];
            String oldMainQueue = u.FEC_Main_Queue__c;

            // Assign text value directly (allow null to clear)
            u.FEC_Main_QUEUE__c = namequeue;
            Database.SaveResult sr = Database.update(u, false);
            if (sr.isSuccess()) {
                // Log the change asynchronously
                insertCustomLog(queueId, CLASS_NAME, 'updateMainQueueForUser', 'Update main queue: ' + u.Email, oldMainQueue, namequeue);
                System.debug('DepartmentAdmin - updateMainQueueForUser for UserID: ' + sr.getId() + ' MainQueue update: ' + namequeue);
                return true;
            } else {
                // Build error message from save result errors and throw to follow "ALWAYS throw" rule
                String err = '';
                for (Database.Error e : sr.getErrors()) {
                    err += e.getMessage() + '; ';
                }
                throw new AuraHandledException(System.Label.CS_OrgChart_Text_UserDetail_MainQueue_Error + err);
            }
        } catch (DmlException d) {
            // Convert to AuraHandledException with required prefix
            throw new AuraHandledException(System.Label.CS_OrgChart_Text_UserDetail_MainQueue_Error + d.getMessage());
        }
    }
}
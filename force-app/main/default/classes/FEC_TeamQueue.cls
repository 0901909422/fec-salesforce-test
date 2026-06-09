/**
 * @description Class to handle team queue operations
 * @author FEC Team
 * @since 2026-03-24
 */
public without sharing class FEC_TeamQueue {
    public static final String CLASS_NAME = 'FEC_TeamQueue';
    public static final String QUEUE_TYPE = 'Queue';
    /**
     * @description Wrapper class to hold team 
     */
    public class TeamQueueWrapper {
        @AuraEnabled public String teamName;
        @AuraEnabled public String teamLabel;
        @AuraEnabled public String teamId;
        @AuraEnabled public String teamDescription;
    }

    /**
     * @description Wrapper class to hold list queue
     */
    public class ListQueueDto {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String teamqueue;
        @AuraEnabled public String queueId;
        @AuraEnabled public String displayname;
        @AuraEnabled public String queueLabelStatus;
    }

    /**
     * @description DTO for editing queue information
     */
    public class EditQueueDto {
        @AuraEnabled public Id queueId;                // Group Id
        @AuraEnabled public String queueLabel;         // Group.Name

        @AuraEnabled public Id teamQueueRecordId;      // FEC_Team_Queue__c.Id
        @AuraEnabled public Id teamId;
        @AuraEnabled public String teamName;           // FEC_Select_Team__r.Name
        @AuraEnabled public String queueLabelStatus;    // FEC_Team_Queue__c.FEC_Team__c
    }
    /*------------------------------------------------------------
    Author:        Ha Linh
    Company:       Amaris
    Description:   Returns a list of teams
    @return List of team queue records with TeamQueueWrapper
    Test Class:    
    History
    <Date>         <Authors Name>     <Brief Description of Change>
    2026/03/31      Ha Linh          Init
    ------------------------------------------------------------*/
    @AuraEnabled
    public static List<TeamQueueWrapper> getListTeam() {
        List<TeamQueueWrapper> result = new List<TeamQueueWrapper>();
        
        try {
            // Query to get teams and their queue counts
            List<FEC_Team__c> listTeamNames = [
                SELECT Id, Name, FEC_Team_Label__c, FEC_Team_Description__c
                FROM FEC_Team__c 
                WHERE FEC_Team_Active__c = true
                ORDER BY Name
            ];
            
            // Process the results
            for (FEC_Team__c team : listTeamNames) {
                TeamQueueWrapper wrapper = new TeamQueueWrapper();
                wrapper.teamName = team.Name;
                wrapper.teamLabel = team.FEC_Team_Label__c;
                wrapper.teamId = team.Id;
                wrapper.teamDescription = team.FEC_Team_Description__c;
                result.add(wrapper);
            }
        } catch (Exception e) {
            // Log the exception or handle as needed
            System.debug('Error in getListTeam: ' + e.getMessage());
            throw e;
        }
        
        return result;
    }
    /*------------------------------------------------------------
    Author:        Ha Linh
    Company:       Amaris
    Description:   Returns a list of queue names for a specific team
    @param teamID The ID of the team to get queues for
    @return List of queue names for the specified team
    Test Class:    
    History
    <Date>         <Authors Name>     <Brief Description of Change>
    2026/03/31      Ha Linh          Init
    ------------------------------------------------------------*/
    @AuraEnabled
    public static List<ListQueueDto> getQueuesForTeam(Id teamID) {
        try {
            // Query to get queue names for a specific team
            List<FEC_Team_Queue__c> teamQueues = [
                SELECT Id, FEC_Queue_Name__c, FEC_Team__c
                FROM FEC_Team_Queue__c
                WHERE FEC_Select_Team__r.Id = :teamID
                ORDER BY FEC_Queue_Name__c
            ];

            List<ListQueueDto> result = new List<ListQueueDto>();
            
            // Extract queue names and validate each one exists
            for (FEC_Team_Queue__c tq : teamQueues) {
                // Validate that the queue exists using DepartmentAdmin.getQueueValidBaseNameOrId
                DepartmentAdmin.QueueDto queueInfo = DepartmentAdmin.getQueueValidBaseNameOrId(tq.FEC_Queue_Name__c, null);
                // Only add to result if queue exists
                if (queueInfo != null) {
                    ListQueueDto listQueue = new ListQueueDto();
                    listQueue.id = tq.Id;
                    listQueue.name = tq.FEC_Queue_Name__c;
                    listQueue.teamqueue = teamID;
                    listQueue.queueId = queueInfo.Id;
                    listQueue.displayname = queueInfo.name;
                    listQueue.queueLabelStatus = tq.FEC_Team__c;
                    result.add(listQueue);
                }
            }
            return result;
        } catch (Exception e) {
            // Log the exception or handle as needed
            System.debug('Error in getQueuesForTeam: ' + e.getMessage());
            throw e;
        }
    }
    /*------------------------------------------------------------
    Author:        Ha Linh
    Company:       Amaris
    Description:   Creates a new queue in Salesforce with the specified properties
    @param queueLabel The label for the new queue
    @param queueName The developer name for the new queue
    @return String QueueID if successful, null otherwise
    Test Class:    
    History
    <Date>         <Authors Name>     <Brief Description of Change>
    2026/03/31      Ha Linh          Init
    ------------------------------------------------------------*/
    @AuraEnabled
    public static String createQueue(String queueLabel, String queueName) {
        try {
            // Create a new Group (Queue) record
            Group newQueue = new Group(
                Name = queueLabel, 
                DeveloperName = queueName, 
                Type = QUEUE_TYPE
            );
            // Insert the queue
            insert newQueue;
            QueueSobject mapping = new QueueSobject(
                QueueId = newQueue.Id, 
                SobjectType = 'Case'
            );
            insert mapping;
            return newQueue.Id;
        } catch (Exception e) {
            System.debug('Error creating queue: ' + e.getMessage());
            return null;
        }
    }
    /*------------------------------------------------------------
    Author:        Ha Linh
    Company:       Amaris
    Description:   Creates a new record in FEC_Team_Queue__c custom object
    @param teamID The ID of the team
    @param queueName The developer name for the new queue
    @return Boolean indicating success or failure
    Test Class:    
    History
    <Date>         <Authors Name>     <Brief Description of Change>
    2026/03/31      Ha Linh          Init
    ------------------------------------------------------------*/
    @AuraEnabled
    public static Boolean createTeamQueueRecord(String teamID, String queueName, String labelStatus) {
        try {
            // Create a new FEC_Team_Queue__c record
            FEC_Team_Queue__c newTeamQueue = new FEC_Team_Queue__c(
                FEC_Select_Team__c = teamID,  // This maps to the Name field on the custom object
                FEC_Queue_Name__c = queueName,  // This maps to the custom field
                FEC_Team__c = labelStatus  // This maps to the custom field for label status
            );
            insert newTeamQueue;
            DepartmentAdmin.insertCustomLog(teamID, CLASS_NAME, 'saveNewQueue', 'Add New Queue For Team', '', queueName);
            return true;
        } catch (Exception e) {
            // Call remove queue if team queue record creation fails to avoid orphaned queues
            removeQueue(queueName, null);
            System.debug('Error creating team queue record: ' + e.getMessage());
            return false;
        }
    }
    /*------------------------------------------------------------
    Author:        Ha Linh
    Company:       Amaris
    Description:   Remove Queue by DeveloperName or Id, used when queue creation is successful but team queue record creation fails to avoid orphaned queues
    @param QueueId The ID of the queue to delete
    @param queueDeveloperName The developer name for the new queue
    Test Class:    
    History
    <Date>         <Authors Name>     <Brief Description of Change>
    2026/04/13      Ha Linh          Init
    ------------------------------------------------------------*/
    @future
    public static void removeQueue(String queueDeveloperName, Id QueueId) {
        if (String.isBlank(queueDeveloperName) && QueueId == null) return;
        List<Group> queuesToDelete = [
            SELECT Id 
            FROM Group 
            WHERE Type = :QUEUE_TYPE 
            AND (DeveloperName = :queueDeveloperName OR Id = :QueueId)
            LIMIT 1
        ];

        if (!queuesToDelete.isEmpty()) {
            try {
                delete queuesToDelete;
                System.debug('Successfully deleted queue: ' + queueDeveloperName + ' with Id: ' + queuesToDelete[0].Id);
            } catch (DmlException e) {
                System.debug('Error deleting queue: ' + e.getMessage() + ' for queue: ' + queueDeveloperName + ' with Id: ' + queuesToDelete[0].Id);
            }
        } else {
            System.debug('Queue not found: ' + queueDeveloperName);
        }
    }
    /*------------------------------------------------------------
    Author:        Ha Linh
    Company:       Amaris
    Description:   Creates a new Team (FEC_Team__c) from modal inputs with validation
    @param teamLabel maps to FEC_Team__c.FEC_Team_Label__c
    @param teamName maps to FEC_Team__c.Name (API/Developer Name style)
    @param teamDescription maps to FEC_Team__c.FEC_Team_Description__c
    @return Id of created FEC_Team__c on success
    Test Class:    
    History
    <Date>         <Authors Name>     <Brief Description of Change>
    2026/03/31      Ha Linh          Init
    ------------------------------------------------------------*/
    @AuraEnabled
    public static Id CreateNewTeam(String teamLabel, String teamName, String teamDescription) {
        // Basic null/blank checks
        if (String.isBlank(teamLabel)) {
            throw new AuraHandledException(System.Label.CS_OrgChart_Text_AddTeamModal_Label_Require_Err);
        }
        if (String.isBlank(teamName)) {
            throw new AuraHandledException(System.Label.CS_OrgChart_Text_AddTeamModal_Name_Require_Err);
        }
        // Construct record
        FEC_Team__c rec = new FEC_Team__c();
        rec.Name = teamName.trim();
        rec.FEC_Team_Label__c = teamLabel;
        rec.FEC_Team_Description__c = teamDescription;

        // Insert with error handling
        try {
            insert rec;
            DepartmentAdmin.insertCustomLog(rec.Id, CLASS_NAME, 'CreateNewTeam', 'Add new Team', '', teamName);
            return rec.Id;
        } catch (DmlException dmlEx) {
            // Surface first error to LWC cleanly
            String msg = (dmlEx.getNumDml() > 0 && dmlEx.getDmlMessage(0) != null) ? dmlEx.getDmlMessage(0) : dmlEx.getMessage();
            throw new AuraHandledException(System.Label.CS_OrgChart_Text_AddTeamModal_Create_Err + msg);
        } catch (Exception e) {
            throw new AuraHandledException(System.Label.CS_OrgChart_Text_AddTeamModal_Create_Err + e.getMessage());
        }
    }

    /*------------------------------------------------------------
    Author:        Ha Linh
    Company:       Amaris
    Description:   Get queue edit info: Queue Label (from Group by Id) and Queue Team (from FEC_Team_Queue__c by id)
    @param queueId Group (Queue) Id
    @param teamQueueRecordId Id record in FEC_Team_Queue__c
    @return object EditQueueDto
    Test Class:    
    History
    <Date>         <Authors Name>     <Brief Description of Change>
    2026/03/31      Ha Linh          Init
    ------------------------------------------------------------*/
    @AuraEnabled
    public static EditQueueDto getQueueEditInfo(Id queueId, Id teamQueueRecordId) {
        EditQueueDto dto = new EditQueueDto();

        // Load Group (Queue) - use safe list query to avoid QueryException when no rows returned
        List<Group> groups = [SELECT Id, Name FROM Group WHERE Id = :queueId AND Type = :QUEUE_TYPE LIMIT 1];
        if (groups.isEmpty()) {
            throw new AuraHandledException(System.Label.CS_OrgChart_Text_EditQueueModal_Invalid_Queue);
        }
        Group queue = groups[0];
        dto.queueId = queue.Id;
        dto.queueLabel = queue.Name;

        // Resolve FEC_Team_Queue__c mapping
        FEC_Team_Queue__c teamQueue = [
                SELECT Id, FEC_Select_Team__c, FEC_Team__c, FEC_Select_Team__r.Name
                FROM FEC_Team_Queue__c
                WHERE Id = :teamQueueRecordId
                LIMIT 1
            ];

        if (teamQueue != null) {
            dto.teamQueueRecordId = teamQueue.Id;
            dto.teamId = teamQueue.FEC_Select_Team__c;
            dto.queueLabelStatus = teamQueue.FEC_Team__c;
            dto.teamName = teamQueue.FEC_Select_Team__r.Name;
        }
        return dto;
    }
    /*------------------------------------------------------------
    Author:        Ha Linh
    Company:       Amaris
    Description:   Update queue label (Group.Name) and Team mapping (FEC_Team_Queue__c.Team__c)
    @param queueId Group (Queue) Id to update label
    @param newQueueLabel New label for queue (Group.Name)
    @param teamQueueRecordId Id of FEC_Team_Queue__c to update FEC_Select_Team__c
    @param newTeamId New FEC_Select_Team__c Id to map the queue to
    @return Boolean success
    Test Class:    
    History
    <Date>         <Authors Name>     <Brief Description of Change>
    2026/03/31      Ha Linh          Init
    ------------------------------------------------------------*/
    @AuraEnabled
    public static Boolean updateQueueEdit(Id queueId, String newQueueLabel, Id teamQueueRecordId, Id newTeamId, String newLabelStatus) {
        String messageEdit = '';
        String oldValueDisplay = '';
        EditQueueDto info = getQueueEditInfo(queueId, teamQueueRecordId);
        if (info == null) {
            throw new AuraHandledException(System.Label.CS_OrgChart_Text_EditQueueModal_Invalid_Queue);
        }
        Map<String, Object> oldValue = new Map<String, Object>();
        oldValue.put('oldLabel', info.queueLabel != null ? info.queueLabel : null);
        oldValue.put('oldTeam', info.teamName != null ? info.teamName : null);
        oldValue.put('oldLabelStatus', info.queueLabelStatus != null ? info.queueLabelStatus : null);
        // Update Queue Label if provided
        if (!String.isBlank(newQueueLabel)) {
            Group toUpdate = new Group(Id = queueId, Name = newQueueLabel);
            try {
                update toUpdate;
                oldValueDisplay = oldValueDisplay + ' - Old label: ' + oldValue.get('oldLabel');
                messageEdit = messageEdit + ' - Updated label to: ' + newQueueLabel;
            } catch (DmlException d) {
                throw new AuraHandledException(System.Label.CS_OrgChart_Text_EditQueueModal_Update_Err + d.getMessage());
            }
        }
        // Update Team mapping if provided
        FEC_Team_Queue__c tqUpdate = new FEC_Team_Queue__c(Id = teamQueueRecordId);
        Boolean isTqNeeded = false;
        if (newTeamId != null) {
            tqUpdate.FEC_Select_Team__c = newTeamId;
            FEC_Team__c teamByNewTeamId = [SELECT FEC_Team_Label__c FROM FEC_Team__c WHERE Id = :newTeamId LIMIT 1];
            String teamName = teamByNewTeamId.FEC_Team_Label__c;
            oldValueDisplay = oldValueDisplay + ' - Old team: ' + (oldValue.get('oldTeam') != null ? oldValue.get('oldTeam') : 'None');
            messageEdit = messageEdit + ' - Updated team to: ' + teamName;
            isTqNeeded = true;
        }
        if (!String.isBlank(newLabelStatus)) {
            tqUpdate.FEC_Team__c = newLabelStatus;
            oldValueDisplay = oldValueDisplay + ' - Old label status: ' + (oldValue.get('oldLabelStatus') != null ? oldValue.get('oldLabelStatus') : 'None');
            messageEdit = messageEdit + ' - Updated label status to: ' + newLabelStatus;
            isTqNeeded = true;
        }
        if (isTqNeeded) {
            try {
                update tqUpdate;
            } catch (DmlException d) {
                throw new AuraHandledException(System.Label.CS_OrgChart_Text_EditQueueModal_UpdateTeam_Err + d.getMessage());
            }
        }
        if (!String.isBlank(messageEdit)) {
            DepartmentAdmin.insertCustomLog(queueId, CLASS_NAME, 'updateQueueEdit', 'Update Queue', oldValueDisplay, messageEdit);
        }
        return true;
    }

    @AuraEnabled
    public static Boolean isTeamActiveForQueue(String developerName) {

        // Load the FEC_Team_Queue__c record
        List<FEC_Team_Queue__c> teamQueue = [
            SELECT Id, FEC_Select_Team__r.FEC_Team_Active__c
            FROM FEC_Team_Queue__c
            WHERE FEC_Queue_Name__c = :developerName
            LIMIT 1
        ];

        if (teamQueue == null || teamQueue.isEmpty()) {
            return false;
        }
        return teamQueue[0].FEC_Select_Team__r.FEC_Team_Active__c;
    }
}
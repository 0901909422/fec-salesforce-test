public with sharing class FEC_AssignmentExecuteService {
    
    public class ExecuteVisibilityResult {
        @AuraEnabled public Boolean value;
        @AuraEnabled public Boolean shouldUpdate;
    }
    
    private static final Set<String> CLOSED_STATUSES = new Set<String>{
        FEC_ConstantCommon.STATUS_COMPLETED,
        FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED,
        FEC_ConstantCommon.CASE_STATUS_RESOLVED_REJECTED,
        FEC_ConstantCommon.CASE_STATUS_RESOLVED_CANCELLED,
        FEC_ConstantCommon.ASSIGNMENT_AUTORECALLED_STATUS,
        FEC_ConstantCommon.ASSIGNMENT_AUTOCOMPLETE_STATUS
    };
    
    
    @AuraEnabled
    public static void executeAssignment(
        Id caseId
    ) {
        
        Id userId = UserInfo.getUserId();
        
        System.debug('==============================');
        System.debug(
            'START executeAssignment'
            );
        System.debug('caseId = ' + caseId);
        System.debug('userId = ' + userId);
        System.debug('==============================');
        
        User currentUser = [
        SELECT
            Id,
            UserRoleId
        FROM User
        WHERE Id = :userId
        LIMIT 1
    ];
        
        /*
         * STEP 1
         * Query assignments
         */
        List<FEC_Assignment__c> assignments = [
        SELECT
            Id,
            Name,
            FEC_Assignment_Name__c,
            FEC_OwnerID__c,
            FEC_Assignment_Owner__c,
            FEC_Assignment_Status__c
        FROM FEC_Assignment__c
        WHERE
            FEC_Case__c = :caseId
            AND FEC_Assignment_Status__c
                NOT IN :CLOSED_STATUSES
    ];
        
        System.debug(
            'assignments size = '
            + assignments.size()
            );
        
        /*
         * STEP 2
         * Collect queue names
         */
        Set<String> queueNames =
            new Set<String>();
        
        for (
            FEC_Assignment__c assignment :
            assignments
        ) {
            
            if (
                assignment
                .FEC_Assignment_Owner__c
                == null
                &&
                !String.isBlank(
                assignment.FEC_OwnerID__c
                )
            ) {
                queueNames.add(
                    assignment.FEC_OwnerID__c
                    );
            }
        }
        
        System.debug(
            'queueNames = '
            + queueNames
            );
        
        /*
         * STEP 3
         * Query queues by name
         */
        Map<String, Group> queueByName =
            new Map<String, Group>();
        
        if (!queueNames.isEmpty()) {
            
            for (
                Group g : [
                SELECT
                    Id,
                    Name,
                    Type
                FROM Group
                WHERE
                    Type = 'Queue'
                    AND Name IN :queueNames
            ]
            ) {
                queueByName.put(
                    g.Name,
                g
                    );
            }
        }
        
        System.debug(
            'queueByName = '
            + queueByName
            );
        
        /*
         * STEP 4
         * Find executable assignments
         */
        List<FEC_Assignment__c>
            assignmentsToUpdate =
            new List<FEC_Assignment__c>();
        
        for (
            FEC_Assignment__c assignment :
            assignments
        ) {
            
            Boolean matched = false;
            
            /*
             * DIRECT OWNER
             */
            if (
                assignment.FEC_Assignment_Owner__c
                == userId
            ) {
                
                matched = true;
                
                System.debug(
                    'MATCH DIRECT OWNER => '
                    + assignment.Id
                    );
            }
            
            /*
             * QUEUE OWNER
             */
            if (
                !matched
                &&
                assignment
                .FEC_Assignment_Owner__c
                == null
                &&
                queueByName.containsKey(
                assignment.FEC_OwnerID__c
                )
            ) {
                
                Group queueGroup =
                    queueByName.get(
                    assignment.FEC_OwnerID__c
                    );
                
                System.debug(
                    'CHECK QUEUE => '
                    + queueGroup.Name
                    );
                
                /*
                 * direct user in queue
                 */
                Integer directUserCount = [
                SELECT COUNT()
                FROM GroupMember
                WHERE
                    GroupId = :queueGroup.Id
                    AND UserOrGroupId = :userId
            ];
                
                if (directUserCount > 0) {
                    
                    matched = true;
                    
                    System.debug(
                        'MATCH DIRECT QUEUE USER'
                        );
                }
                
                /*
                 * role in queue
                 */
                if (
                    !matched
                    &&
                    currentUser.UserRoleId
                    != null
                ) {
                    
                    Integer roleCount = [
                    SELECT COUNT()
                    FROM GroupMember
                    WHERE
                        GroupId = :queueGroup.Id
                        AND UserOrGroupId IN (
                            SELECT Id
                            FROM Group
                            WHERE
                                Type IN (
                                    'Role',
                                    'RoleAndSubordinates',
                                    'RoleAndSubordinatesInternal'
                                )
                                AND RelatedId =
                                    :currentUser.UserRoleId
                        )
                ];
                    
                    if (roleCount > 0) {
                        
                        matched = true;
                        
                        System.debug(
                            'MATCH ROLE QUEUE'
                            );
                    }
                }
            }
            
            /*
             * TAKE OWNERSHIP
             */
            if (matched) {
                
                System.debug(
                    'TAKE ASSIGNMENT => '
                    + assignment.Id
                    );
                
                assignment.FEC_Assignment_Owner__c = userId;
                assignmentsToUpdate.add(assignment);
            }
        }
        
        /*
         * STEP 5
         * UPDATE
         */
        if (!assignmentsToUpdate.isEmpty()) {
            
            try {
                
                FEC_CaseTriggerHandler.isSystemUpdate = true;
                
                update assignmentsToUpdate;
                
                System.debug(
                    'Assignments updated successfully'
                    );
                
            } catch (Exception e) {
                
                System.debug(
                    'executeAssignment ERROR = '
                    + e.getMessage()
                    );
                
                throw e;
                
            } finally {
                
                FEC_CaseTriggerHandler.isSystemUpdate = false;
            }
        }
    }
}
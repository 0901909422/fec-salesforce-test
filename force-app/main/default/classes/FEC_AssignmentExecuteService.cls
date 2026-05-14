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
    public static ExecuteVisibilityResult canExecuteAssignment(
        Id caseId
    ) {
        
        Id userId = UserInfo.getUserId();
        
        System.debug('==============================');
        System.debug(
            'START canExecuteAssignment'
            );
        System.debug('caseId = ' + caseId);
        System.debug('userId = ' + userId);
        System.debug('==============================');
        
        /*
         * Query current user role
         */
        User currentUser = [
        SELECT
            Id,
            UserRoleId,
            UserRole.Name
        FROM User
        WHERE Id = :userId
        LIMIT 1
    ];
        
        System.debug(
            'UserRoleId = '
            + currentUser.UserRoleId
            );
        
        /*
         * Get queue ids
         */
        Set<Id> queueIds = new Set<Id>();
        
        for (
            GroupMember gm : [
            SELECT GroupId
            FROM GroupMember
            WHERE UserOrGroupId = :userId
        ]
        ) {
            queueIds.add(gm.GroupId);
        }
        
        System.debug(
            'queueIds = '
            + queueIds
            );
        
        /*
         * Assignment logic (OLD LOGIC)
         */
        Integer activeAssignmentCount = [
        SELECT COUNT()
        FROM FEC_Assignment__c
        WHERE
            FEC_Case__c = :caseId
            AND FEC_Assignment_Status__c
                NOT IN :CLOSED_STATUSES
            AND (
                FEC_Assignment_Owner__c = :userId
                OR (
                    FEC_Assignment_Owner__c = null
                    AND FEC_OwnerID__c IN :queueIds
                )
            )
    ];
        
        System.debug(
            'activeAssignmentCount = '
            + activeAssignmentCount
            );
        
        Boolean canExecute =
            activeAssignmentCount > 0;
        /*
         * =================================================
         * NEW LOGIC
         * Check FEC_Assignment_Users__c
         * =================================================
         */
        Case caseRecord = [
            SELECT
                Id,
                FEC_Can_Execute_Assignment__c,
                FEC_Assignment_Users__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        
        System.debug(
            'FEC_Assignment_Users__c = '
            + caseRecord.FEC_Assignment_Users__c
            );
        
        if (
            !canExecute &&
            !String.isBlank(
            caseRecord.FEC_Assignment_Users__c
            )
        ) {
            
            /*
             * Format:
             * xxxx;yyyy;zzzz
             */
            Set<String> assignmentValues =
                new Set<String>();
            
            for (
                String value :
                caseRecord
                .FEC_Assignment_Users__c
                .split(';')
            ) {
                
                if (!String.isBlank(value)) {
                    
                    assignmentValues.add(
                        value.trim()
                        );
                }
            }
            
            System.debug(
                'assignmentValues = '
                + assignmentValues
                );
            
            /*
             * ============================================
             * 1. Direct user match
             * ============================================
             */
            Boolean matchedUser =
                assignmentValues.contains(
                String.valueOf(userId)
                );
            
            /*
             * ============================================
             * 2. Direct role match
             * ============================================
             */
            Boolean matchedRole =
                currentUser.UserRoleId != null
                &&
                assignmentValues.contains(
                String.valueOf(
                currentUser.UserRoleId
                )
                );
            
            System.debug(
                'matchedUser = '
                + matchedUser
                );
            
            System.debug(
                'matchedRole = '
                + matchedRole
                );
            
            /*
             * ============================================
             * 3. Queue logic
             * ============================================
             */
            Boolean matchedQueue = false;
            
            if (
                !matchedUser &&
                !matchedRole
            ) {
                
                /*
                 * Get queues from assignment values
                 */
                Set<Id> queueIdsFromAssignment =
                    new Set<Id>();
                Set<String> queueNamesFromAssignment =
                    new Set<String>();
                
                for (String value : assignmentValues) {
                    
                    /*
                     * Queue prefix = 00G
                     */
                    if (
                        value.startsWith('00G')
                    ) {
                        queueIdsFromAssignment.add(
                            (Id)value
                            );
                    } else if (String.isNotBlank(value)) {
                        // tungnm37 fix: hỗ trợ Queue Name (không phải Id)
                        queueNamesFromAssignment.add(value);
                    }
                }
                
                // tungnm37 fix: lookup Queue Id từ Queue Name
                if (!queueNamesFromAssignment.isEmpty()) {
                    for (Group g : [SELECT Id FROM Group WHERE Name IN :queueNamesFromAssignment AND Type = 'Queue']) {
                        queueIdsFromAssignment.add(g.Id);
                    }
                }
                
                System.debug(
                    'queueIdsFromAssignment = '
                    + queueIdsFromAssignment
                    );
                
                if (!queueIdsFromAssignment.isEmpty()) {
                    
                    /*
                     * ====================================
                     * 3.1 Check direct user in queue
                     * ====================================
                     */
                    Integer directQueueMemberCount = [
                SELECT COUNT()
                FROM GroupMember
                WHERE
                    GroupId IN :queueIdsFromAssignment
                    AND UserOrGroupId = :userId
            ];
                    
                    System.debug(
                        'directQueueMemberCount = '
                        + directQueueMemberCount
                        );
                    
                    matchedQueue =
                        directQueueMemberCount > 0;
                    
                    /*
                     * ====================================
                     * 3.2 Check role in queue
                     * ====================================
                     */
                    if (
                        !matchedQueue &&
                        currentUser.UserRoleId != null
                    ) {
                        
                        /*
                         * Get roles added into queue
                         */
                        Set<Id> roleIdsInQueue =
                            new Set<Id>();
                        
                        for (
                            GroupMember gm : [
                        SELECT
                            UserOrGroupId
                        FROM GroupMember
                        WHERE GroupId
                            IN :queueIdsFromAssignment
                    ]
                        ) {
                            
                            Id memberId =
                                gm.UserOrGroupId;
                            
                            /*
                             * Role prefix = 00E
                             */
                            if (
                                String.valueOf(memberId)
                                .startsWith('00E')
                            ) {
                                
                                roleIdsInQueue.add(
                                    memberId
                                    );
                            }
                        }
                        
                        System.debug(
                            'roleIdsInQueue = '
                            + roleIdsInQueue
                            );
                        
                        /*
                         * Current user role
                         * belongs to queue role
                         */
                        matchedQueue =
                            roleIdsInQueue.contains(
                            currentUser.UserRoleId
                            );
                    }
                }
            }
            
            System.debug(
                'matchedQueue = '
                + matchedQueue
                );
            
            if (
                matchedUser ||
                matchedRole ||
                matchedQueue
            ) {
                
                System.debug(
                    'Assignment Users matched'
                    );
                
                canExecute = true;
            }
        }
        
        System.debug(
            'FINAL canExecute = '
            + canExecute
            );
        
        ExecuteVisibilityResult result =
            new ExecuteVisibilityResult();
        
        result.value = canExecute;
        
        Boolean currentValue =
            caseRecord
            .FEC_Can_Execute_Assignment__c
            == true;
        
        result.shouldUpdate =
            currentValue != canExecute;
        
        System.debug(
            'currentValue = '
            + currentValue
            );
        
        System.debug(
            'newValue = '
            + canExecute
            );
        
        System.debug(
            'shouldUpdate = '
            + result.shouldUpdate
            );
        
        /*
         * IMPORTANT:
         * Update Dynamic Action field
         */
        if (result.shouldUpdate) {
            
            try {
                
                System.debug(
                    'START UPDATE CASE'
                    );
                
                FEC_CaseTriggerHandler.isSystemUpdate = true;
                
                /*
                 * UPDATE HERE
                 */
                update new Case(
                    Id = caseId,
                FEC_Can_Execute_Assignment__c =
                    canExecute
                    );
                
                System.debug(
                    'Case updated successfully'
                    );
                
            } catch (Exception e) {
                
                System.debug(
                    'FEC_AssignmentExecuteService ERROR: '
                    + e.getMessage()
                    );
                
                System.debug(
                    'STACK: '
                    + e.getStackTraceString()
                    );
                
                throw e;
                
            } finally {
                
                FEC_CaseTriggerHandler.isSystemUpdate = false;
            }
        } else {
            
            System.debug(
                'SKIP UPDATE: value unchanged'
                );
        }
        
        return result;
    }
    
    
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
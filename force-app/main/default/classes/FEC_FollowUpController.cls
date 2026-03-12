/**
 * @description Controller xử lý logic cho tính năng Follow-up Case
 * @author Toannd61
 * @date 2025-12-23
 * @modified 2026-01-27 - Refactored and optimized code
 */
public without sharing class FEC_FollowUpController {
    
    // private static final String FOLLOW_TYPE_RESOLVED = 'Until Case is Resolved';
    // private static final String FOLLOW_TYPE_UNFOLLOW = 'Until choosing Unfollow';
    // private static final String FRONTEND_TYPE_RESOLVED = 'UNTIL_RESOLVED';
    // private static final String FRONTEND_TYPE_UNFOLLOW = 'UNTIL_UNFOLLOW';
    
    /**
     * @description Wrapper class cho watcher information
     */
    public class WatcherDetail {
        @AuraEnabled public String odtId;
        @AuraEnabled public String odtUser;
        @AuraEnabled public String odtUserRole;
        @AuraEnabled public String odtFollowUpType;
        @AuraEnabled public Datetime odtDatetime;
        @AuraEnabled public Boolean odtActive;
        
        public WatcherDetail(String id, String user, String role, String type, Datetime dt, Boolean active) {
            this.odtId = id;
            this.odtUser = user;
            this.odtUserRole = role;
            this.odtFollowUpType = type;
            this.odtDatetime = dt;
            this.odtActive = active;
        }
    }
    
    // ==================== PUBLIC METHODS ====================
    
    /**
     * @description Kiểm tra trạng thái follow của user
     * Logic: CHỈ cho phép unfollow khi followType = "Until Case is Resolved"
     */
    @AuraEnabled(cacheable=false)
    public static Map<String, Object> checkFollowStatus(String caseId) {
        try {
            String currentUserId = UserInfo.getUserId();
            
            // Query Case
            Case caseRecord = [SELECT Id, OwnerId, CreatedById, Status FROM Case WHERE Id = :caseId LIMIT 1];
            
            // Query Active Watcher
            List<FEC_Watcher__c> activeWatchers = [
                SELECT FEC_Follow_up_Type__c
                FROM FEC_Watcher__c
                WHERE FEC_Case__c = :caseId AND FEC_Watcher_User__c = :currentUserId AND FEC_Active__c = true
                LIMIT 1
            ];
            
            Boolean isFollowing = !activeWatchers.isEmpty();
            String followType = '';
            Boolean canUnfollow = false;
            
            if (isFollowing) {
                followType = convertToFrontendValue(activeWatchers[0].FEC_Follow_up_Type__c);
                // CHO PHÉP unfollow với MỌI follow type
                canUnfollow = true;
            } else {
                // Lấy followType cũ nếu có (để pre-select trong UI)
                List<FEC_Watcher__c> inactiveWatchers = [
                    SELECT FEC_Follow_up_Type__c FROM FEC_Watcher__c
                    WHERE FEC_Case__c = :caseId AND FEC_Watcher_User__c = :currentUserId AND FEC_Active__c = false
                    LIMIT 1
                ];
                if (!inactiveWatchers.isEmpty()) {
                    followType = convertToFrontendValue(inactiveWatchers[0].FEC_Follow_up_Type__c);
                }
            }
            
            return new Map<String, Object>{
                'isFollowing' => isFollowing,
                'followType' => followType,
                'canUnfollow' => canUnfollow,
                'isOwner' => caseRecord.OwnerId == currentUserId,
                'isCreator' => caseRecord.CreatedById == currentUserId,
                'status' => caseRecord.Status
            };
            
        } catch (Exception e) {
            throw new AuraHandledException(String.format(System.Label.FEC_MSG_FollowUp_Check_Status_Error, new List<Object>{ e.getMessage() }));
        }
    }
    
    /**
     * @description Lấy danh sách watchers đang active
     */
    @AuraEnabled(cacheable=true)
    public static List<WatcherDetail> getWatchersList(String caseId) {
        try {
            List<WatcherDetail> result = new List<WatcherDetail>();
            if (String.isBlank(caseId)) return result;
            
            // User Role lấy từ FEC_User_Role__c (text)
            for (FEC_Watcher__c w : [
                SELECT Id, FEC_User__c, FEC_User_Role__c, FEC_Follow_up_Type__c, CreatedDate,
                       FEC_Watcher_User__r.Email
                FROM FEC_Watcher__c
                WHERE FEC_Case__c = :caseId AND FEC_Active__c = true
                ORDER BY CreatedDate ASC
            ]) {
                String userEmail = String.isNotBlank(w.FEC_User__c) ? w.FEC_User__c : FEC_CommonUltils.defaultToEmpty(w.FEC_Watcher_User__r?.Email);
                String userRole = FEC_CommonUltils.defaultToEmpty(w.FEC_User_Role__c);
                result.add(new WatcherDetail(w.Id, userEmail, userRole, w.FEC_Follow_up_Type__c, w.CreatedDate, true));
            }
            return result;
            
        } catch (Exception e) {
            throw new AuraHandledException(String.format(System.Label.FEC_MSG_FollowUp_Get_Watchers_Error, new List<Object>{ e.getMessage() }));
        }
    }
    
    /**
     * @description Follow Case
     */
    @AuraEnabled
    public static String followCase(String caseId, String followType) {
        try {
            String currentUserId = UserInfo.getUserId();
            String picklistValue = convertToPicklistValue(followType);
            
            // Get User info
            User currentUser = [SELECT Email, UserRole.Name FROM User WHERE Id = :currentUserId LIMIT 1];
            Case caseRecord = [SELECT FEC_Follow_Up_User__c FROM Case WHERE Id = :caseId LIMIT 1];
            
            // Check/Create Watcher
            List<FEC_Watcher__c> existingWatchers = [
                SELECT Id, FEC_Active__c FROM FEC_Watcher__c
                WHERE FEC_Case__c = :caseId AND FEC_Watcher_User__c = :currentUserId LIMIT 1
            ];
            
            Id watcherId;
            Boolean isReFollow = false;
            
            if (!existingWatchers.isEmpty()) {
                // Update existing watcher (cập nhật cả FEC_User_Role__c, FEC_User__c để hiển thị đúng khi re-follow)
                watcherId = existingWatchers[0].Id;
                isReFollow = !existingWatchers[0].FEC_Active__c;
                
                update new FEC_Watcher__c(
                    Id = watcherId,
                    FEC_User__c = currentUser.Email,
                    FEC_User_Role__c = currentUser.UserRole?.Name,
                    FEC_Follow_up_Type__c = picklistValue,
                    FEC_Active__c = true
                );
            } else {
                // Create new watcher
                FEC_Watcher__c newWatcher = new FEC_Watcher__c(
                    FEC_Case__c = caseId,
                    FEC_Watcher_User__c = currentUserId,
                    FEC_User__c = currentUser.Email,
                    FEC_User_Role__c = currentUser.UserRole?.Name,
                    FEC_Follow_up_Type__c = picklistValue,
                    FEC_Active__c = false
                );
                insert newWatcher;
                watcherId = newWatcher.Id;
            }
            
            // Add to Case Team and Follow Up User field if needed
            Boolean userInFollowUpField = isUserInFollowUpField(caseRecord.FEC_Follow_Up_User__c, currentUserId);
            
            if (!userInFollowUpField || isReFollow) {
                addUserToCaseTeam(caseId, currentUserId);
                addUserToFollowUpField(caseId, currentUserId, picklistValue);
            } else {
                addUserToFollowUpField(caseId, currentUserId, picklistValue);
            }
            
            // Set watcher active
            update new FEC_Watcher__c(Id = watcherId, FEC_Active__c = true);
            
            publishFollowUpdateEvent(caseId);
            return System.Label.FEC_MSG_FollowUp_Save_Success;
            
        } catch (Exception e) {
            throw new AuraHandledException(String.format(System.Label.FEC_MSG_FollowUp_Save_Error, new List<Object>{ e.getMessage() }));
        }
    }
    
    /**
     * @description Thêm user được chọn (từ modal Select Follow-Up User) vào danh sách follow-up và bảng Watcher Information.
     * Chỉ Case Owner mới gọi được. Tạo/cập nhật FEC_Watcher__c, thêm Case Team, cập nhật FEC_Follow_Up_User__c và publish event để LWC Watchers Information refresh.
     */
    @AuraEnabled
    public static String followCaseForUser(String caseId, String targetUserId, String followType) {
        try {
            if (String.isBlank(caseId) || String.isBlank(targetUserId)) {
                throw new AuraHandledException(System.Label.FEC_MSG_FollowUp_Case_User_Required);
            }
            String currentUserId = UserInfo.getUserId();
            Case caseRecord = [SELECT Id, OwnerId, FEC_Follow_Up_User__c FROM Case WHERE Id = :caseId LIMIT 1];
            if (caseRecord.OwnerId != currentUserId) {
                throw new AuraHandledException(System.Label.FEC_MSG_FollowUp_Owner_Only);
            }
            String picklistValue = convertToPicklistValue(followType);
            List<User> targetUsers = [SELECT Id, Email, UserRole.Name FROM User WHERE Id = :targetUserId AND IsActive = true LIMIT 1];
            if (targetUsers.isEmpty()) {
                throw new AuraHandledException(System.Label.FEC_MSG_FollowUp_User_Not_Found);
            }
            User targetUser = targetUsers[0];
            // Create or update Watcher for target user (hiển thị trong bảng Watcher Information)
            List<FEC_Watcher__c> existingWatchers = [
                SELECT Id, FEC_Active__c FROM FEC_Watcher__c
                WHERE FEC_Case__c = :caseId AND FEC_Watcher_User__c = :targetUserId LIMIT 1
            ];
            if (!existingWatchers.isEmpty()) {
                update new FEC_Watcher__c(
                    Id = existingWatchers[0].Id,
                    FEC_User__c = targetUser.Email,
                    FEC_User_Role__c = targetUser.UserRole?.Name,
                    FEC_Follow_up_Type__c = picklistValue,
                    FEC_Active__c = true
                );
            } else {
                insert new FEC_Watcher__c(
                    FEC_Case__c = caseId,
                    FEC_Watcher_User__c = targetUserId,
                    FEC_User__c = targetUser.Email,
                    FEC_User_Role__c = targetUser.UserRole?.Name,
                    FEC_Follow_up_Type__c = picklistValue,
                    FEC_Active__c = true
                );
            }
            addUserToCaseTeam(caseId, targetUserId);
            addUserToFollowUpField(caseId, targetUserId, picklistValue);
            publishFollowUpdateEvent(caseId);
            return System.Label.FEC_MSG_FollowUp_Add_User_Success;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(String.format(System.Label.FEC_MSG_FollowUp_Add_User_Error, new List<Object>{ e.getMessage() }));
        }
    }
    
    /**
     * @description Unfollow Case
     * CHO PHÉP unfollow với MỌI follow type
     */
    @AuraEnabled
    public static String unfollowCase(String caseId) {
        try {
            String currentUserId = UserInfo.getUserId();
            
            // Find watcher
            List<FEC_Watcher__c> watchers = [
                SELECT Id, FEC_Active__c, FEC_Follow_up_Type__c FROM FEC_Watcher__c
                WHERE FEC_Case__c = :caseId AND FEC_Watcher_User__c = :currentUserId LIMIT 1
            ];
            
            if (watchers.isEmpty()) {
                throw new AuraHandledException(System.Label.FEC_MSG_FollowUp_Not_Following);
            }
    
            // Không validate followType nữa - user có thể unfollow bất cứ lúc nào
            
            if (!watchers[0].FEC_Active__c) {
                return System.Label.FEC_MSG_FollowUp_Already_Unfollowed;
            }
            
            // Unfollow: Delete watcher record, remove from Case Team and Follow Up User field
            delete watchers[0];
            removeUserFromFollowUpField(caseId, currentUserId);
            removeUserFromCaseTeam(caseId, currentUserId);
            publishFollowUpdateEvent(caseId);
            
            return System.Label.FEC_MSG_FollowUp_Unfollow_Success;
            
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * @description Auto unfollow tất cả users khi Case resolved
     * Called from Trigger
     */
    public static void removeWatchersOnCaseResolved(Set<Id> caseIds) {
        try {
            if (caseIds == null || caseIds.isEmpty()) return;
            
            List<FEC_Watcher__c> activeWatchers = [
                SELECT Id, FEC_Case__c, FEC_Watcher_User__c FROM FEC_Watcher__c
                WHERE FEC_Case__c IN :caseIds AND FEC_Active__c = true
            ];
            
            if (activeWatchers.isEmpty()) return;
            
            Set<Id> userIds = new Set<Id>();
            for (FEC_Watcher__c w : activeWatchers) {
                userIds.add(w.FEC_Watcher_User__c);
            }
            
            // Delete watcher records
            delete activeWatchers;
            
            // Clear Follow Up User field
            List<Case> casesToUpdate = new List<Case>();
            for (Id caseId : caseIds) {
                casesToUpdate.add(new Case(Id = caseId, FEC_Follow_Up_User__c = FEC_ConstantCommon.STR_EMPTY));
            }
            update casesToUpdate;
            
            // Remove from Case Team
            List<CaseTeamMember> teamMembers = [
                SELECT Id FROM CaseTeamMember
                WHERE ParentId IN :caseIds AND MemberId IN :userIds
            ];
            if (!teamMembers.isEmpty()) delete teamMembers;
            
            // Publish events
            for (Id caseId : caseIds) {
                publishFollowUpdateEvent(caseId);
            }
            
        } catch (Exception e) {
            System.debug('Error in removeWatchersOnCaseResolved: ' + e.getMessage());
        }
    }
    
    /**
     * @description Bulk add users to follow-up (for auto-follow from trigger)
     */
    public static void addUsersToFollowUpBulk(Map<Id, Set<Id>> caseUserMap, String followType) {
        if (caseUserMap == null || caseUserMap.isEmpty()) return;
        
        try {
            Map<Id, Case> caseMap = new Map<Id, Case>([
                SELECT Id, Status, FEC_Follow_Up_User__c FROM Case WHERE Id IN :caseUserMap.keySet()
            ]);
            
            // Get existing watchers
            Map<String, FEC_Watcher__c> existingWatchersMap = new Map<String, FEC_Watcher__c>();
            for (FEC_Watcher__c w : [
                SELECT Id, FEC_Case__c, FEC_Watcher_User__c, FEC_Active__c, FEC_Follow_up_Type__c
                FROM FEC_Watcher__c WHERE FEC_Case__c IN :caseUserMap.keySet()
            ]) {
                existingWatchersMap.put(String.valueOf(w.FEC_Case__c) + '_' + String.valueOf(w.FEC_Watcher_User__c), w);
            }
            
            // Get existing Case Team Members
            Map<String, Boolean> existingTeamMap = new Map<String, Boolean>();
            for (CaseTeamMember ctm : [
                SELECT ParentId, MemberId FROM CaseTeamMember WHERE ParentId IN :caseUserMap.keySet()
            ]) {
                existingTeamMap.put(String.valueOf(ctm.ParentId) + '_' + String.valueOf(ctm.MemberId), true);
            }
            
            // Get users info
            Set<Id> allUserIds = new Set<Id>();
            for (Set<Id> ids : caseUserMap.values()) allUserIds.addAll(ids);
            
            Map<Id, User> userMap = new Map<Id, User>([
                SELECT Id, Email, UserRole.Name FROM User WHERE Id IN :allUserIds
            ]);
            
            // Get Case Team Role
            List<CaseTeamRole> roles = [SELECT Id FROM CaseTeamRole WHERE AccessLevel = 'Edit' LIMIT 1];
            if (roles.isEmpty()) roles = [SELECT Id FROM CaseTeamRole LIMIT 1];
            Id roleId = roles.isEmpty() ? null : roles[0].Id;
            
            // Collections for bulk operations
            List<FEC_Watcher__c> newWatchers = new List<FEC_Watcher__c>();
            List<FEC_Watcher__c> watchersToUpdate = new List<FEC_Watcher__c>();
            List<CaseTeamMember> newTeamMembers = new List<CaseTeamMember>();
            List<Case> casesToUpdate = new List<Case>();
            
            String compactType = getCompactTypeForFollowUp(followType);
            
            for (Id caseId : caseUserMap.keySet()) {
                Case c = caseMap.get(caseId);
                if (c == null || FEC_CommonUltils.isCaseStatusResolved(c.Status)) continue;
                
                List<String> followUpEntries = new List<String>();
                if (String.isNotBlank(c.FEC_Follow_Up_User__c)) {
                    followUpEntries.addAll(c.FEC_Follow_Up_User__c.split(FEC_ConstantCommon.FOLLOW_UP_FIELD_DELIMITER));
                }
                Boolean needUpdate = false;
                
                for (Id userId : caseUserMap.get(caseId)) {
                    User u = userMap.get(userId);
                    if (u == null) continue;
                    
                    String key = String.valueOf(caseId) + '_' + String.valueOf(userId);
                    FEC_Watcher__c existingWatcher = existingWatchersMap.get(key);
                    
                    // Create or update watcher
                    if (existingWatcher != null) {
                        existingWatcher.FEC_Active__c = true;
                        existingWatcher.FEC_Follow_up_Type__c = followType;
                        watchersToUpdate.add(existingWatcher);
                    } else {
                        newWatchers.add(new FEC_Watcher__c(
                            FEC_Case__c = caseId,
                            FEC_Watcher_User__c = userId,
                            FEC_User__c = u.Email,
                            FEC_User_Role__c = u.UserRole?.Name,
                            FEC_Follow_up_Type__c = followType,
                            FEC_Active__c = true
                        ));
                    }
                    
                    // Add to Follow Up User field if not exists
                    if (!isUserInFollowUpField(c.FEC_Follow_Up_User__c, userId)) {
                        followUpEntries.add(userId + FEC_ConstantCommon.KEY_DELIMITER_PIPE + compactType);
                        needUpdate = true;
                        
                        // Add to Case Team if not exists
                        if (roleId != null && !existingTeamMap.containsKey(key)) {
                            newTeamMembers.add(new CaseTeamMember(
                                ParentId = caseId,
                                MemberId = userId,
                                TeamRoleId = roleId
                            ));
                        }
                    }
                }
                
                if (needUpdate) {
                    casesToUpdate.add(new Case(
                        Id = caseId,
                        FEC_Follow_Up_User__c = String.join(followUpEntries, FEC_ConstantCommon.FOLLOW_UP_FIELD_DELIMITER)
                    ));
                }
            }
            
            // Bulk DML
            if (!newWatchers.isEmpty()) insert newWatchers;
            if (!watchersToUpdate.isEmpty()) update watchersToUpdate;
            if (!newTeamMembers.isEmpty()) Database.insert(newTeamMembers, false);
            if (!casesToUpdate.isEmpty()) update casesToUpdate;
            
        } catch (Exception e) {
            System.debug('Error in addUsersToFollowUpBulk: ' + e.getMessage());
        }
    }
    
    // ==================== PRIVATE HELPER METHODS ====================
    
    private static String convertToPicklistValue(String frontendValue) {
        if (FEC_ConstantCommon.FOLLOW_UP_FRONTEND_UNFOLLOW.equalsIgnoreCase(frontendValue)) {
            return FEC_ConstantCommon.FOLLOW_UP_TYPE_UNTIL_UNFOLLOW;
        }
        return FEC_ConstantCommon.FOLLOW_UP_TYPE_UNTIL_RESOLVED;
    }
    
    private static String convertToFrontendValue(String picklistValue) {
        if (FEC_ConstantCommon.FOLLOW_UP_TYPE_UNTIL_UNFOLLOW.equalsIgnoreCase(picklistValue)) {
            return FEC_ConstantCommon.FOLLOW_UP_FRONTEND_UNFOLLOW;
        }
        return FEC_ConstantCommon.FOLLOW_UP_FRONTEND_RESOLVED;
    }
    
    private static Boolean isUserInFollowUpField(String field, String userId) {
        if (String.isBlank(field) || String.isBlank(userId)) return false;
        String shortId = userId.length() > 15 ? userId.substring(0, 15) : userId;
        return field.contains(userId) || field.contains(shortId);
    }
    
    private static String getCompactTypeForFollowUp(String followType) {
        return FEC_ConstantCommon.FOLLOW_UP_TYPE_UNTIL_RESOLVED.equals(followType)
            ? FEC_ConstantCommon.FOLLOW_UP_COMPACT_RESOLVED
            : FEC_ConstantCommon.FOLLOW_UP_COMPACT_UNFOLLOW;
    }
    
    private static void addUserToCaseTeam(String caseId, String userId) {
        try {
            // Check if already exists
            if (![SELECT Id FROM CaseTeamMember WHERE ParentId = :caseId AND MemberId = :userId LIMIT 1].isEmpty()) {
                return;
            }
            
            // Get role
            List<CaseTeamRole> roles = [SELECT Id FROM CaseTeamRole WHERE AccessLevel = 'Edit' LIMIT 1];
            if (roles.isEmpty()) roles = [SELECT Id FROM CaseTeamRole LIMIT 1];
            if (roles.isEmpty()) return;
            
            insert new CaseTeamMember(ParentId = caseId, MemberId = userId, TeamRoleId = roles[0].Id);
        } catch (Exception e) {
            System.debug('Error adding user to Case Team: ' + e.getMessage());
        }
    }
    
    private static void addUserToFollowUpField(String caseId, String userId, String followType) {
        try {
            Case c = [SELECT FEC_Follow_Up_User__c FROM Case WHERE Id = :caseId LIMIT 1];
            String compactType = getCompactTypeForFollowUp(followType);
            String newEntry = userId + FEC_ConstantCommon.KEY_DELIMITER_PIPE + compactType;
            
            if (isUserInFollowUpField(c.FEC_Follow_Up_User__c, userId)) {
                // Update existing entry
                List<String> entries = c.FEC_Follow_Up_User__c.split(FEC_ConstantCommon.FOLLOW_UP_FIELD_DELIMITER);
                List<String> updated = new List<String>();
                String shortId = userId.length() > 15 ? userId.substring(0, 15) : userId;
                
                for (String entry : entries) {
                    if (entry.contains(userId) || entry.contains(shortId)) {
                        updated.add(entry.split('\\' + FEC_ConstantCommon.KEY_DELIMITER_PIPE)[0] + FEC_ConstantCommon.KEY_DELIMITER_PIPE + compactType);
                    } else {
                        updated.add(entry);
                    }
                }
                update new Case(Id = caseId, FEC_Follow_Up_User__c = String.join(updated, FEC_ConstantCommon.FOLLOW_UP_FIELD_DELIMITER));
            } else {
                // Add new entry
                String newValue = String.isBlank(c.FEC_Follow_Up_User__c) ? newEntry : c.FEC_Follow_Up_User__c + FEC_ConstantCommon.FOLLOW_UP_FIELD_DELIMITER + newEntry;
                update new Case(Id = caseId, FEC_Follow_Up_User__c = newValue);
            }
        } catch (Exception e) {
            System.debug('Error adding user to Follow Up field: ' + e.getMessage());
        }
    }
    
    private static void removeUserFromFollowUpField(String caseId, String userId) {
        try {
            Case c = [SELECT FEC_Follow_Up_User__c FROM Case WHERE Id = :caseId LIMIT 1];
            if (String.isBlank(c.FEC_Follow_Up_User__c)) return;
            
            List<String> entries = c.FEC_Follow_Up_User__c.split(FEC_ConstantCommon.FOLLOW_UP_FIELD_DELIMITER);
            List<String> remaining = new List<String>();
            String shortId = userId.length() > 15 ? userId.substring(0, 15) : userId;
            
            for (String entry : entries) {
                if (!entry.contains(userId) && !entry.contains(shortId)) {
                    remaining.add(entry);
                }
            }
            
            update new Case(Id = caseId, FEC_Follow_Up_User__c = remaining.isEmpty() ? FEC_ConstantCommon.STR_EMPTY : String.join(remaining, FEC_ConstantCommon.FOLLOW_UP_FIELD_DELIMITER));
        } catch (Exception e) {
            System.debug('Error removing user from Follow Up field: ' + e.getMessage());
        }
    }
    
    private static void removeUserFromCaseTeam(String caseId, String userId) {
        try {
            List<CaseTeamMember> members = [SELECT Id FROM CaseTeamMember WHERE ParentId = :caseId AND MemberId = :userId];
            if (!members.isEmpty()) delete members;
        } catch (Exception e) {
            System.debug('Error removing user from Case Team: ' + e.getMessage());
        }
    }
    
    private static void publishFollowUpdateEvent(String caseId) {
        try {
            EventBus.publish(new FEC_Case_Follow_Update__e(FEC_Case_Id__c = caseId));
        } catch (Exception e) {
            System.debug('Error publishing event: ' + e.getMessage());
        }
    }
    @AuraEnabled(cacheable=false)
    public static List<Map<String, String>> searchUsers(String searchTerm) {
        try {
            List<Map<String, String>> results = new List<Map<String, String>>();
            String term = String.isBlank(searchTerm) ? null : searchTerm.trim();
            if (String.isBlank(term)) {
                // Hiển thị danh sách user có sẵn khi focus vào ô (chưa nhập)
                for (User u : [SELECT Id, Name, Email, Username FROM User WHERE IsActive = true ORDER BY Name ASC LIMIT 50]) {
                    results.add(new Map<String, String>{
                        'id' => u.Id,
                        'name' => u.Name,
                        'email' => u.Email != null ? u.Email : '',
                        'username' => u.Username != null ? u.Username : ''
                    });
                }
            } else if (term.length() < 2) {
                return new List<Map<String, String>>();
            } else {
                String likeTerm = '%' + String.escapeSingleQuotes(term) + '%';
                List<User> users = [SELECT Id, Name, Email, Username FROM User WHERE IsActive = true AND (Email LIKE :likeTerm OR Name LIKE :likeTerm OR Username LIKE :likeTerm) ORDER BY Name ASC LIMIT 100];
                // Ưu tiên: Username/Name bắt đầu bằng search term lên trước
                String termLower = term.toLowerCase();
                List<Map<String, String>> prefixMatch = new List<Map<String, String>>();
                List<Map<String, String>> otherMatch = new List<Map<String, String>>();
                for (User u : users) {
                    Map<String, String> m = new Map<String, String>{
                        'id' => u.Id,
                        'name' => u.Name,
                        'email' => u.Email != null ? u.Email : '',
                        'username' => u.Username != null ? u.Username : ''
                    };
                    Boolean userNameMatch = u.Username != null && u.Username.toLowerCase().startsWith(termLower);
                    Boolean namePrefixMatch = u.Name != null && u.Name.toLowerCase().startsWith(termLower);
                    if (userNameMatch || namePrefixMatch) {
                        prefixMatch.add(m);
                    } else {
                        otherMatch.add(m);
                    }
                }
                results.addAll(prefixMatch);
                results.addAll(otherMatch);
                if (results.size() > 50) {
                    List<Map<String, String>> trimmed = new List<Map<String, String>>();
                    for (Integer i = 0; i < 50 && i < results.size(); i++) {
                        trimmed.add(results[i]);
                    }
                    return trimmed;
                }
            }
            return results;
        } catch (Exception e) {
            System.debug('Error searching users: ' + e.getMessage());
            return new List<Map<String, String>>();
        }
    }
}

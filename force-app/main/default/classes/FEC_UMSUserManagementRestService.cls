@RestResource(urlMapping='/ums/v1/users/*')
global without sharing class FEC_UMSUserManagementRestService {
    private static final String STATUS_SUCCESS = 'S';
    private static final String STATUS_FAIL = 'F';
    private static final String UPDATE_TYPE_CREATE = 'C';
    private static final String UPDATE_TYPE_REPLACE = 'R';
    private static final String UPDATE_TYPE_APPEND = 'A';
    private static final String ACTION_DEACTIVATE = 'D';
    private static final String ACTION_REACTIVATE = 'R';

    global class UserUpsertRequest {
        global String RequestorID;
        global String UpdateType;
        global List<UserPayload> UserList;
    }

    global class UserPayload {
        global String UserID;
        global String UserName;
        global String FirstName;
        global String LastName;
        global String FEEmail;
        global String Position;
        global String ReportTo;
        global String OrgUnit;
        global String OrgDivision;
        global String MainQueue;
        global String DefaultQueue;
        /** Salesforce UserRole.Name, e.g. Customer Service E-com Team Leader 1 */
        global String Role;
        /** Permission Set Group DeveloperName / Label / Id */
        global List<String> ListUserRole;
    }

    global class UserStatusRequest {
        global String RequestorID;
        global String ActionType;
        global List<UserStatusPayload> UserList;
    }

    global class UserStatusPayload {
        global String UserID;
    }

    global class UserMessage {
        global String Status;
        global String Description;
        global String UserID;
    }

    global class UMSMutationResponse {
        global List<UserMessage> Message;
        global String TransID;
        global String RequestorID;
    }

    global class UserInfo {
        global String UserID;
        global String UserName;
        global String FEEmail;
        global Boolean IsDeactivated;
        global String RoleList;
        global Datetime LastLoginDate;
        global Datetime LastChangePasswordDate;
        global String CreatedBy;
        global Datetime CreatedDate;
        global String UpdateBy;
        global Datetime UpdatedDate;
        global String OrgUnit;
        global String OrgDivision;
        global String MainQueue;
        global String DefaultQueue;
    }

    global class UMSGetInfoResponse {
        global String Status;
        global String Description;
        global UserInfo Infor;
        global String TransID;
        global String RequestorID;
    }

    global class UMSGetAllResponse {
        global String Status;
        global String Description;
        global List<UserInfo> Data;
        global String TransID;
        global String RequestorID;
    }

    @HttpPost
    global static void doPost() {
        RestResponse res = RestContext.response;
        res.addHeader(
            FEC_ConstantCommon.HTTP_HEADER_CONTENT_TYPE,
            FEC_ConstantCommon.API_CONTENT_TYPE_JSON
        );
        String uri = (RestContext.request != null && RestContext.request.requestURI != null)
            ? RestContext.request.requestURI.toLowerCase()
            : '';
        if (uri.endsWith('/status')) {
            handleStatus();
        } else {
            handleCreateOrUpdate();
        }
    }

    @HttpGet
    global static void doGet() {
        RestResponse res = RestContext.response;
        res.addHeader(
            FEC_ConstantCommon.HTTP_HEADER_CONTENT_TYPE,
            FEC_ConstantCommon.API_CONTENT_TYPE_JSON
        );
        String uri = (RestContext.request != null && RestContext.request.requestURI != null)
            ? RestContext.request.requestURI.toLowerCase()
            : '';
        if (uri.endsWith('/info')) {
            handleGetInfo();
        } else {
            handleGetAll();
        }
    }

    private static void handleCreateOrUpdate() {
        String transId = FEC_CommonUltils.generateTransactionUUID();
        RestResponse res = RestContext.response;
        UMSMutationResponse response = new UMSMutationResponse();
        response.TransID = transId;
        response.Message = new List<UserMessage>();

        try {
            UserUpsertRequest req = (UserUpsertRequest) JSON.deserialize(
                RestContext.request.requestBody == null ? null : RestContext.request.requestBody.toString(),
                UserUpsertRequest.class
            );
            response.RequestorID = req != null ? req.RequestorID : null;

            if (req == null) {
                throw new UMSException('UMS-001: Missing request body');
            }
            if (String.isBlank(req.RequestorID)) {
                throw new UMSException('UMS-001: Missing required field: RequestorID');
            }
            if (req.UserList == null || req.UserList.isEmpty()) {
                throw new UMSException('UMS-001: Missing required field: UserList');
            }

            String updateType = String.isBlank(req.UpdateType)
                ? UPDATE_TYPE_CREATE
                : req.UpdateType.trim().toUpperCase();
            if (
                updateType != UPDATE_TYPE_CREATE &&
                updateType != UPDATE_TYPE_REPLACE &&
                updateType != UPDATE_TYPE_APPEND
            ) {
                throw new UMSException('UMS-001: Invalid UpdateType. Use C/R/A');
            }

            for (UserPayload payload : req.UserList) {
                response.Message.add(processUpsertUser(payload, updateType));
            }
            res.statusCode = FEC_ConstantCommon.HTTP_STATUS_OK;
        } catch (Exception e) {
            response.Message.add(buildMessage(STATUS_FAIL, e.getMessage(), null));
            res.statusCode = FEC_ConstantCommon.HTTP_STATUS_BAD_REQUEST;
        }

        res.responseBody = Blob.valueOf(JSON.serialize(response));
    }

    private static UserMessage processUpsertUser(UserPayload payload, String updateType) {
        if (payload == null) {
            return buildMessage(STATUS_FAIL, 'UMS-001: User payload is null', null);
        }
        if (String.isBlank(payload.UserID)) {
            return buildMessage(STATUS_FAIL, 'UMS-001: Missing required field: UserID', null);
        }
        if (String.isBlank(payload.UserName)) {
            return buildMessage(STATUS_FAIL, 'UMS-001: Missing required field: UserName', payload.UserID);
        }
        if (String.isBlank(payload.FEEmail)) {
            return buildMessage(STATUS_FAIL, 'UMS-001: Missing required field: FEEmail', payload.UserID);
        }
        if (String.isBlank(payload.Role)) {
            return buildMessage(STATUS_FAIL, 'UMS-001: Missing required field: Role', payload.UserID);
        }
        if (payload.ListUserRole == null || payload.ListUserRole.isEmpty()) {
            return buildMessage(STATUS_FAIL, 'UMS-001: Missing required field: ListUserRole', payload.UserID);
        }

        Id userRoleId = resolveUserRoleId(payload.Role.trim());
        if (userRoleId == null) {
            return buildMessage(
                STATUS_FAIL,
                'UMS-007: Role not found: ' + payload.Role.trim(),
                payload.UserID
            );
        }

        PermissionSetGroupResolveResult psgResult = resolvePermissionSetGroups(payload.ListUserRole);
        if (!psgResult.missingKeys.isEmpty()) {
            return buildMessage(
                STATUS_FAIL,
                'UMS-005: Permission Set Group not found: ' + String.join(psgResult.missingKeys, ','),
                payload.UserID
            );
        }

        List<User> existing = [
            SELECT Id, Username
            FROM User
            WHERE Username = :payload.UserID
            LIMIT 1
        ];
        Boolean isCreate = existing.isEmpty();

        if (updateType == UPDATE_TYPE_CREATE && !isCreate) {
            return buildMessage(STATUS_FAIL, 'UMS-004: Username already exists', payload.UserID);
        }
        if ((updateType == UPDATE_TYPE_REPLACE || updateType == UPDATE_TYPE_APPEND) && isCreate) {
            return buildMessage(STATUS_FAIL, 'UMS-003: User does not exist', payload.UserID);
        }

        User target;
        if (isCreate) {
            target = buildCreateUser(payload, userRoleId);
            insert target;
        } else {
            target = buildUpdateUser(existing[0].Id, payload, userRoleId);
            update target;
            target = [SELECT Id FROM User WHERE Id = :target.Id LIMIT 1];
        }

        syncPermissionSetGroupAssignments(target.Id, psgResult.groupIds, updateType);
        return buildMessage(STATUS_SUCCESS, isCreate ? 'Create success' : 'Update success', payload.UserID);
    }

    private static User buildCreateUser(UserPayload payload, Id userRoleId) {
        Profile p = [SELECT Id FROM Profile WHERE Id = :System.UserInfo.getProfileId() LIMIT 1];
        User current = [
            SELECT TimeZoneSidKey, LocaleSidKey, LanguageLocaleKey, EmailEncodingKey
            FROM User WHERE Id = :System.UserInfo.getUserId() LIMIT 1
        ];

        User u = new User();
        u.Username = payload.UserID;
        u.Email = payload.FEEmail;
        u.ProfileId = p.Id;
        u.Alias = buildAlias(payload.UserID);
        u.LastName = resolveLastName(payload);
        u.FirstName = payload.FirstName;
        applyRoleAndTitleFields(u, payload, userRoleId);
        u.ManagerId = resolveManagerId(payload.ReportTo);
        u.FEC_User_Group__c = payload.OrgUnit;
        u.FEC_User_Division_Group__c = payload.OrgDivision;
        u.FEC_Main_Queue__c = payload.MainQueue;
        u.FEC_Default_Queue__c = payload.DefaultQueue;
        u.TimeZoneSidKey = current.TimeZoneSidKey;
        u.LocaleSidKey = current.LocaleSidKey;
        u.LanguageLocaleKey = current.LanguageLocaleKey;
        u.EmailEncodingKey = current.EmailEncodingKey;
        return u;
    }

    private static User buildUpdateUser(Id userId, UserPayload payload, Id userRoleId) {
        User u = new User(Id = userId);
        u.Email = payload.FEEmail;
        u.FirstName = payload.FirstName;
        u.LastName = resolveLastName(payload);
        applyRoleAndTitleFields(u, payload, userRoleId);
        u.ManagerId = resolveManagerId(payload.ReportTo);
        u.FEC_User_Group__c = payload.OrgUnit;
        u.FEC_User_Division_Group__c = payload.OrgDivision;
        u.FEC_Main_Queue__c = payload.MainQueue;
        u.FEC_Default_Queue__c = payload.DefaultQueue;
        return u;
    }

    private static void handleStatus() {
        String transId = FEC_CommonUltils.generateTransactionUUID();
        RestResponse res = RestContext.response;
        UMSMutationResponse response = new UMSMutationResponse();
        response.TransID = transId;
        response.Message = new List<UserMessage>();

        try {
            UserStatusRequest req = (UserStatusRequest) JSON.deserialize(
                RestContext.request.requestBody == null ? null : RestContext.request.requestBody.toString(),
                UserStatusRequest.class
            );
            response.RequestorID = req != null ? req.RequestorID : null;

            if (req == null) throw new UMSException('UMS-001: Missing request body');
            if (String.isBlank(req.RequestorID)) throw new UMSException('UMS-001: Missing required field: RequestorID');
            if (req.UserList == null || req.UserList.isEmpty()) throw new UMSException('UMS-001: Missing required field: UserList');

            String actionType = String.isBlank(req.ActionType) ? null : req.ActionType.trim().toUpperCase();
            if (actionType != ACTION_DEACTIVATE && actionType != ACTION_REACTIVATE) {
                throw new UMSException('UMS-002: ActionType must be D or R');
            }

            List<String> usernames = new List<String>();
            for (UserStatusPayload item : req.UserList) {
                if (item != null && String.isNotBlank(item.UserID)) {
                    usernames.add(item.UserID);
                }
            }
            Map<String, User> byUsername = new Map<String, User>();
            for (User u : [
                SELECT Id, Username, IsActive
                FROM User
                WHERE Username IN :usernames
            ]) {
                byUsername.put(u.Username, u);
            }

            List<User> toUpdate = new List<User>();
            for (UserStatusPayload item : req.UserList) {
                if (item == null || String.isBlank(item.UserID)) {
                    response.Message.add(buildMessage(STATUS_FAIL, 'UMS-001: Missing required field: UserID', null));
                    continue;
                }
                if (!byUsername.containsKey(item.UserID)) {
                    response.Message.add(buildMessage(STATUS_FAIL, 'UMS-003: User does not exist', item.UserID));
                    continue;
                }
                User target = byUsername.get(item.UserID);
                target.IsActive = (actionType == ACTION_REACTIVATE);
                toUpdate.add(target);
                response.Message.add(
                    buildMessage(
                        STATUS_SUCCESS,
                        actionType == ACTION_DEACTIVATE ? 'User inactivated' : 'User activated',
                        item.UserID
                    )
                );
            }
            if (!toUpdate.isEmpty()) {
                update toUpdate;
            }
            res.statusCode = FEC_ConstantCommon.HTTP_STATUS_OK;
        } catch (Exception e) {
            response.Message.add(buildMessage(STATUS_FAIL, e.getMessage(), null));
            res.statusCode = FEC_ConstantCommon.HTTP_STATUS_BAD_REQUEST;
        }

        res.responseBody = Blob.valueOf(JSON.serialize(response));
    }

    private static void handleGetInfo() {
        RestResponse res = RestContext.response;
        String transId = FEC_CommonUltils.generateTransactionUUID();
        UMSGetInfoResponse response = new UMSGetInfoResponse();
        response.TransID = transId;
        response.RequestorID = RestContext.request.params != null
            ? RestContext.request.params.get('RequestorID')
            : null;

        try {
            String userId = RestContext.request.params == null
                ? null
                : RestContext.request.params.get('UserID');
            if (String.isBlank(response.RequestorID)) throw new UMSException('UMS-001: Missing required field: RequestorID');
            if (String.isBlank(userId)) throw new UMSException('UMS-001: Missing required field: UserID');

            List<User> users = [
                SELECT
                    Id, Name, Username, Email, IsActive, LastLoginDate, LastPasswordChangeDate,
                    CreatedDate, LastModifiedDate, CreatedBy.Name, LastModifiedBy.Name,
                    FEC_User_Group__c, FEC_User_Division_Group__c, FEC_Main_Queue__c, FEC_Default_Queue__c
                FROM User
                WHERE Username = :userId
                LIMIT 1
            ];
            if (users.isEmpty()) throw new UMSException('UMS-003: User does not exist');
            response.Infor = toUserInfo(users[0]);
            response.Status = STATUS_SUCCESS;
            response.Description = 'Get user info successfully.';
            res.statusCode = FEC_ConstantCommon.HTTP_STATUS_OK;
        } catch (Exception e) {
            response.Status = STATUS_FAIL;
            response.Description = e.getMessage();
            res.statusCode = FEC_ConstantCommon.HTTP_STATUS_BAD_REQUEST;
        }

        res.responseBody = Blob.valueOf(JSON.serialize(response));
    }

    private static void handleGetAll() {
        RestResponse res = RestContext.response;
        String transId = FEC_CommonUltils.generateTransactionUUID();
        UMSGetAllResponse response = new UMSGetAllResponse();
        response.TransID = transId;
        response.RequestorID = RestContext.request.params != null
            ? RestContext.request.params.get('RequestorID')
            : null;
        response.Data = new List<UserInfo>();

        try {
            if (String.isBlank(response.RequestorID)) throw new UMSException('UMS-001: Missing required field: RequestorID');
            String fromRaw = RestContext.request.params == null ? null : RestContext.request.params.get('FromDate');
            String toRaw = RestContext.request.params == null ? null : RestContext.request.params.get('ToDate');
            Datetime fromDt = parseDateTimeInput(fromRaw);
            Datetime toDt = parseDateTimeInput(toRaw);
            if (fromDt == null || toDt == null) throw new UMSException('UMS-006: Invalid date format');
            if (fromDt >= toDt) throw new UMSException('UMS-006: FromDate must be less than ToDate');

            for (User u : [
                SELECT
                    Id, Name, Username, Email, IsActive, LastLoginDate, LastPasswordChangeDate,
                    CreatedDate, LastModifiedDate, CreatedBy.Name, LastModifiedBy.Name,
                    FEC_User_Group__c, FEC_User_Division_Group__c, FEC_Main_Queue__c, FEC_Default_Queue__c
                FROM User
                WHERE LastModifiedDate >= :fromDt AND LastModifiedDate <= :toDt
                ORDER BY LastModifiedDate DESC
                LIMIT 2000
            ]) {
                response.Data.add(toUserInfo(u));
            }
            response.Status = STATUS_SUCCESS;
            response.Description = 'Get user info by update date successfully.';
            res.statusCode = FEC_ConstantCommon.HTTP_STATUS_OK;
        } catch (Exception e) {
            response.Status = STATUS_FAIL;
            response.Description = e.getMessage();
            res.statusCode = FEC_ConstantCommon.HTTP_STATUS_BAD_REQUEST;
        }

        res.responseBody = Blob.valueOf(JSON.serialize(response));
    }

    private class PermissionSetGroupResolveResult {
        Set<Id> groupIds = new Set<Id>();
        List<String> missingKeys = new List<String>();
    }

    private static PermissionSetGroupResolveResult resolvePermissionSetGroups(List<String> inputKeys) {
        PermissionSetGroupResolveResult result = new PermissionSetGroupResolveResult();
        if (inputKeys == null) return result;

        Set<Id> idKeys = new Set<Id>();
        Set<String> devNameKeys = new Set<String>();
        Set<String> labelKeys = new Set<String>();
        for (String raw : inputKeys) {
            if (String.isBlank(raw)) continue;
            String key = raw.trim();
            try {
                Id keyId = (Id) key;
                if (String.valueOf(keyId).startsWith('0PG')) {
                    idKeys.add(keyId);
                    continue;
                }
            } catch (Exception e) {
                // ignore parse failure
            }
            devNameKeys.add(key);
            labelKeys.add(key);
        }

        Map<String, Id> foundByKey = new Map<String, Id>();
        for (PermissionSetGroup psg : [
            SELECT Id, DeveloperName, MasterLabel
            FROM PermissionSetGroup
            WHERE Id IN :idKeys
            OR DeveloperName IN :devNameKeys
            OR MasterLabel IN :labelKeys
        ]) {
            result.groupIds.add(psg.Id);
            foundByKey.put(String.valueOf(psg.Id), psg.Id);
            if (String.isNotBlank(psg.DeveloperName)) foundByKey.put(psg.DeveloperName, psg.Id);
            if (String.isNotBlank(psg.MasterLabel)) foundByKey.put(psg.MasterLabel, psg.Id);
        }

        for (String raw : inputKeys) {
            if (String.isBlank(raw)) continue;
            String key = raw.trim();
            if (!foundByKey.containsKey(key)) {
                result.missingKeys.add(key);
            }
        }
        return result;
    }

    private static void syncPermissionSetGroupAssignments(
        Id userId,
        Set<Id> groupIds,
        String updateType
    ) {
        if (userId == null) return;
        if (groupIds == null) groupIds = new Set<Id>();

        Map<Id, PermissionSetAssignment> existingByGroup = new Map<Id, PermissionSetAssignment>();
        for (PermissionSetAssignment psa : [
            SELECT Id, PermissionSetGroupId
            FROM PermissionSetAssignment
            WHERE AssigneeId = :userId
            AND PermissionSetGroupId != NULL
        ]) {
            existingByGroup.put(psa.PermissionSetGroupId, psa);
        }

        if (updateType == UPDATE_TYPE_REPLACE) {
            List<PermissionSetAssignment> toDelete = new List<PermissionSetAssignment>();
            for (Id groupId : existingByGroup.keySet()) {
                if (!groupIds.contains(groupId)) {
                    toDelete.add(existingByGroup.get(groupId));
                }
            }
            if (!toDelete.isEmpty()) delete toDelete;
        }

        List<PermissionSetAssignment> toInsert = new List<PermissionSetAssignment>();
        for (Id groupId : groupIds) {
            if (!existingByGroup.containsKey(groupId)) {
                toInsert.add(new PermissionSetAssignment(
                    AssigneeId = userId,
                    PermissionSetGroupId = groupId
                ));
            }
        }
        if (!toInsert.isEmpty()) insert toInsert;
    }

    private static void applyRoleAndTitleFields(User u, UserPayload payload, Id userRoleId) {
        if (u == null || payload == null) return;
        if (String.isNotBlank(payload.Role)) {
            u.UserRoleId = userRoleId;
            u.Title = deriveTitleFromRole(payload.Role);
        } else if (String.isNotBlank(payload.Position)) {
            u.Title = payload.Position;
        }
    }

    @TestVisible
    private static Id resolveUserRoleId(String roleName) {
        if (String.isBlank(roleName)) return null;
        List<UserRole> roles = [
            SELECT Id
            FROM UserRole
            WHERE Name = :roleName.trim()
            LIMIT 1
        ];
        return roles.isEmpty() ? null : roles[0].Id;
    }

    /** Job Title = Role bỏ số ở cuối, e.g. "... Team Leader 1" → "... Team Leader". */
    @TestVisible
    private static String deriveTitleFromRole(String role) {
        if (String.isBlank(role)) return null;
        return role.trim().replaceAll('\\s+\\d+$', '');
    }

    private static UserInfo toUserInfo(User u) {
        UserInfo info = new UserInfo();
        info.UserID = u.Username;
        info.UserName = u.Name;
        info.FEEmail = u.Email;
        info.IsDeactivated = !u.IsActive;
        info.LastLoginDate = u.LastLoginDate;
        info.LastChangePasswordDate = u.LastPasswordChangeDate;
        info.CreatedBy = u.CreatedBy != null ? u.CreatedBy.Name : null;
        info.CreatedDate = u.CreatedDate;
        info.UpdateBy = u.LastModifiedBy != null ? u.LastModifiedBy.Name : null;
        info.UpdatedDate = u.LastModifiedDate;
        info.OrgUnit = u.FEC_User_Group__c;
        info.OrgDivision = u.FEC_User_Division_Group__c;
        info.MainQueue = u.FEC_Main_Queue__c;
        info.DefaultQueue = u.FEC_Default_Queue__c;
        info.RoleList = String.join(getPermissionRoleList(u.Id), ',');
        return info;
    }

    /**
     * RoleList = Permission Set Group (DeveloperName) + Permission Set (Name) gán trực tiếp cho user.
     * Không gồm permission set của Profile.
     */
    @TestVisible
    private static List<String> getPermissionRoleList(Id userId) {
        Set<String> roleNames = new Set<String>();
        if (userId == null) {
            return new List<String>();
        }

        for (PermissionSetAssignment psa : [
            SELECT
                PermissionSet.Name,
                PermissionSet.IsOwnedByProfile,
                PermissionSetGroup.DeveloperName,
                PermissionSetGroupId
            FROM PermissionSetAssignment
            WHERE AssigneeId = :userId
        ]) {
            if (
                psa.PermissionSetGroupId != null &&
                psa.PermissionSetGroup != null &&
                String.isNotBlank(psa.PermissionSetGroup.DeveloperName)
            ) {
                roleNames.add(psa.PermissionSetGroup.DeveloperName);
                continue;
            }
            if (
                psa.PermissionSet != null &&
                psa.PermissionSet.IsOwnedByProfile == false &&
                String.isNotBlank(psa.PermissionSet.Name)
            ) {
                roleNames.add(psa.PermissionSet.Name);
            }
        }

        List<String> sorted = new List<String>(roleNames);
        sorted.sort();
        return sorted;
    }

    private static String resolveLastName(UserPayload payload) {
        if (String.isNotBlank(payload.LastName)) return payload.LastName;
        if (String.isNotBlank(payload.UserName)) return payload.UserName.left(80);
        return 'User';
    }

    private static String buildAlias(String userId) {
        String raw = String.isBlank(userId) ? 'user' : userId.replaceAll('[^a-zA-Z0-9]', '');
        if (String.isBlank(raw)) raw = 'user';
        return raw.left(Math.min(8, raw.length()));
    }

    private static Id resolveManagerId(String reportTo) {
        if (String.isBlank(reportTo)) return null;
        List<User> managerByUsername = [
            SELECT Id FROM User WHERE Username = :reportTo LIMIT 1
        ];
        if (!managerByUsername.isEmpty()) return managerByUsername[0].Id;
        List<User> managerByEmail = [
            SELECT Id FROM User WHERE Email = :reportTo LIMIT 1
        ];
        return managerByEmail.isEmpty() ? null : managerByEmail[0].Id;
    }

    @TestVisible
    private static Datetime parseDateTimeInput(String raw) {
        if (String.isBlank(raw)) return null;
        String v = raw.trim();
        try {
            return (Datetime) JSON.deserialize('"' + v + '"', Datetime.class);
        } catch (Exception e) {
            // fallback MM-dd-yyyy
        }
        try {
            List<String> parts = v.split('-');
            if (parts.size() == 3) {
                Integer month = Integer.valueOf(parts[0]);
                Integer day = Integer.valueOf(parts[1]);
                Integer year = Integer.valueOf(parts[2]);
                Date d = Date.newInstance(year, month, day);
                return Datetime.newInstanceGmt(d, Time.newInstance(0, 0, 0, 0));
            }
        } catch (Exception e) {
            return null;
        }
        return null;
    }

    private static UserMessage buildMessage(String status, String description, String userId) {
        UserMessage m = new UserMessage();
        m.Status = status;
        m.Description = description;
        m.UserID = userId;
        return m;
    }

    public class UMSException extends Exception {}
}
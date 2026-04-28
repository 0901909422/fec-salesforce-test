/****************************************************************************************
 * File Name    : FEC_Chathub.Apex
 * Author       : Quangdv7
 * Date         : 2026-03-20
 * Description  : Call data object Case
 * Modification Log
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0      2026-03-20     Quangdv7             Create
 
****************************************************************************************/

public without sharing class FEC_Chathub {

    // ─── DTOs ─────────────────────────────────────────────────────────────

    public class CreateCaseRequestEvent {
        public CustomerInfo customerInfo;
        public ChatSession  chatSession;
    }

    public class CustomerInfo {
        public String customerID;
        public String customerName;
        public String decryptNationalID;
        public String kYCStatus;
        public String nationalID;
        public String phoneNumber;
    }

    public class ChatSession {
        public String  agentID;
        public String  chatChannel;
        public String  chatID;
        public String  createdAt;
        public String  customerID;
        public String  customerName;
        public Boolean hasNewMessage;
        public String  lastMessage;
        public String  sessionID;
        public String  sessionStatus;
        public String  updatedAt;
        public String  topic;
        public String  note;
    }

    public class EndChatEvent {
        public String  chatID;
        public String  chatChannel;
        public String  senderName;
        public String  senderID;
        public String  sessionID;
        public String  message;
        public String  createdAt;
        public String  id;
        public Boolean isAgent;
        public String  messageID;
        public String  messageType;
        public String  agentName;
        public String  pega_id;
    }

    public class FEC_ChathubCaseResponse {
        public Id     caseId;
        public String linkId;
        public String caseNo;
        public String customerID;
        public String customerName;
        public String phoneNumber;
        public String nationalID;
        public String cardAccountNum;
        public String chatChannel;
        public String agentID;
    }

    // ─── createCaseRequestEvent ───────────────────────────────────────────

    public static FEC_ChathubCaseResponse createInteractionCase(CreateCaseRequestEvent dto) {

        if (dto == null) {
            throw new IllegalArgumentException(System.Label.FEC_MSG_Interaction_Case_DTO_Null);
        }

        if (dto.customerInfo == null || dto.chatSession == null) {
            throw new IllegalArgumentException(System.Label.FEC_CustomerInfo_Null_Or_ChatSession_Null);
        }

        CustomerInfo ci = dto.customerInfo;
        ChatSession  cs = dto.chatSession;

        Id interactionRecordTypeId = Schema.SObjectType.Case
            .getRecordTypeInfosByDeveloperName()
            .get(FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME)
            .getRecordTypeId();

        Case interactionCase = new Case();
        interactionCase.RecordTypeId = interactionRecordTypeId;

        // ---------------------------
        // CHANNEL / STATUS
        // ---------------------------
        interactionCase.FEC_Channel__c = FEC_ConstantCommon.CHANNEL_CHAT;
        interactionCase.Status         = FEC_ConstantCommon.CASE_STATUS_PENDING;

        if (String.isNotBlank(cs.chatChannel)) {
            interactionCase.FEC_Interaction_Subchannel__c = cs.chatChannel;
        }

        interactionCase.FEC_External_Interaction_ID__c = cs.chatID;

        // ---------------------------
        // CUSTOMER INFO
        // ---------------------------
        interactionCase.FEC_CIF_Number__c             = ci.customerID;
        interactionCase.FEC_Customer_Username__c       = ci.customerName;
        interactionCase.FEC_Phone_Number__c            = ci.phoneNumber;
        interactionCase.FEC_National_ID_Passport_ID__c = ci.nationalID;

        insert interactionCase;

        interactionCase = [
            SELECT Id,
                   FEC_Link_ID__c,
                   OwnerId,
                   FEC_CIF_Number__c,
                   FEC_Customer_Username__c,
                   FEC_Phone_Number__c,
                   FEC_National_ID_Passport_ID__c,
                   FEC_Account_Number__c,
                   FEC_Interaction_Subchannel__c
            FROM   Case
            WHERE  Id = :interactionCase.Id
        ];

        // ---------------------------
        // ASSIGN AGENT ID vào Owner User
        // ---------------------------
        String resolvedAgentID = null;
        if (String.isNotBlank(cs.agentID)) {
            User ownerUser = [
                SELECT Id, FEC_Agent_ID__c
                FROM   User
                WHERE  Id = :interactionCase.OwnerId
            ];
            ownerUser.FEC_Agent_ID__c = cs.agentID;
            update ownerUser;
            resolvedAgentID = cs.agentID;
        }

        // ---------------------------
        // RESPONSE
        // ---------------------------
        FEC_ChathubCaseResponse res = new FEC_ChathubCaseResponse();
        res.caseId         = interactionCase.Id;
        res.linkId         = interactionCase.FEC_Link_ID__c;
        res.customerID     = interactionCase.FEC_CIF_Number__c;
        res.customerName   = interactionCase.FEC_Customer_Username__c;
        res.phoneNumber    = interactionCase.FEC_Phone_Number__c;
        res.nationalID     = interactionCase.FEC_National_ID_Passport_ID__c;
        res.cardAccountNum = interactionCase.FEC_Account_Number__c;
        res.chatChannel    = interactionCase.FEC_Interaction_Subchannel__c;
        res.agentID        = resolvedAgentID;

        if (res.linkId != null && res.linkId.contains('>')) {
            res.caseNo = res.linkId.substringBetween('>', '</');
        }

        return res;
    }

    // ─── endChatEvent ─────────────────────────────────────────────────────

    public static FEC_ChathubCaseResponse endChatEvent(EndChatEvent dto) {

        if (dto == null) {
            throw new IllegalArgumentException(System.Label.FEC_MSG_Interaction_Case_DTO_Null);
        }

        if (String.isBlank(dto.sessionID)) {
            System.debug('FEC_Chathub.endChatEvent: sessionID rỗng, bỏ qua');
            return null;
        }

        List<Case> cases = [
            SELECT Id,
                   Status,
                   FEC_Link_ID__c,
                   OwnerId,
                   FEC_CIF_Number__c,
                   FEC_Customer_Username__c,
                   FEC_Phone_Number__c,
                   FEC_National_ID_Passport_ID__c,
                   FEC_Account_Number__c,
                   FEC_Interaction_Subchannel__c
            FROM   Case
            WHERE  FEC_External_Interaction_ID__c = :dto.chatID
            AND    RecordType.DeveloperName        = :FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME
            LIMIT  1
        ];

        if (cases.isEmpty()) {
            return null;
        }

        Case c   = cases[0];
        c.Status = FEC_ConstantCommon.CASE_STATUS_CLOSED;
        update c;

        // ---------------------------
        // AGENT ID từ Owner User
        // ---------------------------
        String resolvedAgentID = null;
        if (c.OwnerId != null) {
            List<User> owners = [
                SELECT FEC_Agent_ID__c
                FROM   User
                WHERE  Id = :c.OwnerId
                LIMIT  1
            ];
            if (!owners.isEmpty()) {
                resolvedAgentID = owners[0].FEC_Agent_ID__c;
            }
        }

        // ---------------------------
        // RESPONSE
        // ---------------------------
        FEC_ChathubCaseResponse res = new FEC_ChathubCaseResponse();
        res.caseId         = c.Id;
        res.linkId         = c.FEC_Link_ID__c;
        res.customerID     = c.FEC_CIF_Number__c;
        res.customerName   = c.FEC_Customer_Username__c;
        res.phoneNumber    = c.FEC_Phone_Number__c;
        res.nationalID     = c.FEC_National_ID_Passport_ID__c;
        res.cardAccountNum = c.FEC_Account_Number__c;
        res.chatChannel    = c.FEC_Interaction_Subchannel__c;
        res.agentID        = resolvedAgentID;

        if (res.linkId != null && res.linkId.contains('>')) {
            res.caseNo = res.linkId.substringBetween('>', '</');
        }

        return res;
    }
}
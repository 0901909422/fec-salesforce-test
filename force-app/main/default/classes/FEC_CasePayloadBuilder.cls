public class FEC_CasePayloadBuilder {

    /**
     * Build JSON array cho toàn bộ batch.
     *
     * @param cases             List Case records trong batch
     * @param remarksByCaseId   Map<CaseId, List<Remarks>> từ queryRemarksByCaseIds
     * @return String JSON array: [ {case1}, {case2}, ... ]
     */
    public static String buildBatch(
        List<Case> cases,
        Map<Id, List<FEC_Case_Remarks__c>> remarksByCaseId,
        Map<Id, List<FEC_ChatHistory__c>> chatHistoriesByCaseId,
        Map<Id, User> usersById
    ) {
        List<Map<String, Object>> batchList = new List<Map<String, Object>>();
        for (Case c : cases) {
            List<FEC_Case_Remarks__c> remarks = remarksByCaseId.containsKey(c.Id)
                ? remarksByCaseId.get(c.Id)
                : new List<FEC_Case_Remarks__c>();
            List<FEC_ChatHistory__c> chats = chatHistoriesByCaseId.containsKey(c.Id)
                ? chatHistoriesByCaseId.get(c.Id)
                : new List<FEC_ChatHistory__c>();
            batchList.add(buildOne(c, remarks, chats, usersById));
        }
        return JSON.serialize(batchList);
    }

    @TestVisible
    public static Map<String, Object> buildOne(
        Case c,
        List<FEC_Case_Remarks__c> remarks,
        List<FEC_ChatHistory__c> chats,
        Map<Id, User> usersById
    ) {
        Map<String, Object> p = new Map<String, Object>();

        // ── Core ──────────────────────────────────────────────────────────────
        p.put('Id',           c.Id);
        p.put('CaseNumber',   c.CaseNumber);
        p.put('Status',       c.Status);
        p.put('ParentId',     c.ParentId);
        p.put('CreatedDate',      formatDt(c.CreatedDate));
        p.put('LastModifiedDate', formatDt(c.LastModifiedDate));
        p.put('ClosedDate',       formatDt(c.ClosedDate));

        // ── Users — lookup từ usersById vì CreatedBy/Owner là polymorphic Name ──
        p.put('CreatedById',      c.CreatedById);
        p.put('CreatedBy',        userMap(usersById.get(c.CreatedById)));
        p.put('LastModifiedById', c.LastModifiedById);
        p.put('LastModifiedBy',   userMap(usersById.get(c.LastModifiedById)));
        p.put('OwnerId',          c.OwnerId);
        p.put('Owner',            userMap(usersById.get(c.OwnerId)));

        // ── Interaction ───────────────────────────────────────────────────────
        p.put('FEC_External_Interaction_ID__c',   c.FEC_External_Interaction_ID__c);
        p.put('FEC_Channel__c',                   c.FEC_Channel__c);
        p.put('FEC_Case_Channel__c',              c.FEC_Case_Channel__c);
        p.put('FEC_Created_By__c',                c.FEC_Created_By__c);
        p.put('FEC_Created_On__c',                formatDt(c.FEC_Created_On__c));
        p.put('FEC_Interaction_Start_On__c',      formatDt(c.FEC_Interaction_Start_On__c));
        p.put('FEC_Interaction_End_On__c',        formatDt(c.FEC_Interaction_End_On__c));
        p.put('FEC_Interaction_Duration__c',      c.FEC_Interaction_Duration__c);
        p.put('FEC_Interaction__c',               c.FEC_Interaction__c);
        p.put('FEC_Interaction_Remarks__c',       c.FEC_Interaction_Remarks__c);
        p.put('FEC_Interaction_Status__c',        c.FEC_Interaction_Status__c);
        p.put('FEC_Interaction_ID__c',            c.FEC_Interaction_ID__c);
        p.put('FEC_Interaction_Owner__c',         c.FEC_Interaction_Owner__c);
        p.put('FEC_Interaction_Masked_Phone__c',  c.FEC_Interaction_Masked_Phone__c);
        p.put('FEC_Genesys_Campaign_Name__c',     c.FEC_Genesys_Campaign_Name__c);
        p.put('FEC_Genesys_Campaign__c',          c.FEC_Genesys_Campaign__c);
        p.put('FEC_Routing_Action__c',            c.FEC_Routing_Action__c);

        p.put('FEC_Interaction_Resolved_By__c',   c.FEC_Interaction_Resolved_By__c);
        p.put('FEC_Interaction_Resolved_By__r',   userMap(c.FEC_Interaction_Resolved_By__r));

        // ── Customer / Contact ────────────────────────────────────────────────
        p.put('FEC_Phone_Number__c',              c.FEC_Phone_Number__c);
        p.put('FEC_Case_Phone_Number__c',         c.FEC_Case_Phone_Number__c);
        p.put('FEC_Transcription__c',             c.FEC_Transcription__c);
        p.put('FEC_KYC_Method__c',                c.FEC_KYC_Method__c);
        p.put('FEC_Interaction_Subchannel__c',    c.FEC_Interaction_Subchannel__c);
        p.put('FEC_Other_Subchannel__c',          c.FEC_Other_Subchannel__c);
        p.put('FEC_Customer_Name__c',             c.FEC_Customer_Name__c);
        p.put('FEC_Customer_Type__c',             c.FEC_Customer_Type__c);
        p.put('FEC_Customer_Username__c',         c.FEC_Customer_Username__c);
        p.put('FEC_Phone_Type__c',                c.FEC_Phone_Type__c);
        p.put('FEC_Updated_Info_Phone_Type__c',   c.FEC_Updated_Info_Phone_Type__c);
        p.put('FEC_Original_Info_Phone_Type__c',  c.FEC_Original_Info_Phone_Type__c);
        p.put('FEC_Original_Info_Phone_Number__c',c.FEC_Original_Info_Phone_Number__c);
        p.put('FEC_Updated_Info_Phone_Number__c', c.FEC_Updated_Info_Phone_Number__c);
        p.put('FEC_Interaction_Email__c',         c.FEC_Interaction_Email__c);
        p.put('FEC_Email_From__c',                c.FEC_Email_From__c);
        p.put('FEC_Email_CC__c',                  c.FEC_Email_CC__c);
        p.put('FEC_Case_Email__c',                c.FEC_Case_Email__c);
        p.put('FEC_User_Email_ID__c',             c.FEC_User_Email_ID__c);
        p.put('FEC_National_ID_Passport_ID__c',   c.FEC_National_ID_Passport_ID__c);
        p.put('FEC_CIF_Number__c',                c.FEC_CIF_Number__c);
        p.put('FEC_Account_Number__c',            c.FEC_Account_Number__c);
        p.put('FEC_Contract_Number__c',           c.FEC_Contract_Number__c);
        p.put('FEC_Correct_Contract_Number__c',   c.FEC_Correct_Contract_Number__c);
        p.put('FEC_Account_Contract_Number_Text__c', c.FEC_Account_Contract_Number_Text__c);

        // ── Account / Contract ────────────────────────────────────────────────
        p.put('FEC_Account_or_Contract__c',   c.FEC_Account_or_Contract__c);
        p.put('FEC_Account_or_Contract__r',   accountContractMap(c.FEC_Account_or_Contract__r));

        // ── Classification ────────────────────────────────────────────────────
        p.put('FEC_Product_Type__c',    c.FEC_Product_Type__c);
        p.put('FEC_Product_Type__r',    classMap(c.FEC_Product_Type__r));
        p.put('FEC_Category__c',        c.FEC_Category__c);
        p.put('FEC_Category__r',        classMap(c.FEC_Category__r));
        p.put('FEC_SubCategory__c',     c.FEC_SubCategory__c);
        p.put('FEC_SubCategory__r',     classMap(c.FEC_SubCategory__r));
        p.put('FEC_SubCode__c',         c.FEC_SubCode__c);
        p.put('FEC_SubCode__r',         classMap(c.FEC_SubCode__r));
        p.put('FEC_New_Category__c',    c.FEC_New_Category__c);
        p.put('FEC_New_Category__r',    classMap(c.FEC_New_Category__r));
        p.put('FEC_New_SubCategory__c', c.FEC_New_SubCategory__c);
        p.put('FEC_New_SubCategory__r', classMap(c.FEC_New_SubCategory__r));
        p.put('FEC_New_SubCode__c',     c.FEC_New_SubCode__c);
        p.put('FEC_New_SubCode__r',     classMap(c.FEC_New_SubCode__r));

        // ── Actual Nature of Case ─────────────────────────────────────────────
        p.put('FEC_Actual_Nature_of_Case__c', c.FEC_Actual_Nature_of_Case__c);
        p.put('FEC_Actual_Nature_of_Case__r', nocMap(c.FEC_Actual_Nature_of_Case__r));

        // ── Business Process ──────────────────────────────────────────────────
        p.put('FEC_Business_Process__c', c.FEC_Business_Process__c);
        p.put('FEC_Business_Process__r', bizProcessMap(c.FEC_Business_Process__r));

        // ── Case management ───────────────────────────────────────────────────
        p.put('FEC_Stage_Name__c',            c.FEC_Stage_Name__c);
        p.put('FEC_Complain_Type__c',         c.FEC_Complain_Type__c);
        p.put('FEC_Service_Case_Owner__c',    c.FEC_Service_Case_Owner__c);
        p.put('FEC_Final_Status__c',          c.FEC_Final_Status__c);
        p.put('FEC_Task__c',                  c.FEC_Task__c);
        p.put('FEC_Team__c',                  c.FEC_Team__c);
        p.put('FEC_Completed_User__c',        c.FEC_Completed_User__c);
        p.put('FEC_Follow_Up_User__c',        c.FEC_Follow_Up_User__c);
        p.put('FEC_Is_Submited__c',           c.FEC_Is_Submited__c);
        p.put('FEC_Is_Save_Closed__c',        c.FEC_Is_Save_Closed__c);
        p.put('FEC_FCR__c',                   c.FEC_FCR__c);
        p.put('FEC_Has_Account_or_Contract__c', c.FEC_Has_Account_or_Contract__c);
        p.put('EntitlementId',                c.EntitlementId);

        // ── SLA ───────────────────────────────────────────────────────────────
        p.put('FEC_SLA_Violating_Warning__c', c.FEC_SLA_Violating_Warning__c);
        p.put('FEC_SLA_Warning__c',           c.FEC_SLA_Warning__c);
        p.put('FEC_SLA_Notification_1__c',    formatDt(c.FEC_SLA_Notification_1__c));
        p.put('FEC_SLA_Notification_2__c',    formatDt(c.FEC_SLA_Notification_2__c));
        p.put('FEC_SLA_Notification_3__c',    formatDt(c.FEC_SLA_Notification_3__c));

        // ── Audit ─────────────────────────────────────────────────────────────
        p.put('FEC_Case_Created_On__c',   formatDt(c.FEC_Case_Created_On__c));
        p.put('FEC_Case_Created_By__c',   c.FEC_Case_Created_By__c);
        p.put('FEC_Last_Updated_On__c',   formatDt(c.FEC_Last_Updated_On__c));
        p.put('FEC_Last_Updated_By__c',   c.FEC_Last_Updated_By__c);
        p.put('FEC_Case_ID__c',           c.FEC_Case_ID__c);

        // ── D2C / Assessment ──────────────────────────────────────────────────
        p.put('FEC_CS_D2C_Assessment_Type__c', c.FEC_CS_D2C_Assessment_Type__c);
        p.put('FEC_CS_D2C_Risk_Level__c',      c.FEC_CS_D2C_Risk_Level__c);
        p.put('FEC_Outcome_Code__c',           c.FEC_Outcome_Code__c);
        p.put('FEC_Application_ID__c',         c.FEC_Application_ID__c);

        // ── RecordType ────────────────────────────────────────────────────────
        p.put('RecordTypeId', c.RecordTypeId);
        p.put('RecordType',   c.RecordType != null ? c.RecordType.Name : null);

        // ── Remarks (tất cả remarks của case này) ─────────────────────────────
        p.put('FEC_Case_Remarks_List__r', remarksList(remarks));

        // ── Chat Histories (tất cả tin nhắn của case này) ─────────────────────
        // p.put('Chat_Histories__r', chatHistoryList(chats));

        return p;
    }

    // ── User map (overload 1) — nhận User trực tiếp từ usersById lookup ────────
    private static Map<String, Object> userMap(User u) {
        if (u == null) return null;
        return new Map<String, Object>{
            'Id'                   => u.Id,
            'Name'                 => u.Name,
            'Username'             => u.Username,
            'Email'                => u.Email,
            'Phone'                => u.Phone,
            'FEC_Agent_ID__c'      => u.FEC_Agent_ID__c,
            'FEC_Default_Queue__c' => u.FEC_Default_Queue__c
        };
    }

    // ── User map (overload 2) — nhận SObject cho FEC_Interaction_Resolved_By__r ─
    // Relationship này là typed User (không phải polymorphic Name)
    // nên custom fields có thể truy cập qua .get()
    private static Map<String, Object> userMap(SObject u) {
        if (u == null) return null;
        return new Map<String, Object>{
            'Id'                   => (String) u.get('Id'),
            'Name'                 => (String) u.get('Name'),
            'Username'             => (String) u.get('Username'),
            'Email'                => (String) u.get('Email'),
            'Phone'                => (String) u.get('Phone'),
            'FEC_Agent_ID__c'      => (String) u.get('FEC_Agent_ID__c'),
            'FEC_Default_Queue__c' => (String) u.get('FEC_Default_Queue__c')
        };
    }

    // ── Account/Contract map ──────────────────────────────────────────────────
    private static Map<String, Object> accountContractMap(FEC_Customer_History__c ac) {
        if (ac == null) return null;
        return new Map<String, Object>{
            'Id'                             => ac.Id,
            'Name'                           => ac.Name,
            'FEC_Account_Number__c'          => ac.FEC_Account_Number__c,
            'FEC_Contract_Number__c'         => ac.FEC_Contract_Number__c,
            'FEC_Customer_Name__c'           => ac.FEC_Customer_Name__c,
            'FEC_CIF_Number__c'              => ac.FEC_CIF_Number__c,
            'FEC_Contract_Status__c'         => ac.FEC_Contract_Status__c,
            'FEC_Contract_Type__c'           => ac.FEC_Contract_Type__c,
            'FEC_Product_Code__c'            => ac.FEC_Product_Code__c,
            'FEC_Account_Status__c'          => ac.FEC_Account_Status__c,
            'FEC_Credit_Limit__c'            => ac.FEC_Credit_Limit__c,
            'FEC_Current_Balance__c'         => ac.FEC_Current_Balance__c,
            'FEC_OTB__c'                     => ac.FEC_OTB__c,
            'FEC_Total_Balance__c'           => ac.FEC_Total_Balance__c,
            'FEC_Date_of_Birth__c'           => String.valueOf(ac.FEC_Date_of_Birth__c),
            'FEC_National_ID_Passport_ID__c' => ac.FEC_National_ID_Passport_ID__c,
            'FEC_Primary_Phone__c'           => ac.FEC_Primary_Phone__c,
            'FEC_Email__c'                   => ac.FEC_Email__c,
            'FEC_Gender__c'                  => ac.FEC_Gender__c,
            'FEC_Card_Number__c'             => ac.FEC_Card_Number__c,
            'FEC_Card_Type__c'               => ac.FEC_Card_Type__c,
            'FEC_Expiry_Date__c'             => String.valueOf(ac.FEC_Expiry_Date__c)
        };
    }

    // ── Classification node (ProductType / Category / Sub...) ────────────────
    private static Map<String, Object> classMap(SObject obj) {
        if (obj == null) return null;
        return new Map<String, Object>{
            'Id'             => (String) obj.get('Id'),
            'Name'           => (String) obj.get('Name'),
            'FEC_Code__c'    => (String) obj.get('FEC_Code__c'),
            'FEC_Alias__c'   => (String) obj.get('FEC_Alias__c'),
            'FEC_Name_VN__c' => (String) obj.get('FEC_Name_VN__c'),
            'FEC_Order__c'   => obj.get('FEC_Order__c')
        };
    }

    // ── Business Process map ─────────────────────────────────────────────────
    private static Map<String, Object> bizProcessMap(FEC_Business_Process__c bp) {
        if (bp == null) return null;
        return new Map<String, Object>{
            'Id'             => bp.Id,
            'Name'           => bp.Name,
            'FEC_Code__c'    => bp.FEC_Code__c,
            'FEC_Alias__c'   => bp.FEC_Alias__c,
            'FEC_Name_VN__c' => bp.FEC_Name_VN__c,
            'FEC_Order__c'   => bp.FEC_Order__c
        };
    }

    // ── Actual Nature of Case map ─────────────────────────────────────────────
    private static Map<String, Object> nocMap(FEC_Actual_Nature_of_Case__c noc) {
        if (noc == null) return null;
        Map<String, Object> m = new Map<String, Object>{
            'Id'                      => noc.Id,
            'Name'                    => noc.Name,
            'FEC_Customer_Type__c'    => noc.FEC_Customer_Type__c,
            'FEC_User_Group__c'       => noc.FEC_User_Group__c,
            'FEC_Business_Process__c' => noc.FEC_Business_Process__c,
            'FEC_Business_Process__r' => bizProcessMap(noc.FEC_Business_Process__r)
        };
        return m;
    }

    // ── Remarks list ──────────────────────────────────────────────────────────
    private static List<Map<String, Object>> remarksList(List<FEC_Case_Remarks__c> remarks) {
        List<Map<String, Object>> results = new List<Map<String, Object>>();
        if (remarks == null) return results;
        for (FEC_Case_Remarks__c r : remarks) {
            results.add(new Map<String, Object>{
                'Id'                  => r.Id,
                'Name'                => r.Name,
                'FEC_Case__c'         => r.FEC_Case__c,
                'FEC_Case_Remarks__c' => r.FEC_Case_Remarks__c,
                'FEC_Stage_Name__c'   => r.FEC_Stage_Name__c,
                'FEC_User__c'         => r.FEC_User__c,
                'FEC_User_Role__c'    => r.FEC_User_Role__c
            });
        }
        return results;
    }

    // ── Chat History list ─────────────────────────────────────────────────────
    private static List<Map<String, Object>> chatHistoryList(List<FEC_ChatHistory__c> chats) {
        List<Map<String, Object>> results = new List<Map<String, Object>>();
        if (chats == null) return results;
        for (FEC_ChatHistory__c ch : chats) {
            results.add(new Map<String, Object>{
                'Id'                 => ch.Id,
                'Name'               => ch.Name,
                'FEC_Case__c'        => ch.FEC_Case__c,
                'FEC_ChatChannel__c' => ch.FEC_ChatChannel__c,
                'FEC_CreatedAt__c'   => formatDt(ch.FEC_CreatedAt__c),
                'FEC_IsAgent__c'     => ch.FEC_IsAgent__c,
                'FEC_Message__c'     => ch.FEC_Message__c,
                'FEC_MessageType__c' => ch.FEC_MessageType__c,
                'FEC_SenderName__c'  => ch.FEC_SenderName__c,
                'FEC_SessionID__c'   => ch.FEC_SessionID__c
            });
        }
        return results;
    }

    // ── Format helpers ────────────────────────────────────────────────────────
    private static String formatDt(Datetime dt) {
        return dt == null ? null : dt.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');
    }
}
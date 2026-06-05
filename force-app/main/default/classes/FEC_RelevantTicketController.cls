public with sharing class FEC_RelevantTicketController {

    // tungnm37 thêm: query Relevant Tickets theo cả 2 chiều (FEC_Related_To__c OR FEC_Interaction__c)
    @AuraEnabled(cacheable=false)
    public static List<FEC_Relevant_Ticket__c> getRelevantTickets(String caseId) {
        if (String.isBlank(caseId)) return new List<FEC_Relevant_Ticket__c>();
        return [
            SELECT Id, FEC_Relevant_Ticket_ID__c, FEC_Category_Relevant__c,
                   FEC_Sub_Category_Relevant__c, FEC_Sub_Code_Relevant__c,
                   FEC_User_Relevant__c, FEC_User_Role_Relevant__c,
                   FEC_Account_or_Contract_Revelant__c,
                   FEC_Related_To__r.FEC_ID_Search__c,
                   FEC_Interaction__r.FEC_ID_Search__c,
                   FEC_Status_Relevant__c, CreatedDate
            FROM FEC_Relevant_Ticket__c
            WHERE FEC_Related_To__c = :caseId OR FEC_Interaction__c = :caseId
            ORDER BY CreatedDate DESC
        ];
    }

    @AuraEnabled
    public static Id createRelevantTicket(String interactionId, String relatedToId) {
        System.debug('FEC_DEBUG createRelevantTicket interactionId=' + interactionId + ' relatedToId=' + relatedToId);
        String currentStageCode = null;
        if (String.isNotBlank(relatedToId)) {
            List<Case> cases = [SELECT FEC_Current_Case_Stage__r.FEC_Code__c FROM Case WHERE Id = :relatedToId LIMIT 1];
            if (!cases.isEmpty()) currentStageCode = cases[0].FEC_Current_Case_Stage__r?.FEC_Code__c;
        }
        System.debug('FEC_DEBUG createRelevantTicket currentStageCode=' + currentStageCode);
        FEC_Relevant_Ticket__c rt = new FEC_Relevant_Ticket__c();
        rt.FEC_Interaction__c  = relatedToId;
        rt.FEC_Related_To__c   = String.isNotBlank(interactionId) ? interactionId : null;
        rt.FEC_Stage_Name__c   = currentStageCode;
        insert rt;
        return rt.Id;
    }

    // tungnm37 sửa: chỉ cho xóa ticket được tạo tại stage hiện tại, chặn nếu từ stage trước
    @AuraEnabled
    public static void deleteRelevantTicket(String ticketId) {
        if (String.isBlank(ticketId)) return;
        List<FEC_Relevant_Ticket__c> tickets = [
            SELECT Id, FEC_Stage_Name__c, FEC_Interaction__c
            FROM FEC_Relevant_Ticket__c WHERE Id = :ticketId LIMIT 1
        ];
        if (tickets.isEmpty()) return;
        FEC_Relevant_Ticket__c ticket = tickets[0];
        if (String.isNotBlank(ticket.FEC_Interaction__c)) {
            List<Case> cases = [SELECT FEC_Current_Case_Stage__r.FEC_Code__c FROM Case WHERE Id = :ticket.FEC_Interaction__c LIMIT 1];
            if (!cases.isEmpty()) {
                String currentStageCode = cases[0].FEC_Current_Case_Stage__r?.FEC_Code__c;
                // Chỉ check stage khi Case có stage (có workflow)
                // Nếu Case không có stage → cho phép xóa tự do
                if (String.isNotBlank(currentStageCode)) {
                    // Case có stage: chặn nếu ticket null stage (ticket cũ) hoặc khác stage hiện tại
                    if (String.isBlank(ticket.FEC_Stage_Name__c) || ticket.FEC_Stage_Name__c != currentStageCode) {
                        throw new AuraHandledException(System.Label.FEC_RelevantTicket_Cannot_Delete);
                    }
                }
            }
        }
        delete ticket;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, String> getCaseById(String caseId) {
        if (String.isBlank(caseId)) return null;
        List<Case> cases = [SELECT Id, FEC_ID_Search__c, CaseNumber, Subject, Status FROM Case WHERE Id = :caseId LIMIT 1];
        if (cases.isEmpty()) return null;
        Case c = cases[0];
        return new Map<String, String>{
            'id'    => c.Id,
            'label' => (String.isNotBlank(c.FEC_ID_Search__c) ? c.FEC_ID_Search__c : c.CaseNumber),
            'sub'   => (String.isNotBlank(c.Subject) ? c.Subject : '') + ' | ' + (c.Status != null ? c.Status : '')
        };
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> searchCases(String searchTerm) {
        List<Map<String, String>> results = new List<Map<String, String>>();
        if (String.isBlank(searchTerm) || searchTerm.length() < 2) return results;
        String q = '%' + searchTerm + '%';
        for (Case c : [
            SELECT Id, FEC_ID_Search__c, CaseNumber, Subject, Status
            FROM Case
            WHERE (FEC_ID_Search__c LIKE :q OR CaseNumber LIKE :q)
            ORDER BY LastModifiedDate DESC
            LIMIT 10
        ]) {
            results.add(new Map<String, String>{
                'id'    => c.Id,
                'label' => (String.isNotBlank(c.FEC_ID_Search__c) ? c.FEC_ID_Search__c : c.CaseNumber),
                'sub'   => (String.isNotBlank(c.Subject) ? c.Subject : '') + ' | ' + (c.Status != null ? c.Status : '')
            });
        }
        return results;
    }
}

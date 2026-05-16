// Test logic xóa Relevant Ticket
// Tìm case có ít nhất 1 relevant ticket để test

// 1. Tìm ticket có stage_name != null để test
List<FEC_Relevant_Ticket__c> ticketsWithStage = [
    SELECT Id, FEC_Stage_Name__c, FEC_Interaction__c,
           FEC_Interaction__r.FEC_ID_Search__c,
           FEC_Interaction__r.FEC_Current_Case_Stage__r.FEC_Code__c,
           CreatedDate
    FROM FEC_Relevant_Ticket__c
    WHERE FEC_Stage_Name__c != null
    ORDER BY CreatedDate DESC
    LIMIT 5
];

System.debug('=== Tickets WITH stage_name (should block if different stage) ===');
for (FEC_Relevant_Ticket__c t : ticketsWithStage) {
    String caseStage = t.FEC_Interaction__r?.FEC_Current_Case_Stage__r?.FEC_Code__c;
    Boolean sameStage = t.FEC_Stage_Name__c == caseStage;
    System.debug('TicketId=' + t.Id
        + ' Case=' + t.FEC_Interaction__r?.FEC_ID_Search__c
        + ' TicketStage=[' + t.FEC_Stage_Name__c + ']'
        + ' CaseStage=[' + caseStage + ']'
        + ' SameStage=' + sameStage
        + ' => ' + (sameStage ? 'CAN DELETE' : 'BLOCKED'));
}

// 2. Tìm ticket null stage để test
List<FEC_Relevant_Ticket__c> ticketsNullStage = [
    SELECT Id, FEC_Stage_Name__c, FEC_Interaction__c,
           FEC_Interaction__r.FEC_ID_Search__c,
           FEC_Interaction__r.FEC_Current_Case_Stage__r.FEC_Code__c,
           CreatedDate
    FROM FEC_Relevant_Ticket__c
    WHERE FEC_Stage_Name__c = null
    ORDER BY CreatedDate DESC
    LIMIT 5
];

System.debug('=== Tickets WITHOUT stage_name (null = old tickets, should allow delete) ===');
for (FEC_Relevant_Ticket__c t : ticketsNullStage) {
    String caseStage = t.FEC_Interaction__r?.FEC_Current_Case_Stage__r?.FEC_Code__c;
    System.debug('TicketId=' + t.Id
        + ' Case=' + t.FEC_Interaction__r?.FEC_ID_Search__c
        + ' TicketStage=[null]'
        + ' CaseStage=[' + caseStage + ']'
        + ' => CAN DELETE (null stage = old ticket)');
}

// 3. Simulate deleteRelevantTicket logic với từng ticket
System.debug('=== Simulating deleteRelevantTicket logic ===');
List<FEC_Relevant_Ticket__c> allTickets = new List<FEC_Relevant_Ticket__c>();
allTickets.addAll(ticketsWithStage);
allTickets.addAll(ticketsNullStage);

for (FEC_Relevant_Ticket__c t : allTickets) {
    if (String.isBlank(t.FEC_Interaction__c)) continue;
    String currentStageCode = t.FEC_Interaction__r?.FEC_Current_Case_Stage__r?.FEC_Code__c;
    // Logic mới: chỉ chặn khi có stage VÀ khác stage hiện tại
    Boolean blocked = String.isNotBlank(t.FEC_Stage_Name__c) && t.FEC_Stage_Name__c != currentStageCode;
    System.debug('TicketId=' + t.Id
        + ' TicketStage=[' + t.FEC_Stage_Name__c + ']'
        + ' CaseStage=[' + currentStageCode + ']'
        + ' => ' + (blocked ? 'BLOCKED (different stage)' : 'ALLOWED'));
}

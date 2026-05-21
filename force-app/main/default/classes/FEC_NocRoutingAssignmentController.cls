/**
 * Controller cho NOC Routing Assignment Config tab
 * Hỗ trợ: list, tạo mới, cập nhật, lấy history, lấy options Team/Queue/Channel
 */
public without sharing class FEC_NocRoutingAssignmentController {

    // ─── Wrapper ────────────────────────────────────────────────────────────

    public class RoutingAssignmentWrapper {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String customerType;
        @AuraEnabled public String channel;
        @AuraEnabled public String team;
        @AuraEnabled public String queue;
        @AuraEnabled public Boolean active;
        @AuraEnabled public String nocId;
        @AuraEnabled public String nocName;
    }

    public class HistoryWrapper {
        @AuraEnabled public String historyDate;
        @AuraEnabled public String historyField;
        @AuraEnabled public String userId;
        @AuraEnabled public String userName;
        @AuraEnabled public String oldValue;
        @AuraEnabled public String newValue;
    }

    // ─── List ────────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<RoutingAssignmentWrapper> getRoutingAssignmentsByNoc(String nocId) {
        if (String.isBlank(nocId)) return new List<RoutingAssignmentWrapper>();
        List<FEC_Routing_Assignment__c> records = [
            SELECT Id, Name, FEC_Customer_Type__c, FEC_Channel__c,
                   FEC_Team__c, FEC_Queue__c, FEC_Active__c
            FROM FEC_Routing_Assignment__c
            WHERE FEC_Nature_of_Cases__c = :nocId
            ORDER BY Name ASC
        ];
        List<RoutingAssignmentWrapper> result = new List<RoutingAssignmentWrapper>();
        for (FEC_Routing_Assignment__c r : records) {
            RoutingAssignmentWrapper w = new RoutingAssignmentWrapper();
            w.id = r.Id;
            w.name = r.Name;
            w.customerType = r.FEC_Customer_Type__c;
            w.channel = r.FEC_Channel__c;
            w.team = r.FEC_Team__c;
            w.queue = r.FEC_Queue__c;
            w.active = r.FEC_Active__c;
            result.add(w);
        }
        return result;
    }

    // ─── Options ─────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getTeamOptions() {
        Set<String> seen = new Set<String>();
        List<Map<String, String>> result = new List<Map<String, String>>();
        for (FEC_Team_Queue__c r : [
            SELECT FEC_Select_Team__r.Name
            FROM FEC_Team_Queue__c
            WHERE FEC_Select_Team__c != null
            ORDER BY FEC_Select_Team__r.Name ASC
        ]) {
            String teamName = r.FEC_Select_Team__r?.Name;
            if (String.isNotBlank(teamName) && !seen.contains(teamName)) {
                seen.add(teamName);
                result.add(new Map<String, String>{ 'label' => teamName, 'value' => teamName });
            }
        }
        return result;
    }

    @AuraEnabled
    public static List<Map<String, String>> getQueuesByTeam(String teamName) {
        if (String.isBlank(teamName)) return new List<Map<String, String>>();
        Set<String> queueDevNames = new Set<String>();
        for (FEC_Team_Queue__c r : [
            SELECT FEC_Queue_Name__c
            FROM FEC_Team_Queue__c
            WHERE FEC_Select_Team__r.Name = :teamName
              AND FEC_Queue_Name__c != null
        ]) {
            queueDevNames.add(r.FEC_Queue_Name__c);
        }
        if (queueDevNames.isEmpty()) return new List<Map<String, String>>();
        Map<String, String> devToLabel = new Map<String, String>();
        for (Group g : [
            SELECT Name, DeveloperName FROM Group
            WHERE DeveloperName IN :queueDevNames AND Type = 'Queue'
        ]) {
            devToLabel.put(g.DeveloperName, g.Name);
        }
        List<Map<String, String>> result = new List<Map<String, String>>();
        for (String devName : queueDevNames) {
            String label = devToLabel.containsKey(devName) ? devToLabel.get(devName) : devName;
            result.add(new Map<String, String>{ 'label' => label, 'value' => label });
        }
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getChannelOptions() {
        List<Map<String, String>> result = new List<Map<String, String>>();
        for (FEC_Channel__c ch : [
            SELECT Id, FEC_Channel_Vietnamese_name__c, FEC_Channel_ID__c
            FROM FEC_Channel__c
            WHERE FEC_Channel_Status__c = true
            ORDER BY FEC_Channel_Vietnamese_name__c ASC
        ]) {
            result.add(new Map<String, String>{
                'label' => ch.FEC_Channel_Vietnamese_name__c,
                'value' => ch.FEC_Channel_ID__c,
                'id'    => ch.Id
            });
        }
        return result;
    }

    // ─── Create ──────────────────────────────────────────────────────────────

    @AuraEnabled
    public static String createRoutingAssignment(
        String nocId, String customerType, String channel,
        String team, String queue, Boolean active
    ) {
        if (String.isBlank(nocId)) throw new AuraHandledException('NOC ID is required');
        // Validate duplicate queue trong cùng NOC
        List<FEC_Routing_Assignment__c> existing = [
            SELECT Id FROM FEC_Routing_Assignment__c
            WHERE FEC_Nature_of_Cases__c = :nocId AND FEC_Queue__c = :queue
            LIMIT 1
        ];
        if (!existing.isEmpty()) {
            throw new AuraHandledException('Không thể tạo trùng Queue trong cùng 1 bộ NOC.');
        }
        FEC_Routing_Assignment__c ra = new FEC_Routing_Assignment__c(
            FEC_Nature_of_Cases__c = nocId,
            FEC_Customer_Type__c   = customerType,
            FEC_Channel__c         = channel,
            FEC_Team__c            = team,
            FEC_Queue__c           = queue,
            FEC_Active__c          = (active != null ? active : true)
        );
        try {
            insert ra;
        } catch (Exception e) {
            throw new AuraHandledException('Lỗi khi tạo: ' + e.getMessage());
        }
        return ra.Id;
    }

    // ─── Update ──────────────────────────────────────────────────────────────

    @AuraEnabled
    public static void updateRoutingAssignment(
        String recordId, String customerType, String channel,
        String team, String queue, Boolean active
    ) {
        if (String.isBlank(recordId)) throw new AuraHandledException('Record ID is required');
        // Validate duplicate queue (exclude self)
        List<FEC_Routing_Assignment__c> self = [
            SELECT FEC_Nature_of_Cases__c FROM FEC_Routing_Assignment__c WHERE Id = :recordId LIMIT 1
        ];
        if (self.isEmpty()) throw new AuraHandledException('Record not found');
        String nocId = String.valueOf(self[0].FEC_Nature_of_Cases__c);
        List<FEC_Routing_Assignment__c> existing = [
            SELECT Id FROM FEC_Routing_Assignment__c
            WHERE FEC_Nature_of_Cases__c = :nocId AND FEC_Queue__c = :queue AND Id != :recordId
            LIMIT 1
        ];
        if (!existing.isEmpty()) {
            throw new AuraHandledException('Không thể tạo trùng Queue trong cùng 1 bộ NOC.');
        }
        Database.update(new FEC_Routing_Assignment__c(
            Id                   = recordId,
            FEC_Customer_Type__c = customerType,
            FEC_Channel__c       = channel,
            FEC_Team__c          = team,
            FEC_Queue__c         = queue,
            FEC_Active__c        = (active != null ? active : true)
        ), AccessLevel.SYSTEM_MODE);
    }

    // ─── History ─────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<HistoryWrapper> getRoutingAssignmentHistory(String recordId) {
        if (String.isBlank(recordId)) return new List<HistoryWrapper>();
        List<HistoryWrapper> result = new List<HistoryWrapper>();
        for (FEC_Routing_Assignment__History h : [
            SELECT CreatedDate, Field, CreatedBy.Name, CreatedById, OldValue, NewValue
            FROM FEC_Routing_Assignment__History
            WHERE ParentId = :recordId
            ORDER BY CreatedDate DESC
            LIMIT 200
        ]) {
            HistoryWrapper w = new HistoryWrapper();
            w.historyDate  = h.CreatedDate.format('dd/MM/yyyy, HH:mm');
            w.historyField = h.Field;
            w.userId   = h.CreatedById;
            w.userName = h.CreatedBy?.Name;
            w.oldValue = h.OldValue != null ? String.valueOf(h.OldValue) : '';
            w.newValue = h.NewValue != null ? String.valueOf(h.NewValue) : '';
            result.add(w);
        }
        return result;
    }

    // ─── Single record ───────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static RoutingAssignmentWrapper getRoutingAssignment(String recordId) {
        if (String.isBlank(recordId)) return null;
        List<FEC_Routing_Assignment__c> records = [
            SELECT Id, Name, FEC_Customer_Type__c, FEC_Channel__c,
                   FEC_Team__c, FEC_Queue__c, FEC_Active__c,
                   FEC_Nature_of_Cases__c, FEC_Nature_of_Cases__r.Name
            FROM FEC_Routing_Assignment__c
            WHERE Id = :recordId LIMIT 1
        ];
        if (records.isEmpty()) return null;
        FEC_Routing_Assignment__c r = records[0];
        RoutingAssignmentWrapper w = new RoutingAssignmentWrapper();
        w.id = r.Id;
        w.name = r.Name;
        w.customerType = r.FEC_Customer_Type__c;
        w.channel = r.FEC_Channel__c;
        w.team = r.FEC_Team__c;
        w.queue = r.FEC_Queue__c;
        w.active = r.FEC_Active__c;
        w.nocId = r.FEC_Nature_of_Cases__c;
        w.nocName = r.FEC_Nature_of_Cases__r?.Name;
        return w;
    }

    @AuraEnabled(cacheable=true)
    public static String getRoutingAssignmentName(String recordId) {
        if (String.isBlank(recordId)) return 'Routing Assignment';
        List<FEC_Routing_Assignment__c> records = [SELECT Name FROM FEC_Routing_Assignment__c WHERE Id = :recordId LIMIT 1];
        return records.isEmpty() ? 'Routing Assignment' : records[0].Name;
    }
}

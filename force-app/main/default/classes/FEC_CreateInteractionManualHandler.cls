public without sharing class FEC_CreateInteractionManualHandler {
    
    public class CreateInteractionManualResponse {
        @AuraEnabled public Id caseId { get; set; }
        @AuraEnabled public String linkId { get; set; }
        @AuraEnabled public String caseNo { get; set; }
        
        public CreateInteractionManualResponse(Id caseId, String linkId, String caseNo) {
            this.caseId = caseId;
            this.linkId = linkId;
            this.caseNo = caseNo;
        }
    }
    
    @AuraEnabled
    public static CreateInteractionManualResponse createInteractionManual(String channel, String subChannel) {
        FEC_CreateCaseHandler.FEC_InteractionCaseDTO interactionCaseDTO = new FEC_CreateCaseHandler.FEC_InteractionCaseDTO();
        interactionCaseDTO.channel = channel;
        interactionCaseDTO.subChannel = subChannel;
        
        FEC_CreateCaseHandler.FEC_InteractionCaseResponse response = FEC_CreateCaseHandler.createInteractionCaseManual(interactionCaseDTO);
        
        return new CreateInteractionManualResponse(response.caseId, response.linkId, response.caseNo);
    }
    
    @AuraEnabled
    public static Boolean hasChannelPermission(String channel) {
        System.debug(channel);
        if (String.isBlank(channel)) {
            return false;
        }
        
        Set<Id> psgIds = new Set<Id>();
        
        List<PermissionSetAssignment> assignments = [
            SELECT PermissionSetGroupId
            FROM PermissionSetAssignment
            WHERE AssigneeId = :UserInfo.getUserId()
            AND PermissionSetGroupId != null
        ];
        
        for (PermissionSetAssignment psa : assignments) {
            psgIds.add(psa.PermissionSetGroupId);
        }
        
        if (psgIds.isEmpty()) {
            return false;
        }
        
        List<PermissionSetGroupComponent> components = [
            SELECT PermissionSet.Name
            FROM PermissionSetGroupComponent
            WHERE PermissionSetGroupId IN :psgIds
        ];
        
        String channelLower = channel.toLowerCase();
        
        for (PermissionSetGroupComponent component : components) {
            System.debug(component.PermissionSet.Name);
            if (component.PermissionSet != null
                && component.PermissionSet.Name != null
            && component.PermissionSet.Name.toLowerCase().contains(channelLower)) {
                
                return true;
            }
        }
        
        return false;
    }
}
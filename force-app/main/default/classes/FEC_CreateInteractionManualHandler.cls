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
        FEC_CreateCaseHanlder.FEC_InteractionCaseDTO interactionCaseDTO = new FEC_CreateCaseHanlder.FEC_InteractionCaseDTO();
        interactionCaseDTO.channel = channel;
        interactionCaseDTO.subChannel = subChannel;
        
        FEC_CreateCaseHanlder.FEC_InteractionCaseResponse response = FEC_CreateCaseHanlder.createInteractionCaseManual(interactionCaseDTO);
        
        return new CreateInteractionManualResponse(response.caseId, response.linkId, response.caseNo);
    }
    
}
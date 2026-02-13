public with sharing class FEC_GenesysCreateDummyInteraction {
    
    public static FEC_CreateInteractionGenesys.InteractionResult createDummyInteraction() {
        FEC_CreateInteractionGenesys.GenesysRequest request = new FEC_CreateInteractionGenesys.GenesysRequest();
        request.phoneNumber = '1234567890';
        request.nationalID = '123456789';
        request.genesysInteractionID =UUID.randomUUID()
            .toString()
            .replace('-', '')
            .substring(0, 20);
        
        request.contractNum = 'dummy_contract_num';
        request.cardAccountNum = 'dummy_card_account_num';
        request.agentID = 'dummy_id'+Math.random();
        request.campaignName = 'dummy_campaign_name';
        request.type = 'OutboundEstablished';
        request.method = 'Auto';
        FEC_CreateInteractionGenesys.InteractionResult result = FEC_CreateInteractionGenesys.createInteraction(request);
        return result;
    }
}
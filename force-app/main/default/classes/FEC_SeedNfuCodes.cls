/**
 * @description One-time seed class for NFU Code master data.
 * Run via Developer Console: FEC_SeedNfuCodes.run();
 */
public with sharing class FEC_SeedNfuCodes {
    public static void run() {
        // Delete existing
        delete [SELECT Id FROM FEC_MDM_NFU_Code__c];
        
        List<FEC_MDM_NFU_Code__c> codes = new List<FEC_MDM_NFU_Code__c>();
        codes.add(new FEC_MDM_NFU_Code__c(Name='CS_NFU_COMPLAINT', FEC_Active__c=true));
        codes.add(new FEC_MDM_NFU_Code__c(Name='CS_NFU_CLOSE_90', FEC_Active__c=true));
        codes.add(new FEC_MDM_NFU_Code__c(Name='CS_NFU_COMPLAINT30', FEC_Active__c=true));
        codes.add(new FEC_MDM_NFU_Code__c(Name='CS_NFU_CLOSE_60', FEC_Active__c=true));
        codes.add(new FEC_MDM_NFU_Code__c(Name='CS_NFU_FRAUD_90', FEC_Active__c=true));
        codes.add(new FEC_MDM_NFU_Code__c(Name='CS_NFU_FRAUD_SYS', FEC_Active__c=true));
        codes.add(new FEC_MDM_NFU_Code__c(Name='CS_NFU_COMPLAINT90', FEC_Active__c=true));
        codes.add(new FEC_MDM_NFU_Code__c(Name='CS_NFU_FRAUD_PD90', FEC_Active__c=true));
        codes.add(new FEC_MDM_NFU_Code__c(Name='CS_NFU_COMPLAINT60', FEC_Active__c=true));
        codes.add(new FEC_MDM_NFU_Code__c(Name='CS_NFU_CANCEL', FEC_Active__c=true));
        codes.add(new FEC_MDM_NFU_Code__c(Name='CS_NFU_FRAUD_60', FEC_Active__c=true));
        codes.add(new FEC_MDM_NFU_Code__c(Name='CS_NFU_COMPLAINT10', FEC_Active__c=true));
        codes.add(new FEC_MDM_NFU_Code__c(Name='CS_NFU_PMT', FEC_Active__c=true));
        codes.add(new FEC_MDM_NFU_Code__c(Name='CS_NFU_DEATH', FEC_Active__c=true));
        codes.add(new FEC_MDM_NFU_Code__c(Name='CS_NFU_CUSTMISSING', FEC_Active__c=true));
        codes.add(new FEC_MDM_NFU_Code__c(Name='CS_NFU_ETPMT', FEC_Active__c=true));
        codes.add(new FEC_MDM_NFU_Code__c(Name='CS_NFU_MBW', FEC_Active__c=true));
        codes.add(new FEC_MDM_NFU_Code__c(Name='CS_NFU_NODIS', FEC_Active__c=true));
        codes.add(new FEC_MDM_NFU_Code__c(Name='CS_NFU_NOINS', FEC_Active__c=true));
        codes.add(new FEC_MDM_NFU_Code__c(Name='CS_NFU_OTHERS', FEC_Active__c=true));
        insert codes;
        System.debug('Seeded ' + codes.size() + ' NFU codes');
    }
}
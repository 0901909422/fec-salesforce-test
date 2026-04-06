trigger FEC_EnhancedLetterheadTrigger on FEC_Enhanced_Letterhead__c (before insert, before update, before delete) {
    FEC_EnhancedLetterheadTriggerHandler.run();
}
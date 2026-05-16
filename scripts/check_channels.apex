// Check tất cả FEC_Notification_Channel__c records
List<FEC_Notification_Channel__c> channels = [SELECT Id, Name FROM FEC_Notification_Channel__c];
System.debug('Total channels: ' + channels.size());
for (FEC_Notification_Channel__c c : channels) {
    System.debug('Channel: Id=' + c.Id + ' | Name=[' + c.Name + ']');
}

// Check constant values
System.debug('NOTIFICATION_CHANNEL_EMAIL constant: [' + FEC_ConstantCommon.NOTIFICATION_CHANNEL_EMAIL + ']');
System.debug('NOTIFICATION_CHANNEL_SF_APP constant: [' + FEC_ConstantCommon.NOTIFICATION_CHANNEL_SF_APP + ']');

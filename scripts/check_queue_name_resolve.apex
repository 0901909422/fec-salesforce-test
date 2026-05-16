// Check queue name cho Id 00GAz000005JuCDMA0
Id queueId = '00GAz000005JuCDMA0';
List<Group> queues = [SELECT Id, Name, DeveloperName FROM Group WHERE Id = :queueId AND Type = 'Queue' LIMIT 1];
if (!queues.isEmpty()) {
    System.debug('Queue Name: ' + queues[0].Name + ' | DevName: ' + queues[0].DeveloperName);
} else {
    System.debug('Queue not found');
}

// Test getQueueNames method
Map<String, String> result = FEC_AssignmentListHandler.getQueueNames(new List<String>{'00GAz000005JuCDMA0'});
System.debug('getQueueNames result: ' + result);

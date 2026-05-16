// Check xem CC queues có tồn tại trong Group không
Set<String> ccQueues = new Set<String>{'FEC_DQ_CS_Customer_Care','FEC_Customer_Experience','FEC_Care_Mailbox','FEC_Care_Internal_Task','FEC_Handling'};
List<Group> groups = [SELECT Id, Name, DeveloperName FROM Group WHERE DeveloperName IN :ccQueues AND Type = 'Queue'];
System.debug('Found groups: ' + groups.size());
for (Group g : groups) {
    System.debug('DeveloperName=[' + g.DeveloperName + '] Name=[' + g.Name + ']');
}

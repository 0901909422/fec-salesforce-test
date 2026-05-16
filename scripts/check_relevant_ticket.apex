// Tìm API name của Relevant Ticket object
Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
for (String name : gd.keySet()) {
    if (name.toLowerCase().contains('relevant')) {
        System.debug('Found: ' + name);
    }
}

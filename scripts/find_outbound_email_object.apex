// Find the correct API name for Outbound Email Config object
Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
for (String key : gd.keySet()) {
    if (key.containsIgnoreCase('outbound') || key.containsIgnoreCase('email_config')) {
        System.debug('Found: ' + key + ' => ' + gd.get(key).getDescribe().getLabel());
    }
}

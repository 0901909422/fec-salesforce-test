// Test getFromAddresses trực tiếp
Case c = [SELECT Id FROM Case ORDER BY LastModifiedDate DESC LIMIT 1];
Map<String, Object> result = FEC_CustomEmailService.getFromAddresses(c.Id);
List<Object> opts = (List<Object>) result.get('options');
System.debug('From options count: ' + opts.size());
for (Object o : opts) {
    Map<String, String> opt = (Map<String, String>) o;
    System.debug('  ' + opt.get('label') + ' | ' + opt.get('value'));
}
System.debug('Default: ' + result.get('defaultFrom'));

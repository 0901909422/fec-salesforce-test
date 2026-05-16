// Debug inlineImages - test fetch 1 ảnh từ letterhead
FEC_Enhanced_Letterhead__c lh = [SELECT Id, FEC_Header__c FROM FEC_Enhanced_Letterhead__c WHERE Id = 'a0xAz000000jS4zIAE' LIMIT 1];
System.debug('Header: ' + lh.FEC_Header__c);

// Extract URL từ header
Pattern p = Pattern.compile('src="(https?://[^"]*rtaImage[^"]*)"');
Matcher m = p.matcher(lh.FEC_Header__c);
if (m.find()) {
    String url = m.group(1);
    System.debug('URL to fetch: ' + url);
    
    try {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(url);
        req.setMethod('GET');
        req.setTimeout(10000);
        req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
        Http http = new Http();
        HttpResponse res = http.send(req);
        System.debug('Status: ' + res.getStatusCode());
        System.debug('Content-Type: ' + res.getHeader('Content-Type'));
        System.debug('Body size: ' + res.getBodyAsBlob().size());
    } catch (Exception e) {
        System.debug('ERROR: ' + e.getMessage());
        System.debug('Type: ' + e.getTypeName());
    }
} else {
    System.debug('No rtaImage URL found in header');
}

String url = 'https://fecredit123--fptsb03.sandbox.file.force.com/servlet/rtaImage?eid=a0xAz000000jS4z&feoid=00NAz000006JLmt&refid=0EMAz000000uTAb';
String sid = UserInfo.getSessionId();

HttpRequest req = new HttpRequest();
req.setEndpoint(url);
req.setMethod('GET');
req.setTimeout(10000);
req.setHeader('Cookie', 'sid=' + sid);
Http http = new Http();
HttpResponse res = http.send(req);

System.debug('Status: ' + res.getStatusCode());

// Thử tất cả header keys
List<String> keys = res.getHeaderKeys();
System.debug('Header count: ' + keys.size());
for (String k : keys) {
    System.debug('Header [' + k + '] = ' + res.getHeader(k));
}

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
System.debug('Location header: ' + res.getHeader('Location'));
System.debug('All headers: ' + res.getHeaderKeys());
System.debug('Body (first 500): ' + res.getBody().left(500));

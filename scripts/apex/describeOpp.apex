// Check REST describe for the Technical_* fields
// REST describe should be the most up-to-date view
HttpRequest req = new HttpRequest();
req.setEndpoint(URL.getOrgDomainUrl().toExternalForm() + '/services/data/v62.0/sobjects/Opportunity/describe');
req.setMethod('GET');
req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
HttpResponse res = new Http().send(req);

// Search for all Technical_ fields
String body = res.getBody();
Integer idx = 0;
while (true) {
    Integer pos = body.indexOf('Technical_', idx);
    if (pos == -1) break;
    // Extract surrounding context
    Integer start = Math.max(0, pos - 20);
    Integer endPos = Math.min(body.length(), pos + 80);
    System.debug('FOUND at ' + pos + ': ...' + body.substring(start, endPos) + '...');
    idx = pos + 1;
}

// Also check for Gaming fields
Integer idx2 = 0;
while (true) {
    Integer pos = body.indexOf('Gaming_', idx2);
    if (pos == -1) break;
    Integer start = Math.max(0, pos - 20);
    Integer endPos = Math.min(body.length(), pos + 80);
    System.debug('GAMING FOUND at ' + pos + ': ...' + body.substring(start, endPos) + '...');
    idx2 = pos + 1;
}

System.debug('Body length: ' + body.length());
System.debug('Contains gaming_test_score: ' + body.contains('Gaming_Test_Score'));
System.debug('Contains score_matching: ' + body.contains('Score_Matching'));

// Test if the fields are actually writable using fully dynamic approach
try {
    // Dynamic SOQL to bypass compile-time field checks
    List<SObject> opps = Database.query('SELECT Id FROM Opportunity LIMIT 1');
    if (!opps.isEmpty()) {
        SObject sobj = opps[0];
        sobj.put('Technical_Interview_Status__c', 'Test');
        update sobj;
        System.debug('WRITE SUCCESS');
        
        // Dynamic read
        List<SObject> recheck = Database.query(
            'SELECT Technical_Interview_Status__c FROM Opportunity WHERE Id = \'' + sobj.Id + '\''
        );
        System.debug('READ BACK: ' + recheck[0].get('Technical_Interview_Status__c'));
    }
} catch (Exception e) {
    System.debug('ERROR: ' + e.getTypeName() + ' - ' + e.getMessage());
}

// Also check REST API describe
HttpRequest req = new HttpRequest();
req.setEndpoint(URL.getOrgDomainUrl().toExternalForm() + '/services/data/v62.0/sobjects/Opportunity/describe');
req.setMethod('GET');
req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
HttpResponse res = new Http().send(req);
String body = res.getBody();
System.debug('HAS Technical_Interview_Status: ' + body.contains('Technical_Interview_Status'));
System.debug('HAS Technical_Meet_Link: ' + body.contains('Technical_Meet_Link'));

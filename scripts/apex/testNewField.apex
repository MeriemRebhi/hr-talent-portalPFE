// Test: can we create ANY new field on Opportunity via Tooling API?
String baseUrl = URL.getOrgDomainUrl().toExternalForm() + '/services/data/v62.0/tooling/sobjects/CustomField';
String sessionId = UserInfo.getSessionId();

Map<String, Object> fieldDef = new Map<String, Object>{
    'FullName' => 'Opportunity.Test_Phantom_Check__c',
    'Metadata' => new Map<String, Object>{
        'label' => 'Test Phantom Check',
        'type' => 'Text',
        'length' => 10
    }
};

HttpRequest req = new HttpRequest();
req.setEndpoint(baseUrl);
req.setMethod('POST');
req.setHeader('Authorization', 'Bearer ' + sessionId);
req.setHeader('Content-Type', 'application/json');
req.setBody(JSON.serialize(fieldDef));
req.setTimeout(30000);

HttpResponse res = new Http().send(req);
System.debug('CREATE Test_Phantom_Check: ' + res.getStatusCode() + ' ' + res.getBody());

// Now immediately test if it's accessible
Map<String, Schema.SObjectField> oppFields = Schema.SObjectType.Opportunity.fields.getMap();
System.debug('Test_Phantom_Check in describe: ' + oppFields.containsKey('test_phantom_check__c'));

// Dynamic DML test
try {
    List<SObject> opps = Database.query('SELECT Id FROM Opportunity LIMIT 1');
    opps[0].put('Test_Phantom_Check__c', 'hello');
    update opps[0];
    System.debug('DYNAMIC WRITE: SUCCESS');
} catch (Exception e) {
    System.debug('DYNAMIC WRITE: FAILED - ' + e.getMessage());
}

// REST describe check
HttpRequest descReq = new HttpRequest();
descReq.setEndpoint(URL.getOrgDomainUrl().toExternalForm() + '/services/data/v62.0/sobjects/Opportunity/describe');
descReq.setMethod('GET');
descReq.setHeader('Authorization', 'Bearer ' + sessionId);
HttpResponse descRes = new Http().send(descReq);
System.debug('REST describe contains Test_Phantom_Check: ' + descRes.getBody().contains('Test_Phantom_Check'));

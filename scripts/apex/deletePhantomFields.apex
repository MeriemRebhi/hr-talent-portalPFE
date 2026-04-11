// Delete phantom fields by first removing them from Tooling, then re-creating
// Step 1: Find all 6 phantom Technical_ field IDs
String[] fieldNames = new String[]{
    'Technical_Meet_Link',
    'Technical_Interview_Status',
    'Technical_Interview_Score',
    'Technical_Interview_Duration',
    'Technical_Interview_DateTime',
    'Technical_Composite_Score'
};

for (String fname : fieldNames) {
    HttpRequest req = new HttpRequest();
    req.setEndpoint(URL.getOrgDomainUrl().toExternalForm() + 
        '/services/data/v62.0/tooling/query?q=SELECT+Id,DeveloperName+FROM+CustomField+WHERE+DeveloperName=\'' + fname + '\'+AND+TableEnumOrId=\'Opportunity\'');
    req.setMethod('GET');
    req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
    req.setHeader('Content-Type', 'application/json');
    
    HttpResponse res = new Http().send(req);
    Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
    List<Object> records = (List<Object>) result.get('records');
    
    if (!records.isEmpty()) {
        Map<String, Object> rec = (Map<String, Object>) records[0];
        String fieldId = (String) rec.get('Id');
        System.debug('FIELD: ' + fname + ' => ID: ' + fieldId);
        
        // Try DELETE
        HttpRequest delReq = new HttpRequest();
        delReq.setEndpoint(URL.getOrgDomainUrl().toExternalForm() + 
            '/services/data/v62.0/tooling/sobjects/CustomField/' + fieldId);
        delReq.setMethod('DELETE');
        delReq.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
        
        HttpResponse delRes = new Http().send(delReq);
        System.debug('DELETE ' + fname + ': ' + delRes.getStatusCode() + ' ' + delRes.getBody());
    }
}

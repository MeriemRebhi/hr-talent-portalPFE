// Find all Technical_ phantom fields on Opportunity via Tooling API
// Then PATCH each to force database column provisioning
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
        System.debug('Found ' + fname + ': ' + fieldId);
        
        // PATCH to force provisioning
        HttpRequest patchReq = new HttpRequest();
        patchReq.setEndpoint(URL.getOrgDomainUrl().toExternalForm() + 
            '/services/data/v62.0/tooling/sobjects/CustomField/' + fieldId + '?_HttpMethod=PATCH');
        patchReq.setMethod('POST');
        patchReq.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
        patchReq.setHeader('Content-Type', 'application/json');
        
        // Get current metadata first
        HttpRequest getReq = new HttpRequest();
        getReq.setEndpoint(URL.getOrgDomainUrl().toExternalForm() + 
            '/services/data/v62.0/tooling/sobjects/CustomField/' + fieldId);
        getReq.setMethod('GET');
        getReq.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
        getReq.setHeader('Content-Type', 'application/json');
        
        HttpResponse getRes = new Http().send(getReq);
        Map<String, Object> fieldData = (Map<String, Object>) JSON.deserializeUntyped(getRes.getBody());
        Map<String, Object> metadata = (Map<String, Object>) fieldData.get('Metadata');
        
        // Update label slightly to force a change
        String currentLabel = (String) metadata.get('label');
        metadata.put('label', currentLabel);  // same label, but force update
        
        Map<String, Object> patchBody = new Map<String, Object>();
        patchBody.put('Metadata', metadata);
        
        patchReq.setBody(JSON.serialize(patchBody));
        HttpResponse patchRes = new Http().send(patchReq);
        System.debug('PATCH ' + fname + ': status=' + patchRes.getStatusCode());
    } else {
        System.debug('NOT FOUND: ' + fname);
    }
}

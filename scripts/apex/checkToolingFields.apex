// Check if phantom fields still exist in Tooling API
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
    Integer count = (Integer) result.get('totalSize');
    System.debug(fname + ': ' + (count > 0 ? 'STILL IN TOOLING' : 'GONE'));
}

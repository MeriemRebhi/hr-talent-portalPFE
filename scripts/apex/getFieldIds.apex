// Try to get field IDs via Tooling API approach
// Use Database.query with dynamic SOQL on sObjects
HttpRequest req = new HttpRequest();
req.setEndpoint(URL.getOrgDomainUrl().toExternalForm() + '/services/data/v66.0/tooling/query/?q=' + 
    EncodingUtil.urlEncode('SELECT Id, DeveloperName, TableEnumOrId FROM CustomField WHERE TableEnumOrId = \'01Ifj000006BnZpEAK\' AND DeveloperName IN (\'Email\',\'User\',\'Attempts\',\'Is_Used\')', 'UTF-8'));
req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
req.setMethod('GET');
Http http = new Http();
HttpResponse res = http.send(req);
System.debug('Tooling API response: ' + res.getBody());

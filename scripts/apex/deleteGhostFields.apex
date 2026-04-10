// Delete ghost fields via Tooling API then recreate them
String baseUrl = URL.getOrgDomainUrl().toExternalForm();
String sessionId = UserInfo.getSessionId();

// Ghost field IDs
List<String> fieldIds = new List<String>{
    '00Nfj00003E0DjdEAF', // Attempts
    '00Nfj00003E0DjeEAF', // Email
    '00Nfj00003E0DjgEAF', // Is_Used
    '00Nfj00003E0DjiEAF'  // User
};

Http http = new Http();

for (String fieldId : fieldIds) {
    HttpRequest req = new HttpRequest();
    req.setEndpoint(baseUrl + '/services/data/v66.0/tooling/sobjects/CustomField/' + fieldId);
    req.setHeader('Authorization', 'Bearer ' + sessionId);
    req.setMethod('DELETE');
    HttpResponse res = http.send(req);
    System.debug('DELETE ' + fieldId + ' → ' + res.getStatusCode() + ' ' + res.getBody());
}

System.debug('All ghost fields deleted. Now redeploy via SF CLI.');

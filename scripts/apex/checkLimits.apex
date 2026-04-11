// Check Opportunity custom field count and org limits
HttpRequest req = new HttpRequest();
req.setEndpoint(URL.getOrgDomainUrl().toExternalForm() + '/services/data/v62.0/limits');
req.setMethod('GET');
req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
HttpResponse res = new Http().send(req);
Map<String, Object> limits = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
Map<String, Object> customFields = (Map<String, Object>) limits.get('CustomField');
System.debug('CustomField Limits: ' + JSON.serialize(customFields));

// Count existing custom fields on Opportunity
Map<String, Schema.SObjectField> oppFields = Schema.SObjectType.Opportunity.fields.getMap();
Integer customCount = 0;
for (String fname : oppFields.keySet()) {
    if (fname.endsWith('__c')) {
        customCount++;
        System.debug('Custom: ' + fname);
    }
}
System.debug('Total custom fields on Opportunity: ' + customCount);

// Check org edition via REST
HttpRequest orgReq = new HttpRequest();
orgReq.setEndpoint(URL.getOrgDomainUrl().toExternalForm() + '/services/data/v62.0/sobjects/Organization');
orgReq.setMethod('GET');
orgReq.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
HttpResponse orgRes = new Http().send(orgReq);
System.debug('Org info: ' + orgRes.getBody().substring(0, Math.min(500, orgRes.getBody().length())));

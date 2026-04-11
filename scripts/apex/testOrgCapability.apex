// Test if we can create fields on Account (different standard object)
String baseUrl = URL.getOrgDomainUrl().toExternalForm() + '/services/data/v62.0/tooling/sobjects/CustomField';

Map<String, Object> fieldDef = new Map<String, Object>{
    'FullName' => 'Account.Test_Account_Field__c',
    'Metadata' => new Map<String, Object>{
        'label' => 'Test Account Field',
        'type' => 'Text',
        'length' => 10
    }
};

HttpRequest req = new HttpRequest();
req.setEndpoint(baseUrl);
req.setMethod('POST');
req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
req.setHeader('Content-Type', 'application/json');
req.setBody(JSON.serialize(fieldDef));
req.setTimeout(30000);
HttpResponse res = new Http().send(req);
System.debug('CREATE on Account: ' + res.getStatusCode() + ' ' + res.getBody());

// Check if it's accessible
Map<String, Schema.SObjectField> accFields = Schema.SObjectType.Account.fields.getMap();
System.debug('Account field exists: ' + accFields.containsKey('test_account_field__c'));

// Also test on a custom object
Map<String, Object> fieldDef2 = new Map<String, Object>{
    'FullName' => 'Technical_Question__c.Test_Custom_Field__c',
    'Metadata' => new Map<String, Object>{
        'label' => 'Test Custom Field',
        'type' => 'Text',
        'length' => 10
    }
};

HttpRequest req2 = new HttpRequest();
req2.setEndpoint(baseUrl);
req2.setMethod('POST');
req2.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
req2.setHeader('Content-Type', 'application/json');
req2.setBody(JSON.serialize(fieldDef2));
req2.setTimeout(30000);
HttpResponse res2 = new Http().send(req2);
System.debug('CREATE on Custom Object: ' + res2.getStatusCode() + ' ' + res2.getBody());

// Check the org edition
List<Organization> orgs = [SELECT OrganizationType, InstanceName, IsSandbox, TrialExpirationDate FROM Organization LIMIT 1];
for (Organization o : orgs) {
    System.debug('OrgType: ' + o.OrganizationType);
    System.debug('Instance: ' + o.InstanceName);
    System.debug('IsSandbox: ' + o.IsSandbox);
    System.debug('TrialExpiry: ' + o.TrialExpirationDate);
}

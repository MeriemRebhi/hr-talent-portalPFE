// Create 6 Technical_* fields on Opportunity via Tooling API POST
// This actually provisions DB columns, unlike metadata deploy which creates phantoms

String baseUrl = URL.getOrgDomainUrl().toExternalForm() + '/services/data/v62.0/tooling/sobjects/CustomField';
String sessionId = UserInfo.getSessionId();

// Field definitions: DeveloperName, Label, Type, Length/Precision/Scale
List<Map<String, Object>> fieldDefs = new List<Map<String, Object>>();

// 1. Technical_Meet_Link__c (Url)
Map<String, Object> f1 = new Map<String, Object>{
    'FullName' => 'Opportunity.Technical_Meet_Link__c',
    'Metadata' => new Map<String, Object>{
        'label' => 'Technical Meet Link',
        'type' => 'Url',
        'description' => 'Lien Meet pour l entretien technique'
    }
};
fieldDefs.add(f1);

// 2. Technical_Interview_Status__c (Text 50)
Map<String, Object> f2 = new Map<String, Object>{
    'FullName' => 'Opportunity.Technical_Interview_Status__c',
    'Metadata' => new Map<String, Object>{
        'label' => 'Technical Interview Status',
        'type' => 'Text',
        'length' => 50,
        'description' => 'Statut de l entretien technique'
    }
};
fieldDefs.add(f2);

// 3. Technical_Interview_Score__c (Number 5,1)
Map<String, Object> f3 = new Map<String, Object>{
    'FullName' => 'Opportunity.Technical_Interview_Score__c',
    'Metadata' => new Map<String, Object>{
        'label' => 'Technical Interview Score',
        'type' => 'Number',
        'precision' => 5,
        'scale' => 1,
        'description' => 'Score de l entretien technique'
    }
};
fieldDefs.add(f3);

// 4. Technical_Interview_Duration__c (Picklist 30/45/60/90)
Map<String, Object> f4 = new Map<String, Object>{
    'FullName' => 'Opportunity.Technical_Interview_Duration__c',
    'Metadata' => new Map<String, Object>{
        'label' => 'Technical Interview Duration',
        'type' => 'Picklist',
        'description' => 'Durée de l entretien technique',
        'valueSet' => new Map<String, Object>{
            'valueSetDefinition' => new Map<String, Object>{
                'value' => new List<Map<String, Object>>{
                    new Map<String, Object>{ 'fullName' => '30', 'label' => '30 min', 'default' => false },
                    new Map<String, Object>{ 'fullName' => '45', 'label' => '45 min', 'default' => true },
                    new Map<String, Object>{ 'fullName' => '60', 'label' => '60 min', 'default' => false },
                    new Map<String, Object>{ 'fullName' => '90', 'label' => '90 min', 'default' => false }
                }
            }
        }
    }
};
fieldDefs.add(f4);

// 5. Technical_Interview_DateTime__c (DateTime)
Map<String, Object> f5 = new Map<String, Object>{
    'FullName' => 'Opportunity.Technical_Interview_DateTime__c',
    'Metadata' => new Map<String, Object>{
        'label' => 'Technical Interview DateTime',
        'type' => 'DateTime',
        'description' => 'Date et heure de l entretien technique'
    }
};
fieldDefs.add(f5);

// 6. Technical_Composite_Score__c (Number 5,1)
Map<String, Object> f6 = new Map<String, Object>{
    'FullName' => 'Opportunity.Technical_Composite_Score__c',
    'Metadata' => new Map<String, Object>{
        'label' => 'Technical Composite Score',
        'type' => 'Number',
        'precision' => 5,
        'scale' => 1,
        'description' => 'Score composite technique'
    }
};
fieldDefs.add(f6);

// Create each field via Tooling API POST
for (Map<String, Object> fieldDef : fieldDefs) {
    HttpRequest req = new HttpRequest();
    req.setEndpoint(baseUrl);
    req.setMethod('POST');
    req.setHeader('Authorization', 'Bearer ' + sessionId);
    req.setHeader('Content-Type', 'application/json');
    req.setBody(JSON.serialize(fieldDef));
    req.setTimeout(30000);

    HttpResponse res = new Http().send(req);
    String fullName = (String) fieldDef.get('FullName');
    System.debug('CREATE ' + fullName + ': ' + res.getStatusCode() + ' ' + res.getBody());
}

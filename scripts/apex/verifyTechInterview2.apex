// First verify the object exists
Map<String, Schema.SObjectField> tiFields = Schema.SObjectType.Technical_Interview__c.fields.getMap();
System.debug('=== Technical_Interview__c fields ===');
for (String fname : tiFields.keySet()) {
    if (fname.endsWith('__c')) {
        System.debug('  ' + fname + ': EXISTS');
    }
}

// Find a valid Application opportunity
List<Opportunity> validOpps = [SELECT Id, Name, StageName FROM Opportunity WHERE StageName = 'Technique' LIMIT 5];
if (validOpps.isEmpty()) {
    validOpps = [SELECT Id, Name, StageName FROM Opportunity LIMIT 5];
}
for (Opportunity o : validOpps) {
    System.debug('OPP: ' + o.Id + ' - ' + o.Name + ' - ' + o.StageName);
}

if (!validOpps.isEmpty()) {
    Id testOppId = validOpps[0].Id;
    Technical_Interview__c ti = new Technical_Interview__c(
        Opportunity__c = testOppId,
        Status__c = 'Scheduled',
        Meet_Link__c = 'https://orgfarm-3ed211f8bb-dev-ed.develop.my.site.com/home2/s/entretientechnique?id=' + testOppId,
        Duration__c = '45',
        Interview_DateTime__c = DateTime.now().addDays(2)
    );
    insert ti;
    System.debug('CREATED Technical_Interview__c: ' + ti.Id);

    // Read it back
    Technical_Interview__c readBack = [
        SELECT Id, Opportunity__c, Status__c, Meet_Link__c, Duration__c, 
               Interview_DateTime__c, Score__c, Composite_Score__c
        FROM Technical_Interview__c WHERE Id = :ti.Id
    ];
    System.debug('READ BACK - Status: ' + readBack.Status__c);
    System.debug('READ BACK - MeetLink: ' + readBack.Meet_Link__c);
    System.debug('READ BACK - Duration: ' + readBack.Duration__c);
    System.debug('READ BACK - DateTime: ' + readBack.Interview_DateTime__c);
    System.debug('SUCCESS! Technical_Interview__c is REAL!');
}

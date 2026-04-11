// Grant Guest User access to Technical_Interview__c object
// Find the Guest User profile
Id guestProfileId = '00efj000008OTBdAAO';

// Grant object permission via Apex: ensure the profile can read/create/edit Technical_Interview__c
// The without sharing on controllers handles this, but let's also test the controller method

// Test getInterviewInfo with the Boudidah opportunity (has Technique stage)
Id testOppId = '006fj00000BF6A1AAL';
try {
    Map<String, Object> info = TechnicalInterviewController.getInterviewInfo(testOppId);
    System.debug('=== getInterviewInfo Result ===');
    for (String key : info.keySet()) {
        System.debug('  ' + key + ': ' + info.get(key));
    }
} catch (Exception e) {
    System.debug('getInterviewInfo ERROR: ' + e.getMessage());
}

// Check if Technical_Interview__c record was created for this opp
List<Technical_Interview__c> tis = [
    SELECT Id, Status__c, Meet_Link__c, Duration__c, Interview_DateTime__c
    FROM Technical_Interview__c WHERE Opportunity__c = :testOppId
];
System.debug('Technical_Interview__c records for opp: ' + tis.size());
for (Technical_Interview__c ti : tis) {
    System.debug('  TI: ' + ti.Id + ' Status=' + ti.Status__c + ' Meet=' + ti.Meet_Link__c);
}

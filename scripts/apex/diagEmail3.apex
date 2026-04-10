// Diagnostic: recent gaming test scheduling and email status
List<Opportunity> opps = [
    SELECT Id, Name, Gaming_Test_DateTime__c, Gaming_Test_Status__c, Gaming_Meet_Link__c
    FROM Opportunity
    WHERE Gaming_Test_DateTime__c != null
    ORDER BY LastModifiedDate DESC
    LIMIT 5
];
System.debug('=== RECENT GAMING TESTS: ' + opps.size() + ' ===');
for (Opportunity o : opps) {
    System.debug('OPP: ' + o.Name + ' | DateTime: ' + o.Gaming_Test_DateTime__c + ' | Status: ' + o.Gaming_Test_Status__c);
    System.debug('  Link: ' + o.Gaming_Meet_Link__c);

    List<Lead> leads = [SELECT Id, FirstName, LastName, Email FROM Lead WHERE ConvertedOpportunityId = :o.Id LIMIT 1];
    if (leads.isEmpty()) {
        System.debug('  >> NO LEAD FOUND — email cannot be sent!');
    } else {
        Lead l = leads[0];
        System.debug('  >> Lead: ' + l.FirstName + ' ' + l.LastName + ' | Email: ' + l.Email);
    }
}

// Direct test: call scheduleGamingTest on the most recent one
if (!opps.isEmpty()) {
    Opportunity latest = opps[0];
    System.debug('=== TESTING EMAIL SEND for: ' + latest.Name + ' (Id: ' + latest.Id + ') ===');
    try {
        InternalDashboardController.scheduleGamingTest(
            latest.Id,
            latest.Gaming_Test_DateTime__c != null ? latest.Gaming_Test_DateTime__c : DateTime.now().addDays(1),
            '30'
        );
        System.debug('SUCCESS — scheduleGamingTest completed without error');
    } catch (Exception e) {
        System.debug('ERROR: ' + e.getMessage());
    }
}

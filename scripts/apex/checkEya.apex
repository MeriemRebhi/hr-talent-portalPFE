// Check Eya Boudidah's opportunity and gaming test status
List<Lead> leads = [SELECT Id, FirstName, LastName, Email, ConvertedOpportunityId, IsConverted FROM Lead WHERE LastName = 'Boudidah' LIMIT 5];
System.debug('=== EYA BOUDIDAH LEADS ===');
for (Lead l : leads) {
    System.debug('Lead: ' + l.FirstName + ' ' + l.LastName + ' | Email: ' + l.Email + ' | Converted: ' + l.IsConverted + ' | OppId: ' + l.ConvertedOpportunityId);
    if (l.IsConverted && l.ConvertedOpportunityId != null) {
        List<Opportunity> opps = Database.query('SELECT Id, Name, StageName FROM Opportunity WHERE Id = \'' + l.ConvertedOpportunityId + '\' LIMIT 1');
        if (!opps.isEmpty()) {
            Opportunity o = opps[0];
            System.debug('  OPP: ' + o.Name + ' | Stage: ' + o.StageName);
        }
        // Try sending test email
        System.debug('=== SENDING TEST EMAIL TO EYA ===');
        try {
            InternalDashboardController.scheduleGamingTest(
                l.ConvertedOpportunityId,
                DateTime.now().addDays(1),
                '30'
            );
            System.debug('SUCCESS — email sent to ' + l.Email);
        } catch (Exception e) {
            System.debug('ERROR: ' + e.getMessage());
        }
    }
}

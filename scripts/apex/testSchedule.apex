// Test calling scheduleGamingTest directly
// First find the most recently modified gaming opportunity
List<Opportunity> opps = [SELECT Id, Name FROM Opportunity WHERE StageName = 'Gaming' ORDER BY LastModifiedDate DESC LIMIT 1];
if (opps.isEmpty()) {
    System.debug('NO GAMING OPPORTUNITIES FOUND');
} else {
    Opportunity o = opps[0];
    System.debug('Testing with: ' + o.Name + ' (' + o.Id + ')');
    try {
        InternalDashboardController.scheduleGamingTest(
            o.Id,
            DateTime.now().addDays(1),
            '30'
        );
        System.debug('SUCCESS — method completed, email should have been sent');
    } catch (Exception e) {
        System.debug('ERROR: ' + e.getMessage());
        System.debug('STACK: ' + e.getStackTraceString());
    }
}

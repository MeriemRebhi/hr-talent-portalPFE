// Test the actual controller method with a real opp
List<Opportunity> opps = [SELECT Id FROM Opportunity WHERE RecordType.DeveloperName = 'Application' AND StageName = 'Gaming' LIMIT 1];
if (!opps.isEmpty()) {
    Id oppId = opps[0].Id;
    try {
        InternalDashboardController.scheduleGamingTest(oppId, DateTime.now().addDays(1), '30');
        System.debug('SUCCESS: scheduleGamingTest executed without error for opp ' + oppId);
    } catch (Exception e) {
        System.debug('ERROR: ' + e.getMessage());
    }
} else {
    System.debug('No Gaming stage opp found');
}

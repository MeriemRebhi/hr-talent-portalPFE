// Test if the deployed controller works at runtime despite Job_Posting__c describe issue
// Find a candidature opportunity
List<Opportunity> opps = [SELECT Id, Name, StageName FROM Opportunity WHERE StageName = 'Technique' LIMIT 1];
if (opps.isEmpty()) {
    opps = [SELECT Id, Name, StageName FROM Opportunity WHERE RecordType.Name = 'Candidature' LIMIT 5];
}
System.debug('Found opps: ' + opps.size());
for (Opportunity o : opps) {
    System.debug('OPP: ' + o.Id + ' | ' + o.Name + ' | ' + o.StageName);
}

if (!opps.isEmpty()) {
    try {
        Map<String, Object> info = TechnicalInterviewController.getInterviewInfo(opps[0].Id);
        System.debug('SUCCESS! getInterviewInfo returned: ' + info);
    } catch (Exception e) {
        System.debug('ERROR in getInterviewInfo: ' + e.getMessage());
        System.debug('Stack: ' + e.getStackTraceString());
    }
}

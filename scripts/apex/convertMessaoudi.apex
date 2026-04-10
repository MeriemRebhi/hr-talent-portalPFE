// Convertir le Lead Messaoudi Mohamed (Score 80, non converti)
Id leadId = '00Qfj00000EujIXEAZ';
Lead l = [SELECT Id, Score_Matching__c, IsConverted, Status FROM Lead WHERE Id = :leadId LIMIT 1];
System.debug('Lead: ' + l.Id + ' | Score: ' + l.Score_Matching__c + ' | Status: ' + l.Status + ' | Converted: ' + l.IsConverted);
if (!l.IsConverted) {
    CVScoringService.executeFullConversion(String.valueOf(l.Id), l.Score_Matching__c);
    Lead a = [SELECT Id, IsConverted, ConvertedContactId, ConvertedAccountId, ConvertedOpportunityId FROM Lead WHERE Id = :leadId LIMIT 1];
    System.debug('Result: Converted=' + a.IsConverted + ' Contact=' + a.ConvertedContactId + ' Account=' + a.ConvertedAccountId + ' Opp=' + a.ConvertedOpportunityId);
}

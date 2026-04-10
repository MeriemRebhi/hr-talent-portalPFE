// Convertir le Lead specifique Rebhi Meriem avec Score 80
Id leadId = '00Qfj00000EuizBEAR';
Lead l = [SELECT Id, Score_Matching__c, IsConverted, Status FROM Lead WHERE Id = :leadId LIMIT 1];
System.debug('Lead: ' + l.Id + ' | Score: ' + l.Score_Matching__c + ' | Status: ' + l.Status + ' | Converted: ' + l.IsConverted);
if (!l.IsConverted) {
    CVScoringService.executeFullConversion(String.valueOf(l.Id), l.Score_Matching__c);
    Lead after2 = [SELECT Id, IsConverted, ConvertedContactId, ConvertedAccountId, ConvertedOpportunityId FROM Lead WHERE Id = :leadId LIMIT 1];
    System.debug('After conversion: Converted=' + after2.IsConverted + ' Contact=' + after2.ConvertedContactId + ' Account=' + after2.ConvertedAccountId + ' Opp=' + after2.ConvertedOpportunityId);
} else {
    System.debug('Lead already converted!');
}

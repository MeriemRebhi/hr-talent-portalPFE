List<Lead> leads = [SELECT Id, Email, Score_Matching__c, IsConverted, Status FROM Lead WHERE Email = 'm.rebhi24292@pi.tn' AND IsConverted = false LIMIT 1];
if (!leads.isEmpty()) {
    System.debug('Found Lead: ' + leads[0].Id + ' Score: ' + leads[0].Score_Matching__c + ' Status: ' + leads[0].Status);
    CVScoringService.executeFullConversion(String.valueOf(leads[0].Id), leads[0].Score_Matching__c);
    Lead after2 = [SELECT Id, IsConverted FROM Lead WHERE Id = :leads[0].Id LIMIT 1];
    System.debug('Converted: ' + after2.IsConverted);
} else {
    System.debug('No unconverted lead found with email m.rebhi24292@pi.tn');
}

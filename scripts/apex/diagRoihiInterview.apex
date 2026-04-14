// Check recent emails sent
System.debug('Email invocations used: ' + Limits.getEmailInvocations() + ' / ' + Limits.getLimitEmailInvocations());

// Check recent emails sent
List<EmailMessage> emails = [SELECT Id, Subject, ToAddress, Status, CreatedDate FROM EmailMessage ORDER BY CreatedDate DESC LIMIT 10];
for(EmailMessage em : emails) {
    System.debug('Email: ' + em.ToAddress + ' | ' + em.Subject + ' | ' + em.Status + ' | ' + em.CreatedDate);
}

// Check Technical_Interview__c for roihi's opp
List<Lead> leads = [SELECT Id, ConvertedOpportunityId, IsConverted FROM Lead WHERE Email = 'roihizeineb123@gmail.com' LIMIT 1];
for (Lead l : leads) {
    System.debug('Lead: Id=' + l.Id + ' | Converted=' + l.IsConverted + ' | OppId=' + l.ConvertedOpportunityId);
}

// Check all opps with roihi in name
List<Opportunity> opps = [SELECT Id, Name, StageName FROM Opportunity WHERE Name LIKE '%roihi%' OR Name LIKE '%Rouihi%' OR Name LIKE '%zeineb%' LIMIT 5];
System.debug('Found ' + opps.size() + ' opps');
for (Opportunity o : opps) {
    System.debug('Opp: ' + o.Name + ' | Stage=' + o.StageName + ' | Id=' + o.Id);
    List<Technical_Interview__c> tis = [SELECT Id, Interview_DateTime__c, Meet_Link__c, Status__c, Score__c FROM Technical_Interview__c WHERE Opportunity__c = :o.Id LIMIT 1];
    if (!tis.isEmpty()) {
        System.debug('  TI: DateTime=' + tis[0].Interview_DateTime__c + ' | Meet=' + tis[0].Meet_Link__c + ' | Status=' + tis[0].Status__c + ' | Score=' + tis[0].Score__c);
    } else {
        System.debug('  NO TI record for this opp');
    }
}

// Check all Technical_Interview__c records
List<Technical_Interview__c> allTI = [SELECT Id, Opportunity__c, Opportunity__r.Name, Interview_DateTime__c, Status__c, Meet_Link__c FROM Technical_Interview__c ORDER BY CreatedDate DESC LIMIT 10];
System.debug('All TI records: ' + allTI.size());
for (Technical_Interview__c ti : allTI) {
    System.debug('TI: Opp=' + ti.Opportunity__r.Name + ' | Date=' + ti.Interview_DateTime__c + ' | Status=' + ti.Status__c + ' | Meet=' + ti.Meet_Link__c);
}

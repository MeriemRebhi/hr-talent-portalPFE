// Diagnostic complet : chercher les leads avec score > 15 non convertis
List<Lead> leads = [
    SELECT Id, FirstName, LastName, Email, Status, Score_Matching__c, IsConverted, CreatedDate
    FROM Lead
    WHERE IsConverted = false
    AND Score_Matching__c > 15
    ORDER BY CreatedDate DESC
    LIMIT 10
];

System.debug('🔍 Leads avec score > 15 non convertis: ' + leads.size());
for (Lead l : leads) {
    System.debug('   ' + l.Id + ' | ' + l.FirstName + ' ' + l.LastName + ' | Score=' + l.Score_Matching__c + ' | Status=' + l.Status);
}

// Vérifier si le Platform Event Lead_Convert_Request__e existe dans l'org
try {
    Lead_Convert_Request__e evt = new Lead_Convert_Request__e();
    System.debug('✅ Platform Event Lead_Convert_Request__e existe dans l\'org');
} catch (Exception e) {
    System.debug('❌ Platform Event Lead_Convert_Request__e N\'EXISTE PAS encore (déploiement requis): ' + e.getMessage());
}

// Forcer la conversion de tous les leads score > 15 non convertis
Integer converted = 0;
for (Lead lead : leads) {
    try {
        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(lead.Id);

        List<Contact> existingContacts = [SELECT Id, AccountId FROM Contact WHERE Email = :lead.Email LIMIT 1];
        if (!existingContacts.isEmpty()) {
            lc.setContactId(existingContacts[0].Id);
            lc.setAccountId(existingContacts[0].AccountId);
        } else {
            Account newAcc = new Account(Name = lead.Email);
            Database.DMLOptions dml = new Database.DMLOptions();
            dml.DuplicateRuleHeader.allowSave = true;
            Database.insert(newAcc, dml);
            lc.setAccountId(newAcc.Id);
        }

        LeadStatus convertStatus = [SELECT MasterLabel FROM LeadStatus WHERE IsConverted=true LIMIT 1];
        lc.setConvertedStatus(convertStatus.MasterLabel);
        lc.setOpportunityName(lead.LastName + ' - Candidature (' + lead.Score_Matching__c + '%)');
        lc.setDoNotCreateOpportunity(false);

        Database.LeadConvertResult lcr = Database.convertLead(lc);
        if (lcr.isSuccess()) {
            converted++;
            System.debug('✅ Converti: ' + lead.FirstName + ' ' + lead.LastName + ' | Opp=' + lcr.getOpportunityId());
            if (lcr.getOpportunityId() != null) {
                update new Opportunity(Id = lcr.getOpportunityId(), Score_Matching__c = lead.Score_Matching__c);
            }
        } else {
            System.debug('❌ Échec: ' + lead.Email + ' → ' + lcr.getErrors()[0].getMessage());
        }
    } catch (Exception e) {
        System.debug('❌ Exception: ' + lead.Email + ' → ' + e.getMessage());
    }
}
System.debug('✅ ' + converted + '/' + leads.size() + ' lead(s) convertis');

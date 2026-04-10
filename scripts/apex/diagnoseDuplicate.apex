// Diagnostic complet des règles de doublon qui bloquent la conversion
// 1. Chercher TOUTES les DuplicateRule (Lead, Contact, Account)
List<DuplicateRule> allRules = [
    SELECT Id, DeveloperName, IsActive, MasterLabel, SObjectType
    FROM DuplicateRule
    WHERE IsActive = true
];
System.debug('🔍 Règles de doublon ACTIVES: ' + allRules.size());
for (DuplicateRule r : allRules) {
    System.debug('   ' + r.SObjectType + ' | ' + r.MasterLabel + ' (' + r.DeveloperName + ') | Active=' + r.IsActive);
}

// 2. Voir combien de Leads/Contacts ont le même email
Integer leadCount = [SELECT COUNT() FROM Lead WHERE Email = 'm.rebhi24292@pi.tn' AND IsConverted = false];
Integer contactCount = [SELECT COUNT() FROM Contact WHERE Email = 'm.rebhi24292@pi.tn'];
System.debug('📊 Leads non-convertis avec cet email: ' + leadCount);
System.debug('📊 Contacts avec cet email: ' + contactCount);

// 3. Essayer la conversion manuellement avec le Lead ayoub hannechi
Lead targetLead = [SELECT Id, FirstName, LastName, Email, Score_Matching__c, IsConverted FROM Lead WHERE Id = '00Qfj00000EAf8KEAT' LIMIT 1];
System.debug('🎯 Lead cible: ' + targetLead.FirstName + ' ' + targetLead.LastName + ' | Converted=' + targetLead.IsConverted);

if (!targetLead.IsConverted) {
    // Trouver le Contact existant
    List<Contact> existingContacts = [SELECT Id, AccountId FROM Contact WHERE Email = :targetLead.Email LIMIT 1];
    System.debug('👤 Contact existant trouvé: ' + !existingContacts.isEmpty());
    
    Database.LeadConvert lc = new Database.LeadConvert();
    lc.setLeadId(targetLead.Id);
    
    if (!existingContacts.isEmpty()) {
        lc.setContactId(existingContacts[0].Id);
        lc.setAccountId(existingContacts[0].AccountId);
    }
    
    LeadStatus cs = [SELECT MasterLabel FROM LeadStatus WHERE IsConverted=true LIMIT 1];
    lc.setConvertedStatus(cs.MasterLabel);
    lc.setDoNotCreateOpportunity(true); // Ne pas créer d'opp pour éviter les conflits
    
    try {
        Database.LeadConvertResult lcr = Database.convertLead(lc);
        if (lcr.isSuccess()) {
            System.debug('✅ CONVERSION RÉUSSIE !');
        } else {
            for (Database.Error err : lcr.getErrors()) {
                System.debug('❌ Erreur: ' + err.getStatusCode() + ' | ' + err.getMessage());
            }
        }
    } catch (Exception e) {
        System.debug('❌ Exception: ' + e.getMessage());
    }
} else {
    System.debug('⚠️ Lead déjà converti');
}

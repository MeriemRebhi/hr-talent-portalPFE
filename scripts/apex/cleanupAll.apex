// ========================================
// NETTOYAGE COMPLET - REMISE À ZÉRO
// ========================================

// 1. Supprimer les ContentDocuments (CVs) - les ContentDocumentLinks sont supprimés en cascade
// On passe par les LinkedEntityIds (Leads) pour contourner la restriction SOQL sur ContentDocumentLink
List<Lead> allLeads = [SELECT Id FROM Lead];
Set<Id> leadIds = new Map<Id, Lead>(allLeads).keySet();
Set<Id> docIds = new Set<Id>();
if (!leadIds.isEmpty()) {
    for (ContentDocumentLink cdl : [SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId IN :leadIds]) {
        docIds.add(cdl.ContentDocumentId);
    }
}
// Aussi récupérer les docs liés aux Contacts et Opportunities
List<Contact> allContacts = [SELECT Id FROM Contact];
Set<Id> contactIds = new Map<Id, Contact>(allContacts).keySet();
if (!contactIds.isEmpty()) {
    for (ContentDocumentLink cdl : [SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId IN :contactIds]) {
        docIds.add(cdl.ContentDocumentId);
    }
}
// Supprimer les documents trouvés un par un (pour ignorer les asset files)
List<ContentDocument> docs = docIds.isEmpty() ? new List<ContentDocument>() : [SELECT Id FROM ContentDocument WHERE Id IN :docIds];
System.debug('CVs à supprimer: ' + docs.size());
for(ContentDocument d : docs) {
    try { delete d; } catch(Exception e) { System.debug('Skip doc ' + d.Id + ': ' + e.getMessage()); }
}

// 3. Supprimer tous les Leads (convertis et non convertis)
List<Lead> leads = [SELECT Id FROM Lead];
System.debug('Leads à supprimer: ' + leads.size());
if (!leads.isEmpty()) {
    try { delete leads; } catch(Exception e) { System.debug('Leads err: ' + e.getMessage()); }
}

// 4. Supprimer toutes les Opportunities SAUF les offres Talan
List<Opportunity> candidatures = [SELECT Id FROM Opportunity 
    WHERE Name LIKE '%Candidature%' OR Name LIKE '%Test%'
    OR Name IN ('najaai sarra - Test Candidature', 'Rebhi Meriem - Candidature Qualifiée')];
System.debug('Candidatures à supprimer: ' + candidatures.size());
if (!candidatures.isEmpty()) {
    try { delete candidatures; } catch(Exception e) { System.debug('Opps err: ' + e.getMessage()); }
}

// 5. Supprimer tous les Contacts
List<Contact> contacts = [SELECT Id FROM Contact WHERE Account.Name = 'Candidats Portal'];
System.debug('Contacts à supprimer: ' + contacts.size());
if (!contacts.isEmpty()) {
    try { delete contacts; } catch(Exception e) { System.debug('Contacts err: ' + e.getMessage()); }
}

System.debug('✅ Nettoyage terminé!');
System.debug('Leads restants: ' + [SELECT COUNT() FROM Lead]);
System.debug('Contacts restants: ' + [SELECT COUNT() FROM Contact]);
System.debug('Opportunities restantes: ' + [SELECT COUNT() FROM Opportunity]);

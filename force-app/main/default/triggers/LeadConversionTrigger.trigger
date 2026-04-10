/**
 * LeadConversionTrigger — Détecte les conversions manuelles de Lead
 * et crée le compte portail + envoie l'email de bienvenue.
 *
 * Cas couvert : l'admin convertit un lead manuellement dans Salesforce CRM
 * sans passer par le Flow/Apex automatique (qui utilise executeFullConversion).
 *
 * Guard : si CVScoringService.isProcessing == true, on est DANS executeFullConversion
 * (appelé par le Flow) → la création portail est déjà gérée → ne rien faire.
 */
trigger LeadConversionTrigger on Lead (after update) {
    // Si on est dans une conversion automatique (Flow → executeFullConversion),
    // ne pas interférer — la création portail est déjà déclenchée.
    if (CVScoringService.isProcessing) return;

    List<Lead> newlyConverted = new List<Lead>();
    for (Lead newLead : Trigger.new) {
        Lead oldLead = Trigger.oldMap.get(newLead.Id);
        if (newLead.IsConverted && !oldLead.IsConverted && newLead.ConvertedContactId != null) {
            newlyConverted.add(newLead);
        }
    }
    if (newlyConverted.isEmpty()) return;

    // Récupérer les infos du Contact converti
    Set<Id> contactIds = new Set<Id>();
    for (Lead l : newlyConverted) contactIds.add(l.ConvertedContactId);

    Map<Id, Contact> contactMap = new Map<Id, Contact>([
        SELECT Id, FirstName, LastName, Email
        FROM Contact
        WHERE Id IN :contactIds
    ]);

    for (Lead l : newlyConverted) {
        Contact c = contactMap.get(l.ConvertedContactId);
        if (c == null || String.isBlank(c.Email)) continue;

        // Vérifier si un user portail existe déjà pour cet email
        List<User> existingPortalUser = [
            SELECT Id FROM User
            WHERE Email = :c.Email
            AND UserType IN ('CspLitePortal','CustomerPortal','PowerCustomerSuccess','PowerPartner')
            LIMIT 1
        ];
        // Si pas de user portail, créer + envoyer email (idem chemin automatique)
        // Si user portail déjà existant : ne pas re-créer (il a déjà son compte)
        if (existingPortalUser.isEmpty()) {
            CVScoringService.createPortalUserAsync(c.Id, c.FirstName, c.LastName, c.Email);
        }
    }
}

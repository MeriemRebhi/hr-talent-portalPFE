public without sharing class CandidateChatController {

    public class ChatResponse {
        @AuraEnabled public String message;
        @AuraEnabled public String type;
    }

    @AuraEnabled(cacheable=false)
    public static ChatResponse chat(String userMessage, String userEmail) {
        ChatResponse resp = new ChatResponse();
        resp.type = 'bot';

        if (String.isBlank(userMessage)) {
            resp.message = 'Posez votre question (ex: statut, score IA, offres).';
            return resp;
        }

        String msg = userMessage.toLowerCase();

        try {
            // ── Salutation ───────────────────────────────────────────────────
            if (msg.contains('bonjour') || msg.contains('salut') || msg.contains('hello')
                    || msg.contains('bonsoir') || msg.contains('coucou')
                    || msg.contains('hi') || msg.contains('hey') || msg.contains('salam')) {
                resp.message = 'Bonjour ! Je suis l\'assistant RH de Talan.\n\n'
                    + 'Je peux vous aider avec :\n'
                    + '\u2022 Le statut de vos candidatures\n'
                    + '\u2022 Votre score et analyse IA\n'
                    + '\u2022 Les offres disponibles\n\n'
                    + 'Que souhaitez-vous savoir ?';
                return resp;
            }

            // ── Au revoir ────────────────────────────────────────────────────
            if (msg.contains('au revoir') || msg.contains('aurevoir') || msg.contains('bye')
                    || msg.contains('goodbye') || msg.contains('bonne journée')
                    || msg.contains('bonne soiree') || msg.contains('à bientôt')
                    || msg.contains('a bientot') || msg.contains('merci et bonne')) {
                resp.message = 'Au revoir ! Bonne continuation dans votre recherche d\'emploi.\n\n'
                    + 'N\'hésitez pas à revenir si vous avez des questions. \u2764\ufe0f\nL\'équipe RH Talan';
                return resp;
            }

            // ── Merci ────────────────────────────────────────────────────────
            if (msg.contains('merci') || msg.contains('thanks') || msg.contains('thank you')
                    || msg.contains('super') && msg.length() < 20
                    || msg.contains('parfait') && msg.length() < 20
                    || msg.contains('nickel') || msg.contains('top') && msg.length() < 10) {
                resp.message = 'Avec plaisir ! \ud83d\ude0a\n\nJe suis là si vous avez d\'autres questions.\n'
                    + 'Bonne continuation !';
                return resp;
            }

            // ── Qui es-tu / aide ─────────────────────────────────────────────
            if (msg.contains('qui es-tu') || msg.contains('qui es tu') || msg.contains('qui êtes-vous')
                    || msg.contains('aide') || msg.contains('help') || msg.contains('que sais-tu')
                    || msg.contains('que peux-tu') || msg.contains('comment') && msg.contains('aider')) {
                resp.message = 'Je suis l\'assistant virtuel RH de Talan.\n\n'
                    + 'Je peux répondre à vos questions sur :\n\n'
                    + '\u2022 "Statut de mes candidatures" — voir vos dossiers\n'
                    + '\u2022 "Mon score IA" — analyse de votre CV\n'
                    + '\u2022 "Offres disponibles" — les postes ouverts\n\n'
                    + 'Posez votre question !';
                return resp;
            }

            // ── Offres disponibles ───────────────────────────────────────────
            if (msg.contains('offre') || msg.contains('poste') || msg.contains('job')
                    || msg.contains('emploi') || msg.contains('recrutement')) {
                List<Opportunity> offres = [
                    SELECT Name, Localisation__c, Type_de_Contrat__c, CloseDate, Departement__c
                    FROM Opportunity
                    WHERE RecordType.DeveloperName = 'Job_Posting'
                    AND (Is_Candidature__c = false OR Is_Candidature__c = null)
                    AND IsClosed = false
                    ORDER BY CloseDate ASC NULLS LAST LIMIT 10
                ];
                if (offres.isEmpty()) {
                    resp.message = 'Aucune offre disponible pour le moment.';
                } else {
                    String txt = offres.size() + ' offre(s) disponible(s) :\n\n';
                    Integer n = 1;
                    for (Opportunity o : offres) {
                        txt += n + '. ' + o.Name + '\n';
                        if (o.Departement__c != null)     txt += '   \ud83c\udfe2 ' + o.Departement__c + '\n';
                        if (o.Localisation__c != null)    txt += '   \ud83d\udccd ' + o.Localisation__c + '\n';
                        if (o.Type_de_Contrat__c != null) txt += '   \ud83d\udcbc ' + o.Type_de_Contrat__c + '\n';
                        if (o.CloseDate != null) {
                            txt += '   \ud83d\udcc5 Date limite : '
                                + String.valueOf(o.CloseDate.day()).leftPad(2, '0') + '/'
                                + String.valueOf(o.CloseDate.month()).leftPad(2, '0') + '/'
                                + o.CloseDate.year() + '\n';
                        }
                        txt += '\n';
                        n++;
                    }
                    resp.message = txt.trim();
                }
                return resp;
            }

            // ── Analyse IA / Score ───────────────────────────────────────────
            if (msg.contains('score') || msg.contains('analyse') || msg.contains(' ia')
                    || msg.contains('cv') || msg.contains('point') || msg.contains('recommand')) {
                if (String.isBlank(userEmail)) {
                    resp.message = 'Votre email n\'est pas disponible. Reconnectez-vous pour voir votre analyse IA.';
                    return resp;
                }
                List<Lead> leads = [
                    SELECT Score_Matching__c, AI_Recommendation__c, AI_Points_Forts__c, AI_Points_Faibles__c
                    FROM Lead
                    WHERE Email = :userEmail AND LeadSource = 'Talent Portal' AND Score_Matching__c != null
                    ORDER BY Score_Matching__c DESC LIMIT 1
                ];
                if (leads.isEmpty()) {
                    resp.message = 'Votre CV n\'a pas encore été analysé. Uploadez votre CV depuis le tableau de bord.';
                } else {
                    Lead l = leads[0];
                    resp.message = 'Votre score IA : ' + l.Score_Matching__c.intValue() + '%\n\n'
                        + 'Points forts :\n' + (l.AI_Points_Forts__c != null ? l.AI_Points_Forts__c : 'Non disponible') + '\n\n'
                        + 'Points à améliorer :\n' + (l.AI_Points_Faibles__c != null ? l.AI_Points_Faibles__c : 'Non disponible') + '\n\n'
                        + 'Recommandation :\n' + (l.AI_Recommendation__c != null ? l.AI_Recommendation__c : 'Non disponible');
                }
                return resp;
            }

            // ── Statut candidatures ──────────────────────────────────────────
            if (msg.contains('statut') || msg.contains('candidature') || msg.contains('dossier')
                    || msg.contains('suivi') || msg.contains('etat') || msg.contains('\u00e9tat')) {
                if (String.isBlank(userEmail)) {
                    resp.message = 'Votre email n\'est pas disponible. Reconnectez-vous pour voir vos candidatures.';
                    return resp;
                }
                List<Lead> leads = [
                    SELECT Status, Score_Matching__c, Company, CreatedDate, IsConverted
                    FROM Lead
                    WHERE Email = :userEmail AND LeadSource = 'Talent Portal'
                    ORDER BY CreatedDate DESC LIMIT 5
                ];
                if (leads.isEmpty()) {
                    resp.message = 'Aucune candidature trouvée pour votre compte.';
                } else {
                    String txt = leads.size() + ' candidature(s) :\n\n';
                    Integer idx = 1;
                    Decimal maxScore = 0;
                    for (Lead l : leads) {
                        Decimal sc = l.Score_Matching__c != null ? l.Score_Matching__c : 0;
                        if (sc > maxScore) maxScore = sc;
                        String statut = l.IsConverted ? 'Profil validé' :
                            (l.Status != null ? l.Status : 'En cours');
                        txt += idx + '. ' + (l.Company != null ? l.Company : 'Non précisé')
                            + ' | ' + statut + ' | Score: ' + sc.intValue() + '%\n';
                        idx++;
                    }
                    if (maxScore > 0) txt += '\nMeilleur score : ' + maxScore.intValue() + '%';
                    resp.message = txt;
                }
                return resp;
            }

            // ── Aide par défaut ──────────────────────────────────────────────
            resp.message = 'Je peux vous renseigner sur :\n\n'
                + '\u2022 "Statut de mes candidatures"\n'
                + '\u2022 "Mon score IA"\n'
                + '\u2022 "Offres disponibles"\n\n'
                + 'Tapez votre question !';

        } catch (Exception e) {
            resp.type = 'error';
            resp.message = 'Erreur : ' + e.getMessage();
        }

        return resp;
    }
}

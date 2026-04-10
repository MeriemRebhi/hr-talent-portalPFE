/**
 * CVScoringService - HR Talent Portal - Talan Tunisie PFE 2025
 * Sans Platform Event — Queueable without sharing suffit
 * Flux: Upload CV → Groq Score → Conversion Lead → User portail → Email
 */
public without sharing class CVScoringService {

    private static final Decimal QUALIFICATION_THRESHOLD = 15;
    private static final String  SITE_URL      = 'https://orgfarm-3ed211f8bb-dev-ed.develop.my.site.com/home2/s/loginp';
    private static final String  GROQ_ENDPOINT = 'https://api.groq.com/openai/v1/chat/completions';
    private static final String  GROQ_MODEL    = 'llama-3.3-70b-versatile';
    private static final Integer MAX_TEXT_LENGTH = 3000;

    public class CVScoringException extends Exception {}

    // Garde anti-récursion trigger CDL
    public static Boolean isProcessing = false;
    // Garde anti-doublon scoring (évite 2 Queueables pour le même Lead)
    private static Set<String> processedLeadIds = new Set<String>();

    // ═══════════════════════════════════════════════════
    // POINTS D'ENTRÉE
    // ═══════════════════════════════════════════════════

    /** Appelé par le trigger CVScoringTrigger (Set<String>) */
    public static void scoreCVForLeads(Set<String> leadIds) {
        if (leadIds == null || leadIds.isEmpty()) return;

        List<Lead> toUpdate = [
            SELECT Id, Status, OwnerId, Owner.IsActive
            FROM Lead WHERE Id IN :leadIds AND IsConverted = false
            AND Status != 'Condidature - IA Parsing CV'
            AND Status != 'Condidature - Validée- Email Envoyé'
        ];
        if (toUpdate.isEmpty()) {
            System.debug('ℹ️ Tous les leads déjà en cours de traitement ou validés — skip');
            return;
        }
        for (Lead l : toUpdate) {
            l.Status = 'Condidature - IA Parsing CV';
            if (!l.Owner.IsActive) l.OwnerId = UserInfo.getUserId();
        }
        update toUpdate;

        System.enqueueJob(new CVScoringQueue(new List<String>(leadIds)));
    }

    /** Pour tests via Execute Anonymous */
    public static void scoreCVForLeadNow(Id leadId) {
        Lead l = [SELECT Id, Status, OwnerId, Owner.IsActive, IsConverted FROM Lead WHERE Id = :leadId LIMIT 1];
        if (!l.IsConverted) {
            l.Status = 'Condidature - IA Parsing CV';
            if (!l.Owner.IsActive) l.OwnerId = UserInfo.getUserId();
            update l;
        }
        // Le callout Groq ne peut pas suivre un DML dans la même transaction.
        // On utilise le même Queueable que le trigger (transaction séparée).
        System.enqueueJob(new CVScoringQueue(new List<String>{ String.valueOf(leadId) }));
    }

    private class CVScoringQueue implements Queueable, Database.AllowsCallouts {
        private List<String> ids;
        public CVScoringQueue(List<String> ids) { this.ids = ids; }
        public void execute(QueueableContext ctx) {
            for (String id : ids) { runProcessing(id); }
        }
    }

    // ═══════════════════════════════════════════════════
    // TRAITEMENT PRINCIPAL
    // ═══════════════════════════════════════════════════

    private static void runProcessing(Id leadId) {
        // Éviter le double traitement si 2 Queueables ont été enqueue pour le même Lead
        if (processedLeadIds.contains(String.valueOf(leadId))) {
            System.debug('⚠️ Lead déjà traité dans cette transaction: ' + leadId);
            return;
        }
        processedLeadIds.add(String.valueOf(leadId));

        try {
            Lead lead = [
                SELECT Id, FirstName, LastName, Email, Description,
                       IsConverted, Status, OwnerId, Owner.IsActive
                FROM Lead WHERE Id = :leadId LIMIT 1
            ];
            if (lead.IsConverted) return;

            System.debug('🔄 Analyse IA en cours pour: ' + lead.Email);

            String cvText      = extractCVText(leadId);
            String profileText = extractProfileText(lead.Description);
            String jobDesc     = getJobDescription(lead.Description);

            Decimal score = 0;
            String recommendation = '';
            String pointsForts    = '';
            String pointsFaibles  = '';

            try {
                Map<String, Object> aiResult = callGroqAPI(cvText, profileText, jobDesc);
                Object scoreObj = aiResult.get('score');
                score = scoreObj instanceof Decimal
                    ? (Decimal) scoreObj
                    : Decimal.valueOf(String.valueOf(scoreObj));
                score          = Math.max(0, Math.min(100, score));
                recommendation = String.valueOf(aiResult.get('recommendation'));
                pointsForts    = String.valueOf(aiResult.get('points_forts'));
                pointsFaibles  = String.valueOf(aiResult.get('points_faibles'));
                System.debug('🤖 Score Groq: ' + score + '% pour ' + lead.Email);
            } catch (Exception aiEx) {
                System.debug('⚠️ Erreur Groq: ' + aiEx.getMessage());
                recommendation = 'Erreur analyse IA: ' + aiEx.getMessage();
            }

            lead.Score_Matching__c    = score;
            lead.AI_Recommendation__c = recommendation;
            lead.AI_Points_Forts__c   = pointsForts;
            lead.AI_Points_Faibles__c = pointsFaibles;
            lead.Rating = score >= 80 ? 'Hot' : (score > QUALIFICATION_THRESHOLD ? 'Warm' : 'Cold');

            if (score > QUALIFICATION_THRESHOLD) {
                lead.Status = 'Condidature - Validée- Email Envoyé';
                update lead;
                // Appel direct @future — conversion dans une transaction séparée
                convertLeadsAsync(new List<String>{ String.valueOf(lead.Id) });
                System.debug('✅ Score ' + score + '% → Conversion lancée via @future');
            } else {
                lead.Status = 'Condidature Réfusé';
                update lead;
                System.debug('❌ Score ' + score + '% → Refusé');
            }

        } catch (Exception e) {
            System.debug('❌ runProcessing: ' + e.getMessage() + '\n' + e.getStackTraceString());
            // Remettre le lead dans un état stable pour éviter qu'il reste bloqué
            try {
                Lead errLead = [SELECT Id, Status FROM Lead WHERE Id = :leadId AND IsConverted = false LIMIT 1];
                if (errLead != null && errLead.Status == 'Condidature - IA Parsing CV') {
                    errLead.Score_Matching__c    = 0;
                    errLead.AI_Recommendation__c = 'Erreur traitement IA : ' + e.getMessage().left(255);
                    errLead.Status = 'Condidature Réfusé';
                    update errLead;
                }
            } catch (Exception fallbackEx) {
                System.debug('❌ runProcessing fallback update: ' + fallbackEx.getMessage());
            }
        }
    }

    // ═══════════════════════════════════════════════════
    // CONVERSION LEAD → CONTACT + ACCOUNT + OPPORTUNITY
    // ═══════════════════════════════════════════════════

    /** Appelé par le Record-Triggered Flow (contexte système)
     *  Exécution synchrone — pas de Queueable ici car le Flow est déclenché
     *  dans la même transaction que le Queueable de scoring (callout Groq déjà fait),
     *  et System.enqueueJob() est interdit après un callout dans la même transaction.
     */
    @InvocableMethod(label='Convertir Lead Candidat' description='Convertit un Lead qualifié en Contact + Opportunity')
    public static void convertLeads(List<Id> leadIds) {
        if (leadIds == null || leadIds.isEmpty()) return;
        // Déléguer à @future pour exécuter dans une transaction séparée
        // (Database.convertLead échoue dans le contexte after-save du Flow)
        List<String> stringIds = new List<String>();
        for (Id lid : leadIds) stringIds.add(String.valueOf(lid));
        convertLeadsAsync(stringIds);
    }

    @future
    public static void convertLeadsAsync(List<String> leadIds) {
        for (String leadId : leadIds) {
            List<Lead> leads = [SELECT Id, Score_Matching__c FROM Lead WHERE Id = :leadId AND IsConverted = false LIMIT 1];
            if (!leads.isEmpty()) {
                Decimal score = leads[0].Score_Matching__c != null ? leads[0].Score_Matching__c : 0;
                executeFullConversion(leadId, score);
            }
        }
    }

    public static void executeFullConversion(String leadId, Decimal score) {
        isProcessing = true;
        try {
            Lead lead = [
                SELECT Id, FirstName, LastName, Email, IsConverted,
                       Phone, Company, AI_Recommendation__c, AI_Points_Forts__c
                FROM Lead WHERE Id = :leadId LIMIT 1
            ];
            if (lead.IsConverted) {
                System.debug('⚠️ Lead déjà converti: ' + leadId);
                return;
            }

            Database.LeadConvert lc = new Database.LeadConvert();
            lc.setLeadId(lead.Id);

            List<Contact> existingContacts = [
                SELECT Id, AccountId FROM Contact WHERE Email = :lead.Email LIMIT 1
            ];
            if (!existingContacts.isEmpty()) {
                lc.setContactId(existingContacts[0].Id);
                lc.setAccountId(existingContacts[0].AccountId);
                System.debug('🔗 Contact existant: ' + existingContacts[0].Id);
            } else {
                Account acc = new Account(Name = lead.Email);
                Database.DMLOptions opts = new Database.DMLOptions();
                opts.DuplicateRuleHeader.allowSave = true;
                Database.insert(acc, opts);
                lc.setAccountId(acc.Id);
            }

            LeadStatus convertStatus = [
                SELECT MasterLabel FROM LeadStatus WHERE IsConverted = true LIMIT 1
            ];
            lc.setConvertedStatus(convertStatus.MasterLabel);
            lc.setOpportunityName(lead.LastName + ' - Candidature (' + score.intValue() + '%)');
            lc.setDoNotCreateOpportunity(false);

            Database.LeadConvertResult lcr = Database.convertLead(lc);

            if (!lcr.isSuccess()) {
                String errors = '';
                for (Database.Error err : lcr.getErrors()) {
                    errors += '[' + err.getStatusCode() + '] ' + err.getMessage() + ' | ';
                }
                System.debug('❌ Conversion échouée: ' + errors);
                return;
            }

            Id contactId = lcr.getContactId();
            Id oppId     = lcr.getOpportunityId();
            System.debug('✅ Conversion OK → Contact: ' + contactId + ' | Opp: ' + oppId);

            if (oppId != null) {
                Id appRtId = getRecordTypeId('Opportunity', 'Application');
                Opportunity opp = new Opportunity(
                    Id                = oppId,
                    StageName         = 'Gaming',
                    Score_Matching__c = score,
                    Is_Candidature__c = true,
                    Description       = lead.Email + ' — Score IA: ' + score.intValue() + '%'
                );
                if (appRtId != null) opp.RecordTypeId = appRtId;
                try {
                    update opp;
                } catch (Exception oppEx) {
                    System.debug('⚠️ Update Opp (sans RecordType): ' + oppEx.getMessage());
                    try {
                        update new Opportunity(Id = oppId, Score_Matching__c = score, Is_Candidature__c = true);
                    } catch (Exception fb) {
                        System.debug('⚠️ Fallback Opp: ' + fb.getMessage());
                    }
                }
            }

            if (contactId != null) {
                if (System.isFuture()) {
                    // Déjà dans un contexte @future → appel synchrone
                    createPortalUser(contactId, lead.FirstName, lead.LastName, lead.Email);
                } else {
                    createPortalUserAsync(contactId, lead.FirstName, lead.LastName, lead.Email);
                }
            }

            // Notifier l'admin RH
            if (System.isFuture()) {
                sendAdminNotificationEmail(
                    lead.FirstName, lead.LastName, lead.Email,
                    lead.Phone, lead.Company,
                    lead.AI_Recommendation__c, lead.AI_Points_Forts__c,
                    score
                );
            } else {
                sendAdminEmailAsync(
                    lead.FirstName, lead.LastName, lead.Email,
                    lead.Phone, lead.Company,
                    lead.AI_Recommendation__c, lead.AI_Points_Forts__c,
                    score
                );
            }

        } catch (Exception e) {
            System.debug('❌ executeFullConversion: ' + e.getMessage() + '\n' + e.getStackTraceString());
        } finally {
            isProcessing = false;
        }
    }

    // ═══════════════════════════════════════════════════
    // EMAIL NOTIFICATION ADMIN RH
    // ═══════════════════════════════════════════════════

    @future
    private static void sendAdminEmailAsync(
        String firstName, String lastName, String email,
        String phone, String company, String reco, String forts, Decimal score
    ) {
        sendAdminNotificationEmail(firstName, lastName, email, phone, company, reco, forts, score);
    }

    private static void sendAdminNotificationEmail(
        String firstName, String lastName, String email,
        String phone, String company, String reco, String forts, Decimal score
    ) {
        try {
            String adminEmail = 'meriem.rebhi.d6f3e18c6a1f@agentforce.com';
            String prenom     = firstName != null ? firstName : '';
            String nom        = lastName  != null ? lastName  : '';
            String tel        = phone     != null ? phone     : '—';
            String poste      = company   != null ? company   : '—';
            String reco2      = reco      != null ? reco      : '—';
            String forts2     = forts     != null ? forts     : '—';
            String scoreStr   = score.intValue() + ' %';
            String scoreColor = score >= 80 ? '#15803d' : (score >= 50 ? '#b45309' : '#2F7D59');
            String now        = DateTime.now().format('dd/MM/yyyy HH:mm', 'Africa/Tunis');

            String html =
                '<div style="font-family:Segoe UI,Arial,sans-serif;max-width:640px;margin:auto;">'
                + '<div style="background:linear-gradient(135deg,#0f172a,#1e293b);padding:28px 32px;border-radius:12px 12px 0 0;text-align:center;">'
                + '<h1 style="color:#f8fafc;margin:0;font-size:22px;letter-spacing:-0.5px;">talan<span style="color:#34d399;">.</span></h1>'
                + '<p style="color:#94a3b8;margin:6px 0 0;font-size:13px;">Portail RH — Notification de conversion</p>'
                + '</div>'
                + '<div style="background:#fff;padding:28px 32px;border:1px solid #e2e8f0;border-radius:0 0 12px 12px;">'
                + '<p style="font-size:15px;color:#1e293b;">Bonjour,</p>'
                + '<p style="font-size:14px;color:#475569;margin-bottom:20px;">Un nouveau candidat vient d&apos;être <strong style="color:#15803d;">converti automatiquement</strong> par le système IA.</p>'
                // Score badge
                + '<div style="text-align:center;margin:0 0 24px;">'
                + '<span style="background:' + scoreColor + ';color:#fff;font-size:28px;font-weight:900;padding:12px 32px;border-radius:50px;letter-spacing:-0.5px;">'
                + '&#9733; ' + scoreStr + ' IA</span>'
                + '</div>'
                // Fiche candidat
                + '<table style="width:100%;border-collapse:collapse;margin-bottom:20px;">'
                + '<tr style="background:#f8fafc;"><td colspan="2" style="padding:10px 14px;font-weight:700;font-size:12px;color:#64748b;letter-spacing:1px;">FICHE CANDIDAT</td></tr>'
                + '<tr><td style="padding:9px 14px;color:#64748b;width:140px;border-bottom:1px solid #f1f5f9;">Nom complet</td><td style="padding:9px 14px;font-weight:600;color:#0f172a;border-bottom:1px solid #f1f5f9;">' + prenom + ' ' + nom + '</td></tr>'
                + '<tr><td style="padding:9px 14px;color:#64748b;border-bottom:1px solid #f1f5f9;">Email</td><td style="padding:9px 14px;font-weight:600;color:#0f172a;border-bottom:1px solid #f1f5f9;">' + email + '</td></tr>'
                + '<tr><td style="padding:9px 14px;color:#64748b;border-bottom:1px solid #f1f5f9;">Téléphone</td><td style="padding:9px 14px;color:#334155;border-bottom:1px solid #f1f5f9;">' + tel + '</td></tr>'
                + '<tr><td style="padding:9px 14px;color:#64748b;border-bottom:1px solid #f1f5f9;">Poste ciblé</td><td style="padding:9px 14px;color:#334155;border-bottom:1px solid #f1f5f9;">' + poste + '</td></tr>'
                + '<tr><td style="padding:9px 14px;color:#64748b;border-bottom:1px solid #f1f5f9;">Score IA</td><td style="padding:9px 14px;font-weight:700;color:' + scoreColor + ';border-bottom:1px solid #f1f5f9;">' + scoreStr + '</td></tr>'
                + '<tr><td style="padding:9px 14px;color:#64748b;">Recommandation</td><td style="padding:9px 14px;color:#334155;font-style:italic;">' + reco2 + '</td></tr>'
                + '</table>'
                // Points forts
                + '<div style="background:#f0fdf4;border-left:4px solid #22c55e;padding:12px 16px;border-radius:6px;margin-bottom:20px;">'
                + '<p style="margin:0;font-size:12px;font-weight:700;color:#15803d;margin-bottom:4px;">&#9733; POINTS FORTS IA</p>'
                + '<p style="margin:0;font-size:13px;color:#166534;">' + forts2 + '</p>'
                + '</div>'
                // Actions réalisées
                + '<div style="background:#f8fafc;border-radius:8px;padding:14px 18px;margin-bottom:22px;">'
                + '<p style="margin:0 0 8px;font-size:12px;font-weight:700;color:#64748b;letter-spacing:1px;">ACTIONS RÉALISÉES AUTOMATIQUEMENT</p>'
                + '<p style="margin:3px 0;font-size:13px;color:#334155;">&#10003; Lead converti en Contact + Account + Opportunity</p>'
                + '<p style="margin:3px 0;font-size:13px;color:#334155;">&#10003; Email de bienvenue envoyé au candidat</p>'
                + '<p style="margin:3px 0;font-size:13px;color:#334155;">&#10003; Compte portail Experience Cloud créé</p>'
                + '</div>'
                + '<p style="font-size:12px;color:#94a3b8;text-align:center;border-top:1px solid #f1f5f9;padding-top:14px;margin:0;">'
                + 'Conversion automatique le ' + now + ' — HR Talent Portal Talan Tunisie</p>'
                + '</div></div>';

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new List<String>{ adminEmail });
            mail.setSubject('✅ Candidat converti : ' + prenom + ' ' + nom + ' | Score IA : ' + scoreStr);
            mail.setHtmlBody(html);
            mail.setSaveAsActivity(false);
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
            System.debug('✅ Email admin envoyé pour: ' + prenom + ' ' + nom);
        } catch (Exception e) {
            System.debug('⚠️ sendAdminNotificationEmail: ' + e.getMessage());
        }
    }

    // ═══════════════════════════════════════════════════
    // USER PORTAIL (@future)
    // ═══════════════════════════════════════════════════

    @future
    public static void createPortalUserAsync(Id contactId, String firstName, String lastName, String email) {
        createPortalUser(contactId, firstName, lastName, email);
    }

    public static void createPortalUser(Id contactId, String firstName, String lastName, String email) {
        try {
            List<User> existing = [
                SELECT Id, IsActive, ContactId, Username
                FROM User
                WHERE (Email = :email OR ContactId = :contactId)
                AND UserType IN ('CspLitePortal','CustomerPortal','PowerCustomerSuccess','PowerPartner')
                LIMIT 1
            ];

            if (!existing.isEmpty()) {
                User u = existing[0];
                System.debug('ℹ️ User existant: ' + u.Id + ' | Active: ' + u.IsActive);
                Boolean needsUpdate = false;
                if (!u.IsActive) { u.IsActive = true; needsUpdate = true; }
                if (u.ContactId != contactId) { u.ContactId = contactId; needsUpdate = true; }
                if (needsUpdate) { update u; }
                // Générer un token sécurisé (hashé SHA-256, expiration 24h, usage unique)
                String token = PasswordResetController.generateResetToken(u.Id, email);
                String resetUrl = PasswordResetController.buildResetUrl(token);
                sendWelcomeEmail(email, firstName, resetUrl, true);
                return;
            }

            List<User> internal = [SELECT Id FROM User WHERE Email = :email AND UserType = 'Standard' LIMIT 1];
            if (!internal.isEmpty()) {
                System.debug('⚠️ User interne existant avec cet email');
                return;
            }

            List<Profile> profiles = [
                SELECT Id FROM Profile WHERE Name = 'Customer Community Login User' LIMIT 1
            ];
            if (profiles.isEmpty()) {
                profiles = [SELECT Id FROM Profile WHERE Name = 'Customer Community User' LIMIT 1];
            }
            if (profiles.isEmpty()) {
                System.debug('❌ Aucun profil Community trouvé');
                return;
            }

            String suffix   = String.valueOf(DateTime.now().getTime());
            String alias    = (firstName != null && firstName.length() > 0)
                ? (firstName.substring(0, 1) + (lastName != null ? lastName : '')).left(8).toLowerCase()
                : 'cand';
            String nickname = (firstName != null ? firstName : 'cand') +
                              (lastName  != null ? lastName  : '') + suffix;
            if (nickname.length() > 40) nickname = nickname.substring(0, 40);

            User u = new User(
                ContactId         = contactId,
                ProfileId         = profiles[0].Id,
                FirstName         = firstName,
                LastName          = lastName != null ? lastName : 'Candidat',
                Email             = email,
                Username          = email + '.' + suffix,
                Alias             = alias,
                CommunityNickname = nickname,
                TimeZoneSidKey    = 'Africa/Tunis',
                LocaleSidKey      = 'fr_FR',
                EmailEncodingKey  = 'UTF-8',
                LanguageLocaleKey = 'fr',
                IsActive          = true
            );
            insert u;
            System.debug('✅ User portail créé: ' + u.Username);

            // Générer un token sécurisé (hashé SHA-256, expiration 24h, usage unique)
            String token = PasswordResetController.generateResetToken(u.Id, email);
            String resetUrl = PasswordResetController.buildResetUrl(token);
            // Audit log de la création du compte
            PasswordResetController.logAudit('ACCOUNT_CREATED', email, 'INFO',
                'Compte portail créé. Username: ' + u.Username);
            sendWelcomeEmail(email, firstName, resetUrl, false);

        } catch (Exception e) {
            System.debug('⚠️ createPortalUserAsync: ' + e.getMessage() + '\n' + e.getStackTraceString());
        }
    }

    // ═══════════════════════════════════════════════════
    // GÉNÉRATEUR MOT DE PASSE SÉCURISÉ
    // ═══════════════════════════════════════════════════

    /**
     * Génère un mot de passe aléatoire qui satisfait les règles Salesforce :
     * 8+ chars, au moins 1 majuscule, 1 minuscule, 1 chiffre, 1 spécial.
     * Utilise System.setPassword() → pas de "force change" → Site.login() fonctionne.
     */
    private static String generateSecurePassword() {
        final String UPPER   = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
        final String LOWER   = 'abcdefghjkmnpqrstuvwxyz';
        final String DIGITS  = '23456789';
        final String SPECIAL = '!@#$%&*';
        final String ALL     = UPPER + LOWER + DIGITS + SPECIAL;

        // 1 caractère garanti de chaque type
        String pwd = '';
        pwd += UPPER.substring(  Math.mod(Math.abs(Crypto.getRandomInteger()), UPPER.length()),   Math.mod(Math.abs(Crypto.getRandomInteger()), UPPER.length())   + 1);
        pwd += LOWER.substring(  Math.mod(Math.abs(Crypto.getRandomInteger()), LOWER.length()),   Math.mod(Math.abs(Crypto.getRandomInteger()), LOWER.length())   + 1);
        pwd += DIGITS.substring( Math.mod(Math.abs(Crypto.getRandomInteger()), DIGITS.length()),  Math.mod(Math.abs(Crypto.getRandomInteger()), DIGITS.length())  + 1);
        pwd += SPECIAL.substring(Math.mod(Math.abs(Crypto.getRandomInteger()), SPECIAL.length()), Math.mod(Math.abs(Crypto.getRandomInteger()), SPECIAL.length()) + 1);
        // 4 caractères supplémentaires aléatoires
        for (Integer i = 0; i < 4; i++) {
            Integer idx = Math.mod(Math.abs(Crypto.getRandomInteger()), ALL.length());
            pwd += ALL.substring(idx, idx + 1);
        }
        // Mélanger les caractères via tri sur un vecteur aléatoire
        List<String> chars = new List<String>();
        for (Integer i = 0; i < pwd.length(); i++) chars.add(pwd.substring(i, i + 1));
        List<String> shuffled = new List<String>();
        while (!chars.isEmpty()) {
            Integer pick = Math.mod(Math.abs(Crypto.getRandomInteger()), chars.size());
            shuffled.add(chars.remove(pick));
        }
        return String.join(shuffled, '');
    }

    // ═══════════════════════════════════════════════════
    // EMAIL DE BIENVENUE
    // ═══════════════════════════════════════════════════

    private static void sendWelcomeEmail(String toEmail, String firstName, String resetUrl, Boolean isExisting) {
        try {
            String greeting = isExisting
                ? 'Votre nouvelle candidature a été <strong style="color:#2F7D59;">validée par notre IA</strong> !'
                : 'Félicitations ! Votre candidature a été <strong style="color:#2F7D59;">analysée et validée</strong>.';

            String html =
                '<div style="font-family:Segoe UI,Arial,sans-serif;max-width:600px;margin:auto;">'
                + '<div style="background:linear-gradient(135deg,#2F7D59,#1a4d2e);padding:30px;text-align:center;border-radius:12px 12px 0 0;">'
                + '<h1 style="color:#fff;margin:0;font-size:24px;">Portail RH Talan</h1>'
                + '<p style="color:rgba(255,255,255,.8);margin:8px 0 0;font-size:14px;">Votre espace candidat</p>'
                + '</div>'
                + '<div style="background:#fff;padding:30px;border:1px solid #e0e0e0;border-radius:0 0 12px 12px;">'
                + '<p style="font-size:16px;">Bonjour <strong>' + (firstName != null ? firstName : '') + '</strong>,</p>'
                + '<p>' + greeting + '</p>'
                + '<p style="font-size:14px;color:#444;">Votre compte sur le Portail RH Talan a été créé. Pour activer votre accès, veuillez définir votre mot de passe en cliquant sur le bouton ci-dessous :</p>'
                + '<p style="text-align:center;margin:30px 0;">'
                + '<a href="' + resetUrl + '" style="background:#2F7D59;color:#fff;padding:16px 48px;border-radius:8px;text-decoration:none;font-weight:bold;font-size:16px;display:inline-block;">Définir mon mot de passe &#8594;</a>'
                + '</p>'
                + '<div style="background:#f5f9f7;padding:16px 20px;border-radius:8px;border-left:4px solid #2F7D59;margin:20px 0;">'
                + '<p style="margin:0;font-size:13px;color:#334155;"><strong>&#128274; Sécurité :</strong></p>'
                + '<ul style="margin:8px 0 0;padding-left:20px;font-size:13px;color:#475569;">'
                + '<li>Ce lien est <strong>à usage unique</strong> et expire dans <strong>24 heures</strong></li>'
                + '<li>Votre mot de passe doit contenir au moins 8 caractères avec majuscule, minuscule, chiffre et caractère spécial</li>'
                + '<li>Ne partagez jamais ce lien avec une autre personne</li>'
                + '</ul></div>'
                + '<p style="background:#fff8e1;border-left:4px solid #f59e0b;padding:12px 16px;border-radius:6px;font-size:13px;color:#78350f;">'
                + '&#9888; Si vous n\'avez pas fait de candidature sur le Portail RH Talan, ignorez cet email.</p>'
                + '<p style="color:#999;font-size:12px;text-align:center;border-top:1px solid #eee;padding-top:15px;">'
                + 'Cet email est envoyé automatiquement par le syst&egrave;me de recrutement Talan. Ne répondez pas à ce message.</p>'
                + '</div></div>';

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new List<String>{ toEmail });
            mail.setSubject('Portail RH Talan — Définissez votre mot de passe');
            mail.setHtmlBody(html);
            mail.setSaveAsActivity(false);
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
            System.debug('✅ Email bienvenue (lien sécurisé) envoyé à: ' + toEmail);

        } catch (Exception e) {
            System.debug('⚠️ sendWelcomeEmail: ' + e.getMessage());
        }
    }

    // ═══════════════════════════════════════════════════
    // EXTRACTION TEXTE CV
    // ═══════════════════════════════════════════════════

    private static String extractCVText(Id leadId) {
        List<ContentDocumentLink> cdls = [
            SELECT ContentDocumentId FROM ContentDocumentLink
            WHERE LinkedEntityId = :leadId
            ORDER BY SystemModstamp DESC LIMIT 1
        ];
        if (cdls.isEmpty()) return null;

        List<ContentVersion> cvs = [
            SELECT VersionData, FileExtension, TextPreview
            FROM ContentVersion
            WHERE ContentDocumentId = :cdls[0].ContentDocumentId
            AND IsLatest = true LIMIT 1
        ];
        if (cvs.isEmpty()) return null;

        if (!String.isBlank(cvs[0].TextPreview)) {
            return cvs[0].TextPreview.length() > MAX_TEXT_LENGTH
                ? cvs[0].TextPreview.substring(0, MAX_TEXT_LENGTH)
                : cvs[0].TextPreview;
        }

        String ext = cvs[0].FileExtension != null ? cvs[0].FileExtension.toLowerCase() : '';
        if (ext == 'txt' || ext == 'csv') {
            try {
                String text = cvs[0].VersionData.toString();
                return text.length() > MAX_TEXT_LENGTH ? text.substring(0, MAX_TEXT_LENGTH) : text;
            } catch (Exception e) {
                System.debug('⚠️ extractCVText: ' + e.getMessage());
            }
        }
        return null;
    }

    private static String extractProfileText(String description) {
        if (String.isBlank(description)) return null;
        Integer idx = description.indexOf('PROFILE_TEXT:');
        if (idx < 0) return null;
        String text = description.substring(idx + 13).trim();
        return text.length() > MAX_TEXT_LENGTH ? text.substring(0, MAX_TEXT_LENGTH) : text;
    }

    private static String getJobDescription(String description) {
        if (String.isBlank(description)) return null;
        String jobId = null;
        for (String line : description.split('\n')) {
            if (line.startsWith('JOB_ID:')) {
                jobId = line.replace('JOB_ID:', '').trim();
                break;
            }
        }
        if (String.isBlank(jobId)) return null;
        try {
            List<Opportunity> jobs = [
                SELECT Name, Description_Poste__c, Departement__c,
                       Localisation__c, Type_de_Contrat__c
                FROM Opportunity WHERE Id = :jobId LIMIT 1
            ];
            if (jobs.isEmpty()) return null;
            List<String> parts = new List<String>();
            parts.add('Poste: ' + jobs[0].Name);
            if (jobs[0].Description_Poste__c != null) parts.add('Description: ' + jobs[0].Description_Poste__c);
            if (jobs[0].Departement__c       != null) parts.add('Département: ' + jobs[0].Departement__c);
            if (jobs[0].Localisation__c      != null) parts.add('Localisation: ' + jobs[0].Localisation__c);
            if (jobs[0].Type_de_Contrat__c   != null) parts.add('Contrat: '      + jobs[0].Type_de_Contrat__c);
            return String.join(parts, '\n');
        } catch (Exception e) {
            System.debug('⚠️ getJobDescription: ' + e.getMessage());
            return null;
        }
    }

    // ═══════════════════════════════════════════════════
    // APPEL GROQ API
    // ═══════════════════════════════════════════════════

    private static Map<String, Object> callGroqAPI(String cvText, String profileText, String jobDesc) {
        List<AI_Configuration__c> configs = [SELECT Groq_API_Key__c FROM AI_Configuration__c LIMIT 1];
        if (configs.isEmpty() || String.isBlank(configs[0].Groq_API_Key__c)) {
            throw new CVScoringException('Clé API Groq non configurée');
        }
        String apiKey = configs[0].Groq_API_Key__c;

        String candidateInfo = '';
        if (!String.isBlank(cvText))      candidateInfo += 'CV:\n' + cvText + '\n\n';
        if (!String.isBlank(profileText)) candidateInfo += 'Profil candidat:\n' + profileText + '\n\n';
        if (String.isBlank(candidateInfo)) candidateInfo = 'Aucune information candidat disponible.';

        String jobInfo = !String.isBlank(jobDesc) ? jobDesc : 'Aucune description de poste disponible.';

        String systemPrompt =
            'Tu es un expert RH pour Talan Tunisie (ESN IT/consulting). ' +
            'Analyse le profil candidat vs l\'offre et réponds UNIQUEMENT en JSON valide:\n' +
            '{"score":<0-100>,"recommendation":"<2-3 phrases>","points_forts":"<liste puces>","points_faibles":"<liste puces>"}';

        String userPrompt =
            'Analyse ce profil par rapport à l\'offre. Score de 0 à 100.\n\n' +
            '=== OFFRE ===\n' + jobInfo + '\n\n' +
            '=== CANDIDAT ===\n' + candidateInfo + '\n\n' +
            'Pondération: Compétences tech 40% | Expérience 25% | Formation 20% | Soft skills 15%\n' +
            'Score > 70 = excellente adéquation. Réponds UNIQUEMENT en JSON valide.';

        Map<String, Object> body = new Map<String, Object>{
            'model'       => GROQ_MODEL,
            'temperature' => 0.3,
            'max_tokens'  => 600,
            'messages'    => new List<Map<String, String>>{
                new Map<String, String>{ 'role' => 'system', 'content' => systemPrompt },
                new Map<String, String>{ 'role' => 'user',   'content' => userPrompt   }
            }
        };

        HttpRequest req = new HttpRequest();
        req.setEndpoint(GROQ_ENDPOINT);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Authorization', 'Bearer ' + apiKey);
        req.setTimeout(30000);
        req.setBody(JSON.serialize(body));

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) {
            throw new CVScoringException('Groq API erreur (' + res.getStatusCode() + '): ' + res.getBody().left(200));
        }

        Map<String, Object> resp    = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        List<Object>        choices = (List<Object>) resp.get('choices');
        Map<String, Object> msg     = (Map<String, Object>) ((Map<String, Object>) choices[0]).get('message');
        String content = ((String) msg.get('content')).trim();

        if (content.startsWith('```json')) content = content.substring(7);
        else if (content.startsWith('```')) content = content.substring(3);
        if (content.endsWith('```')) content = content.substring(0, content.length() - 3);
        content = content.trim();

        Integer s = content.indexOf('{');
        Integer e = content.lastIndexOf('}');
        if (s != -1 && e > s) content = content.substring(s, e + 1);

        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(content);

        // Groq peut renvoyer points_forts/points_faibles comme tableau au lieu de string
        for (String key : new List<String>{'points_forts', 'points_faibles', 'recommendation'}) {
            Object val = parsed.get(key);
            if (val instanceof List<Object>) {
                List<Object> items = (List<Object>) val;
                List<String> strs = new List<String>();
                for (Object item : items) strs.add(String.valueOf(item));
                parsed.put(key, String.join(strs, ', '));
            }
        }

        return parsed;
    }

    // ═══════════════════════════════════════════════════
    // UTILITAIRES
    // ═══════════════════════════════════════════════════

    private static Id getRecordTypeId(String sObjectName, String devName) {
        List<RecordType> rts = [
            SELECT Id FROM RecordType
            WHERE SObjectType = :sObjectName AND DeveloperName = :devName LIMIT 1
        ];
        return rts.isEmpty() ? null : rts[0].Id;
    }

    public static String generateTempPassword() {
        String upper   = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
        String lower   = 'abcdefghjkmnpqrstuvwxyz';
        String digits  = '23456789';
        String special = '!@#$%&*';
        String all     = upper + lower + digits + special;
        List<String> chars = new List<String>();
        Integer idx;
        idx = Math.mod(Math.abs(Crypto.getRandomInteger()), upper.length());
        chars.add(upper.substring(idx, idx + 1));
        idx = Math.mod(Math.abs(Crypto.getRandomInteger()), lower.length());
        chars.add(lower.substring(idx, idx + 1));
        idx = Math.mod(Math.abs(Crypto.getRandomInteger()), digits.length());
        chars.add(digits.substring(idx, idx + 1));
        idx = Math.mod(Math.abs(Crypto.getRandomInteger()), special.length());
        chars.add(special.substring(idx, idx + 1));
        for (Integer i = 4; i < 10; i++) {
            idx = Math.mod(Math.abs(Crypto.getRandomInteger()), all.length());
            chars.add(all.substring(idx, idx + 1));
        }
        String pwd = '';
        while (!chars.isEmpty()) {
            Integer pick = Math.mod(Math.abs(Crypto.getRandomInteger()), chars.size());
            pwd += chars.remove(pick);
        }
        return pwd;
    }
}

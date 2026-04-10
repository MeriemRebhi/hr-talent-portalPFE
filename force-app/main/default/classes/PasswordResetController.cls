/**
 * PasswordResetController — Gestion sécurisée des mots de passe portail
 * 
 * SÉCURITÉ IMPLÉMENTÉE :
 * - Token hashé SHA-256 (jamais stocké en clair)
 * - Expiration 24h
 * - Usage unique (Is_Used__c)
 * - Rate limiting (max 3 tentatives par token)
 * - Audit log de toutes les actions sensibles
 * - Validation MDP forte (8+ chars, majuscule, minuscule, chiffre, spécial)
 * - Aucun mot de passe en transit dans les emails
 * 
 * Couvre OWASP : A02 (Cryptographic Failures), A04 (Insecure Design), A07 (Auth Failures)
 */
public without sharing class PasswordResetController {

    private static final Integer TOKEN_EXPIRY_HOURS = 24;
    private static final Integer MAX_ATTEMPTS       = 3;
    private static final String  SITE_BASE_URL      = 'https://orgfarm-3ed211f8bb-dev-ed.develop.my.site.com/home2';

    // ═══════════════════════════════════════════════════
    // GÉNÉRATION DE TOKEN SÉCURISÉ
    // ═══════════════════════════════════════════════════

    /**
     * Génère un token crypto-sécurisé, stocke son hash SHA-256, retourne le token brut.
     * Appelé par CVScoringService lors de la création du compte portail.
     */
    public static String generateResetToken(Id userId, String email) {
        // Invalider les anciens tokens non-utilisés pour cet utilisateur
        List<Password_Reset_Token__c> oldTokens = [
            SELECT Id FROM Password_Reset_Token__c
            WHERE User__c = :userId AND Is_Used__c = false
        ];
        if (!oldTokens.isEmpty()) delete oldTokens;

        // Générer un token crypto-aléatoire (32 bytes = 64 hex chars)
        Blob rawToken = Crypto.generateAesKey(256);
        String token = EncodingUtil.convertToHex(rawToken);

        // Hasher le token avec SHA-256 avant stockage
        String tokenHash = hashToken(token);

        // Stocker le hash (jamais le token brut)
        Password_Reset_Token__c prt = new Password_Reset_Token__c(
            Token_Hash__c = tokenHash,
            User__c       = userId,
            Email__c      = email,
            Expiration__c = DateTime.now().addHours(TOKEN_EXPIRY_HOURS),
            Attempts__c   = 0,
            Is_Used__c    = false
        );
        insert prt;

        // Audit log
        logAudit('TOKEN_CREATED', email, 'INFO', 'Token de réinitialisation créé. Expiration: ' + TOKEN_EXPIRY_HOURS + 'h');

        return token;
    }

    /**
     * Construit l'URL sécurisée pour le lien dans l'email
     */
    public static String buildResetUrl(String token) {
        return SITE_BASE_URL + '/s/set-password?token=' + token;
    }

    // ═══════════════════════════════════════════════════
    // VALIDATION DE TOKEN (appelé par le LWC)
    // ═══════════════════════════════════════════════════

    /**
     * Valide un token et retourne l'email associé (pour affichage).
     * Ne change PAS le mot de passe — juste une vérification.
     */
    @AuraEnabled
    public static Map<String, String> validateToken(String token) {
        Map<String, String> result = new Map<String, String>();

        if (String.isBlank(token)) {
            result.put('status', 'ERROR');
            result.put('message', 'Token manquant.');
            return result;
        }

        String tokenHash = hashToken(token);

        List<Password_Reset_Token__c> tokens = [
            SELECT Id, User__c, Email__c, Expiration__c, Attempts__c, Is_Used__c
            FROM Password_Reset_Token__c
            WHERE Token_Hash__c = :tokenHash
            LIMIT 1
        ];

        if (tokens.isEmpty()) {
            logAudit('TOKEN_FAILED', null, 'WARNING', 'Token invalide présenté');
            result.put('status', 'ERROR');
            result.put('message', 'Lien invalide ou expiré.');
            return result;
        }

        Password_Reset_Token__c prt = tokens[0];

        // Vérifier si déjà utilisé
        if (prt.Is_Used__c) {
            logAudit('TOKEN_FAILED', prt.Email__c, 'WARNING', 'Tentative de réutilisation d\'un token consommé');
            result.put('status', 'ERROR');
            result.put('message', 'Ce lien a déjà été utilisé. Demandez un nouveau lien.');
            return result;
        }

        // Vérifier l'expiration
        if (prt.Expiration__c < DateTime.now()) {
            logAudit('TOKEN_EXPIRED', prt.Email__c, 'INFO', 'Token expiré');
            result.put('status', 'ERROR');
            result.put('message', 'Ce lien a expiré. Demandez un nouveau lien.');
            return result;
        }

        // Vérifier le rate limiting
        if (prt.Attempts__c >= MAX_ATTEMPTS) {
            logAudit('TOKEN_FAILED', prt.Email__c, 'CRITICAL', 'Rate limit atteint (' + MAX_ATTEMPTS + ' tentatives)');
            result.put('status', 'ERROR');
            result.put('message', 'Trop de tentatives. Ce lien est bloqué.');
            return result;
        }

        result.put('status', 'OK');
        result.put('email', prt.Email__c);
        return result;
    }

    // ═══════════════════════════════════════════════════
    // CHANGEMENT DE MOT DE PASSE SÉCURISÉ
    // ═══════════════════════════════════════════════════

    /**
     * Change le mot de passe via un token valide.
     * - Valide le token (hash, expiration, usage unique, rate limit)
     * - Valide la force du mot de passe
     * - Change le mot de passe via System.setPassword()
     * - Marque le token comme utilisé
     * - Supprime les anciens tokens
     * - Écrit dans l'audit log
     */
    @AuraEnabled
    public static String setPasswordWithToken(String token, String newPassword) {
        if (String.isBlank(token) || String.isBlank(newPassword)) {
            throw new AuraHandledException('Paramètres manquants.');
        }

        // Valider la force du mot de passe
        String pwdError = validatePasswordStrength(newPassword);
        if (pwdError != null) {
            throw new AuraHandledException(pwdError);
        }

        String tokenHash = hashToken(token);

        List<Password_Reset_Token__c> tokens = [
            SELECT Id, User__c, Email__c, Expiration__c, Attempts__c, Is_Used__c
            FROM Password_Reset_Token__c
            WHERE Token_Hash__c = :tokenHash
            LIMIT 1
        ];

        if (tokens.isEmpty()) {
            logAudit('TOKEN_FAILED', null, 'CRITICAL', 'Token invalide lors du changement MDP');
            throw new AuraHandledException('Lien invalide ou expiré.');
        }

        Password_Reset_Token__c prt = tokens[0];

        // Incrémenter les tentatives (rate limiting)
        prt.Attempts__c = (prt.Attempts__c != null ? prt.Attempts__c : 0) + 1;
        update prt;

        // Vérifications de sécurité
        if (prt.Is_Used__c) {
            logAudit('TOKEN_FAILED', prt.Email__c, 'CRITICAL', 'Tentative de réutilisation token pour changement MDP');
            throw new AuraHandledException('Ce lien a déjà été utilisé.');
        }
        if (prt.Expiration__c < DateTime.now()) {
            logAudit('TOKEN_EXPIRED', prt.Email__c, 'WARNING', 'Token expiré lors du changement MDP');
            throw new AuraHandledException('Ce lien a expiré.');
        }
        if (prt.Attempts__c > MAX_ATTEMPTS) {
            logAudit('TOKEN_FAILED', prt.Email__c, 'CRITICAL', 'Rate limit dépassé lors du changement MDP');
            throw new AuraHandledException('Trop de tentatives. Ce lien est bloqué.');
        }

        try {
            // Changer le mot de passe
            System.setPassword(prt.User__c, newPassword);

            // Marquer le token comme utilisé (one-time use)
            prt.Is_Used__c = true;
            update prt;

            // Audit log — succès
            logAudit('PASSWORD_SET', prt.Email__c, 'INFO',
                'Mot de passe défini avec succès via token sécurisé. User: ' + prt.User__c);

            // Supprimer tous les autres tokens pour cet utilisateur (nettoyage)
            List<Password_Reset_Token__c> otherTokens = [
                SELECT Id FROM Password_Reset_Token__c
                WHERE User__c = :prt.User__c AND Id != :prt.Id
            ];
            if (!otherTokens.isEmpty()) delete otherTokens;

            return 'OK';

        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            String errMsg = e.getMessage();
            logAudit('PASSWORD_SET', prt.Email__c, 'CRITICAL', 'Erreur setPassword: ' + errMsg);
            
            // Messages d'erreur Salesforce traduits
            if (errMsg != null && errMsg.containsIgnoreCase('repeated password')) {
                throw new AuraHandledException('Ce mot de passe a déjà été utilisé. Veuillez en choisir un nouveau.');
            } else if (errMsg != null && errMsg.containsIgnoreCase('not strong enough')) {
                throw new AuraHandledException('Le mot de passe ne respecte pas la politique de sécurité Salesforce.');
            }
            throw new AuraHandledException('Erreur lors du changement de mot de passe : ' + errMsg);
        }
    }

    // ═══════════════════════════════════════════════════
    // VALIDATION FORCE DU MOT DE PASSE
    // ═══════════════════════════════════════════════════

    /**
     * Retourne null si le MDP est valide, sinon le message d'erreur.
     * Règles : 8+ chars, 1 majuscule, 1 minuscule, 1 chiffre, 1 spécial
     */
    @AuraEnabled
    public static String validatePasswordStrength(String password) {
        if (String.isBlank(password) || password.length() < 8) {
            return 'Le mot de passe doit contenir au moins 8 caractères.';
        }
        Boolean hasUpper   = Pattern.matches('.*[A-Z].*', password);
        Boolean hasLower   = Pattern.matches('.*[a-z].*', password);
        Boolean hasDigit   = Pattern.matches('.*[0-9].*', password);
        Boolean hasSpecial = Pattern.matches('.*[!@#$%^&*()_+\\-=\\[\\]{}|;:,.<>?].*', password);

        if (!hasUpper)   return 'Le mot de passe doit contenir au moins une majuscule.';
        if (!hasLower)   return 'Le mot de passe doit contenir au moins une minuscule.';
        if (!hasDigit)   return 'Le mot de passe doit contenir au moins un chiffre.';
        if (!hasSpecial) return 'Le mot de passe doit contenir au moins un caractère spécial (!@#$%...).';
        return null;
    }

    // ═══════════════════════════════════════════════════
    // UTILITAIRES CRYPTO
    // ═══════════════════════════════════════════════════

    private static String hashToken(String token) {
        Blob digest = Crypto.generateDigest('SHA-256', Blob.valueOf(token));
        return EncodingUtil.convertToHex(digest);
    }

    // ═══════════════════════════════════════════════════
    // AUDIT LOG
    // ═══════════════════════════════════════════════════

    public static void logAudit(String action, String email, String severity, String details) {
        try {
            Security_Audit_Log__c log = new Security_Audit_Log__c(
                Action__c    = action,
                Email__c     = email,
                Severity__c  = severity,
                Details__c   = details,
                Timestamp__c = DateTime.now()
            );
            insert log;
        } catch (Exception e) {
            System.debug('⚠️ Audit log failed: ' + e.getMessage());
        }
    }
}

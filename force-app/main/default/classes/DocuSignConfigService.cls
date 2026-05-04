public with sharing class DocuSignConfigService {

    public class Config {
        public String integrationKey;
        public String userId;
        public String accountId;
        public String baseUri;
        public String oauthBaseUri;
        public String privateKeyPem;
        public String adminEmail;
        public String defaultTemplateId;
        public String signerRoleName;
        public String webhookSecret;
        public Boolean isEnabled;
    }

    public class DocuSignConfigException extends Exception {}

    @TestVisible
    private static Config testConfig;

    public static Config getConfigOrThrow() {
        Config cfg = getConfig();
        if (cfg == null) {
            throw new DocuSignConfigException('DocuSign configuration not found. Create DocuSignConfig__mdt.Default.');
        }
        if (cfg.isEnabled != true) {
            throw new DocuSignConfigException('DocuSign integration is disabled in DocuSignConfig__mdt.');
        }
        validateRequired(cfg);
        return cfg;
    }

    public static Config getConfig() {
        if (Test.isRunningTest() && testConfig != null) {
            return testConfig;
        }

        List<DocuSignConfig__mdt> rows = [
            SELECT IntegrationKey__c,
                   UserId__c,
                   AccountId__c,
                   BaseUri__c,
                   OauthBaseUri__c,
                   PrivateKey__c,
                   AdminEmail__c,
                   DefaultTemplateId__c,
                   SignerRoleName__c,
                   WebhookSecret__c,
                   IsEnabled__c
            FROM DocuSignConfig__mdt
            WHERE DeveloperName = 'Default'
            LIMIT 1
        ];

        if (rows.isEmpty()) {
            rows = [
                SELECT IntegrationKey__c,
                       UserId__c,
                       AccountId__c,
                       BaseUri__c,
                       OauthBaseUri__c,
                       PrivateKey__c,
                       AdminEmail__c,
                       DefaultTemplateId__c,
                       SignerRoleName__c,
                       WebhookSecret__c,
                       IsEnabled__c
                FROM DocuSignConfig__mdt
                LIMIT 1
            ];
        }

        if (rows.isEmpty()) {
            return null;
        }

        DocuSignConfig__mdt row = rows[0];
        Config cfg = new Config();
        cfg.integrationKey = trimToNull(row.IntegrationKey__c);
        cfg.userId = trimToNull(row.UserId__c);
        cfg.accountId = trimToNull(row.AccountId__c);
        cfg.baseUri = trimToNull(row.BaseUri__c);
        cfg.oauthBaseUri = trimToNull(row.OauthBaseUri__c);
        cfg.privateKeyPem = trimToNull(row.PrivateKey__c);
        cfg.adminEmail = trimToNull(row.AdminEmail__c);
        cfg.defaultTemplateId = trimToNull(row.DefaultTemplateId__c);
        cfg.signerRoleName = trimToNull(row.SignerRoleName__c);
        cfg.webhookSecret = trimToNull(row.WebhookSecret__c);
        cfg.isEnabled = row.IsEnabled__c;

        if (String.isBlank(cfg.oauthBaseUri)) {
            cfg.oauthBaseUri = 'https://account-d.docusign.com';
        }
        if (String.isBlank(cfg.baseUri)) {
            cfg.baseUri = 'https://demo.docusign.net';
        }
        if (String.isBlank(cfg.signerRoleName)) {
            cfg.signerRoleName = 'Candidate';
        }

        return cfg;
    }

    public static void validateRequired(Config cfg) {
        List<String> missing = new List<String>();

        if (String.isBlank(cfg.integrationKey)) missing.add('IntegrationKey__c');
        if (String.isBlank(cfg.userId)) missing.add('UserId__c');
        if (String.isBlank(cfg.accountId)) missing.add('AccountId__c');
        if (String.isBlank(cfg.privateKeyPem)) missing.add('PrivateKey__c');
        if (String.isBlank(cfg.baseUri)) missing.add('BaseUri__c');
        if (String.isBlank(cfg.oauthBaseUri)) missing.add('OauthBaseUri__c');

        if (!missing.isEmpty()) {
            throw new DocuSignConfigException(
                'Missing DocuSign config fields: ' + String.join(missing, ', ')
            );
        }
    }

    private static String trimToNull(String v) {
        if (v == null) return null;
        String t = v.trim();
        return t == '' ? null : t;
    }

    @TestVisible
    static void setTestConfig(Config cfg) {
        testConfig = cfg;
    }
}

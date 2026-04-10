import { LightningElement, track, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import getTestInfo       from '@salesforce/apex/GamingTestController.getTestInfo';
import submitTestResults from '@salesforce/apex/GamingTestController.submitTestResults';
import getTestQuestions  from '@salesforce/apex/GamingTestController.getTestQuestions';
import validateAnswer    from '@salesforce/apex/GamingTestController.validateAnswer';

/* ═══════════════════════════════════════
   QUESTION BANKS — FALLBACK statique (utilisé si pas de questions dynamiques IA)
   type: mcq | puzzle | order
   Pour 'order' : opts = items dans le bon ordre, le composant les mélange
   ═══════════════════════════════════════ */
const LETTERS = ['A', 'B', 'C', 'D', 'E'];

const BANKS = {
    /* ── Data Analyst / BI ── */
    data: [
        { id:'d1', type:'mcq', diff:'easy', time:30, pts:10,
          q:'Quelle fonction SQL compte le nombre de lignes ?',
          opts:['COUNT()','SUM()','TOTAL()','NUM()'], c:0 },
        { id:'d2', type:'mcq', diff:'medium', time:25, pts:10,
          q:'Quel type de JOIN retourne toutes les lignes même sans correspondance ?',
          opts:['LEFT JOIN','INNER JOIN','CROSS JOIN','SELF JOIN'], c:0 },
        { id:'d3', type:'mcq', diff:'easy', time:30, pts:10,
          q:'En Python, quelle librairie est utilisée pour la manipulation de données tabulaires ?',
          opts:['pandas','numpy','matplotlib','flask'], c:0 },
        { id:'d4', type:'mcq', diff:'medium', time:25, pts:10,
          q:'Quelle mesure statistique est la plus résistante aux valeurs aberrantes ?',
          opts:['La médiane','La moyenne','L\'écart-type','La variance'], c:0 },
        { id:'d5', type:'mcq', diff:'hard', time:20, pts:10,
          q:'Quelle clause SQL permet de filtrer APRÈS un GROUP BY ?',
          opts:['HAVING','WHERE','FILTER','WITH'], c:0 },
        { id:'d6', type:'mcq', diff:'medium', time:25, pts:10,
          q:'Quel graphique est le plus adapté pour montrer une corrélation entre 2 variables ?',
          opts:['Nuage de points','Diagramme circulaire','Histogramme','Diagramme en barres'], c:0 },
        { id:'d7', type:'mcq', diff:'hard', time:20, pts:10,
          q:'Que fait la fonction Python : df.groupby("ville").agg({"prix":"mean"}) ?',
          opts:['Prix moyen par ville','Nombre de prix par ville','Prix max par ville','Somme des prix'], c:0 },
        { id:'d8', type:'puzzle', diff:'easy', time:30, pts:10,
          q:'Complétez la séquence : 2, 6, 18, 54, …',
          opts:['162','108','72','216'], c:0 },
        { id:'d9', type:'puzzle', diff:'medium', time:25, pts:10,
          q:'Complétez la séquence : 1, 1, 2, 3, 5, 8, …',
          opts:['13','11','10','15'], c:0 },
        { id:'d10', type:'puzzle', diff:'hard', time:20, pts:10,
          q:'Si A=1, B=2 … alors DATA = ?',
          opts:['30','35','26','40'], c:0 },
        { id:'d11', type:'mcq', diff:'easy', time:30, pts:10,
          q:'Quel format est le plus utilisé pour l\'échange de données entre API ?',
          opts:['JSON','CSV','XML','YAML'], c:0 },
        { id:'d12', type:'puzzle', diff:'medium', time:25, pts:10,
          q:'Quelle valeur manque ? [4, 9, 16, 25, ?, 49]',
          opts:['36','30','42','32'], c:0 },
        { id:'d13', type:'mcq', diff:'medium', time:25, pts:10,
          q:'Quelle fonction pandas supprime les doublons ?',
          opts:['drop_duplicates()','remove_dup()','unique()','distinct()'], c:0 },
        { id:'d14', type:'mcq', diff:'hard', time:20, pts:10,
          q:'Quel type de visualisation est idéal pour montrer une distribution ?',
          opts:['Histogramme','Camembert','Radar','Treemap'], c:0 },
        { id:'d15', type:'mcq', diff:'easy', time:30, pts:10,
          q:'Quelle commande SQL trie les résultats ?',
          opts:['ORDER BY','SORT BY','ARRANGE','GROUP BY'], c:0 },
        { id:'d16', type:'mcq', diff:'medium', time:25, pts:10,
          q:'Quel outil Python crée des graphiques ?',
          opts:['matplotlib','requests','flask','django'], c:0 },
        { id:'d17', type:'order', diff:'medium', time:35, pts:10,
          q:'Remettez dans l\'ordre les étapes d\'un pipeline data :',
          opts:['Collecte des données','Nettoyage / Préparation','Analyse / Modélisation','Visualisation / Rapport'] },
        { id:'d18', type:'mcq', diff:'hard', time:20, pts:10,
          q:'Quel algorithme de Machine Learning est supervisé ?',
          opts:['Régression linéaire','K-Means','DBSCAN','PCA'], c:0 },
        { id:'d19', type:'puzzle', diff:'easy', time:30, pts:10,
          q:'Un dataset a 1000 lignes et 20% de nulls. Combien de lignes complètes au minimum ?',
          opts:['800','200','1000','600'], c:0 },
        { id:'d20', type:'mcq', diff:'medium', time:25, pts:10,
          q:'Quelle fonction SQL retourne les valeurs uniques ?',
          opts:['DISTINCT','UNIQUE','DIFFERENT','SINGLE'], c:0 },
        { id:'d21', type:'order', diff:'hard', time:35, pts:10,
          q:'Orden correct d\'une requête SQL :',
          opts:['SELECT','FROM','WHERE','GROUP BY','ORDER BY'] },
        { id:'d22', type:'mcq', diff:'easy', time:30, pts:10,
          q:'Quelle librairie Python est utilisée pour le Machine Learning ?',
          opts:['scikit-learn','beautifulsoup','selenium','flask'], c:0 },
        { id:'d23', type:'puzzle', diff:'hard', time:20, pts:10,
          q:'Que vaut : round(2.5) en Python 3 ?',
          opts:['2','3','2.5','Erreur'], c:0 },
        { id:'d24', type:'mcq', diff:'medium', time:25, pts:10,
          q:'Quel type de base de données est optimisé pour les données en colonnes ?',
          opts:['Columnar (ex: Redshift)','Relationnelle','Document','Graphe'], c:0 },
        { id:'d25', type:'order', diff:'medium', time:35, pts:10,
          q:'Étapes d\'un projet de Data Science :',
          opts:['Définir le problème','Explorer les données','Construire le modèle','Évaluer et déployer'] },
    ],
    /* ── Développeur / Fullstack ── */
    dev: [
        { id:'v1', type:'mcq', diff:'easy', time:30, pts:10,
          q:'Quelle est la complexité temporelle d\'une recherche binaire ?',
          opts:['O(log n)','O(n)','O(n²)','O(1)'], c:0 },
        { id:'v2', type:'mcq', diff:'medium', time:25, pts:10,
          q:'Quel design pattern permet de créer des objets sans spécifier leur classe exacte ?',
          opts:['Factory','Singleton','Observer','Strategy'], c:0 },
        { id:'v3', type:'mcq', diff:'easy', time:30, pts:10,
          q:'Quelle méthode HTTP est utilisée pour mettre à jour une ressource ?',
          opts:['PUT','GET','DELETE','TRACE'], c:0 },
        { id:'v4', type:'mcq', diff:'medium', time:25, pts:10,
          q:'Dans Git, quelle commande fusionne une branche dans la branche courante ?',
          opts:['git merge','git rebase','git pull','git fetch'], c:0 },
        { id:'v5', type:'mcq', diff:'hard', time:20, pts:10,
          q:'Quel algorithme de tri a une complexité O(n log n) dans le pire cas ?',
          opts:['Merge Sort','Quick Sort','Bubble Sort','Insertion Sort'], c:0 },
        { id:'v6', type:'mcq', diff:'easy', time:30, pts:10,
          q:'Quel principe SOLID signifie qu\'une classe ne doit avoir qu\'une seule responsabilité ?',
          opts:['S — Single Responsibility','O — Open/Closed','L — Liskov','D — Dependency Inversion'], c:0 },
        { id:'v7', type:'mcq', diff:'medium', time:25, pts:10,
          q:'Quelle structure de données utilise LIFO (Last In, First Out) ?',
          opts:['Stack (Pile)','Queue (File)','Tableau','Arbre binaire'], c:0 },
        { id:'v8', type:'puzzle', diff:'easy', time:30, pts:10,
          q:'Que retourne : [1,2,3].map(x => x * 2).filter(x => x > 2) ?',
          opts:['[4, 6]','[2, 4, 6]','[4]','[6]'], c:0 },
        { id:'v9', type:'puzzle', diff:'medium', time:25, pts:10,
          q:'Quelle est la sortie ? let a = "5"; let b = 3; console.log(a + b)',
          opts:['"53"','8','undefined','NaN'], c:0 },
        { id:'v10', type:'puzzle', diff:'hard', time:20, pts:10,
          q:'Complétez : function fib(n) { return n <= 1 ? n : fib(n-1) + fib(??) }',
          opts:['n-2','n+1','n','n-3'], c:0 },
        { id:'v11', type:'mcq', diff:'medium', time:25, pts:10,
          q:'Quel status HTTP indique une ressource créée avec succès ?',
          opts:['201','200','204','301'], c:0 },
        { id:'v12', type:'puzzle', diff:'easy', time:30, pts:10,
          q:'Combien de fois s\'exécute : for(i=0; i<5; i++) { for(j=0; j<3; j++) {} } ?',
          opts:['15','8','5','12'], c:0 },
        { id:'v13', type:'order', diff:'medium', time:35, pts:10,
          q:'Lifecycle d\'une requête HTTP :',
          opts:['Client envoie la requête','DNS résout le domaine','Serveur traite la requête','Client reçoit la réponse'] },
        { id:'v14', type:'mcq', diff:'hard', time:20, pts:10,
          q:'Quel mot-clé JavaScript crée une variable à portée de bloc ?',
          opts:['let','var','define','dim'], c:0 },
        { id:'v15', type:'mcq', diff:'easy', time:30, pts:10,
          q:'Quel langage est compilé en bytecode JVM ?',
          opts:['Java','Python','JavaScript','Ruby'], c:0 },
        { id:'v16', type:'mcq', diff:'medium', time:25, pts:10,
          q:'Quel pattern garantit une seule instance d\'une classe ?',
          opts:['Singleton','Factory','Proxy','Builder'], c:0 },
        { id:'v17', type:'order', diff:'hard', time:35, pts:10,
          q:'Ordre d\'exécution dans une Promise chain :',
          opts:['fetch()','then() - parse JSON','then() - traiter les données','catch() - gestion erreur'] },
        { id:'v18', type:'mcq', diff:'easy', time:30, pts:10,
          q:'Quel sélecteur CSS cible un élément par son ID ?',
          opts:['#monId','.monId','monId','@monId'], c:0 },
        { id:'v19', type:'puzzle', diff:'medium', time:25, pts:10,
          q:'Que retourne typeof null en JavaScript ?',
          opts:['"object"','"null"','"undefined"','Error'], c:0 },
        { id:'v20', type:'mcq', diff:'hard', time:20, pts:10,
          q:'Quelle complexité a un accès dans une HashMap ?',
          opts:['O(1) amorti','O(n)','O(log n)','O(n²)'], c:0 },
        { id:'v21', type:'order', diff:'medium', time:35, pts:10,
          q:'Étapes d\'un déploiement CI/CD typique :',
          opts:['Commit du code','Build automatique','Tests automatisés','Déploiement en production'] },
        { id:'v22', type:'mcq', diff:'medium', time:25, pts:10,
          q:'Quel header HTTP contrôle le cache ?',
          opts:['Cache-Control','Content-Type','Authorization','Accept'], c:0 },
        { id:'v23', type:'puzzle', diff:'hard', time:20, pts:10,
          q:'Que vaut : !!"" en JavaScript ?',
          opts:['false','true','undefined','""'], c:0 },
        { id:'v24', type:'mcq', diff:'easy', time:30, pts:10,
          q:'Quelle balise HTML crée un lien hypertexte ?',
          opts:['<a>','<link>','<href>','<url>'], c:0 },
        { id:'v25', type:'mcq', diff:'medium', time:25, pts:10,
          q:'Quelle base de données est relationnelle ?',
          opts:['PostgreSQL','MongoDB','Redis','Cassandra'], c:0 },
    ],
    /* ── DevOps / Cloud ── */
    devops: [
        { id:'o1', type:'mcq', diff:'easy', time:30, pts:10,
          q:'Quel outil permet de containeriser une application ?',
          opts:['Docker','Vagrant','Ansible','Terraform'], c:0 },
        { id:'o2', type:'mcq', diff:'medium', time:25, pts:10,
          q:'Quelle est la fonction principale de Kubernetes ?',
          opts:['Orchestration de conteneurs','Monitoring','CI/CD','Stockage cloud'], c:0 },
        { id:'o3', type:'mcq', diff:'easy', time:30, pts:10,
          q:'Que signifie CI dans CI/CD ?',
          opts:['Continuous Integration','Continuous Inspection','Code Integration','Cloud Integration'], c:0 },
        { id:'o4', type:'mcq', diff:'medium', time:25, pts:10,
          q:'Quel fichier définit les services dans Docker Compose ?',
          opts:['docker-compose.yml','Dockerfile','config.yml','services.json'], c:0 },
        { id:'o5', type:'mcq', diff:'hard', time:20, pts:10,
          q:'Quel outil IaC utilise un langage déclaratif HCL ?',
          opts:['Terraform','Ansible','Chef','Puppet'], c:0 },
        { id:'o6', type:'mcq', diff:'easy', time:30, pts:10,
          q:'Quelle commande Linux affiche les processus en cours ?',
          opts:['ps','ls','cat','chmod'], c:0 },
        { id:'o7', type:'mcq', diff:'medium', time:25, pts:10,
          q:'Quel port est utilisé par défaut par HTTPS ?',
          opts:['443','80','8080','22'], c:0 },
        { id:'o8', type:'puzzle', diff:'easy', time:30, pts:10,
          q:'Quel est le résultat de : 192.168.1.0/24 — combien d\'hôtes possibles ?',
          opts:['254','256','255','253'], c:0 },
        { id:'o9', type:'puzzle', diff:'medium', time:25, pts:10,
          q:'Ordre correct du pipeline CI/CD ?',
          opts:['Build → Test → Deploy','Test → Build → Deploy','Deploy → Build → Test','Build → Deploy → Test'], c:0 },
        { id:'o10', type:'puzzle', diff:'hard', time:20, pts:10,
          q:'Quel fichier protège les credentials dans Git ?',
          opts:['.gitignore','.env','config.yml','secrets.json'], c:0 },
        { id:'o11', type:'mcq', diff:'easy', time:30, pts:10,
          q:'Quel service AWS permet de stocker des fichiers (Object Storage) ?',
          opts:['S3','EC2','RDS','Lambda'], c:0 },
        { id:'o12', type:'mcq', diff:'medium', time:25, pts:10,
          q:'Qu\'est-ce qu\'un Pod dans Kubernetes ?',
          opts:['Plus petite unité déployable','Un cluster','Un namespace','Un service'], c:0 },
        { id:'o13', type:'order', diff:'medium', time:35, pts:10,
          q:'Remettez dans l\'ordre un déploiement Docker :',
          opts:['Écrire le Dockerfile','Build de l\'image','Push vers le registry','Run du conteneur'] },
        { id:'o14', type:'mcq', diff:'hard', time:20, pts:10,
          q:'Quel type de scaling ajoute plus de machines ?',
          opts:['Horizontal','Vertical','Diagonal','Latéral'], c:0 },
        { id:'o15', type:'mcq', diff:'easy', time:30, pts:10,
          q:'Quelle commande affiche le contenu d\'un fichier Linux ?',
          opts:['cat','ls','mv','cp'], c:0 },
        { id:'o16', type:'mcq', diff:'medium', time:25, pts:10,
          q:'Quel service gère les secrets dans AWS ?',
          opts:['AWS Secrets Manager','S3','IAM','CloudWatch'], c:0 },
        { id:'o17', type:'order', diff:'hard', time:35, pts:10,
          q:'Étapes d\'un incident en production :',
          opts:['Détection (alerting)','Diagnostic (logs/metrics)','Correction (hotfix)','Post-mortem (RCA)'] },
        { id:'o18', type:'mcq', diff:'easy', time:30, pts:10,
          q:'Quel protocole est utilisé pour le transfert sécurisé de fichiers ?',
          opts:['SFTP','HTTP','SMTP','DNS'], c:0 },
        { id:'o19', type:'mcq', diff:'medium', time:25, pts:10,
          q:'Quel outil est un système de monitoring open-source ?',
          opts:['Prometheus','Jenkins','GitLab','Docker'], c:0 },
        { id:'o20', type:'puzzle', diff:'hard', time:20, pts:10,
          q:'Un serveur a 16 Go RAM et chaque Pod utilise 512 Mo. Maximum de Pods ?',
          opts:['32','16','64','8'], c:0 },
        { id:'o21', type:'order', diff:'medium', time:35, pts:10,
          q:'Étapes GitFlow pour une feature :',
          opts:['Créer branche feature','Développer','Pull Request / Review','Merge dans develop'] },
        { id:'o22', type:'mcq', diff:'hard', time:20, pts:10,
          q:'Quelle stratégie de déploiement redirige progressivement le trafic ?',
          opts:['Canary','Big Bang','Recreate','A/B Testing'], c:0 },
        { id:'o23', type:'mcq', diff:'easy', time:30, pts:10,
          q:'Quelle commande Docker liste les conteneurs actifs ?',
          opts:['docker ps','docker list','docker show','docker run'], c:0 },
        { id:'o24', type:'mcq', diff:'medium', time:25, pts:10,
          q:'Quel est le rôle d\'un Load Balancer ?',
          opts:['Répartir le trafic entre serveurs','Stocker les logs','Gérer les DNS','Compiler le code'], c:0 },
        { id:'o25', type:'puzzle', diff:'medium', time:25, pts:10,
          q:'Quelle permission Linux correspond à chmod 755 ?',
          opts:['rwxr-xr-x','rwxrwxrwx','rw-r--r--','rwx------'], c:0 },
    ],
    /* ── Général ── */
    general: [
        { id:'g1', type:'mcq', diff:'easy', time:30, pts:10,
          q:'Quel langage est le plus utilisé pour le développement web front-end ?',
          opts:['JavaScript','Python','Java','C++'], c:0 },
        { id:'g2', type:'mcq', diff:'easy', time:30, pts:10,
          q:'Que signifie API ?',
          opts:['Application Programming Interface','Advanced Programming Integration','Automated Process Interface','Application Process Integration'], c:0 },
        { id:'g3', type:'mcq', diff:'medium', time:25, pts:10,
          q:'Quelle base de données est de type NoSQL ?',
          opts:['MongoDB','PostgreSQL','MySQL','Oracle'], c:0 },
        { id:'g4', type:'mcq', diff:'easy', time:30, pts:10,
          q:'Quel protocole sécurise les échanges web ?',
          opts:['HTTPS','FTP','SMTP','TCP'], c:0 },
        { id:'g5', type:'mcq', diff:'medium', time:25, pts:10,
          q:'Quel concept permet de masquer les détails d\'implémentation ?',
          opts:['Encapsulation','Héritage','Polymorphisme','Abstraction'], c:0 },
        { id:'g6', type:'puzzle', diff:'easy', time:30, pts:10,
          q:'Complétez : 3, 7, 15, 31, …',
          opts:['63','47','55','61'], c:0 },
        { id:'g7', type:'puzzle', diff:'medium', time:25, pts:10,
          q:'Si CLOUD = 50, AZURE = ?',
          opts:['57','52','48','60'], c:0 },
        { id:'g8', type:'puzzle', diff:'easy', time:30, pts:10,
          q:'Combien de bits dans un octet ?',
          opts:['8','16','4','32'], c:0 },
        { id:'g9', type:'mcq', diff:'medium', time:25, pts:10,
          q:'Quel outil gère les versions du code source ?',
          opts:['Git','Jira','Slack','Jenkins'], c:0 },
        { id:'g10', type:'mcq', diff:'hard', time:20, pts:10,
          q:'Quelle méthode agile utilise des sprints de 2-4 semaines ?',
          opts:['Scrum','Kanban','Waterfall','Lean'], c:0 },
        { id:'g11', type:'puzzle', diff:'hard', time:20, pts:10,
          q:'Un serveur traite 100 requêtes/s. Combien en 2.5 minutes ?',
          opts:['15 000','25 000','10 000','1 500'], c:0 },
        { id:'g12', type:'mcq', diff:'easy', time:30, pts:10,
          q:'Quel format est couramment utilisé pour les fichiers de configuration ?',
          opts:['YAML','HTML','CSS','SQL'], c:0 },
        { id:'g13', type:'order', diff:'medium', time:35, pts:10,
          q:'Cycle de vie d\'un projet logiciel (Waterfall) :',
          opts:['Analyse des besoins','Conception','Développement','Tests','Déploiement'] },
        { id:'g14', type:'mcq', diff:'medium', time:25, pts:10,
          q:'Quel type d\'attaque envoie des requêtes massives pour surcharger un serveur ?',
          opts:['DDoS','Phishing','SQL Injection','XSS'], c:0 },
        { id:'g15', type:'mcq', diff:'easy', time:30, pts:10,
          q:'Quel réseau social est orienté professionnel ?',
          opts:['LinkedIn','TikTok','Instagram','Snapchat'], c:0 },
        { id:'g16', type:'mcq', diff:'hard', time:20, pts:10,
          q:'Quel est le rôle d\'un proxy inverse (reverse proxy) ?',
          opts:['Relayer les requêtes vers les serveurs backend','Bloquer les virus','Stocker les fichiers','Compiler le code'], c:0 },
        { id:'g17', type:'order', diff:'easy', time:35, pts:10,
          q:'Ordre d\'un sprint Scrum :',
          opts:['Sprint Planning','Développement (Daily Standups)','Sprint Review','Sprint Retrospective'] },
        { id:'g18', type:'mcq', diff:'medium', time:25, pts:10,
          q:'Quel diagramme UML montre les interactions séquentielles ?',
          opts:['Diagramme de séquence','Diagramme de classes','Use Case','Diagramme d\'état'], c:0 },
        { id:'g19', type:'puzzle', diff:'medium', time:25, pts:10,
          q:'Convertir 1010 (binaire) en décimal :',
          opts:['10','12','5','8'], c:0 },
        { id:'g20', type:'mcq', diff:'easy', time:30, pts:10,
          q:'Quel outil est un éditeur de code populaire de Microsoft ?',
          opts:['VS Code','Notepad','Word','Excel'], c:0 },
        { id:'g21', type:'order', diff:'hard', time:35, pts:10,
          q:'Couches du modèle OSI (de bas en haut) :',
          opts:['Physique','Liaison','Réseau','Transport','Application'] },
        { id:'g22', type:'mcq', diff:'hard', time:20, pts:10,
          q:'Quel algorithme de chiffrement est asymétrique ?',
          opts:['RSA','AES','DES','Blowfish'], c:0 },
        { id:'g23', type:'mcq', diff:'easy', time:30, pts:10,
          q:'Combien de valeurs peut stocker un booléen ?',
          opts:['2','1','4','8'], c:0 },
        { id:'g24', type:'puzzle', diff:'hard', time:20, pts:10,
          q:'2^10 = ?',
          opts:['1024','1000','512','2048'], c:0 },
        { id:'g25', type:'mcq', diff:'medium', time:25, pts:10,
          q:'Quel cloud provider propose le service Azure ?',
          opts:['Microsoft','Amazon','Google','IBM'], c:0 },
    ]
};

const DIFF_LABELS = { easy: 'Facile', medium: 'Moyen', hard: 'Difficile' };
const DIFF_CLASS  = { easy: 'gt-diff gt-diff-easy', medium: 'gt-diff gt-diff-med', hard: 'gt-diff gt-diff-hard' };

export default class GamingTest extends LightningElement {

    /* ── State ── */
    @track step = 'loading';   // loading, error, already-done, not-scheduled, welcome, countdown, quiz, results
    @track oppId;
    @track jobPostingId;
    @track isDynamic = false;  // true = questions from Apex/IA, false = static fallback BANKS
    @track candidateName = '';
    @track jobTitle = '';
    @track existingScore = 0;
    @track scheduledDateFmt = '';

    /* ── Quiz ── */
    @track questions = [];
    @track currentIndex = 0;
    @track selectedAnswer = -1;
    @track answered = false;
    @track timeLeft = 0;
    @track answers = [];        // { id, selected, correct, timeSpent, points, speedBonus }
    @track showSpeedBonus = false;
    @track countdownNum = 3;

    /* ── Order question state ── */
    @track orderItems = [];       // current shuffled items for drag
    @track orderLocked = false;   // locked after validate

    /* ── Anti-cheat: tab switch detection ── */
    @track tabViolations = 0;
    @track showTabWarning = false;
    @track testTerminated = false;

    /* ── Results ── */
    @track finalScore = 0;
    @track displayScore = 0;
    @track passed = false;
    @track recommendation = '';
    @track resultStage = '';
    @track errorDetail = '';

    _timerInterval;
    _countdownInterval;
    _questionStartTime;
    _testLoaded = false;
    _boundVisibilityHandler;
    _boundBlurHandler;

    /* ═══════ LIFECYCLE ═══════ */

    /* Wire CurrentPageReference — works in Experience Cloud */
    @wire(CurrentPageReference)
    handlePageRef(pageRef) {
        if (pageRef) {
            // Try state (community query params), then attributes
            const id = (pageRef.state && (pageRef.state.id || pageRef.state.oppId))
                    || (pageRef.attributes && (pageRef.attributes.id || pageRef.attributes.oppId));
            if (id && !this._testLoaded) {
                this.oppId = id;
                this._testLoaded = true;
                this._loadTest();
            }
        }
    }

    connectedCallback() {
        // Fallback: extract oppId from raw URL (for non-community contexts)
        if (!this.oppId) {
            try {
                // Try URLSearchParams first
                const params = new URLSearchParams(window.location.search);
                this.oppId = params.get('id') || params.get('oppId');
            } catch (e) { /* ignore */ }
        }

        // Fallback 2: parse URL hash or full href for ?id= pattern
        if (!this.oppId) {
            try {
                const match = window.location.href.match(/[?&]id=([a-zA-Z0-9]{15,18})/);
                if (match) this.oppId = match[1];
            } catch (e) { /* ignore */ }
        }

        if (this.oppId && !this._testLoaded) {
            this._testLoaded = true;
            this._loadTest();
        } else if (!this.oppId) {
            // Give wire a moment to fire before showing error
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => {
                if (!this._testLoaded) {
                    this.step = 'error';
                    this.errorDetail = 'Aucun identifiant trouvé dans l\'URL.';
                }
            }, 2500);
        }
    }

    disconnectedCallback() {
        this._clearTimers();
        this._removeAntiCheatListeners();
    }

    /* ═══════ ANTI-CHEAT: Tab/Window Switch Detection ═══════ */
    _setupAntiCheatListeners() {
        this._boundVisibilityHandler = this._onVisibilityChange.bind(this);
        this._boundBlurHandler = this._onWindowBlur.bind(this);
        document.addEventListener('visibilitychange', this._boundVisibilityHandler);
        window.addEventListener('blur', this._boundBlurHandler);
    }

    _removeAntiCheatListeners() {
        if (this._boundVisibilityHandler) {
            document.removeEventListener('visibilitychange', this._boundVisibilityHandler);
        }
        if (this._boundBlurHandler) {
            window.removeEventListener('blur', this._boundBlurHandler);
        }
    }

    _onVisibilityChange() {
        if (document.hidden && this.step === 'quiz' && !this.testTerminated) {
            this._handleTabSwitch();
        }
    }

    _onWindowBlur() {
        if (this.step === 'quiz' && !this.testTerminated) {
            this._handleTabSwitch();
        }
    }

    _handleTabSwitch() {
        this.tabViolations++;
        if (this.tabViolations >= 2) {
            this._terminateTest();
        } else {
            this.showTabWarning = true;
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => { this.showTabWarning = false; }, 5000);
        }
    }

    _terminateTest() {
        this.testTerminated = true;
        this._clearTimers();
        this._removeAntiCheatListeners();

        // Submit score 0 to Salesforce
        submitTestResults({
            oppId: this.oppId,
            score: 0,
            correctCount: 0,
            totalQuestions: this.questions.length,
            timeSpentSeconds: Math.round(this.answers.reduce((s, a) => s + a.timeSpent, 0))
        })
        .then(result => {
            this.passed = result.passed;
            this.recommendation = 'Test annulé : le candidat a quitté la fenêtre du test.';
            this.resultStage = result.newStage || '—';
        })
        .catch(() => {
            this.recommendation = 'Test annulé. Erreur lors de la sauvegarde.';
        });
    }

    dismissTabWarning() {
        this.showTabWarning = false;
    }

    goToLogin() {
        const baseUrl = window.location.origin;
        const communityPath = window.location.pathname.split('/s/')[0];
        window.location.href = baseUrl + communityPath + '/s/loginp';
    }

    _loadTest() {
        getTestInfo({ oppId: this.oppId })
            .then(data => {
                this.candidateName = data.candidateName || '';
                this.jobTitle      = data.jobTitle || '';
                this.jobPostingId  = data.jobPostingId || null;
                this.isDynamic     = data.hasDynamicQuestions === true;

                if (data.alreadyCompleted) {
                    this.existingScore = data.existingScore || 0;
                    this.step = 'already-done';
                } else if (!data.isScheduled) {
                    this.step = 'not-scheduled';
                } else {
                    // Format scheduled date for display
                    if (data.scheduledDate) {
                        const d = new Date(data.scheduledDate);
                        this.scheduledDateFmt = d.toLocaleDateString('fr-FR', {
                            weekday: 'long', day: 'numeric', month: 'long',
                            year: 'numeric', hour: '2-digit', minute: '2-digit'
                        });
                        // Block if scheduled date is in the future
                        if (d.getTime() > Date.now()) {
                            this.step = 'too-early';
                            return;
                        }
                    }

                    if (this.isDynamic) {
                        // Dynamic mode — load questions from Apex (server-side)
                        this._loadDynamicQuestions();
                    } else {
                        // Fallback — static BANKS
                        const cat = this._detectCategory(data.jobTitle);
                        this._prepareQuestions(cat);
                        this.step = 'welcome';
                    }
                }
            })
            .catch(err => {
                this.step = 'error';
                const msg = err && err.body ? err.body.message : (err && err.message ? err.message : 'Erreur inconnue');
                this.errorDetail = msg;
            });
    }

    /* ═══════ DYNAMIC QUESTIONS — from Apex/IA ═══════ */
    _loadDynamicQuestions() {
        getTestQuestions({ jobPostingId: this.jobPostingId })
            .then(serverQuestions => {
                this.questions = serverQuestions.map((q, i) => ({
                    id: q.id,
                    index: i,
                    type: q.type,
                    isOrder: q.type === 'order',
                    isPuzzle: q.type === 'puzzle',
                    isMcq: q.type === 'mcq' || q.type === 'puzzle',
                    diff: q.diff,
                    diffLabel: DIFF_LABELS[q.diff] || 'Moyen',
                    diffBadgeClass: DIFF_CLASS[q.diff] || DIFF_CLASS.medium,
                    question: q.question,
                    options: q.type === 'order' ? null : q.opts,
                    correctOrder: q.type === 'order' ? [...q.opts] : null,
                    correct: -1,  // NOT sent by server — will be resolved after validateAnswer
                    timeLimit: q.time,
                    points: 10,
                    pts: 10
                }));
                this.step = 'welcome';
            })
            .catch(err => {
                // Fallback to static if dynamic loading fails
                console.warn('Dynamic questions failed, falling back to static:', err);
                this.isDynamic = false;
                const cat = this._detectCategory(this.jobTitle);
                this._prepareQuestions(cat);
                this.step = 'welcome';
            });
    }

    /* ═══════ CATEGORY DETECTION ═══════ */
    _detectCategory(title) {
        const t = (title || '').toLowerCase();
        if (t.includes('data') || t.includes('analyst') || t.includes('bi') || t.includes('donnée')) return 'data';
        if (t.includes('dev') || t.includes('full') || t.includes('software') || t.includes('front') || t.includes('back') || t.includes('engineer')) return 'dev';
        if (t.includes('devops') || t.includes('cloud') || t.includes('infra') || t.includes('sre') || t.includes('réseau')) return 'devops';
        return 'general';
    }

    _prepareQuestions(category) {
        const bank = BANKS[category] || BANKS.general;
        const shuffled = [...bank].sort(() => Math.random() - 0.5);
        this.questions = shuffled.slice(0, 10).map((q, i) => ({
            ...q,
            index: i,
            isOrder: q.type === 'order',
            isPuzzle: q.type === 'puzzle',
            isMcq: q.type === 'mcq',
            diffLabel: DIFF_LABELS[q.diff] || 'Moyen',
            diffBadgeClass: DIFF_CLASS[q.diff] || DIFF_CLASS.medium,
            question: q.q,
            options: q.type === 'order' ? null : q.opts,
            correctOrder: q.type === 'order' ? [...q.opts] : null,
            correct: q.type === 'order' ? -1 : q.c,
            timeLimit: q.time,
            points: q.pts
        }));
    }

    /* ═══════ COUNTDOWN 3-2-1 ═══════ */
    startCountdown() {
        this.step = 'countdown';
        this.countdownNum = 3;
        this._countdownInterval = setInterval(() => {
            this.countdownNum--;
            if (this.countdownNum <= 0) {
                clearInterval(this._countdownInterval);
                this._beginQuiz();
            }
        }, 900);
    }

    _beginQuiz() {
        this.currentIndex = 0;
        this.answers = [];
        this.tabViolations = 0;
        this.testTerminated = false;
        this.showTabWarning = false;
        this.step = 'quiz';
        this._setupAntiCheatListeners();
        this._startQuestion();
    }

    /* ═══════ QUESTION FLOW ═══════ */
    _startQuestion() {
        this.selectedAnswer = -1;
        this.answered = false;
        this.showSpeedBonus = false;
        this.orderLocked = false;
        this.timeLeft = this.currentQuestion.timeLimit;
        this._questionStartTime = Date.now();

        // Initialize order items if order question
        if (this.currentQuestion.isOrder) {
            if (this.isDynamic) {
                // Dynamic mode — options from server are in correct order, shuffle them
                const opts = this.currentQuestion.correctOrder || this.currentQuestion.options || [];
                const items = opts.map((text, idx) => ({ text, correctIdx: idx, key: 'ord-' + idx }));
                let arr = [...items];
                do { arr.sort(() => Math.random() - 0.5); }
                while (arr.length > 1 && arr.every((it, i) => it.correctIdx === i));
                this.orderItems = arr;
            } else {
                // Static mode — same as before
                const correct = this.currentQuestion.correctOrder;
                const items = correct.map((text, idx) => ({ text, correctIdx: idx, key: 'ord-' + idx }));
                let arr = [...items];
                do { arr.sort(() => Math.random() - 0.5); }
                while (arr.length > 1 && arr.every((it, i) => it.correctIdx === i));
                this.orderItems = arr;
            }
        } else {
            this.orderItems = [];
        }

        this._clearTimers();
        this._timerInterval = setInterval(() => {
            this.timeLeft--;
            if (this.timeLeft <= 0) {
                clearInterval(this._timerInterval);
                this._timeUp();
            }
        }, 1000);
    }

    _timeUp() {
        if (this.answered) return;
        this.answered = true;
        this.selectedAnswer = -1; // no selection

        if (this.isDynamic) {
            // Server-side: validate with empty answer to get correct answer for UI
            validateAnswer({
                questionId: this.currentQuestion.id,
                selectedAnswer: '__TIMEOUT__',
                timeSpent: this.currentQuestion.timeLimit
            })
            .then(result => {
                if (result.correctAnswer && !this.currentQuestion.isOrder) {
                    const correctIdx = LETTERS.indexOf(result.correctAnswer);
                    this.questions[this.currentIndex] = {
                        ...this.questions[this.currentIndex],
                        correct: correctIdx
                    };
                }
                this.answers = [...this.answers, {
                    id: this.currentQuestion.id,
                    selected: -1,
                    correct: false,
                    timeSpent: this.currentQuestion.timeLimit,
                    points: 0,
                    speedBonus: false
                }];
                // eslint-disable-next-line @lwc/lwc/no-async-operation
                setTimeout(() => this._nextQuestion(), 1500);
            })
            .catch(() => {
                this.answers = [...this.answers, {
                    id: this.currentQuestion.id,
                    selected: -1,
                    correct: false,
                    timeSpent: this.currentQuestion.timeLimit,
                    points: 0,
                    speedBonus: false
                }];
                // eslint-disable-next-line @lwc/lwc/no-async-operation
                setTimeout(() => this._nextQuestion(), 1500);
            });
        } else {
            this.answers = [...this.answers, {
                id: this.currentQuestion.id,
                selected: -1,
                correct: false,
                timeSpent: this.currentQuestion.timeLimit,
                points: 0,
                speedBonus: false
            }];
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => this._nextQuestion(), 1500);
        }
    }

    selectAnswer(event) {
        if (this.answered) return;
        const idx = parseInt(event.currentTarget.dataset.index, 10);
        this.selectedAnswer = idx;
        this.answered = true;
        clearInterval(this._timerInterval);

        const elapsed = (Date.now() - this._questionStartTime) / 1000;

        if (this.isDynamic) {
            // Dynamic mode — validate server-side
            const selectedLetter = LETTERS[idx];
            validateAnswer({
                questionId: this.currentQuestion.id,
                selectedAnswer: selectedLetter,
                timeSpent: elapsed
            })
            .then(result => {
                // Store the correct answer index for UI feedback
                const correctIdx = LETTERS.indexOf(result.correctAnswer);
                this.questions[this.currentIndex] = {
                    ...this.questions[this.currentIndex],
                    correct: correctIdx
                };

                if (result.speedBonus) this.showSpeedBonus = true;

                this.answers = [...this.answers, {
                    id: this.currentQuestion.id,
                    selected: idx,
                    correct: result.correct,
                    timeSpent: Math.round(elapsed),
                    points: result.points,
                    speedBonus: result.speedBonus
                }];

                // eslint-disable-next-line @lwc/lwc/no-async-operation
                setTimeout(() => this._nextQuestion(), 1500);
            })
            .catch(() => {
                // On error, count as wrong and move on
                this.answers = [...this.answers, {
                    id: this.currentQuestion.id,
                    selected: idx,
                    correct: false,
                    timeSpent: Math.round(elapsed),
                    points: 0,
                    speedBonus: false
                }];
                // eslint-disable-next-line @lwc/lwc/no-async-operation
                setTimeout(() => this._nextQuestion(), 1500);
            });
        } else {
            // Static fallback mode — validate client-side
            const isCorrect = idx === this.currentQuestion.correct;
            const fast = elapsed < this.currentQuestion.timeLimit * 0.5;
            const speedBonus = isCorrect && fast;
            const pts = isCorrect ? this.currentQuestion.points + (speedBonus ? 2 : 0) : 0;

            if (speedBonus) this.showSpeedBonus = true;

            this.answers = [...this.answers, {
                id: this.currentQuestion.id,
                selected: idx,
                correct: isCorrect,
                timeSpent: Math.round(elapsed),
                points: pts,
                speedBonus
            }];

            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => this._nextQuestion(), 1500);
        }
    }

    _nextQuestion() {
        this.showSpeedBonus = false;
        this.orderItems = [];
        this.orderLocked = false;
        if (this.currentIndex < this.questions.length - 1) {
            this.currentIndex++;
            this._startQuestion();
        } else {
            this._finishQuiz();
        }
    }

    /* ═══════ ORDER QUESTION — Move & Validate ═══════ */
    moveOrderUp(event) {
        if (this.orderLocked || this.answered) return;
        const idx = parseInt(event.currentTarget.dataset.idx, 10);
        if (idx <= 0) return;
        const arr = [...this.orderItems];
        [arr[idx - 1], arr[idx]] = [arr[idx], arr[idx - 1]];
        this.orderItems = arr;
    }

    moveOrderDown(event) {
        if (this.orderLocked || this.answered) return;
        const idx = parseInt(event.currentTarget.dataset.idx, 10);
        if (idx >= this.orderItems.length - 1) return;
        const arr = [...this.orderItems];
        [arr[idx], arr[idx + 1]] = [arr[idx + 1], arr[idx]];
        this.orderItems = arr;
    }

    validateOrder() {
        if (this.orderLocked || this.answered) return;
        this.orderLocked = true;
        this.answered = true;
        clearInterval(this._timerInterval);

        const elapsed = (Date.now() - this._questionStartTime) / 1000;

        if (this.isDynamic) {
            // Dynamic mode — send order as pipe-separated string to server
            const orderString = this.orderItems.map(it => it.text).join('|');
            validateAnswer({
                questionId: this.currentQuestion.id,
                selectedAnswer: orderString,
                timeSpent: elapsed
            })
            .then(result => {
                // Resolve correct order for UI feedback
                if (result.correctAnswer) {
                    const correctParts = result.correctAnswer.split('|');
                    this.orderItems = this.orderItems.map((it, i) => {
                        const isItemCorrect = it.text === correctParts[i];
                        return { ...it, correctIdx: isItemCorrect ? i : -1 };
                    });
                }

                if (result.speedBonus) this.showSpeedBonus = true;

                this.answers = [...this.answers, {
                    id: this.currentQuestion.id,
                    selected: -1,
                    correct: result.correct,
                    timeSpent: Math.round(elapsed),
                    points: result.points,
                    speedBonus: result.speedBonus
                }];

                // eslint-disable-next-line @lwc/lwc/no-async-operation
                setTimeout(() => this._nextQuestion(), 1800);
            })
            .catch(() => {
                this.answers = [...this.answers, {
                    id: this.currentQuestion.id,
                    selected: -1,
                    correct: false,
                    timeSpent: Math.round(elapsed),
                    points: 0,
                    speedBonus: false
                }];
                // eslint-disable-next-line @lwc/lwc/no-async-operation
                setTimeout(() => this._nextQuestion(), 1800);
            });
        } else {
            // Static fallback mode — validate client-side
            const isCorrect = this.orderItems.every((it, i) => it.correctIdx === i);
            const fast = elapsed < this.currentQuestion.timeLimit * 0.5;
            const speedBonus = isCorrect && fast;
            const pts = isCorrect ? this.currentQuestion.points + (speedBonus ? 2 : 0) : 0;

            if (speedBonus) this.showSpeedBonus = true;

            this.answers = [...this.answers, {
                id: this.currentQuestion.id,
                selected: -1,
                correct: isCorrect,
                timeSpent: Math.round(elapsed),
                points: pts,
                speedBonus
            }];

            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => this._nextQuestion(), 1800);
        }
    }

    /* ═══════ FINISH & SUBMIT ═══════ */
    _finishQuiz() {
        this._clearTimers();
        this._removeAntiCheatListeners();
        const totalPts  = this.answers.reduce((s, a) => s + a.points, 0);
        const maxPts    = this.questions.length * 10; // base max (no bonus)
        this.finalScore = Math.min(100, Math.round((totalPts / maxPts) * 100));
        this.step = 'results';

        // Animate score
        this.displayScore = 0;
        let current = 0;
        const target = this.finalScore;
        const scoreInterval = setInterval(() => {
            current += 1;
            this.displayScore = current;
            if (current >= target) clearInterval(scoreInterval);
        }, 25);

        // Submit to Salesforce
        submitTestResults({
            oppId: this.oppId,
            score: this.finalScore,
            correctCount: this.answers.filter(a => a.correct).length,
            totalQuestions: this.questions.length,
            timeSpentSeconds: Math.round(this.answers.reduce((s, a) => s + a.timeSpent, 0))
        })
        .then(result => {
            this.passed = result.passed;
            this.recommendation = result.recommendation;
            this.resultStage = result.newStage || '—';
        })
        .catch(() => {
            this.recommendation = 'Erreur de sauvegarde. Contactez le recruteur.';
        });
    }

    _clearTimers() {
        if (this._timerInterval)    clearInterval(this._timerInterval);
        if (this._countdownInterval) clearInterval(this._countdownInterval);
    }

    /* ═══════ GETTERS — Step visibility ═══════ */
    get isLoading()      { return this.step === 'loading'; }
    get isError()        { return this.step === 'error'; }
    get isAlreadyDone()  { return this.step === 'already-done'; }
    get isNotScheduled() { return this.step === 'not-scheduled'; }
    get isTooEarly()     { return this.step === 'too-early'; }
    get isWelcome()      { return this.step === 'welcome'; }
    get isCountdown()    { return this.step === 'countdown'; }
    get isQuiz()         { return this.step === 'quiz' && !this.testTerminated; }
    get isResults()      { return this.step === 'results'; }
    get isTerminated()   { return this.testTerminated; }

    /* ═══════ GETTERS — Welcome ═══════ */
    get candidateInitials() {
        const parts = (this.candidateName || '').trim().split(' ');
        return parts.length >= 2
            ? (parts[0][0] + parts[parts.length - 1][0]).toUpperCase()
            : (this.candidateName || 'C').substring(0, 2).toUpperCase();
    }

    /* ═══════ GETTERS — Quiz ═══════ */
    get currentQuestion() {
        const q = this.questions[this.currentIndex];
        if (!q) return {};

        // For order questions, build items with visual state
        let orderItemsWithState = [];
        if (q.isOrder && this.orderItems.length > 0) {
            orderItemsWithState = this.orderItems.map((it, i) => {
                let itemClass = 'gt-order-item';
                if (this.orderLocked) {
                    itemClass += it.correctIdx === i ? ' gt-order-correct' : ' gt-order-wrong';
                }
                return {
                    ...it,
                    idx: i,
                    num: i + 1,
                    itemClass,
                    canUp: !this.orderLocked && i > 0,
                    canDown: !this.orderLocked && i < this.orderItems.length - 1
                };
            });
        }

        return {
            ...q,
            orderItemsWithState,
            optionsWithState: q.options ? q.options.map((text, i) => {
                let cssClass = 'gt-opt';
                let showCheck = false;
                let showCross = false;
                if (this.answered) {
                    if (i === q.correct) {
                        cssClass = 'gt-opt gt-opt-is-correct';
                        showCheck = true;
                    } else if (i === this.selectedAnswer && i !== q.correct) {
                        cssClass = 'gt-opt gt-opt-is-wrong';
                        showCross = true;
                    } else {
                        cssClass = 'gt-opt gt-opt-disabled';
                    }
                }
                return { index: i, text, letter: LETTERS[i], cssClass, showCheck, showCross };
            }) : []
        };
    }

    get isOrderQuestion() {
        const q = this.questions[this.currentIndex];
        return q && q.isOrder;
    }

    get isMcqOrPuzzle() {
        const q = this.questions[this.currentIndex];
        return q && !q.isOrder;
    }

    get questionNumber() { return this.currentIndex + 1; }
    get totalQuestions()  { return this.questions.length; }

    get progressStyle() {
        const pct = ((this.currentIndex + 1) / this.questions.length) * 100;
        return `width:${pct}%`;
    }

    get timerStyle() {
        if (!this.currentQuestion.timeLimit) return 'width:100%';
        const pct = (this.timeLeft / this.currentQuestion.timeLimit) * 100;
        return `width:${pct}%`;
    }

    get timerFillClass() {
        if (!this.currentQuestion.timeLimit) return 'gt-q-timer-fill';
        const ratio = this.timeLeft / this.currentQuestion.timeLimit;
        if (ratio > 0.5) return 'gt-q-timer-fill gt-timer-green';
        if (ratio > 0.25) return 'gt-q-timer-fill gt-timer-yellow';
        return 'gt-q-timer-fill gt-timer-red';
    }

    get timerTextClass() {
        if (!this.currentQuestion.timeLimit) return 'gt-timer-text';
        const ratio = this.timeLeft / this.currentQuestion.timeLimit;
        if (ratio > 0.5) return 'gt-timer-text';
        if (ratio > 0.25) return 'gt-timer-text gt-timer-text-warn';
        return 'gt-timer-text gt-timer-text-danger';
    }

    /* ── Circular timer getters ── */
    get timeLeftFormatted() {
        return this.timeLeft < 10 ? '0' + this.timeLeft : '' + this.timeLeft;
    }

    get circularTimerClass() {
        if (!this.currentQuestion.timeLimit) return 'gt-circular-timer';
        const ratio = this.timeLeft / this.currentQuestion.timeLimit;
        if (ratio > 0.5) return 'gt-circular-timer';
        if (ratio > 0.25) return 'gt-circular-timer gt-ctimer-warn';
        return 'gt-circular-timer gt-ctimer-danger';
    }

    get circleStrokeDash() {
        const circumference = 2 * Math.PI * 34; // r=34
        const ratio = this.currentQuestion.timeLimit ? this.timeLeft / this.currentQuestion.timeLimit : 1;
        const offset = circumference * (1 - ratio);
        return `stroke-dasharray:${circumference.toFixed(1)};stroke-dashoffset:${offset.toFixed(1)}`;
    }

    get liveScore() {
        return this.answers.reduce((s, a) => s + a.points, 0);
    }

    /* ═══════ GETTERS — Results ═══════ */
    get correctCount() {
        return this.answers.filter(a => a.correct).length;
    }

    get totalTimeFormatted() {
        const secs = this.answers.reduce((s, a) => s + a.timeSpent, 0);
        const m = Math.floor(secs / 60);
        const s = secs % 60;
        return m > 0 ? `${m}m ${s}s` : `${s}s`;
    }

    get speedBonusTotal() {
        const bonus = this.answers.filter(a => a.speedBonus).length;
        return `${bonus} × ⚡`;
    }

    get ringDashStyle() {
        const circumference = 326.73;
        const offset = circumference - (circumference * this.displayScore / 100);
        return `stroke-dashoffset:${offset}`;
    }

    get ringFillClass() {
        if (this.finalScore >= 80) return 'gt-r-ring-fill gt-ring-excellent';
        if (this.finalScore >= 60) return 'gt-r-ring-fill gt-ring-good';
        if (this.finalScore >= 40) return 'gt-r-ring-fill gt-ring-mid';
        return 'gt-r-ring-fill gt-ring-fail';
    }

    get answersReview() {
        return this.answers.map((a, i) => {
            const q = this.questions[i];
            return {
                id: a.id,
                num: i + 1,
                questionShort: q ? (q.question.length > 50 ? q.question.substring(0, 50) + '…' : q.question) : '',
                icon: a.correct ? '✓' : '✕',
                iconClass: a.correct ? 'gt-rv-icon gt-rv-ok' : 'gt-rv-icon gt-rv-ko',
                points: a.points,
                rowClass: a.correct ? 'gt-rv-row gt-rv-row-ok' : 'gt-rv-row gt-rv-row-ko'
            };
        });
    }
}

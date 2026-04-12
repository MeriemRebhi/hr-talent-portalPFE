import { LightningElement, track, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import getInterviewInfo from '@salesforce/apex/TechnicalInterviewController.getInterviewInfo';
import getProblems from '@salesforce/apex/TechnicalInterviewController.getProblems';
import evaluateAnswer from '@salesforce/apex/TechnicalInterviewController.evaluateAnswer';
import submitInterviewResults from '@salesforce/apex/TechnicalInterviewController.submitInterviewResults';
import requestReschedule from '@salesforce/apex/TechnicalInterviewController.requestReschedule';

export default class EntretienTechnique extends LightningElement {

    /* ────────── State Machine ────────── */
    @track step = 'loading'; // loading | error | done | wait | welcome | interview | submitting | results

    /* ────────── IDs ────────── */
    oppId;
    jobPostingId;

    /* ────────── Interview info ────────── */
    @track candidateName = '';
    @track jobTitle = '';
    @track existingScore = 0;
    @track meetLink = '';
    @track scheduledDate = null;
    @track interviewDuration = '';

    /* ────────── Problems ────────── */
    @track problems = [];
    @track currentIndex = 0;
    @track answers = [];       // { answer, score, feedback, criteriaResults, evaluated, timeSpent }

    /* ────────── Timer ────────── */
    @track timeRemaining = 0;
    timeLimitCurrent = 0;
    _timerInterval = null;
    _problemStartTime = 0;

    /* ────────── Evaluation ────────── */
    @track isEvaluating = false;

    /* ────────── Results ────────── */
    @track resultsData = {};

    /* ────────── Error ────────── */
    @track errorMessage = '';

    /* ────────── Reschedule ────────── */
    @track rescheduleRequested = false;
    @track showRescheduleModal = false;
    @track rescheduleReason = '';
    @track isRescheduling = false;
    @track rescheduleSuccess = false;

    /* ═══════════ COMPUTED ═══════════ */

    get canReschedule() {
        return !this.rescheduleRequested && !this.rescheduleSuccess && this.scheduledDate;
    }

    get showRescheduleAlready() {
        return this.rescheduleRequested && !this.rescheduleSuccess;
    }

    get scheduledDateFormatted() {
        if (!this.scheduledDate) return '';
        try {
            const d = new Date(this.scheduledDate);
            const pad = n => String(n).padStart(2, '0');
            return `${pad(d.getDate())}/${pad(d.getMonth()+1)}/${d.getFullYear()} à ${pad(d.getHours())}:${pad(d.getMinutes())}`;
        } catch (e) {
            return '';
        }
    }

    /* ═══════════ LIFECYCLE ═══════════ */

    @wire(CurrentPageReference)
    setPageRef(ref) {
        if (ref && ref.state && ref.state.id) {
            this.oppId = ref.state.id;
        }
    }

    connectedCallback() {
        // Small delay to allow wire to run
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => { this._loadInterview(); }, 300);
    }

    disconnectedCallback() {
        this._clearTimer();
    }

    /* ═══════════ LOAD INTERVIEW ═══════════ */

    async _loadInterview() {
        try {
            if (!this.oppId) {
                // Try to extract from URL
                const url = new URL(window.location.href);
                this.oppId = url.searchParams.get('id');
            }
            if (!this.oppId) {
                this.errorMessage = 'Aucun entretien trouvé. Vérifiez le lien reçu par email.';
                this.step = 'error';
                return;
            }

            const info = await getInterviewInfo({ oppId: this.oppId });

            this.candidateName = info.candidateName || 'Candidat';
            this.jobTitle = info.jobTitle || '';
            this.jobPostingId = info.jobPostingId;
            this.existingScore = info.existingScore || 0;
            this.meetLink = info.meetLink || '';
            this.scheduledDate = info.scheduledDate || null;

            // Format duration
            const dur = info.duration || '';
            if (dur === '30') this.interviewDuration = '30 minutes';
            else if (dur === '45') this.interviewDuration = '45 minutes';
            else if (dur === '60') this.interviewDuration = '1 heure';
            else if (dur === '90') this.interviewDuration = '1h30';
            else this.interviewDuration = dur ? dur + ' min' : '';

            // Track reschedule status
            this.rescheduleRequested = info.rescheduleRequested || false;

            if (info.alreadyCompleted) {
                this.step = 'done';
                return;
            }
            if (!info.hasProblems) {
                this.step = 'wait';
                return;
            }

            // Load problems
            const probs = await getProblems({ jobPostingId: this.jobPostingId });
            if (!probs || probs.length === 0) {
                this.step = 'wait';
                return;
            }

            this.problems = probs;
            this.answers = probs.map(() => ({
                answer: '',
                score: null,
                feedback: '',
                criteriaResults: null,
                evaluated: false,
                timeSpent: 0
            }));

            this.step = 'welcome';
        } catch (err) {
            this.errorMessage = err.body ? err.body.message : (err.message || 'Erreur inconnue.');
            this.step = 'error';
        }
    }

    /* ═══════════ START INTERVIEW ═══════════ */

    startInterview() {
        this.currentIndex = 0;
        this.step = 'interview';
        this._startProblemTimer();
    }

    /* ═══════════ RESCHEDULE ═══════════ */

    openRescheduleModal() { this.showRescheduleModal = true; }
    closeRescheduleModal() { this.showRescheduleModal = false; this.rescheduleReason = ''; }
    handleRescheduleReason(e) { this.rescheduleReason = e.target.value; }
    stopPropagation(e) { e.stopPropagation(); }

    async confirmReschedule() {
        this.isRescheduling = true;
        try {
            await requestReschedule({
                oppId: this.oppId,
                reason: this.rescheduleReason
            });
            this.rescheduleSuccess = true;
            this.rescheduleRequested = true;
            this.showRescheduleModal = false;
            this.rescheduleReason = '';
        } catch (err) {
            this.errorMessage = err.body ? err.body.message : 'Erreur lors de la demande de report.';
        } finally {
            this.isRescheduling = false;
        }
    }

    /* ═══════════ TIMER ═══════════ */

    _startProblemTimer() {
        this._clearTimer();
        const prob = this.problems[this.currentIndex];
        this.timeLimitCurrent = prob.timeLimit || 600;
        this.timeRemaining = this.timeLimitCurrent;
        this._problemStartTime = Date.now();

        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._timerInterval = setInterval(() => {
            this.timeRemaining--;
            if (this.timeRemaining <= 0) {
                this._clearTimer();
                this.timeRemaining = 0;
                // Auto-submit if not yet evaluated
                if (!this.answers[this.currentIndex].evaluated) {
                    this.submitAnswer();
                }
            }
        }, 1000);
    }

    _clearTimer() {
        if (this._timerInterval) {
            clearInterval(this._timerInterval);
            this._timerInterval = null;
        }
    }

    /* ═══════════ ANSWER HANDLING ═══════════ */

    handleAnswerChange(event) {
        const val = event.target.value;
        this.answers = this.answers.map((a, i) =>
            i === this.currentIndex ? { ...a, answer: val } : a
        );
    }

    /* ═══════════ SUBMIT ANSWER ═══════════ */

    async submitAnswer() {
        if (this.isEvaluating || this.answers[this.currentIndex].evaluated) return;

        this._clearTimer();
        const timeSpent = Math.round((Date.now() - this._problemStartTime) / 1000);
        const answer = this.answers[this.currentIndex].answer || '';
        const prob = this.problems[this.currentIndex];

        this.isEvaluating = true;

        try {
            const result = await evaluateAnswer({
                questionId: prob.id,
                candidateAnswer: answer,
                timeSpent: timeSpent
            });

            this.answers = this.answers.map((a, i) => {
                if (i === this.currentIndex) {
                    return {
                        ...a,
                        score: result.score,
                        feedback: result.feedback,
                        criteriaResults: result.criteriaResults || [],
                        evaluated: true,
                        timeSpent: timeSpent
                    };
                }
                return a;
            });
        } catch (err) {
            // Fallback — mark as evaluated with 0
            this.answers = this.answers.map((a, i) => {
                if (i === this.currentIndex) {
                    return { ...a, score: 0, feedback: 'Erreur d\'évaluation. Votre réponse a été enregistrée.', evaluated: true, timeSpent: timeSpent };
                }
                return a;
            });
        } finally {
            this.isEvaluating = false;
        }
    }

    /* ═══════════ NAVIGATION ═══════════ */

    navigateToProblem(event) {
        const idx = parseInt(event.currentTarget.dataset.index, 10);
        if (idx === this.currentIndex) return;
        this._clearTimer();
        this.currentIndex = idx;
        if (!this.answers[idx].evaluated) {
            this._startProblemTimer();
        }
    }

    prevProblem() {
        if (this.currentIndex > 0) {
            this._clearTimer();
            this.currentIndex--;
            if (!this.answers[this.currentIndex].evaluated) {
                this._startProblemTimer();
            }
        }
    }

    nextProblem() {
        if (this.currentIndex < this.problems.length - 1) {
            this._clearTimer();
            this.currentIndex++;
            if (!this.answers[this.currentIndex].evaluated) {
                this._startProblemTimer();
            }
        }
    }

    /* ═══════════ FINISH INTERVIEW ═══════════ */

    async finishInterview() {
        this._clearTimer();
        this.step = 'submitting';

        // Calculate average score from evaluated answers
        let totalScore = 0;
        let answeredCount = 0;
        let totalTime = 0;

        this.answers.forEach(a => {
            if (a.evaluated) {
                totalScore += (a.score || 0);
                answeredCount++;
            }
            totalTime += (a.timeSpent || 0);
        });

        const avgScore = answeredCount > 0
            ? Math.round((totalScore / answeredCount) * 10) / 10
            : 0;

        try {
            const result = await submitInterviewResults({
                oppId: this.oppId,
                technicalScore: avgScore,
                answeredCount: answeredCount,
                totalProblems: this.problems.length,
                timeSpentSeconds: totalTime
            });

            this.resultsData = {
                ...result,
                totalTime: totalTime
            };
            this.step = 'results';
        } catch (err) {
            this.errorMessage = 'Erreur lors de la soumission: ' + (err.body ? err.body.message : err.message);
            this.step = 'error';
        }
    }

    /* ═══════════ GETTERS — STEP VISIBILITY ═══════════ */

    get isLoading()          { return this.step === 'loading'; }
    get hasError()           { return this.step === 'error'; }
    get alreadyCompleted()   { return this.step === 'done'; }
    get noProblems()         { return this.step === 'wait'; }
    get isWelcome()          { return this.step === 'welcome'; }
    get isInterview()        { return this.step === 'interview'; }
    get isSubmitting()       { return this.step === 'submitting'; }
    get isResults()          { return this.step === 'results'; }

    /* ═══════════ GETTERS — CANDIDATE INFO ═══════════ */

    get initials() {
        if (!this.candidateName) return '?';
        const parts = this.candidateName.trim().split(/\s+/);
        return parts.length >= 2
            ? (parts[0][0] + parts[parts.length - 1][0]).toUpperCase()
            : parts[0].substring(0, 2).toUpperCase();
    }

    /* ═══════════ GETTERS — PROBLEM NAVIGATION ═══════════ */

    get totalProblems()        { return this.problems.length; }
    get currentProblemDisplay() { return this.currentIndex + 1; }

    get currentProblemText()   { return this.problems[this.currentIndex]?.problem || ''; }
    get currentProblemType()   { return this.problems[this.currentIndex]?.type || 'code'; }
    get currentProblemDifficulty() { return this.problems[this.currentIndex]?.difficulty || 'medium'; }
    get currentTimeLimit()     { return this.problems[this.currentIndex]?.timeLimit || 600; }
    get currentAnswer()        { return this.answers[this.currentIndex]?.answer || ''; }

    get currentProblemEvaluated() { return this.answers[this.currentIndex]?.evaluated === true; }
    get currentProblemScore()     { return this.answers[this.currentIndex]?.score || 0; }
    get currentProblemFeedback()  { return this.answers[this.currentIndex]?.feedback || ''; }

    get currentCriteriaResults() {
        const cr = this.answers[this.currentIndex]?.criteriaResults;
        if (!cr || cr.length === 0) return null;
        return cr.map(c => ({
            ...c,
            barStyle: `width: ${Math.round((c.score / c.max) * 100)}%`
        }));
    }

    get currentTypeBadgeClass() {
        const t = this.currentProblemType;
        return 'type-badge type-' + (t === 'code' ? 'code' : t === 'architecture' ? 'arch' : 'debug');
    }

    get currentDiffBadgeClass() {
        const d = this.currentProblemDifficulty;
        return 'diff-badge diff-' + (d === 'easy' ? 'easy' : d === 'hard' ? 'hard' : 'medium');
    }

    /* ═══════════ GETTERS — TIMER ═══════════ */

    get timerDisplay() {
        const m = Math.floor(this.timeRemaining / 60);
        const s = this.timeRemaining % 60;
        return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
    }

    get timerClass() {
        return 'timer-text' + (this.timeRemaining <= 30 ? ' timer-danger' : this.timeRemaining <= 60 ? ' timer-warn' : '');
    }

    get timerCircleStyle() {
        const pct = this.timeLimitCurrent > 0 ? this.timeRemaining / this.timeLimitCurrent : 1;
        const circumference = 2 * Math.PI * 20;
        const offset = circumference * (1 - pct);
        const color = this.timeRemaining <= 30 ? '#ef4444' : this.timeRemaining <= 60 ? '#f59e0b' : '#22c55e';
        return `stroke-dasharray: ${circumference}; stroke-dashoffset: ${offset}; stroke: ${color};`;
    }

    /* ═══════════ GETTERS — LIVE SCORE ═══════════ */

    get liveScore() {
        let total = 0;
        let count = 0;
        this.answers.forEach(a => {
            if (a.evaluated) {
                total += (a.score || 0);
                count++;
            }
        });
        return count > 0 ? Math.round(total / count) : 0;
    }

    /* ═══════════ GETTERS — PROBLEM INDICATORS ═══════════ */

    get problemIndicators() {
        return this.problems.map((p, i) => {
            let cls = 'indicator';
            if (i === this.currentIndex) cls += ' indicator-active';
            if (this.answers[i]?.evaluated) {
                const s = this.answers[i].score || 0;
                cls += s >= 70 ? ' indicator-good' : s >= 40 ? ' indicator-ok' : ' indicator-bad';
            }
            return { index: i, displayNumber: i + 1, className: cls };
        });
    }

    /* ═══════════ GETTERS — NAVIGATION BUTTONS ═══════════ */

    get canGoBack()       { return this.currentIndex > 0; }
    get canGoNext()       { return this.currentIndex < this.problems.length - 1; }
    get canSubmitAnswer() { return !this.answers[this.currentIndex]?.evaluated; }

    get canFinish() {
        // Can finish when all problems are evaluated or on the last problem
        const allEvaluated = this.answers.every(a => a.evaluated);
        return allEvaluated || (this.currentIndex === this.problems.length - 1 && this.answers[this.currentIndex]?.evaluated);
    }

    /* ═══════════ GETTERS — RESULTS ═══════════ */

    get compositeScoreDisplay() { return Math.round(this.resultsData.compositeScore || 0); }
    get technicalScoreDisplay() { return Math.round(this.resultsData.technicalScore || 0); }
    get gamingScoreDisplay()    { return Math.round(this.resultsData.gamingScore || 0); }
    get matchingScoreDisplay()  { return Math.round(this.resultsData.matchingScore || 0); }
    get answeredCount()         { return this.resultsData.answeredCount || 0; }

    get totalTimeDisplay() {
        const t = this.resultsData.totalTime || 0;
        const m = Math.floor(t / 60);
        const s = t % 60;
        return `${m}m ${s}s`;
    }

    get resultRingStyle() {
        const pct = (this.resultsData.compositeScore || 0) / 100;
        const circumference = 2 * Math.PI * 65;
        const offset = circumference * (1 - pct);
        const score = this.resultsData.compositeScore || 0;
        const color = score >= 70 ? '#22c55e' : score >= 50 ? '#f59e0b' : '#ef4444';
        return `stroke-dasharray: ${circumference}; stroke-dashoffset: ${offset}; stroke: ${color}; transition: stroke-dashoffset 1.5s ease;`;
    }

    /* ═══════════ GETTERS — PROBLEM REVIEW ═══════════ */

    get problemReview() {
        return this.problems.map((p, i) => {
            const a = this.answers[i] || {};
            const score = a.score || 0;
            return {
                index: i,
                type: p.type,
                difficulty: p.difficulty,
                score: Math.round(score),
                feedback: a.feedback || '',
                typeBadgeClass: 'type-badge type-' + (p.type === 'code' ? 'code' : p.type === 'architecture' ? 'arch' : 'debug'),
                diffBadgeClass: 'diff-badge diff-' + (p.difficulty === 'easy' ? 'easy' : p.difficulty === 'hard' ? 'hard' : 'medium'),
                scoreClass: 'review-score ' + (score >= 70 ? 'score-good' : score >= 40 ? 'score-ok' : 'score-bad')
            };
        });
    }
}

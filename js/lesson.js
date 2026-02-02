/**
 * Gerenciamento de Aulas do Velociclos
 * Controla navegação, progresso e estado de conclusão
 */

class LessonManager {
    constructor(lessonId, courseId, totalLessons = 6) {
        this.lessonId = lessonId;
        this.courseId = courseId;
        this.totalLessons = totalLessons;
        this.currentLessonIndex = this.extractLessonNumber(lessonId);
        
        this.init();
    }

    init() {
        this.setupNavigation();
        this.setupCompletion();
        this.restoreState();
    }

    extractLessonNumber(id) {
        // Exemplo: f1-1 -> 1, f1-2 -> 2
        const parts = id.split('-');
        return parseInt(parts[parts.length - 1]) || 1;
    }

    setupNavigation() {
        const prevBtn = document.getElementById('prev-lesson');
        const nextBtn = document.getElementById('next-lesson');
        const counter = document.querySelector('.lesson-counter');

        if (counter) {
            counter.textContent = `${this.currentLessonIndex} de ${this.totalLessons}`;
        }

        if (prevBtn) {
            if (this.currentLessonIndex <= 1) {
                prevBtn.disabled = true;
                prevBtn.classList.add('disabled');
            } else {
                prevBtn.addEventListener('click', () => this.navigate(-1));
            }
        }

        if (nextBtn) {
            if (this.currentLessonIndex >= this.totalLessons) {
                nextBtn.textContent = 'Concluir Curso';
                nextBtn.addEventListener('click', () => {
                    this.markAsCompleted();
                    if(window.showToast) window.showToast('Parabéns! Curso concluído!', 'success');
                });
            } else {
                nextBtn.addEventListener('click', () => this.navigate(1));
            }
        }
    }

    navigate(direction) {
        // Lógica simples para encontrar o próximo arquivo
        // Assumindo padrão f1-1.html -> f1-2.html
        const prefix = this.lessonId.substring(0, this.lessonId.lastIndexOf('-') + 1); // f1-
        const nextNum = this.currentLessonIndex + direction;
        const nextFile = `${prefix}${nextNum}.html`;
        
        window.location.href = nextFile;
    }

    setupCompletion() {
        window.markAsCompleted = () => this.markAsCompleted();
    }

    markAsCompleted() {
        // Salvar no localStorage
        const key = `velociclos_progress_${this.courseId}`;
        let progress = JSON.parse(localStorage.getItem(key) || '[]');
        
        if (!progress.includes(this.lessonId)) {
            progress.push(this.lessonId);
            localStorage.setItem(key, JSON.stringify(progress));
            
            // Atualizar UI
            const btn = document.querySelector('.lesson-actions button');
            if (btn) {
                btn.innerHTML = '<i class="fas fa-check-circle"></i> Aula Concluída';
                btn.classList.add('completed');
                btn.disabled = true;
            }
            
            if (window.showToast) {
                window.showToast('Aula marcada como concluída!', 'success');
            }
            
            // Atualizar barra de progresso (visual)
            this.updateProgressBar(progress.length);
        }
    }

    restoreState() {
        const key = `velociclos_progress_${this.courseId}`;
        const progress = JSON.parse(localStorage.getItem(key) || '[]');
        
        if (progress.includes(this.lessonId)) {
            const btn = document.querySelector('.lesson-actions button');
            if (btn) {
                btn.innerHTML = '<i class="fas fa-check-circle"></i> Concluída';
                btn.classList.add('completed');
                btn.disabled = true;
            }
        }
        
        // Calcular progresso para barra
        // Se for a primeira vez abrindo, pode ser 0 ou baseado no histórico
        // Aqui vamos simplificar e usar a posição da aula atual
        const percent = Math.round((this.currentLessonIndex / this.totalLessons) * 100);
        const progressBar = document.querySelector('.progress-fill');
        const progressText = document.querySelector('.progress-text');
        
        if (progressBar) progressBar.style.width = `${percent}%`;
        if (progressText) progressText.textContent = `${percent}% concluído`;
    }

    updateProgressBar(completedCount) {
        // Atualização mais realista baseada em aulas concluídas reais
        // Mas por enquanto mantém visual simples da aula atual
    }
}

// Inicializador Global
window.initializeLesson = function(lessonId, courseId) {
    new LessonManager(lessonId, courseId);
};

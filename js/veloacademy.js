/**
 * VeloAcademy - Sistema de Cursos
 * Criado por Kilo Code
 */

// Função para inicializar o sistema de cursos
function initCourseSystem() {
    // Inicializar filtros de cursos
    initCourseFilters();

    // Inicializar navegação para cursos
    initCourseNavigation();

    // Inicializar animações
    initAnimations();

    // Inicializar transições de página
    initPageTransitions();
}

// Função para inicializar filtros de cursos
function initCourseFilters() {
    const filterButtons = document.querySelectorAll('.filter-btn');
    const courseCards = document.querySelectorAll('.course-card-modern');

    filterButtons.forEach(button => {
        button.addEventListener('click', function() {
            const filter = this.getAttribute('data-filter');

            // Atualizar botões ativos
            filterButtons.forEach(btn => btn.classList.remove('active'));
            this.classList.add('active');

            // Filtrar cursos
            courseCards.forEach(card => {
                if (filter === 'all' || card.getAttribute('data-category') === filter) {
                    card.style.display = 'flex';
                    setTimeout(() => {
                        card.style.opacity = '1';
                        card.style.transform = 'translateY(0)';
                    }, 50);
                } else {
                    card.style.opacity = '0';
                    card.style.transform = 'translateY(20px)';
                    setTimeout(() => {
                        card.style.display = 'none';
                    }, 300);
                }
            });
        });
    });
}

// Função para inicializar navegação para cursos
function initCourseNavigation() {
    const detailButtons = document.querySelectorAll('.course-btn');

    detailButtons.forEach(button => {
        button.addEventListener('click', function() {
            // Obter informações do curso a partir do card
            const courseCard = this.closest('.course-card-modern');
            const courseTitle = courseCard.querySelector('h3').textContent;

            // Mapear títulos de cursos para URLs
            const courseUrls = {
                'Forex para Iniciantes': 'cursos-estáticos/forex-iniciante/f1-1.html',
                'Análise Técnica Básica': 'cursos-estáticos/analise-tecnica-basica/at1-1.html',
                'Gestão de Risco Avançada': 'cursos-estáticos/gestão-risco-avançada/gr1-1.html',
                'Estratégias de Trading': 'cursos-estáticos/estrategias-trading/et1-1.html',
                'Psicologia do Trader': 'cursos-estáticos/pscicologia-trader/pt1-1.html',
                'Expert Advisor Velociclos': 'cursos-estáticos/expert-advisor-velociclos/ea1-1.html'
            };

            // Redirecionar para a página do curso
            const courseUrl = courseUrls[courseTitle];
            if (courseUrl) {
                window.location.href = courseUrl;
            } else {
                console.error('URL não encontrada para o curso:', courseTitle);
                alert('Página do curso não encontrada. Entre em contato com o suporte.');
            }
        });
    });
}

// Função para navegar para página de curso (mantida para compatibilidade)
function navigateToCourse(courseTitle) {
    // Mapear títulos de cursos para URLs
    const courseUrls = {
        'Forex para Iniciantes': 'cursos-estáticos/forex-iniciante/f1-1.html',
        'Análise Técnica Básica': 'cursos-estáticos/analise-tecnica-basica/at1-1.html',
        'Gestão de Risco Avançada': 'cursos-estáticos/gestão-risco-avançada/gr1-1.html',
        'Estratégias de Trading': 'cursos-estáticos/estrategias-trading/et1-1.html',
        'Psicologia do Trader': 'cursos-estáticos/pscicologia-trader/pt1-1.html',
        'Expert Advisor Velociclos': 'cursos-estáticos/expert-advisor-velociclos/ea1-1.html'
    };

    // Redirecionar para a página do curso
    const courseUrl = courseUrls[courseTitle];
    if (courseUrl) {
        window.location.href = courseUrl;
    } else {
        console.error('URL não encontrada para o curso:', courseTitle);
        alert('Página do curso não encontrada. Entre em contato com o suporte.');
    }
}

// Função para fechar modal
function closeModal() {
    const modal = document.getElementById('course-modal');
    if (modal) {
        modal.style.opacity = '0';
        setTimeout(() => {
            modal.style.display = 'none';
        }, 300);
    }
}

// Função para inicializar animações
function initAnimations() {
    // Animação de entrada para os cards
    const cards = document.querySelectorAll('.course-card-modern');
    cards.forEach((card, index) => {
        setTimeout(() => {
            card.style.opacity = '1';
            card.style.transform = 'translateY(0)';
        }, index * 100);
    });
}

// Função para inicializar transições de página
function initPageTransitions() {
    // Criar elemento de transição se não existir
    if (!document.querySelector('.page-transition')) {
        const transitionElement = document.createElement('div');
        transitionElement.className = 'page-transition';
        document.body.appendChild(transitionElement);
    }

    // Adicionar evento para links internos
    document.querySelectorAll('a[href^="./"]').forEach(link => {
        link.addEventListener('click', function(e) {
            if (this.getAttribute('href') !== './cursos.html') {
                e.preventDefault();
                const href = this.getAttribute('href');
                triggerPageTransition(href);
            }
        });
    });
}

// Função para disparar transição de página
function triggerPageTransition(href) {
    const transitionElement = document.querySelector('.page-transition');
    const currentBg = getComputedStyle(document.body).backgroundColor;

    // Ativar transição
    transitionElement.style.backgroundColor = currentBg;
    transitionElement.classList.add('active');

    // Após a transição, redirecionar
    setTimeout(() => {
        window.location.href = href;
    }, 800);
}

// Função para scroll suave
function scrollToCourses() {
    document.getElementById('courses-section').scrollIntoView({
        behavior: 'smooth'
    });
}

// Inicializar sistema quando o DOM estiver pronto
document.addEventListener('DOMContentLoaded', function() {
    initCourseSystem();
});

// Exportar funções para uso global
window.scrollToCourses = scrollToCourses;
window.openCourseModal = openCourseModal;
window.closeModal = closeModal;
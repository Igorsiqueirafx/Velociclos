// sistema de Toggle de Tema - IMPLEMENTADO SEGUINDO GUIDELINE
// Velociclos - Sistema de Design

// Estado do tema
let isDarkMode = false;

// Função para alternar tema
const toggleDarkMode = () => {
    isDarkMode = !isDarkMode;
    
    if (isDarkMode) {
        document.documentElement.classList.add('dark');
        localStorage.setItem('Velociclos-theme', 'dark');
        updateThemeIcon(true);
    } else {
        document.documentElement.classList.remove('dark');
        localStorage.setItem('Velociclos-theme', 'light');
        updateThemeIcon(false);
    }
};

// Função para atualizar ícone do tema
const updateThemeIcon = (isDark) => {
    const themeWrapper = document.querySelector('.theme-switch-wrapper');
    if (themeWrapper) {
        const sunIcon = themeWrapper.querySelector('.bx-sun');
        const moonIcon = themeWrapper.querySelector('.bx-moon');

        if (sunIcon && moonIcon) {
            // Garantir estado limpo
            sunIcon.classList.remove('active');
            moonIcon.classList.remove('active');

            if (isDark) {
                // Mostrar lua
                moonIcon.classList.add('active');
                console.log('🌙 Ativando tema escuro (lua)');
            } else {
                // Mostrar sol
                sunIcon.classList.add('active');
                console.log('☀️ Ativando tema claro (sol)');
            }
            
            console.log('🎯 Ícones atualizados:', {
                sun: sunIcon.classList.contains('active'),
                moon: moonIcon.classList.contains('active')
            });
        } else {
            console.warn('⚠️ Ícones não encontrados!', { sunIcon, moonIcon });
        }
    }
};

// Função para aplicar tema salvo ao carregar
const applySavedTheme = () => {
    const savedTheme = localStorage.getItem('Velociclos-theme') || 'light';
    const isDark = savedTheme === 'dark';

    if (isDark) {
        document.documentElement.classList.add('dark');
        isDarkMode = true;
    } else {
        document.documentElement.classList.remove('dark');
        isDarkMode = false;
    }
    updateThemeIcon(isDark);
};

// Função para detectar preferência do sistema
const detectSystemTheme = () => {
    if (window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches) {
        return 'dark';
    }
    return 'light';
};

// Função para aplicar tema do sistema se não houver preferência salva
const applySystemTheme = () => {
    if (!localStorage.getItem('Velociclos-theme')) {
        const SystemTheme = detectSystemTheme();
        if (SystemTheme === 'dark') {
            document.documentElement.classList.add('dark');
            isDarkMode = true;
            updateThemeIcon(true);
        }
    }
};

// Função otimizada para detectar nível de zoom do navegador
const detectZoomLevel = () => {
    try {
        // Método 1: Visual Viewport API (mais preciso para zoom 100%)
        if (window.visualViewport) {
            const zoom = window.visualViewport.scale;
            return Math.round(zoom * 100) / 100;
        }
        
        // Método 2: Device Pixel Ratio
        const dpr = window.devicePixelRatio || 1;
        const zoom = Math.round(dpr * 100) / 100;
        
        // Método 3: Teste de elemento (fallback)
        const testElement = document.createElement('div');
        testElement.style.width = '100px';
        testElement.style.height = '100px';
        testElement.style.position = 'absolute';
        testElement.style.top = '-9999px';
        document.body.appendChild(testElement);

        const rect = testElement.getBoundingClientRect();
        document.body.removeChild(testElement);

        const calculatedZoom = Math.round((rect.width / 100) * 100) / 100;
        
        // Retornar o valor mais confiável
        return zoom !== 1 ? zoom : calculatedZoom;
        
    } catch (error) {
        console.warn('Erro na detecção de zoom:', error);
        return 1; // Fallback para zoom 100%
    }
};

// Função otimizada para atualizar propriedades CSS baseadas no zoom
const updateZoomCSS = (zoomLevel) => {
    const root = document.documentElement;

    // Definir variável CSS para zoom
    root.style.setProperty('--zoom-factor', zoomLevel);

    // Aplicar classes baseadas no nível de zoom (otimizado para 100%)
    root.classList.remove('zoom-low', 'zoom-normal', 'zoom-high', 'zoom-extreme');

    // Tolerância de 5% para zoom 100% (0.95 - 1.05)
    const ZOOM_TOLERANCE = 0.05;
    
    if (zoomLevel >= (1 - ZOOM_TOLERANCE) && zoomLevel <= (1 + ZOOM_TOLERANCE)) {
        // Zoom 100% (padrão otimizado)
        root.classList.add('zoom-normal');
        // Log apenas em desenvolvimento
        if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
            console.log(`✅ Zoom 100% detectado (${zoomLevel}) - Classe: zoom-normal`);
        }
    } else if (zoomLevel < 0.8) {
        root.classList.add('zoom-low');
        // Log apenas em desenvolvimento
        if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
            console.log(`📉 Zoom baixo detectado (${zoomLevel}) - Classe: zoom-low`);
        }
    } else if (zoomLevel <= 1.5) {
        root.classList.add('zoom-high');
        // Log apenas em desenvolvimento
        if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
            console.log(`📈 Zoom alto detectado (${zoomLevel}) - Classe: zoom-high`);
        }
    } else {
        root.classList.add('zoom-extreme');
        // Log apenas em desenvolvimento
        if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
            console.log(`⚠️ Zoom extremo detectado (${zoomLevel}) - Classe: zoom-extreme`);
        }
    }
};

// Função otimizada para monitorar mudanças de zoom
const setupZoomMonitoring = () => {
    let lastZoom = detectZoomLevel();
    updateZoomCSS(lastZoom);
    
    // Log apenas em desenvolvimento
    if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
        console.log(`🎯 Zoom inicial detectado: ${lastZoom}`);
    }

    // Verificar zoom periodicamente (otimizado para zoom 100%)
    const checkZoom = () => {
        const currentZoom = detectZoomLevel();
        const ZOOM_SENSITIVITY = 0.01; // Sensibilidade mais alta para zoom 100%
        
        if (Math.abs(currentZoom - lastZoom) > ZOOM_SENSITIVITY) {
            lastZoom = currentZoom;
            updateZoomCSS(currentZoom);
        }
    };

    // Intervalo otimizado
    setInterval(checkZoom, 300); // Verificar a cada 300ms

    // Event listeners melhorados
    window.addEventListener('resize', () => {
        setTimeout(checkZoom, 100);
    });

    // Visual Viewport change (mais preciso para zoom 100%)
    if (window.visualViewport) {
        window.visualViewport.addEventListener('resize', () => {
            setTimeout(checkZoom, 50);
        });
        
        window.visualViewport.addEventListener('scroll', () => {
            setTimeout(checkZoom, 25);
        });
    }

    // Detectar mudanças de orientação
    window.addEventListener('orientationchange', () => {
        setTimeout(checkZoom, 500);
    });
};

// Event Listeners
document.addEventListener('DOMContentLoaded', () => {
    // Aplicar tema salvo
    applySavedTheme();

    // Aplicar tema do sistema se não houver preferência
    applySystemTheme();

    // Configurar monitoramento de zoom
    setupZoomMonitoring();

    // Adicionar listener para o botão de tema com melhor debugging
    const themeSwitch = document.querySelector('.theme-switch-wrapper');
    if (themeSwitch) {
        console.log('🎯 Botão de tema encontrado, adicionando listener...');
        themeSwitch.addEventListener('click', (e) => {
            console.log('🔄 Click no botão de tema detectado!');
            e.preventDefault();
            e.stopPropagation();
            toggleDarkMode();
        });
        
        // Adicionar também touch para dispositivos móveis
        themeSwitch.addEventListener('touchstart', (e) => {
            console.log('👆 Touch no botão de tema detectado!');
            toggleDarkMode();
        });
    } else {
        console.error('❌ Botão de tema NÃO encontrado!');
        console.log('🔍 Elementos disponíveis:', document.querySelectorAll('[class*="theme"]'));
    }

    // Listener para mudanças na preferência do sistema
    if (window.matchMedia) {
        window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', (e) => {
            if (!localStorage.getItem('Velociclos-theme')) {
                if (e.matches) {
                    document.documentElement.classList.add('dark');
                    isDarkMode = true;
                    updateThemeIcon(true);
                } else {
                    document.documentElement.classList.remove('dark');
                    isDarkMode = false;
                    updateThemeIcon(false);
                }
            }
        });
    }
    
    // Log do estado inicial
    console.log('🎨 Estado inicial do tema:', {
        isDarkMode,
        theme: localStorage.getItem('Velociclos-theme') || 'light',
        hasDarkClass: document.documentElement.classList.contains('dark')
    });
});

// Exportar funções para uso externo
window.VelociclosTheme = {
    toggle: toggleDarkMode,
    isDark: () => isDarkMode,
    getCurrentTheme: () => isDarkMode ? 'dark' : 'light'
};

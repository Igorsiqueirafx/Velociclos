// Sistema de autenticação básico
class AuthManager {
    constructor() {
        this.user = null;
        this.init();
    }

    init() {
        this.checkAuthStatus();
        this.setupAuthButtons();
    }

    checkAuthStatus() {
        const sessionData = localStorage.getItem('Velociclos_user_session');
        if (sessionData) {
            try {
                this.user = JSON.parse(sessionData);
                this.showAuthenticatedState();
            } catch (error) {
                console.error('Erro na sessão:', error);
                this.clearSession();
            }
        } else {
            this.showUnauthenticatedState();
        }
    }

    updateUserInfo() {
        if (!this.user) return;

        // Atualizar nome do usuário
        const userNameElement = document.getElementById('user-name');
        if (userNameElement) {
            userNameElement.textContent = this.user.name || 'Usuário';
        }

        // Atualizar avatar do usuário
        const userAvatarElement = document.getElementById('user-avatar');
        if (userAvatarElement) {
            if (this.user.picture) {
                userAvatarElement.src = this.user.picture;
                userAvatarElement.classList.remove('hidden');
                userAvatarElement.alt = `Avatar de ${this.user.name || 'Usuário'}`;
            } else {
                // Usar avatar padrão se não houver imagem
                userAvatarElement.src = 'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMzIiIGhlaWdodD0iMzIiIHZpZXdCb3g9IjAgMCAzMiAzMiIgZmlsbD0ibm9uZSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj4KPGNpcmNsZSBjeD0iMTYiIGN5PSIxNiIgcj0iMTYiIGZpbGw9IiMxNjM0RkYiLz4KPHBhdGggZD0iTTIyIDIxYzAtMS45LTEuMS0zLjYtMi43LTQuN0MxOC4zIDE1LjEgMTcgMTMuNiAxNyAxM3MtMS4zLTEtMi4zLTFoLTUuNGMtMSAwLTEuMyAxLTEuMyAyIDAgMS40IDEgMi43IDIuMyA0LjJDOS43IDE3LjQgOC43IDE5LjEgOC43IDIxIiBmaWxsPSJ3aGl0ZSIvPgo8L3N2Zz4=';
                userAvatarElement.classList.remove('hidden');
                userAvatarElement.alt = `Avatar padrão de ${this.user.name || 'Usuário'}`;
            }
        }
    }

    showAuthenticatedState() {
        // Mostrar elementos para usuário logado
        const userInfo = document.getElementById('user-info');
        if (userInfo) {
            userInfo.classList.remove('hidden');
            userInfo.classList.add('visible');
        }

        // Atualizar informações do usuário
        this.updateUserInfo();

        // Esconder botões de login
        const loginButtons = document.querySelectorAll('.login-btn');
        loginButtons.forEach(btn => btn.classList.add('hidden'));
    }

    showUnauthenticatedState() {
        // Esconder elementos de usuário
        const userInfo = document.getElementById('user-info');
        if (userInfo) {
            userInfo.classList.remove('visible');
            userInfo.classList.add('hidden');
        }

        // Mostrar botões de login
        const loginButtons = document.querySelectorAll('.login-btn');
        loginButtons.forEach(btn => btn.classList.remove('hidden'));
    }

    setupAuthButtons() {
        // Botão de login simulado
        const loginBtn = document.getElementById('login-btn');
        if (loginBtn) {
            loginBtn.addEventListener('click', () => this.simulateLogin());
        }

        // Botão de logout
        const logoutBtn = document.getElementById('logout-btn');
        if (logoutBtn) {
            logoutBtn.addEventListener('click', () => this.logout());
        }
    }

    simulateLogin() {
        // Simulação de login para desenvolvimento
        const mockUser = {
            id: 'user123',
            name: 'Usuário Teste',
            email: 'teste@velociclos.com',
            picture: null,
            loginTime: new Date().toISOString()
        };

        this.user = mockUser;
        localStorage.setItem('Velociclos_user_session', JSON.stringify(mockUser));
        this.showAuthenticatedState();

        if (window.showToast) {
            window.showToast('Login realizado com sucesso!', 'success');
        }

        // Recarregar página para atualizar estado
        setTimeout(() => location.reload(), 1000);
    }

    logout() {
        if (confirm('Tem certeza que deseja sair?')) {
            this.clearSession();
            this.showUnauthenticatedState();

            if (window.showToast) {
                window.showToast('Logout realizado com sucesso!', 'info');
            }

            // Recarregar página
            setTimeout(() => location.reload(), 500);
        }
    }

    clearSession() {
        localStorage.removeItem('Velociclos_user_session');
        this.user = null;
    }

    isAuthenticated() {
        return this.user !== null;
    }

    getCurrentUser() {
        return this.user;
    }
}

// Inicializar autenticação
document.addEventListener('DOMContentLoaded', () => {
    window.authManager = new AuthManager();
});
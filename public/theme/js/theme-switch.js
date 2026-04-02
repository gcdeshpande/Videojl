(function() {
    const storedTheme = localStorage.getItem('theme') || 'light';
    document.documentElement.setAttribute('data-theme', storedTheme);

    window.addEventListener('DOMContentLoaded', (event) => {
        const toggleBtn = document.getElementById('theme-toggle');
        if (toggleBtn) {
            updateToggleIcon(storedTheme);
            toggleBtn.addEventListener('click', () => {
                const currentTheme = document.documentElement.getAttribute('data-theme');
                const newTheme = currentTheme === 'light' ? 'dark' : 'light';
                
                document.documentElement.setAttribute('data-theme', newTheme);
                localStorage.setItem('theme', newTheme);
                updateToggleIcon(newTheme);
            });
        }
    });

    function updateToggleIcon(theme) {
        const toggleBtn = document.getElementById('theme-toggle');
        if (!toggleBtn) return;
        if (theme === 'dark') {
            toggleBtn.innerHTML = '<i class="fa fa-sun-o"></i>';
            toggleBtn.title = 'Switch to Light Theme';
        } else {
            toggleBtn.innerHTML = '<i class="fa fa-moon-o"></i>';
            toggleBtn.title = 'Switch to Dark Theme';
        }
    }
})();

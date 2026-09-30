// views/window_controller.js — Контроллер главного окна приложения (сессия, геометрия, жизненный цикл)
.pragma library

function initWindow(window, backend) {
    if (!window || !backend || typeof backend.get_session_config !== "function") return
    try {
        var sess = backend.get_session_config()
        if (sess) {
            if (typeof sess.win_width === "number" && sess.win_width >= window.minimumWidth) {
                window.width = sess.win_width
            }
            if (typeof sess.win_height === "number" && sess.win_height >= window.minimumHeight) {
                window.height = sess.win_height
            }
        }
    } catch(e) {}
}

function handleLoaderLoaded(window, item, backend) {
    if (item) {
        item.appWindow = window
        if (typeof item.applyInitialState === "function") {
            item.applyInitialState()
        }
    }
    if (backend && typeof backend.register_window === "function") {
        backend.register_window(window, item)
    }
}

function saveWindowGeometry(window, backend) {
    if (!window || !backend || typeof backend.save_window_geometry !== "function") return
    // Window.Maximized в Qt = 4
    if (window.visibility !== 4) {
        backend.save_window_geometry(window.x, window.y, window.width, window.height)
    }
}

function handleWindowClosing(window, backend) {
    if (backend && typeof backend.unregister_window === "function") {
        backend.unregister_window(window)
    }
}

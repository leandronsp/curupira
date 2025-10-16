// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/curupira"
import topbar from "../vendor/topbar"

const Hooks = {}

Hooks.AutoResize = {
  mounted() {
    this.resize()
    this.el.addEventListener('input', () => this.resize())
  },
  updated() {
    this.resize()
  },
  resize() {
    this.el.style.height = 'auto'
    this.el.style.height = this.el.scrollHeight + 'px'
  }
}

// Combined hook for title textarea: AutoResize + Keyboard shortcuts with undo/redo
Hooks.TitleEditor = {
  mounted() {
    // Initialize undo/redo history
    this.history = [this.el.value]
    this.historyIndex = 0
    this.maxHistory = 50

    // AutoResize functionality
    this.resize()
    this.el.addEventListener('input', () => this.resize())

    // Keyboard shortcuts
    this.setupKeyboardShortcuts()
  },
  updated() {
    this.resize()
  },
  resize() {
    this.el.style.height = 'auto'
    this.el.style.height = this.el.scrollHeight + 'px'
  },
  setupKeyboardShortcuts() {
    this.el.addEventListener('keydown', (e) => {
      const isMac = navigator.platform.toUpperCase().indexOf('MAC') >= 0
      const modifier = isMac ? e.metaKey : e.ctrlKey

      if (!modifier) return

      // Undo: Cmd/Ctrl + Z (without Shift)
      if (e.key === 'z' && !e.shiftKey) {
        e.preventDefault()
        this.undo()
        return
      }

      // Redo: Cmd/Ctrl + Shift + Z
      if (e.key === 'z' && e.shiftKey) {
        e.preventDefault()
        this.redo()
        return
      }

      // Save: Cmd/Ctrl + S
      if (e.key === 's') {
        e.preventDefault()
        const submitButton = document.querySelector('button[type="submit"][form="article-form"]')
        if (submitButton) {
          submitButton.click()
        }
        return
      }

      // Bold: Cmd/Ctrl + B
      if (e.key === 'b') {
        e.preventDefault()
        this.toggleFormatting('**', '**')
        return
      }

      // Italic: Cmd/Ctrl + I
      if (e.key === 'i') {
        e.preventDefault()
        this.toggleFormatting('*', '*')
        return
      }
    })
  },
  saveToHistory() {
    this.history = this.history.slice(0, this.historyIndex + 1)
    this.history.push(this.el.value)
    if (this.history.length > this.maxHistory) {
      this.history.shift()
    } else {
      this.historyIndex++
    }
  },
  undo() {
    if (this.historyIndex > 0) {
      this.historyIndex--
      const value = this.history[this.historyIndex]
      this.el.value = value
      this.el.dispatchEvent(new Event('input', { bubbles: true }))
      this.resize()
    }
  },
  redo() {
    if (this.historyIndex < this.history.length - 1) {
      this.historyIndex++
      const value = this.history[this.historyIndex]
      this.el.value = value
      this.el.dispatchEvent(new Event('input', { bubbles: true }))
      this.resize()
    }
  },
  toggleFormatting(before, after) {
    const start = this.el.selectionStart
    const end = this.el.selectionEnd
    const text = this.el.value
    const selectedText = text.substring(start, end)

    if (start !== end) {
      const beforeStart = start - before.length
      const afterEnd = end + after.length
      const textBefore = text.substring(beforeStart, start)
      const textAfter = text.substring(end, afterEnd)

      if (textBefore === before && textAfter === after) {
        // Remove formatting
        const newText = text.substring(0, beforeStart) + selectedText + text.substring(afterEnd)
        this.el.value = newText
        this.saveToHistory()
        this.el.dispatchEvent(new Event('input', { bubbles: true }))
        this.el.setSelectionRange(beforeStart, beforeStart + selectedText.length)
      } else {
        // Add formatting
        const newText = text.substring(0, start) + before + selectedText + after + text.substring(end)
        this.el.value = newText
        this.saveToHistory()
        this.el.dispatchEvent(new Event('input', { bubbles: true }))
        const newCursorPos = start + before.length + selectedText.length + after.length
        this.el.setSelectionRange(newCursorPos, newCursorPos)
      }
    } else {
      const newText = text.substring(0, start) + before + after + text.substring(end)
      this.el.value = newText
      this.saveToHistory()
      this.el.dispatchEvent(new Event('input', { bubbles: true }))
      const newCursorPos = start + before.length
      this.el.setSelectionRange(newCursorPos, newCursorPos)
    }

    this.el.focus()
    this.resize()
  }
}

Hooks.ConfirmDelete = {
  mounted() {
    this.el.addEventListener('click', (e) => {
      e.preventDefault()
      e.stopPropagation()

      if (confirm('Are you sure you want to delete this article?')) {
        const id = this.el.getAttribute('phx-value-id')
        this.pushEvent('delete', {id: id})
      }
    })
  }
}

Hooks.TagInput = {
  mounted() {
    this.el.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') {
        e.preventDefault()
        const value = this.el.value.trim()
        if (value) {
          this.pushEvent('add_tag', {value: value})
          this.el.value = ''
        }
      } else if (e.key === 'Backspace' && this.el.value === '') {
        e.preventDefault()
        this.pushEvent('remove_last_tag', {})
      }
    })

    this.el.addEventListener('input', (e) => {
      this.pushEvent('update_tag_input', {value: e.target.value})
    })
  }
}

Hooks.PreserveScroll = {
  mounted() {
    this.scrollTop = 0
    this.el.addEventListener('scroll', () => {
      this.scrollTop = this.el.scrollTop
    })
  },
  beforeUpdate() {
    this.scrollTop = this.el.scrollTop
  },
  updated() {
    this.el.scrollTop = this.scrollTop
  }
}

Hooks.PreviewAnchorScroll = {
  mounted() {
    this.setupAnchorNavigation()
  },
  updated() {
    this.setupAnchorNavigation()
  },
  setupAnchorNavigation() {
    // Find all anchor links in the preview
    const anchorLinks = this.el.querySelectorAll('a[href^="#"]')

    anchorLinks.forEach(link => {
      link.addEventListener('click', (e) => {
        e.preventDefault()
        e.stopPropagation()

        const href = link.getAttribute('href').substring(1)
        // Decode URL-encoded characters in the href
        const targetId = decodeURIComponent(href)

        // Try to find the target element by ID
        let targetElement = this.el.querySelector(`#${CSS.escape(targetId)}`)

        // If not found, try with the raw href (for cases where IDs are already encoded)
        if (!targetElement) {
          targetElement = this.el.querySelector(`#${CSS.escape(href)}`)
        }

        if (targetElement) {
          // Smooth scroll to the target element within the preview container
          targetElement.scrollIntoView({
            behavior: 'smooth',
            block: 'start'
          })
        }
      })
    })
  }
}

// Markdown editor with keyboard shortcuts and undo/redo
// Available shortcuts (Cmd on Mac, Ctrl on Windows/Linux):
//   - Cmd/Ctrl + S: Save article
//   - Cmd/Ctrl + B: Toggle bold (**text**)
//   - Cmd/Ctrl + I: Toggle italic (*text*)
//   - Cmd/Ctrl + E: Toggle inline code (`code`)
//   - Cmd/Ctrl + K: Insert link ([text](url))
//   - Cmd/Ctrl + Shift + X: Toggle strikethrough (~~text~~)
//   - Cmd/Ctrl + Shift + K: Toggle code block (```code```)
//   - Cmd/Ctrl + Z: Undo
//   - Cmd/Ctrl + Shift + Z: Redo
Hooks.MarkdownEditor = {
  mounted() {
    // Initialize undo/redo history
    this.history = [this.el.value]
    this.historyIndex = 0
    this.maxHistory = 50

    this.el.addEventListener('keydown', (e) => {
      const isMac = navigator.platform.toUpperCase().indexOf('MAC') >= 0
      const modifier = isMac ? e.metaKey : e.ctrlKey

      // Only handle shortcuts when modifier key is pressed
      if (!modifier) return

      // Undo: Cmd/Ctrl + Z (without Shift)
      if (e.key === 'z' && !e.shiftKey) {
        e.preventDefault()
        this.undo()
        return
      }

      // Redo: Cmd/Ctrl + Shift + Z
      if (e.key === 'z' && e.shiftKey) {
        e.preventDefault()
        this.redo()
        return
      }

      // Save: Cmd/Ctrl + S
      if (e.key === 's') {
        e.preventDefault()
        const submitButton = document.querySelector('button[type="submit"][form="article-form"]')
        if (submitButton) {
          submitButton.click()
        }
        return
      }

      // Bold: Cmd/Ctrl + B
      if (e.key === 'b') {
        e.preventDefault()
        this.toggleFormatting('**', '**')
        return
      }

      // Italic: Cmd/Ctrl + I
      if (e.key === 'i') {
        e.preventDefault()
        this.toggleFormatting('*', '*')
        return
      }

      // Inline Code: Cmd/Ctrl + E
      if (e.key === 'e') {
        e.preventDefault()
        this.toggleFormatting('`', '`')
        return
      }

      // Strikethrough: Cmd/Ctrl + Shift + X
      if (e.key === 'X' && e.shiftKey) {
        e.preventDefault()
        this.toggleFormatting('~~', '~~')
        return
      }

      // Code Block: Cmd/Ctrl + Shift + K
      if (e.key === 'K' && e.shiftKey) {
        e.preventDefault()
        this.toggleFormatting('\n```\n', '\n```\n')
        return
      }

      // Link: Cmd/Ctrl + K
      if (e.key === 'k') {
        e.preventDefault()
        this.insertLink()
        return
      }
    })
  },

  saveToHistory() {
    // Remove any future history if we're not at the end
    this.history = this.history.slice(0, this.historyIndex + 1)

    // Add current state
    this.history.push(this.el.value)

    // Keep history size limited
    if (this.history.length > this.maxHistory) {
      this.history.shift()
    } else {
      this.historyIndex++
    }
  },

  undo() {
    if (this.historyIndex > 0) {
      this.historyIndex--
      const value = this.history[this.historyIndex]
      this.el.value = value
      this.el.dispatchEvent(new Event('input', { bubbles: true }))
    }
  },

  redo() {
    if (this.historyIndex < this.history.length - 1) {
      this.historyIndex++
      const value = this.history[this.historyIndex]
      this.el.value = value
      this.el.dispatchEvent(new Event('input', { bubbles: true }))
    }
  },

  toggleFormatting(before, after) {
    const start = this.el.selectionStart
    const end = this.el.selectionEnd
    const text = this.el.value
    const selectedText = text.substring(start, end)

    // If there's a selection
    if (start !== end) {
      // Check if the selection is already wrapped with the formatting
      const beforeStart = start - before.length
      const afterEnd = end + after.length
      const textBefore = text.substring(beforeStart, start)
      const textAfter = text.substring(end, afterEnd)

      if (textBefore === before && textAfter === after) {
        // Remove formatting
        const newText = text.substring(0, beforeStart) + selectedText + text.substring(afterEnd)
        this.el.value = newText
        this.saveToHistory()
        this.el.dispatchEvent(new Event('input', { bubbles: true }))

        // Set cursor position to the unwrapped text
        this.el.setSelectionRange(beforeStart, beforeStart + selectedText.length)
      } else {
        // Add formatting
        const newText = text.substring(0, start) + before + selectedText + after + text.substring(end)
        this.el.value = newText
        this.saveToHistory()
        this.el.dispatchEvent(new Event('input', { bubbles: true }))

        // Set cursor position after the wrapped text
        const newCursorPos = start + before.length + selectedText.length + after.length
        this.el.setSelectionRange(newCursorPos, newCursorPos)
      }
    } else {
      // No selection, insert markers and place cursor between them
      const newText = text.substring(0, start) + before + after + text.substring(end)
      this.el.value = newText
      this.saveToHistory()
      this.el.dispatchEvent(new Event('input', { bubbles: true }))

      // Place cursor between the markers
      const newCursorPos = start + before.length
      this.el.setSelectionRange(newCursorPos, newCursorPos)
    }

    this.el.focus()
  },

  insertLink() {
    const start = this.el.selectionStart
    const end = this.el.selectionEnd
    const text = this.el.value
    const selectedText = text.substring(start, end)

    if (selectedText) {
      // If text is selected, use it as link text
      const newText = text.substring(0, start) + '[' + selectedText + '](url)' + text.substring(end)
      this.el.value = newText
      this.saveToHistory()
      this.el.dispatchEvent(new Event('input', { bubbles: true }))

      // Select "url" so user can type the URL
      const urlStart = start + selectedText.length + 3
      this.el.setSelectionRange(urlStart, urlStart + 3)
    } else {
      // No selection, insert template
      const newText = text.substring(0, start) + '[text](url)' + text.substring(end)
      this.el.value = newText
      this.saveToHistory()
      this.el.dispatchEvent(new Event('input', { bubbles: true }))

      // Select "text" so user can type link text
      this.el.setSelectionRange(start + 1, start + 5)
    }

    this.el.focus()
  }
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, ...Hooks},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}


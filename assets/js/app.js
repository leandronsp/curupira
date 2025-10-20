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

// Combined hook for title textarea: AutoResize + Keyboard shortcuts (no custom undo/redo - use browser native)
Hooks.TitleEditor = {
  mounted() {
    // Auto-save state
    this.autoSaveTimeout = null

    // AutoResize functionality
    this.resize()
    this.el.addEventListener('input', (e) => {
      this.resize()
      this.handleInput(e)
    })

    // Keyboard shortcuts (formatting only, undo/redo is native browser)
    this.setupKeyboardShortcuts()
  },
  handleInput(e) {
    // Auto-save after 5 seconds of inactivity
    clearTimeout(this.autoSaveTimeout)
    this.autoSaveTimeout = setTimeout(() => {
      const form = document.getElementById('article-form')
      if (form) {
        const submitEvent = new Event('submit', { bubbles: true, cancelable: true })
        form.dispatchEvent(submitEvent)
      }
    }, 5000)
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

      const key = e.key.toLowerCase()

      // NOTE: Undo/Redo (Ctrl+Z / Ctrl+Shift+Z) is handled natively by the browser
      // We don't intercept these - browser native undo/redo works perfectly

      // Save: Cmd/Ctrl + S
      if (key === 's') {
        e.preventDefault()
        const submitButton = document.querySelector('button[type="submit"][form="article-form"]')
        if (submitButton) {
          submitButton.click()
        }
        return false
      }

      // Bold: Cmd/Ctrl + B
      if (key === 'b') {
        e.preventDefault()
        this.toggleFormatting('**', '**')
        return false
      }

      // Italic: Cmd/Ctrl + I
      if (key === 'i') {
        e.preventDefault()
        this.toggleFormatting('*', '*')
        return false
      }
    })
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
        this.el.dispatchEvent(new Event('input', { bubbles: true }))
        this.el.setSelectionRange(beforeStart, beforeStart + selectedText.length)
      } else {
        // Add formatting
        const newText = text.substring(0, start) + before + selectedText + after + text.substring(end)
        this.el.value = newText
        this.el.dispatchEvent(new Event('input', { bubbles: true }))
        const newCursorPos = start + before.length + selectedText.length + after.length
        this.el.setSelectionRange(newCursorPos, newCursorPos)
      }
    } else {
      const newText = text.substring(0, start) + before + after + text.substring(end)
      this.el.value = newText
      this.el.dispatchEvent(new Event('input', { bubbles: true }))
      const newCursorPos = start + before.length
      this.el.setSelectionRange(newCursorPos, newCursorPos)
    }

    this.el.focus()
    this.resize()
  }
}

// Markdown content editor with keyboard shortcuts (no custom undo/redo - use browser native)
Hooks.MarkdownEditor = {
  mounted() {
    // Auto-save state
    this.autoSaveTimeout = null

    // Setup input handler
    this.el.addEventListener('input', (e) => {
      this.handleInput(e)
    })

    // Keyboard shortcuts (formatting only, undo/redo is native browser)
    this.setupKeyboardShortcuts()

    // Listen for image upload completion from server
    this.handleEvent("image-uploaded", ({url}) => {
      this.insertImageAtCursor(url)
    })

    // Setup paste support for images
    this.setupPasteUpload()
  },
  handleInput(e) {
    // Auto-save after 5 seconds of inactivity
    clearTimeout(this.autoSaveTimeout)
    this.autoSaveTimeout = setTimeout(() => {
      const form = document.getElementById('article-form')
      if (form) {
        const submitEvent = new Event('submit', { bubbles: true, cancelable: true })
        form.dispatchEvent(submitEvent)
      }
    }, 5000)
  },
  setupPasteUpload() {
    this.el.addEventListener('paste', (e) => {
      const items = e.clipboardData?.items
      if (!items) return

      for (let item of items) {
        if (item.type.startsWith('image/')) {
          e.preventDefault()
          const file = item.getAsFile()

          // Find the LiveView file input (has data-phx-upload-ref attribute)
          const fileInput = document.querySelector('input[data-phx-upload-ref]')
          if (fileInput) {
            // Create a new FileList-like object
            const dataTransfer = new DataTransfer()
            dataTransfer.items.add(file)

            // Assign files to input
            fileInput.files = dataTransfer.files

            // Dispatch input event that LiveView listens to
            const event = new Event('input', { bubbles: true })
            fileInput.dispatchEvent(event)
          }
          break
        }
      }
    })
  },
  insertImageAtCursor(url) {
    const textarea = this.el
    const start = textarea.selectionStart
    const end = textarea.selectionEnd
    const text = textarea.value
    const selectedText = text.substring(start, end)

    // Use selected text as alt text, or default to "image"
    const altText = selectedText || "image"
    const imageMarkdown = `![${altText}](${url})`

    const newText = text.substring(0, start) + imageMarkdown + text.substring(end)
    textarea.value = newText
    textarea.dispatchEvent(new Event('input', { bubbles: true }))

    // Position cursor after the inserted image
    const newCursorPos = start + imageMarkdown.length
    textarea.setSelectionRange(newCursorPos, newCursorPos)
    textarea.focus()
  },
  setupKeyboardShortcuts() {
    this.el.addEventListener('keydown', (e) => {
      const isMac = navigator.platform.toUpperCase().indexOf('MAC') >= 0
      const modifier = isMac ? e.metaKey : e.ctrlKey

      if (!modifier) return

      const key = e.key.toLowerCase()

      // NOTE: Undo/Redo (Ctrl+Z / Ctrl+Shift+Z) is handled natively by the browser
      // We don't intercept these - browser native undo/redo works perfectly

      // Save: Cmd/Ctrl + S
      if (key === 's') {
        e.preventDefault()
        const submitButton = document.querySelector('button[type="submit"][form="article-form"]')
        if (submitButton) {
          submitButton.click()
        }
        return false
      }

      // Bold: Cmd/Ctrl + B
      if (key === 'b') {
        e.preventDefault()
        this.toggleFormatting('**', '**')
        return false
      }

      // Italic: Cmd/Ctrl + I
      if (key === 'i') {
        e.preventDefault()
        this.toggleFormatting('*', '*')
        return false
      }

      // Code: Cmd/Ctrl + E
      if (key === 'e') {
        e.preventDefault()
        this.toggleFormatting('`', '`')
        return false
      }

      // Link: Cmd/Ctrl + K
      if (key === 'k' && !e.shiftKey) {
        e.preventDefault()
        this.insertLink()
        return false
      }

      // Strikethrough: Cmd/Ctrl + Shift + X
      if (key === 'x' && e.shiftKey) {
        e.preventDefault()
        this.toggleFormatting('~~', '~~')
        return false
      }

      // Code Block: Cmd/Ctrl + Shift + K
      if (key === 'k' && e.shiftKey) {
        e.preventDefault()
        this.toggleCodeBlock()
        return false
      }
    })
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
        this.el.dispatchEvent(new Event('input', { bubbles: true }))
        this.el.setSelectionRange(beforeStart, beforeStart + selectedText.length)
      } else {
        // Add formatting
        const newText = text.substring(0, start) + before + selectedText + after + text.substring(end)
        this.el.value = newText
        this.el.dispatchEvent(new Event('input', { bubbles: true }))
        const newCursorPos = start + before.length + selectedText.length + after.length
        this.el.setSelectionRange(newCursorPos, newCursorPos)
      }
    } else {
      const newText = text.substring(0, start) + before + after + text.substring(end)
      this.el.value = newText
      this.el.dispatchEvent(new Event('input', { bubbles: true }))
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

    const linkText = selectedText || 'link text'
    const linkFormat = `[${linkText}](url)`

    const newText = text.substring(0, start) + linkFormat + text.substring(end)
    this.el.value = newText
    this.el.dispatchEvent(new Event('input', { bubbles: true }))

    // Select the URL part
    const urlStart = start + linkText.length + 3
    const urlEnd = urlStart + 3
    this.el.setSelectionRange(urlStart, urlEnd)
    this.el.focus()
  },
  toggleCodeBlock() {
    const start = this.el.selectionStart
    const end = this.el.selectionEnd
    const text = this.el.value
    const selectedText = text.substring(start, end)

    // Find the start of the current line
    let lineStart = start
    while (lineStart > 0 && text[lineStart - 1] !== '\n') {
      lineStart--
    }

    // Find the end of the current line
    let lineEnd = end
    while (lineEnd < text.length && text[lineEnd] !== '\n') {
      lineEnd++
    }

    const before = '```\n'
    const after = '\n```'

    // Check if already in code block
    const checkStart = Math.max(0, lineStart - 4)
    const checkEnd = Math.min(text.length, lineEnd + 4)
    const surrounding = text.substring(checkStart, checkEnd)

    if (surrounding.includes('```')) {
      // Try to remove code block
      const beforeBlock = text.substring(checkStart, lineStart)
      const afterBlock = text.substring(lineEnd, checkEnd)

      if (beforeBlock.trim() === '```' || beforeBlock.endsWith('\n```\n')) {
        // Remove the code block markers
        let newLineStart = lineStart
        while (newLineStart > 0 && text.substring(newLineStart - 4, newLineStart) !== '```\n') {
          newLineStart--
        }
        newLineStart -= 4

        let newLineEnd = lineEnd
        while (newLineEnd < text.length && text.substring(newLineEnd, newLineEnd + 4) !== '\n```') {
          newLineEnd++
        }
        newLineEnd += 4

        const newText = text.substring(0, newLineStart) + text.substring(newLineStart + 4, newLineEnd - 4) + text.substring(newLineEnd)
        this.el.value = newText
        this.el.dispatchEvent(new Event('input', { bubbles: true }))
        this.el.setSelectionRange(start - 4, end - 4)
        this.el.focus()
        return
      }
    }

    // Add code block
    const newText = text.substring(0, lineStart) + before + text.substring(lineStart, lineEnd) + after + text.substring(lineEnd)
    this.el.value = newText
    this.el.dispatchEvent(new Event('input', { bubbles: true }))
    this.el.setSelectionRange(lineStart + before.length, lineEnd + before.length)
    this.el.focus()
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
    this.userScrolling = false
    this.scrollTimeout = null

    // Track user manual scrolling
    this.el.addEventListener('scroll', () => {
      this.userScrolling = true
      clearTimeout(this.scrollTimeout)
      // Reset after 2 seconds of no scrolling
      this.scrollTimeout = setTimeout(() => {
        this.userScrolling = false
      }, 2000)
    })
  },
  updated() {
    this.setupAnchorNavigation()

    // Auto-scroll to bottom when preview updates (user is typing)
    // Only if user hasn't manually scrolled recently
    if (!this.userScrolling) {
      // Small delay to ensure DOM is fully rendered
      setTimeout(() => {
        this.el.scrollTop = this.el.scrollHeight
      }, 50)
    }
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

Hooks.ThemeToggle = {
  mounted() {
    // Load theme from localStorage or default to 'light'
    const savedTheme = localStorage.getItem('theme') || 'light'
    this.setTheme(savedTheme)

    this.el.addEventListener('click', () => {
      const currentTheme = document.documentElement.getAttribute('data-theme')
      const newTheme = currentTheme === 'dark' ? 'light' : 'dark'
      this.setTheme(newTheme)
      localStorage.setItem('theme', newTheme)
    })
  },
  setTheme(theme) {
    document.documentElement.setAttribute('data-theme', theme)

    // Update icon visibility
    const sunIcon = this.el.querySelector('.sun-icon')
    const moonIcon = this.el.querySelector('.moon-icon')

    if (sunIcon && moonIcon) {
      if (theme === 'dark') {
        sunIcon.classList.remove('hidden')
        moonIcon.classList.add('hidden')
      } else {
        sunIcon.classList.add('hidden')
        moonIcon.classList.remove('hidden')
      }
    }
  }
}

Hooks.InlineEdit = {
  mounted() {
    this.el.addEventListener('blur', () => {
      const field = this.el.getAttribute('phx-value-field')
      const value = this.el.value

      // Push event to server
      this.pushEvent('update_profile', { field: field, value: value })
    })
  }
}

Hooks.BioEditor = {
  mounted() {
    // Auto-resize functionality
    this.resize()
    this.el.addEventListener('input', () => this.resize())

    // Save on blur
    this.el.addEventListener('blur', () => {
      const field = this.el.getAttribute('phx-value-field')
      const value = this.el.value
      this.pushEvent('update_profile', { field: field, value: value })
    })
  },
  updated() {
    this.resize()
  },
  resize() {
    this.el.style.height = 'auto'
    this.el.style.height = this.el.scrollHeight + 'px'
  }
}

Hooks.PaginationScroll = {
  mounted() {
    // Store initial state from URL
    const urlParams = new URLSearchParams(window.location.search)
    this.previousPage = urlParams.get('page') || '1'
    this.previousQuery = urlParams.get('q') || ''
  },
  updated() {
    // Get current state from URL
    const urlParams = new URLSearchParams(window.location.search)
    const currentPage = urlParams.get('page') || '1'
    const currentQuery = urlParams.get('q') || ''

    // Only scroll if:
    // - Page changed AND
    // - Search query stayed the same (not a new search)
    const pageChanged = currentPage !== this.previousPage
    const queryChanged = currentQuery !== this.previousQuery

    if (pageChanged && !queryChanged) {
      // Scroll to top of this container
      this.el.scrollIntoView({ behavior: 'smooth', block: 'start', inline: 'nearest' })

      // Also scroll window to absolute top to ensure bookmark is visible
      setTimeout(() => {
        const rect = this.el.getBoundingClientRect()
        const scrollTop = window.pageYOffset || document.documentElement.scrollTop
        const targetScroll = rect.top + scrollTop - 32 // 32px padding from top

        window.scrollTo({
          top: targetScroll,
          behavior: 'smooth'
        })
      }, 100)
    }

    // Update stored values
    this.previousPage = currentPage
    this.previousQuery = currentQuery
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


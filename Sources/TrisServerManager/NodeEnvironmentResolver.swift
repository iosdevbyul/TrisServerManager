import Foundation

enum NodeEnvironmentResolver {
    /// Applies only to Node-based launch commands; Swift and Docker services stay untouched.
    static func wrap(_ command: String) -> String {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        let executable = trimmed.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? ""
        guard ["node", "npm", "npx", "pnpm", "yarn", "corepack"].contains(executable) else {
            return "exec " + command
        }

        return """
        echo '[Environment] Inspecting Node.js runtime...'
        if command -v node >/dev/null 2>&1; then
          echo "[Environment] Initial Node.js: $(node -v) ($(command -v node))"
        else
          echo '[Environment] Node.js not found in the application shell.'
        fi
        export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
        if [ -s "$NVM_DIR/nvm.sh" ]; then
          echo '[Environment] Found local nvm installation; initializing...'
          . "$NVM_DIR/nvm.sh"
          if [ -f .nvmrc ]; then
            echo '[Environment] Project .nvmrc found; applying its version...'
            if ! nvm use --silent; then
              echo '[Environment] Could not activate .nvmrc version; no Node.js installation was attempted.'
            fi
          else
            echo '[Environment] Selecting latest locally installed Node.js through nvm...'
            if ! nvm use --silent node; then
              echo '[Environment] No suitable installed nvm Node.js could be activated.'
            fi
          fi
        else
          echo '[Environment] nvm not found; retaining the existing PATH.'
        fi
        if command -v node >/dev/null 2>&1; then
          echo "[Environment] Effective Node.js: $(node -v) ($(command -v node))"
        else
          echo '[Environment] Node.js is unavailable. Check the configured runtime.'
        fi
        echo '[Environment] Starting service command...'
        exec """ + command
    }
}

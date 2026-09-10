local map = vim.keymap.set

local function configure_debugging()
  vim.o.verbosefile = vim.fn.stdpath("state") .. "/nvim-debug.log"

  local function dlog(x)
    vim.cmd("silent verbose echomsg " .. vim.fn.string(vim.inspect(x)))
  end
  dlog('loading nixvim.lua')

  -- Set up termdebug configuration
  vim.g.termdebug_config = {
    -- Disable overriding the 'K' map globally to keep it clean.
    map_K = 0,
    -- We can set variables/disasm windows to 0 by default to avoid clutter.
    variables_window = 0,
  }

  -- Define custom commands to launch GDB / rust-gdb on demand
  vim.api.nvim_create_user_command("Gdb", function(opts)
    vim.g.termdebugger = "gdb"
    vim.cmd("packadd termdebug")
    if opts.args ~= "" then
      vim.cmd("Termdebug " .. opts.args)
    else
      vim.cmd("Termdebug")
    end
  end, { nargs = "?", complete = "file", desc = "Start termdebug with gdb" })

  vim.api.nvim_create_user_command("RustGdb", function(opts)
    if vim.fn.executable("rust-gdb") == 1 then
      vim.g.termdebugger = "rust-gdb"
    else
      vim.notify("rust-gdb not found in PATH; falling back to gdb", vim.log.levels.WARN)
      vim.g.termdebugger = "gdb"
    end
    vim.cmd("packadd termdebug")
    if opts.args ~= "" then
      vim.cmd("Termdebug " .. opts.args)
    else
      vim.cmd("Termdebug")
    end
  end, { nargs = "?", complete = "file", desc = "Start termdebug with rust-gdb" })

  -- Set up keymaps that only exist when a debugging session is active.
  local group = vim.api.nvim_create_augroup("TermdebugKeymaps", { clear = true })

  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "TermdebugStartPost",
    callback = function()
      map("n", "<leader>db", "<cmd>Break<CR>", { desc = "Debugger: Toggle breakpoint" })
      map("n", "<leader>dx", "<cmd>Clear<CR>", { desc = "Debugger: Clear breakpoint" })
      map("n", "<leader>dc", "<cmd>Continue<CR>", { desc = "Debugger: Continue" })
      map("n", "<leader>dn", "<cmd>Over<CR>", { desc = "Debugger: Step over (next)" })
      map("n", "<leader>di", "<cmd>Step<CR>", { desc = "Debugger: Step into (step)" })
      map("n", "<leader>do", "<cmd>Finish<CR>", { desc = "Debugger: Step out (finish)" })
      map("n", "<leader>de", "<cmd>Evaluate<CR>", { desc = "Debugger: Evaluate expression" })
      map("v", "<leader>de", ":Evaluate<CR>", { desc = "Debugger: Evaluate selection" })
    end,
  })

  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "TermdebugStopPre",
    callback = function()
      local active_maps = {
        "<leader>db", "<leader>dx", "<leader>dc", "<leader>dn",
        "<leader>di", "<leader>do", "<leader>de"
      }
      for _, lhs in ipairs(active_maps) do
        pcall(vim.keymap.del, "n", lhs)
      end
      pcall(vim.keymap.del, "v", "<leader>de")
    end,
  })
end

local function configure_syntax_highlighting()
  vim.cmd("syntax off")
  vim.api.nvim_create_autocmd("LspAttach", {
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if client then
        client.server_capabilities.semanticTokensProvider = nil
        vim.lsp.semantic_tokens.enable(false, { client_id = client.id })
      end

      vim.cmd("syntax off")
    end,
  })
end

local function configure_general_options()
  vim.opt.undodir = vim.fn.stdpath("data") .. "/.nvim-undo//"
  vim.fn.mkdir(vim.fn.stdpath("cache"), "p")

  -- leaving this off until I fix other formatting on newline issue
  -- disable comment continuation in normal mode
  -- vim.opt.formatoptions:remove("o")
  -- vim.api.nvim_create_autocmd("FileType", {
  --   group = vim.api.nvim_create_augroup("DisableNormalModeCommentContinuation", { clear = true }),
  --   callback = function()
  --     vim.opt_local.formatoptions:remove("o")
  --   end,
  -- })
end

local function configure_plugins()
  require("fidget").setup({})

  require("trouble").setup({
    position = "bottom",
    height = 10,
    width = 50,
    mode = "workspace_diagnostics",
    auto_open = false,
    auto_close = true,
    signs = {
      error = "",
      warning = "",
      hint = "",
      information = "",
      other = "",
    },
    use_diagnostic_signs = true,
  })
  map("n", "<leader>xx", "<cmd>Trouble diagnostics toggle<CR>", { desc = "Trouble: Workspace Diagnostics" })
  map("n", "<leader>xl", "<cmd>Trouble lsp toggle focus=false win.position=right<CR>",
    { desc = "Trouble: LSP Definitions / References" })
  map("n", "<leader>xq", "<cmd>Trouble qflist toggle<CR>", { desc = "Trouble: Quickfix List" })
  map("n", "<leader>xL", "<cmd>Trouble loclist toggle<CR>", { desc = "Trouble: Location List" })

  require("gitsigns").setup({
    signs = {
      add = { text = "+" },
      change = { text = "~" },
      delete = { text = "_" },
      topdelete = { text = "‾" },
      changedelete = { text = "~" },
    },
    on_attach = function(bufnr)
      local gs = package.loaded.gitsigns
      local trouble = require("trouble")

      local function gs_map(mode, lhs, rhs, opts)
        opts = opts or {}
        opts.buf = bufnr
        map(mode, lhs, rhs, opts)
      end

      gs_map("n", "<leader>hq", function()
        gs.setqflist(0, { use_location_list = true, open = false }, function(err)
          if err then
            vim.notify(err, vim.log.levels.ERROR)
            return
          end

          require("telescope.builtin").loclist({
            prompt_title = "Git hunks in buffer",
          })
        end)
      end, { desc = "Git hunks in buffer" })

      gs_map("n", "<leader>hQ", function()
        gs.setqflist("all", { open = false }, function()
          trouble.close("loclist")
          trouble.open({ mode = "qflist", focus = true, win = { position = "bottom", size = 0.15 } })
          require("telescope.builtin").loclist({
            prompt_title = "Git hunks in repo",
          })
        end)
      end, { desc = "Git hunks in repo" })

      gs_map("n", "]c", function()
        if vim.wo.diff then
          return "]c"
        end
        vim.schedule(function()
          gs.next_hunk()
        end)
        return "<Ignore>"
      end, { expr = true, desc = "Next Git hunk" })

      gs_map("n", "[c", function()
        if vim.wo.diff then
          return "[c"
        end
        vim.schedule(function()
          gs.prev_hunk()
        end)
        return "<Ignore>"
      end, { expr = true, desc = "Previous Git hunk" })

      gs_map("n", "<leader>hn", gs.next_hunk, { desc = "Next Git hunk" })
      gs_map("n", "<leader>hp", gs.prev_hunk, { desc = "Previous Git hunk" })
      gs_map("n", "<leader>hl", gs.preview_hunk, { desc = "Preview Git hunk" })
      gs_map("n", "<leader>hb", function()
        gs.blame_line({ full = true })
      end, { desc = "Git blame line" })
      gs_map("n", "<leader>hr", function()
        vim.ui.input({ prompt = "Are you sure? (y/n): " }, function(input)
          if input and (input:lower() == "y" or input:lower() == "yes") then
            gs.reset_hunk()
            print("Hunk reset")
          else
            print("Hunk reset cancelled")
          end
        end)
      end, { desc = "Reset Git hunk with confirmation" })
    end,
  })

  require("grug-far").setup({})

  vim.api.nvim_create_autocmd("CmdlineLeave", {
    group = vim.api.nvim_create_augroup("LeapOnSearch", { clear = true }),
    callback = function()
      local cmdtypes = {
        ["/"] = true,
        ["?"] = true,
      }

      local ev = vim.v.event
      local cmdtype = ev.cmdtype
      if not cmdtypes[cmdtype] or ev.abort then
        return
      end

      vim.schedule(function()
        -- CmdlineLeave fires before the search command has fully settled.
        vim.schedule(function()
          if vim.fn.searchcount().total <= 1 then
            return
          end

          local labels = require("leap").opts.safe_labels:gsub("[nN]", "")
          local vim_opts = { ["wo.conceallevel"] = vim.wo.conceallevel }
          require("leap").leap({
            pattern = vim.fn.getreg("/"),
            windows = { vim.fn.win_getid() },
            opts = { safe_labels = "", labels = labels, vim_opts = vim_opts },
          })
        end)
      end)
    end,
  })

  require("mini.surround").setup({
    highlight_duration = 500,
    mappings = {
      add = "sa",
      delete = "sd",
      find = "sf",
      find_left = "sF",
      highlight = "sh",
      replace = "sr",
      suffix_last = "l",
      suffix_next = "n",
    },
    n_lines = 20,
    respect_selection_type = false,
    search_method = "cover",
    silent = false,
  })
end

local function configure_treesitter()
  require("nvim-treesitter").setup({
    install_dir = vim.fn.stdpath("data") .. "/site",
    highlight = { enable = false },
  })

  vim.api.nvim_create_autocmd("FileType", {
    callback = function(ev)
      local parser = vim.treesitter.get_parser(ev.buf)
      if not parser then
        return
      end

      vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
    end,
  })

  require("nvim-treesitter-textobjects").setup({
    move = { set_jumps = true },
  })

  local ts_move = require("nvim-treesitter-textobjects.move")
  local ts_repeat_move = require("nvim-treesitter-textobjects.repeatable_move")

  local function map_move(lhs, rhs, desc)
    map({ "n", "x", "o" }, lhs, rhs, { desc = desc })
  end

  map_move("]m", function() ts_move.goto_next_start("@function.outer", "textobjects") end, "Next function start")
  map_move("]]", function() ts_move.goto_next_start("@class.outer", "textobjects") end, "Next class start")
  map_move("]o", function() ts_move.goto_next_start("@loop.outer", "textobjects") end, "Next loop start")
  map_move("]s", function() ts_move.goto_next_start("@local.scope", "locals") end, "Next scope")
  map_move("]z", function() ts_move.goto_next_start("@fold", "folds") end, "Next fold")

  map_move("]M", function() ts_move.goto_next_end("@function.outer", "textobjects") end, "Next function end")
  map_move("][", function() ts_move.goto_next_end("@class.outer", "textobjects") end, "Next class end")

  map_move("[m", function() ts_move.goto_previous_start("@function.outer", "textobjects") end, "Previous function start")
  map_move("[[", function() ts_move.goto_previous_start("@class.outer", "textobjects") end, "Previous class start")

  map_move("[M", function() ts_move.goto_previous_end("@function.outer", "textobjects") end, "Previous function end")
  map_move("[]", function() ts_move.goto_previous_end("@class.outer", "textobjects") end, "Previous class end")

  map({ "n", "x", "o" }, ";", ts_repeat_move.repeat_last_move_next)
  map({ "n", "x", "o" }, ",", ts_repeat_move.repeat_last_move_previous)
  map({ "n", "x", "o" }, "f", ts_repeat_move.builtin_f_expr, { expr = true })
  map({ "n", "x", "o" }, "F", ts_repeat_move.builtin_F_expr, { expr = true })
  map({ "n", "x", "o" }, "t", ts_repeat_move.builtin_t_expr, { expr = true })
  map({ "n", "x", "o" }, "T", ts_repeat_move.builtin_T_expr, { expr = true })
end

local function configure_telescope_symbol_search()
  local function is_rust_test_attribute(line)
    return line:match("^#%s*%[%s*test%s*%]")
        or line:match("^#%s*%[%s*[%w_]+::test")
        or line:match("^#%s*%[%s*rstest")
  end

  local function rust_symbol_has_test_attribute(bufnr, lnum)
    if vim.bo[bufnr].filetype ~= "rust" then
      return false
    end

    local lines = vim.api.nvim_buf_get_lines(bufnr, math.max(0, lnum - 8), lnum - 1, false)
    for i = #lines, 1, -1 do
      local line = vim.trim(lines[i])
      if line == "" then
        return false
      end
      if line:match("^#%s*%[") then
        if is_rust_test_attribute(line) then
          return true
        end
      else
        return false
      end
    end

    return false
  end

  local builtin = require("telescope.builtin")
  local make_entry = require("telescope.make_entry")
  local function treesitter_symbols()
    local opts = { bufnr = vim.api.nvim_get_current_buf(), show_line = true }
    local base_entry_maker = make_entry.gen_from_treesitter(opts)

    opts.entry_maker = function(raw_entry)
      local entry = base_entry_maker(raw_entry)
      if entry and rust_symbol_has_test_attribute(opts.bufnr, entry.lnum) then
        entry.text = "[test] " .. entry.text
        entry.ordinal = "[test] " .. entry.ordinal
      end
      return entry
    end

    builtin.treesitter(opts)
  end

  local function lsp_document_symbols()
    builtin.lsp_document_symbols({ bufnr = vim.api.nvim_get_current_buf(), show_line = true })
  end

  local symbol_picker_by_filetype = {
    c = lsp_document_symbols,
    cpp = lsp_document_symbols,
    objc = lsp_document_symbols,
    objcpp = lsp_document_symbols,
    rust = treesitter_symbols,
    lua = lsp_document_symbols,
    typescript = lsp_document_symbols,
  }

  local function buffer_symbols()
    local ft = vim.bo.filetype
    local picker = symbol_picker_by_filetype[ft]
    if picker then
      picker()
    else
      vim.notify(("No symbol picker configured for filetype %q"):format(ft), vim.log.levels.WARN)
    end
  end

  map("n", "<leader>:", builtin.command_history, { desc = "nvim command history" })
  map("n", "<leader>c", builtin.git_status, { desc = "Telescope: Changed files" })
  map("n", "<leader>b", function() builtin.buffers({ sort_mru = true, sort_lastused = true }) end,
    { desc = "Telescope: Buffers" })
  map("n", "<leader>R", function()
    builtin.oldfiles({ cwd_only = true, prompt_title = "Recent files" })
  end, { desc = "Telescope: Recent files" })
  map("n", "<leader>m", builtin.marks, { desc = "Telescope: Marks" })
  map("n", "<leader>j", builtin.jumplist, { desc = "Telescope: Jumps" })
  map("n", "<leader>s", buffer_symbols, { desc = "Search buffer symbols" })
  --  map("n", "<leader>S", builtin.lsp_dynamic_workspace_symbols, { desc = "Search workspace symbols" })
  map("n", "<leader>?", ":Telescope keymaps<CR>", { silent = true })
  map("n", "<leader>d", "<cmd>Telescope diagnostics<CR>", { desc = "Telescope: diagnostics" })
  map("n", "<leader>rf", function()
    builtin.lsp_references({ include_declaration = false, include_current_line = false })
  end, { desc = "Telescope: lsp_references (usages only)" })
  map("n", "<leader>rr", builtin.registers, { desc = "Registers" })
  map("n", "<leader>ic", builtin.lsp_incoming_calls, { desc = "Telescope: lsp_incoming_calls" })
end

local function configure_completion()
  -- Completion
  local luasnip = require("luasnip")
  luasnip.config.setup({})
  require("luasnip.loaders.from_vscode").lazy_load()

  local cmp = require("cmp")
  local source_labels = {
    buffer = "[Buf]",
    luasnip = "[Snip]",
    nvim_lsp = "[LSP]",
    path = "[Path]",
  }

  cmp.setup({
    preselect = cmp.PreselectMode.None,
    snippet = {
      expand = function(args)
        luasnip.lsp_expand(args.body)
      end,
    },
    completion = {
      completeopt = "menu,menuone,noinsert,noselect",
      autocomplete = { cmp.TriggerEvent.TextChanged },
    },
    formatting = {
      format = function(entry, vim_item)
        vim_item.menu = source_labels[entry.source.name] or ("[" .. entry.source.name .. "]")
        return vim_item
      end,
    },
    view = {
      docs = {
        auto_open = false,
      },
    },
    window = {
      completion = cmp.config.window.bordered({ border = "rounded" }),
      documentation = cmp.config.window.bordered({ border = "rounded" }),
    },
    mapping = cmp.mapping.preset.insert({

      -- ["<C-N>"] = cmp.mapping(function()
      --   if cmp.visible() then
      --     cmp.select_next_item()
      --   else
      --     cmp.complete({
      --       config = {
      --         sources = {
      --           { name = "buffer" },
      --         },
      --       },
      --     })
      --   end
      -- end),

      ["<C-p>"] = cmp.mapping.select_prev_item(),
      ["<C-b>"] = cmp.mapping.scroll_docs(-4),
      ["<C-f>"] = cmp.mapping.scroll_docs(4),
      ["<C-g>"] = cmp.mapping(function(fallback)
        if cmp.visible() then
          if cmp.visible_docs() then
            cmp.close_docs()
          else
            cmp.open_docs()
          end
        else
          fallback()
        end
      end),
      ["<C-y>"] = cmp.mapping.confirm({ select = true }),
      ["<CR>"] = cmp.mapping.confirm({ select = false }),
      ["<Tab>"] = cmp.mapping.select_next_item(),
      ["<S-Tab>"] = cmp.mapping.select_prev_item(),
      ["<C-n>"] = cmp.mapping(function()
        if cmp.visible() then
          cmp.select_next_item()
        else
          cmp.complete({
            config = {
              sources = cmp.config.sources({
                { name = "luasnip" },
                { name = "nvim_lsp" },
              }, {
                { name = "buffer" },
              }),
            },
          })
        end
      end),
      ["<C-l>"] = cmp.mapping(function()
        if luasnip.expand_or_locally_jumpable() then
          luasnip.expand_or_jump()
        end
      end, { "i", "s" }),
      ["<C-h>"] = cmp.mapping(function(fallback)
        if luasnip.locally_jumpable(-1) then
          luasnip.jump(-1)
        else
          fallback()
        end
      end, { "i", "s" }),
    }),
    sources = {
      { name = "luasnip" },
      { name = "nvim_lsp" },
      { name = "path" },
    },
  })
  -- Markdown: no generic autocomplete noise. Obsidian injects its own sources
  -- (wiki-links after [[, tags after #) on vault note enter; those sources only
  -- return items in-context. Outside vaults, sources stay empty.
  cmp.setup.filetype("markdown", {
    completion = { autocomplete = { cmp.TriggerEvent.TextChanged } },
    sources = {},
  })
  cmp.setup.filetype("lua", {
    sources = {
      { name = "luasnip" },
      { name = "nvim_lsp" },
    },
  })
end

local function configure_treesitter_context()
  -- Treesitter context
  require("treesitter-context").setup({
    enable = true,
    max_lines = 3,
    separator = "─",
  })
  vim.api.nvim_set_hl(0, "TreesitterContext", { bg = "#2e2e3e" })
  vim.api.nvim_set_hl(0, "TreesitterContextSeparator", { fg = "#555577" })
end

local function configure_fff()
  require("fff").setup({
    lazy_sync = true,
    layout = {
      height = 0.85,
      width = 0.85,
      preview_position = "right",
      preview_size = 0.5,
    },
    hl = {
      matched = "Special",
      grep_match = "Special",
    },
  })

  local fff = require("fff")
  map("n", "<leader>f", function() fff.find_files() end, { desc = "FFF: Find files" })
  map("n", "<leader>g", function() fff.live_grep() end, { desc = "FFF: Live grep" })
  map("n", "<leader>G", function()
    fff.live_grep({ query = vim.fn.expand("<cword>") })
  end, { desc = "FFF: Grep word under cursor" })
  map("x", "<leader>G", function()
    local lines = vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = vim.fn.mode() })
    local selection = vim.trim(table.concat(lines, " "))
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
    if selection ~= "" then
      fff.live_grep({ query = selection })
    end
  end, { desc = "FFF: Grep selection" })
end

local function configure_telescope()
  local telescope = require("telescope")
  telescope.setup({
    defaults = {
      history = {
        path = "~/.local/share/nvim/telescope_history",
        limit = 1000,
      },
      mappings = {
        i = {
          ["<C-u>"] = false,
          ["<C-d>"] = false,
          ["<C-n>"] = require("telescope.actions").cycle_history_next,
          ["<C-p>"] = require("telescope.actions").cycle_history_prev,
        },
      },
    },
    extensions = {
      fzf = {
        fuzzy = true,
        case_mode = "ignore_case",
        hidden = true,
      },
      ast_grep = {
        command = {
          "ast-grep",
          "--json=stream",
        },
        grep_open_files = false,
        lang = nil,
      },
    },
  })
  telescope.load_extension("fzf")
  telescope.load_extension("ast_grep")
end

local function configure_statusline()
  vim.o.laststatus = 0
  map("n", "<leader>e", function()
    vim.o.laststatus = vim.o.laststatus == 0 and 2 or 0
  end, { desc = "Toggle status line" })

  local function statusline_bufnr()
    local winid = tonumber(vim.g.statusline_winid)
    if winid and vim.api.nvim_win_is_valid(winid) then
      return vim.api.nvim_win_get_buf(winid)
    end

    return vim.api.nvim_get_current_buf()
  end

  function _G.nvim_diagnostic_statusline(bufnr)
    bufnr = bufnr or statusline_bufnr()
    local parts = {}
    local counts = vim.diagnostic.count(bufnr)
    local nvim_statusline_diagnostic_highlights = {
      [vim.diagnostic.severity.ERROR] = "DiagnosticSignError",
      [vim.diagnostic.severity.WARN] = "DiagnosticSignWarn",
      [vim.diagnostic.severity.INFO] = "DiagnosticSignInfo",
      [vim.diagnostic.severity.HINT] = "DiagnosticSignHint",
    }

    for _, item in ipairs({
      { severity = vim.diagnostic.severity.ERROR, label = "E" },
      { severity = vim.diagnostic.severity.WARN,  label = "W" },
      { severity = vim.diagnostic.severity.INFO,  label = "I" },
      { severity = vim.diagnostic.severity.HINT,  label = "H" },
    }) do
      local count = counts[item.severity]
      if count and count > 0 then
        local highlight = nvim_statusline_diagnostic_highlights[item.severity]
        table.insert(parts, ("%%#%s#%s:%d%%##"):format(highlight, item.label, count))
      end
    end

    return table.concat(parts, " ")
  end

  _G.statusline = _G.statusline or {}

  _G.statusline.count_todos_in_open_buffers = function()
    local count = 0

    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(bufnr) and vim.bo[bufnr].buflisted then
        for _, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
          count = count + select(2, line:gsub("TODO", ""))
          count = count + select(2, line:gsub("FIXME", ""))
        end
      end
    end

    return count
  end

  _G.statusline.todo_count = function()
    local count = _G.statusline.count_todos_in_open_buffers()

    if count == 0 then
      return ""
    end

    return ("%%#DiagnosticSignHint#T:%d%%##"):format(count)
  end


  local statusline_todo_count = "%{%v:lua.statusline.todo_count()%}"
  local statusline_diagnostics = "%{%v:lua.nvim_diagnostic_statusline()%}"
  local statusline_position = "%l:%c %P"

  vim.o.statusline = table.concat({
    "%m ",
    "%=",
    statusline_diagnostics,
    " ",
    statusline_todo_count,
    " ",
    statusline_position,
  })
end

local function configure_lsp()
  vim.api.nvim_create_autocmd("LspAttach", {
    callback = function(args)
      local opts = { buffer = args.buf }

      map("n", "K", vim.lsp.buf.hover, opts)
      map("n", "gd", vim.lsp.buf.definition, opts)
      map("n", "gD", vim.lsp.buf.declaration, opts)
      map("n", "grr", vim.lsp.buf.references, opts)
      map("n", "grn", vim.lsp.buf.rename, opts)
      map("n", "gca", vim.lsp.buf.code_action, opts)
    end,
  })

  vim.lsp.config("lua_ls", {
    cmd = { "lua-language-server" },
    filetypes = { "lua" },
    root_markers = { ".luarc.json", ".luarc.jsonc", ".git" },
    settings = {
      Lua = {
        diagnostics = {
          globals = { "vim" },
        },
        runtime = { version = "LuaJIT" },
        workspace = {
          checkThirdParty = false,
          ignoreDir = { ".git", ".jj", ".direnv", "node_modules", "result", "nixos/home/result", "nixos/sys/result" },
          ignoreSubmodules = true,
          library = { vim.env.VIMRUNTIME .. "/lua" },
          maxPreload = 300,
          preloadFileSize = 100,
          useGitIgnore = true,
        },
        completion = {
          showWord = "Disable",
          workspaceWord = false,
        },
        telemetry = { enable = false },
      }
    },
  })

  vim.lsp.enable({
    "eslint",
    "phpactor",
    "vtsls",
    "lua_ls",
    "nixd",
    "scheme_langserver",
  })

  -- vtsls
  vim.lsp.config("vtsls", {
    settings = {
      vtsls = {
        autoUseWorkspaceTsdk = true,
      },
    },
  })

  -- LSP diagnostics
  vim.diagnostic.config({ virtual_text = true, })

  -- Rustacean
  local extension_path = vim.env.HOME .. "/.nix-profile/share/vscode/extensions/vadimcn.vscode-lldb/"
  local codelldb_path = extension_path .. "adapter/codelldb"
  local liblldb_path = extension_path .. "lldb/lib/liblldb.so"
  local codelldb_adapter = require("rustaceanvim.config").get_codelldb_adapter(codelldb_path, liblldb_path)
  vim.g.rustaceanvim = {
    dap = {
      adapter = codelldb_adapter,
    },
    server = {
      default_settings = {
        ["rust-analyzer"] = {
          check = { command = "clippy" },
          cargo = { allFeatures = true },
        },
      },
    },
  }
end

local function c()
  local function c_man_or_lsp_hover()
    local word = vim.fn.expand("<cword>")
    if word == "" then
      vim.lsp.buf.hover()
      return
    end

    local result = vim.system({ "man", "-w", "3", word }, { text = true }):wait()
    if result.code == 0 then
      vim.cmd("Man 3 " .. vim.fn.fnameescape(word))
    else
      vim.lsp.buf.hover()
    end
  end

  local c_filetypes = {
    c = true,
    cpp = true,
    objc = true,
    objcpp = true,
  }

  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("CManHover", { clear = true }),
    callback = function(args)
      if not c_filetypes[vim.bo[args.buf].filetype] then
        return
      end

      map("n", "K", c_man_or_lsp_hover, {
        buffer = args.buf,
        desc = "Open C man page or LSP hover",
      })
    end,
  })

  vim.lsp.config('clangd', {
    cmd = { 'clangd' },
    capabilities = require('cmp_nvim_lsp').default_capabilities(),
    filetypes = { 'c', 'cpp', 'objc', 'objcpp' },
    root_markers = {
      '.clangd',
      'compile_commands.json',
      'compile_flags.txt',
      '.git',
      '.jj',
    },
  })
  vim.lsp.enable('clangd')
end

local function bash()
  vim.lsp.enable('bashls')
end

local function configure_misc_autocommands()
  local function restore_cursor_to_last_position()
    vim.api.nvim_create_autocmd("BufReadPost", {
      callback = function()
        local mark = vim.api.nvim_buf_get_mark(0, '"')
        local lcount = vim.api.nvim_buf_line_count(0)
        if mark[1] > 0 and mark[1] <= lcount then
          pcall(vim.api.nvim_win_set_cursor, 0, mark)
        end
      end,
    })
  end

  -- highlight whitespace at EOL
  local group = vim.api.nvim_create_augroup("ExtraWhitespace", { clear = true })

  vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile", "InsertLeave" }, {
    group = group,
    pattern = "*",
    callback = function()
      vim.cmd([[match ExtraWhitespace /\s\+$/]])
    end,
  })

  vim.api.nvim_create_autocmd("InsertEnter", {
    group = group,
    pattern = "*",
    callback = function()
      vim.cmd([[match none]])
    end,
  })

  -- cursorline color and toggle
  local function get_system_appearance()
    if vim.fn.executable("darkman") == 1 then
      local ok, output = pcall(vim.fn.system, { "darkman", "get" })
      if ok and vim.v.shell_error == 0 then
        local appearance = vim.trim(output)
        if appearance == "light" or appearance == "dark" then
          return appearance
        end
      end
    end

    return vim.o.background
  end

  local function apply_cursor_line_highlight()
    vim.api.nvim_set_hl(0, "CursorLine", {
      -- weaker to stronger contrast for light -> 255..250 and for dark -> 232..241
      ctermbg = get_system_appearance() == "light" and 252 or 237,
    })

    local search_bg_color = get_system_appearance() == "light" and 230 or 101;
    vim.api.nvim_set_hl(0, "Search", { ctermbg = search_bg_color, })
    vim.api.nvim_set_hl(0, "CurSearch", { ctermbg = search_bg_color, })
  end

  apply_cursor_line_highlight()
  vim.api.nvim_create_autocmd({ "ColorScheme", "FocusGained", "VimEnter" }, {
    callback = apply_cursor_line_highlight,
  })

  -- from `:h registers` the Yank-ring: store yanked text in registers 1-9.
  vim.api.nvim_create_autocmd('TextYankPost', {
    callback = function()
      if vim.v.event.operator == 'y' then
        for i = 9, 1, -1 do -- Shift all numbered registers.
          vim.fn.setreg(tostring(i), vim.fn.getreg(tostring(i - 1)))
        end
      end
    end,
  })

  restore_cursor_to_last_position()
end

local function configure_handy_commands()
  -----------------
  -- Handy commands
  -----------------

  vim.api.nvim_create_user_command("ClearRegisters", function()
    local regs = [[abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789/-"*+]]

    for r in regs:gmatch(".") do
      pcall(vim.fn.setreg, r, {})
    end

    vim.fn.setreg("/", "")
    -- persist the cleared registers by calling wshada?
    -- vim.cmd("wshada!");
  end, {})

  local function delete_current_file()
    local bufnr = vim.api.nvim_get_current_buf()
    local filepath = vim.api.nvim_buf_get_name(bufnr)

    if filepath == "" then
      vim.notify("Buffer has no file", vim.log.levels.WARN)
      return
    end

    vim.ui.select({ "Yes", "No" }, {
      prompt = "Delete " .. vim.fn.fnamemodify(filepath, ":~:.") .. "?",
    }, function(choice)
      if choice ~= "Yes" then
        return
      end

      local ok, err = os.remove(filepath)
      if not ok then
        vim.notify("Failed to delete file: " .. err, vim.log.levels.ERROR)
        return
      end

      vim.api.nvim_buf_delete(bufnr, { force = true })
      vim.notify("Deleted " .. filepath)
    end)
  end

  vim.api.nvim_create_user_command("DeleteFile", delete_current_file, {
    desc = "Delete the file for the current buffer",
  })

  -- close all buffers except current
  vim.api.nvim_create_user_command("BOnly", function()
    local current = vim.api.nvim_get_current_buf()

    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if buf ~= current and vim.api.nvim_buf_is_loaded(buf) then
        vim.api.nvim_buf_delete(buf, {})
      end
    end
  end, {})

  --

  local function toggle_line_numbers()
    local enabled = not vim.wo.number
    vim.wo.number = enabled
    vim.wo.relativenumber = enabled
  end

  map("n", "<leader>ll", toggle_line_numbers, { desc = "Toggle line numbers" })

  --

  vim.api.nvim_create_user_command("CursorLineToggle", function()
    vim.wo.cursorline = not vim.wo.cursorline
  end, {});

  --

  vim.api.nvim_create_user_command("GithubCopyLink", function()
    require("gitlinker").get_buf_range_url("n")
  end, {});

  vim.api.nvim_create_user_command("GithubCopyLinkSelection", function()
    require("gitlinker").get_buf_range_url("v")
  end, {});

  vim.api.nvim_create_user_command("GithubOpenLink", function()
    require("gitlinker").get_buf_range_url("n", { action_callback = require("gitlinker.actions").open_in_browser })
  end, {});

  vim.api.nvim_create_user_command("GithubOpenLink", function()
    require("gitlinker").get_buf_range_url("v", { action_callback = require("gitlinker.actions").open_in_browser })
  end, {});
end

local function configure_keymaps()
  map("n", "'", "`") -- make ' jump straight to mark's column

  map("n", "\\wb", function()
    local folder = vim.fn.expand("~/code/blog/posts")
    local date = os.date("%Y-%m-%d")
    local seconds = os.time()
    local filename = string.format("%s/%s_%d.md", folder, date, seconds)
    vim.fn.mkdir(folder, "p")
    vim.cmd("edit " .. filename)
  end, { desc = "Create new timestamped file" })

  -- tmux navigator
  vim.g.tmux_navigator_no_mappings = 1
  map("n", "<M-h>", "<cmd>TmuxNavigateLeft<CR>")
  map("n", "<M-j>", "<cmd>TmuxNavigateDown<CR>")
  map("n", "<M-k>", "<cmd>TmuxNavigateUp<CR>")
  map("n", "<M-l>", "<cmd>TmuxNavigateRight<CR>")

  -- quickfix nav
  map("n", "]q", "<cmd>cnext<CR>zz", { desc = "Next quickfix item", silent = true })
  map("n", "[q", "<cmd>cprev<CR>zz", { desc = "Previous quickfix item", silent = true })
  map("n", "]Q", "<cmd>clast<CR>zz", { desc = "Last quickfix item", silent = true })
  map("n", "[Q", "<cmd>cfirst<CR>zz", { desc = "First quickfix item", silent = true })

  -- loclist nav
  map("n", "]l", "<cmd>lnext<CR>zz", { desc = "Next location-list item", silent = true })
  map("n", "[l", "<cmd>lprev<CR>zz", { desc = "Previous location-list item", silent = true })
  map("n", "]L", "<cmd>llast<CR>zz", { desc = "Last location-list item", silent = true })
  map("n", "[L", "<cmd>lfirst<CR>zz", { desc = "First location-list item", silent = true })

  map("n", "<leader>q", "<cmd>copen<CR>")
  map("n", "<leader>Q", "<cmd>cclose<CR>")
  map("n", "<leader>l", "<cmd>lopen<CR>")
  map("n", "<leader>L", "<cmd>lclose<CR>")

  -- via the primeagen
  -- move visual blocks up and down
  map("v", "J", ":m '>+1<CR>gv=gv")
  map("v", "K", ":m '<-2<CR>gv=gv")
  -- cursor remains in place post J line join
  map("n", "J", "mzJ`z")

  -- avoid overwriting the yank register
  map("x", "<leader>p", [["_dP]])
  --map({ "n", "v" }, "<leader>d", [["_d]])
  --map({ "n", "v" }, "<leader>c", [["_c]])

  -- keep visual selection selected after indents
  map("v", "<", "<gv")
  map("v", ">", ">gv")

  -- reselect the most recently pasted region
  map("n", "gp", "`[v`]")

  map("n", "<leader>y", function() require("yazi").toggle() end, { desc = "Yazi" })

  -- delete without yanking
  map("n", "x", [["_x]])
  map("n", "X", [["_X]])

  -- jump to recent buffer
  map("n", "<leader><leader>", "<C-^>")

  -- toggle comment
  map({ "x", "n" }, "<C-_>", "gcc", { remap = true, desc = "Toggle comment line" })

  -- toggle diagnostics display
  local show_diagnostics = true

  vim.keymap.set('n', '<leader>td', function()
    show_diagnostics = not show_diagnostics
    vim.diagnostic.config({
      virtual_text = show_diagnostics,
      signs = show_diagnostics,
      underline = show_diagnostics,
    })
  end, { desc = 'Toggle diagnostic display' })


  -- Ctrl+Backspace → delete previous word
  -- <C-H> is what many terminals actually send for Ctrl+Backspace
  vim.keymap.set("i", "<C-BS>", "<C-w>", { desc = "Delete word backward" })
  vim.keymap.set("i", "<C-H>", "<C-w>", { desc = "Delete word backward (terminal)" })

  -- Ctrl+Shift+Backspace → delete current line, stay in insert
  vim.keymap.set("i", "<C-S-BS>", "<C-o>dd", { desc = "Delete current line" })

  local opts = { silent = true, desc = "Select by word" }
  -- leave insert without moving the cursor, then start visual
  vim.keymap.set("i", "<C-S-Left>", "<C-\\><C-n>vb", opts)
  vim.keymap.set("i", "<C-S-Right>", "<C-\\><C-n>ve", opts)

  -- normal mode
  vim.keymap.set("n", "<C-S-Left>", "vb", opts)
  vim.keymap.set("n", "<C-S-Right>", "ve", opts)

  -- already in visual: extend by word
  vim.keymap.set("x", "<C-S-Left>", "b", opts)
  vim.keymap.set("x", "<C-S-Right>", "e", opts)
end

local function configure_lsp_formatting()
  -- jj hunks (and lsp format on save the hunks stuff)
  local function jj_root_for_buf(bufnr)
    local bufname = vim.api.nvim_buf_get_name(bufnr)
    if bufname == "" then
      return nil
    end

    local jj_dirs = vim.fs.find(".jj", {
      path = vim.fs.dirname(bufname),
      upward = true,
      type = "directory",
      limit = 1,
    })
    if not jj_dirs[1] then
      return nil
    end

    return vim.fs.dirname(jj_dirs[1])
  end

  local function relative_path(root, path)
    root = vim.fs.normalize(root)
    path = vim.fs.normalize(path)

    local prefix = root:sub(-1) == "/" and root or root .. "/"
    if path:sub(1, #prefix) ~= prefix then
      return nil
    end

    return path:sub(#prefix + 1)
  end

  local function jj_hunk_ranges(bufnr, root)
    if vim.fn.executable("jj") == 0 then
      vim.notify_once("[LSP] jj is not executable; skipping changed-hunk format", vim.log.levels.WARN)
      return nil
    end

    local relpath = relative_path(root, vim.api.nvim_buf_get_name(bufnr))
    if not relpath then
      vim.notify_once("[LSP] Buffer is outside jj workspace; skipping changed-hunk format", vim.log.levels.WARN)
      return nil
    end

    local result = vim.system({
      "jj",
      "--no-pager",
      "--color=never",
      "--quiet",
      "--no-integrate-operation",
      "diff",
      "--git",
      "--context=0",
      "--",
      relpath,
    }, { cwd = root, text = true }):wait()

    if result.code ~= 0 then
      local message = vim.trim(result.stderr or result.stdout or "")
      vim.notify(message ~= "" and message or "[LSP] jj diff failed", vim.log.levels.ERROR)
      return nil
    end

    local ranges = {}
    for line in (result.stdout or ""):gmatch("[^\r\n]+") do
      local start, count = line:match("^@@ %-%d+,?%d* %+(%d+),?(%d*) @@")
      if start then
        start = tonumber(start)
        count = count ~= "" and tonumber(count) or 1
        if start and count and count > 0 then
          ranges[#ranges + 1] = {
            start = start,
            ["end"] = start + count - 1,
          }
        end
      end
    end

    return ranges
  end

  local function line_end_col(bufnr, lnum)
    local line = vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, true)[1] or ""
    return #line - 1
  end

  local function lsp_format_line_range(bufnr, start_line, end_line)
    vim.lsp.buf.format({
      bufnr = bufnr,
      range = {
        start = { start_line, 0 },
        ["end"] = { end_line, line_end_col(bufnr, end_line) },
      },
    })
  end

  local function has_lsp_format_client(bufnr, method)
    return #vim.lsp.get_clients({ bufnr = bufnr, method = method }) > 0
  end

  local function lsp_format_line_ranges(bufnr, ranges)
    if #ranges == 0 then
      return false
    end


    if not has_lsp_format_client(bufnr, "textDocument/rangeFormatting") then
      vim.notify_once(
        ("[LSP] No range formatter for %s; skipping changed-hunk format"):format(vim.bo[bufnr].filetype),
        vim.log.levels.WARN
      )
      return false
    end

    local line_count = vim.api.nvim_buf_line_count(bufnr)
    for i = #ranges, 1, -1 do
      local range = ranges[i]
      local start_line = math.max(range.start, 1)
      local end_line = math.min(range["end"], line_count)
      if start_line <= end_line then
        lsp_format_line_range(bufnr, start_line, end_line)
      end
    end

    return true
  end

  local function lsp_format_jj_hunks(bufnr, root)
    return lsp_format_line_ranges(bufnr, jj_hunk_ranges(bufnr, root) or {})
  end

  local function lsp_format_local_hunks(bufnr)
    local jj_root = jj_root_for_buf(bufnr)
    if jj_root then
      if vim.bo[bufnr].modified then
        vim.notify_once("[LSP] Save before manually formatting jj hunks", vim.log.levels.WARN)
        return false
      end

      return lsp_format_jj_hunks(bufnr, jj_root)
    end
  end

  local function lsp_format_buffer(bufnr)
    if has_lsp_format_client(bufnr, "textDocument/formatting") then
      vim.lsp.buf.format({ bufnr = bufnr })
    end
  end

  local function lsp_format_visual_selection(bufnr)
    local start_line = vim.fn.line("'<")
    local end_line = vim.fn.line("'>")
    if start_line > end_line then
      start_line, end_line = end_line, start_line
    end

    lsp_format_line_range(bufnr, start_line, end_line)
  end

  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("UserLspFormatting", { clear = true }),
    callback = function(ev)
      local opts = { buf = ev.buf, silent = true }
      map("n", "<leader>lf", function()
        lsp_format_buffer(ev.buf)
      end, vim.tbl_extend("force", opts, { desc = "Format buffer" }))
      map("x", "<leader>lf", function()
        lsp_format_visual_selection(ev.buf)
      end, vim.tbl_extend("force", opts, { desc = "Format selection" }))
      map("n", "<leader>lF", function()
        lsp_format_local_hunks(ev.buf)
      end, vim.tbl_extend("force", opts, { desc = "Format changed hunks" }))
    end,
  })

  local lsp_format_on_save_filetypes = {
    javascript = "file",
    javascriptreact = "file",
    lua = "file",
    nix = "file",
    php = "hunks",
    r = "file",
    rust = "file",
    scheme = "file",
    typescript = "hunks",
    typescriptreact = "hunks",
    c = "file",
    -- sh, has no range formatter and too many others
  }

  local lsp_format_on_save_group = vim.api.nvim_create_augroup("LspFormatOnSave", { clear = true })

  vim.api.nvim_create_autocmd("BufWritePre", {
    group = lsp_format_on_save_group,
    pattern = "*",
    callback = function(ev)
      local format_mode = lsp_format_on_save_filetypes[vim.bo[ev.buf].filetype]
      if not format_mode then
        return
      end

      if format_mode == "file" then
        lsp_format_buffer(ev.buf)
      elseif format_mode == "hunks" then
        local jj_root = jj_root_for_buf(ev.buf)
        if jj_root then
          vim.b[ev.buf].lsp_format_jj_hunks_after_save = jj_root
        else
          lsp_format_jj_hunks(ev.buf)
        end
      else
        vim.notify_once(
          ("[LSP] Invalid format-on-save mode %q for %s"):format(tostring(format_mode), vim.bo[ev.buf].filetype),
          vim.log.levels.WARN
        )
      end
    end,
  })

  vim.api.nvim_create_autocmd("BufWritePost", {
    group = lsp_format_on_save_group,
    pattern = "*",
    callback = function(ev)
      local jj_root = vim.b[ev.buf].lsp_format_jj_hunks_after_save
      if not jj_root then
        return
      end
      vim.b[ev.buf].lsp_format_jj_hunks_after_save = nil

      if lsp_format_jj_hunks(ev.buf, jj_root) and vim.bo[ev.buf].modified then
        vim.api.nvim_buf_call(ev.buf, function()
          vim.cmd("silent noautocmd write")
        end)
      end
    end,
  })
end

local function configure_obsidian()
  vim.g.bullets_enabled_file_types = { "markdown" }
  vim.g.bullets_enable = 1
  vim.g.bullets_checkbox_markers = " ~x"
  vim.g.bullets_outline_levels = { "std-", "std*", "std+", "num", "rom", "abc", "ROM" }
  vim.g.bullets_set_mappings = 0
  vim.g.bullets_custom_mappings = {
    { "imap",     "<CR>",   "<Plug>(bullets-newline)" },
    { "inoremap", "<C-CR>", "<CR>" },
    { "nmap",     "o",      "<Plug>(bullets-newline)" },
  }
  local function open_vault_file(name)
    local obsidian_state = rawget(_G, "Obsidian")
    local workspace = obsidian_state and obsidian_state.workspace
    local base_path = workspace and tostring(workspace.path) or "~/vaults/sdb"
    local path = vim.fn.resolve(vim.fn.expand(base_path .. "/" .. name))

    if vim.fn.filereadable(path) == 1 then
      vim.cmd("edit " .. vim.fn.fnameescape(path))
    else
      vim.notify(name .. " not found in path: " .. path, vim.log.levels.WARN)
    end
  end

  local function vault_path()
    local obsidian_state = rawget(_G, "Obsidian")
    local dir = obsidian_state and obsidian_state.dir
    if dir then
      return tostring(dir)
    end
    local workspace = obsidian_state and obsidian_state.workspace
    if workspace and workspace.path then
      return tostring(workspace.path)
    end
    return vim.fn.expand("~/vaults/sdb")
  end

  local function fff_vault_find()
    require("fff").find_files({
      title = "Vault notes",
      cwd = vault_path(),
    })
  end

  local function fff_vault_grep()
    require("fff").live_grep({
      title = "Vault search",
      cwd = vault_path(),
    })
  end

  require("obsidian").setup({
    -- Don't set ui.checkboxes here: normalize() warns whenever that key is
    -- present (even for display-only overrides). Patch chars after setup.
    ui = { enable = true },
    legacy_commands = false,
    checkbox = {
      order = { " ", "x" },
    },
    workspaces = {
      { name = "personal", path = "~/vaults/sdb" },
      { name = "work",     path = "~/vaults/clt" },
    },
    daily_notes = {
      folder = "dailies",
      date_format = "%Y-%m-%d",
      default_tags = { "daily-notes" },
      template = "daily-mo",
    },
    completion = {
      nvim_cmp = true,
      min_chars = 2,
    },
    sync = {
      enabled = false,
    },
    note_id_func = function(title)
      if title ~= nil then
        return title:gsub(" ", "-"):gsub("[^A-Za-z0-9-]", ""):lower()
      else
        return tostring(os.time())
      end
    end,
    callbacks = {
      enter_note = function()
        -- Obsidian's inject_sources also pulls in global cmp sources + tags.
        -- Keep only wiki-link completion (fires inside [[ ... ]]).
        require("cmp").setup.buffer({
          sources = {
            { name = "obsidian" },
            { name = "obsidian_new" },
          },
        })
        -- Hot paths via fff; other Obsidian pickers stay on Telescope.
        map("n", "<leader>o", fff_vault_find, {
          buf = 0,
          desc = "Obsidian: Quick Switch (fff)",
        })
        map("n", "<leader>n", ":Obsidian unique_note<CR>", {
          buf = 0,
          desc = "Obsidian: Unique Note",
        })
        map("n", "<leader>N", ":Obsidian orphans<CR>", {
          buf = 0,
          desc = "Obsidian: Orphans",
        })
        map("n", "<leader>g", fff_vault_grep, {
          buf = 0,
          desc = "Obsidian: Search (fff)",
        })
        map("n", "<C-t>", ":Obsidian toggle_checkbox<CR>", {
          buf = 0,
          desc = "Obsidian: Toggle Checkbox",
        })
        map("n", "<CR>", ":Obsidian follow_link<CR>", {
          buf = 0,
          desc = "Obsidian: Follow Link",
        })
      end,
    },
  })

  -- Prefer plain Unicode over Nerd PUA icons (New CM Mono draws those as junk/χ).
  -- Mutate _opts so workspace switches that re-normalize from _opts keep the glyphs.
  local checkbox_chars = { [" "] = "☐", ["x"] = "✓" }
  local function apply_checkbox_chars(ui)
    if not (ui and ui.checkboxes) then
      return
    end
    for key, char in pairs(checkbox_chars) do
      if ui.checkboxes[key] then
        ui.checkboxes[key].char = char
      end
    end
  end
  apply_checkbox_chars(Obsidian._opts and Obsidian._opts.ui)
  apply_checkbox_chars(Obsidian.opts and Obsidian.opts.ui)

  -- Upstream `Obsidian links` feeds bare link strings into picker.pick.
  -- Telescope only attaches a file previewer when entries are tables with
  -- `filename`, so the Links picker shows an empty preview pane. Resolve each
  -- link to a path and rebuild the command.
  local function resolve_link_picker_entry(link, source_note)
    local util = require("obsidian.util")
    local search = require("obsidian.search")
    local location, _, link_type = util.parse_link(link, { exclude = { "Tag", "BlockID" } })
    local entry = {
      text = link,
      user_data = link,
    }

    if not location or not link_type then
      return entry
    end

    location = vim.uri_decode(location)

    if link_type == "HeaderLink" or link_type == "BlockLink" then
      if source_note and source_note.path then
        entry.filename = tostring(source_note.path)
        local resolved
        if link_type == "HeaderLink" and source_note.resolve_anchor_link then
          resolved = source_note:resolve_anchor_link(location)
        elseif link_type == "BlockLink" and source_note.resolve_block then
          resolved = source_note:resolve_block(location)
        end
        if resolved and resolved.line then
          entry.lnum = resolved.line
        end
      end
      return entry
    end

    local block_link, anchor_link
    location, block_link = util.strip_block_links(location)
    location, anchor_link = util.strip_anchor_links(location)

    if util.is_uri(location) then
      return entry
    end

    local notes = search.resolve_note(location, {
      notes = {
        collect_anchor_links = anchor_link ~= nil,
        collect_blocks = block_link ~= nil,
      },
    })
    if notes and notes[1] and notes[1].path then
      entry.filename = tostring(notes[1].path)
      if block_link or anchor_link then
        local loc = notes[1]:_location({ block = block_link, anchor = anchor_link })
        if loc and loc.range and loc.range.start and loc.range.start.line then
          entry.lnum = loc.range.start.line + 1
        end
      end
    end
    return entry
  end

  require("obsidian.commands").register("links", {
    nargs = 0,
    note_action = true,
    func = function()
      local api = require("obsidian.api")
      local note = api.current_note(0, {
        collect_anchor_links = true,
        collect_blocks = true,
      })
      if not note then
        return vim.notify("not in a note", vim.log.levels.INFO, { title = "Obsidian.nvim" })
      end

      local entries = vim.tbl_map(function(match)
        return resolve_link_picker_entry(match.link, note)
      end, note:links())

      if #entries == 0 then
        return vim.notify("no links in note", vim.log.levels.INFO, { title = "Obsidian.nvim" })
      end

      Obsidian.picker.pick(entries, {
        prompt_title = "Links",
        callback = function(entry)
          api.follow_link(entry.user_data or entry.text)
        end,
      })
    end,
  })

  -- Notes with no incoming links from other notes (vault-wide orphan scan).
  -- One pass builds a ref-string index; a second pass marks outbound targets.
  -- Self-links do not count as backlinks.
  require("obsidian.commands").register("orphans", {
    nargs = 0,
    func = function()
      local api = require("obsidian.api")
      local Note = require("obsidian.note")
      local search = require("obsidian.search")
      local util = require("obsidian.util")

      local vault = Obsidian.dir
      if not vault then
        return vim.notify("no workspace", vim.log.levels.WARN, { title = "Obsidian.nvim" })
      end

      vim.notify("Scanning vault for orphans…", vim.log.levels.INFO, { title = "Obsidian.nvim" })

      ---@type { path: string, note: obsidian.Note }[]
      local notes = {}
      ---@type table<string, string[]>
      local ref_index = {}

      local function index_ref(ref, path)
        if not ref or ref == "" then
          return
        end
        local key = string.lower(ref)
        local list = ref_index[key]
        if not list then
          list = {}
          ref_index[key] = list
        end
        for i = 1, #list do
          if list[i] == path then
            return
          end
        end
        list[#list + 1] = path
      end

      for path in api.dir(vault) do
        local ok, note = pcall(Note.from_file, path)
        if ok and note and note.path then
          local abs = tostring(note.path)
          notes[#notes + 1] = {
            path = abs,
            note = note,
          }
          for _, ref in ipairs(note:reference_ids({ lowercase = true })) do
            index_ref(ref, abs)
          end
          for _, ref in ipairs(note:get_reference_paths()) do
            index_ref(ref, abs)
          end
        end
      end

      ---@type table<string, boolean>
      local has_backlink = {}

      local function mark_targets(location, source_path)
        if not location or location == "" or util.is_uri(location) then
          return
        end
        location = vim.uri_decode(location)
        location = select(1, util.strip_block_links(location))
        location = select(1, util.strip_anchor_links(location))
        if not location or location == "" or vim.startswith(location, "#") then
          return
        end
        location = location:gsub("^%./", ""):gsub("^/", "")

        local candidates = {
          location,
          location:gsub("%.md$", ""),
          location .. (vim.endswith(location, ".md") and "" or ".md"),
          vim.fs.basename(location),
          vim.fs.basename(location):gsub("%.md$", ""),
        }
        for _, candidate in ipairs(candidates) do
          if candidate ~= "" then
            local targets = ref_index[string.lower(candidate)]
            if targets then
              for _, target in ipairs(targets) do
                if target ~= source_path then
                  has_backlink[target] = true
                end
              end
            end
          end
        end
      end

      for _, entry in ipairs(notes) do
        local ok, matches = pcall(search.find_links, entry.note)
        if ok then
          for _, match in ipairs(matches) do
            local location, _, link_type =
                util.parse_link(match.link, { exclude = { "Tag", "BlockID" } })
            if location and link_type ~= "HeaderLink" and link_type ~= "BlockLink" then
              mark_targets(location, entry.path)
            end
          end
        end
      end

      ---@type obsidian.PickerEntry[]
      local orphans = {}
      for _, entry in ipairs(notes) do
        if not has_backlink[entry.path] then
          -- filename only: picker make_display already shows vault-relative path;
          -- setting text too duplicates the same string in the list.
          orphans[#orphans + 1] = {
            filename = entry.path,
          }
        end
      end

      table.sort(orphans, function(a, b)
        return a.filename < b.filename
      end)

      if #orphans == 0 then
        return vim.notify(
          string.format("no orphans among %d notes", #notes),
          vim.log.levels.INFO,
          { title = "Obsidian.nvim" }
        )
      end

      Obsidian.picker.pick(orphans, {
        prompt_title = string.format("Orphans (%d / %d)", #orphans, #notes),
        callback = function(picked)
          api.open_note(picked)
        end,
      })
    end,
  })

  local function load_clt_workspace()
    vim.cmd("Obsidian workspace work")
  end
  local function load_personal_workspace()
    vim.cmd("Obsidian workspace personal")
  end
  map("n", "\\ws", function()
    load_personal_workspace()
    vim.cmd("edit " .. vim.fn.expand("~/vaults/sdb/inbox.md"))
  end, { desc = "Load obsidian personal inbox" })
  map("n", "\\ww", function()
    load_clt_workspace()
    vim.cmd("edit " .. vim.fn.expand("~/vaults/clt/inbox.md"))
  end, { desc = "Load obsidian work inbox" })
  map("n", "\\wt", function()
    load_personal_workspace()
    open_vault_file("todo.md")
  end, { desc = "Open Personal todo.md" })
  map("n", "\\wT", function()
    load_clt_workspace()
    open_vault_file("todo.md")
  end, { desc = "Open CLT todo.md" })
  map("n", "\\wd", function()
    load_personal_workspace()
    vim.cmd("Obsidian today")
  end, { desc = "Open Personal daily" })
end

local function configure_folding()
  local lsp_fold_filetypes = {
    c = true,
    cpp = true,
    objc = true,
    objcpp = true,
  }
  vim.o.foldmethod = 'expr'
  vim.o.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
  vim.o.foldlevel = 99

  -- treesitter foldexpr walks injected languages too (e.g. rust inside
  -- ```rust fences), so notes get noisy nested folds. Heading-only outline.
  -- Applied from after/ftplugin/markdown.lua (window-local).
  function _G.markdown_heading_foldexpr()
    local lnum = vim.v.lnum
    local line = vim.fn.getline(lnum)
    local hashes = line:match("^%s*(#+)%s")
    if hashes then
      return ">" .. #hashes
    end
    return "="
  end

  local function apply_markdown_folds(buf)
    buf = buf or vim.api.nvim_get_current_buf()
    if vim.bo[buf].filetype ~= "markdown" then
      return
    end
    for _, win in ipairs(vim.fn.win_findbuf(buf)) do
      vim.wo[win].foldmethod = "expr"
      vim.wo[win].foldexpr = "v:lua.markdown_heading_foldexpr()"
      vim.wo[win].foldenable = true
    end
  end

  vim.api.nvim_create_autocmd("FileType", {
    pattern = "markdown",
    callback = function(ev)
      apply_markdown_folds(ev.buf)
    end,
  })

  vim.api.nvim_create_autocmd("BufWinEnter", {
    callback = function(ev)
      apply_markdown_folds(ev.buf)
    end,
  })

  vim.opt.foldtext = "v:lua.custom_foldtext()"
  vim.opt.foldcolumn = "0"
  vim.opt.fillchars:append({ fold = " " })

  function _G.custom_foldtext()
    local line = vim.fn.getline(vim.v.foldstart)
    -- local count = vim.v.foldend - vim.v.foldstart + 1
    return "≻  " .. line .. "  ≺"
  end

  vim.api.nvim_create_autocmd('LspAttach', {
    callback = function(ev)
      if not lsp_fold_filetypes[vim.bo[ev.buf].filetype] then
        return
      end

      local client = vim.lsp.get_client_by_id(ev.data.client_id)
      if client and client:supports_method('textDocument/foldingRange') then
        for _, win in ipairs(vim.fn.win_findbuf(ev.buf)) do
          vim.wo[win][0].foldmethod = 'expr'
          vim.wo[win][0].foldexpr = 'v:lua.vim.lsp.foldexpr()'
          vim.wo[win][0].foldlevel = 99
          vim.wo[win][0].foldenable = true
        end
      end
    end,
  })


  local function open_only_fold_at_level(target_level)
    local cur = vim.api.nvim_win_get_cursor(0)
    local lnum = cur[1]

    if target_level < 1 then
      vim.cmd("normal! zM")
      vim.wo.foldlevel = 0
      return
    end

    vim.cmd("normal! zM")
    vim.wo.foldlevel = target_level - 1
    local start = vim.fn.foldclosed(lnum)
    if start == -1 then
      start = lnum
    end
    vim.api.nvim_win_set_cursor(0, { start, 0 })
    vim.cmd("normal! zO")
    vim.api.nvim_win_set_cursor(0, cur)
    vim.cmd("normal! zv")
  end

  local function focus_parent_fold()
    local level = vim.fn.foldlevel(".")
    if level <= 1 then
      open_only_fold_at_level(level)
    else
      open_only_fold_at_level(level - 1)
    end
  end

  vim.keymap.set("n", "<leader>Z", focus_parent_fold, {
    desc = "Open only parent fold subtree",
  })
  map("n", "<leader>z", "zMzv", { desc = "Close all folds except current line", })
end

local function configure_telescope_snippets()
  local function search_luasnip_snippets()
    local ls = require("luasnip")
    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")
    local previewers = require("telescope.previewers")

    local snippets = {}

    -- available() = snippets available for current file / current position
    for ft, snips in pairs(ls.available(function(snip)
      return snip
    end)) do
      for _, snip in ipairs(snips) do
        table.insert(snippets, {
          ft = ft,
          snip = snip,
        })
      end
    end

    local sorters = require("telescope.sorters")

    pickers.new({}, {
      prompt_title = "LuaSnip snippets: " .. vim.bo.filetype,

      finder = finders.new_table({
        results = snippets,

        entry_maker = function(entry)
          local snip = entry.snip
          local trigger = snip.trigger or ""
          local name = snip.name or trigger
          local desc = snip.description or snip.dscr or ""

          if type(desc) == "table" then
            desc = table.concat(desc, " ")
          end

          return {
            value = entry,
            display = string.format("%-10s %-20s %s", entry.ft, trigger, name),
            ordinal = table.concat({ entry.ft, trigger, name, desc }, " "),
          }
        end,
      }),

      sorter = sorters.get_fuzzy_file({}),

      previewer = previewers.new_buffer_previewer({
        define_preview = function(self, entry)
          local snip = entry.value.snip
          local doc = snip:get_docstring()

          if type(doc) == "string" then
            doc = vim.split(doc, "\n")
          end

          vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, doc or {})
          vim.bo[self.state.bufnr].filetype = entry.value.ft
        end,
      }),

      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local entry = action_state.get_selected_entry()
          actions.close(prompt_bufnr)

          vim.cmd("startinsert!")
          vim.defer_fn(function()
            ls.snip_expand(entry.value.snip)
          end, 50)
        end)

        return true
      end,
    }):find()
  end

  vim.keymap.set("n", "<leader>S", search_luasnip_snippets, {
    desc = "Search LuaSnip snippets",
  })
end

local function configure_readonly_files()
  vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
    pattern = { "*.lock", "*/generated/*" },
    callback = function()
      vim.bo.modifiable = false
      vim.bo.readonly = true
    end,
  })
end

configure_debugging()
configure_general_options()
configure_plugins()
configure_treesitter()
configure_telescope_symbol_search()
configure_completion()
configure_treesitter_context()
configure_fff()
configure_telescope()
configure_statusline()
configure_lsp()
c()
bash()
configure_misc_autocommands()
configure_handy_commands()
configure_keymaps()
configure_lsp_formatting()
configure_obsidian()
configure_folding()
configure_telescope_snippets()
configure_readonly_files()
configure_syntax_highlighting()

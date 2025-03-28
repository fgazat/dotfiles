return {
    "neovim/nvim-lspconfig",
    event = "VeryLazy",
    dependencies = {
        "williamboman/mason.nvim",
        "williamboman/mason-lspconfig.nvim",
        "hrsh7th/cmp-nvim-lsp",
        "hrsh7th/cmp-buffer",
        "hrsh7th/cmp-path",
        "hrsh7th/cmp-cmdline",
        "hrsh7th/nvim-cmp",
        "saadparwaiz1/cmp_luasnip",
        'kristijanhusak/vim-dadbod-completion',
        -- "j-hui/fidget.nvim",
    },
    config = function()
        local cmp = require('cmp')
        local cmp_lsp = require("cmp_nvim_lsp")


        local lspconfig = require("lspconfig")
        local capabilities = vim.tbl_deep_extend(
            "force",
            {},
            vim.lsp.protocol.make_client_capabilities(),
            cmp_lsp.default_capabilities())
        -- capabilities.workspace.didChangeWatchedFiles.dynamicRegistration = false
        -- capabilities.textDocument.completion.completionItem.snippetSupport = true

        -- require("fidget").setup({})

        require("mason").setup()

        require("mason-lspconfig").setup({
            ensure_installed = {
                "html",
                "lua_ls",
                -- "pylsp",
                -- "pyright",
                "bashls",
                "gopls",
                "marksman",
                "ts_ls",
                "templ",
                "htmx",
                "buf_ls",
                "tailwindcss",
                "svelte"
            },

            handlers = {
                function(server_name) -- default handler (optional)
                    require("lspconfig")[server_name].setup {
                        capabilities = capabilities
                    }
                end,

                ["lua_ls"] = function()
                    lspconfig.lua_ls.setup {
                        capabilities = capabilities,
                        settings = {
                            Lua = {
                                runtime = { version = "Lua 5.1" },
                                diagnostics = {
                                    globals = { "bit", "vim", "it", "describe", "before_each", "after_each" },
                                }
                            }
                        }
                    }
                end,

                pyright = function()
                    lspconfig.pyright.setup {
                        capabilities = capabilities,
                        settings = {
                            python = {
                                analysis = {
                                    typeCheckingMode = "off",
                                },
                            },
                        },
                    }
                end,

                pylsp = function()
                    lspconfig.pylsp.setup {
                        autostart = false
                    }
                end,

                gopls = function()
                    local filter = {
                        "-",
                        "+infra/infractl/cli",
                        "+locdoc/doc_tools",
                        "+locdoc/doc_tools/yfm",
                        "+locdoc/libs/go",
                        "+locdoc/libs/gowiki",
                        "+locdoc/libs/godaas",
                        "+locdoc/projects/wl/back",
                        "+locdoc/projects/cashdesk/gobackend",
                        "+locdoc/doc/daas-farm/",
                        "+locdoc/doc/doccenter/go-sitemap",
                        "+junk/azat-fg",
                        "+billing/pepperoni",
                        "+billing/library/go",
                        "-library",
                        "+library/go",
                        "+tasklet",
                        "+sandbox/tasklet",
                        "+yt/go",
                        "+noc/go",
                        "+security/markdown_check/mdcheck",
                        -- "+browser/backend/pkg/startrek"
                    }

                    local home_dir = vim.env.HOME
                    local cmd = home_dir .. "/.ya/tools/v4/gopls-darwin-arm64/gopls"
                    -- local p = vim.fn.getcwd()
                    --
                    -- vim.notify(p .. "path", "error", {})
                    if string.find(vim.fn.getcwd(), "/goarc") == nil then
                        cmd = home_dir .. "/.local/share/nvim/mason/bin/gopls"
                        filter = {}
                    end

                    lspconfig.gopls.setup {
                        cmd = { cmd },
                        capabilities = capabilities,
                        settings = {
                            gopls = {
                                experimentalPostfixCompletions = true,
                                analyses = {
                                    unusedparams = true,
                                    shadow = true,
                                },
                                hints = {
                                    assignVariableTypes = true,
                                    compositeLiteralFields = true,
                                    compositeLiteralTypes = true,
                                    constantValues = true,
                                    functionTypeParameters = true,
                                    parameterNames = true,
                                    rangeVariableTypes = true,
                                },
                                staticcheck = true,
                                usePlaceholders = true,
                                expandWorkspaceToModule = false,
                                directoryFilters = filter,
                            },
                        },
                    }
                end,
            }
        })


        cmp.setup({
            snippet = {
                expand = function(args)
                    require('luasnip').lsp_expand(args.body) -- For `luasnip` users.
                end,
            },
            mapping = cmp.mapping.preset.insert {
                ["<C-j>"] = cmp.mapping.select_next_item { behavior = cmp.SelectBehavior.Insert },
                ["<C-k>"] = cmp.mapping.select_prev_item { behavior = cmp.SelectBehavior.Insert },
                ["<C-y>"] = cmp.mapping.confirm({ select = true }),
                ["<C-Space>"] = cmp.mapping.complete(),
            },

            window = {
                documentation = {
                    border = "rounded",
                    winhighlight = "NormalFloat:Pmenu,NormalFloat:Pmenu,CursorLine:PmenuSel,Search:None",
                },
                completion = {
                    border = "rounded",
                    winhighlight = "NormalFloat:Pmenu,NormalFloat:Pmenu,CursorLine:PmenuSel,Search:None",
                },
            },
            sources = cmp.config.sources({
                { name = 'nvim_lsp' },
                { name = 'luasnip' }, -- For luasnip users.
                -- { name = 'path' }, -- For luasnip users.
            }, {
                { name = 'path' }, { name = "buffer" },
            }),

            sorting = {
                priority_weight = 2,
                comparators = {
                    -- Below is the default comparitor list and order for nvim-cmp
                    cmp.config.compare.offset,
                    -- cmp.config.compare.scopes, --this is commented in nvim-cmp too
                    cmp.config.compare.exact,
                    cmp.config.compare.score,
                    cmp.config.compare.recently_used,
                    cmp.config.compare.locality,
                    cmp.config.compare.kind,
                    cmp.config.compare.sort_text,
                    cmp.config.compare.length,
                    cmp.config.compare.order,
                },
            },
        })
        cmp.setup.filetype({ "sql" }, {
            sources = {
                { name = "vim-dadbod-completion" },
                -- { name = "buffer" },
            }
        })
        cmp.setup.filetype({ "markdown" }, {
            enabled = true,
            sources = {
                { name = "luasnip" },
                { name = "path" },
            },
        })

        vim.diagnostic.config({
            virtual_text = false,
            -- update_in_insert = true,
            float = {
                focusable = false,
                style = "minimal",
                border = "rounded",
                source = "always",
                header = "",
                prefix = "",
            },
        })

        vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, {
            border = "rounded",
        })

        vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, {
            border = "rounded",
        })
    end
}

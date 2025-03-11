-- vim.cmd("colorscheme default")
return {
    { "sainnhe/gruvbox-material", lazy = false, priority = 1000, },
    { "rebelot/kanagawa.nvim",    lazy = false, priority = 1000, },
    {
        "rose-pine/neovim",
        name = "rose-pine",
        lazy = false,
        priority = 1000,
        config = function()
            require('rose-pine').setup({
                variant = "dark",
                disable_background = true,
                styles = {
                    italic = false,
                    transparency = true,
                },
            })
            vim.cmd("colorscheme rose-pine-moon")
            vim.cmd("highlight Visual guibg=#c4a7e7 guifg=black")
        end
    }
}

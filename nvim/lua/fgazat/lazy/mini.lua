return {
    'echasnovski/mini.nvim',
    version = '*',
    event = "VeryLazy",
    config = function()
        require('mini.ai').setup()
        require('mini.comment').setup()
    end
}

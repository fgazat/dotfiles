vim.api.nvim_set_keymap('n', '<leader>gg', [[:lua SendBufferToChatGPT()<CR>]], { noremap = true, silent = true })
vim.api.nvim_set_keymap('v', '<leader>gg', [[:lua SendSelectionToChatGPT()<CR>]], { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>gp', [[:lua PromptAndSendToChatGPT()<CR>]], { noremap = true, silent = true })
vim.api.nvim_set_keymap('v', '<leader>gp', [[:lua SendSelectionWithPromptToChatGPT()<CR>]],
    { noremap = true, silent = true })
local spinner_ns = vim.api.nvim_create_namespace("chatgpt_spinner")
local spinner_timer = nil
local spinner_line = 0
local spinner_col = 0
local spinner_index = 1
local spinner_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
-- Table to keep track of active processes per buffer
local active_processes = {}
-- Function to send the entire buffer to ChatGPT
function SendBufferToChatGPT()
    local buf = vim.api.nvim_get_current_buf()
    if active_processes[buf] then
        vim.notify("A query is already being processed for this buffer.", vim.log.levels.WARN)
        return
    end
    active_processes[buf] = true
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local text = table.concat(lines, "\n")
    ProcessTextWithChatGPT(buf, text)
end

-- Function to send selected text to ChatGPT
function SendSelectionToChatGPT()
    local buf = vim.api.nvim_get_current_buf()
    if active_processes[buf] then
        vim.notify("A query is already being processed for this buffer.", vim.log.levels.WARN)
        return
    end
    active_processes[buf] = true
    local start_pos = vim.fn.getpos("'<")
    local end_pos = vim.fn.getpos("'>")
    local start_line = start_pos[2] - 1
    local end_line = end_pos[2]
    local lines = vim.api.nvim_buf_get_lines(buf, start_line, end_line, false)
    local text = table.concat(lines, "\n")
    ProcessTextWithChatGPT(buf, text)
end

-- Function to prompt user for input and send both text and input to ChatGPT
function PromptAndSendToChatGPT()
    local prompt = vim.fn.input("Provide additional context: ")

    if prompt == "" then
        vim.notify("No input provided.", vim.log.levels.INFO)
        return
    end
    local buf = vim.api.nvim_get_current_buf()
    if active_processes[buf] then
        vim.notify("A query is already being processed for this buffer.", vim.log.levels.WARN)
        return
    end
    active_processes[buf] = true
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local text = table.concat(lines, "\n")
    local combined_text = text .. "\n---\nUser Input: " .. prompt

    ProcessTextWithChatGPT(buf, combined_text)
end

function SendSelectionWithPromptToChatGPT()
    local buf = vim.api.nvim_get_current_buf()
    if active_processes[buf] then
        vim.notify("A query is already being processed for this buffer.", vim.log.levels.WARN)
        return
    end
    local start_pos = vim.fn.getpos("'<")
    local end_pos = vim.fn.getpos("'>")
    local start_line = start_pos[2] - 1
    local end_line = end_pos[2]
    local lines = vim.api.nvim_buf_get_lines(buf, start_line, end_line, false)
    local text = table.concat(lines, "\n")
    -- Prompt the user for additional context
    local prompt = vim.fn.input("Provide additional context: ")

    -- Do nothing if no prompt is provided
    if prompt == "" then
        vim.notify("No input provided.", vim.log.levels.INFO)
        return
    end
    active_processes[buf] = true
    local combined_text = text .. "\n---\nUser Input: " .. prompt
    ProcessTextWithChatGPT(buf, combined_text)
end

-- Map the function to visually selected text with the leader key
vim.api.nvim_set_keymap('v', '<leader>gp', [[:lua SendSelectionWithPromptToChatGPT()<CR>]],
    { noremap = true, silent = true })
-- Function to process and send text to ChatGPT
function ProcessTextWithChatGPT(buf, text)
    local tmpfile = os.tmpname()
    local f = io.open(tmpfile, "w")
    f:write(text)
    f:close()
    -- Spinner position (on current line of that buffer)
    spinner_line = vim.api.nvim_win_get_cursor(0)[1] - 1
    spinner_col = 0
    spinner_index = 1
    -- Start spinner (in that buffer)
    spinner_timer = vim.loop.new_timer()
    spinner_timer:start(0, 100, vim.schedule_wrap(function()
        if vim.api.nvim_buf_is_valid(buf) then
            vim.api.nvim_buf_clear_namespace(buf, spinner_ns, 0, -1)
            vim.api.nvim_buf_set_extmark(buf, spinner_ns, spinner_line, spinner_col, {
                virt_text = { { spinner_frames[spinner_index], "Comment" } },
                virt_text_pos = "eol",
            })
            spinner_index = (spinner_index % #spinner_frames) + 1
        end
    end))
    -- Callback for when stdout is ready
    local function on_stdout(job_id, data, event)
        -- Stop spinner
        if spinner_timer then
            spinner_timer:stop()
            spinner_timer:close()
            spinner_timer = nil
        end
        -- Mark the process as finished
        active_processes[buf] = nil
        if vim.api.nvim_buf_is_valid(buf) then
            vim.api.nvim_buf_clear_namespace(buf, spinner_ns, 0, -1)
            if data then
                local filtered_data = {}
                for _, line in ipairs(data) do
                    if line ~= "" then
                        table.insert(filtered_data, line)
                    end
                end
                -- Add header before the response data
                table.insert(filtered_data, 1, "## GPT RESPONSE")
                -- Insert filtered data into buffer
                local line_count = vim.api.nvim_buf_line_count(buf)
                vim.api.nvim_buf_set_lines(buf, line_count, line_count, false, filtered_data)
            end
        end
        vim.notify("Query finished", vim.log.levels.INFO)
        os.remove(tmpfile)
    end
    -- Run ChatGPT command
    vim.fn.jobstart({ "zsh", "-c", "chatgpt -n < " .. tmpfile }, {
        on_stdout = on_stdout,
        stdout_buffered = true,
        stderr_buffered = true,
    })
end

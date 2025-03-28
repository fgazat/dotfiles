-- Key mappings to trigger functions from normal and visual modes
vim.api.nvim_set_keymap('n', '<leader>gg', [[:lua SendBufferToChatGPT()<CR>]], { noremap = true, silent = true })
vim.api.nvim_set_keymap('v', '<leader>gg', [[:lua SendSelectionToChatGPT()<CR>]], { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>gp', [[:lua PromptAndSendToChatGPT()<CR>]], { noremap = true, silent = true })
vim.api.nvim_set_keymap('v', '<leader>gp', [[:lua SendSelectionWithPromptToChatGPT()<CR>]],
    { noremap = true, silent = true })
-- Spinner related variables
local spinner_ns = vim.api.nvim_create_namespace("chatgpt_spinner")
local spinner_timer = nil
local spinner_line = 0
local spinner_col = 0
local spinner_index = 1
local spinner_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
-- Track active processes per buffer
local active_processes = {}
-- Append response function
function AppendResponseToBuffer()
    local response_buf = vim.api.nvim_get_current_buf()
    local response_lines = vim.api.nvim_buf_get_lines(response_buf, 0, -1, false)
    -- Switch back to original buffer
    vim.cmd('b#')
    local buf = vim.api.nvim_get_current_buf()
    -- Append response to the original buffer
    local line_count = vim.api.nvim_buf_line_count(buf)
    vim.api.nvim_buf_set_lines(buf, line_count, line_count, false, response_lines)
    vim.notify("Response appended to the buffer.", vim.log.levels.INFO)
end

-- Send the entire buffer to ChatGPT
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

-- Send selected lines to ChatGPT
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

-- Prompt user for context and send the whole buffer to ChatGPT
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

-- Prompt user for context and send selection to ChatGPT
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
    local prompt = vim.fn.input("Provide additional context: ")
    if prompt == "" then
        vim.notify("No input provided.", vim.log.levels.INFO)
        return
    end
    active_processes[buf] = true
    local combined_text = text .. "\n---\nUser Input: " .. prompt
    ProcessTextWithChatGPT(buf, combined_text)
end

-- Process text with ChatGPT and add the response to a new buffer
function ProcessTextWithChatGPT(original_buf, text)
    local tmpfile = os.tmpname()
    local f = io.open(tmpfile, "w")
    f:write(text)
    f:close()
    -- Create a new buffer for the response
    vim.cmd("vnew resp.md")
    local response_buf = vim.api.nvim_get_current_buf()
    -- vim.api.nvim_buf_set_option(response_buf, 'filetype', 'markdown')
    -- Spinner position (on the current line of that buffer)
    spinner_line = vim.api.nvim_win_get_cursor(0)[1] - 1
    spinner_col = 0
    spinner_index = 1
    -- Start a spinner
    spinner_timer = vim.loop.new_timer()
    spinner_timer:start(0, 100, vim.schedule_wrap(function()
        if vim.api.nvim_buf_is_valid(response_buf) then
            vim.api.nvim_buf_clear_namespace(response_buf, spinner_ns, 0, -1)
            vim.api.nvim_buf_set_extmark(response_buf, spinner_ns, spinner_line, spinner_col,
                { virt_text = { { spinner_frames[spinner_index], "Comment" } }, virt_text_pos = "eol", })
            spinner_index = (spinner_index % #spinner_frames) + 1
        end
    end))
    -- Callback for processing the stdout response
    local function on_stdout(job_id, data, event)
        if spinner_timer then
            spinner_timer:stop()
            spinner_timer:close()
            spinner_timer = nil
        end
        -- Mark the process as finished
        active_processes[original_buf] = nil
        -- Clear the original spinner
        if vim.api.nvim_buf_is_valid(response_buf) then
            vim.api.nvim_buf_clear_namespace(response_buf, spinner_ns, 0, -1)
        end
        if data then
            local filtered_data = {}
            for _, line in ipairs(data) do
                if line ~= "" then
                    table.insert(filtered_data, line)
                end
            end
            -- Add a header before the response data
            table.insert(filtered_data, 1, "## GPT RESPONSE")
            -- Insert filtered data into the response buffer
            vim.api.nvim_buf_set_lines(response_buf, 0, -1, false, filtered_data)
            -- Close the response buffer and append response to the original buffer
            function append_and_close()
                local line_count = vim.api.nvim_buf_line_count(original_buf)
                vim.api.nvim_buf_set_lines(original_buf, line_count, line_count, false, filtered_data)
                vim.cmd("bd!") -- Close the response buffer
            end

            -- Keybindings for response buffer
            vim.api.nvim_buf_set_keymap(response_buf, 'n', '<leader>a', ':lua append_and_close()<CR>',
                { noremap = true, silent = true })
            vim.api.nvim_buf_set_keymap(response_buf, 'n', '<leader>q', ':bd!<CR>', { noremap = true, silent = true })
        end
        -- Cleanup
        os.remove(tmpfile)
    end
    -- Run the chatgpt command on the temporary file
    vim.fn.jobstart({ "zsh", "-c", "chatgpt -n < " .. tmpfile },
        { on_stdout = on_stdout, stdout_buffered = true, stderr_buffered = true, })
end

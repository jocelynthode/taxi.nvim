local taxi = require("taxi")

describe("taxi format", function()
  it("formats entries with aligned columns", function()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(buf)

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      "a 1 Task",
      "longalias 12:30 Another task",
      "note line",
    })

    taxi.format_file()

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

    assert.equals("a            1        Task", lines[1])
    assert.equals("longalias    12:30    Another task", lines[2])
    assert.equals("note line", lines[3])
  end)
end)

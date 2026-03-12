vim.opt.runtimepath:append(vim.fn.getcwd())
package.path = vim.fn.getcwd() .. "/tests/?.lua;" .. package.path

local plenary_path = os.getenv("PLENARY_PATH")
if plenary_path then
  vim.opt.runtimepath:append(plenary_path)
end

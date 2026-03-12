{ pkgs, ... }:

{
  env.PLENARY_PATH = "${pkgs.vimPlugins.plenary-nvim}";

  enterTest = ''
    set -euo pipefail
    exec 1>&2
    echo "Running taxi.nvim tests..."
    ${pkgs.neovim}/bin/nvim --headless -u tests/minimal_init.lua \
      -c "PlenaryBustedDirectory tests/ { minimal_init = './tests/minimal_init.lua', verbose = true }" \
      -c "qa"
  '';

}

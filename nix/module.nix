{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.zellij.project-sidebar;

  initScript = shell: ''
    eval "$(${pkgs.zellij-sidebar-init}/bin/zellij-sidebar-init hook ${shell})"
  '';
in

{
  options.programs.zellij.project-sidebar = {
    enable = mkEnableOption "zellij-project-sidebar shell activity tracking";

    enableZshIntegration = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to enable the shell hook in zsh.
        Injects the init command into `programs.zsh.initContent`.
      '';
    };

    enableBashIntegration = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to enable the shell hook in bash.
        Injects the init command into `programs.bash.initExtra`.
      '';
    };

    staleTimeout = mkOption {
      type = types.ints.positive;
      default = 3600;
      description = ''
        How long (in seconds) a state file can persist without a heartbeat
        before the plugin ignores it. Applies to both AI and shell state.
        Default is 3600 (60 minutes).
      '';
    };
  };

  config = mkIf cfg.enable {
    home.sessionVariables.SIDEBAR_STALE_TIMEOUT = toString cfg.staleTimeout;

    programs.zsh.initContent = mkIf cfg.enableZshIntegration (initScript "zsh");
    programs.bash.initExtra = mkIf cfg.enableBashIntegration (initScript "bash");

    home.packages = [ pkgs.zellij-sidebar-init ];
  };
}

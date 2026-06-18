{ config, lib, pkgs, package, pluginPackage }:

with lib;

let
  cfg = config.programs.zellij.ssidebar;

  initScript = shell: ''
    eval "$(${package}/bin/zellij-ssidebar hook ${shell})"
  '';
in

{
  options.programs.zellij.ssidebar = {
    enable = mkEnableOption "zellij-ssidebar shell activity tracking and AI activity indicators";

    enableZshIntegration = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to enable the shell hook in zsh.
        Injects the init command into `programs.zsh.interactiveShellInit`.
      '';
    };

    enableBashIntegration = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to enable the shell hook in bash.
        Injects the init command into `programs.bash.shellInit`.
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
    environment.sessionVariables.SIDEBAR_STALE_TIMEOUT = toString cfg.staleTimeout;

    programs.zsh.interactiveShellInit = mkIf cfg.enableZshIntegration (initScript "zsh");
    programs.bash.shellInit = mkIf cfg.enableBashIntegration (initScript "bash");

    environment.systemPackages = [ package ];

    environment.etc."zellij/plugins/zellij-ssidebar.wasm" = {
      source = "${pluginPackage}/zellij-ssidebar.wasm";
    };
  };
}

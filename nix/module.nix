# NixOS module for the PixelStreaming signalling server.
#
# Usage in a flake:
#   imports = [ bevy_streaming.nixosModules.pixelstreaming-signaller ];
#   services.pixelstreaming-signaller.enable = true;
#
# Or for local development without NixOS, run the package directly:
#   nix run .#pixelstreaming-signaller -- --streamer_port 8888 --player_port 8080
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.pixelstreaming-signaller;
  pkg = pkgs.callPackage ./pixelstreaming-signaller.nix { };
in
{
  options.services.pixelstreaming-signaller = {
    enable = lib.mkEnableOption "PixelStreaming signalling server";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkg;
      description = "The pixelstreaming-signaller package to use.";
    };

    streamerPort = lib.mkOption {
      type = lib.types.port;
      default = 8888;
      description = "Port the game (streamer) connects to via WebSocket.";
    };

    playerPort = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Port browsers connect to for the web player and signalling.";
    };

    httpsEnable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable HTTPS for the player-facing web server.";
    };

    httpsPort = lib.mkOption {
      type = lib.types.port;
      default = 8443;
      description = "HTTPS port when TLS is enabled.";
    };

    sslCertPath = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to SSL certificate file.";
    };

    sslKeyPath = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to SSL private key file.";
    };

    peerOptions = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = ''{"iceServers":[{"urls":["stun:stun.l.google.com:19302"]}]}'';
      description = "JSON string of WebRTC peer connection options (STUN/TURN servers).";
    };

    maxPlayers = lib.mkOption {
      type = lib.types.int;
      default = 0;
      description = "Maximum concurrent players. 0 means unlimited.";
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional command-line arguments passed to the signalling server.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open firewall ports for streamer and player connections.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.pixelstreaming-signaller = {
      description = "PixelStreaming WebRTC signalling server";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        ExecStart =
          let
            args =
              [
                "--streamer_port"
                (toString cfg.streamerPort)
                "--player_port"
                (toString cfg.playerPort)
                "--serve"
                "--http_root"
                "${cfg.package}/lib/SignallingWebServer/www"
                "--log_folder"
                "/var/log/pixelstreaming-signaller"
              ]
              ++ lib.optionals (cfg.maxPlayers > 0) [
                "--max_players"
                (toString cfg.maxPlayers)
              ]
              ++ lib.optionals cfg.httpsEnable [
                "--https"
                "--https_port"
                (toString cfg.httpsPort)
              ]
              ++ lib.optionals (cfg.sslCertPath != null) [
                "--ssl_cert_path"
                (toString cfg.sslCertPath)
              ]
              ++ lib.optionals (cfg.sslKeyPath != null) [
                "--ssl_key_path"
                (toString cfg.sslKeyPath)
              ]
              ++ lib.optionals (cfg.peerOptions != null) [
                "--peer_options"
                cfg.peerOptions
              ]
              ++ cfg.extraArgs;
          in
          "${cfg.package}/bin/pixelstreaming-signaller ${lib.escapeShellArgs args}";

        DynamicUser = true;
        StateDirectory = "pixelstreaming-signaller";
        LogsDirectory = "pixelstreaming-signaller";
        WorkingDirectory = "/var/lib/pixelstreaming-signaller";
        Restart = "on-failure";
        RestartSec = 5;

        # Hardening
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectKernelTunables = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
      };
    };

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts =
        [ cfg.streamerPort cfg.playerPort ]
        ++ lib.optionals cfg.httpsEnable [ cfg.httpsPort ];
    };
  };
}

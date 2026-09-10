{
  description = "Home Manager configuration of stephen";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixvim = {
      url = "github:nix-community/nixvim/nixos-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
       url = "github:nix-community/nix-index-database";
       inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    toofan = {
      url = "github:vyrx-dev/toofan";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, nix-index-database, home-manager, nixvim, zen-browser, nixpkgs-unstable, toofan, ... }:
  let
    system = "x86_64-linux";
    allowedUnfree = [
      "anki-bin"
      "claude-code"
      "codex"
      "discord"
      "dropbox"
      "etlegacy"
      "etlegacy-assets"
      "fastmail-desktop"
      "firefox-bin"
      "firefox-bin-unwrapped"
      "grok-build"
      "datagrip"
      "slack"
      "spotify"
      "vscode-extension-vadimcn-vscode-lldb"
    ];

    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfreePredicate = pkg: builtins.elem (nixpkgs.lib.getName pkg) allowedUnfree;
      overlays = [
        (final: prev: {
          zen = zen-browser.packages.${system}.default;
        })
      ];
    };
    pkgs-unstable = import nixpkgs-unstable {
      inherit system;
      config.allowUnfreePredicate = pkg: builtins.elem (nixpkgs-unstable.lib.getName pkg) allowedUnfree;
    };
  in
  {
    homeConfigurations."stephen" = home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        nix-index-database.homeModules.default
        nixvim.homeModules.nixvim
        ./nixvim.nix
        {
          home.username = "stephen";
          home.homeDirectory = "/home/stephen";
          # The state version is required and should stay at the version you originally installed.
          home.stateVersion = "25.05";  # did you read the comment?

          home.packages = with pkgs; [
            toofan.packages.${pkgs.stdenv.hostPlatform.system}.default
            aerc
            akkuPackages.scheme-langserver
            #algol68g
            anki-bin
            ast-grep
            awscli2
            ssm-session-manager-plugin
            bat
            #bzflag
            chez
            cliphist
            vscode-extensions.vadimcn.vscode-lldb
            cmatrix
            csvkit
            darkman
            dict
            dig
            discord
            djbdns
            dmidecode
            dropbox
            easyeffects
            eksctl
            element-desktop
            emmylua-ls
            etlegacy
            etlegacy-assets
            exercism
            exiftool
            firefox-bin-unwrapped
            fd
            fractal
            gdb
            ghostty
            git-filter-repo
            git-open
            gnuplot_qt
            grim
            gtypist
            hyprlock
            iamb
            imagemagick
            iw
            delta
            difftastic
            jetbrains.datagrip
            lazygit
            libnotify
            libqalculate
            librespot
            librsvg # for mdmath.nvim
            lsof
            lua
            lua-language-server
            man-pages
            man-pages-posix
            mako
            ncdu
            nixd
            nmap
            nodejs_24
            openssl
            pcalc
            playerctl
            psmisc
            pdf4qt
            pdftk
            swi-prolog
            ripgrep
            rpi-imager
            rustlings
            shfmt
            slack
            signal-desktop
            slurp
            swaybg
            swayidle
            swayimg
            swaylock
            syncthing
            telegram-desktop
            timer
            tree-sitter
            tt
            # TODO move to flake
            # (texlive.combine {
            # inherit (texlive) scheme-medium
            #   collection-langenglish
            #   collection-mathscience
            #   collection-bibtexextra
            #   collection-latexextra
            #   collection-fontsrecommended
            #   dvisvgm;   # for SVG previews in some viewers
            # })
            # latexrun
            yazi
            yq
            wev
            wf-recorder
            whois
            zen
            zip
            zoxide
            zulip
            zulip-term
            # (import ./custom_derivations/tableplus.nix { inherit pkgs; })
            # libreoffice  TODO move me to a separate nix flake in a directory to avoid heavy updates
          ] ++ [
            # pkgs-unstable.fastmail-desktop
            # pkgs-unstable.claude-code
            pkgs-unstable.spotify
            pkgs-unstable.codex
            pkgs-unstable.ncspot
            pkgs-unstable.jjui
            pkgs-unstable.jujutsu
            pkgs-unstable.ffmpeg_9
            pkgs-unstable.grok-build
          ];

          programs = {
            home-manager.enable = true;
            btop.enable = true;
            chromium.enable = true;
            gh.enable = true;
            mpv.enable = true;
            zathura =  {
              enable = true;
                options = {
                  selection-clipboard = "clipboard";
                  render-loading = false;
              };
            };
            direnv = {
              enable = true;
              enableZshIntegration = true;
              nix-direnv.enable = true;
              silent = true;
              config = {
                global = {
                  hide_env_diff = true;
                };
              };
            };
          };

          xdg.mimeApps = {
            enable = true;
            defaultApplications = let
              defaultBrowser = "zen-beta.desktop";
            in
            {
              "image/png" = "swayimg.desktop";
              "image/jpg" = "swayimg.desktop";
              "image/jpeg" = "swayimg.desktop";
              "application/pdf" = "org.pwmt.zathura.desktop";
              "x-scheme-handler/http" = "${defaultBrowser}";
              "x-scheme-handler/https" = "${defaultBrowser}";
              "x-scheme-handler/chrome" = "${defaultBrowser}";
              "application/x-extension-htm" = "${defaultBrowser}";
              "application/x-extension-html" = "${defaultBrowser}";
              "application/x-extension-shtml" = "${defaultBrowser}";
              "application/x-extension-xhtml" = "${defaultBrowser}";
              "application/x-extension-xht" = "${defaultBrowser}";
              "application/xhtml+xml" = "${defaultBrowser}";
              "text/html" = "${defaultBrowser}";
              "x-scheme-handler/sgnl" = "signal.desktop";
              "x-scheme-handler/signalcaptcha" = "signal.desktop";
              "x-scheme-handler/tg" = "org.telegram.desktop.desktop";
              "x-scheme-handler/tonsite" = "org.telegram.desktop.desktop";
            };
          };

          services = {
            darkman.enable = true;
            easyeffects.enable = true;
          };


        }
      ];
    };
  };
}

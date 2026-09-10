# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, lib, pkgs, modulesPath, unstable, inputs, ... }:
{
  imports = [
    ./hardware-configuration.nix
  ];

  networking.useDHCP = lib.mkDefault true;

  hardware = {
    graphics = {
      enable = true;
      extraPackages = with pkgs; [ mesa ];
    };
    bluetooth = {
      enable = true;
      powerOnBoot = true;
      settings.General.ControllerMode = "bredr";
      settings.Policy.AutoEnable = true;
      settings.General.Experimental = true;
    };
    amdgpu = {
     opencl.enable = true;
    };
    i2c.enable = true;
    enableAllFirmware = true;
    firmware = [ pkgs.linux-firmware ];
  };

  boot.loader.systemd-boot.enable = false;
  boot.kernelPackages = pkgs.linuxPackages_7_2;
  boot.kernelModules = [ "i2c-dev" ];
  boot.kernelParams = [ "console=tty3" "resume=UUID=9c6645d4-4d56-444b-8f32-36890a1c8dae" "video=eDP-1:1920x1080@60" "video=DP-7:1920x1080@60" ];
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.grub = {
    enable = true;
    device = "nodev";
    efiSupport = true;
    useOSProber = false;
    configurationLimit = 5;
    memtest86.enable = true;
  };
  networking.hostName = "euclid";
  networking.networkmanager.enable = true;
  networking.hosts = {
    "127.0.0.1" = [
      "dev.cltexam.com"
      "clt2-dev.cltexam.com"
      "app2-dev.cltexam.com"
      "backroom-dev.cltexam.com"
      "cat-dev.cltexam.com"
      "elgato-dev.cltexam.com"
    ];
  };
  networking.firewall = {
    enable = true;
    trustedInterfaces = [ "docker0" ];
    # ports 22000 and 21027 => syncthing
    # 5154 bzFlag
    interfaces."wlp194s0" = {
      allowedTCPPorts = [ 22000 ];
      allowedUDPPorts = [ 22000 21027 ];
    };
    interfaces."enp195s0f0" = {
      allowedTCPPorts = [ 22000 ];
      allowedUDPPorts = [ 22000 21027 ];
    };
    extraCommands = ''
      iptables -A INPUT -i br-+ -j ACCEPT
    '';
  };
  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  users.users.stephen = {
    isNormalUser = true;
    description = "Stephen";
    extraGroups = [ "networkmanager" "wheel" "video" "audio" "docker" "i2c" ];
    # packages = with pkgs; [];
    shell = pkgs.zsh;
  };

  services.fwupd.enable = true;
  services.udev.packages = [ pkgs.ddcutil ];
  nixpkgs.config.allowUnfree = true;
  nix.settings = {
    experimental-features = ["nix-command" "flakes"];
    allowed-users = [ "stephen" ];
    auto-optimise-store = true;
    extra-substituters = [
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };
  environment.systemPackages = with pkgs; [
    comma
    pulsemixer
    nautilus
    tuigreet
    gsettings-desktop-schemas
    glib-networking
    acpi
    alsa-lib
    alsa-tools
    alsa-utils
    brightnessctl
    cryptsetup
    curl
    ddcutil
    foot
    fuzzel
    fzf
    git-lfs
    gcc
    gnupg
    gnumake
    i2c-tools
    jq
    man-pages
    man-pages-posix
    pass-wayland
    pavucontrol
    pciutils
    perf
    php
    pinentry-all
    pipewire
    plocate
    powertop
    pstree
    pulseaudio
    pwvucontrol
    rocmPackages.rocminfo
    runit
    syshud
    theme-sh
    tlp
    tmux
    tree
    unzip
    usbutils
    v4l-utils
    wayland-utils
    wget
    wl-clipboard
    wlr-randr
    xwayland-satellite
    xdg-dbus-proxy
    xdg-desktop-portal
    xdg-desktop-portal-gnome
    xdg-desktop-portal-gtk
  ] ++ (with unstable; [
    bluez
    bluez-alsa
    bluez-tools
    bluetuith
    docker
  ]);

  programs = {
    zsh.enable = true;
    niri = {
      enable = true;
      package = unstable.niri;
    };
    #neovim = {
    #  enable = true;
    #  vimAlias = true;
    #  viAlias = true;
    #  withNodeJs = true;
    #};
    git.enable = true;
    xwayland.enable = true;
    uwsm = {
      enable = true;
      waylandCompositors.niri = {
        prettyName = "niri";
        comment = "niri managed by UWSM";
        binPath = "/run/current-system/sw/bin/niri";
      };
    };
  };

  systemd.services."getty@tty2".enable = false; # disable tty2 for Ly
  systemd.services."getty@tty3".enable = true; # send dmesg here
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd niri-session";
      user = "greeter";
    };
  };

  services.xserver = {
    enable = false;
    # despite xserver being off, we still use this to bind capslock to ctrl for gettys
    xkb = {
      layout = "us";
      options = "ctrl:nocaps";
    };
  };
  console.useXkbConfig = true;

  services.pulseaudio.enable = false;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
    wireplumber.enable = true;
  };
  services.upower.enable = true;
  # services.power-profiles-daemon.enable = true;
  powerManagement.powertop.enable = true;
  services.tlp = {
    enable = true;
    settings = {
      PLATFORM_PROFILE_ON_AC = "balanced";
      PLATFORM_PROFILE_ON_BAT = "low-power";
      PLATFORM_PROFILE_ON_SAV = "low-power";

      CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
      CPU_ENERGY_PERF_POLICY_ON_SAV = "power";

      RADEON_DPM_PERF_LEVEL_ON_AC = "auto";
      RADEON_DPM_PERF_LEVEL_ON_BAT = "auto";
      RADEON_DPM_STATE_ON_AC = "performance";
      RADEON_DPM_STATE_ON_BAT = "battery";
    };
  };

  # Hibernate wiring. s2idle on this AMD laptop is unreliable and has caused
  # unclean shutdowns that corrupted the ext4 inode table. Until/unless BIOS
  # exposes S3 deep sleep, prefer hibernate on lid close.
  boot.resumeDevice = "/dev/disk/by-uuid/9c6645d4-4d56-444b-8f32-36890a1c8dae";
  services.logind.settings.Login = {
    HandleLidSwitch = "suspend-then-hibernate";
    HandleLidSwitchExternalPower = "suspend-then-hibernate";
    HandleLidSwitchDocked = "ignore";
  };
  # making sleep 12 hours until the hibernate bug (waking from sleep when peripherals are plugged in) in linux 7.1 is fixed
  systemd.sleep.settings.Sleep = { HibernateDelaySec = "12h"; };
  services.locate.enable = true;
  security.rtkit.enable = true;

  services.fprintd = {
    enable = true;
    tod.enable = true;
    tod.driver = pkgs.libfprint-2-tod1-goodix;
  };
  security.pam.services = {
    # login.fprintAuth = true;
    sudo.fprintAuth  = true;
    polkit-1.fprintAuth = true;
    gdm.fprintAuth      = true;
  };

  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "net.reactivated.fprint.device.enroll" && subject.isInGroup("wheel")) {
        return polkit.Result.YES;
      }
    });
  '';

#  xdg.portal = {
#    enable = true;
#    wlr.enable = true;
#    extraPortals = [
#      pkgs.xdg-desktop-portal-wlr
#      pkgs.xdg-desktop-portal-gnome
#      pkgs.xdg-desktop-portal-gtk
#    ];
#    configPackages = [
#      pkgs.darkman
#    ];
#    config.common = {
#      default = [ "wlr" "gnome" ];
#      "org.freedesktop.impl.portal.FileChooser" = "gtk";
#      "org.freedesktop.impl.portal.Settings" = "darkman";
#      "org.freedesktop.impl.portal.Screencast" = "wlr";
#      "org.freedesktop.impl.portal.Screenshot" = "wlr";
#    };
#  };

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gnome ];
    configPackages = [ pkgs.darkman ];
    config = {
      common = {
        default = [ "gnome" ];
        "org.freedesktop.impl.portal.Settings" = "darkman";
      };
      niri = {
        "org.freedesktop.impl.portal.Settings" = "darkman";
      };
    };
  };

  services.gnome.gnome-keyring.enable = true;
  #services.dbus.packages = [
  #  pkgs.gnome-session
  #  pkgs.gnome-shell
  #];

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1"; # Enable Wayland support for Electron/Chromium apps
    MOZ_ENABLE_WAYLAND = "1"; # Enable Wayland support in Firefox
    XDG_SESSION_TYPE = "wayland";
    XDG_CURRENT_DESKTOP = "niri";
     XDG_SESSION_DESKTOP = "niri";
  };

  fonts = {
    packages = with pkgs; [
      dejavu_fonts
      nerd-fonts._0xproto
      nerd-fonts.iosevka-term-slab
      nerd-fonts.geist-mono
      nerd-fonts.anonymice
      nerd-fonts.aurulent-sans-mono
      nerd-fonts.go-mono
      nerd-fonts.envy-code-r
      cm_unicode
      newcomputermodern
    ];
    enableDefaultPackages = true;
    fontDir.enable = true;
  };

  documentation.man.cache = {
    enable = true;
    generateAtRuntime = true;
  };

  security.polkit.enable = true;
  virtualisation.docker.enable = true;
  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?
}

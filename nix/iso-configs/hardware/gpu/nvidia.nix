# NVIDIA graphics defaults for Ryoku on NixOS.
{ config, lib, ... }:

{
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    powerManagement.finegrained = false;

    # The proprietary kernel module remains the broadest-compatible default.
    # Users with hardware supported by NVIDIA's open module can opt into it.
    open = lib.mkDefault false;

    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.latest;
  };
}

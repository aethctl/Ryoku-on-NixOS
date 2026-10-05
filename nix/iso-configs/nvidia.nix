{ config, lib, pkgs, ... }:

{
  # Enable the system-wide graphics stack.
  hardware.graphics = {
    enable = true;

    # Enable 32-bit graphics support for applications such as Steam and Wine.
    enable32Bit = true;
  };

  # Use the proprietary NVIDIA driver for Xorg.
  services.xserver.videoDrivers = [ "nvidia" ];

  # NVIDIA-specific configuration.
  hardware.nvidia = {
    # Enable kernel modesetting for better Wayland and graphical session support.
    modesetting.enable = true;

    # Use the open-source NVIDIA kernel module.
    open = true;

    # Install NVIDIA's graphical settings application.
    nvidiaSettings = true;

    # Use the latest NVIDIA driver package available for the selected kernel.
    package = config.boot.kernelPackages.nvidiaPackages.latest;
  };
}

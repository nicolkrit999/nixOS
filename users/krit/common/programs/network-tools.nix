{ delib, pkgs, inputs, ... }:
let
  pkgs-unstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system};

  # Darwin-compatible network tools
  sharedPackages = (with pkgs; [
    arping # ARP broadcast utility (may need sudo/capabilities for raw-socket access to actually send ARP requests)
    bandwhich # CLI utility for displaying current network utilization
    dig # Domain name server
    #evebox # Web Based Event Viewer (GUI) for Suricata EVE Events in Elastic Search (compatible with darwin but currently broken) FIXME
    iperf3 # Tool to measure IP bandwidth using UDP or TCP
    jq # Lightweight and flexible command-line JSON processor
    miniupnpc # Client that implements the UPnP Internet Gateway Device (IGD) specification
    #ntopng # High-speed web-based traffic analysis and flow collection tool (compatible with darwin but currently broken due to libcap Linux-only dependency) FIXME
    openhue-cli # CLI for interacting with Philips Hue smart lighting systems
    sane-backends # Scanner Access Now Easy backends, for network/eSCL scanner testing
    socat # Bidirectional socket relay
    speedtest-cli # Command line interface for testing internet bandwidth using speedtest.net
    tcpdump # Network sniffer
    trippy # Network diagnostic tool
    tshark # Powerful network protocol analyzer
    wireshark # Powerful network protocol analyzer
    wol # Implements Wake On LAN functionality in a small program
    yq # Command-line YAML/XML/TOML processor - jq wrapper for YAML, XML, TOML documents
  ]) ++ (with pkgs-unstable; [
    unifly # Elegant UniFi network management CLI & TUI - for humans and agents
  ]);
in
delib.module {
  name = "krit.services.network-tools";

  options = delib.singleEnableOption false;

  nixos.ifEnabled = {
    environment.systemPackages = sharedPackages ++ (with pkgs; [
      # Linux-only
      ethtool # Utility for controlling network drivers and hardware
      evebox # Web Based Event Viewer (GUI) for Suricata EVE Events in Elastic Search
      iw # Tool to use nl80211
      netcat-openbsd # Modern netcat implementation (nc)
      ntopng # High-speed web-based traffic analysis and flow collection tool
      ptcpdump # Process-aware, eBPF-based tcpdump
      rsyslog # Enhanced syslog implementation
      sane-airscan # Apple AirScan/eSCL backend for SANE, for network scanner discovery
      suricata # Free and open source, mature, fast and robust network threat detection engine
      traceroute # Route tracing utility
      wavemon # Ncurses-based monitoring application for wireless network devices
      wirelesstools # Legacy wireless tools (iwconfig/iwlist), complements iw
    ]);
  };

  darwin.ifEnabled = {
    environment.systemPackages = sharedPackages;
  };
}

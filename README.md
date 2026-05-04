# Bevy Streaming

This is a Bevy plugin for Cloud Gaming.

![Alt text](screenshots/simple.jpg)

It allows to stream Bevy's camera to a streaming server (through WebRTC) with ultra-low latency, and play the game through a simple browser or phone.

You can imagine any kind of game of application, using cloud provider's powerful GPUs, and simply stream the content to any device compatible with WebRTC.

The player can then play from his browser or any device compatible with WebRTC. The input events are sent through a WebRTC data channel.

## Features

- Headless GPU/CPU Acceleration for 2D/3D rendering using Vulkan or any other
- NVIDIA NVENC for H264/H265 encoding through GStreamer's provided plugins to provide high-quality low-latency video streaming
- Software encoding for VP8/VP9/H264/H265 codecs using GStreamer's provided plugins
- Congestion Control algorithm (provided by GStreamer's webrtcsink element)
- Multiple signalling server options:
  - GstWebRTC
  - PixelStreaming
  - LiveKit (WebRTC infrastructure platform)
  - Soon: (supported by GStreamer natively)
    - Amazon Kinesis
    - Janus
    - WHIP
- Implementation of Unreal's Pixel Streaming signalling server protocol to send video and receive mouse/keyboard controls
- Easy configuration of cameras using an helper
- Support for multiple cameras (each cameras is a streamer, and a streamer is a resource)

## Prerequisites

### Linux (Ubuntu 24.04)

Install the following libraries:

```bash
sudo apt-get install \
    libssl-dev \
    libvulkan-dev \
    gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-plugins-ugly \
    gstreamer1.0-libav \
    gstreamer1.0-nice  \
    gstreamer1.0-tools \
    libgstreamer1.0-dev \
    libgstreamer-plugins-base1.0-dev \
    libgstreamer-plugins-good1.0-dev \
    libgstreamer-plugins-bad1.0-dev \
    libasound2-dev
```

### macOS

Install GStreamer and dependencies using Homebrew:

```bash
brew install gstreamer gst-plugins-base gst-plugins-good gst-plugins-bad gst-plugins-ugly gst-libav libnice-gstreamer
```

Upgrade Rust if needed (Rust edition 2024):

```bash
rustup update stable
```

### Nix

On NixOS or any system with the Nix package manager, all dependencies are handled automatically.
No manual installation is required.

Enter the development shell:

```bash
nix develop
```

This provides the Rust toolchain, GStreamer plugins, Vulkan libraries, and all other build dependencies.

## Running the examples

### Quick start with Nix

Start both the signalling server and the streaming example in two terminals:

```bash
# Terminal 1: start the signalling server
nix run .#pixelstreaming-signaller -- --player_port 8080

# Terminal 2: run the example
nix run
```

Open a browser to connect:

- Player (with mouse input): <http://localhost:8080/?StreamerId=player&HoveringMouse=true>
- Spectator (view only): <http://localhost:8080/?StreamerId=spectator>

Click in the player window to begin the WebRTC connection.
The streamer connects to the signalling server on `ws://localhost:8888` (the default streamer port), while browsers connect via the HTTP player port.

<details>
<summary>NixOS module for persistent signalling server</summary>

For a NixOS system that should run the PixelStreaming signalling server as a persistent service, this flake exports a NixOS module.

#### Adding the module

If your NixOS configuration uses flake inputs:

```nix
# flake.nix
{
  inputs.bevy-streaming.url = "github:Joaqim/bevy_streaming";

  outputs = { self, nixpkgs, bevy-streaming, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [
        bevy-streaming.nixosModules.pixelstreaming-signaller
        ./configuration.nix
      ];
    };
  };
}
```

If your NixOS configuration uses npins instead of flake inputs, import the module directly:

```nix
# configuration.nix
let
  sources = import ./npins;
  bevy-streaming = import sources.bevy-streaming;
in
{
  imports = [ (bevy-streaming + "/nix/module.nix") ];
}
```

#### Minimal configuration (plain HTTP, no certificates)

```nix
{
  services.pixelstreaming-signaller = {
    enable = true;
    playerPort = 8080;
    streamerPort = 8888;
    openFirewall = true;
  };
}
```

This starts a systemd service that serves the web player over plain HTTP on port 8080 and accepts streamer connections on port 8888.
No TLS certificates are needed.
The game connects via `ws://localhost:8888` and browsers open `http://<host>:8080`.

For LAN or development use this is the simplest setup.
WebRTC media streams are encrypted with DTLS-SRTP regardless of whether the signalling channel uses TLS, so the video and audio data is always encrypted in transit.

#### Configuration with a STUN server

For connections that need to traverse NAT (players outside the local network), add a STUN server:

```nix
{
  services.pixelstreaming-signaller = {
    enable = true;
    peerOptions = builtins.toJSON {
      iceServers = [{ urls = [ "stun:stun.l.google.com:19302" ]; }];
    };
    openFirewall = true;
  };
}
```

#### Optional: TLS for the signalling channel

TLS is entirely opt-in.
Enable it when the signalling server is exposed to the public internet or when browser security policies require HTTPS:

```nix
{
  services.pixelstreaming-signaller = {
    enable = true;
    httpsEnable = true;
    httpsPort = 8443;
    sslCertPath = "/run/secrets/pixelstreaming/cert.pem";
    sslKeyPath = "/run/secrets/pixelstreaming/key.pem";
    maxPlayers = 4;
    openFirewall = true;
  };
}
```

#### All options

| Option | Type | Default | Description |
|---|---|---|---|
| `enable` | bool | `false` | Enable the service |
| `package` | package | built from npins | Override the signaller package |
| `streamerPort` | port | `8888` | WebSocket port the game connects to |
| `playerPort` | port | `8080` | HTTP port browsers connect to |
| `httpsEnable` | bool | `false` | Enable TLS for the player port |
| `httpsPort` | port | `8443` | HTTPS port when TLS is enabled |
| `sslCertPath` | path or null | `null` | Path to TLS certificate |
| `sslKeyPath` | path or null | `null` | Path to TLS private key |
| `peerOptions` | string or null | `null` | JSON WebRTC peer config (STUN/TURN) |
| `maxPlayers` | int | `0` | Max concurrent players (0 = unlimited) |
| `extraArgs` | list of string | `[]` | Additional CLI arguments |
| `openFirewall` | bool | `false` | Open streamer and player ports |

The service runs as a hardened systemd unit with `DynamicUser`, `ProtectSystem=strict`, and other sandboxing options.

</details>

### PixelStreaming example

First, start a PixelStreaming signalling server with the following command:

```bash
docker run --rm -t -i --network=host pixelstreamingunofficial/pixel-streaming-signalling-server:5.4
```

_Note: 5.5 version has a default feature enabled that makes the WebRTC connection fail on some versions of Chrome._

Launch the example:

```bash
cargo run --example simple
```

### Build the headless Docker image

I've provided a Dockerfile in `docker/Dockerfile` that runs the example as a starting point for you to build your own Docker images.

The Dockerfile is optimized to allow caching of dependencies and prevent unnecessary rebuilds if Cargo.toml is not changed.

Using a multi-stage build also allows to reduce the Docker image size. Of course, many improvements can still be made, PR welcome!

To build the example docker image, run the following command:

```bash
docker build . -f docker/Dockerfile -t bevy_streaming
```

### Run the Docker image

#### Without GPU (not recommended)

To run the docker image without GPU, run the following command:

```bash
docker run --rm \
    -t -i \
    --network=host \
    bevy_streaming
```

_Note: you can ignore the messages `ERROR wgpu_hal::gles:` see https://github.com/bevyengine/bevy/issues/13115._

#### With NVIDIA GPU acceleration (recommended if you have a NVIDIA GPU)

To run the docker image with NVIDIA GPU acceleration, after having installed NVIDIA Container Toolkit (https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html), run the following command:

```bash
docker run --rm \
    -t -i \
    --network=host \
    --runtime nvidia \
    --gpus all \
    -e NVIDIA_VISIBLE_DEVICES=all \
    -e NVIDIA_DRIVER_CAPABILITIES=video,graphics \
    bevy_streaming
```

_Note: you must have a recent version of NVIDIA Container Toolkit installed on your system.
If the Vulkan backend is not available, upgrading NVIDIA Container Toolkit might fix the issue.
See https://github.com/NVIDIA/nvidia-container-toolkit/issues/16 for more information._

Explanation of the parameters:

- `--rm` : removes the container after it exits.
- `-t -i` : runs the container in interactive mode with a pseudo-TTY (see the logs and stop it easily with Ctrl+C)
- `--network=host` : allows the container to access the host's network interfaces, to easily access the Signalling Server.
- `--runtime nvidia` : specifies the NVIDIA runtime for GPU acceleration.
- `--gpus all` : enables access to all available GPUs.
- `-e NVIDIA_VISIBLE_DEVICES=all` : sets the environment variable to make all GPUs visible to the container.
- `-e NVIDIA_DRIVER_CAPABILITIES=all` : sets the environment variable to enable all driver capabilities (see https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/1.10.0/user-guide.html#driver-capabilities).

#### With DRI GPU acceleration (recommended if you have an intel GPU)

```bash
docker run --rm \
    -t -i \
    --network=host \
    --device /dev/dri:/dev/dri \
    bevy_streaming
```

_Note: it is possible that the `vaapih264enc` encoder does not support CBR bitrate. There is a workaround that will be soon provided. If you're in this situation, you can change the encoder priority with this command:_

```bash
docker run --rm \
    -t -i \
    --network=host \
    --device /dev/dri:/dev/dri \
    -e GST_PLUGIN_FEATURE_RANK="x264enc:1000" \
    bevy_streaming
```

This will force to use the CPU H264 encoder.

### Connect to the streamer

- Open the player window: http://localhost/?StreamerId=player&HoveringMouse=true
- Open the spectator window: http://localhost/?StreamerId=spectator

Click in each window to connect to the signalling server.

Freecam Controls:

- Mouse - Move camera orientation
- Scroll - Adjust movement speed
- Left - Hold to grab cursor
- KeyM - Toggle cursor grab
- KeyW & KeyS - Fly forward & backwards
- KeyA & KeyD - Fly sideways left & right
- KeyE & KeyQ - Fly up & down
- ShiftLeft - Fly faster while held

When you move in the player window, the spectator window will always look at you, the big red sphere.

_Note: the parameter `HoveringMouse=true` in url makes sending mouse events by simply hovering the window. If you disable it, the cursor will be grabbed when you click in the window. You can release grabbing of the cursor using `ESC` key._

_Note 2: in the example, the cursor is volontary shown so you can easily have an idea of the latency._


### LiveKit Example

#### Prerequisites for LiveKit

To use LiveKit streaming, you need the `livekitwebrtcsink` GStreamer element installed.

##### macOS

After installing the Homebrew packages above, run:

```bash
./scripts/build-livekit-gstreamer-macos.sh
```

Then add this to your `~/.zshrc` or `~/.bash_profile`:

```bash
export GST_PLUGIN_PATH="$HOME/.local/lib/gstreamer-1.0"
```

##### Linux

Build and install gst-plugins-rs:

```bash
# Clone and build gst-plugins-rs with LiveKit support
git clone https://gitlab.freedesktop.org/gstreamer/gst-plugins-rs.git
cd gst-plugins-rs
cargo build --release -p gst-plugin-webrtc --features livekit

# Install the plugin
sudo install -m 644 target/release/libgstrswebrtc.so \
  $(pkg-config --variable=pluginsdir gstreamer-1.0)/

# Verify installation
gst-inspect-1.0 livekitwebrtcsink
```

_Note: If you run into any Bevy-related build errors, please see the [Bevy repository](https://github.com/bevyengine/bevy) for platform-specific setup instructions._

#### Running with LiveKit Cloud

1. Sign up for a free account at https://livekit.io/cloud
2. Create a new project and get your API credentials
3. Set environment variables:

```bash
export LIVEKIT_URL="wss://your-project.livekit.cloud"
export LIVEKIT_API_KEY="your-api-key"
export LIVEKIT_API_SECRET="your-api-secret"
export LIVEKIT_ROOM_NAME="bevy_streaming_demo"
```

4. Run the LiveKit example:

```bash
cargo run --example livekit --features livekit
```

5. Generate a viewer token and connect:

```bash
uv run ./scripts/generate-viewer-token.py
```

This will output a token and instructions to connect using the LiveKit meet app at https://meet.livekit.io/

![LiveKit Demo](livekit_demo.png)

## Thanks

This plugin would not have been possible without the following libraries:

- Bevy Engine (of course)
- Bevy Capture Plugin (https://crates.io/crates/bevy_capture) for headless capturing of frames to Gstreamer
- GStreamer (https://gstreamer.freedesktop.org/) and Rust Bindings
- Unreal Engine for their Pixel Streaming Infrastructure (https://github.com/EpicGamesExt/PixelStreamingInfrastructure)

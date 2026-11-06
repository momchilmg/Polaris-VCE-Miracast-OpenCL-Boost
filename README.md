
# Polaris-VCE-Miracast-OpenCL-Boost

A tiny, optional OpenCL background workload for AMD Polaris GPUs that may improve hardware video encoding behavior during Windows Miracast screen sharing.

**Tested on an AMD Radeon RX 570 with Windows 10. Not a universal driver fix.**

## The problem

On the tested AMD Polaris system, Windows Miracast exhibited very high Video Encode utilization and occasional video/audio stutter. In our test setup, the issue was especially noticeable at **2560x1440, 30 Hz** while playing video on a Samsung TV.

After pausing a movie and resuming it, Windows Task Manager could show **95-98% Video Encode** utilization. The encoder sometimes remained heavily loaded before settling down. High reported utilization by itself is not proof of missed frames; the practical issue was the accompanying playback stutter.

The project is intended as a lightweight workaround for this behavior, not as a general Miracast connection or Wi-Fi fix. It does **not** automatically connect to a TV.

## How it works

The included Windows CMD script runs FFmpeg as a separate process. FFmpeg:

1. Generates a tiny synthetic image at **64x36 pixels, 1 frame per second**.
2. Uploads it to the selected GPU using OpenCL.
3. Executes an `avgblur_opencl` kernel on the image.
4. Discards the result using FFmpeg's null output.
5. Repeats continuously until stopped.

No video is displayed, streamed, encoded, or saved by the helper itself. Miracast still runs normally through Windows, independently of FFmpeg.

The hypothesis is that periodic real OpenCL kernel dispatches encourage the Polaris GPU to use a different power/performance state while its **VCE (Video Coding Engine)** handles Miracast encoding. This could reduce the *reported* Video Encode utilization and improve playback smoothness.

The exact hardware mechanism has not been directly measured in this Miracast setup. **GPU core clock and VCE clock are not the same thing.**

## Observed results

One repeatedly tested configuration:

| Item | Configuration |
| --- | --- |
| GPU | AMD Radeon RX 570 4 GB (Polaris) |
| OS | Windows 10 |
| Receiver | Samsung TV over Miracast |
| Display mode | 2560x1440 at 30 Hz |
| Test | Video playback on the wireless display |

| Condition | Windows Task Manager Video Encode |
| --- | --- |
| Helper stopped, playback stabilized | Approximately **75%** |
| Helper running at 30 fps | Approximately **41-42%** |
| Helper running at 5 fps | Approximately **41-42%** |
| Helper running at 1 fps (default) | Approximately **41-42%** |

After resuming from a short pause, a brief **93-94%** peak for around **2-3 seconds** could still occur before settling at approximately **41-42%**. The video was reported as smooth once stabilized.

The difference between helper **on** and **off** was reproduced multiple times while keeping the Miracast video playing. These are observations from one PC, not a controlled benchmark across different GPUs.

**Important:** Task Manager's Video Encode percentage is engine utilization, not a direct measurement of encoding throughput, VCE frequency, or video quality. A lower percentage alone does not guarantee more frames per second or fewer dropped frames on other systems.

## Requirements

- Windows 10 or later.
- An AMD Polaris GPU with a working OpenCL runtime (tested on RX 570; other cards are unverified).
- An FFmpeg build with OpenCL support, including the `avgblur_opencl` filter.
- An existing working Miracast connection if you want to test wireless display playback.

Suitable FFmpeg builds are available from:

- [Gyan.dev FFmpeg Builds](https://www.gyan.dev/ffmpeg/builds/)
- [BtbN FFmpeg Builds on GitHub](https://github.com/BtbN/FFmpeg-Builds/releases)

Make sure your selected build includes OpenCL support and the `avgblur_opencl` filter.

## Installation and usage

1. Download and extract an FFmpeg build with OpenCL support:
   - **Gyan.dev:** Download `ffmpeg-release-full.7z`.
   - **BtbN:** Choose a compatible Windows x64 build with OpenCL support, such as `ffmpeg-master-latest-win64-gpl.zip`.

2. Open the extracted FFmpeg `bin` folder, where `ffmpeg.exe` is located.

3. Place `Polaris-VCE-Miracast-OpenCL-Boost.cmd` in that **same folder**.

4. Connect your TV through Windows Miracast as usual.

5. Double-click the CMD file. **It starts immediately with no menu, no duration limit, and a fixed 1 fps helper rate.**

6. Leave the console running while you use Miracast. Press **`q`** in the console (or **`Ctrl+C`**) to stop the helper.

The process can stay in the background or be minimized. You do **not** need to modify the AMD driver, flash a VBIOS, or change the Windows registry.

### Verifying FFmpeg compatibility

Open Command Prompt inside the FFmpeg `bin` folder and run:

```bat
ffmpeg.exe -filters
```

Check that `avgblur_opencl` appears in the list of available filters.


To verify that FFmpeg can initialize an OpenCL GPU, run:

```bat
ffmpeg.exe -hide_banner -loglevel verbose -init_hw_device opencl=ocl:,device_type=gpu -f lavfi -i "testsrc2=size=64x36:rate=1" -frames:v 1 -f null NUL
```

This tests OpenCL GPU initialization using the same device selection as the helper. It does not enumerate every available OpenCL device. On systems with multiple OpenCL GPUs, explicit device selection may be required.

The FFmpeg build must provide OpenCL support, and your AMD driver must provide a working OpenCL runtime.

## What the script runs

```bat
"%FFMPEG%" -hide_banner -loglevel info -stats -init_hw_device opencl=ocl:,device_type=gpu -filter_hw_device ocl -re -f lavfi -i "testsrc2=size=64x36:rate=1" -vf "format=nv12,hwupload,avgblur_opencl=sizeX=1:sizeY=1,hwdownload,format=nv12" -an -f null NUL
```

- `device_type=gpu` asks FFmpeg to select an OpenCL GPU device. Systems with multiple OpenCL GPUs may require an explicit device selection.
- `rate=1` submits one synthetic input frame per second; it does not mean exactly one low-level GPU instruction per second.
- `-re` paces input to real time.
- `-f null NUL` discards the result instead of writing a video file.
- No `-t` option means the process continues until you stop it.

The helper does not perform video encoding itself. Its purpose is to generate a very small, periodic OpenCL workload while another application performs hardware encoding.

## Troubleshooting

**`ffmpeg.exe was not found`**

Put the CMD file directly next to `ffmpeg.exe`, not in a separate folder.

**OpenCL device initialization error**

Check that your AMD driver provides an OpenCL runtime and that the FFmpeg build includes OpenCL support.

A PC with several OpenCL-capable devices might need a specific platform/device index instead of the default GPU filter.

See the [FFmpeg hardware device documentation](https://ffmpeg.org/ffmpeg.html).

**`No such filter: avgblur_opencl`**

Use an FFmpeg build that provides OpenCL filters, such as a compatible Full build linked above.

**No improvement**

Stop the helper and compare the same video with it running and stopped.

This is a hardware/driver-dependent workaround, not a guaranteed performance boost.

**Increased power or temperature**

Even at 1 fps, a periodic compute workload may keep the GPU in a higher power state.

Monitor temperatures, clock speeds, and power draw, and stop the helper if necessary.

**The console window closes immediately**

Run the CMD file from an existing Command Prompt window to inspect any error messages.

Verify that FFmpeg is available, OpenCL is initialized successfully, and the selected GPU supports the required filter.

## Scope and limitations

- The helper does not modify `WUDFHost.exe`, Windows Miracast, or the video stream.
- It is not a fix for Wi-Fi Direct negotiation, connection failures, or wireless interference.
- The tested system had AMD Adrenalin `GPU Workload = Compute` and application-specific `Performance` profiles.
- The measurements above demonstrate a reproducible on/off effect of the OpenCL helper **within that configuration**. Whether those driver settings are required has not been established.
- There is no guarantee the same behavior will occur on RX 470, RX 480, RX 580, RX 590, or other GPUs.
- Other uses of VCE/AMF are plausible areas for experimentation, but are **not validated by these Miracast measurements**.
- The helper can increase idle GPU power consumption by keeping certain hardware resources active.
- Reported Video Encode utilization is not a direct measurement of the encoder's operating frequency or encoding performance.

## License

This project is released under the MIT License. See [LICENSE](LICENSE) for details.
